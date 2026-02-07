import Foundation
import SwiftSoup

/// Removes Yahoo slideshow modal UI blocks from extracted article content.
///
/// SiteRule Metadata:
/// - Scope: Yahoo slideshow modal chrome
/// - Phase: `unwanted` cleanup
/// - Trigger: `div[id^=modal-slideshow-]`
/// - Evidence: `realworld/yahoo-1`, `realworld/yahoo-2`
/// - Risk if misplaced: modal UI containers leak into readable output
enum YahooSlideshowModalRule: ArticleCleanerSiteRule {
    static let id = "yahoo-slideshow-modal"

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        try articleContent.select("div[id^=modal-slideshow-]").remove()
    }
}
