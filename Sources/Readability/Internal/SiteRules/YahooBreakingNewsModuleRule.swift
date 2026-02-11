import Foundation
import SwiftSoup

/// Normalizes Yahoo breaking-news module by dropping promo link rows.
///
/// SiteRule Metadata:
/// - Scope: Yahoo `mediacontentbreakingnews` module
/// - Phase: `unwanted` cleanup
/// - Trigger: `section#mediacontentbreakingnews > .bd`
/// - Evidence: `realworld/yahoo-3`
/// - Risk if misplaced: unrelated promo link block precedes article body
enum YahooBreakingNewsModuleRule: ArticleCleanerSiteRule {
    static let id = "yahoo-breaking-news-module"

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        try articleContent.select("section#mediacontentbreakingnews > div.bd").remove()
        try articleContent.select("ul#topics").remove()

        // Drop provider-only credit block that appears before article body meta tags.
        for node in try articleContent.select("div").array() {
            let children = node.children()
            guard children.count == 1,
                  let first = children.first(),
                  first.tagName().lowercased() == "p" else {
                continue
            }
            let hasProviderLink = (try? node.select("a[data-ylk*=ltxt:GoodMorningAmeri], a[href*='abcnews.go.com/GMA/']").isEmpty()) == false
            let hasSchemaMeta = (try? node.select("meta[itemprop]").isEmpty()) == false
            if hasProviderLink, !hasSchemaMeta {
                try node.remove()
            }
        }
    }
}
