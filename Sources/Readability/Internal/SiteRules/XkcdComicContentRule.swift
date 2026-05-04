import Foundation
import SwiftSoup

/// Selects the actual xkcd comic container instead of the site footer.
///
/// xkcd comic pages are intentionally short and image-heavy. The visible comic
/// lives in `#middleContainer #comic`, but Mozilla-style text scoring can prefer
/// `#bottom` because it contains long site-wide footer/link text. Keep this
/// rule site-specific so the generic scoring model remains Mozilla-compatible.
enum XkcdComicCandidateRule: CandidatePromotionSiteRule {
    static let id = "xkcd-comic-candidate"

    static func promotedCandidate(from candidate: Element) -> Element? {
        guard let middleContainer = findMiddleContainer(near: candidate),
              hasComicImage(in: middleContainer),
              hasXkcdFooterSibling(middleContainer) else {
            return nil
        }

        return middleContainer
    }
}

/// Prevents xkcd's site-wide footer from being merged back after selecting the
/// comic container.
enum XkcdFooterSiblingRule: SiblingInclusionSiteRule {
    static let id = "xkcd-footer-sibling"

    static func shouldIncludeSibling(_ sibling: Element, topCandidate: Element) throws -> Bool? {
        guard topCandidate.id().trimmingCharacters(in: .whitespacesAndNewlines) == "middleContainer",
              sibling.id().trimmingCharacters(in: .whitespacesAndNewlines) == "bottom" else {
            return nil
        }

        return false
    }
}

/// Removes xkcd navigation chrome after the correct comic container has been
/// selected. The remaining content is the comic image; the comic title belongs
/// to metadata.
enum XkcdComicChromeCleanupRule: ArticleCleanerSiteRule {
    static let id = "xkcd-comic-chrome-cleanup"

    static func apply(to articleContent: Element, context: ArticleCleanerSiteRuleContext) throws {
        guard let middleContainer = try articleContent.select("#middleContainer").first(),
              hasComicImage(in: middleContainer) else {
            return
        }

        for nav in try middleContainer.select("ul.comicNav") {
            try nav.remove()
        }

        for transcript in try middleContainer.select("#transcript") {
            try transcript.remove()
        }

        let comicAltText = firstComicImageAlt(in: middleContainer)?.lowercased()
        for paragraph in try middleContainer.select("p") {
            let text = ((try? paragraph.text()) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            if text.contains("permanent link to this comic") ||
                text.contains("image url (for hotlinking/embedding)") ||
                (!text.isEmpty && text == comicAltText) {
                try paragraph.remove()
            }
        }
    }
}

enum XkcdTextlessComicContentRule: TextlessArticleContentSiteRule {
    static let id = "xkcd-textless-comic-content"

    static func shouldKeepTextlessArticleContent(_ articleContent: Element, sourceURL: URL?, document: Document) throws -> Bool {
        guard let middleContainer = try articleContent.select("#middleContainer").first() else {
            return false
        }

        return hasComicImage(in: middleContainer)
    }
}

enum XkcdComicExcerptRule: ExcerptSiteRule {
    static let id = "xkcd-comic-excerpt"

    static func apply(currentExcerpt: String?, articleContent: Element, sourceURL: URL?, document: Document) throws -> String? {
        guard let middleContainer = try articleContent.select("#middleContainer").first(),
              hasComicImage(in: middleContainer),
              try middleContainer.text().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return currentExcerpt
        }

        return ""
    }
}

/// Prefer xkcd's high-resolution comic URL when the page provides a 2x srcset.
enum XkcdComicImageSourceRule: SerializationSiteRule {
    static let id = "xkcd-comic-image-source"

    static func apply(to articleContent: Element) throws {
        guard let middleContainer = try articleContent.select("#middleContainer").first() else {
            return
        }

        for image in try middleContainer.select("img") {
            guard isComicImage(image),
                  let highResolutionURL = twoXURL(from: (try? image.attr("srcset")) ?? "") else {
                continue
            }
            try image.attr("src", highResolutionURL)
        }
    }
}

private func findMiddleContainer(near candidate: Element) -> Element? {
    let chain = [candidate] + candidate.ancestors(maxDepth: 6)

    for node in chain {
        if node.id().trimmingCharacters(in: .whitespacesAndNewlines) == "middleContainer" {
            return node
        }

        guard let parent = node.parent() else { continue }
        for sibling in parent.children() {
            if sibling.id().trimmingCharacters(in: .whitespacesAndNewlines) == "middleContainer" {
                return sibling
            }
        }
    }

    return nil
}

private func hasComicImage(in element: Element) -> Bool {
    guard let images = try? element.select("img") else { return false }
    for image in images {
        if isComicImage(image) {
            return true
        }
    }
    return false
}

private func firstComicImageAlt(in element: Element) -> String? {
    guard let images = try? element.select("img") else { return nil }
    for image in images where isComicImage(image) {
        let alt = ((try? image.attr("alt")) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !alt.isEmpty {
            return alt
        }
    }
    return nil
}

private func isComicImage(_ image: Element) -> Bool {
    let src = ((try? image.attr("src")) ?? "").lowercased()
    let srcset = ((try? image.attr("srcset")) ?? "").lowercased()
    return src.contains("/comics/") || srcset.contains("/comics/")
}

private func twoXURL(from srcset: String) -> String? {
    for candidate in srcset.split(separator: ",") {
        let parts = candidate.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" })
        guard parts.count >= 2,
              parts[1] == "2x" else {
            continue
        }
        return String(parts[0])
    }
    return nil
}

private func hasXkcdFooterSibling(_ middleContainer: Element) -> Bool {
    guard let parent = middleContainer.parent() else { return false }
    for sibling in parent.children() {
        guard sibling.id().trimmingCharacters(in: .whitespacesAndNewlines) == "bottom" else {
            continue
        }
        if ((try? sibling.select("#comicLinks").isEmpty()) == false) {
            return true
        }
    }
    return false
}
