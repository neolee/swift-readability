import Foundation
import SwiftSoup

/// Removes Washington Post gallery/chrome blocks that are not article body content.
///
/// SiteRule Metadata:
/// - Scope: Washington Post gallery embed and scald gallery containers
/// - Phase: `unwanted` cleanup
/// - Trigger: `[data-scald-gallery]` and `div[id^=gallery-embed_]`
/// - Evidence: `realworld/wapo-1`, `realworld/wapo-2`
/// - Risk if misplaced: interactive gallery chrome remains in extracted content
enum WashingtonPostGalleryEmbedRule: ArticleCleanerSiteRule {
    static let id = "washingtonpost-gallery-embed"

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        // Scald gallery widgets (and companion heading wrappers) are non-article chrome.
        for gallery in try articleContent.select("[data-scald-gallery]") {
            if let parent = gallery.parent(), parent.tagName().lowercased() == "div" {
                try parent.remove()
            } else {
                try gallery.remove()
            }
        }

        // Washington Post gallery embeds are interactive chrome; Mozilla output drops them.
        try articleContent.select("div[id^=gallery-embed_]").remove()
    }
}
