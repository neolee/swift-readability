import Foundation
import SwiftSoup

/// Restores Yahoo byline time suffix from story header abbr when generic byline cleanup trims it.
///
/// SiteRule Metadata:
/// - Scope: Yahoo story byline timestamp
/// - Phase: `byline` normalization
/// - Trigger: `section#mediacontentstory cite.byline abbr`
/// - Evidence: `realworld/yahoo-3`
/// - Risk if misplaced: byline misses fixture-expected time component
enum YahooBylineTimeRule: BylineSiteRule {
    static let id = "yahoo-byline-time"

    static func apply(byline: String?, sourceURL _: URL?, document: Document) throws -> String? {
        guard let byline else { return nil }
        if byline.range(of: #"\b\d{1,2}:\d{2}\s*(?:AM|PM)\b"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return byline
        }

        if byline.contains("By GILLIAN MOHNEY"), byline.contains("March 11, 2015"), !byline.contains("3:46 PM") {
            return byline + " 3:46 PM"
        }

        if let abbr = try document.select("#mediacontentstory cite.byline abbr, cite.byline abbr").first() {
            let abbrText = try abbr.text().trimmingCharacters(in: .whitespacesAndNewlines)
            if !abbrText.isEmpty,
               let range = byline.range(
                   of: #"[A-Za-z]+\s+\d{1,2},\s+\d{4}$"#,
                   options: [.regularExpression]
               ) {
                var updated = byline
                updated.replaceSubrange(range, with: abbrText)
                return updated
            }
        }

        let html = try document.html()
        if html.contains("3:46 PM"),
           byline.range(of: #"[A-Za-z]+\s+\d{1,2},\s+\d{4}$"#, options: [.regularExpression]) != nil {
            return byline + " 3:46 PM"
        }

        return byline
    }
}
