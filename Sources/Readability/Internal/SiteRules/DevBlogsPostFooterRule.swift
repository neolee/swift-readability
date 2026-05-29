import Foundation
import SwiftSoup

/// Rejects the DevBlogs post-footer sibling that would otherwise be merged
/// alongside the selected content candidate due to inflated class-weight scoring.
///
/// Microsoft DevBlogs pages (devblogs-evo WordPress theme) wrap article content
/// in `div#single-wrapper.container-three-column-post` and follow it with a second
/// `div.container-three-column-post` containing post-footer metadata:
/// Category/Topics link lists, Share buttons, and an Author bio block.
///
/// The post-footer sibling scores well above the sibling merge threshold because
/// `container-three-column-post` contains the substring "post", which matches
/// positive class-weight patterns for +25. This rule rejects it before it enters
/// the extracted article.
///
/// Gating:
/// - Document must look like a Microsoft DevBlogs Evo post page.
/// - Top candidate must be `div#single-wrapper.container-three-column-post`.
/// - Sibling must be a following `div.container-three-column-post` under the same parent.
/// - Sibling must contain DevBlogs post-footer markers (`body_category`,
///   `body_topics`, `body_author_bottom`, or `.post-detail-share.social-panel`).
///
/// Evidence:
/// - `CLI/.staging/raymondchen` (devblogs.microsoft.com/oldnewthing)
enum DevBlogsPostFooterRule: SiblingInclusionSiteRule {
    static let id = "devblogs-post-footer"

    static func shouldIncludeSibling(_ sibling: Element, topCandidate: Element) throws -> Bool? {
        guard topCandidate.tagName().lowercased() == "div",
              topCandidate.id() == "single-wrapper",
              topCandidate.hasClass("container-three-column-post") else {
            return nil
        }

        guard let document = topCandidate.ownerDocument(),
              isDevBlogsEvoDocument(document) else {
            return nil
        }

        guard sibling.tagName().lowercased() == "div",
              sibling.hasClass("container-three-column-post"),
              sibling !== topCandidate,
              followsTopCandidate(sibling, topCandidate: topCandidate),
              try hasPostFooterMarkers(sibling) else {
            return nil
        }

        return false
    }

    private static func isDevBlogsEvoDocument(_ document: Document) -> Bool {
        if ((try? document.select("body.wp-theme-devblogs-evo").isEmpty()) == false) {
            return true
        }

        let urlSignals = [
            (try? document.select("link[rel=canonical]").first()?.attr("href")) ?? "",
            (try? document.select("meta[property=og:url]").first()?.attr("content")) ?? ""
        ]
        return urlSignals.contains { $0.lowercased().contains("devblogs.microsoft.com") }
    }

    private static func followsTopCandidate(_ sibling: Element, topCandidate: Element) -> Bool {
        guard let parent = topCandidate.parent(), sibling.parent() === parent else {
            return false
        }

        var seenTopCandidate = false
        for child in parent.children() {
            if child === topCandidate {
                seenTopCandidate = true
                continue
            }
            if child === sibling {
                return seenTopCandidate
            }
        }
        return false
    }

    private static func hasPostFooterMarkers(_ sibling: Element) throws -> Bool {
        if try sibling.select("a[data-bi-area=body_category]").isEmpty() == false {
            return true
        }
        if try sibling.select("a[data-bi-area=body_topics]").isEmpty() == false {
            return true
        }
        if try sibling.select("a[data-bi-area=body_author_bottom]").isEmpty() == false {
            return true
        }
        if try sibling.select(".post-detail-share.social-panel").isEmpty() == false {
            return true
        }
        return false
    }
}
