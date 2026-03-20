import Foundation
import SwiftSoup

/// Restores antirez post author from the leading inline metadata block when metadata is absent.
///
/// SiteRule Metadata:
/// - Scope: antirez article header metadata
/// - Phase: `metadata byline` fallback
/// - Trigger: `article.comment > span.info` with `span.username > a[href^='/user/']` and sibling `<pre>` body
/// - Evidence: `ex-pages/antirez-*`
/// - Risk if misplaced: username-only blocks from unrelated pages could be misread as author byline
enum AntirezBylineRule: MetadataBylineSiteRule {
    static let id = "antirez-byline"

    static func apply(currentByline: String?, sourceURL: URL?, document: Document) throws -> String? {
        if let currentByline,
           !currentByline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return currentByline
        }

        guard AntirezRuleHelpers.isAntirezDocument(document, sourceURL: sourceURL) else {
            return currentByline
        }

        return try AntirezRuleHelpers.extractedAuthor(in: document) ?? currentByline
    }
}
