import Foundation
import SwiftSoup

/// Clears the false "About" byline on xkcd.com.
///
/// xkcd has `<a rel="author" href="/about">About</a>` in its top navigation.
/// Mozilla Readability treats `rel="author"` as a byline indicator and
/// extracts "About" as the author name, but this is a generic nav link,
/// not a real byline.
///
/// This rule clears the byline ONLY when it's "About" on xkcd.
/// If xkcd ever changes the link text to a real author name (e.g.
/// "Randall Munroe"), the rule stops matching and the byline will
/// be extracted normally.
///
/// Metadata:
/// - Scope: xkcd.com
/// - Phase: byline
/// - Trigger: byline == "About" on xkcd page
/// - Risk if misplaced: low (narrow match on text + site)
enum XkcdBylineRule: BylineSiteRule {
    static let id = "xkcd-byline"

    static func apply(byline currentByline: String?, sourceURL: URL?, document: Document) throws -> String? {
        guard let byline = currentByline?.trimmingCharacters(in: .whitespacesAndNewlines),
              byline.lowercased() == "about" else {
            return currentByline
        }

        // Verify we're on xkcd.
        let siteName = (try? document.select("meta[property=og:site_name]").first()?.attr("content")) ?? ""
        guard siteName.lowercased() == "xkcd" else { return currentByline }

        // The author link text is a nav label, not a person name.
        // If xkcd ever changes it to a real name, this guard won't trigger.
        return nil
    }
}
