import Foundation
import SwiftSoup

/// Swift implementation of Mozilla's Readability.js
/// Extracts readable content from web pages
public struct Readability {
    private final class ParseLifecycleState {
        var hasParsed = false
    }

    private let doc: Document
    private let options: ReadabilityOptions
    private let lifecycleState = ParseLifecycleState()

    /// Initialize with HTML string and optional configuration
    public init(html: String, baseURL: URL? = nil, options: ReadabilityOptions = .default) throws {
        if let baseURL {
            self.doc = try SwiftSoup.parse(html, baseURL.absoluteString)
        } else {
            self.doc = try SwiftSoup.parse(html)
        }
        self.options = options
    }

    /// Parse the document and extract readable content.
    /// This instance is single-use: calling `parse()` more than once throws `ReadabilityError.alreadyParsed`.
    public func parse() throws -> ReadabilityResult {
        guard !lifecycleState.hasParsed else {
            throw ReadabilityError.alreadyParsed
        }
        lifecycleState.hasParsed = true

        // Match Mozilla: upgrade lazy/placeholder images from <noscript> first.
        try unwrapNoscriptImages()

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
        let extractor = ContentExtractor(doc: doc, options: options, articleTitle: title)
        let (articleContent, extractedByline, _, articleDir, articleLang) = try extractor.extract()

        // Post-process with ArticleCleaner
        let cleaner = ArticleCleaner(options: options)
        try cleaner.prepArticle(articleContent)
        try cleaner.postProcessArticle(articleContent)
        try removeTitleMatchedHeaders(from: articleContent, title: title)

        // Get text content
        let textContent = try articleContent.text()

        // Extract excerpt: use metadata if available, otherwise from article
        let excerpt: String?
        if let metaExcerpt = metadata.excerpt {
            excerpt = metaExcerpt
        } else {
            excerpt = try extractExcerpt(from: articleContent)
        }

        // Keep Mozilla-compatible page wrapper shape under the article container.
        // This guarantees the exported content starts with a page DIV wrapper.
        let pageWrapper = try doc.createElement("div")
        try pageWrapper.attr("id", "readability-page-1")
        try pageWrapper.attr("class", "page")

        while let firstChild = articleContent.getChildNodes().first {
            try pageWrapper.appendChild(firstChild)
        }
        try articleContent.appendChild(pageWrapper)

        // Clean and serialize content
        let content = try cleanAndSerialize(articleContent)

        // Use byline from metadata if available, otherwise from content extraction
        // This matches Mozilla's behavior: metadata.byline || this._articleByline
        let byline = metadata.byline ?? extractedByline

        return ReadabilityResult(
            title: title,
            byline: byline,
            dir: articleDir,
            lang: articleLang,
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

    private func unwrapNoscriptImages() throws {
        let imgs = try doc.select("img")
        for img in imgs {
            var keep = false
            if let attrs = img.getAttributes() {
                for attr in attrs {
                    let key = attr.getKey().lowercased()
                    if key == "src" || key == "srcset" || key == "data-src" || key == "data-srcset" {
                        keep = true
                        break
                    }
                    if attr.getValue().range(of: "\\.(jpg|jpeg|png|webp)", options: [.regularExpression, .caseInsensitive]) != nil {
                        keep = true
                        break
                    }
                }
            }

            if !keep {
                try img.remove()
            }
        }

        let noscripts = try doc.select("noscript")
        for noscript in noscripts {
            guard let extractedImage = try extractSingleImage(fromNoscript: noscript) else {
                continue
            }

            guard let prevElement = try? noscript.previousElementSibling(),
                  isSingleImage(prevElement) else {
                continue
            }

            let prevImg: Element?
            if prevElement.tagName().uppercased() == "IMG" {
                prevImg = prevElement
            } else {
                prevImg = try prevElement.select("img").first()
            }

            guard let oldImg = prevImg else { continue }
            try copyLegacyImageAttributes(from: oldImg, to: extractedImage)
            try prevElement.replaceWith(extractedImage)
        }
    }

    private func extractSingleImage(fromNoscript noscript: Element) throws -> Element? {
        let html = try noscript.html()
        let fragment = try SwiftSoup.parseBodyFragment(html)
        guard let body = fragment.body(),
              isSingleImage(body),
              let img = try body.select("img").first() else {
            return nil
        }
        return try DOMHelpers.cloneElement(img, in: doc)
    }

    private func isSingleImage(_ element: Element?) -> Bool {
        var current = element
        while let node = current {
            if node.tagName().uppercased() == "IMG" {
                return true
            }
            if node.children().count != 1 {
                return false
            }
            let text = (try? node.text())?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !text.isEmpty {
                return false
            }
            current = node.children().first
        }
        return false
    }

    private func copyLegacyImageAttributes(from oldImg: Element, to newImg: Element) throws {
        guard let attrs = oldImg.getAttributes() else { return }
        for attr in attrs {
            let key = attr.getKey()
            let value = attr.getValue()
            if value.isEmpty {
                continue
            }

            let lowerKey = key.lowercased()
            let looksLikeImageURL = value.range(
                of: "\\.(jpg|jpeg|png|webp)",
                options: [.regularExpression, .caseInsensitive]
            ) != nil
            guard lowerKey == "src" || lowerKey == "srcset" || looksLikeImageURL else {
                continue
            }

            let existing = (try? newImg.attr(key)) ?? ""
            if existing == value {
                continue
            }

            let targetKey = newImg.hasAttr(key) ? "data-old-\(key)" : key
            try newImg.attr(targetKey, value)
        }
    }

    private func prepDocument() throws {
        // Keep media/embed nodes for later scoring/cleaning. Mozilla only strips
        // style tags at prep stage and defers iframe/embed pruning to article cleaning.
        let elementsToRemove = try doc.select("script, style, noscript, object, embed, template")
        try elementsToRemove.remove()

        try removeHiddenElements()
        try replaceBrs()
        try replaceFontTags()
    }

    /// Remove hidden elements from the document
    /// Handles aria-hidden, hidden attribute, display:none, and visibility:hidden
    private func removeHiddenElements() throws {
        try VisibilityRules.removeHiddenElements(from: doc)
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
                    if DOMTraversal.isWhitespace(lastChild) {
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
            return ""
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

    private func removeTitleMatchedHeaders(from element: Element, title: String) throws {
        let normalizedTitle = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .lowercased()

        guard !normalizedTitle.isEmpty else { return }

        let headers = try element.select("h1, h2")
        for header in headers {
            let text = (try? header.text()) ?? ""
            let normalizedHeader = text
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .lowercased()

            if normalizedHeader == normalizedTitle {
                try header.remove()
            }
        }
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

        doc.outputSettings().prettyPrint(pretty: false)

        return try cleaned.html()
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
        let documentURL = URL(string: doc.location())
        let effectiveBaseURL: URL? = {
            guard let baseElement = try? doc.select("base[href]").first(),
                  let rawBaseHref = try? baseElement.attr("href") else {
                return documentURL
            }

            let trimmedBaseHref = rawBaseHref.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedBaseHref.isEmpty else { return documentURL }

            if let docURL = documentURL,
               let resolved = URL(string: trimmedBaseHref, relativeTo: docURL)?.absoluteURL {
                return resolved
            }

            return URL(string: trimmedBaseHref) ?? documentURL
        }()
        let baseMatchesDocument = effectiveBaseURL?.absoluteString == documentURL?.absoluteString

        func toAbsoluteURI(_ rawURI: String) -> String {
            let uri = rawURI.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !uri.isEmpty else { return rawURI }

            // Keep data URLs verbatim to match Mozilla/jsdom behavior.
            if uri.lowercased().hasPrefix("data:") {
                return uri
            }

            if uri.hasPrefix("#"), baseMatchesDocument {
                return uri
            }

            if let base = effectiveBaseURL,
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
                    let text: String
                    if let textNode = link.getChildNodes().first as? TextNode {
                        // Preserve original whitespace around inline links.
                        text = textNode.getWholeText()
                    } else {
                        text = try link.text()
                    }
                    let replacement = TextNode(text, doc.location())
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

            let srcset = (try? media.attr("srcset")) ?? ""
            if !srcset.isEmpty {
                let pattern = "(\\S+)(\\s+[\\d.]+[xw])?(\\s*(?:,|$))"
                if let regex = try? NSRegularExpression(pattern: pattern) {
                    let nsRange = NSRange(srcset.startIndex..<srcset.endIndex, in: srcset)
                    let matches = regex.matches(in: srcset, options: [], range: nsRange)
                    var rewritten = srcset
                    for match in matches.reversed() {
                        guard match.numberOfRanges >= 4,
                              let totalRange = Range(match.range(at: 0), in: rewritten),
                              let r1 = Range(match.range(at: 1), in: srcset),
                              let r2 = Range(match.range(at: 2), in: srcset),
                              let r3 = Range(match.range(at: 3), in: srcset) else {
                            continue
                        }
                        let rawURL = String(srcset[r1])
                        let descriptor = String(srcset[r2])
                        let trailing = String(srcset[r3])
                        let replacement = toAbsoluteURI(rawURL) + descriptor + trailing
                        rewritten.replaceSubrange(totalRange, with: replacement)
                    }
                    try media.attr("srcset", rewritten)
                }
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
                            let key = attr.getKey().lowercased()
                            if child.tagName().lowercased() == "p" && key == "dir" {
                                continue
                            }
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
