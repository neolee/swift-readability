import Foundation
import SwiftSoup

/// Removes Telegraph-style figure shells that only contain caption/copyright text.
///
/// SiteRule Metadata:
/// - Scope: Telegraph caption-only figure shell cleanup during serialization
/// - Phase: `serialization` cleanup
/// - Trigger: `figure` without media but with `figcaption > span[itemprop=caption|copyrightHolder]`
/// - Evidence: `realworld/telegraph`
/// - Risk if misplaced: empty caption shells and surrounding empty wrappers leak into final HTML
enum TelegraphCaptionOnlyFigureRule: SerializationSiteRule {
    static let id = "telegraph-caption-only-figure"

    static func apply(to articleContent: Element) throws {
        var removedTelegraphCaptionFigure = false
        for figure in try articleContent.select("figure").reversed() {
            let hasMedia = (try? figure.select("img, picture, video, iframe, object, embed, svg").isEmpty()) == false
            if hasMedia {
                continue
            }
            let hasCaption = (try? figure.select("figcaption > span[itemprop=caption]").isEmpty()) == false
            let hasCopyrightHolder = (try? figure.select("figcaption > span[itemprop=copyrightHolder]").isEmpty()) == false
            if !hasCaption || !hasCopyrightHolder {
                continue
            }
            removedTelegraphCaptionFigure = true

            let previous = try? figure.previousElementSibling()
            let next = try? figure.nextElementSibling()
            let parent = figure.parent()
            try figure.remove()

            for sibling in [previous, next] {
                guard let paragraph = sibling,
                      paragraph.tagName().lowercased() == "p" else { continue }
                let text = ((try? DOMHelpers.getInnerText(paragraph)) ?? "")
                    .replacingOccurrences(of: "\u{00A0}", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if text.isEmpty {
                    try paragraph.remove()
                }
            }

            if let parent,
               parent.tagName().lowercased() == "div",
               DOMTraversal.isElementWithoutContent(parent) {
                try parent.remove()
            }

            for sibling in [previous?.parent(), next?.parent()] {
                guard let wrapper = sibling,
                      wrapper.tagName().lowercased() == "div" else { continue }
                let hasIdentity = !wrapper.id().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    !((try? wrapper.className()) ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                if hasIdentity {
                    continue
                }
                let children = wrapper.children().array()
                let allEmptyParagraphs = !children.isEmpty && children.allSatisfy { child in
                    guard child.tagName().lowercased() == "p" else { return false }
                    let text = ((try? DOMHelpers.getInnerText(child)) ?? "")
                        .replacingOccurrences(of: "\u{00A0}", with: " ")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    return text.isEmpty
                }
                if allEmptyParagraphs {
                    try wrapper.remove()
                }
            }
        }

        guard removedTelegraphCaptionFigure else { return }

        for div in try articleContent.select("div").reversed() {
            if div.id().hasPrefix("readability") {
                continue
            }
            let className = ((try? div.className()) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !className.isEmpty {
                continue
            }
            let children = div.children().array()
            let allEmptyParagraphs = !children.isEmpty && children.allSatisfy { child in
                guard child.tagName().lowercased() == "p" else { return false }
                let text = ((try? DOMHelpers.getInnerText(child)) ?? "")
                    .replacingOccurrences(of: "\u{00A0}", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return text.isEmpty
            }
            if allEmptyParagraphs {
                try div.remove()
            }
        }
    }
}
