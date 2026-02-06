import Foundation
import SwiftSoup

/// Swift implementation of Mozilla's Readability.js
/// Extracts readable content from web pages
public struct Readability {
    private let doc: Document
    private let options: ReadabilityOptions

    /// Initialize with HTML string and optional configuration
    public init(html: String, baseURL: URL? = nil, options: ReadabilityOptions = .default) throws {
        if let baseURL {
            self.doc = try SwiftSoup.parse(html, baseURL.absoluteString)
        } else {
            self.doc = try SwiftSoup.parse(html)
        }
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
        try cleaner.postProcessArticle(articleContent)

        // Get text content
        let textContent = try articleContent.text()

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

        // Use byline from metadata if available, otherwise from content extraction
        // This matches Mozilla's behavior: metadata.byline || this._articleByline
        let byline = metadata.byline ?? extractedByline

        return ReadabilityResult(
            title: title,
            byline: byline,
            content: content,
            textContent: textContent,
            excerpt: excerpt,
            siteName: metadata.siteName,
            publishedTime: metadata.publishedTime
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
                // Check if key matches the pattern OR is article:published_time
                let isArticlePublishedTime = key == "article:published_time"
                if let regex = try? NSRegularExpression(pattern: propertyPattern, options: [.caseInsensitive]),
                   (regex.firstMatch(in: key, options: [], range: NSRange(location: 0, length: key.utf16.count)) != nil || isArticlePublishedTime),
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

        // Extract published time
        metadata.publishedTime = values["article:published_time"] ??
                                 values["parsely-pub-date"]

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

        try removeHiddenElements()
        try replaceBrs()
        try replaceFontTags()
    }

    /// Remove hidden elements from the document
    /// Handles aria-hidden, hidden attribute, display:none, and visibility:hidden
    private func removeHiddenElements() throws {
        // Remove elements with aria-hidden="true"
        let ariaHiddenElements = try doc.select("[aria-hidden=true]")
        try ariaHiddenElements.remove()

        // Remove elements with hidden attribute
        let hiddenElements = try doc.select("[hidden]")
        try hiddenElements.remove()

        // Remove elements with display:none or visibility:hidden in style
        let styledElements = try doc.select("*[style]")
        for el in styledElements {
            if let style = try? el.attr("style").lowercased() {
                let normalized = style.replacingOccurrences(of: " ", with: "")
                if normalized.contains("display:none") || normalized.contains("visibility:hidden") {
                    try el.remove()
                }
            }
        }
    }

    /// Replaces 2 or more successive <br> elements with a single <p>.
    /// Whitespace between <br> elements are ignored.
    /// Based on Mozilla Readability.js _replaceBrs()
    private func replaceBrs() throws {
        let brs = try doc.select("br")

        for br in brs {
            // Get the next non-whitespace sibling
            var next = nextNode(br.nextSibling())
            var replaced = false

            // If we find a <br> chain, remove the <br>s until we hit another element
            // or non-whitespace. This leaves behind the first <br> in the chain.
            while let current = next,
                  current.nodeName().lowercased() == "br" {
                replaced = true
                let brSibling = current.nextSibling()
                try current.remove()
                next = nextNode(brSibling)
            }

            // If we removed a <br> chain, replace the remaining <br> with a <p>
            if replaced {
                let p = try doc.createElement("p")
                try br.replaceWith(p)

                // Add all sibling nodes as children of the <p> until we hit another <br> chain
                next = p.nextSibling()
                while let current = next {
                    // If we've hit another <br><br>, we're done adding children to this <p>
                    if current.nodeName().lowercased() == "br" {
                        if let nextElem = nextNode(current.nextSibling()),
                           nextElem.nodeName().lowercased() == "br" {
                            break
                        }
                    }

                    // Only add phrasing content
                    if !isPhrasingContent(current) {
                        break
                    }

                    // Otherwise, make this node a child of the new <p>
                    let sibling = current.nextSibling()
                    try p.appendChild(current)
                    next = sibling
                }

                // Remove trailing whitespace from the paragraph.
                // Use all child nodes to include trailing text nodes.
                while let lastChild = p.getChildNodes().last {
                    if isWhitespace(lastChild) {
                        try lastChild.remove()
                    } else {
                        break
                    }
                }

                // If the parent is a <p>, convert it to a <div>
                if let parent = p.parent(),
                   parent.tagName().lowercased() == "p" {
                    _ = try DOMHelpers.setTagName(parent, newTag: "div")
                }
            }
        }
    }

    /// Get the next non-whitespace node, skipping text nodes that only contain whitespace
    /// Similar to Mozilla's _nextNode()
    private func nextNode(_ node: Node?) -> Node? {
        var current = node
        while let n = current {
            // If it's an element node, return it
            if n is Element {
                return n
            }
            // If it's a text node with non-whitespace content, return it
            if let textNode = n as? TextNode {
                if !textNode.text().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return n
                }
            }
            // Skip whitespace text nodes and move to next sibling
            current = n.nextSibling()
        }
        return nil
    }

