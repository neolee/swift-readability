import Foundation
import SwiftSoup

/// Ensures the content candidate on Microsoft DevBlogs pages is always
/// `div#single-wrapper`, the theme's designated article content container.
///
/// The generic promotion algorithm may select `div.container-evo` (the full
/// page wrapper) when the top candidate's score is low enough that the
/// container-evo parent crosses the dynamic threshold. On devblogs-evo pages
/// the correct content container is always `#single-wrapper`, which wraps
/// the `<article>` element directly.
///
/// This rule handles two shapes:
/// - **Candidate is inside `#single-wrapper`** (e.g. `div.entry-content`):
///   walks up the ancestor chain to find `#single-wrapper`.
/// - **`#single-wrapper` is inside the candidate** (e.g. `div.container-evo`):
///   narrows down to the `#single-wrapper` descendant.
///
/// Works in concert with `DevBlogsPostFooterRule`, which excludes the
/// post-footer sibling that follows `#single-wrapper` during sibling merge.
///
/// Evidence:
/// - `CLI/.staging/raymondchen-1` (candidate inside `#single-wrapper`)
/// - `CLI/.staging/raymondchen-2` (candidate containing `#single-wrapper`)
/// - `CLI/.staging/raymondchen-3` (same as raymondchen-2)
enum DevBlogsArticleCandidateRule: CandidatePromotionSiteRule {
    static let id = "devblogs-article-candidate"

    static func promotedCandidate(from candidate: Element) -> Element? {
        guard let document = candidate.ownerDocument(),
              isDevBlogsEvoDocument(document) else {
            return nil
        }

        // If `#single-wrapper` is a descendant of the candidate, narrow to it.
        if let wrapper = try? candidate.select("#single-wrapper").first() {
            return wrapper
        }

        // Walk up from the candidate; if `#single-wrapper` is an ancestor, return it.
        var cursor: Element? = candidate
        while let current = cursor {
            if current.id() == "single-wrapper" {
                return current
            }
            cursor = current.parent()
        }

        return nil
    }

    private static func isDevBlogsEvoDocument(_ document: Document) -> Bool {
        if ((try? document.select("body.wp-theme-devblogs-evo").isEmpty()) == false) {
            return true
        }
        let urlSignals = [
            (try? document.select("link[rel=canonical]").first()?.attr("href")) ?? "",
            (try? document.select("meta[property=og:url]").first()?.attr("content")) ?? ""
        ]
        return urlSignals.contains { $0.lowercased().contains("devblogs.microsoft.com") }
    }
}
