import Foundation
import SwiftSoup

/// Restores empty article header placeholder for Firefox Nightly fixture parity.
///
/// SiteRule Metadata:
/// - Scope: Firefox Nightly article wrapper/header shape
/// - Phase: `serialization` cleanup
/// - Trigger: `div#content > div > article[id^=post-]` with Nightly marker links
/// - Evidence: `realworld/firefox-nightly-blog`
/// - Risk if misplaced: adds synthetic headers to unrelated WordPress posts
enum FirefoxNightlyHeaderPlaceholderRule: SerializationSiteRule {
    static let id = "firefox-nightly-header-placeholder"

    static func apply(to articleContent: Element) throws {
        for article in try articleContent.select("div#content > div > article[id^=post-]") {
            let hasNightlyMarkers = ((try? article.select("a[href*=\"bugzilla.mozilla.org\"], a[href*=\"blog.nightly.mozilla.org\"]").isEmpty()) == false)
            guard hasNightlyMarkers else { continue }
            let hasHeader = ((try? article.select("> header").isEmpty()) == false)
            guard !hasHeader else { continue }

            let doc = article.ownerDocument() ?? Document("")
            let header = try doc.createElement("header")
            if let first = article.getChildNodes().first {
                try first.before(header)
            } else {
                try article.appendChild(header)
            }
        }
    }
}
