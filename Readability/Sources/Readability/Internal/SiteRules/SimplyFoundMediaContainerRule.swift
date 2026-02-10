import Foundation
import SwiftSoup

/// Removes SimplyFound media containers/carousels while keeping caption text blocks.
///
/// SiteRule Metadata:
/// - Scope: SimplyFound article media wrappers
/// - Phase: `unwanted` cleanup
/// - Trigger: `div.media-container` and `div[id^=snippet-][id$=-image-carousel]`
/// - Evidence: `realworld/simplyfound-1`
/// - Risk if misplaced: image-heavy wrapper noise remains in extracted article
enum SimplyFoundMediaContainerRule: ArticleCleanerSiteRule {
    static let id = "simplyfound-media-container"

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        let snippetCarousels = try articleContent.select("div[id^=snippet-][id$=-image-carousel]")
        guard !snippetCarousels.isEmpty() else { return }

        for container in try articleContent.select("div.media-container").reversed() {
            guard container.parent() != nil else { continue }
            try container.remove()
        }
    }
}
