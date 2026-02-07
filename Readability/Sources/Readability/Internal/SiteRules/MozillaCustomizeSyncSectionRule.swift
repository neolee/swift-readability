import Foundation
import SwiftSoup

/// Removes the trailing Firefox Sync promo section from Mozilla customize page.
///
/// Metadata:
/// - Scope: `mozilla-1` Firefox customize landing page
/// - Phase: `unwanted` cleanup
/// - Trigger: `#main-content > #sync.ga-section` with Sync-specific label/button
/// - Risk if misplaced: accidental removal of legitimate article sections named `sync`
struct MozillaCustomizeSyncSectionRule: ArticleCleanerSiteRule {
    static let id = "mozilla-customize-sync-section"

    static func apply(to articleContent: Element, context: ArticleCleanerSiteRuleContext) throws {
        guard let mainContent = try articleContent.select("#main-content").first() else { return }
        guard try mainContent.select("#intro, #customizers-wrapper").count >= 2 else { return }

        let syncSections = try mainContent.select("#sync.ga-section")
        for section in syncSections {
            let label = ((try? section.attr("data-ga-label")) ?? "").lowercased()
            let hasSyncButton = ((try? section.select("#sync-button").isEmpty()) == false)
            if label.contains("sync") || hasSyncButton {
                try section.remove()
            }
        }
    }
}
