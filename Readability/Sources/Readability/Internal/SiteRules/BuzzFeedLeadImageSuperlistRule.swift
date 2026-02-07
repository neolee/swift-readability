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
            let hasLeadHeading = (try? item.select("> h2").isEmpty()) == false
            let hasLeadImageBlock = (try? item.select("> div p img[rel\\:bf_image_src]").isEmpty()) == false
            guard hasLeadHeading && hasLeadImageBlock else { continue }

            if let sourceParagraph = (try? item.select("> p:has(> span)").last()) ?? nil {
                let replacement = try DOMHelpers.cloneElement(sourceParagraph, in: item.ownerDocument() ?? Document(""))
                try item.replaceWith(replacement)
                continue
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
            let hasBuzzImage = ((try? item.select("img[rel\\:bf_image_src]").isEmpty()) == false)
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
}
