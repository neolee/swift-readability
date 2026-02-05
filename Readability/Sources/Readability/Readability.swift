import Foundation
import SwiftSoup

public struct Readability {
    private let doc: Document
    private let baseURL: URL?
    private let options: ReadabilityOptions

    /// Initialize with HTML string and optional configuration
    public init(html: String, baseURL: URL? = nil, options: ReadabilityOptions = .default) throws {
        self.doc = try SwiftSoup.parse(html)
        self.baseURL = baseURL
        self.options = options
    }

    /// Parse the document and extract readable content
    public func parse() throws -> ReadabilityResult {
        try prepDocument()

        // Extract metadata first (following Mozilla's order)
        let metadata = try extractMetadata()

        let title = try extractTitle()
        let article = try grabArticle()
        let textContent = try article.text()

        // Check character threshold
        if textContent.count < options.charThreshold {
            throw ReadabilityError.contentTooShort(
                actualLength: textContent.count,
                threshold: options.charThreshold
            )
        }

        // Extract excerpt: use metadata if available, otherwise from article
        let excerpt: String?
        if let metaExcerpt = metadata.excerpt {
            excerpt = metaExcerpt
        } else {
            excerpt = try extractExcerpt(from: article)
        }
        let content = try cleanArticle(article)

        return ReadabilityResult(
            title: title,
            byline: metadata.byline,
            content: content,
            textContent: textContent,
            excerpt: excerpt
        )
    }

    /// Metadata extraction structure following Mozilla's logic
    private struct Metadata {
        var title: String?
        var byline: String?
        var excerpt: String?
        var siteName: String?
        var publishedTime: String?
    }

