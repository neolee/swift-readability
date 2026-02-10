import Foundation
import SwiftSoup

/// Keeps WebMD `author_fmt` node in the document so byline normalization can restore full multiline byline text.
///
/// SiteRule Metadata:
/// - Scope: WebMD author byline container retention
/// - Phase: byline container retention hook during extraction
/// - Trigger: `div.author_fmt` containing `a[rel=author]` + `WebMD Health News`
/// - Evidence: `realworld/webmd-1`, `realworld/webmd-2`
/// - Risk if misplaced: byline normalizer loses source whitespace/newline context
enum WebMDAuthorBylineRetentionRule: BylineContainerRetentionSiteRule {
    static let id = "webmd-author-byline-retention"

    static func shouldKeepBylineContainer(_ node: Element, sourceURL _: URL?, document _: Document) throws -> Bool {
        let className = ((try? node.className()) ?? "").lowercased()
        guard className.contains("author_fmt") else {
            return false
        }

        guard (try? node.select("a[rel=author]").isEmpty()) == false else {
            return false
        }

        let text = ((try? DOMHelpers.getInnerText(node)) ?? "").lowercased()
        return text.contains("webmd health news")
    }
}
