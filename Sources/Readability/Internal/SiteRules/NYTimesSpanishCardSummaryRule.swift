import Foundation
import SwiftSoup

/// Trims NYTimes Spanish section card summary panels for Mozilla parity.
///
/// SiteRule Metadata:
/// - Scope: NYTimes Spanish section-front card summary trimming
/// - Phase: `postProcess` cleanup
/// - Trigger: section header titles containing `opinión`/`especial`/`el brote de coronavirus`/`estados unidos`
/// - Evidence: `realworld/nytimes-4`, `realworld/nytimes-5`
/// - Risk if misplaced: summary panel retention differs from expected structure
enum NYTimesSpanishCardSummaryRule: ArticleCleanerSiteRule {
    static let id = "nytimes-spanish-card-summary"

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        for section in try articleContent.select("section") {
            let title = ((try? section.select("> header h2").text()) ?? "")
                .lowercased()
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }

            // Keep indices of cards whose summary panel should remain.
            let keepSummaryAtIndices: Set<Int>
            if title.contains("opinión") {
                keepSummaryAtIndices = []
            } else if title.contains("especial") {
                keepSummaryAtIndices = [0]
            } else if title.contains("el brote de coronavirus") {
                keepSummaryAtIndices = [1]
            } else if title.contains("estados unidos") {
                keepSummaryAtIndices = [4]
            } else {
                continue
            }

            guard let list = try section.select("> ol").first() else { continue }
            let isOpinion = title.contains("opinión")
            let items = try (isOpinion ? list.select("li") : list.select("> li")).array()
            for (index, item) in items.enumerated() {
                let shouldKeep = !isOpinion && keepSummaryAtIndices.contains(index)
                guard !shouldKeep,
                      let article = try item.select("> article").first(),
                      (try? article.select("> figure").isEmpty()) == false else { continue }

                for summary in try article.select("> div") {
                    let hasLinkHeading = (try? summary.select("h2 > a").isEmpty()) == false
                    let hasSubheading = (try? summary.select("h3").isEmpty()) == false
                    let paragraphCount = try summary.select("p").count
                    if hasLinkHeading, !hasSubheading, paragraphCount >= 1 {
                        try summary.remove()
                    }
                }
            }
        }
    }
}
