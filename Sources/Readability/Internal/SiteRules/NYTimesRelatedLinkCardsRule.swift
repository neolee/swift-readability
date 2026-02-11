import Foundation
import SwiftSoup

/// Removes NYTimes in-article related-link card inserts.
///
/// SiteRule Metadata:
/// - Scope: NYTimes related-link card/list inserts inside article flow
/// - Phase: `preConversion` cleanup
/// - Trigger: link hrefs containing `module=RelatedLinks` and `pgtype=Article`
/// - Evidence: NYTimes real-world fixtures (`nytimes-2`/`nytimes-3`/`nytimes-4`/`nytimes-5`)
/// - Risk if misplaced: related-link cards pollute article text continuity
enum NYTimesRelatedLinkCardsRule: ArticleCleanerSiteRule {
    static let id = "nytimes-related-link-cards"

    static func apply(to articleContent: Element, context: ArticleCleanerSiteRuleContext) throws {
        let links = try articleContent.select("a[href*=module=RelatedLinks][href*=pgtype=Article]")
        var cardContainers: [Element] = []
        var sectionContainers: [Element] = []

        for link in links {
            var cursor: Element? = link
            while let node = cursor {
                let tag = node.tagName().lowercased()
                if tag == "div",
                   node.parent()?.tagName().lowercased() == "section" {
                    sectionContainers.append(node)
                    break
                }
                if tag == "div",
                   node.parent()?.tagName().lowercased() == "div" {
                    cardContainers.append(node)
                    break
                }
                if tag == "article" || node.parent() == nil {
                    break
                }
                cursor = node.parent()
            }
        }

        for container in cardContainers.reversed() {
            guard container.parent() != nil else { continue }
            let allLinks = try container.select("a")
            guard !allLinks.isEmpty() else { continue }
            let relatedLinksCount = allLinks.array().filter { link in
                let href = ((try? link.attr("href")) ?? "").lowercased()
                return href.contains("module=relatedlinks") && href.contains("pgtype=article")
            }.count
            let textLength = try DOMHelpers.getInnerText(container)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .count
            if relatedLinksCount == allLinks.count, textLength <= 260 {
                try container.remove()
            }
        }

        for container in sectionContainers.reversed() {
            guard container.parent() != nil else { continue }
            let headingCount = try container.select("h1, h2, h3, h4, h5, h6").count
            if headingCount > 0 {
                continue
            }

            let allLinks = try container.select("a")
            guard !allLinks.isEmpty() else { continue }

            let relatedLinksCount = allLinks.array().filter { link in
                let href = ((try? link.attr("href")) ?? "").lowercased()
                return href.contains("module=relatedlinks") && href.contains("pgtype=article")
            }.count

            let textLength = try DOMHelpers.getInnerText(container)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .count
            let linkDensity = try context.getLinkDensity(container)

            if relatedLinksCount == allLinks.count,
               textLength <= 420,
               linkDensity >= 0.15 {
                try container.remove()
            }
        }
    }
}
