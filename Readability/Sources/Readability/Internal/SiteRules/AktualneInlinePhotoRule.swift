import Foundation
import SwiftSoup

/// Removes inline promotional photo card wrappers retained in Aktualne articles.
///
/// SiteRule Metadata:
/// - Scope: Aktualne inline photo card block
/// - Phase: `unwanted` cleanup
/// - Trigger: `div.article__photo`
/// - Evidence: `realworld/aktualne`
/// - Risk if misplaced: non-paragraph card block interrupts expected paragraph-only flow
enum AktualneInlinePhotoRule: ArticleCleanerSiteRule {
    static let id = "aktualne-inline-photo"

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        try articleContent.select("div.article__photo").remove()
    }
}
