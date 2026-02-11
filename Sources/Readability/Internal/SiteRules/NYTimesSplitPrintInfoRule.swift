import Foundation
import SwiftSoup

/// Merges split NYTimes print-info paragraph fragments to match Mozilla output.
///
/// SiteRule Metadata:
/// - Scope: NYTimes print-info tail block normalization
/// - Phase: `postParagraph` cleanup
/// - Trigger: container text containing "a version of this article appears in print on"
/// - Evidence: NYTimes real-world fixtures (`nytimes-1`, `nytimes-2`)
/// - Risk if misplaced: fragmented print-info paragraphs remain split in output
enum NYTimesSplitPrintInfoRule: ArticleCleanerSiteRule {
    static let id = "nytimes-split-print-info"

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        let candidates = try articleContent.select("div > div")
        for container in candidates.reversed() {
            guard container.parent() != nil else { continue }
            let text = try DOMHelpers.getInnerText(container).lowercased()
            guard text.contains("a version of this article appears in print on") else { continue }

            let paragraphs = container.children().array().filter { $0.tagName().lowercased() == "p" }
            guard paragraphs.count >= 3 else { continue }

            let doc = container.ownerDocument() ?? Document("")
            let merged = try doc.createElement("p")

            for paragraph in paragraphs {
                while let first = paragraph.getChildNodes().first {
                    try merged.appendChild(first)
                }
                try paragraph.remove()
            }

            if let firstChild = container.getChildNodes().first {
                try firstChild.before(merged)
            } else {
                try container.appendChild(merged)
            }
        }
    }
}
