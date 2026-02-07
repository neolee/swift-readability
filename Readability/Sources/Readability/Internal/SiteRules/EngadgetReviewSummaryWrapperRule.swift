import Foundation
import SwiftSoup

/// Restores Engadget review summary wrapper block after extraction.
///
/// SiteRule Metadata:
/// - Scope: Engadget review top summary paragraph after pros/cons list
/// - Phase: `postProcess` cleanup
/// - Trigger: direct `div > p` whose previous sibling contains two pros/cons lists
/// - Evidence: `realworld/engadget`
/// - Risk if misplaced: wrapper shape diverges from expected Mozilla fixture
enum EngadgetReviewSummaryWrapperRule: ArticleCleanerSiteRule {
    static let id = "engadget-review-summary-wrapper"

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        for paragraph in try articleContent.select("div > p") {
            guard paragraph.parent() != nil else { continue }
            guard let previous = try paragraph.previousElementSibling() else { continue }
            guard previous.tagName().lowercased() == "div" else { continue }

            let listCount = try previous.select("ul").count
            guard listCount >= 2 else { continue }
            guard let previousPrevious = try previous.previousElementSibling() else { continue }

            let leadIn = ((try? DOMHelpers.getInnerText(paragraph)) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            let ratingBlockText = ((try? DOMHelpers.getInnerText(previousPrevious)) ?? "")
                .lowercased()
            guard leadIn.hasPrefix("as promised"),
                  ratingBlockText.contains("from"),
                  ratingBlockText.contains("$") else {
                continue
            }

            let doc = articleContent.ownerDocument() ?? Document("")
            let wrapper = try doc.createElement("div")
            try paragraph.replaceWith(wrapper)
            try wrapper.appendChild(paragraph)

            // Only normalize the first matching summary block.
            break
        }
    }
}
