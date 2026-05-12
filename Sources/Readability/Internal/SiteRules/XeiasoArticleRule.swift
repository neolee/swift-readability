import Foundation
import SwiftSoup

/// Promotes xeiaso.net posts out of inline character dialogue blocks and
/// normalizes those dialogue cards into reader-friendly blockquotes.
///
/// SiteRule Metadata:
/// - Scope: xeiaso.net posts with character dialogue cards inside `article.prose`
/// - Phase: candidate promotion and `postProcess` cleanup/normalization
/// - Trigger: xeiaso canonical/location plus character links and sticker avatars
/// - Evidence: `CLI/.staging/xeiaso`
/// - Risk if misplaced: Tailwind `text-*` classes can make a dialogue card or footer
///   outscore the real article body before cleanup.
enum XeiasoArticleRule: CandidatePromotionSiteRule, ArticleCleanerSiteRule, SerializationSiteRule {
    static let id = "xeiaso-article"

    static func promotedCandidate(from candidate: Element) -> Element? {
        guard let document = candidate.ownerDocument(),
              isXeiasoDocument(document),
              let article = nearestArticleProseAncestor(of: candidate),
              containsCharacterDialogue(in: article) else {
            return nil
        }

        return article
    }

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        guard containsCharacterDialogue(in: articleContent) else {
            return
        }

        try removePostMetadata(from: articleContent)
        try removePostTailChrome(from: articleContent)
    }

    static func apply(to articleContent: Element) throws {
        guard containsCharacterDialogue(in: articleContent) else {
            return
        }

        try normalizeCharacterDialogues(in: articleContent)
    }

    private static func nearestArticleProseAncestor(of element: Element) -> Element? {
        if isArticleProse(element) {
            return element
        }

        return element.ancestors().first(where: isArticleProse)
    }

    private static func isArticleProse(_ element: Element) -> Bool {
        element.tagName().uppercased() == "ARTICLE" && element.hasClass("prose")
    }

    private static func containsCharacterDialogue(in article: Element) -> Bool {
        hasCharacterLink(in: article) && hasStickerAvatar(in: article)
    }

    private static func isCharacterDialogueContainer(_ element: Element) -> Bool {
        guard element.hasClass("bg-bg-soft") || element.hasClass("space-y-0") else {
            return false
        }

        guard hasCharacterLink(in: element), hasStickerAvatar(in: element) else {
            return false
        }

        if element.hasClass("space-y-0") {
            return true
        }

        return element.parent()?.hasClass("space-y-0") == true
    }

    private static func normalizeCharacterDialogues(in articleContent: Element) throws {
        for card in try articleContent.select("div").reversed() {
            guard isSingleCharacterDialogueCard(card) else {
                continue
            }

            let document = card.ownerDocument() ?? Document("")
            let blockquote = try makeDialogueBlockquote(from: card, in: document)
            try card.replaceWith(blockquote)
        }

        try unwrapDialogueBlockquoteWrappers(in: articleContent)
    }

    private static func isCharacterDialogueCard(_ element: Element) -> Bool {
        hasCharacterLink(in: element) && hasStickerAvatar(in: element)
    }

    private static func isSingleCharacterDialogueCard(_ element: Element) -> Bool {
        characterLinkCount(in: element) == 1 && stickerAvatarCount(in: element) == 1
    }

    private static func makeDialogueBlockquote(from card: Element, in document: Document) throws -> Element {
        let blockquote = try document.createElement("blockquote")

        if let speaker = try firstCharacterLink(in: card) {
            let speakerParagraph = try document.createElement("p")
            let strong = try document.createElement("strong")
            try strong.text(try speaker.text())
            try speakerParagraph.appendChild(strong)
            try blockquote.appendChild(speakerParagraph)
        }

        let speakerText = ((try? speakerText(in: card)) ?? "")
        for paragraph in try card.select("p") {
            let text = try normalizedText(paragraph)
            let hasAvatar = hasStickerAvatar(in: paragraph)
            guard !hasAvatar, !text.isEmpty, text != speakerText else {
                continue
            }
            try blockquote.appendChild(try DOMHelpers.cloneElement(paragraph, in: document))
        }

        return blockquote
    }

    private static func speakerText(in card: Element) throws -> String? {
        guard let speaker = try firstCharacterLink(in: card) else {
            return nil
        }
        return try normalizedText(speaker)
    }

    private static func unwrapDialogueBlockquoteWrappers(in articleContent: Element) throws {
        for wrapper in try articleContent.select("div").reversed() {
            let children = wrapper.children()
            guard !children.isEmpty,
                  children.allSatisfy({ $0.tagName().uppercased() == "BLOCKQUOTE" }) else {
                continue
            }

            for child in children {
                try wrapper.before(child)
            }
            try wrapper.remove()
        }
    }

    private static func hasCharacterLink(in element: Element) -> Bool {
        (try? firstCharacterLink(in: element)) != nil
    }

    private static func firstCharacterLink(in element: Element) throws -> Element? {
        for link in try element.select("a") {
            let href = (try? link.attr("href")) ?? ""
            if href.contains("/characters#") {
                return link
            }
        }
        return nil
    }

    private static func characterLinkCount(in element: Element) -> Int {
        guard let links = try? element.select("a") else {
            return 0
        }
        return links.filter {
            let href = (try? $0.attr("href")) ?? ""
            return href.contains("/characters#")
        }.count
    }

    private static func hasStickerAvatar(in element: Element) -> Bool {
        guard let images = try? element.select("img") else {
            return false
        }
        for image in images {
            let src = (try? image.attr("src")) ?? ""
            if src.contains("/sticker/") {
                return true
            }
        }
        return false
    }

    private static func stickerAvatarCount(in element: Element) -> Int {
        guard let images = try? element.select("img") else {
            return 0
        }
        return images.filter {
            let src = (try? $0.attr("src")) ?? ""
            return src.contains("/sticker/")
        }.count
    }

    private static func removePostMetadata(from articleContent: Element) throws {
        for metadata in try articleContent.select("div").reversed() {
            let text = try normalizedText(metadata)
            let hasPublicationTime = (try? metadata.select("time[datetime]").isEmpty()) == false
            guard hasPublicationTime,
                  text.contains("words"),
                  text.contains("minutes to read") else {
                continue
            }
            try metadata.remove()
        }
    }

    private static func removePostTailChrome(from articleContent: Element) throws {
        for paragraph in try articleContent.select("p").reversed() {
            let text = try normalizedText(paragraph)
            if text.hasPrefix("Facts and circumstances may have changed since publication.") ||
                text == "Tags:" {
                try paragraph.remove()
            }
        }

        for rule in try articleContent.select("hr").reversed() {
            try rule.remove()
        }
    }

    private static func normalizedText(_ element: Element) throws -> String {
        try DOMHelpers.getInnerText(element)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isXeiasoDocument(_ document: Document) -> Bool {
        let candidates = [
            document.location(),
            (try? document.select("link[rel=canonical]").first()?.attr("href")) ?? "",
            (try? document.select("meta[property=og:url]").first()?.attr("content")) ?? ""
        ]

        return candidates.contains(where: isXeiasoURL)
    }

    private static func isXeiasoURL(_ rawURL: String) -> Bool {
        guard let host = URL(string: rawURL)?.host?.lowercased() else {
            return false
        }
        return host == "xeiaso.net" || host.hasSuffix(".xeiaso.net")
    }
}
