import Foundation
import SwiftSoup

/// Shared visibility/hidden-node rules used across extraction and cleanup.
enum VisibilityRules {
    /// Scoring visibility follows Mozilla behavior:
    /// hidden/style-hidden are invisible; aria-hidden may keep fallback-image.
    static func isProbablyVisibleForScoring(_ element: Element) -> Bool {
        var current: Element? = element
        while let node = current {
            if hasStyleHidden(node) || node.hasAttr("hidden") {
                return false
            }

            if isAriaHidden(node) {
                // Keep Mozilla's fallback-image exception only for the node itself.
                if node === element {
                    let className = (try? element.className()) ?? ""
                    if !className.contains("fallback-image") {
                        return false
                    }
                } else {
                    return false
                }
            }

            current = node.parent()
        }

        return true
    }

    /// Strict removal visibility used during preprocessing/cleanup.
    /// Hidden/style-hidden nodes are removed; aria-hidden nodes are removed
    /// except media/math fallbacks that must survive for content parity.
    static func shouldRemoveAsHidden(_ element: Element) -> Bool {
        if element.hasAttr("hidden") || hasStyleHidden(element) {
            return true
        }

        if isAriaHidden(element) {
            return !shouldKeepAriaHiddenMedia(element)
        }

        return false
    }

    /// Remove hidden nodes from a subtree using strict removal rules.
    static func removeHiddenElements(from root: Element) throws {
        let candidates = try root.select("[hidden], [aria-hidden=true], *[style]")
        for element in candidates {
            if shouldRemoveAsHidden(element) {
                try element.remove()
            }
        }
    }

    private static func isAriaHidden(_ element: Element) -> Bool {
        let ariaHidden = (try? element.attr("aria-hidden").lowercased()) ?? ""
        return ariaHidden == "true"
    }

    /// Keep aria-hidden media/math nodes that carry meaningful article content
    /// (for example Wikimedia math fallback images).
    private static func shouldKeepAriaHiddenMedia(_ element: Element) -> Bool {
        let tag = element.tagName().lowercased()
        if ["img", "picture", "source", "video", "audio"].contains(tag) {
            return true
        }

        let className = ((try? element.className()) ?? "").lowercased()
        if className.contains("mwe-math") {
            return true
        }

        return false
    }

    private static func hasStyleHidden(_ element: Element) -> Bool {
        guard let style = try? element.attr("style").lowercased() else {
            return false
        }
        let normalized = style.replacingOccurrences(of: " ", with: "")
        return normalized.contains("display:none") || normalized.contains("visibility:hidden")
    }
}
