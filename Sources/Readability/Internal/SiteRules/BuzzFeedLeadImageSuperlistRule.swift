import Foundation
import SwiftSoup

/// Removes BuzzFeed superlist lead image cards that Mozilla output drops.
///
/// SiteRule Metadata:
/// - Scope: BuzzFeed `buzz_superlist_item_image` lead image panels
/// - Phase: `unwanted` cleanup
/// - Trigger: `.buzz_superlist_item_image` with image-only payload
/// - Evidence: `realworld/buzzfeed-1`
/// - Risk if misplaced: image card survives and shifts first-content node parity
enum BuzzFeedLeadImageSuperlistRule: SerializationSiteRule {
    static let id = "buzzfeed-lead-image-superlist"

    static func apply(to articleContent: Element) throws {
        for item in try articleContent.select("div[id^=superlist_]").reversed() {
            guard item.parent() != nil else { continue }
            let children = item.children().array()
            let hasLeadHeading = children.contains { $0.tagName().lowercased() == "h2" }
            let hasLeadImageBlock = children.contains { child in
                guard child.tagName().lowercased() == "div" else { return false }
                return hasBuzzFeedImage(in: child)
            }
            guard hasLeadHeading && hasLeadImageBlock else { continue }

            // Drop the lead image wrapper block while keeping headline text.
            for block in children.reversed() {
                guard block.tagName().lowercased() == "div" else { continue }
                let containsLeadImage = hasBuzzFeedImage(in: block)
                if containsLeadImage {
                    try block.remove()
                }
            }

            // Normalize source attribution paragraph to expected shape:
            // <p><span>Source</span></p>
            if let source = (try? item.select("p.article_caption_w_attr .sub_buzz_source_via").first()) ?? nil {
                let sourceText = ((try? source.text()) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if !sourceText.isEmpty {
                    let doc = item.ownerDocument() ?? Document("")
                    let normalizedP = try doc.createElement("p")
                    let span = try doc.createElement("span")
                    try span.text(sourceText)
                    try normalizedP.appendChild(span)

                    if let caption = (try? item.select("p.article_caption_w_attr").first()) ?? nil {
                        try caption.replaceWith(normalizedP)
                    } else {
                        try item.appendChild(normalizedP)
                    }
                }
            }
        }

        for item in try articleContent.select("div").reversed() {
            guard item.parent() != nil else { continue }
            let hasImage = (try? item.select("img, picture").isEmpty()) == false
            let hasHeading = (try? item.select("h1, h2, h3, h4, h5, h6").isEmpty()) == false
            guard hasImage && !hasHeading else { continue }

            let hasSuperlistClass = ((try? item.className()) ?? "").contains("buzz_superlist_item_image")
            let hasCaptionSource = ((try? item.select(".article_caption_w_attr .sub_buzz_source_via").isEmpty()) == false)
            let hasViewImageLink = ((try? item.select("p.print a").isEmpty()) == false)
            let hasBuzzImage = hasBuzzFeedImage(in: item)
            guard hasSuperlistClass ||
                    (hasCaptionSource && hasViewImageLink) ||
                    (hasBuzzImage && hasViewImageLink) ||
                    (hasBuzzImage && hasCaptionSource) else { continue }

            if let source = (try? item.select(".article_caption_w_attr .sub_buzz_source_via").first()) ?? nil {
                let text = ((try? source.text()) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty, let doc = item.ownerDocument() {
                    let p = try doc.createElement("p")
                    let span = try doc.createElement("span")
                    try span.text(text)
                    try p.appendChild(span)
                    try item.replaceWith(p)
                    continue
                }
            }

            try item.remove()
        }
    }

    private static func hasBuzzFeedImage(in element: Element) -> Bool {
        guard let images = try? element.select("img") else { return false }
        for image in images {
            if image.hasAttr("rel:bf_image_src") {
                return true
            }
        }
        return false
    }
}
