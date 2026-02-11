import Foundation
import SwiftSoup

/// Removes BBC JS-driven media placeholders that should not remain in article body.
///
/// SiteRule Metadata:
/// - Scope: BBC article video placeholder chrome
/// - Phase: `unwanted` cleanup
/// - Trigger: `div.media-placeholder[data-media-type=video]` and equivalent class/data signature
/// - Evidence: `realworld/bbc-1`
/// - Risk if misplaced: media placeholder leaks into content body
enum BBCVideoPlaceholderRule: ArticleCleanerSiteRule {
    static let id = "bbc-video-placeholder"

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        try articleContent.select(
            "div.media-placeholder[data-media-type=video], div[data-media-type=video][class*=media-placeholder]"
        ).remove()
    }
}
