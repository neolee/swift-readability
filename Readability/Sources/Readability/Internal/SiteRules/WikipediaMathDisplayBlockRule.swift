import Foundation
import SwiftSoup

/// Keeps Wikipedia display-math blocks wrapped as `div > p > img`, matching Mozilla output shape.
///
/// SiteRule Metadata:
/// - Scope: Wikimedia math display paragraphs
/// - Phase: `serialization` cleanup
/// - Trigger: article has many `/wiki/` links and display-math image paragraphs
/// - Evidence: `realworld/wikipedia-3`
/// - Risk if misplaced: low; guarded by wiki-link density and math-render image src
enum WikipediaMathDisplayBlockRule: SerializationSiteRule {
    static let id = "wikipedia-math-display-block"

    static func apply(to articleContent: Element) throws {
        let wikiLinkCount = (try? articleContent.select("a[href*='/wiki/']").count) ?? 0
        guard wikiLinkCount >= 20 else { return }

        let paragraphs = try articleContent.select("p")
        for paragraph in paragraphs {
            guard let parent = paragraph.parent() else { continue }

            let directMathImages = try paragraph.select("img[src*='/media/math/render/']").array().filter { image in
                image.parent() === paragraph
            }
            guard directMathImages.count == 1 else { continue }

            // Only wrap display formula lines that are image-only paragraphs.
            let hasElementChildExceptImg = paragraph.children().array().contains { $0.tagName().lowercased() != "img" }
            if hasElementChildExceptImg {
                continue
            }

            let text = ((try? paragraph.text()) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                continue
            }

            if parent.tagName().lowercased() == "div",
               parent.children().count == 1,
               parent.children().first() === paragraph {
                var attrCount = 0
                if let attributes = parent.getAttributes() {
                    for _ in attributes {
                        attrCount += 1
                    }
                }
                if parent.id().isEmpty,
                   ((try? parent.className()) ?? "").isEmpty,
                   attrCount == 0 {
                    continue
                }
            }

            let doc = paragraph.ownerDocument() ?? Document("")
            let wrapper = try doc.createElement("div")
            try paragraph.replaceWith(wrapper)
            try wrapper.appendChild(paragraph)
        }
    }
}
