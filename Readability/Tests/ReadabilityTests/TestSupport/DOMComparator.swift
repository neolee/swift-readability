import Foundation
import SwiftSoup

/// DOM comparison utility for Mozilla compatibility assertions.
enum DOMComparator {
    /// Compare two DOM structures and return detailed diff.
    /// Mirrors Mozilla-style structural traversal:
    /// - In-order node traversal
    /// - Ignore empty text nodes
    /// - Compare node descriptors, text content, and attributes
    static func compare(_ actualHTML: String, _ expectedHTML: String) -> (isEqual: Bool, diff: String) {
        do {
            let actualParsed = try SwiftSoup.parse(actualHTML)
            let expectedParsed = try SwiftSoup.parse(expectedHTML)
            let actualDoc = try SwiftSoup.parse(actualParsed.outerHtml())
            let expectedDoc = try SwiftSoup.parse(expectedParsed.outerHtml())

            guard let actualRoot = domRoot(actualDoc),
                  let expectedRoot = domRoot(expectedDoc) else {
                return (false, "DOM comparison error: missing root node")
            }

            let actualNodes = flattenedDOMNodes(from: actualRoot)
            let expectedNodes = flattenedDOMNodes(from: expectedRoot)

            let maxCount = max(actualNodes.count, expectedNodes.count)
            for index in 0..<maxCount {
                guard index < actualNodes.count, index < expectedNodes.count else {
                    let actualTail = actualNodes.suffix(3).map { "\(nodeDescription($0)) @ \(nodePath($0))" }.joined(separator: " | ")
                    let expectedTail = expectedNodes.suffix(3).map { "\(nodeDescription($0)) @ \(nodePath($0))" }.joined(separator: " | ")
                    return (
                        false,
                        "DOM node count mismatch at index \(index). Expected \(expectedNodes.count) nodes, got \(actualNodes.count) nodes. Expected tail: \(expectedTail). Actual tail: \(actualTail)."
                    )
                }

                let actualNode = actualNodes[index]
                let expectedNode = expectedNodes[index]

                let actualDesc = nodeDescription(actualNode)
                let expectedDesc = nodeDescription(expectedNode)
                if actualDesc != expectedDesc {
                    let actualPath = nodePath(actualNode)
                    let expectedPath = nodePath(expectedNode)
                    if let actualTextNode = actualNode as? TextNode,
                       let expectedTextNode = expectedNode as? TextNode {
                        let actualContext = (actualTextNode.parent() as? Element).flatMap { try? $0.outerHtml() } ?? ""
                        let expectedContext = (expectedTextNode.parent() as? Element).flatMap { try? $0.outerHtml() } ?? ""
                        return (
                            false,
                            "Node descriptor mismatch at index \(index). Expected: \(expectedDesc), Actual: \(actualDesc). Expected path: \(expectedPath). Actual path: \(actualPath). Expected context: '\(preview(expectedContext, limit: 220))'. Actual context: '\(preview(actualContext, limit: 220))'."
                        )
                    }
                    let actualContext = (actualNode as? Element).flatMap { try? $0.outerHtml() } ?? ""
                    let expectedContext = (expectedNode as? Element).flatMap { try? $0.outerHtml() } ?? ""
                    return (
                        false,
                        "Node descriptor mismatch at index \(index). Expected: \(expectedDesc), Actual: \(actualDesc). Expected path: \(expectedPath). Actual path: \(actualPath). Expected context: '\(preview(expectedContext, limit: 220))'. Actual context: '\(preview(actualContext, limit: 220))'."
                    )
                }

                if let actualTextNode = actualNode as? TextNode,
                   let expectedTextNode = expectedNode as? TextNode {
                    let actualText = normalizeHTMLText(actualTextNode.getWholeText())
                    let expectedText = normalizeHTMLText(expectedTextNode.getWholeText())
                    if actualText != expectedText {
                        let actualContext = (actualTextNode.parent() as? Element).flatMap { try? $0.outerHtml() } ?? ""
                        let expectedContext = (expectedTextNode.parent() as? Element).flatMap { try? $0.outerHtml() } ?? ""
                        return (
                            false,
                            "Text mismatch at index \(index). Expected: '\(preview(expectedText))', Actual: '\(preview(actualText))'. Expected context: '\(preview(expectedContext, limit: 220))'. Actual context: '\(preview(actualContext, limit: 220))'."
                        )
                    }
                } else if let actualElement = actualNode as? Element,
                          let expectedElement = expectedNode as? Element {
                    let actualAttrs = attributesForNode(actualElement)
                    let expectedAttrs = attributesForNode(expectedElement)
                    if actualAttrs.count != expectedAttrs.count {
                        let actualPath = nodePath(actualElement)
                        let expectedPath = nodePath(expectedElement)
                        return (
                            false,
                            "Attribute count mismatch at index \(index) for \(actualElement.tagName().lowercased()). Expected \(expectedAttrs.count), got \(actualAttrs.count). Expected attrs: \(expectedAttrs), Actual attrs: \(actualAttrs). Expected path: \(expectedPath). Actual path: \(actualPath)."
                        )
                    }
                    for (key, expectedValue) in expectedAttrs {
                        guard let actualValue = actualAttrs[key] else {
                            let actualPath = nodePath(actualElement)
                            let expectedPath = nodePath(expectedElement)
                            return (
                                false,
                                "Missing attribute at index \(index): '\(key)' on \(actualElement.tagName().lowercased()). Expected path: \(expectedPath). Actual path: \(actualPath)."
                            )
                        }
                        if actualValue != expectedValue {
                            let actualPath = nodePath(actualElement)
                            let expectedPath = nodePath(expectedElement)
                            return (
                                false,
                                "Attribute mismatch at index \(index): '\(key)'. Expected '\(preview(expectedValue))', got '\(preview(actualValue))'. Expected path: \(expectedPath). Actual path: \(actualPath)."
                            )
                        }
                    }
                }
            }

            return (true, "DOM structures match")
        } catch {
            return (false, "DOM comparison error: \(error)")
        }
    }

