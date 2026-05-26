import Foundation
import SwiftSoup

/// Rejects Ghost CMS article chrome siblings that would otherwise be merged
/// alongside the selected content candidate due to scoring just above the
/// sibling merge threshold.
///
/// Ghost article pages commonly wrap the body content (`section.gh-content`)
/// together with a metadata header (`header.article-header`) and a footer
/// promotional CTA (`div.content-cta`) inside a shared `<article>` parent.
/// The header and CTA frequently score above the sibling merge threshold
/// (`topCandidate.score × 0.2`) and leak into extracted content.
///
/// This rule uses the same shared gating for both rejected siblings:
/// - The top candidate must be `section.gh-content`.
/// - Both the sibling and top candidate must be direct children of the same
///   `<article>` parent.
///
/// Evidence:
/// - `CLI/.staging/joanwestenberg` (Ghost CMS v6.41)
///
/// Upgrade path: if more Ghost CMS blogs exhibit the same pattern, add
/// additional fixture references here rather than creating host-specific
/// duplicates.
enum GhostArticleChromeRule: SiblingInclusionSiteRule {
    static let id = "ghost-article-chrome"

    static func shouldIncludeSibling(_ sibling: Element, topCandidate: Element) throws -> Bool? {
        // Shared gating: top candidate must be section.gh-content
        guard topCandidate.tagName().lowercased() == "section",
              topCandidate.hasClass("gh-content") else {
            return nil
        }

        // Shared gating: both must share the same <article> parent
        guard let candidateParent = topCandidate.parent(),
              candidateParent.tagName().lowercased() == "article",
              let siblingParent = sibling.parent(),
              siblingParent === candidateParent else {
            return nil
        }

        // Reject header.article-header (date/author metadata chrome)
        if sibling.tagName().lowercased() == "header",
           sibling.hasClass("article-header") {
            return false
        }

        // Reject div.content-cta / div.studio-cta (footer promotional CTA)
        if sibling.tagName().lowercased() == "div",
           (sibling.hasClass("content-cta") || sibling.hasClass("studio-cta")) {
            return false
        }

        // Defer all other siblings to default scoring logic
        return nil
    }
}
