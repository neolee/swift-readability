import Foundation
import SwiftSoup

/// Removes Folha inline gallery teaser blocks embedded inside article paragraphs.
///
/// SiteRule Metadata:
/// - Scope: Folha gallery teaser module
/// - Phase: `unwanted` cleanup
/// - Trigger: `figure.gallery-widget-pre` under article content
/// - Evidence: `realworld/folha`
/// - Risk if misplaced: gallery promo block interrupts paragraph flow
enum FolhaGalleryWidgetRule: ArticleCleanerSiteRule {
    static let id = "folha-gallery-widget"

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        for teaser in try articleContent.select("figure.gallery-widget-pre").array() {
            // Prefer removing the smallest wrapper that contains the teaser module.
            if let moduleRoot = teaser.parents().first(where: { parent in
                parent.hasClass("js-gallery-widget")
            }) {
                if let wrapper = moduleRoot.parent(), wrapper.tagName().lowercased() == "div" {
                    try wrapper.remove()
                    continue
                }
                try moduleRoot.remove()
                continue
            }
            try teaser.remove()
        }
    }
}
