import Foundation
import SwiftSoup

/// Removes WordPress previous/next post navigation blocks from extracted content.
///
/// SiteRule Metadata:
/// - Scope: WordPress post navigation rail
/// - Phase: `postProcess` cleanup
/// - Trigger: compact div containers containing `a[rel=prev]` / `a[rel=next]` with
///   "Previous Post:" / "Next Post:" lead-in text
/// - Evidence: `realworld/wordpress`
/// - Risk if misplaced: navigation rail leaks into article body output
enum WordPressPrevNextNavigationRule: ArticleCleanerSiteRule {
    static let id = "wordpress-prev-next-navigation"

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        for container in try articleContent.select("div").reversed() {
            guard container.parent() != nil else { continue }
            if (try? container.select("img, picture, figure, video, iframe, object, embed, table").isEmpty()) == false {
                continue
            }

            let prevLinks = try container.select("a[rel=prev]")
            let nextLinks = try container.select("a[rel=next]")
            guard !prevLinks.isEmpty() || !nextLinks.isEmpty() else { continue }

            let normalizedText = ((try? DOMHelpers.getInnerText(container)) ?? "")
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            let hasPrevLabel = normalizedText.contains("previous post:")
            let hasNextLabel = normalizedText.contains("next post:")
            guard hasPrevLabel || hasNextLabel else { continue }

            // Keep this narrow to navigation rails only.
            if normalizedText.count <= 500 {
                try container.remove()
            }
        }
    }
}
