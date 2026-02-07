import Foundation
import SwiftSoup

/// Removes Seattle Times section rail inserts that are link-dense related modules.
///
/// SiteRule Metadata:
/// - Scope: Seattle Times `data-section` related-link rail blocks
/// - Phase: `unwanted` cleanup
/// - Trigger: `div[data-section]` plus list/link-density thresholds without media
/// - Evidence: `realworld/seattletimes-1`
/// - Risk if misplaced: related-link rail remains inside article body
enum SeattleTimesSectionRailRule: ArticleCleanerSiteRule {
    static let id = "seattletimes-section-rail"

    static func apply(to articleContent: Element, context: ArticleCleanerSiteRuleContext) throws {
        for panel in try articleContent.select("div[data-section]").reversed() {
            guard panel.parent() != nil else { continue }
            if (try? panel.select("img, picture, figure, video, iframe, object, embed, table").isEmpty()) == false {
                continue
            }
            let listCount = try panel.select("ul, ol").count
            let linkCount = try panel.select("a").count
            let text = ((try? DOMHelpers.getInnerText(panel)) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let linkDensity = try context.getLinkDensity(panel)
            if listCount >= 1,
               linkCount >= 3,
               text.count <= 1200,
               linkDensity >= 0.2 {
                try panel.remove()
            }
        }
    }
}
