import Foundation
import SwiftSoup

/// Removes the leading site chrome from fabiensanglard.net article bodies.
///
/// fabiensanglard.net pages have a flat HTML structure with no semantic
/// container. The site banner (`<center>`), publication date, article title
/// (`<div class="heading">`), and a separator `<hr>` appear as direct children
/// before the actual article content. Standard extraction includes them
/// because they are structurally indistinguishable from body paragraphs.
///
/// This rule runs in `.unwantedElements` phase (before `cleanStyles`).
/// `ownerDocument()` is not available (the extracted article is detached),
/// so site fingerprinting relies entirely on structural signals within the
/// article content itself.
///
/// Strategy:
/// 1. Site fingerprint: leading `<center>` containing an `<a href="/">` whose
///    text matches "FABIEN SANGLARD".
/// 2. Remove leading `<br>` nodes and the `<center>` banner.
/// 3. Find the first `<hr>` — it separates the heading chrome from content.
///    Remove the `<hr>` and all preceding siblings (the date and title `<p>`
///    elements that prepDocument normalized from `<div>`).
///
/// SiteRule Metadata:
/// - Scope: fabiensanglard.net leading page chrome
/// - Phase: `unwantedElements` cleanup
/// - Trigger: "FABIEN SANGLARD" banner + separator `<hr>`
/// - Evidence: `CLI/.staging/fabiensanglard`
/// - Risk if misplaced: date and title remain in extracted body
enum FabienSanglardLeadingChromeRule: ArticleCleanerSiteRule {
    static let id = "fabiensanglard-leading-chrome"

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        // Site fingerprint: leading <center> with "FABIEN SANGLARD" banner link.
        guard let center = try articleContent.select("> center").first() else { return }
        let bannerLink = try center.select("a[href='/']").first()
        let bannerText = (try? bannerLink?.text()) ?? ""
        guard bannerText.range(of: "FABIEN SANGLARD", options: .caseInsensitive) != nil else {
            return
        }

        // Remove leading <br> nodes
        while let firstChild = articleContent.children().first() {
            if firstChild.nodeName().lowercased() == "br" {
                try firstChild.remove()
            } else {
                break
            }
        }

        // Remove the <center> banner
        try center.remove()

        // Remove any trailing <br> nodes after the center
        while let firstChild = articleContent.children().first() {
            if firstChild.nodeName().lowercased() == "br" {
                try firstChild.remove()
            } else {
                break
            }
        }

        // Find the first <hr> — it separates the heading chrome from content.
        // Remove it and everything before it (date <p>, title <p>, any empty
        // <p> artifacts from prepDocument).
        guard let firstHR = try articleContent.select("> hr").first() else { return }

        // Remove all preceding siblings of the <hr>
        while let firstChild = articleContent.children().first() {
            if firstChild === firstHR { break }
            try firstChild.remove()
        }

        // Remove the <hr> itself
        try firstHR.remove()
    }
}