    /// Extract metadata from various sources (meta tags, JSON-LD, etc.)
    private func extractMetadata() throws -> Metadata {
        var metadata = Metadata()

        // Skip if JSON-LD is disabled
        if !options.disableJSONLD {
            // TODO: Implement JSON-LD parsing (Phase 3)
        }

        // Extract from meta tags following Mozilla's priority order
        // Pattern for matching property names: (dc|dcterm|og|twitter|parsely|weibo):property
        let propertyPattern = "^\\s*(?:(dc|dcterm|og|twitter|parsely|weibo:(article|webpage))\\s*[-\\.:]\\s*)?(author|creator|pub-date|description|title|site_name)\\s*$"

        // Collect all meta values
        var values: [String: String] = [:]
        let metas = try doc.select("meta")

        for meta in metas {
            let property = (try? meta.attr("property"))?.lowercased() ?? ""
            let name = (try? meta.attr("name"))?.lowercased() ?? ""
            let content = (try? meta.attr("content")) ?? ""

            let key = property.isEmpty ? name : property

            // Match against pattern
            if let regex = try? NSRegularExpression(pattern: propertyPattern, options: [.caseInsensitive]),
               regex.firstMatch(in: key, options: [], range: NSRange(location: 0, length: key.utf16.count)) != nil,
               !content.isEmpty {
                values[key] = content
            }
        }

        // Extract byline (author) following Mozilla's priority
        metadata.byline = values["dc:creator"] ??
                         values["dcterm:creator"] ??
                         values["author"] ??
                         values["parsely:author"] ??
                         values["weibo:article:author"] ??
                         values["weibo:webpage:author"] ??
                         values["twitter:creator"] ??
                         values["og:author"]

        // Clean up byline (remove "By" prefix, etc.)
        if var byline = metadata.byline {
            byline = byline.trimmingCharacters(in: .whitespaces)
            if byline.lowercased().hasPrefix("by ") {
                byline = String(byline.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            }
            metadata.byline = byline
        }

        // Extract description/excerpt following Mozilla's priority
        metadata.excerpt = values["dc:description"] ??
                          values["dcterm:description"] ??
                          values["og:description"] ??
                          values["weibo:article:description"] ??
                          values["weibo:webpage:description"] ??
                          values["description"] ??
                          values["twitter:description"]

        // Extract site name
        metadata.siteName = values["og:site_name"] ??
                           values["twitter:site"] ??
                           values["dc:publisher"] ??
                           values["dcterm:publisher"]

        // Clean up excerpt (unescape HTML entities)
        if var excerpt = metadata.excerpt {
            excerpt = excerpt.trimmingCharacters(in: .whitespaces)
            // Basic HTML entity unescaping
            excerpt = excerpt.replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&#39;", with: "'")
                .replacingOccurrences(of: "&apos;", with: "'")
            metadata.excerpt = excerpt
        }

        return metadata
    }

    // MARK: - Document Preparation

    private func prepDocument() throws {
        // Remove script, style, and other non-content elements
        let elementsToRemove = try doc.select("script, style, noscript, iframe, object, embed, template")
        try elementsToRemove.remove()

        // Convert BR tags to paragraphs
        try replaceBrs()

        // Replace font tags with spans
        try replaceFontTags()
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

    private func replaceFontTags() throws {
        let fonts = try doc.select("font")
        for font in fonts {
            let span = Element(Tag("span"), "")
            // Copy children
            for child in font.children() {
                try span.appendChild(child)
            }
            try font.replaceWith(span)
        }
    }

    // MARK: - Title Extraction

    /// Extract article title following Mozilla Readability.js logic exactly
    private func extractTitle() throws -> String {
        var curTitle = ""
        var origTitle = ""

        // Get original title from document
        origTitle = try doc.title().trimmingCharacters(in: .whitespaces)
        curTitle = origTitle

        // Skip processing if title is empty
        if curTitle.isEmpty {
            // Try h1 as fallback
            if let h1 = try doc.select("h1").first() {
                return try h1.text().trimmingCharacters(in: .whitespaces)
            }
            return "Untitled"
        }

        var titleHadHierarchicalSeparators = false

        // Check for hierarchical separators: | - – — \ / > »
        let titleSeparators = "|\\-–—\\/»"
        let separatorPattern = "\\s[\(titleSeparators)]\\s"

        if let _ = origTitle.range(of: separatorPattern, options: .regularExpression) {
            titleHadHierarchicalSeparators = origTitle.range(of: "\\s[\\/>»]\\s", options: .regularExpression) != nil

            // Find all separator occurrences and take text before the last one
            let regex = try NSRegularExpression(pattern: separatorPattern, options: [.caseInsensitive])
            let matches = regex.matches(in: origTitle, options: [], range: NSRange(location: 0, length: origTitle.utf16.count))

            if let lastMatch = matches.last {
                let index = origTitle.index(origTitle.startIndex, offsetBy: lastMatch.range.location)
                curTitle = String(origTitle[..<index])
            }

            // If resulting title is too short (< 3 words), remove the first part instead
            if wordCount(curTitle) < 3 {
                if let firstMatch = matches.first {
                    let endIndex = origTitle.index(origTitle.startIndex, offsetBy: firstMatch.range.location + firstMatch.range.length)
                    curTitle = String(origTitle[endIndex...]).trimmingCharacters(in: .whitespaces)
                }
            }
        } else if curTitle.contains(": ") {
            // Check if we have a heading containing this exact string
            let headings = try doc.select("h1, h2")
            let trimmedTitle = curTitle.trimmingCharacters(in: .whitespaces)

            var hasExactMatch = false
            for heading in headings {
                let headingText = try heading.text().trimmingCharacters(in: .whitespaces)
                if headingText == trimmedTitle {
                    hasExactMatch = true
                    break
                }
            }

            // If no exact match in headings, extract title from after the colon
            if !hasExactMatch {
                if let lastColon = origTitle.lastIndex(of: ":") {
                    let afterColon = origTitle.index(after: lastColon)
                    curTitle = String(origTitle[afterColon...]).trimmingCharacters(in: .whitespaces)

                    // If title is now too short, try the first colon
                    if wordCount(curTitle) < 3 {
                        if let firstColon = origTitle.firstIndex(of: ":") {
                            let afterFirstColon = origTitle.index(after: firstColon)
                            curTitle = String(origTitle[afterFirstColon...]).trimmingCharacters(in: .whitespaces)
                        }
                    } else if wordCount(String(origTitle[..<origTitle.firstIndex(of: ":")!])) > 5 {
                        // If too many words before first colon, use original title
                        curTitle = origTitle
                    }
                }
            }
        } else if curTitle.count > 150 || curTitle.count < 15 {
            // Title too long or too short - try h1
            let hOnes = try doc.select("h1")
            if hOnes.count == 1 {
                curTitle = try hOnes.first()!.text()
            }
        }

        // Normalize whitespace
        curTitle = curTitle.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        // If we now have 4 words or fewer and either no hierarchical separators were found
        // or we decreased the word count by more than 1, use original title
        let curTitleWordCount = wordCount(curTitle)
        if curTitleWordCount <= 4 {
            if !titleHadHierarchicalSeparators {
                curTitle = origTitle
            } else {
                let origWordCount = wordCount(origTitle.replacingOccurrences(of: separatorPattern, with: "", options: .regularExpression, range: nil))
                if curTitleWordCount != origWordCount - 1 {
                    curTitle = origTitle
                }
            }
        }

        return curTitle.isEmpty ? origTitle : curTitle
    }

    /// Count words in a string
    private func wordCount(_ str: String) -> Int {
        return str.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }

    // MARK: - Article Extraction

    private func grabArticle() throws -> Element {
        let body = doc.body() ?? doc
        let elements = try body.select("p, div, article, section, td, pre, blockquote")
        var candidates: [(element: Element, score: Double)] = []

        for element in elements {
            let score = try scoreElement(element)
            if score > 0 {
                candidates.append((element, score))
                // Score ancestors
                if let parent = element.parent() {
                    let parentScore = score * Configuration.ancestorScoreMultiplier
                    if parentScore > 0 {
                        candidates.append((parent, parentScore))
                    }
                }
            }
        }

        // Aggregate scores by element
        var scoreMap: [ObjectIdentifier: (element: Element, score: Double)] = [:]
        for (element, score) in candidates {
            let key = ObjectIdentifier(element)
            if let existing = scoreMap[key] {
                scoreMap[key] = (element, existing.score + score)
            } else {
                scoreMap[key] = (element, score)
            }
        }

        // Find best element
        var bestElement: Element?
        var bestScore: Double = 0

        for (_, (element, score)) in scoreMap {
            if score > bestScore {
                bestScore = score
                bestElement = element
            }
        }

        return bestElement ?? body
    }

    private func scoreElement(_ element: Element) throws -> Double {
        let tagName = element.tagName().lowercased()
        let text = try element.text()
        let textLength = text.count

        // Skip elements with too little text
        if textLength < 25 {
            return 0
        }

        // Skip hidden elements
        if !DOMHelpers.isProbablyVisible(element) {
            return 0
        }

        var score: Double = 0

        // Base score by tag
        switch tagName {
        case "div", "article", "section":
            score += Configuration.baseScoreDiv
        case "pre", "td", "blockquote":
            score += Configuration.baseScorePre
        case "p":
            score += Configuration.baseScoreP
        default:
            break
        }

        // Score by text length
        let lengthScore = min(Double(textLength) / 100.0, Configuration.textLengthScoreMax)
        score += lengthScore

        // Score by comma count (text density indicator)
        let commaCount = text.filter { $0 == "," }.count
        score += Double(commaCount) * Configuration.commaScore

        // Penalize by link density
        let linkDensity = try calculateLinkDensity(element)
        score *= (1.0 - linkDensity + options.linkDensityModifier)

        // Score by class/id patterns
        let classAndId = DOMHelpers.getClassAndId(element)

        if DOMHelpers.matchesPatterns(classAndId, patterns: Configuration.positivePatterns) {
            score += Configuration.classWeightPositive
        }

        if DOMHelpers.matchesPatterns(classAndId, patterns: Configuration.negativePatterns) {
            score += Configuration.classWeightNegative
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
        if !options.keepClasses {
            let unwantedAttrs = ["style", "class", "id", "onclick", "onload", "width", "height", "align", "border", "cellpadding", "cellspacing"]
            for attr in unwantedAttrs {
                try element.removeAttr(attr)
            }
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
            "[class*=widget]", "[id*=widget]",
            "[class*=ad-]", "[id*=ad-]",
            "[class*=social]", "[id*=social]",
            "[aria-hidden=true]"
        ]

        for selector in junkSelectors {
            let elements = try element.select(selector)
            try elements.remove()
        }
    }
}
