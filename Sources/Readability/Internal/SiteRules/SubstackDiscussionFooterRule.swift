import Foundation
import SwiftSoup

/// Removes Substack discussion and subscription footer modules that can leak into extracted content.
///
/// SiteRule Metadata:
/// - Scope: Substack post tail discussion and subscribe modules
/// - Phase: `unwanted` cleanup
/// - Trigger: `div#discussion > div#substack-comments`, `Ready for more?` footer signup form,
///   and empty `Top Posts Footer` archive placeholder
/// - Evidence: `CLI/.staging/garymarcus-2`
/// - Risk if misplaced: community and signup chrome remain in article output
enum SubstackDiscussionFooterRule: ArticleCleanerSiteRule {
    static let id = "substack-discussion-footer"

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        try removeDiscussionModule(from: articleContent)
        try removeSubscribeFooter(from: articleContent)
        try removeEmptyTopPostsFooter(from: articleContent)
    }

    private static func removeDiscussionModule(from articleContent: Element) throws {
        for discussion in try articleContent.select("div#discussion").reversed() {
            let hasCommentsRoot = (try? discussion.select("div#substack-comments").isEmpty()) == false
            let hasMoreCommentsLink = (try? discussion.select("a.more-comments, a[href$=/comments]").isEmpty()) == false
            let headingText = ((try? discussion.select("h1, h2, h3, h4").first()?.text()) ?? "")
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            guard hasCommentsRoot || hasMoreCommentsLink || headingText == "discussion about this post" else {
                continue
            }

            try discussion.remove()
        }
    }

    private static func removeSubscribeFooter(from articleContent: Element) throws {
        for form in try articleContent.select("form[action*=\"/api/v1/free?nojs=true\"]").reversed() {
            let isSubscribeFooter = (try? form.select("input[name=source][value=subscribe_footer]").isEmpty()) == false
            guard isSubscribeFooter else { continue }

            var candidate: Element? = form.parent()
            while let current = candidate {
                let headingText = ((try? current.select("h1, h2, h3, h4").first()?.text()) ?? "")
                    .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                if headingText == "ready for more?" {
                    try current.remove()
                    break
                }
                candidate = current.parent()
            }
        }
    }

    private static func removeEmptyTopPostsFooter(from articleContent: Element) throws {
        for footer in try articleContent.select("div[aria-label=\"Top Posts Footer\"][role=\"region\"]").reversed() {
            let text = ((try? DOMHelpers.getInnerText(footer)) ?? "")
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            let hasEmptyArchiveMarker = (try? footer.select("p.portable-archive-empty").isEmpty()) == false
            let hasArchiveTabs = (try? footer.select("[aria-label=\"Archive sort tabs\"]").isEmpty()) == false

            guard text == "no posts" || hasEmptyArchiveMarker || hasArchiveTabs else {
                continue
            }

            try footer.remove()
        }
    }
}
