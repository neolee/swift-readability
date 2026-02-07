import Foundation
import SwiftSoup

/// Removes NYTimes live/latest list panels that represent navigation chrome.
///
/// SiteRule Metadata:
/// - Scope: NYTimes latest/popular stream panel modules
/// - Phase: `unwanted` cleanup
/// - Trigger: direct `> ol[aria-live=off]` with multi-item list in container div
/// - Evidence: NYTimes real-world fixtures (`nytimes-2`/`nytimes-3`/`nytimes-4`/`nytimes-5`)
/// - Risk if misplaced: navigation streams remain in extracted article body
enum NYTimesLivePanelsRule: ArticleCleanerSiteRule {
    static let id = "nytimes-live-panels"

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        for panel in try articleContent.select("div") {
            let hasLiveList = (try? panel.select("> ol[aria-live=off]").isEmpty()) == false
            guard hasLiveList else { continue }
            let listCount = try panel.select("> ol > li").count
            if listCount >= 3 {
                try panel.remove()
            }
        }
    }
}