    private static func normalizeHTMLText(_ str: String) -> String {
        return str
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func domRoot(_ doc: Document) -> Node? {
        if let root = doc.children().first {
            return root
        }
        if let body = doc.body() {
            return body
        }
        return nil
    }

    private static func flattenedDOMNodes(from root: Node) -> [Node] {
        var nodes: [Node] = []
        collectNodesInOrder(root, into: &nodes)
        return nodes.filter { !isIgnorableTextNode($0) }
    }

    private static func collectNodesInOrder(_ node: Node, into nodes: inout [Node]) {
        nodes.append(node)
        for child in node.getChildNodes() {
            collectNodesInOrder(child, into: &nodes)
        }
    }

    private static func isIgnorableTextNode(_ node: Node) -> Bool {
        guard let textNode = node as? TextNode else { return false }
        return textNode.getWholeText().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func nodeDescription(_ node: Node) -> String {
        if node is TextNode {
            // Node shape comparison should treat text nodes structurally;
            // text content is compared separately with normalized whitespace.
            return "#text"
        }
        if let element = node as? Element {
            var desc = element.tagName().lowercased()
            let id = element.id()
            if !id.isEmpty {
                desc += "#\(id)"
            }
            if let className = try? element.className(), !className.isEmpty {
                desc += ".(\(className))"
            }
            return desc
        }
        return "node(\(node.nodeName()))"
    }

    private static func attributesForNode(_ element: Element) -> [String: String] {
        var attrs: [String: String] = [:]
        guard let attributes = element.getAttributes() else { return attrs }

        for attr in attributes {
            let key = attr.getKey()
            if isValidXMLAttributeName(key) {
                attrs[key] = attr.getValue()
            }
        }
        return attrs
    }

    private static func isValidXMLAttributeName(_ name: String) -> Bool {
        let pattern = "^[A-Za-z_][A-Za-z0-9._:-]*$"
        return name.range(of: pattern, options: .regularExpression) != nil
    }

    private static func preview(_ text: String, limit: Int = 80) -> String {
        if text.count <= limit { return text }
        return String(text.prefix(limit)) + "..."
    }

    private static func nodePath(_ node: Node) -> String {
        var parts: [String] = []
        var current: Node? = node

        while let n = current {
            if let element = n as? Element {
                let tag = element.tagName().lowercased()
                var position = 1
                if let parent = element.parent() {
                    for sibling in parent.getChildNodes() {
                        guard sibling !== element else { break }
                        if let siblingElement = sibling as? Element,
                           siblingElement.tagName().lowercased() == tag {
                            position += 1
                        }
                    }
                }
                parts.append("\(tag)[\(position)]")
            } else if n is TextNode {
                parts.append("text()")
            } else {
                parts.append(n.nodeName())
            }
            current = n.parent()
        }

        return "/" + parts.reversed().joined(separator: "/")
    }
}
