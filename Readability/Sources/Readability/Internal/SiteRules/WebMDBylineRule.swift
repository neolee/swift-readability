import Foundation
import SwiftSoup

/// Restores WebMD multiline byline from `author_fmt` block.
///
/// SiteRule Metadata:
/// - Scope: WebMD article author byline formatting
/// - Phase: `byline` normalization
/// - Trigger: `div.author_fmt` containing `a[rel=author]` and `WebMD Health News`
/// - Evidence: `realworld/webmd-1`, `realworld/webmd-2`
/// - Risk if misplaced: byline collapses to author-name-only metadata value
enum WebMDBylineRule: BylineSiteRule {
    static let id = "webmd-byline"

    static func apply(byline: String?, sourceURL: URL?, document: Document) throws -> String? {
        _ = sourceURL

        guard let authorContainer = try document.select("div.author_fmt").first(),
              let authorLink = try authorContainer.select("a[rel=author]").first()
        else {
            return byline
        }

        let author = (try? authorLink.html())?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !author.isEmpty else { return byline }

        let html = (try? authorContainer.html()) ?? ""
        guard html.localizedCaseInsensitiveContains("WebMD Health News") else {
            return byline
        }

        let pattern = #"</a>(\s*)<br\s*/?>([^<]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)),
              let spacingRange = Range(match.range(at: 1), in: html),
              let publicationRange = Range(match.range(at: 2), in: html)
        else {
            return byline
        }

        var spacing = String(html[spacingRange])
        if spacing.isEmpty || !spacing.contains("\n") {
            spacing = "\n"
        }

        let publication = String(html[publicationRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !publication.isEmpty else { return byline }

        return "By \(author)\(spacing)\(publication)"
    }
}