    /// Check if node is phrasing content (inline content)
    private func isPhrasingContent(_ node: Node) -> Bool {
        // Text nodes are phrasing content
        if node is TextNode {
            return true
        }

        guard let element = node as? Element else { return false }

        let phrasingTags = Set(Configuration.phrasingElements.map { $0.lowercased() })
        let tagName = element.tagName().lowercased()

        // Direct phrasing elements
        if phrasingTags.contains(tagName) {
            return true
        }

        // A, DEL, INS are phrasing if all their children are phrasing
        if ["a", "del", "ins"].contains(tagName) {
            for child in element.children() {
                if !isPhrasingContent(child) {
                    return false
                }
            }
            return true
        }

        return false
    }

    /// Check if node is whitespace
    private func isWhitespace(_ node: Node) -> Bool {
        if let textNode = node as? TextNode {
            return textNode.text().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if let element = node as? Element {
            return element.tagName().lowercased() == "br"
        }
        return false
    }

    private func replaceFontTags() throws {
        let fonts = try doc.select("font")
        for font in fonts {
            let span = try doc.createElement("span")

            // Copy attributes from font to span
            if let attributes = font.getAttributes() {
                for attr in attributes {
                    try span.attr(attr.getKey(), attr.getValue())
                }
            }

            // Move all child nodes (including text nodes) to span in original order
            // We move rather than clone since we're replacing the parent
            let childNodes = font.getChildNodes()
            for node in childNodes {
                try span.appendChild(node)
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
        let cleaned = try DOMHelpers.cloneElement(element, in: doc)

        // Match Mozilla post-processing order:
        // 1) fix relative links/media URLs
        // 2) simplify nested wrappers
        // 3) optionally strip classes
        try fixRelativeURIs(cleaned)
        try simplifyNestedElements(cleaned)
        if !options.keepClasses {
            try cleanClasses(cleaned)
        }

        return try cleaned.outerHtml()
    }

    private func cleanClasses(_ element: Element) throws {
        let preservedClasses = Set(Configuration.classesToPreserve + options.classesToPreserve)
        let className = (try? element.className()) ?? ""
        let newClasses = className
            .split(separator: " ")
            .map(String.init)
            .filter { preservedClasses.contains($0) }
            .joined(separator: " ")

        if newClasses.isEmpty {
            try element.removeAttr("class")
        } else {
            try element.attr("class", newClasses)
        }

        for child in element.children() {
            try cleanClasses(child)
        }
    }

    private func fixRelativeURIs(_ articleContent: Element) throws {
        func toAbsoluteURI(_ rawURI: String) -> String {
            let uri = rawURI.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !uri.isEmpty else { return rawURI }

            if uri.hasPrefix("#") {
                return uri
            }

            if let base = URL(string: doc.location()),
               let resolved = URL(string: uri, relativeTo: base)?.absoluteURL {
                if var components = URLComponents(url: resolved, resolvingAgainstBaseURL: false),
                   components.path.isEmpty {
                    components.path = "/"
                    return components.string ?? resolved.absoluteString
                }
                return resolved.absoluteString
            }

            if let resolved = URL(string: uri)?.absoluteURL {
                if var components = URLComponents(url: resolved, resolvingAgainstBaseURL: false),
                   components.path.isEmpty {
                    components.path = "/"
                    return components.string ?? resolved.absoluteString
                }
                return resolved.absoluteString
            }

            return uri
        }

        let links = try articleContent.select("a[href]")
        for link in links {
            let href = (try? link.attr("href")) ?? ""
            guard !href.isEmpty else { continue }
            let normalizedHref = href.trimmingCharacters(in: .whitespacesAndNewlines)

            if normalizedHref.lowercased().hasPrefix("javascript:") {
                if link.getChildNodes().count == 1, link.getChildNodes().first is TextNode {
                    let text = try link.text()
                    let replacement = TextNode(text, nil)
                    try link.replaceWith(replacement)
                } else {
                    let span = try doc.createElement("span")
                    for child in link.getChildNodes() {
                        try span.appendChild(child)
                    }
                    try link.replaceWith(span)
                }
                continue
            }

            try link.attr("href", toAbsoluteURI(normalizedHref))
        }

        let mediaElements = try articleContent.select("img, picture, figure, video, audio, source")
        for media in mediaElements {
            let src = (try? media.attr("src")) ?? ""
            if !src.isEmpty {
                try media.attr("src", toAbsoluteURI(src))
            }

            let poster = (try? media.attr("poster")) ?? ""
            if !poster.isEmpty {
                try media.attr("poster", toAbsoluteURI(poster))
            }
        }
    }

    private func simplifyNestedElements(_ articleContent: Element) throws {
        let cleaner = ArticleCleaner(options: options)
        var node: Element? = articleContent

        while let current = node {
            let next = DOMTraversal.getNextNode(current)
            let tagName = current.tagName().uppercased()

            if let _ = current.parent(),
               (tagName == "DIV" || tagName == "SECTION"),
               !current.id().hasPrefix("readability") {
                if DOMTraversal.isElementWithoutContent(current) {
                    try current.remove()
                } else if cleaner.hasSingleTagInsideElement(current, tag: "DIV") ||
                            cleaner.hasSingleTagInsideElement(current, tag: "SECTION"),
                          let child = current.children().first {
                    if let attributes = current.getAttributes() {
                        for attr in attributes {
                            try child.attr(attr.getKey(), attr.getValue())
                        }
                    }
                    try current.replaceWith(child)
                }
            }

            node = next
        }
    }
}
