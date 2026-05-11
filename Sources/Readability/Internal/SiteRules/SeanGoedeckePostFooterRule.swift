import Foundation
import SwiftSoup

/// Rejects the orphaned related-post preview intro paragraph that survives sibling
/// merge when the surrounding subscription prompt and preview card are already
/// excluded by other scoring/cleanup gates.
///
/// seangoedecke.com posts end with a subscription prompt followed by a preview of a
/// tag-related post. The subscription `<p>` is rejected during sibling merge (link
/// density), and the preview `<blockquote>` is skipped (score below threshold), but
/// the short intro `<p>` is appended as `paragraph-short-terminal-period`. This rule
/// rejects it so the extracted article ends cleanly after the article body and
/// footnotes.
///
/// SiteRule Metadata:
/// - Scope: seangoedecke.com post-footer promotion tail
/// - Phase: sibling inclusion
/// - Trigger: `<p>` whose normalized text is the exact related-post preview intro
///   "Here's a preview of a related post that shares tags with this one.", with
///   adjacent evidence from the same post-footer pattern.
/// - Evidence: `CLI/.staging/seangoedecke`
/// - Risk if misplaced: a genuinely short terminal paragraph on another site could
///   be rejected; gated by exact text match plus adjacent sibling evidence
enum SeanGoedeckePostFooterRule: SiblingInclusionSiteRule {
    static let id = "seangoedecke-post-footer"

    private static let previewIntroText = "Here's a preview of a related post that shares tags with this one."

    static func shouldIncludeSibling(_ sibling: Element, topCandidate: Element) throws -> Bool? {
        // Only handle <p> elements
        guard sibling.tagName().lowercased() == "p" else { return nil }

        // Check for exact preview intro text
        let siblingText = (try DOMHelpers.getInnerText(sibling))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard siblingText == previewIntroText else { return nil }

        // Confirm adjacent sibling evidence from the same post-footer pattern:
        // either a previous sibling contains "If you liked this post"
        // or the next sibling is the related-post <blockquote>
        let hasAdjacentEvidence = hasPostFooterNeighbor(sibling)
        guard hasAdjacentEvidence else { return nil }

        return false
    }

    private static func hasPostFooterNeighbor(_ sibling: Element) -> Bool {
        guard let parent = sibling.parent() else { return false }

        let children = parent.children().array()

        // Find our position among siblings
        guard let index = children.firstIndex(where: { $0 === sibling }) else {
            return false
        }

        // Check previous sibling for subscription prompt
        if index > 0 {
            let prevText = (try? DOMHelpers.getInnerText(children[index - 1])) ?? ""
            if prevText.localizedCaseInsensitiveContains("If you liked this post") {
                return true
            }
        }

        // Check next sibling for related-post blockquote
        if index + 1 < children.count {
            let next = children[index + 1]
            if next.tagName().lowercased() == "blockquote",
               let blockquoteText = try? DOMHelpers.getInnerText(next),
               blockquoteText.localizedCaseInsensitiveContains("Continue reading") {
                return true
            }
        }

        return false
    }
}
