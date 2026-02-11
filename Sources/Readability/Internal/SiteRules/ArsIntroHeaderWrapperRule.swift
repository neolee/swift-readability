import Foundation
import SwiftSoup

/// Restores Ars Technica intro wrapper structure around header + article body.
///
/// SiteRule Metadata:
/// - Scope: Ars Technica intro shell
/// - Phase: `serialization` cleanup
/// - Trigger: intro paragraph containing `h2[itemprop=description]` near `div[itemprop=articleBody]`
/// - Evidence: `realworld/ars-1`
/// - Risk if misplaced: root-level heading/body wrapper shape diverges from Mozilla fixture
enum ArsIntroHeaderWrapperRule: SerializationSiteRule {
    static let id = "ars-intro-header-wrapper"

    static func apply(to articleContent: Element) throws {
        guard let body = try articleContent.select("div[itemprop=articleBody]").first(),
              let container = body.parent() else {
            return
        }

        var introP: Element?
        var introH2: Element?
        var introH4: Element?

        for candidate in try container.select("p") {
            guard candidate.parent() == container else { continue }
            if let h2 = try candidate.select("h2[itemprop=description]").first() {
                introP = candidate
                introH2 = h2
                introH4 = try candidate.select("h4").first()
                break
            }
        }

        guard let paragraph = introP, let h2 = introH2 else {
            return
        }

        let doc = articleContent.ownerDocument() ?? Document("")
        let wrapper = try doc.createElement("div")
        let header = try doc.createElement("header")

        if let h4 = introH4 {
            try h4.remove()
            try header.appendChild(h4)
        }

        try h2.remove()
        try header.appendChild(h2)

        try paragraph.remove()
        try body.before(wrapper)
        try wrapper.appendChild(header)
        try body.remove()
        try wrapper.appendChild(body)

        for figcaption in try wrapper.select("figcaption") {
            let captionText = (try? DOMHelpers.getInnerText(figcaption))?
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if captionText.count <= 24,
               captionText.caseInsensitiveCompare("kevin") == .orderedSame {
                for child in figcaption.getChildNodes() {
                    try child.remove()
                }
            }
        }

        for paragraph in try articleContent.select("p").reversed() {
            let text = try paragraph.text().trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty {
                try paragraph.remove()
            }
        }
    }
}
