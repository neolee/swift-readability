import Foundation
import SwiftSoup

/// Removes Substack inline share call-to-action buttons from the extracted
/// article body.
///
/// These buttons appear between article paragraphs and are not part of the
/// author's content. The existing generic `removeShortShareElements` cleanup
/// does not catch them because the signal is `data-component-name`, not
/// `class` or `id`.
///
/// SiteRule Metadata:
/// - Scope: Substack inline share CTA rendered as `ButtonCreateButton`
/// - Phase: `preConversion`
/// - Trigger: `<p data-component-name="ButtonCreateButton">` whose visible
///   text is exactly "Share" and whose payload or child anchor links to
///   `action=share` or `utm_content=share`.
/// - Context gate: document contains `article.newsletter-post.post`, or
///   the candidate is inside `div.body.markup`.
/// - Evidence: `CLI/.staging/garymarcus-3`
/// - Risk if misplaced: extremely low — triple-condition gating prevents
///   removal of non-share `ButtonCreateButton` instances (e.g. "Subscribe now").
enum SubstackInlineButtonCTARule: ArticleCleanerSiteRule {
    static let id = "substack-inline-button-cta"

    private struct ButtonPayload: Decodable {
        let text: String?
        let url: String?
        let action: String?
    }

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        for paragraph in try articleContent.select("p[data-component-name=\"ButtonCreateButton\"]").reversed() {
            guard isShareButton(paragraph) else { continue }
            guard hasSubstackContext(paragraph, articleContent: articleContent) else { continue }
            try paragraph.remove()
        }
    }

    // MARK: - Share Signal Detection

    private static func isShareButton(_ element: Element) -> Bool {
        let visibleText = ((try? element.text()) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard visibleText == "Share" else { return false }

        if hasSharePayload(element) { return true }
        if hasShareLink(element) { return true }

        return false
    }

    private static func hasSharePayload(_ element: Element) -> Bool {
        guard let raw = try? element.attr("data-attrs"),
              let data = raw.data(using: .utf8),
              let payload = try? JSONDecoder().decode(ButtonPayload.self, from: data) else {
            return false
        }
        let text = payload.text ?? ""
        let url = payload.url ?? ""
        let action = payload.action ?? ""
        guard text == "Share" else { return false }
        return url.contains("action=share")
            || url.contains("utm_content=share")
            || action == "share"
    }

    private static func hasShareLink(_ element: Element) -> Bool {
        guard let anchor = try? element.select("a").first(),
              let href = try? anchor.attr("href") else {
            return false
        }
        return href.contains("action=share") || href.contains("utm_content=share")
    }

    // MARK: - Substack Context Confirmation

    private static func hasSubstackContext(
        _ element: Element,
        articleContent: Element
    ) -> Bool {
        if hasSubstackArticleElement(articleContent) { return true }
        if isInsideBodyMarkup(element) { return true }
        return false
    }

    private static func hasSubstackArticleElement(_ articleContent: Element) -> Bool {
        let articleRoot = findRoot(articleContent)
        return (try? articleRoot.select("article.newsletter-post.post").isEmpty()) == false
    }

    private static func isInsideBodyMarkup(_ element: Element) -> Bool {
        var cursor: Element? = element.parent()
        while let current = cursor {
            let className = ((try? current.className()) ?? "").lowercased()
            if className.contains("body") && className.contains("markup") {
                return true
            }
            cursor = current.parent()
        }
        return false
    }

    private static func findRoot(_ element: Element) -> Element {
        var root = element
        while let parent = root.parent() {
            root = parent
        }
        return root
    }
}
