import Foundation
import SwiftSoup

/// Removes inline Twitter embed widgets retained in Aktualne article bodies.
///
/// SiteRule Metadata:
/// - Scope: Aktualne inline social embeds
/// - Phase: `unwanted` cleanup
/// - Trigger: `div[id^=twttr_]` and `div.codefragment--twitter`
/// - Evidence: `realworld/aktualne`
/// - Risk if misplaced: non-article social embeds interrupt paragraph flow
enum AktualneTwitterEmbedRule: ArticleCleanerSiteRule {
    static let id = "aktualne-twitter-embed"

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        try articleContent.select("div[id^=twttr_], div.codefragment--twitter").remove()
    }
}
