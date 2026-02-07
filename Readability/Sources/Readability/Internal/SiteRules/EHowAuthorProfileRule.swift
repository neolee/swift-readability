import Foundation
import SwiftSoup

/// Normalizes eHow author profile blocks so they survive generic compact-link cleanup.
///
/// SiteRule Metadata:
/// - Scope: eHow author profile module
/// - Phase: `unwanted` cleanup
/// - Trigger: `div[data-type=AuthorProfile]` containing avatar link and publish/update time
/// - Evidence: `realworld/ehow-2`
/// - Risk if misplaced: compact metadata rails may be dropped before final cleanup
enum EHowAuthorProfileRule: ArticleCleanerSiteRule {
    static let id = "ehow-author-profile"

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        try articleContent.select("div#relatedContentUpper[data-module=rcp_top]").remove()
        for featured in try articleContent.select("section#FeaturedTombstone[data-module=rcp_tombstone]") {
            for child in featured.children() where child.tagName().lowercased() != "h2" {
                try child.remove()
            }
        }
        for container in try articleContent.select("div") {
            let children = container.children().array()
            let hasAuthorProfile = children.contains { child in
                child.tagName().lowercased() == "div" &&
                    ((try? child.attr("data-type")) ?? "").lowercased() == "authorprofile"
            }
            guard hasAuthorProfile else { continue }

            let hasScoreBlock = children.contains { child in
                child.tagName().lowercased() == "div" &&
                    ((try? child.attr("data-score")) ?? "").lowercased() == "true"
            }
            guard hasScoreBlock else { continue }

            for headline in children where
                (headline.tagName().lowercased() == "h1" || headline.tagName().lowercased() == "h2") &&
                ((try? headline.attr("itemprop")) ?? "").lowercased().contains("headline") {
                try headline.remove()
            }
        }

        for profile in try articleContent.select("div[data-type=AuthorProfile]") {
            guard profile.parent() != nil else { continue }

            guard let imageLink = try profile.select("a#img-follow-tip, a:has(img)").first(),
                  let time = try profile.select("time[datetime], time").first() else {
                continue
            }

            let doc = articleContent.ownerDocument() ?? Document("")
            let normalized = try doc.createElement("div")
            try normalized.attr("data-type", "AuthorProfile")

            let imageContainer = try doc.createElement("div")
            let imageParagraph = try doc.createElement("p")
            try imageLink.remove()
            try imageParagraph.appendChild(imageLink)
            try imageContainer.appendChild(imageParagraph)
            try normalized.appendChild(imageContainer)

            let timeParagraph = try doc.createElement("p")
            try time.remove()
            try timeParagraph.appendChild(time)
            try normalized.appendChild(timeParagraph)

            try profile.replaceWith(normalized)
        }
    }
}
