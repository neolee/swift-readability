import Foundation
import SwiftSoup

/// Removes Engadget slideshow icon chrome that appears as non-content SVG blocks.
///
/// SiteRule Metadata:
/// - Scope: Engadget slideshow icon wrappers
/// - Phase: `unwanted` cleanup
/// - Trigger: SVG `<use>` with `#icon-slideshow` reference
/// - Evidence: `realworld/engadget`
/// - Risk if misplaced: icon-only container drifts ahead of expected prose/rating block
enum EngadgetSlideshowIconRule: ArticleCleanerSiteRule {
    static let id = "engadget-slideshow-icon"

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        for thumbs in try articleContent.select("[data-engadget-slideshow-id] ul").reversed() {
            try thumbs.remove()
        }

        for badge in try articleContent.select("div:has(svg use)").reversed() {
            let use = try badge.select("svg use")
            let hasSlideshow = use.array().contains {
                (((try? $0.attr("xlink:href")) ?? "").lowercased() == "#icon-slideshow")
            }
            guard hasSlideshow else { continue }

            let text = ((try? DOMHelpers.getInnerText(badge)) ?? "")
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if text.range(of: "^[0-9]{1,3}$", options: .regularExpression) != nil {
                try badge.remove()
                continue
            }
        }

        for use in try articleContent.select("svg use").reversed() {
            let href = ((try? use.attr("xlink:href")) ?? "").lowercased()
            guard href == "#icon-slideshow" else { continue }
            if let svg = use.parent() {
                try svg.remove()
            }
        }

        for div in try articleContent.select("div").reversed() {
            guard div.parent() != nil else { continue }
            guard div.children().count == 1, let child = div.children().first else { continue }
            guard child.tagName().lowercased() == "p" else { continue }
            let text = ((try? DOMHelpers.getInnerText(child)) ?? "").lowercased()
            if text.contains("from"), text.contains("$") {
                try div.replaceWith(child)
            }
        }

    }
}
