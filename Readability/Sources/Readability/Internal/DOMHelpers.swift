import Foundation
import SwiftSoup

/// Helper functions for DOM manipulation
enum DOMHelpers {
    /// Get inner text of an element (similar to textContent in JS)
    static func getInnerText(_ element: Element, normalizeSpaces: Bool = true) throws -> String {
        let text = try element.text()
        if normalizeSpaces {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        }
        return text
    }

    /// Get character count of element's text
    static func getCharCount(_ element: Element) throws -> Int {
        return try getInnerText(element).count
    }

    /// Check if element has a child with the given tag name
    static func hasChildBlockElement(_ element: Element) throws -> Bool {
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

    /// Determine if a node should be considered for content extraction
    static func isProbablyVisible(_ element: Element) -> Bool {
        // Check for display:none or visibility:hidden
        if let style = try? element.attr("style").lowercased() {
            if style.contains("display:none") || style.contains("visibility:hidden") {
                return false
            }
        }
        // Check for aria-hidden="true"
        if let ariaHidden = try? element.attr("aria-hidden").lowercased(), ariaHidden == "true" {
            return false
        }
        return true
    }

    /// Get the class name and id as a single string for pattern matching
    static func getClassAndId(_ element: Element) -> String {
        let className = (try? element.className()) ?? ""
        let id = element.id()
        return "\(className) \(id)".lowercased()
    }

    /// Check if class/id matches any pattern in the list
    static func matchesPatterns(_ text: String, patterns: [String]) -> Bool {
        return patterns.contains { pattern in
            text.contains(pattern.lowercased())
        }
    }

    /// Set element tag name by replacing the element
    static func setTagName(_ element: Element, newTag: String) throws -> Element {
        let doc = element.ownerDocument() ?? Document("")
        let replacement = try doc.createElement(newTag.lowercased())
        for child in element.children() {
            try replacement.appendChild(child)
        }
        try element.replaceWith(replacement)
        return replacement
    }

    /// Clone an element into document context
    /// Preserves the original order of child nodes (elements and text)
    /// - Parameters:
    ///   - element: Element to clone
    ///   - doc: Document for creating the clone
    /// - Returns: Cloned element with proper document ownership
    static func cloneElement(_ element: Element, in doc: Document) throws -> Element {
        let clone = try doc.createElement(element.tagName())

        // Copy attributes
        if let attributes = element.getAttributes() {
            for attr in attributes {
                try clone.attr(attr.getKey(), attr.getValue())
            }
        }

        // Clone all child nodes in their original order
        // Use getChildNodes() to preserve mixed element/text order
        for node in element.getChildNodes() {
            if let childElement = node as? Element {
                // Recursively clone element children
                let childClone = try cloneElement(childElement, in: doc)
                try clone.appendChild(childClone)
            } else if let textNode = node as? TextNode {
                // Clone text nodes in their original position
                try clone.appendText(textNode.text())
            }
        }

        return clone
    }
}
