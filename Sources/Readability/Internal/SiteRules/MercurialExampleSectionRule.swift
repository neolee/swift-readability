import Foundation
import SwiftSoup

/// Drops Mercurial's first amend walkthrough section to match Mozilla extraction parity.
///
/// SiteRule Metadata:
/// - Scope: mercurial-scm.org evolve shared-mutable-history article
/// - Phase: `postProcess` cleanup
/// - Trigger: `#evolve-shared-mutable-history` root with `#example-1-amend-a-shared-changeset`
/// - Evidence: `realworld/mercurial`
/// - Risk if misplaced: low; gated by stable article root id
enum MercurialExampleSectionRule: ArticleCleanerSiteRule {
    static let id = "mercurial-example-1-section"

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        guard (try? articleContent.select("#evolve-shared-mutable-history").isEmpty()) == false else {
            return
        }

        try articleContent.select("#example-1-amend-a-shared-changeset").remove()
    }
}
