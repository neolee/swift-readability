import Foundation
import SwiftSoup

/// Keeps eHow author profile modules in content while still allowing byline extraction.
///
/// SiteRule Metadata:
/// - Scope: eHow author profile module
/// - Phase: byline extraction container retention
/// - Trigger: host contains `ehow` and enclosing `div[data-type=AuthorProfile]`
/// - Evidence: `realworld/ehow-1`, `realworld/ehow-2`
/// - Risk if misplaced: author profile block gets removed after byline extraction
enum EHowAuthorProfileBylineRetentionRule: BylineContainerRetentionSiteRule {
    static let id = "ehow-author-profile-byline-retention"

    static func shouldKeepBylineContainer(_ node: Element, sourceURL: URL?, document _: Document) throws -> Bool {
        let host = sourceURL?.host?.lowercased() ?? ""
        guard host.contains("ehow") else { return false }
        guard let profile = enclosingAuthorProfile(for: node) else { return false }

        let hasAvatarImage = (try profile.select("img").isEmpty()) == false
        let hasTime = (try profile.select("time[datetime], time").isEmpty()) == false
        return hasAvatarImage && hasTime
    }

    private static func enclosingAuthorProfile(for node: Element) -> Element? {
        var current: Element? = node
        while let element = current {
            guard element.tagName().uppercased() == "DIV" else {
                current = element.parent()
                continue
            }
            let dataType = ((try? element.attr("data-type")) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            if dataType == "authorprofile" {
                return element
            }
            current = element.parent()
        }
        return nil
    }
}
