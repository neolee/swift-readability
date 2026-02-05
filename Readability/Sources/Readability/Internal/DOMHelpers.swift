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
    static func setTagName(_ element: Element, newTag: String, baseUri: String) throws -> Element {
        let replacement = Element(Tag(newTag.lowercased()), baseUri)
        for child in element.children() {
            try replacement.appendChild(child)
        }
        try element.replaceWith(replacement)
        return replacement
    }
}
