import Foundation
import SwiftSoup

/// Removes Liberation trailing in-body author container.
///
/// SiteRule Metadata:
/// - Scope: Liberation in-body author footer block
/// - Phase: `unwanted` cleanup
/// - Trigger: `#article-body > .authors-container`
/// - Evidence: `realworld/liberation-1`
/// - Risk if misplaced: author footer leaks as an extra tail block
enum LiberationAuthorsContainerRule: ArticleCleanerSiteRule {
    static let id = "liberation-authors-container"

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        try articleContent.select("#article-body > div.authors-container").remove()
    }
}
