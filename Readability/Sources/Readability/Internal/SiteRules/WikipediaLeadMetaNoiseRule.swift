import Foundation
import SwiftSoup

/// Removes Wikipedia lead hatnotes/shortdescription blocks that should not appear in extracted article content.
///
/// SiteRule Metadata:
/// - Scope: Wikipedia lead metadata/hatnote wrappers
/// - Phase: `unwanted` cleanup
/// - Trigger: `.mw-parser-output > .shortdescription`, `.mw-parser-output > .hatnote[role=note]`
/// - Evidence: `realworld/wikipedia-2`, `realworld/wikipedia-4`
/// - Risk if misplaced: disambiguation/dynamic-list note leaks into lead paragraph flow
enum WikipediaLeadMetaNoiseRule: ArticleCleanerSiteRule {
    static let id = "wikipedia-lead-meta-noise"

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        try articleContent.select(".mw-parser-output > div.shortdescription").remove()
        try articleContent.select(".mw-parser-output > div.hatnote[role='note']").remove()
    }
}
