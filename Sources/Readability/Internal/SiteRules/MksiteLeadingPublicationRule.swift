import Foundation
import SwiftSoup

/// Removes `mksite` lead publication metadata that leaks into article content.
///
/// The mksite template renders a leading metadata line that may include:
/// - `<b title="Publication"><time>` — original publication date
/// - `<b title="Last edit"><time>` — last-edit date
/// - separator text (` — `) between dates
/// - bracketed `<em>` labels such as `[Photo]`, `[Article]`
/// - `<a href="/tags/...">` taxonomy links
/// - `<note-box>` wrappers with skip links
///
/// This rule removes the entire metadata line, regardless of which combination
/// of these elements is present, so the article starts with body content.
///
/// SiteRule Metadata:
/// - Scope: `mksite`-generated pages with a leading publication badge
/// - Phase: `unwanted` cleanup
/// - Trigger: `meta[name=generator*='mksite']` plus leading direct children shaped like
///   `b[title=Publication] > time`, optionally followed by `/tags/...` links
/// - Evidence: `CLI/.staging/maurycyz`, `CLI/.staging/maurycyz-2`
/// - Risk if misplaced: legitimate lead metadata could be removed on unrelated generators
enum MksiteLeadingPublicationRule: ArticleCleanerSiteRule {
    static let id = "mksite-leading-publication"

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        let childNodes = articleContent.getChildNodes()
        guard let publicationIndex = leadingPublicationNodeIndex(in: childNodes),
              let publication = childNodes[publicationIndex] as? Element,
              try isLeadingPublicationElement(publication) else {
            return
        }

        var removalNodes: [Node] = [publication]
        var cursor = publicationIndex + 1
        var sawTagLink = false

        while cursor < childNodes.count {
            let node = childNodes[cursor]

            if let textNode = node as? TextNode {
                if isIgnorableSeparatorText(textNode.getWholeText()) {
                    removalNodes.append(textNode)
                    cursor += 1
                    continue
                }
                break
            }

            if node.nodeName() == "#comment" {
                removalNodes.append(node)
                cursor += 1
                continue
            }

            guard let element = node as? Element else { break }

            if try isLeadingTagLink(element) {
                removalNodes.append(element)
                sawTagLink = true
                cursor += 1
                continue
            }

            // Bracketed <em> labels like [Photo], [Article] are taxonomy
            // tags rendered by mksite templates. Collect them regardless of
            // whether /tags/ links were found.
            if !sawTagLink, try isLeadingBracketedLabel(element) {
                removalNodes.append(element)
                cursor += 1
                continue
            }

            // Subsequent date elements: "Last edit" and similar <b title> +
            // <time> combinations that appear after the Publication date.
            if try isLeadingDateElement(element) {
                removalNodes.append(element)
                cursor += 1
                continue
            }

            // <note-box> wrappers containing skip links are part of the
            // lead metadata line.
            if try isIgnorableMetadataWrapper(element) {
                removalNodes.append(element)
                cursor += 1
                continue
            }

            if try isIgnorableEmptyParagraph(element) {
                removalNodes.append(element)
                cursor += 1
                continue
            }

            break
        }

        guard sawTagLink,
              let nextElement = nextSignificantElement(in: childNodes, from: cursor),
              try matchesMksiteContextIfAvailable(articleContent, childNodes: childNodes),
              try isLeadMediaElement(nextElement) else {
            // No tag-link cluster found. If the date stands alone (no /tags/
            // links after it), remove the date, trailing whitespace, and any
            // bracketed <em> label such as [Photo]. This handles the
            // maurycyz-2 shape:
            //   <b title="Publication"><time>...</time></b> <em>[Photo]</em>
            if !sawTagLink,
               try matchesMksiteContextIfAvailable(articleContent, childNodes: childNodes) {
                for node in removalNodes.reversed() where node.parent() != nil {
                    try node.remove()
                }
            }
            return
        }

