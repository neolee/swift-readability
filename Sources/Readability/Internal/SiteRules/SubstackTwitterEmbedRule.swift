import Foundation
import SwiftSoup

/// Normalizes Substack `Twitter2ToDOM` widgets into compact readable blockquotes.
///
/// This is an intentional Mozilla-parity deviation for Substack pages. Mozilla keeps the
/// full widget UI, but Substack exposes stable tweet payload data in `data-attrs`, which
/// lets us preserve the post content while dropping interaction chrome.
///
/// SiteRule Metadata:
/// - Scope: Substack inline X/Twitter embeds rendered via `Twitter2ToDOM`
/// - Phase: `postProcess` normalization
/// - Trigger: `a[data-component-name=Twitter2ToDOM][href*=\"x.com/\"]`
/// - Evidence: `CLI/.staging/garymarcus-2`
/// - Risk if misplaced: embed UI chrome overwhelms article prose
enum SubstackTwitterEmbedRule: ArticleCleanerSiteRule {
    static let id = "substack-twitter-embed"

    private struct EmbedPayload: Decodable {
        let url: String?
        let fullText: String?
        let username: String?
        let name: String?
        let date: String?
        let photos: [Photo]?

        enum CodingKeys: String, CodingKey {
            case url
            case fullText = "full_text"
            case username
            case name
            case date
            case photos
        }
    }

    private struct Photo: Decodable {
        let imageURL: String?

        enum CodingKeys: String, CodingKey {
            case imageURL = "img_url"
        }
    }

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        for anchor in try articleContent.select("a[data-component-name=\"Twitter2ToDOM\"][href*=\"x.com/\"]").reversed() {
            guard let replacement = try buildNormalizedEmbed(from: anchor) else {
                continue
            }
            try anchor.replaceWith(replacement)
        }
    }

    private static func buildNormalizedEmbed(from anchor: Element) throws -> Element? {
        let payload = decodePayload(from: anchor)
        let rawText = payload?.fullText ?? fallbackBodyText(from: anchor)
        let normalizedText = normalizeTweetText(rawText)
        let photos = payload?.photos ?? []

        let href = nonEmpty((try? anchor.attr("href")) ?? "") ?? payload?.url
        let displayName = nonEmpty(payload?.name)
        let username = nonEmpty(payload?.username)
        let dateText = formatDate(payload?.date)

        guard !normalizedText.isEmpty || !photos.isEmpty || href != nil else {
            return nil
        }

        let doc = anchor.ownerDocument() ?? Document("")
        let blockquote = try doc.createElement("blockquote")
        if let href {
            try blockquote.attr("cite", href)
        }

        if !normalizedText.isEmpty {
            let textParagraph = try doc.createElement("p")
            try textParagraph.text(normalizedText)
            try blockquote.appendChild(textParagraph)
        }

        for photo in photos {
            guard let imageURL = nonEmpty(photo.imageURL) else { continue }
            let imageParagraph = try doc.createElement("p")
            let image = try doc.createElement("img")
            try image.attr("src", imageURL)
            try imageParagraph.appendChild(image)
            try blockquote.appendChild(imageParagraph)
        }

        if let attribution = buildAttribution(displayName: displayName, username: username, dateText: dateText) {
            let attributionParagraph = try doc.createElement("p")
            if let href {
                let link = try doc.createElement("a")
                try link.attr("href", href)
                try link.text(attribution)
                try attributionParagraph.appendChild(link)
            } else {
                try attributionParagraph.text(attribution)
            }
            try blockquote.appendChild(attributionParagraph)
        }

        return blockquote
    }

    private static func decodePayload(from anchor: Element) -> EmbedPayload? {
        guard let raw = try? anchor.select("> div[data-attrs]").first()?.attr("data-attrs"),
              let data = raw.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(EmbedPayload.self, from: data)
    }

    private static func fallbackBodyText(from anchor: Element) -> String {
        let paragraphs = ((try? anchor.select("> div > p").array()) ?? [])
        guard paragraphs.count >= 2 else {
            return ""
        }

        return ((try? paragraphs[1].text()) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizeTweetText(_ text: String?) -> String {
        guard let raw = nonEmpty(text) else { return "" }

        let decoded = (try? SwiftSoup.parseBodyFragment(raw).text()) ?? raw
        return decoded
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func buildAttribution(
        displayName: String?,
        username: String?,
        dateText: String?
    ) -> String? {
        var parts: [String] = []

        if let displayName, let username {
            parts.append("\(displayName) (@\(username)) on X")
        } else if let username {
            parts.append("@\(username) on X")
        } else if let displayName {
            parts.append("\(displayName) on X")
        }

        if let dateText {
            parts.append(dateText)
        }

        let joined = parts.joined(separator: ", ")
        return joined.isEmpty ? nil : joined
    }

    private static func formatDate(_ rawDate: String?) -> String? {
        guard let rawDate = nonEmpty(rawDate) else { return nil }

        let formatterWithFractionalSeconds = ISO8601DateFormatter()
        formatterWithFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let formatterWithoutFractionalSeconds = ISO8601DateFormatter()
        formatterWithoutFractionalSeconds.formatOptions = [.withInternetDateTime]

        guard let date =
            formatterWithFractionalSeconds.date(from: rawDate) ??
            formatterWithoutFractionalSeconds.date(from: rawDate) else {
            return nil
        }

        let outputFormatter = DateFormatter()
        outputFormatter.locale = Locale(identifier: "en_US_POSIX")
        outputFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        outputFormatter.dateFormat = "MMM d, yyyy"
        return outputFormatter.string(from: date)
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return value
    }
}
