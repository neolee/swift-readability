import Foundation
import SwiftSoup

/// Removes trailing tag/category badge lists from tomrenner.com article bodies.
///
/// tomrenner.com renders taxonomy tags as pill-shaped badges at the bottom of
/// `div.e-content`. These are microformats `p-category` metadata links (pointing
/// to `/tags/` URLs), not article content. Because they are direct children of
/// the article body container, standard extraction includes them.
///
/// The original `p-category` class and parent `e-content` class are stripped
/// during `cleanStyles`, so this rule uses structural signals instead:
/// - The `<ul>` is the last element sibling.
/// - Each `<li>` contains exactly one `<a>` with `/tags/` in its `href`.
/// - Each `<li>` has no text content beyond the link text itself.
///
/// SiteRule Metadata:
/// - Scope: tomrenner.com article tail tag badges
/// - Phase: `postProcess` cleanup
/// - Trigger: trailing `<ul>` whose items contain only `/tags/` links with no
///   extra text
/// - Evidence: `CLI/.staging/tomrenner`
/// - Risk if misplaced: tag badge pills remain in extracted article body
enum TomRennerTagListRule: ArticleCleanerSiteRule {
    static let id = "tomrenner-tag-list"

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        // Collect all <ul> elements. Process in reverse so removal does not
        // invalidate the remaining index positions.
        let uls = try articleContent.select("ul").array().reversed()
        for ul in uls {
            // Only consider the trailing-most <ul> — the tag list is always the
            // last child element of div.e-content. Guarding with
            // nextElementSibling() == nil prevents accidental removal of
            // mid-content <ul> elements.
            guard try ul.nextElementSibling() == nil else { continue }

            let items = ul.children().array()
            guard !items.isEmpty else { continue }
            guard items.allSatisfy({ $0.tagName().lowercased() == "li" }) else { continue }

            let allTagLinks = items.allSatisfy { li in
                let links = (try? li.select("a")) ?? Elements()
                guard links.count == 1 else { return false }
                guard let link = links.first() else { return false }

                let href = (try? link.attr("href")) ?? ""
                guard href.contains("/tags/") else { return false }

                // Extra-text guard: the <li> text must match the <a> text.
                // If there is additional prose outside the link, skip.
                let liText = (try? li.text())?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let linkText = (try? link.text())?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard liText == linkText else { return false }

                return true
            }
            guard allTagLinks else { continue }

            try ul.remove()
        }
    }
}
