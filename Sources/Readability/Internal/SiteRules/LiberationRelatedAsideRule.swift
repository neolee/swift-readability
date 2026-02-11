import Foundation
import SwiftSoup

/// Removes Liberation "related content" aside embedded at the top of article body.
///
/// SiteRule Metadata:
/// - Scope: Liberation related-content module
/// - Phase: `unwanted` cleanup
/// - Trigger: `aside#related-content`
/// - Evidence: `realworld/liberation-1`
/// - Risk if misplaced: related links leak into extracted article tail
enum LiberationRelatedAsideRule: ArticleCleanerSiteRule {
    static let id = "liberation-related-aside"

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        try articleContent.select("aside#related-content").remove()
    }
}
