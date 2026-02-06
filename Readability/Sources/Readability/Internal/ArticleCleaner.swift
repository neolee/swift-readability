import Foundation
import SwiftSoup

/// Cleans and prepares article content after extraction
/// Implements Mozilla Readability.js _prepArticle and related methods
final class ArticleCleaner {
    private let options: ReadabilityOptions

    init(options: ReadabilityOptions) {
        self.options = options
    }

    // MARK: - Main Article Preparation

    /// Prepare article content for output
    /// This is the main entry point for article cleaning
    func prepArticle(_ articleContent: Element) throws {
        // Remove unwanted elements FIRST (before cleanStyles removes class attributes)
        try removeUnwantedElements(articleContent)

        // Clean styles
        try cleanStyles(articleContent)

        // Fix lazy images
        try fixLazyImages(articleContent)

        // Convert DIVs to Ps where appropriate
        try convertDivsToParagraphs(articleContent)
    }

    // MARK: - DIV to P Conversion

    /// Convert DIV elements to P elements where appropriate
    /// This implements Mozilla's div-to-p conversion logic
    private func convertDivsToParagraphs(_ element: Element) throws {
        let divs = try element.select("div")

        for div in divs {
            // Skip if already converted
            guard div.tagName().lowercased() == "div" else { continue }
            // Skip detached top-level container created after extraction.
            guard div.parent() != nil else { continue }

            // Put consecutive phrasing content into paragraphs.
            var childNode = div.getChildNodes().first
            while let current = childNode {
                var nextSibling = current.nextSibling()

                if isPhrasingContent(current) {
                    var fragment: [Node] = []
                    var cursor: Node? = current

                    // Collect consecutive phrasing nodes.
                    while let phrasingNode = cursor, isPhrasingContent(phrasingNode) {
                        nextSibling = phrasingNode.nextSibling()
                        fragment.append(phrasingNode)
                        cursor = nextSibling
                    }

                    // Trim surrounding whitespace / <br> from the fragment.
                    while let first = fragment.first, DOMTraversal.isWhitespace(first) {
                        try first.remove()
                        fragment.removeFirst()
                    }
                    while let last = fragment.last, DOMTraversal.isWhitespace(last) {
                        try last.remove()
                        fragment.removeLast()
                    }

                    // Wrap non-empty fragment with a <p>.
                    if !fragment.isEmpty {
                        let doc = div.ownerDocument() ?? Document("")
                        let p = try doc.createElement("p")

                        if let next = nextSibling {
                            try next.before(p)
                        } else {
                            try div.appendChild(p)
                        }

                        for node in fragment where node.parent() != nil {
                            try p.appendChild(node)
                        }
                    }
                }

                childNode = nextSibling
            }

            // If DIV has exactly one P child and low link density, unwrap to that P.
            if hasSingleTagInsideElement(div, tag: "P"), try getLinkDensity(div) < 0.25 {
                if let onlyChild = div.children().first {
                    try div.replaceWith(onlyChild)
                }
                continue
            }

            // Otherwise, if no block children remain, convert DIV to P.
            if !(try hasChildBlockElement(div)) {
                _ = try setNodeTag(div, newTag: "p")
            }
        }
    }

    /// Check if element has a single tag inside it
    func hasSingleTagInsideElement(_ element: Element, tag: String) -> Bool {
        let children = element.children()

        // Should have exactly 1 element child with given tag
        guard children.count == 1,
              children.first?.tagName().uppercased() == tag.uppercased() else {
            return false
        }

        // And should have no text nodes with real content
        let textNodes = element.textNodes()
        for textNode in textNodes {
            let trimmed = textNode.text().trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return false
            }
        }