        for node in removalNodes.reversed() where node.parent() != nil {
            try node.remove()
        }
    }

    private static func matchesMksiteContextIfAvailable(_ articleContent: Element, childNodes: [Node]) throws -> Bool {
        if let document = articleContent.ownerDocument() {
            let generatorMetas = try document.select("meta[name=generator]")
            if !generatorMetas.isEmpty() {
                for meta in generatorMetas {
                    let content = ((try? meta.attr("content")) ?? "").lowercased()
                    if content.contains("mksite") {
                        return true
                    }
                }
                return false
            }
        }

        for node in childNodes {
            guard let comment = node as? Comment else { continue }
            if comment.getData().lowercased().contains("mksite") {
                return true
            }
        }

        // Extracted fragments can lose the original `<head>` metadata. When that
        // happens, rely on the exact lead-cluster shape checked in `apply()`.
        return true
    }

    private static func leadingPublicationNodeIndex(in nodes: [Node]) -> Int? {
        guard let firstIndex = nextSignificantNodeIndex(in: nodes, from: 0) else {
            return nil
        }

        if let dateEl = nodes[firstIndex] as? Element,
           (try? isLeadingDateElement(dateEl)) == true {
            return firstIndex
        }

        guard let heading = nodes[firstIndex] as? Element,
              isHeadingElement(heading),
              let secondIndex = nextSignificantNodeIndex(in: nodes, from: firstIndex + 1),
              let dateEl = nodes[secondIndex] as? Element,
              (try? isLeadingDateElement(dateEl)) == true else {
            return nil
        }

        return secondIndex
    }

    private static func nextSignificantNodeIndex(in nodes: [Node], from startIndex: Int) -> Int? {
        guard startIndex < nodes.count else { return nil }

        for index in startIndex..<nodes.count {
            let node = nodes[index]

            if let textNode = node as? TextNode {
                let text = textNode.getWholeText().trimmingCharacters(in: .whitespacesAndNewlines)
                if text.isEmpty {
                    continue
                }
                return index
            }

            if node.nodeName() == "#comment" {
                continue
            }

            return index
        }

        return nil
    }

    private static func nextSignificantElement(in nodes: [Node], from startIndex: Int) -> Element? {
        guard startIndex < nodes.count else { return nil }

        for index in startIndex..<nodes.count {
            let node = nodes[index]

            if let textNode = node as? TextNode {
                let text = textNode.getWholeText()
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continue
                }
                return nil
            }

            if node.nodeName() == "#comment" {
                continue
            }

            return node as? Element
        }

        return nil
    }

    private static func isLeadingPublicationElement(_ element: Element) throws -> Bool {
        guard element.tagName().lowercased() == "b" else { return false }
        let title = ((try? element.attr("title")) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.caseInsensitiveCompare("Publication") == .orderedSame else { return false }
        return (try? element.select("time").isEmpty()) == false
    }

    private static func isHeadingElement(_ element: Element) -> Bool {
        ["h1", "h2", "h3", "h4", "h5", "h6"].contains(element.tagName().lowercased())
    }

    private static func isLeadingTagLink(_ element: Element) throws -> Bool {
        guard element.tagName().lowercased() == "a" else { return false }
        let href = ((try? element.attr("href")) ?? "").lowercased()
        return href.contains("/tags/")
    }

    private static func isLeadingBracketedLabel(_ element: Element) throws -> Bool {
        guard element.tagName().lowercased() == "em" else { return false }
        let text = (try? element.text())?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.hasPrefix("[") && text.hasSuffix("]")
    }

    private static func isLeadingDateElement(_ element: Element) throws -> Bool {
        guard element.tagName().lowercased() == "b" else { return false }
        let title = ((try? element.attr("title")) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let recognized = ["Publication", "Last edit"]
        guard recognized.contains(where: { title.caseInsensitiveCompare($0) == .orderedSame }) else {
            return false
        }
        return (try? element.select("time").isEmpty()) == false
    }

    /// Matches wrappers like `<note-box>` that contain only a skip/action link
    /// and are part of the lead metadata line.
    private static func isIgnorableMetadataWrapper(_ element: Element) throws -> Bool {
        let tag = element.tagName().lowercased()
        guard tag == "note-box" else { return false }
        // Must contain at least one <a> and no other meaningful content
        let links = try element.select("a")
        guard !links.isEmpty() else { return false }
        let text = (try? element.text())?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let linkText = try links.array().compactMap { try? $0.text() }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // The wrapper's visible text should be dominated by link text
        return text == linkText || text.isEmpty
    }

    private static func isIgnorableEmptyParagraph(_ element: Element) throws -> Bool {
        guard element.tagName().lowercased() == "p" else { return false }
        let text = ((try? DOMHelpers.getInnerText(element)) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty else { return false }
        return (try? element.select("img, picture, figure, video, iframe, object, embed").isEmpty()) != false
    }

    private static func isLeadMediaElement(_ element: Element) throws -> Bool {
        let tagName = element.tagName().lowercased()
        if ["img", "figure", "picture"].contains(tagName) {
            return true
        }

        if tagName == "center" {
            let hasLeadLinkOrImage = (try? element.select("a, img").isEmpty()) == false
            return hasLeadLinkOrImage
        }

        return false
    }

    private static func isIgnorableSeparatorText(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return trimmed.range(of: #"^[()\[\],:;|/\-–—]+$"#, options: .regularExpression) != nil
    }
}
