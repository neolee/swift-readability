import Foundation
import SwiftSoup

/// Restores The Verge zoom wrapper accessibility attributes dropped during cleanup.
///
/// SiteRule Metadata:
/// - Scope: The Verge hero/media zoom wrapper containers
/// - Phase: `postProcess` normalization
/// - Trigger: `div > figure` image wrapper with sibling `figcaption` block and missing attrs
/// - Evidence: `realworld/theverge`
/// - Risk if misplaced: unnecessary accessibility attrs on unrelated wrappers
enum TheVergeZoomWrapperAccessibilityRule: ArticleCleanerSiteRule {
    static let id = "theverge-zoom-wrapper-accessibility"

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        for wrapper in try articleContent.select("div").reversed() {
            guard !wrapper.hasAttr("role"),
                  wrapper.children().count == 1,
                  let figure = wrapper.children().first,
                  figure.tagName().lowercased() == "figure" else {
                continue
            }

            let hasImage = (try? figure.select("img").isEmpty()) == false
            guard hasImage else { continue }

            let hasNimg = (try? figure.select("img[data-nimg]").isEmpty()) == false
            guard hasNimg else { continue }

            try wrapper.attr("role", "button")
            try wrapper.attr("aria-label", "Zoom")
            try wrapper.attr("tabindex", "0")
        }

        // Deduplicate accidental duplicated zoom wrappers that can appear after
        // wrapper normalization: keep the first and remove identical followers.
        for parent in try articleContent.select("div").reversed() {
            let zoomChildren = parent.children().array().filter {
                guard $0.tagName().lowercased() == "div" else { return false }
                let role = ((try? $0.attr("role")) ?? "").lowercased()
                let ariaLabel = ((try? $0.attr("aria-label")) ?? "").lowercased()
                return role == "button" && ariaLabel == "zoom"
            }
            guard zoomChildren.count >= 2 else { continue }

            var seenImageSignatures = Set<String>()
            for child in zoomChildren {
                let signature = ((try? child.select("img").first()?.attr("src")) ?? "")
                if signature.isEmpty {
                    continue
                }
                if seenImageSignatures.contains(signature) {
                    try child.remove()
                } else {
                    seenImageSignatures.insert(signature)
                }
            }
        }

        for container in try articleContent.select("div").reversed() {
            guard container.parent() != nil else { continue }
            guard container.children().count == 1,
                  let child = container.children().first,
                  child.tagName().lowercased() == "div" else {
                continue
            }
            let role = ((try? child.attr("role")) ?? "").lowercased()
            let ariaLabel = ((try? child.attr("aria-label")) ?? "").lowercased()
            let hasNoDirectText = container.textNodes().allSatisfy {
                $0.text().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            if role == "button", ariaLabel == "zoom", hasNoDirectText {
                try container.replaceWith(child)
            }
        }
    }
}
