import Foundation
import SwiftSoup

/// Removes Herald Sun inline "Read more" teaser block that precedes article continuation.
///
/// SiteRule Metadata:
/// - Scope: Herald Sun article teaser widget
/// - Phase: `unwanted` cleanup
/// - Trigger: `div#read-more-link`
/// - Evidence: `realworld/herald-sun-1`
/// - Risk if misplaced: teaser CTA appears as first content node after intro
enum HeraldSunReadMoreLinkRule: ArticleCleanerSiteRule {
    static let id = "herald-sun-read-more-link"

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        try articleContent.select("div#read-more-link").remove()
    }
}
