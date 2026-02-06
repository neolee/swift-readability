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
    /// Any hidden/style-hidden/aria-hidden element should be removed.
    static func shouldRemoveAsHidden(_ element: Element) -> Bool {
        return element.hasAttr("hidden") || isAriaHidden(element) || hasStyleHidden(element)
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

    private static func hasStyleHidden(_ element: Element) -> Bool {
        guard let style = try? element.attr("style").lowercased() else {
            return false
        }
        let normalized = style.replacingOccurrences(of: " ", with: "")
        return normalized.contains("display:none") || normalized.contains("visibility:hidden")
    }
}
