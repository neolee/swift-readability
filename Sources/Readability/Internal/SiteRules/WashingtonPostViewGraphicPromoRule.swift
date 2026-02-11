import Foundation
import SwiftSoup

/// Removes residual "View Graphic" promo blocks left by gallery embed extraction.
///
/// SiteRule Metadata:
/// - Scope: Washington Post residual "View Graphic" promo cards
/// - Phase: `unwanted` cleanup
/// - Trigger: `_graphic.html` link + image + text containing "view graphic"
/// - Evidence: `realworld/wapo-1`, `realworld/wapo-2`
/// - Risk if misplaced: promo cards remain in article body
enum WashingtonPostViewGraphicPromoRule: ArticleCleanerSiteRule {
    static let id = "washingtonpost-view-graphic-promo"

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        for candidate in try articleContent.select("div").reversed() {
            let hasGraphicLink = ((try? candidate.select("a[href*=_graphic.html]"))?.isEmpty()) == false
            let hasImage = ((try? candidate.select("img"))?.isEmpty()) == false
            guard hasGraphicLink && hasImage else { continue }
            let text = ((try? DOMHelpers.getInnerText(candidate)) ?? "")
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .lowercased()
            if text.contains("view graphic") {
                try candidate.remove()
            }
        }
    }
}
