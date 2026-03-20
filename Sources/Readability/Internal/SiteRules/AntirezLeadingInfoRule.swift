import Foundation
import SwiftSoup

/// Removes antirez leading post metadata from extracted article content.
///
/// SiteRule Metadata:
/// - Scope: antirez leading article metadata strip
/// - Phase: `unwanted` cleanup
/// - Trigger: `article.comment > span.info` with username link and sibling `<pre>` article body
/// - Evidence: `ex-pages/antirez-*`
/// - Risk if misplaced: removes legitimate inline metadata spans on unrelated pages
enum AntirezLeadingInfoRule: ArticleCleanerSiteRule {
    static let id = "antirez-leading-info"

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        for info in try articleContent.select("span").reversed() {
            guard try AntirezRuleHelpers.isArticleMetadataInfoNode(info) else { continue }
            try info.remove()
        }
    }
}
