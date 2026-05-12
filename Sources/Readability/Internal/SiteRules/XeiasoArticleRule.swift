import Foundation
import SwiftSoup

/// Removes xeiaso.net site template chrome before extraction, promotes the article
/// candidate out of dialogue / footer noise, normalizes character-dialogue cards into
/// blockquotes, and cleans post metadata and tail chrome during post-processing.
///
/// SiteRule Metadata:
/// - Scope: xeiaso.net posts with `article.prose`
/// - Phase: pre-extraction document cleanup, candidate promotion,
///   `postProcess` cleanup, and serialization normalization
/// - Trigger: xeiaso canonical/location/hostname
/// - Evidence: `CLI/.staging/xeiaso-1` through `xeiaso-5`
/// - Risk if misplaced: Tailwind `text-*` class-weight false positives can make
///   dialogue cards or the site footer outscore the real article body.
enum XeiasoArticleRule: PreExtractionDocumentRule, CandidatePromotionSiteRule, CandidateProtectionSiteRule, ShortContentFallbackSiteRule, ArticleCleanerSiteRule, SerializationSiteRule {
    static let id = "xeiaso-article"

    // MARK: - PreExtractionDocumentRule

    static func apply(to document: Document, sourceURL: URL?) throws {
        guard let url = sourceURL ?? (try? document.select("link[rel=canonical]").first()?.attr("href")).flatMap(URL.init(string:)),
              isXeiasoURL(url.absoluteString) else {
            return
        }

        try removeSiteHeader(from: document)
        try removeArticleTailChrome(from: document)
        try removeSiteFooter(from: document)
    }

    /// Removes the stable post-body tail inside `article.prose` that starts at the
    /// final site-chrome `<hr>` separator.  Body-level `<hr>` elements are preserved.
    private static func removeArticleTailChrome(from document: Document) throws {
        guard let article = try document.select("article.prose").first() else {
            return
        }

        for hr in try article.select("> hr").reversed() {
            guard isTailBoundaryHR(hr) else { continue }
            try removeFromHRThroughEndOfArticle(hr)
            break
        }
    }

    /// Returns `true` when the `<hr>` is followed by siblings that contain
    /// xeiaso tail markers: share button, disclaimer paragraph, or empty tags.
    private static func isTailBoundaryHR(_ hr: Element) -> Bool {
        var next = try? hr.nextElementSibling()
        while let sibling = next {
            let id = sibling.id().trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if id == "sharebutton" { return true }

            if sibling.tagName().uppercased() == "P" {
                let text = (try? normalizedText(sibling)) ?? ""
                if text.hasPrefix("Facts and circumstances may have changed since publication.") ||
                    text.hasPrefix("Tags:") {
                    return true
                }
                // Only the first following <p> is checked — past that it is likely
                // article body content, not tail chrome.
                break
            }
            next = try? sibling.nextElementSibling()
        }
        return false
    }

    /// Removes `hr` and all following siblings inside its parent.
    private static func removeFromHRThroughEndOfArticle(_ hr: Element) throws {
        var next = try? hr.nextElementSibling()
        while let sibling = next {
            let upcoming = try? sibling.nextElementSibling()
            try sibling.remove()
            next = upcoming
        }
        try hr.remove()
    }

    /// Removes the top-level site `<header>` (site navigation bar) to prevent it
    /// from entering the candidate pool.
    private static func removeSiteHeader(from document: Document) throws {
        for header in try document.select("body > header").reversed() {
            let navCount = (try? header.select("nav").count) ?? 0
            guard navCount == 1 else { continue }
            try header.remove()
        }
    }

    /// Removes the top-level site footer block (direct child of `<body>`) whose text
    /// contains the stable xeiaso footer markers.
    private static func removeSiteFooter(from document: Document) throws {
        for footer in try document.select("body > footer").reversed() {
            let text = (try? normalizedText(footer)) ?? ""
            guard text.contains("Copyright"),
                  text.contains("Xe Iaso"),
                  text.contains("Served by xesite") else {
                continue
            }
            try footer.remove()
        }
    }

    // MARK: - CandidateProtectionSiteRule

    /// Prevents `article.prose` from being promoted into outer layout wrappers
    /// (e.g., `div.mt-4`) during standard single-child or alternative-ancestor
    /// promotion.  This keeps the semantic article boundary stable regardless of
    /// content length or sibling scores.
    static func shouldKeepCandidate(_ current: Element) -> Bool {
        guard let document = current.ownerDocument(),
              isXeiasoDocument(document),
              isArticleProse(current) else {
            return false
        }
        return true
    }

    // MARK: - ShortContentFallbackSiteRule

    /// When all passes fail the content-length threshold (e.g. after pre-extraction
    /// chrome removal shortens a very brief post), return `article.prose` directly
    /// instead of falling through to an outer layout container.
    static func fallbackArticleContent(in document: Document, sourceURL: URL?) throws -> Element? {
        let url = sourceURL ?? (try? document.select("link[rel=canonical]").first()?.attr("href")).flatMap(URL.init(string:))
        guard let url, isXeiasoURL(url.absoluteString),
              let article = try document.select("article.prose").first() else {
            return nil
        }
        return article
    }

    // MARK: - CandidatePromotionSiteRule

    static func promotedCandidate(from candidate: Element) -> Element? {
        guard let document = candidate.ownerDocument(),
              isXeiasoDocument(document) else {
            return nil
        }

        // Case 1: candidate is inside article.prose (e.g., dialogue card won)
        //          → promote up to article.prose
        if let article = nearestArticleProseAncestor(of: candidate) {
            return article
        }

        // Case 2: candidate is NOT article.prose itself (e.g., footer won,
        //          or standard promotion moved to outer div.mt-4)
        //          → promote directly to article.prose
        if let article = try? document.select("article.prose").first(),
           candidate !== article {
            return article
        }

        return nil
    }

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
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
        var foundXeiasoTailMarker = false

        for paragraph in try articleContent.select("p").reversed() {
            let text = try normalizedText(paragraph)
            if text.hasPrefix("Facts and circumstances may have changed since publication.") ||
                text == "Tags:" {
                try paragraph.remove()
                foundXeiasoTailMarker = true
            }
        }

        guard foundXeiasoTailMarker else { return }

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
