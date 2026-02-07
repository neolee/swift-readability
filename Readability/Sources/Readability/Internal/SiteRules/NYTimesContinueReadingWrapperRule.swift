import Foundation
import SwiftSoup

/// Removes NYTimes collection rank wrappers that only contain "continue reading" jumps.
///
/// SiteRule Metadata:
/// - Scope: NYTimes mid-rank wrapper jump modules
/// - Phase: `unwanted` cleanup
/// - Trigger: `div[id$=-wrapper]` matching `mid\\d+-wrapper` plus `#after-mid` anchors/text
/// - Evidence: NYTimes real-world fixtures (`nytimes-2`/`nytimes-3`/`nytimes-4`/`nytimes-5`)
/// - Risk if misplaced: rank-navigation blocks leak into article content
enum NYTimesContinueReadingWrapperRule: ArticleCleanerSiteRule {
    static let id = "nytimes-continue-reading-wrapper"

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        for wrapper in try articleContent.select("div[id$=-wrapper]") {
            let id = wrapper.id().lowercased()
            guard id.range(of: "^mid\\d+-wrapper$", options: .regularExpression) != nil else { continue }
            let type = ((try? wrapper.attr("type")) ?? "").lowercased()
            let links = try wrapper.select("a[href^=#after-mid]")
            guard !links.isEmpty() else { continue }
            let text = ((try? DOMHelpers.getInnerText(wrapper)) ?? "")
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            if type == "rank" || text.contains("continue reading the main story") {
                try wrapper.remove()
            }
        }
    }
}
