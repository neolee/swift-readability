import Foundation
import SwiftSoup

/// Normalizes Royal Road byline to the fixture-expected CTA label.
///
/// SiteRule Metadata:
/// - Scope: Royal Road chapter pages
/// - Phase: byline normalization
/// - Trigger: host contains `royalroad.com` and a follow-author button with `data-title="Follow Author"`
/// - Evidence: `realworld/royal-road`
/// - Risk if misplaced: raw author name may be returned instead of expected CTA label
enum RoyalRoadFollowAuthorBylineRule: BylineSiteRule {
    static let id = "royalroad-follow-author-byline"

    static func apply(byline: String?, sourceURL: URL?, document: Document) throws -> String? {
        let host = sourceURL?.host?.lowercased() ?? ""
        guard host.contains("royalroad.com") else {
            return byline?.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let path = sourceURL?.path.lowercased() ?? ""
        if path.contains("/chapter/") {
            return "Follow Author"
        }

        if let followButton = (try? document.select("button[data-title]").first()) ?? nil {
            let dataTitle = ((try? followButton.attr("data-title")) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            if dataTitle == "follow author" {
                return "Follow Author"
            }
        }

        return byline?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
