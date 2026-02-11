import Foundation
import SwiftSoup

/// Removes CNN legacy story-top wrappers and fixed in-read ad shell blocks.
///
/// SiteRule Metadata:
/// - Scope: CNN legacy top video wrapper and fixed in-read shell text block
/// - Phase: `unwanted` cleanup
/// - Trigger: `#js-ie-storytop` / `.ie--storytop` / `#ie_column` and exact ad shell text
/// - Evidence: `realworld/cnn`
/// - Risk if misplaced: non-article legacy chrome survives extraction
enum CNNLegacyStoryTopRule: ArticleCleanerSiteRule {
    static let id = "cnn-legacy-storytop"

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        // CNN legacy story-top video wrapper should be removed from article body.
        try articleContent.select("div#js-ie-storytop, div.ie--storytop, div#ie_column").remove()

        // In-read ad shell that Mozilla output drops in cnn real-world fixtures.
        for candidate in try articleContent.select("div").reversed() {
            let text = ((try? DOMHelpers.getInnerText(candidate)) ?? "")
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            if text == "advertising inread invented by teads" {
                try candidate.remove()
            }
        }
    }
}
