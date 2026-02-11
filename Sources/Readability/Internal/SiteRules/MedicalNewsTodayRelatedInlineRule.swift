import Foundation
import SwiftSoup

/// Removes inline related/promoted modules injected inside MedicalNewsToday article flow.
///
/// SiteRule Metadata:
/// - Scope: MedicalNewsToday inline related/suggested-reading blocks
/// - Phase: `unwanted` cleanup
/// - Trigger: `.related_inline`, `.suggested_reading*`, `.internal_related`
/// - Evidence: `realworld/medicalnewstoday`
/// - Risk if misplaced: recommendation cards pollute article body and shift paragraph parity
enum MedicalNewsTodayRelatedInlineRule: ArticleCleanerSiteRule {
    static let id = "medicalnewstoday-related-inline"

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        try articleContent.select(
            "div.related_inline, h2.suggested_reading, h2.internal_related, div.suggested_reading_container, div.suggested_reading_inner"
        ).remove()
    }
}

