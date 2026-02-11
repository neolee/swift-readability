import Foundation
import SwiftSoup

/// Removes Engadget commerce CTA buy-link blocks from extracted article content.
///
/// SiteRule Metadata:
/// - Scope: Engadget buy-link CTA buttons
/// - Phase: `postProcess` cleanup
/// - Trigger: review-module CTA anchor with `href` containing `/buylink/`
/// - Evidence: `realworld/engadget`
/// - Risk if misplaced: buy-link CTA can be retained ahead of rating/prose blocks
enum EngadgetBuyLinkRule: ArticleCleanerSiteRule {
    static let id = "engadget-buy-link"

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        // Run in post-process phase to avoid affecting earlier structural pruning.
        for link in try articleContent.select("a[href*=/buylink/]").reversed() {
            try link.remove()
        }
    }
}
