import Foundation
import SwiftSoup

/// Restores antirez excerpt from the leading article `<pre>` block when generic paragraph fallback has no result.
///
/// SiteRule Metadata:
/// - Scope: antirez excerpt fallback for preformatted article bodies
/// - Phase: `excerpt` fallback
/// - Trigger: antirez document, no existing excerpt, and article content contains a non-empty `<pre>` body
/// - Evidence: `ex-pages/antirez-1`
/// - Risk if misplaced: preformatted non-article blocks could be used as excerpts on unrelated pages
enum AntirezExcerptRule: ExcerptSiteRule {
    static let id = "antirez-excerpt"

    static func apply(
        currentExcerpt: String?,
        articleContent: Element,
        sourceURL: URL?,
        document: Document
    ) throws -> String? {
        if let currentExcerpt,
           !currentExcerpt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return currentExcerpt
        }

        guard AntirezRuleHelpers.isAntirezDocument(document, sourceURL: sourceURL) else {
            return currentExcerpt
        }

        let preformattedBlocks = try articleContent.select("pre")
        for pre in preformattedBlocks {
            let rawText = collectRawText(from: pre).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawText.isEmpty else { continue }

            let segments = rawText
                .components(separatedBy: CharacterSet.newlines)
                .split { line in
                    line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
                .map { segment in
                    segment.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                }
                .filter { !$0.isEmpty }

            if let firstSegment = segments.first {
                return firstSegment
            }
            return rawText
        }

        return currentExcerpt
    }

    static func collectRawText(from element: Element) -> String {
        func collect(from node: Node, into output: inout String) {
            if let textNode = node as? TextNode {
                output.append(textNode.getWholeText())
                return
            }
            if let childElement = node as? Element {
                for child in childElement.getChildNodes() {
                    collect(from: child, into: &output)
                }
            }
        }

        var raw = ""
        for node in element.getChildNodes() {
            collect(from: node, into: &raw)
        }
        return raw
    }
}