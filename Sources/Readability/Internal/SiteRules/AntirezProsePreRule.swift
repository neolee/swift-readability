import Foundation
import SwiftSoup

/// Marks antirez article-body `<pre>` blocks as prose so renderers can soft-wrap them.
///
/// SiteRule Metadata:
/// - Scope: antirez article prose preformatted body
/// - Phase: `serialization` cleanup
/// - Trigger: antirez document with top-level `article[data-comment-id] > pre` body block
/// - Evidence: `ex-pages/antirez-1`
/// - Risk if misplaced: code examples on unrelated pages could be mislabeled as prose
enum AntirezProsePreRule: SerializationSiteRule {
    static let id = "antirez-prose-pre"

    static func apply(to articleContent: Element) throws {
        guard let page = try serializedAntirezPage(in: articleContent) else {
            return
        }

        for article in try page.select("topcomment > article[data-comment-id][id]") {
            let preBlocks = article.children().array().filter { child in
                child.tagName().lowercased() == "pre"
            }

            guard preBlocks.count == 1, let pre = preBlocks.first else {
                continue
            }

            guard (try? pre.select("code").isEmpty()) != false else {
                continue
            }

            let text = AntirezExcerptRule.collectRawText(from: pre)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                continue
            }

            try pre.attr("data-readability-prose-pre", "true")
        }
    }

    private static func serializedAntirezPage(in articleContent: Element) throws -> Element? {
        let page: Element
        if articleContent.id() == "readability-page-1" {
            page = articleContent
        } else if let found = try articleContent.select("#readability-page-1").first() {
            page = found
        } else {
            return nil
        }

        guard let content = try page.select("> div#content").first() else {
            return nil
        }

        let hasNewsList = (try? content.select("> section#newslist > article[data-news-id]").isEmpty()) == false
        let hasTopComment = (try? content.select("> topcomment > article[data-comment-id][id] > pre").isEmpty()) == false
        guard hasNewsList && hasTopComment else {
            return nil
        }

        return page
    }
}