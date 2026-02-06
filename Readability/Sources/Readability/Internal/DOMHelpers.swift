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

    /// Determine if a node should be considered for content extraction
    static func isProbablyVisible(_ element: Element) -> Bool {
        return VisibilityRules.isProbablyVisibleForScoring(element)
    }

    /// Get the class name and id as a single string for pattern matching
    static func getClassAndId(_ element: Element) -> String {
        let className = (try? element.className()) ?? ""
        let id = element.id()
        return "\(className) \(id)".lowercased()
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

    /// Copy all attributes from source to target.
    static func copyAttributes(from source: Element, to target: Element) throws {
        if let attributes = source.getAttributes() {
            for attr in attributes {
                try target.attr(attr.getKey(), attr.getValue())
            }
        }
    }

    /// Clone all child nodes from source into target preserving node order.
    static func cloneChildNodes(from source: Element, to target: Element, in doc: Document) throws {
        for node in source.getChildNodes() {
            if let childElement = node as? Element {
                let childClone = try cloneElement(childElement, in: doc)
                try target.appendChild(childClone)
            } else if let textNode = node as? TextNode {
                // Preserve original whitespace; TextNode.text() normalizes spaces.
                let textClone = TextNode(textNode.getWholeText(), doc.location())
                try target.appendChild(textClone)
            }
        }
    }

    /// Clone an element into document context
    /// Preserves the original order of child nodes (elements and text)
    /// - Parameters:
    ///   - element: Element to clone
    ///   - doc: Document for creating the clone
    /// - Returns: Cloned element with proper document ownership
    static func cloneElement(_ element: Element, in doc: Document) throws -> Element {
        let clone = try doc.createElement(element.tagName())
        try copyAttributes(from: element, to: clone)
        try cloneChildNodes(from: element, to: clone, in: doc)

        return clone
    }
}
