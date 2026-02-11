import Foundation
import SwiftSoup

/// Removes WebMD reviewer attribution blocks that Mozilla fixtures exclude from article body.
///
/// SiteRule Metadata:
/// - Scope: WebMD reviewed-by module in article header
/// - Phase: `unwanted` cleanup
/// - Trigger: `.reviewedBy_fmt` and compact `div > p` blocks starting with "Reviewed by"
/// - Evidence: `realworld/webmd-1`, `realworld/webmd-2`
/// - Risk if misplaced: reviewer credit leaks ahead of first article paragraph
enum WebMDReviewedByRule: ArticleCleanerSiteRule {
    static let id = "webmd-reviewed-by"

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        try articleContent.select("div.author_fmt, [class*=author_fmt]").remove()
        try articleContent.select("div.reviewedBy_fmt, [class*=reviewedBy_fmt]").remove()
        try articleContent.select("div.slideshow_links_rdr, div.contextual_links_fmt").remove()

        for container in try articleContent.select("div").reversed() {
            guard container.parent() != nil else { continue }
            if (try? container.select("img, picture, figure, video, iframe, table, blockquote").isEmpty()) == false {
                continue
            }

            let text = (try? DOMHelpers.getInnerText(container))?
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard text.lowercased().hasPrefix("reviewed by ") else { continue }

            let links = (try? container.select("a[href*='webmd.com']").count) ?? 0
            guard links > 0 else { continue }

            // Keep this narrow to reviewer credit modules only.
            if text.count <= 240 {
                try container.remove()
            }
        }
    }
}
