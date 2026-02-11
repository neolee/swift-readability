import Foundation
import SwiftSoup

/// Restores missing Engadget breakout type metadata for hero image wrappers.
///
/// SiteRule Metadata:
/// - Scope: Engadget hero breakout wrappers
/// - Phase: `postProcess` cleanup
/// - Trigger: Engadget article markers + `div > figure > img` without `figcaption`
/// - Evidence: `realworld/engadget`
/// - Risk if misplaced: missing `data-engadget-breakout-type` attribute in output
enum EngadgetBreakoutTypeRule: ArticleCleanerSiteRule {
    static let id = "engadget-breakout-type"

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        let hasEngadgetMarkers = (try? articleContent.select("[data-engadget-slideshow-id], [data-eng-bang]").isEmpty()) == false
        guard hasEngadgetMarkers else { return }

        for wrapper in try articleContent.select("div") {
            if wrapper.hasAttr("data-engadget-breakout-type") {
                continue
            }
            let children = wrapper.children()
            guard children.count == 1, let figure = children.first() else { continue }
            guard figure.tagName().lowercased() == "figure" else { continue }

            let hasImage = (try? figure.select("img").isEmpty()) == false
            let hasCaption = (try? figure.select("figcaption").isEmpty()) == false
            guard hasImage, !hasCaption else { continue }
            try wrapper.attr("data-engadget-breakout-type", "e2ehero")
        }
    }
}
