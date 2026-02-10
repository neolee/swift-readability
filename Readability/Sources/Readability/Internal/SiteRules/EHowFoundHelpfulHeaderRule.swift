import Foundation
import SwiftSoup

/// Restores eHow "Found This Helpful" helper block wrapper parity.
///
/// SiteRule Metadata:
/// - Scope: eHow top helper header module
/// - Phase: `serialization` cleanup
/// - Trigger: `header > p` text containing `Found This Helpful`
/// - Evidence: `realworld/ehow-1`
/// - Risk if misplaced: generic header paragraphs could be wrapped unexpectedly
enum EHowFoundHelpfulHeaderRule: SerializationSiteRule {
    static let id = "ehow-found-helpful-header"

    static func apply(to articleContent: Element) throws {
        try EHowRuleHelpers.removeLegacyHeadlineSiblings(in: articleContent)

        for header in try articleContent.select("header") {
            let children = header.children()
            guard children.count == 1,
                  let onlyChild = children.first,
                  onlyChild.tagName().lowercased() == "p" else {
                continue
            }

            let normalizedText = ((try? DOMHelpers.getInnerText(onlyChild)) ?? "")
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            guard normalizedText.contains("found this helpful") else { continue }

            let doc = articleContent.ownerDocument() ?? Document("")
            let wrapper = try doc.createElement("div")
            try onlyChild.remove()
            try wrapper.appendChild(onlyChild)
            try header.appendChild(wrapper)
        }
    }
}
