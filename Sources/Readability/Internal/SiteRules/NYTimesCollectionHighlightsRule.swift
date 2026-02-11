import Foundation
import SwiftSoup

/// Normalizes NYTimes collection highlights wrapper structure to match Mozilla output.
///
/// SiteRule Metadata:
/// - Scope: NYTimes `collection-highlights-container` wrapper/layout normalization
/// - Phase: `postProcess` cleanup
/// - Trigger: `section#collection-highlights-container` and `div#collection-highlights-container`
/// - Evidence: `realworld/nytimes-4`, `realworld/nytimes-5`
/// - Risk if misplaced: nested wrapper/layout artifacts diverge from expected output
enum NYTimesCollectionHighlightsRule: ArticleCleanerSiteRule {
    static let id = "nytimes-collection-highlights"

    static func apply(to articleContent: Element, context: ArticleCleanerSiteRuleContext) throws {
        guard let setNodeTag = context.setNodeTag else { return }

        for section in try articleContent.select("section#collection-highlights-container") {
            _ = try setNodeTag(section, "div")
        }

        for container in try articleContent.select("div#collection-highlights-container") {
            guard let firstChild = container.children().first,
                  firstChild.tagName().lowercased() == "div" else { continue }
            let children = firstChild.children()
            guard children.count >= 2,
                  children[0].tagName().lowercased() == "h2",
                  children[1].tagName().lowercased() == "ol" else { continue }
            while let node = firstChild.getChildNodes().first {
                try firstChild.before(node)
            }
            try firstChild.remove()
        }

        for container in try articleContent.select("div#collection-highlights-container") {
            let children = container.children().array()

            // Mozilla output keeps only the leading "Highlights" list block here.
            // Additional sibling div>ol blocks are emitted as separate sections, not nested
            // under collection-highlights-container.
            for child in children.dropFirst(2) where child.tagName().lowercased() == "div" {
                let childElements = child.children().array()
                if childElements.count == 1, childElements.first?.tagName().lowercased() == "ol" {
                    try child.remove()
                }
            }

            // For the first highlight card, Mozilla keeps the hero media block and drops
            // the adjacent plain summary panel (h2 + paragraphs) in this container.
            if let firstItem = try container.select("> ol > li").first(),
               let article = try firstItem.select("> article").first() {
                let articleChildren = article.children().array()
                if articleChildren.count == 2,
                   articleChildren[0].tagName().lowercased() == "figure",
                   articleChildren[1].tagName().lowercased() == "div" {
                    let summary = articleChildren[1]
                    let hasHeading = (try? summary.select("h2").isEmpty()) == false
                    let hasSubheading = (try? summary.select("h3").isEmpty()) == false
                    let paragraphCount = try summary.select("p").count
                    if hasHeading, !hasSubheading, paragraphCount >= 2 {
                        try summary.remove()
                    }
                }
            }
        }
    }
}
