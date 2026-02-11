import Foundation
import SwiftSoup

/// Removes ebb.org previous-post navigation block from extracted article content.
///
/// SiteRule Metadata:
/// - Scope: ebb blog previous link rail
/// - Phase: `postProcess` cleanup
/// - Trigger: `div#prevlink > a.previous` containing "Previous"
/// - Evidence: `realworld/ebb-org`
/// - Risk if misplaced: previous-post navigation leaks into article tail
enum EbbPreviousLinkRule: ArticleCleanerSiteRule {
    static let id = "ebb-previous-link"

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        for container in try articleContent.select("div#prevlink").reversed() {
            guard container.parent() != nil else { continue }

            let previousLink = try container.select("a").first()
            guard let previousLink else { continue }

            let linkText = (try? previousLink.text().lowercased()) ?? ""
            guard linkText.contains("previous") else { continue }

            try container.remove()
        }
    }
}
