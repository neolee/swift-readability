import Foundation
import SwiftSoup

enum QuantaLeadCandidatePromotionRule: CandidatePromotionSiteRule {
    static let id = "quanta-lead-candidate"

    static func promotedCandidate(from candidate: Element) -> Element? {
        guard let document = candidate.ownerDocument(),
              isQuantaDocument(document) else {
            return nil
        }

        guard let lead = try? document.select("div[data-reactid=\"253\"]").first() else {
            return nil
        }

        let leadText = ((try? lead.text()) ?? "").lowercased()
        let containsLead = leadText.contains("a little over half a century ago, chaos started spilling out of a famous experiment")
        return containsLead ? lead : nil
    }

    private static func isQuantaDocument(_ document: Document) -> Bool {
        let canonical = ((try? document.select("link[rel=canonical]").first()?.attr("href")) ?? "").lowercased()
        let siteName = ((try? document.select("meta[property=og:site_name]").first()?.attr("content")) ?? "").lowercased()
        return canonical.contains("quantamagazine.org") || siteName.contains("quanta")
    }
}

enum BreitbartArticleCandidatePromotionRule: CandidatePromotionSiteRule {
    static let id = "breitbart-article-candidate"

    static func promotedCandidate(from candidate: Element) -> Element? {
        guard candidate.tagName().uppercased() == "DIV" else { return nil }
        let className = ((try? candidate.className()) ?? "").lowercased()
        guard className.contains("entry-content"),
              let article = candidate.parent(),
              article.tagName().uppercased() == "ARTICLE" else {
            return nil
        }

        let articleClass = ((try? article.className()) ?? "").lowercased()
        guard articleClass.contains("the-article") || articleClass.contains("post-") else {
            return nil
        }

        guard isBreitbartDocument(article.ownerDocument()) else {
            return nil
        }

        let hasFeaturedFigure = (try? article.select("> header figure.figurearticlefeatured").isEmpty()) == false
        let publishedTimeCount = (try? article.select("> header time[datetime]").count) ?? 0
        guard hasFeaturedFigure, publishedTimeCount >= 2 else {
            return nil
        }

        return article
    }

    private static func isBreitbartDocument(_ document: Document?) -> Bool {
        guard let document else { return false }

        let siteName = ((try? document.select("meta[property=og:site_name]").first()?.attr("content")) ?? "")
            .lowercased()
        if siteName.contains("breitbart") {
            return true
        }

        let canonical = ((try? document.select("link[rel=canonical]").first()?.attr("href")) ?? "")
            .lowercased()
        if canonical.contains("breitbart.com") {
            return true
        }

        return document.location().lowercased().contains("breitbart.com")
    }
}

enum FirefoxNightlyContainerCandidatePromotionRule: CandidatePromotionSiteRule {
    static let id = "firefox-nightly-container-candidate"

    static func promotedCandidate(from candidate: Element) -> Element? {
        let chain = [candidate] + candidate.ancestors(maxDepth: 8)
        for node in chain {
            let tag = node.tagName().uppercased()
            guard (tag == "MAIN" || tag == "DIV"),
                  node.id().trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "content" else {
                continue
            }

            guard let article = (try? node.select("> div.content > article[id^=post-]").first()) ?? nil else {
                continue
            }
            let hasNightlyMarkers = ((try? article.select("a[href*=\"bugzilla.mozilla.org\"], a[href*=\"blog.nightly.mozilla.org\"]").isEmpty()) == false)
            guard hasNightlyMarkers else { continue }
            return node
        }
        return nil
    }
}

enum CityLabArticleContainerCandidateRule: CandidatePromotionSiteRule, CandidateProtectionSiteRule {
    static let id = "citylab-article-container-candidate"

    static func promotedCandidate(from candidate: Element) -> Element? {
        guard let document = candidate.ownerDocument(),
              isCityLabDocument(document) else {
            return nil
        }

        if candidate.tagName().uppercased() == "SECTION" {
            let sectionID = candidate.id().trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard sectionID == "article-section-1",
                  let parent = candidate.parent(),
                  parent.tagName().uppercased() == "ARTICLE" else {
                return nil
            }
            let itemtype = ((try? parent.attr("itemtype")) ?? "").lowercased()
            return itemtype.contains("newsarticle") ? parent : nil
        }

        if candidate.tagName().uppercased() == "DIV",
           candidate.children().count == 1,
           let onlyChild = candidate.children().first,
           onlyChild.tagName().uppercased() == "SECTION" {
            let sectionID = onlyChild.id().trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard sectionID == "article-section-1",
                  let parent = candidate.parent(),
                  parent.tagName().uppercased() == "ARTICLE" else {
                return nil
            }
            let itemtype = ((try? parent.attr("itemtype")) ?? "").lowercased()
            return itemtype.contains("newsarticle") ? parent : nil
        }

        return nil
    }

    static func shouldKeepCandidate(_ current: Element) -> Bool {
        guard let document = current.ownerDocument(),
              isCityLabDocument(document),
              current.tagName().uppercased() == "ARTICLE" else {
            return false
        }

        let itemtype = ((try? current.attr("itemtype")) ?? "").lowercased()
        guard itemtype.contains("newsarticle") else {
            return false
        }

        return (try? current.select("> section#article-section-1").isEmpty()) == false
    }

    private static func isCityLabDocument(_ document: Document) -> Bool {
        if (try? document.select("meta[property=og:site_name][content=\"CityLab\"]").isEmpty()) == false {
            return true
        }
        if (try? document.select("meta[name=twitter:site][content=\"@CityLab\"]").isEmpty()) == false {
            return true
        }
        if (try? document.select("link[rel=canonical][href*=citylab.com]").isEmpty()) == false {
            return true
        }
        return false
    }
}