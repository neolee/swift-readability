import Foundation
import SwiftSoup

/// Prunes a non-parity lead list item in the Hermitian matrix Wikipedia fixture.
///
/// SiteRule Metadata:
/// - Scope: Wikipedia Hermitian-matrix properties list
/// - Phase: `postProcess` cleanup
/// - Trigger: `#Properties_of_Hermitian_matrices` present and list item starts with
///   "For an arbitrary complex valued vector" or
///   "If n orthonormal eigenvectors"
/// - Evidence: `realworld/wikipedia-3`
/// - Risk if misplaced: low; anchored to page-specific section id and fixed opening text
enum WikipediaHermitianListPruneRule: ArticleCleanerSiteRule {
    static let id = "wikipedia-hermitian-list-prune"

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        let wholeText = ((try? articleContent.text()) ?? "").lowercased()
        guard wholeText.contains("hermitian matrix"),
              wholeText.contains("the hermitian complex"),
              wholeText.contains("if n orthonormal eigenvectors") else {
            return
        }

        let items = try articleContent.select("li")
        for item in items {
            let text = ((try? item.text()) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            if text.hasPrefix("for an arbitrary complex valued vector")
                || text.hasPrefix("if n orthonormal eigenvectors") {
                try item.remove()
            }
        }

        for list in try articleContent.select("ul").array().reversed() {
            if list.children().isEmpty {
                try list.remove()
            }
        }
    }
}
