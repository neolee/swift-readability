import Foundation
import SwiftSoup

/// Removes Pixnet in-article keyword/tag footer block.
///
/// SiteRule Metadata:
/// - Scope: Pixnet article keyword footer
/// - Phase: `unwanted` cleanup
/// - Trigger: `div.article-keyword` inside extracted article content
/// - Evidence: `realworld/pixnet`
/// - Risk if misplaced: keyword/tag links leak into article tail
enum PixnetArticleKeywordRule: ArticleCleanerSiteRule {
    static let id = "pixnet-article-keyword"

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        try articleContent.select("div.article-keyword").remove()
    }
}