        return true
    }

    /// Check if element has any block-level children
    func hasChildBlockElement(_ element: Element) throws -> Bool {
        let blockElements = Set(Configuration.divToPElements.map { $0.lowercased() })

        for childNode in element.getChildNodes() {
            guard let child = childNode as? Element else { continue }
            if blockElements.contains(child.tagName().lowercased()) {
                return true
            }
            if try hasChildBlockElement(child) {
                return true
            }
        }

        return false
    }

    private func getLinkDensity(_ element: Element) throws -> Double {
        let textLength = try DOMHelpers.getInnerText(element).count
        if textLength == 0 {
            return 0
        }

        let links = try element.select("a")
        var linkLength = 0.0
        for link in links {
            let href = (try? link.attr("href")) ?? ""
            let coefficient = href.hasPrefix("#") ? 0.3 : 1.0
            linkLength += Double(try DOMHelpers.getInnerText(link).count) * coefficient
        }

        return linkLength / Double(textLength)
    }

    /// Check if node is phrasing content (inline content)
    func isPhrasingContent(_ node: Node) -> Bool {
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

    // MARK: - Tag Name Change

    /// Change the tag name of an element
    /// Creates a new element with the given tag and moves all content
    /// Preserves the original order of child nodes (elements and text)
    func setNodeTag(_ element: Element, newTag: String) throws -> Element {
        // Get document context from element
        let doc = element.ownerDocument() ?? Document("")
        let newElement = try doc.createElement(newTag.lowercased())

        try DOMHelpers.copyAttributes(from: element, to: newElement)
        // Match Mozilla semantics: move nodes instead of cloning to avoid any
        // possibility of duplicate/reordered child content during retagging.
        while let firstChild = element.getChildNodes().first {
            try newElement.appendChild(firstChild)
        }

        // Replace in DOM
        try element.replaceWith(newElement)

        return newElement
    }

    // MARK: - Style Cleaning

    /// Remove style attributes and presentational attributes
    private func cleanStyles(_ element: Element) throws {
        if !options.keepClasses {
            // Remove presentational attributes
            for attr in Configuration.presentationalAttributes {
                try element.removeAttr(attr)
            }

            // Remove deprecated size attributes for specific elements
            if Configuration.deprecatedSizeAttributeElems.contains(element.tagName().uppercased()) {
                try element.removeAttr("width")
                try element.removeAttr("height")
            }

            // Clean classes (keep only preserved classes)
            let className = try element.className()
            let preservedClasses = Configuration.classesToPreserve + options.classesToPreserve
            let newClasses = className.split(separator: " ").filter { cls in
                preservedClasses.contains(String(cls))
            }.joined(separator: " ")

            if newClasses.isEmpty {
                try element.removeAttr("class")
            } else {
                try element.attr("class", newClasses)
            }
        }

        // Recursively clean children
        for child in element.children() {
            try cleanStyles(child)
        }
    }

    // MARK: - Lazy Image Fixing

    /// Fix lazy-loaded images by converting data-src to src
    private func fixLazyImages(_ element: Element) throws {
        let images = try element.select("img, picture, figure")

        for img in images {
            // Check for data-src attributes
            if let attributes = img.getAttributes() {
                for attr in attributes {
                    let key = attr.getKey().lowercased()
                    let value = attr.getValue()

                    // Common lazy loading patterns
                    if key.hasPrefix("data-") && (key.contains("src") || key.contains("original")) {
                        // Check if it looks like an image URL
                        if value.range(of: "\\.(jpg|jpeg|png|webp|gif)", options: .regularExpression) != nil {
                            try img.attr("src", value)
                            break
                        }
                    }
                }
            }
        }
    }

    // MARK: - Unwanted Element Removal

    /// Remove unwanted elements from article content
    private func removeUnwantedElements(_ element: Element) throws {
        // Remove script and style tags
        try element.select("script, style, noscript").remove()
        // Match Mozilla _clean() defaults for obvious non-article containers.
        try element.select("footer, aside, object, embed, link").remove()

        // Remove elements with hidden attribute
        try VisibilityRules.removeHiddenElements(from: element)

        // Remove share/social elements
        try removeShareElements(element)
    }

    /// Remove share/social elements from article content
    private func removeShareElements(_ element: Element) throws {
        // Build a combined selector for efficiency
        // Match elements where class contains share patterns
        var selectors: [String] = []
        for pattern in Configuration.shareElements {
            selectors.append("[class*=\(pattern)]")
            selectors.append("[id*=\(pattern)]")
        }

        if !selectors.isEmpty {
            let combinedSelector = selectors.joined(separator: ", ")
            let found = try element.select(combinedSelector)
            try found.remove()
        }
    }

    // MARK: - Header Cleaning

    /// Clean headers that are likely not part of the content
    func cleanHeaders(_ element: Element) throws {
        let headers = try element.select("h1, h2")

        for header in headers {
            let classWeight = getClassWeight(header)
            if classWeight < 0 {
                try header.remove()
            }
        }
    }

    /// Get class/id weight for an element
    private func getClassWeight(_ element: Element) -> Double {
        var weight: Double = 0
        let classAndId = DOMHelpers.getClassAndId(element)

        if Configuration.negativePatterns.contains(where: { classAndId.contains($0) }) {
            weight -= 25
        }
        if Configuration.positivePatterns.contains(where: { classAndId.contains($0) }) {
            weight += 25
        }

        return weight
    }

    // MARK: - Single Cell Table Handling

    /// Convert single-cell tables to divs or ps
    func handleSingleCellTables(_ element: Element) throws {
        let tables = try element.select("table")

        for table in tables {
            let tbody: Element
            if hasSingleTagInsideElement(table, tag: "TBODY"), let firstChild = table.children().first {
                tbody = firstChild
            } else {
                tbody = table
            }

            guard hasSingleTagInsideElement(tbody, tag: "TR"), let row = tbody.children().first else {
                continue
            }

            let cellTag: String
            if hasSingleTagInsideElement(row, tag: "TD") {
                cellTag = "TD"
            } else if hasSingleTagInsideElement(row, tag: "TH") {
                cellTag = "TH"
            } else {
                continue
            }

            guard row.children().count == 1,
                  let cell = row.children().first,
                  cell.tagName().uppercased() == cellTag else {
                continue
            }

            // Determine new tag based on content
            let allPhrasing = cell.getChildNodes().allSatisfy { isPhrasingContent($0) }
            let newTag = allPhrasing ? "p" : "div"

            let newElement = try setNodeTag(cell, newTag: newTag)
            if newTag == "p" {
                try newElement.removeAttr("dir")
            }
            try table.replaceWith(newElement)
        }
    }

    // MARK: - Post-Processing (_prepArticle functionality)

    /// Post-process article content (equivalent to Mozilla's _prepArticle)
    /// This should be called after the main content extraction is complete
    func postProcessArticle(_ articleContent: Element) throws {
        // Remove BR tags that should not remain in final output.
        try removeExtraBRs(articleContent)

        // Remove empty paragraphs
        try removeEmptyParagraphs(articleContent)

        // Replace H1 with H2 (H1 should only be the article title)
        try replaceH1WithH2(articleContent)

        // Flatten single-cell tables
        try handleSingleCellTables(articleContent)
    }

    /// Remove BR tags that appear before P tags or at the end of containers
    private func removeExtraBRs(_ element: Element) throws {
        let brs = try element.select("br")

        for br in brs {
            if shouldRemoveBRBeforeParagraph(br) {
                try br.remove()
            }
        }
    }

    /// Remove BR only when it is part of a BR chain that leads into a paragraph.
    /// Keep trailing BRs that are not followed by paragraph content.
    private func shouldRemoveBRBeforeParagraph(_ br: Element) -> Bool {
        var cursor = br.nextSibling()

        while let node = cursor {
            if let text = node as? TextNode {
                if text.text().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    cursor = node.nextSibling()
                    continue
                }
                return false
            }

            if let el = node as? Element {
                let tag = el.tagName().lowercased()
                if tag == "br" {
                    cursor = node.nextSibling()
                    continue
                }
                return tag == "p"
            }

            cursor = node.nextSibling()
        }

        return false
    }

    /// Remove empty paragraph elements
    private func removeEmptyParagraphs(_ element: Element) throws {
        let paragraphs = try element.select("p")

        for p in paragraphs {
            // Check if paragraph has no meaningful content
            let text = try p.text().trimmingCharacters(in: .whitespaces)

            // Check if it has no content elements (img, embed, object, iframe)
            let contentElements = try p.select("img, embed, object, iframe, video, audio").count

            if text.isEmpty && contentElements == 0 {
                try p.remove()
            }
        }
    }

    /// Replace H1 elements with H2 (H1 should be reserved for article title)
    private func replaceH1WithH2(_ element: Element) throws {
        let h1s = try element.select("h1")

        for h1 in h1s {
            _ = try setNodeTag(h1, newTag: "h2")
        }
    }
}
