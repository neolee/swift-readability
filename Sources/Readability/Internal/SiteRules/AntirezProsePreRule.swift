import Foundation
import SwiftSoup

/// Marks antirez article-body `<pre>` blocks as Markdown source for downstream renderers.
///
/// SiteRule Metadata:
/// - Scope: antirez article markdown preformatted body
/// - Phase: `serialization` cleanup
/// - Trigger: extracted `article[data-comment-id][id]` with matching `id`, trailing `-`, and a single top-level prose `<pre>` body
/// - Evidence: `ex-pages/antirez-*`
/// - Risk if misplaced: code examples on unrelated pages could be mislabeled as Markdown source
enum AntirezProsePreRule: SerializationSiteRule {
    static let id = "antirez-prose-pre"

    static func apply(to articleContent: Element) throws {
        for article in AntirezRuleHelpers.candidateArticleNodes(in: articleContent) {
            let commentID = ((try? article.attr("data-comment-id")) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let articleID = article.id().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !commentID.isEmpty,
                  commentID == articleID,
                  commentID.hasSuffix("-") else {
                continue
            }

            let preBlocks = article.children().array().filter { child in
                child.tagName().lowercased() == "pre"
            }

            guard preBlocks.count == 1, let pre = preBlocks.first else {
                continue
            }

            let topLevelElements = article.children().array()
            guard topLevelElements.count == 1, topLevelElements.first === pre else {
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

            try pre.attr("data-readability-pre-type", "markdown")
        }
    }
}
