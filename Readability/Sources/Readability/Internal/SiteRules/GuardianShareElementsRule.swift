import Foundation
import SwiftSoup

/// Removes social-share UI containers while preserving article media wrappers.
///
/// SiteRule Metadata:
/// - Scope: Guardian share/social containers near article media
/// - Phase: `share` cleanup
/// - Trigger: class/id token match for `share`/`sharedaddy`, excluding media figures
/// - Evidence: `realworld/guardian-1`, `links-in-tables`, `bug-1255978`
/// - Risk if misplaced: over-removal of real figures or under-removal of share widgets
enum GuardianShareElementsRule: ArticleCleanerSiteRule {
    static let id = "guardian-share-elements"

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        // Match share/social controls, but avoid media figures such as
        // Guardian "fig--has-shares" article images.
        let candidates = try articleContent.select("[class*=share], [id*=share], [class*=sharedaddy], [id*=sharedaddy]")
        for node in candidates.reversed() {
            let identity = (
                (((try? node.className()) ?? "") + " " + node.id())
                    .lowercased()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            )

            let isShareControl = identity.range(
                of: "(^|\\s|[-_])(share|sharedaddy)(\\s|[-_]|$)",
                options: [.regularExpression]
            ) != nil
            if !isShareControl {
                continue
            }

            if node.tagName().lowercased() == "figure" {
                continue
            }

            let textLength = (try? DOMHelpers.getInnerText(node).count) ?? 0
            let paragraphCount = (try? node.select("p").count) ?? 0
            if textLength <= 1500 && paragraphCount <= 3 {
                try node.remove()
            }
        }
    }
}
