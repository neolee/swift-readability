import Foundation
import SwiftSoup

/// Swift implementation of Mozilla's Readability.js
/// Extracts readable content from web pages
public struct Readability {
    private let doc: Document
    private let options: ReadabilityOptions

    /// Initialize with HTML string and optional configuration
    public init(html: String, options: ReadabilityOptions = .default) throws {
        self.doc = try SwiftSoup.parse(html)
        self.options = options
    }

    /// Parse the document and extract readable content
    public func parse() throws -> ReadabilityResult {
        // Extract metadata BEFORE prepDocument() to preserve JSON-LD scripts
        let metadata = try extractMetadata()

        // Prepare document (remove scripts, styles, etc.)
        try prepDocument()

        // Use metadata title if available, otherwise extract from document
        let title: String
        if let metaTitle = metadata.title {
            title = metaTitle
        } else {
            title = try extractTitle()
        }

        // Extract article content using new ContentExtractor
        let extractor = ContentExtractor(doc: doc, options: options)
        let (articleContent, extractedByline, _) = try extractor.extract()

        // Post-process with ArticleCleaner
        let cleaner = ArticleCleaner(options: options)
        try cleaner.prepArticle(articleContent)

        // Get text content
        let textContent = try articleContent.text()

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
            excerpt = try extractExcerpt(from: articleContent)
        }

        // Add page wrapper attributes to article content directly
        try articleContent.attr("id", "readability-page-1")
        try articleContent.addClass("page")

        // Clean and serialize content
        let content = try cleanAndSerialize(articleContent)

        // Use byline from extraction if available, otherwise from metadata
        let byline = extractedByline ?? metadata.byline

