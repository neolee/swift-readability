import Foundation
import SwiftSoup

/// Restores Breitbart lead media/timestamp block while keeping entry body as a sibling block.
///
/// SiteRule Metadata:
/// - Scope: Breitbart article header normalization
/// - Phase: `serialization` cleanup
/// - Trigger: `article#post-*` with `header figure.figurearticlefeatured` + `div.entry-content`
/// - Evidence: `realworld/breitbart`
/// - Risk if misplaced: rewraps generic article/header layouts incorrectly
enum BreitbartHeaderMediaRule: SerializationSiteRule {
    static let id = "breitbart-header-media"

    static func apply(to articleContent: Element) throws {
        guard let article = try articleContent.select("article[id^=post-]").first() else {
            return
        }
        guard let header = try article.select("> header").first(),
              let featuredFigure = try header.select("figure").first() else {
            return
        }

        guard let entryContent = article.children().array().first(where: { child in
            guard child.tagName().lowercased() == "div" else { return false }
            let paragraphCount = (try? child.select("p").count) ?? 0
            return paragraphCount >= 3
        }) else {
            return
        }

        let doc = articleContent.ownerDocument() ?? Document("")
        let leadBlock = try doc.createElement("div")
        let bodyBlock = try DOMHelpers.cloneElement(entryContent, in: doc)
        let figureClone = try DOMHelpers.cloneElement(featuredFigure, in: doc)
        try normalizeFigureStructure(figureClone, in: doc)
        try leadBlock.appendChild(figureClone)

        for timestamp in try header.select("time[datetime]") {
            let timeClone = try DOMHelpers.cloneElement(timestamp, in: doc)
            try leadBlock.appendChild(timeClone)
        }

        try article.before(leadBlock)
        try article.before(bodyBlock)
        try article.remove()
    }

    private static func normalizeFigureStructure(_ figure: Element, in doc: Document) throws {
        guard let container = try figure.select("> div").first() else { return }

        if let img = try container.select("> img").first() {
            let imageParagraph = try doc.createElement("p")
            try img.remove()
            try imageParagraph.appendChild(img)
            try container.prependChild(imageParagraph)
        }

        if let attribution = try container.select("> div.attribution").first() {
            let attributionText = ((try? attribution.text()) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let attributionParagraph = try doc.createElement("p")
            if !attributionText.isEmpty {
                try attributionParagraph.text(attributionText)
            }
            try attribution.replaceWith(attributionParagraph)
        }
    }
}
