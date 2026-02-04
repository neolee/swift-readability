import Foundation
import SwiftSoup

public struct Readability {
    private let doc: Document
    private let baseURL: URL?

    public init(html: String, baseURL: URL? = nil) throws {
        self.doc = try SwiftSoup.parse(html)
        self.baseURL = baseURL
    }

    public func parse() throws -> ReadabilityResult {
        try prepDocument()
        let title = try extractTitle()
        let article = try grabArticle()
        let textContent = try article.text()
        let excerpt = try extractExcerpt(from: article)
        let content = try cleanArticle(article)

        return ReadabilityResult(
            title: title,
            content: content,
            textContent: textContent,
            excerpt: excerpt
        )
    }

    // MARK: - Document Preparation

    private func prepDocument() throws {
        let elementsToRemove = try doc.select("script, style, noscript, iframe, object, embed")
        try elementsToRemove.remove()
        try replaceBrs()
    }

    private func replaceBrs() throws {
        let brs = try doc.select("br")
        for br in brs {
            var next: Element? = try br.nextElementSibling()
            var replaced = false

            while let current = next, current.tagName() == "br" {
                if !replaced {
                    replaced = true
                    let p = Element(Tag("p"), "")
                    _ = try br.previousElementSibling()?.after(p)
                }
                let sibling = try current.nextElementSibling()
                try current.remove()
                next = sibling
            }

            if replaced {
                try br.remove()
            }
        }
    }

    // MARK: - Title Extraction

    private func extractTitle() throws -> String {
        var title = try doc.title()
        title = cleanTitle(title)

        if title.isEmpty {
            if let h1 = try doc.select("h1").first() {
                title = try h1.text()
            }
        }

        return title.isEmpty ? "Untitled" : title
    }

    private func cleanTitle(_ title: String) -> String {
        let separators = [" | ", " - ", " — ", " – ", " « ", " » ", " : ", " · "]
        var cleaned = title

        for separator in separators {
            if let range = cleaned.range(of: separator) {
                let part1 = String(cleaned[..<range.lowerBound])
                let part2 = String(cleaned[range.upperBound...])
                cleaned = part1.count > part2.count ? part1 : part2
            }
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Article Extraction

    private func grabArticle() throws -> Element {
        let body = doc.body() ?? doc
        let elements = try body.select("p, div, article, section, td, pre")
        var candidates: [(element: Element, score: Double)] = []

        for element in elements {
            let score = try scoreElement(element)
            if score > 0 {
                candidates.append((element, score))
                if let parent = element.parent() {
                    let parentScore = score * 0.5
                    if parentScore > 0 {
                        candidates.append((parent, parentScore))
                    }
                }
            }
        }

        var bestElement: Element?
        var bestScore: Double = 0

        for (element, _) in candidates {
            let currentScore = candidates
                .filter { $0.element == element }
                .reduce(0) { $0 + $1.score }

            if currentScore > bestScore {
                bestScore = currentScore
                bestElement = element
            }
        }

        return bestElement ?? body
    }

    private func scoreElement(_ element: Element) throws -> Double {
        let tagName = element.tagName().lowercased()
        let text = try element.text()
        let textLength = text.count

        if textLength < 25 {
            return 0
        }

        var score: Double = 0
        switch tagName {
        case "div", "article", "section":
            score += 5
        case "pre", "td", "blockquote":
            score += 3
        case "p":
            score += 1
        default:
            break
        }

        score += Double(textLength) / 100.0
        let commaCount = text.filter { $0 == "," }.count
        score += Double(commaCount)

        let linkDensity = try calculateLinkDensity(element)
        score *= (1.0 - linkDensity)

        let className = try element.className().lowercased()
        let id = element.id().lowercased()

        let positivePatterns = ["article", "content", "entry", "hentry", "main", "page", "post", "text", "blog", "story"]
        let negativePatterns = ["comment", "com", "contact", "foot", "footer", "footnote", "link", "media", "meta", "nav", "pagination", "promo", "related", "scroll", "share", "shopping", "sidebar", "social", "sponsor", "tags", "widget"]

        for pattern in positivePatterns {
            if className.contains(pattern) || id.contains(pattern) {
                score += 25
            }
        }

        for pattern in negativePatterns {
            if className.contains(pattern) || id.contains(pattern) {
                score -= 25
            }
        }

        return score
    }

    private func calculateLinkDensity(_ element: Element) throws -> Double {
        let text = try element.text()
        let textLength = max(text.count, 1)

        let links = try element.select("a")
        var linkLength = 0
        for link in links {
            linkLength += try link.text().count
        }

        return Double(linkLength) / Double(textLength)
    }

    // MARK: - Excerpt Extraction

    private func extractExcerpt(from element: Element) throws -> String? {
        let paragraphs = try element.select("p")
        for p in paragraphs {
            let text = try p.text().trimmingCharacters(in: .whitespacesAndNewlines)
            if text.count > 50 {
                return String(text.prefix(200))
            }
        }
        return nil
    }

    // MARK: - Article Cleaning

    private func cleanArticle(_ article: Element) throws -> String {
        guard let cleaned = article.copy() as? Element else {
            return try article.outerHtml()
        }

        try removeUnwantedAttributes(cleaned)
        try removeJunkElements(cleaned)

        return try cleaned.outerHtml()
    }

    private func removeUnwantedAttributes(_ element: Element) throws {
        let unwantedAttrs = ["style", "class", "id", "onclick", "onload", "width", "height", "align"]

        for attr in unwantedAttrs {
            try element.removeAttr(attr)
        }

        for child in element.children() {
            try removeUnwantedAttributes(child)
        }
    }

    private func removeJunkElements(_ element: Element) throws {
        let junkSelectors = [
            "script", "style", "noscript", "iframe", "object", "embed",
            "[class*=comment]", "[id*=comment]",
            "[class*=sidebar]", "[id*=sidebar]",
            "[class*=footer]", "[id*=footer]",
            "[class*=widget]", "[id*=widget]"
        ]

        for selector in junkSelectors {
            let elements = try element.select(selector)
            try elements.remove()
        }
    }
}
