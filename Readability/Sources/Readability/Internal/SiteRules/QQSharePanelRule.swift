import Foundation
import SwiftSoup

/// Removes Tencent QQ share control panel from extracted article content.
///
/// SiteRule Metadata:
/// - Scope: Tencent QQ article share widget
/// - Phase: `unwanted` cleanup
/// - Trigger: `div#shareBtn`
/// - Evidence: `realworld/qq`
/// - Risk if misplaced: share UI is promoted ahead of article body content
enum QQSharePanelRule: ArticleCleanerSiteRule {
    static let id = "qq-share-panel"

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        try articleContent.select("div#shareBtn").remove()

        // In QQ fixtures, `#rv-player` keeps nested visual wrappers around share copy.
        // Mozilla output flattens them into direct children before paragraphization.
        try unwrapSelectors(
            ["#rv-player div.mbArticleSharePic", "#rv-player div.rv-player-adjust-img"],
            in: articleContent
        )

        try articleContent.select(
            "#rv-player .rv-top, #rv-player .rv-player-wrap, #rv-player .rv-playlist"
        ).remove()

        try articleContent.select(".correlation-Article-QQ > :not(#vote)").remove()
    }

    private static func unwrapSelectors(_ selectors: [String], in articleContent: Element) throws {
        for selector in selectors {
            for wrapper in try articleContent.select(selector).array() {
                for child in wrapper.children().array() {
                    try wrapper.before(child)
                }
                try wrapper.remove()
            }
        }
    }
}
