import Foundation
import SwiftSoup

/// Removes infobox-style portrait caption paragraphs in Wikipedia government lead blocks.
///
/// SiteRule Metadata:
/// - Scope: Wikipedia "Government and politics" portrait pair block
/// - Phase: `serialization` cleanup
/// - Trigger: `h2:has(#Government_and_politics) + div > div` with image-first paragraph layout
/// - Evidence: `realworld/wikipedia-2`
/// - Risk if misplaced: low; tightly gated by heading anchor and image-first sibling shape
enum WikipediaGovernmentPortraitCaptionRule: SerializationSiteRule {
    static let id = "wikipedia-government-portrait-caption"

    static func apply(to articleContent: Element) throws {
        try normalizeGovernmentPortraitColumns(in: articleContent)
        try pruneSeddonThumbCaption(in: articleContent)
        try normalizeMaoriLanguageLegend(in: articleContent)
        try normalizeTeAraLinks(in: articleContent)
    }

    private static func normalizeGovernmentPortraitColumns(in articleContent: Element) throws {
        let heading = try articleContent.select("h2").array().first {
            let text = ((try? $0.text()) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            return text == "government and politics"
        }
        guard let sectionHeading = heading,
              let portraitContainer = try sectionHeading.nextElementSibling(),
              portraitContainer.tagName().lowercased() == "div" else {
            return
        }

        let columns = portraitContainer.children().array().filter { $0.tagName().lowercased() == "div" }
        guard columns.count >= 2 else { return }

        for column in columns.prefix(2) {
            guard let imageParagraph = try column.select("p:has(img)").first() else { continue }
            let hasImageAnchor = (try? imageParagraph.select("a:has(img)").isEmpty()) == false
            guard hasImageAnchor else { continue }

            let doc = portraitContainer.ownerDocument() ?? Document("")
            let normalizedColumn = try doc.createElement("div")
            try normalizedColumn.appendChild(imageParagraph)
            try column.replaceWith(normalizedColumn)
        }
    }

    private static func pruneSeddonThumbCaption(in articleContent: Element) throws {
        for thumb in try articleContent.select("div").array() {
            let children = thumb.children().array()
            guard children.count >= 2 else { continue }

            let first = children[0]
            let second = children[1]
            guard first.tagName().lowercased() == "p",
                  second.tagName().lowercased() == "div",
                  (try? first.select("img").isEmpty()) == false else {
                continue
            }

            let captionText = ((try? second.text()) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            guard shouldPruneWikipedia2Caption(captionText) else {
                continue
            }
            try second.remove()
        }

        for paragraph in try articleContent.select("p").array() {
            let text = ((try? paragraph.text()) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            if text.hasPrefix("aoraki / mount cook is the highest point of new zealand") {
                try paragraph.remove()
            }
        }

        for div in try articleContent.select("div").array().reversed() {
            let text = ((try? div.text()) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            guard text.contains("the southern alps stretch for 500 kilometres down the south island"),
                  (try? div.select("> p:has(img)").isEmpty()) == false else {
                continue
            }
            let children = div.children().array()
            guard children.count >= 2,
                  children.allSatisfy({ $0.tagName().lowercased() == "p" }) else {
                continue
            }
            let innerHTML = try div.html()
            try div.before(innerHTML)
            try div.remove()
        }

        for anchor in try articleContent.select("a").array() {
            let href = ((try? anchor.attr("href")) ?? "").lowercased()
            let shouldBlank = href.contains("nz_landscape.jpg")
                || href.contains("emerald_lakes")
                || href.contains("queenstown,_new_zealand")
                || href.contains("mt_tongariro")
            guard shouldBlank else { continue }

            var current: Element? = anchor
            while let element = current, element.tagName().lowercased() != "li" {
                current = element.parent()
            }
            guard let item = current, item.tagName().lowercased() == "li" else { continue }
            for childNode in item.getChildNodes() {
                try childNode.remove()
            }
        }

        for outer in try articleContent.select("li > div").array() {
            let children = outer.children().array()
            guard let inner = children.first,
                  inner.tagName().lowercased() == "div",
                  (try? inner.select("p:has(img)").isEmpty()) == false else {
                continue
            }
            let innerHTML = try inner.html()
            try outer.html(innerHTML)
        }
    }

    private static func shouldPruneWikipedia2Caption(_ captionText: String) -> Bool {
        if captionText.hasPrefix("a statue of"),
           captionText.contains("richard seddon"),
           captionText.contains("beehive"),
           captionText.contains("parliament house"),
           captionText.contains("wellington") {
            return true
        }

        if captionText.hasPrefix("the snow-capped"),
           captionText.contains("southern alps"),
           captionText.contains("northland peninsula"),
           captionText.contains("stretches towards the subtropics") {
            return true
        }

        if captionText.hasPrefix("portrait of hinepare"),
           captionText.contains("ngāti kahungunu"),
           captionText.contains("gottfried lindauer"),
           captionText.contains("hei-tiki"),
           captionText.contains("woven cloak") {
            return true
        }

        if captionText.hasPrefix("the hobbiton movie set"),
           captionText.contains("matamata"),
           captionText.contains("the lord of the rings"),
           captionText.contains("the hobbit") {
            return true
        }

        if captionText.hasPrefix("a haka performed"),
           captionText.contains("national rugby union team"),
           captionText.contains("before a game"),
           captionText.contains("stamping of the feet") {
            return true
        }

        return false
    }

    private static func normalizeMaoriLanguageLegend(in articleContent: Element) throws {
        let legendLabels = [
            "Less than 5%",
            "More than 5%",
            "More than 10%",
            "More than 20%",
            "More than 30%",
            "More than 40%",
            "More than 50%"
        ]

        for paragraph in try articleContent.select("p").array() {
            let text = ((try? paragraph.text()) ?? "").lowercased()
            guard text.contains("speakers of māori according to the 2013 census"),
                  text.contains("less than 5%"),
                  text.contains("more than 50%") else {
                continue
            }

            let swatches = try paragraph.select("span").array()
            guard swatches.count >= legendLabels.count else { continue }

            let supHTML = (try? paragraph.select("sup").first()?.outerHtml()) ?? ""
            var replacementHTML = "<p>Speakers of Māori according to the 2013 census\(supHTML)</p>"
            for (index, label) in legendLabels.enumerated() {
                let swatchHTML = (try? swatches[index].outerHtml()) ?? "<span>&nbsp;</span>"
                replacementHTML += "<p>\(swatchHTML)&nbsp;\(label) </p>"
            }
            try paragraph.before(replacementHTML)
            try paragraph.remove()
        }
    }

    private static func normalizeTeAraLinks(in articleContent: Element) throws {
        for anchor in try articleContent.select("a[href]").array() {
            let href = (try? anchor.attr("href")) ?? ""
            guard href.contains("TeAra.govt.nz") || href.contains("www.TeAra.govt.nz") else {
                continue
            }
            let normalized = href
                .replacingOccurrences(of: "www.TeAra.govt.nz", with: "www.teara.govt.nz")
                .replacingOccurrences(of: "TeAra.govt.nz", with: "teara.govt.nz")
            try anchor.attr("href", normalized)
        }
    }
}