        return ReadabilityResult(
            title: title,
            byline: byline,
            content: content,
            textContent: textContent,
            excerpt: excerpt
        )
    }

    // MARK: - Metadata Extraction

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
            let jsonldMetadata = try extractJSONLDMetadata()
            metadata.title = jsonldMetadata.title
            metadata.byline = jsonldMetadata.byline
            metadata.excerpt = jsonldMetadata.excerpt
            metadata.siteName = jsonldMetadata.siteName
            metadata.publishedTime = jsonldMetadata.publishedTime
        }

        // Extract from meta tags
        let metaMetadata = try extractMetaMetadata()
        metadata.title = metadata.title ?? metaMetadata.title
        metadata.byline = metadata.byline ?? metaMetadata.byline
        metadata.excerpt = metadata.excerpt ?? metaMetadata.excerpt
        metadata.siteName = metadata.siteName ?? metaMetadata.siteName
        metadata.publishedTime = metadata.publishedTime ?? metaMetadata.publishedTime

        return metadata
    }

    private func extractMetaMetadata() throws -> Metadata {
        var metadata = Metadata()

        let propertyPattern = "^\\s*(?:(dc|dcterm|og|twitter|parsely|weibo:(article|webpage))\\s*[-\\.:]\\s*)?(author|creator|pub-date|description|title|site_name)\\s*$"

        var values: [String: String] = [:]
        let metas = try doc.select("meta")

        for meta in metas {
            let property = (try? meta.attr("property"))?.lowercased() ?? ""
            let name = (try? meta.attr("name"))?.lowercased() ?? ""
            let content = (try? meta.attr("content")) ?? ""

            var keysToCheck: [String] = []
            if !property.isEmpty {
                keysToCheck.append(contentsOf: property.split(separator: " ").map(String.init))
            }
            if !name.isEmpty {
                keysToCheck.append(name)
            }

            for key in keysToCheck {
                if let regex = try? NSRegularExpression(pattern: propertyPattern, options: [.caseInsensitive]),
                   regex.firstMatch(in: key, options: [], range: NSRange(location: 0, length: key.utf16.count)) != nil,
                   !content.isEmpty {
                    values[key] = content
                }
            }
        }

        // Extract title
        metadata.title = values["dc:title"] ??
                         values["dcterm:title"] ??
                         values["og:title"] ??
                         values["twitter:title"] ??
                         values["parsely-title"] ??
                         values["title"]

        // Extract byline
        let metaByline = values["dc:creator"] ??
                        values["dcterm:creator"] ??
                        values["author"]
        let socialByline = values["parsely-author"] ??
                          values["weibo:article:author"] ??
                          values["weibo:webpage:author"]
        let ogByline = values["twitter:creator"] ??
                      values["og:author"]
        metadata.byline = metaByline ?? socialByline ?? ogByline

        if var byline = metadata.byline {
            byline = byline.trimmingCharacters(in: .whitespaces)
            if byline.lowercased().hasPrefix("by ") {
                byline = String(byline.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            }
            metadata.byline = byline
        }

        // Extract excerpt
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

        // Clean up excerpt
        if var excerpt = metadata.excerpt {
            excerpt = excerpt.trimmingCharacters(in: .whitespaces)
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

    private func extractJSONLDMetadata() throws -> Metadata {
        var metadata = Metadata()

        var scripts = try doc.select("script[type=\"application/ld+json\"]")
        if scripts.isEmpty {
            scripts = try doc.select("script[type='application/ld+json']")
        }

        var jsonldObjects: [[String: Any]] = []

        for script in scripts {
            guard let jsonText = try? script.html() else { continue }

            let cleanedText = jsonText
                .replacingOccurrences(of: "<![CDATA[", with: "")
                .replacingOccurrences(of: "]]>", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !cleanedText.isEmpty,
                  let data = cleanedText.data(using: .utf8) else { continue }

            do {
                if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    jsonldObjects.append(jsonObject)
                } else if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    jsonldObjects.append(contentsOf: jsonArray)
                }
            } catch {
                continue
            }
        }

        let preferredTypes = ["NewsArticle", "Article", "WebPage", "BlogPosting"]
        var selectedObject: [String: Any]?

        for type in preferredTypes {
            if let match = jsonldObjects.first(where: { ($0["@type"] as? String)?.lowercased() == type.lowercased() }) {
                selectedObject = match
                break
            }
        }

        if selectedObject == nil && !jsonldObjects.isEmpty {
            selectedObject = jsonldObjects.first
        }

        guard let jsonld = selectedObject else {
            return metadata
        }

        if let headline = jsonld["headline"] as? String {
            metadata.title = headline
        }

        if let description = jsonld["description"] as? String {
            metadata.excerpt = description
        }

        if let datePublished = jsonld["datePublished"] as? String {
            metadata.publishedTime = datePublished
        }

        metadata.byline = extractAuthorFromJSONLD(jsonld["author"])

        if let publisher = jsonld["publisher"] as? [String: Any],
           let publisherName = publisher["name"] as? String {
            metadata.siteName = publisherName
        }

        return metadata
    }

    private func extractAuthorFromJSONLD(_ author: Any?) -> String? {
        guard let author = author else { return nil }

        if let authorArray = author as? [Any] {
            let names = authorArray.compactMap { extractAuthorFromJSONLD($0) }
            return names.isEmpty ? nil : names.joined(separator: ", ")
        }

        if let authorString = author as? String {
            return authorString
        }

        if let authorObject = author as? [String: Any],
           let name = authorObject["name"] as? String {
            return name
        }

        return nil
    }

    // MARK: - Document Preparation

    private func prepDocument() throws {
        let elementsToRemove = try doc.select("script, style, noscript, iframe, object, embed, template")
        try elementsToRemove.remove()

        try removeAriaHiddenElements()
        try replaceBrs()
        try replaceFontTags()
    }

    private func removeAriaHiddenElements() throws {
        let ariaHiddenElements = try doc.select("[aria-hidden=true]")
        try ariaHiddenElements.remove()
    }

    private func replaceBrs() throws {
        let brs = try doc.select("br")
        for br in brs {
            var next: Element? = try br.nextElementSibling()
            var replaced = false

            while let current = next, current.tagName() == "br" {
                if !replaced {
                    replaced = true
                    let p = try doc.createElement("p")
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
            let span = try doc.createElement("span")
            for child in font.children() {
                try span.appendChild(child)
            }
            try font.replaceWith(span)
        }
    }

    // MARK: - Title Extraction

    private func extractTitle() throws -> String {
        var curTitle = ""
        var origTitle = ""

        origTitle = try doc.title().trimmingCharacters(in: .whitespaces)
        curTitle = origTitle

        if curTitle.isEmpty {
            if let h1 = try doc.select("h1").first() {
                return try h1.text().trimmingCharacters(in: .whitespaces)
            }
            return "Untitled"
        }

        var titleHadHierarchicalSeparators = false
        let titleSeparators = "|\\-–—\\/»"
        let separatorPattern = "\\s[\(titleSeparators)]\\s"

        if let _ = origTitle.range(of: separatorPattern, options: .regularExpression) {
            titleHadHierarchicalSeparators = origTitle.range(of: "\\s[\\/>»]\\s", options: .regularExpression) != nil

            let regex = try NSRegularExpression(pattern: separatorPattern, options: [.caseInsensitive])
            let matches = regex.matches(in: origTitle, options: [], range: NSRange(location: 0, length: origTitle.utf16.count))

            if let lastMatch = matches.last {
                let index = origTitle.index(origTitle.startIndex, offsetBy: lastMatch.range.location)
                curTitle = String(origTitle[..<index])
            }

            if wordCount(curTitle) < 3 {
                if let firstMatch = matches.first {
                    let endIndex = origTitle.index(origTitle.startIndex, offsetBy: firstMatch.range.location + firstMatch.range.length)
                    curTitle = String(origTitle[endIndex...]).trimmingCharacters(in: .whitespaces)
                }
            }
        } else if curTitle.contains(": ") {
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

            if !hasExactMatch {
                if let lastColon = origTitle.lastIndex(of: ":") {
                    let afterColon = origTitle.index(after: lastColon)
                    curTitle = String(origTitle[afterColon...]).trimmingCharacters(in: .whitespaces)

                    if wordCount(curTitle) < 3 {
                        if let firstColon = origTitle.firstIndex(of: ":") {
                            let afterFirstColon = origTitle.index(after: firstColon)
                            curTitle = String(origTitle[afterFirstColon...]).trimmingCharacters(in: .whitespaces)
                        }
                    } else if wordCount(String(origTitle[..<origTitle.firstIndex(of: ":")!])) > 5 {
                        curTitle = origTitle
                    }
                }
            }
        } else if curTitle.count > 150 || curTitle.count < 15 {
            let hOnes = try doc.select("h1")
            if hOnes.count == 1 {
                curTitle = try hOnes.first()!.text()
            }
        }

        curTitle = curTitle.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

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

    private func wordCount(_ str: String) -> Int {
        return str.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
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

    // MARK: - Content Serialization

    private func cleanAndSerialize(_ element: Element) throws -> String {
        // Clone element into document context for serialization
        let cleaned = try cloneElement(element, in: doc)

        // Remove unwanted attributes
        try removeUnwantedAttributes(cleaned)

        // Remove junk elements that might have been missed
        try removeJunkElements(cleaned)

        return try cleaned.outerHtml()
    }

    /// Clone an element into document context
    private func cloneElement(_ element: Element, in doc: Document) throws -> Element {
        let clone = try doc.createElement(element.tagName())

        // Copy attributes
        if let attributes = element.getAttributes() {
            for attr in attributes {
                try clone.attr(attr.getKey(), attr.getValue())
            }
        }

        // Recursively clone children
        for child in element.children() {
            let childClone = try cloneElement(child, in: doc)
            try clone.appendChild(childClone)
        }

        // Copy text nodes
        for textNode in element.textNodes() {
            try clone.appendText(textNode.text())
        }

        return clone
    }

    private func removeUnwantedAttributes(_ element: Element) throws {
        if !options.keepClasses {
            let unwantedAttrs = ["style", "onclick", "onload", "width", "height", "align", "border", "cellpadding", "cellspacing"]
            for attr in unwantedAttrs {
                try element.removeAttr(attr)
            }

            // Handle class attribute - preserve "page" class
            if let className = try? element.attr("class") {
                let classes = className.split(separator: " ").map(String.init)
                let preservedClasses = classes.filter { $0 == "page" }
                if preservedClasses.isEmpty {
                    try element.removeAttr("class")
                } else {
                    try element.attr("class", preservedClasses.joined(separator: " "))
                }
            }

            // Handle id attribute - preserve "readability-page-*" and "readability-content" ids
            if let id = try? element.attr("id") {
                if !id.hasPrefix("readability-") {
                    try element.removeAttr("id")
                }
            }
        }

        for child in element.children() {
            try removeUnwantedAttributes(child)
        }
    }

    private func removeJunkElements(_ element: Element) throws {
        let junkSelectors = [
            "script", "style", "noscript",
            "[class*=comment]", "[id*=comment]",
            "[class*=sidebar]", "[id*=sidebar]",
            "[class*=footer]", "[id*=footer]",
            "[class*=ad-]", "[id*=ad-]",
            "[aria-hidden=true]"
        ]

        for selector in junkSelectors {
            let elements = try element.select(selector)
            try elements.remove()
        }
    }
}


