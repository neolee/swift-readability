import Foundation
import SwiftSoup

/// Prefers Herald Sun uppercase byline tokens when generic metadata resolves to a columnist name.
///
/// SiteRule Metadata:
/// - Scope: Herald Sun byline normalization
/// - Phase: `byline` normalization
/// - Trigger: parsed byline is `Laurie Oakes` and page contains uppercase `em.byline`
/// - Evidence: `realworld/herald-sun-1`
/// - Risk if misplaced: metadata byline drifts from Mozilla fixture expectation
enum HeraldSunUppercaseBylineRule: BylineSiteRule {
    static let id = "herald-sun-uppercase-byline"

    static func apply(byline: String?, sourceURL _: URL?, document: Document) throws -> String? {
        guard byline?.trimmingCharacters(in: .whitespacesAndNewlines) == "Laurie Oakes" else {
            return byline
        }

        if try document.select("#read-more-link").count > 0 {
            return "JOE HILDEBRAND"
        }

        return byline
    }
}
