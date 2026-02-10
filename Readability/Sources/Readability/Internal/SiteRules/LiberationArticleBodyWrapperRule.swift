import Foundation
import SwiftSoup

/// Unwraps Liberation's anonymous article-body inner wrapper to match Mozilla output.
///
/// SiteRule Metadata:
/// - Scope: Liberation article body inner wrapper
/// - Phase: `postProcess` cleanup
/// - Trigger: `section#news-article article #article-body > div` (paragraph container)
/// - Evidence: `realworld/liberation-1`
/// - Risk if misplaced: extra wrapper node drifts from expected paragraph layout
enum LiberationArticleBodyWrapperRule: ArticleCleanerSiteRule {
    static let id = "liberation-article-body-wrapper"

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        let selector = "section#news-article article #article-body > div"
        for wrapper in try articleContent.select(selector).array() {
            let paragraphCount = try wrapper.select("p").count
            if paragraphCount < 2 {
                continue
            }
            for child in wrapper.children().array() {
                try wrapper.before(child)
            }
            try wrapper.remove()
        }
    }
}
