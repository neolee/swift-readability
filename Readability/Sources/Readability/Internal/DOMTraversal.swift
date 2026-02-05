import Foundation
import SwiftSoup

/// DOM traversal utilities for Readability
/// Mirrors Mozilla Readability.js traversal functions
enum DOMTraversal {

    /// Get the next node in a depth-first traversal
    /// - Parameters:
    ///   - node: Current node
    ///   - ignoreSelfAndKids: If true, skip the current node and its children
    /// - Returns: Next node in traversal order, or nil if at end
    static func getNextNode(_ node: Element?, ignoreSelfAndKids: Bool = false) -> Element? {
        guard let node = node else { return nil }

        // First check for kids if those aren't being ignored
        if !ignoreSelfAndKids {
            if let firstChild = node.children().first {
                return firstChild
            }
        }

        // Then for siblings
        if let nextSibling = try? node.nextElementSibling() {
            return nextSibling
        }

        // And finally, move up the parent chain and find a sibling
        var current: Element? = node
        while let parent = current?.parent() {
            if let sibling = try? parent.nextElementSibling() {
                return sibling
            }
            current = parent
        }

        return nil
    }

    /// Remove a node and return the next node for traversal
    /// - Parameter node: Node to remove
    /// - Returns: Next node in traversal order
    @discardableResult
    static func removeAndGetNext(_ node: Element) -> Element? {
        let nextNode = getNextNode(node, ignoreSelfAndKids: true)
        try? node.remove()
        return nextNode
    }

    /// Get ancestors of a node up to a maximum depth
    /// - Parameters:
    ///   - node: Starting node
    ///   - maxDepth: Maximum number of ancestors to collect (0 = unlimited)
    /// - Returns: Array of ancestor elements, ordered from immediate parent to root
    static func getNodeAncestors(_ node: Element, maxDepth: Int = 0) -> [Element] {
        var ancestors: [Element] = []
        var current: Element? = node
        var depth = 0

        while let parent = current?.parent() {
            ancestors.append(parent)
            depth += 1
            if maxDepth > 0 && depth >= maxDepth {
                break
            }
            current = parent
        }

        return ancestors
    }

    /// Check if a node has an ancestor with the given tag name
    /// - Parameters:
    ///   - node: Node to check
    ///   - tagName: Tag name to look for (case-insensitive)
    ///   - maxDepth: Maximum depth to search (0 = unlimited, default 3)
    ///   - filter: Optional filter function for the ancestor
    /// - Returns: True if matching ancestor found
    static func hasAncestorTag(
        _ node: Element,
        tagName: String,
        maxDepth: Int = 3,
        filter: ((Element) -> Bool)? = nil
    ) -> Bool {
        let upperTagName = tagName.uppercased()
        var current: Element? = node
        var depth = 0

        while let parent = current?.parent() {
            if maxDepth > 0 && depth > maxDepth {
                return false
            }

            if parent.tagName().uppercased() == upperTagName {
                if let filter = filter {
                    if filter(parent) {
                        return true
                    }
                } else {
                    return true
                }
            }

            depth += 1
            current = parent
        }

        return false
    }

    /// Check if a node has a single tag inside it
    /// - Parameters:
    ///   - element: Element to check
    ///   - tag: Tag name to look for (case-insensitive)
    /// - Returns: True if element has exactly one child with the given tag and no text content
    static func hasSingleTagInsideElement(_ element: Element, tag: String) -> Bool {
        let children = element.children()

        // Should have exactly 1 element child with given tag
        guard children.count == 1,
              children.first?.tagName().uppercased() == tag.uppercased() else {
            return false
        }

        // And should have no text nodes with real content
        // Check textNodes for text content
        let textNodes = element.textNodes()
        for textNode in textNodes {
            let trimmed = textNode.text().trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return false
            }
        }

        return true
    }

    /// Check if element has no meaningful content
    /// - Parameter node: Element to check
    /// - Returns: True if element has no text content or only contains br/hr elements
    static func isElementWithoutContent(_ node: Element) -> Bool {
        let textContent = (try? node.text()) ?? ""
        let trimmedText = textContent.trimmingCharacters(in: .whitespacesAndNewlines)

        // No text content
        if trimmedText.isEmpty {
            let children = node.children()

            // No children at all
            if children.isEmpty {
                return true
            }

            // Only br/hr elements
            let nonBreakChildren = children.filter { child in
                let tag = child.tagName().lowercased()
                return tag != "br" && tag != "hr"
            }

            return nonBreakChildren.isEmpty
        }

        return false
    }

    /// Check if node is a whitespace node (empty text or br element)
    /// - Parameter node: Node to check
    /// - Returns: True if node is whitespace
    static func isWhitespace(_ node: Node) -> Bool {
        if let textNode = node as? TextNode {
            return textNode.text().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if let element = node as? Element {
            return element.tagName().lowercased() == "br"
        }
        return false
    }

    /// Get all nodes with specified tags
    /// - Parameters:
    ///   - node: Root node to search from
    ///   - tagNames: Array of tag names to find
    /// - Returns: Array of matching elements
    static func getAllNodesWithTag(_ node: Element, tagNames: [String]) throws -> [Element] {
        let selector = tagNames.joined(separator: ", ")
        return try node.select(selector).array()
    }
}

// MARK: - Element Extension for Convenience

extension Element {
    /// Get the next element in depth-first traversal
    func nextNode(ignoreSelfAndKids: Bool = false) -> Element? {
        return DOMTraversal.getNextNode(self, ignoreSelfAndKids: ignoreSelfAndKids)
    }

    /// Remove this element and get the next element for traversal
    @discardableResult
    func removeAndGetNext() -> Element? {
        return DOMTraversal.removeAndGetNext(self)
    }

    /// Get ancestors of this element
    func ancestors(maxDepth: Int = 0) -> [Element] {
        return DOMTraversal.getNodeAncestors(self, maxDepth: maxDepth)
    }

    /// Check if this element has an ancestor with the given tag
    func hasAncestor(tagName: String, maxDepth: Int = 3, filter: ((Element) -> Bool)? = nil) -> Bool {
        return DOMTraversal.hasAncestorTag(self, tagName: tagName, maxDepth: maxDepth, filter: filter)
    }
}
