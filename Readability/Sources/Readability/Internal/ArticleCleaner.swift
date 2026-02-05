import Foundation
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
        // Clean styles
        try cleanStyles(articleContent)

        // Fix lazy images
        try fixLazyImages(articleContent)

        // Remove unwanted elements
        try removeUnwantedElements(articleContent)

        // Convert DIVs to Ps where appropriate
        try convertDivsToParagraphs(articleContent)

        // Simplify nested elements
        try simplifyNestedElements(articleContent)
    }

    // MARK: - DIV to P Conversion

    /// Convert DIV elements to P elements where appropriate
    /// This implements Mozilla's div-to-p conversion logic
    private func convertDivsToParagraphs(_ element: Element) throws {
        let divs = try element.select("div")

        for div in divs {
            // Skip if already converted
            guard div.tagName().lowercased() == "div" else { continue }

            // Check if div contains only phrasing content
            let hasBlockChildren = try hasChildBlockElement(div)

            if !hasBlockChildren {
                // Convert this div to a p
                _ = try setNodeTag(div, newTag: "p")
            } else {
                // Try to wrap consecutive phrasing content in p tags
                try wrapPhrasingContentInParagraphs(div)
            }
        }
    }

    /// Wrap consecutive phrasing content nodes in paragraph tags
    private func wrapPhrasingContentInParagraphs(_ element: Element) throws {
        var currentFragment: [Node] = []

        for child in element.children() {
            if isPhrasingContent(child) {
                currentFragment.append(child)
            } else {
                // Wrap collected phrasing content in p
                if !currentFragment.isEmpty {
                    try wrapNodesInParagraph(currentFragment, parent: element)
                    currentFragment.removeAll()
                }
            }
        }

        // Wrap any remaining phrasing content
        if !currentFragment.isEmpty {
            try wrapNodesInParagraph(currentFragment, parent: element)
        }
    }

    /// Wrap a collection of nodes in a paragraph
    private func wrapNodesInParagraph(_ nodes: [Node], parent: Element) throws {
        guard !nodes.isEmpty else { return }

        let p = Element(Tag("p"), "")

        for node in nodes {
            if let clone = node.copy() as? Node {
                try p.appendChild(clone)
            }
        }

        // Only append if paragraph has content
        if try !p.text().isEmpty {
            try parent.appendChild(p)
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
        let blockElements = Set(["div", "blockquote", "ol", "ul", "li", "p", "pre", "table", "td", "th", "article", "section", "h1", "h2", "h3", "h4", "h5", "h6"])

        for child in element.children() {
            if blockElements.contains(child.tagName().lowercased()) {
                return true
            }
            if try hasChildBlockElement(child) {
                return true
            }
        }

        return false
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
    func setNodeTag(_ element: Element, newTag: String) throws -> Element {
        let newElement = Element(Tag(newTag.lowercased()), "")

        // Copy attributes
        if let attributes = element.getAttributes() {
            for attr in attributes {
                try newElement.attr(attr.getKey(), attr.getValue())
            }
        }

        // Copy children
        for child in element.children() {
            if let clone = child.copy() as? Element {
                try newElement.appendChild(clone)
            }
        }

        // Copy text nodes
        for textNode in element.textNodes() {
            try newElement.appendText(textNode.text())
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

        // Remove elements with hidden attribute
        try element.select("[hidden]").remove()

        // Remove elements with aria-hidden="true"
        try element.select("[aria-hidden=true]").remove()

        // Remove elements with display:none or visibility:hidden in style
        let allElements = try element.select("*[style]")
        for el in allElements {
            if let style = try? el.attr("style").lowercased() {
                // Remove whitespace and check
                let normalized = style.replacingOccurrences(of: " ", with: "")
                if normalized.contains("display:none") || normalized.contains("visibility:hidden") {
                    try el.remove()
                }
            }
        }
    }

    // MARK: - Nested Element Simplification

    /// Simplify nested elements (e.g., div > div > p becomes just p)
    private func simplifyNestedElements(_ element: Element) throws {
        let divsAndSections = try element.select("div, section")

        for node in divsAndSections {
            // Check if element has no content
            if DOMTraversal.isElementWithoutContent(node) {
                try node.remove()
                continue
            }

            // Check for single nested div/section
            if hasSingleTagInsideElement(node, tag: "DIV") ||
               hasSingleTagInsideElement(node, tag: "SECTION") {
                let child = node.children().first!

                // Copy attributes from parent to child
                if let attributes = node.getAttributes() {
                    for attr in attributes {
                        let key = attr.getKey()
                        if !child.hasAttr(key) {
                            try child.attr(key, attr.getValue())
                        }
                    }
                }

                try node.replaceWith(child)
            }
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
            // Check for single row
            let rows = try table.select("tr")
            guard rows.count == 1 else { continue }

            let row = rows.first!
            let cells = try row.select("td, th")
            guard cells.count == 1 else { continue }

            let cell = cells.first!

            // Determine new tag based on content
            let allPhrasing = cell.children().allSatisfy { isPhrasingContent($0) }
            let newTag = allPhrasing ? "p" : "div"

            let newElement = try setNodeTag(cell, newTag: newTag)
            try table.replaceWith(newElement)
        }
    }
}
