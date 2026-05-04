import Foundation
import SwiftSoup

/// Removes non-content footer elements from xkcd.com serialized output.
///
/// xkcd.com keeps site-wide footer content inside `#bottom.box`:
/// - `#comicLinks` -- "Comics I enjoy" and "Other things" link collections
/// - `<center>` / `#footnote` -- humorous browser disclaimer
/// - Earth temperature timeline link -- public-service banner on every page
///
/// These are site chrome, not comic content. The actual comic lives in
/// `#middleContainer` but Readability's text-based scoring selects `#bottom`
/// because comics are image-heavy and footer text scores higher.
///
/// This rule runs in the serialization phase (after textContent is computed)
/// so that removing these text-only elements does not cause the article to
/// fail the minimum-content-length check.
///
/// Metadata:
/// - Scope: xkcd.com
/// - Phase: serialization
/// - Trigger: `#bottom.box` containing `#comicLinks` on an xkcd.com page
/// - Risk if misplaced: low (selectors are narrowly scoped to xkcd structure)
struct XkcdFooterCleanupRule: SerializationSiteRule {
    static let id = "xkcd-footer-cleanup"

    static func apply(to articleContent: Element) throws {
        // Guard: only apply when the serialized content contains the
        // xkcd-specific #comicLinks nav section inside #bottom.box.
        guard ((try? articleContent.select("#bottom.box").isEmpty()) == false) else { return }
        guard ((try? articleContent.select("#comicLinks").isEmpty()) == false) else { return }

        // Remove all #comicLinks divs (both "Comics I enjoy" and "Other things").
        for comicLinks in try articleContent.select("#comicLinks") {
            try comicLinks.remove()
        }

        // Remove the <center> element containing the browser disclaimer.
        for center in try articleContent.select("center") {
            // On xkcd, the only <center> inside #bottom is the footnote.
            try center.remove()
        }

        // Remove the Earth temperature timeline public-service banner.
        for img in try articleContent.select("img[alt='Earth temperature timeline']") {
            var parent: Element? = img
            // Walk up to the nearest <p> wrapper and remove it entirely.
            while let node = parent {
                if node.tagName().lowercased() == "p" {
                    try node.remove()
                    break
                }
                parent = node.parent()
            }
        }
    }
}
