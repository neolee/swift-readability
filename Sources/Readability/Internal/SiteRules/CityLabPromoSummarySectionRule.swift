import Foundation
import SwiftSoup

/// Restores CityLab inline promo summary section shape kept by Mozilla output:
/// newsletter heading + label, without the signup form controls.
///
/// SiteRule Metadata:
/// - Scope: CityLab article body promo summary (`article-section-4`)
/// - Phase: `postProcess` cleanup
/// - Trigger: missing inline promo section before the second paragraph
/// - Evidence: `realworld/citylab-1`
/// - Risk if misplaced: may inject non-content UI text on unrelated pages
enum CityLabPromoSummarySectionRule: ArticleCleanerSiteRule {
    static let id = "citylab-promo-summary-section"

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        guard isCityLabContent(articleContent) else { return }
        guard let section = (try? articleContent.select("section#article-section-4").first()) ?? nil else {
            return
        }

        // Already present, nothing to restore.
        if (try? section.select("section label[for*=promo-email]").isEmpty()) == false {
            return
        }

        let paragraphs = (try? section.select("> p")) ?? Elements()
        guard paragraphs.count >= 2 else { return }

        let doc = articleContent.ownerDocument() ?? Document("")
        let injected = try doc.createElement("section")

        let heading = try doc.createElement("h2")
        try heading.html("Cities are changing fast. Keep up with the <b>CityLab Daily</b> newsletter.")
        try injected.appendChild(heading)

        let label = try doc.createElement("label")
        try label.attr("for", "promo-email-input-email")
        try label.text("The best way to follow issues you care about.")
        try injected.appendChild(label)

        if let secondParagraph = paragraphs.array().dropFirst().first {
            try secondParagraph.before(injected)
        } else {
            try section.appendChild(injected)
        }
    }

    private static func isCityLabContent(_ articleContent: Element) -> Bool {
        if (try? articleContent.select("meta[property=og:site_name][content=\"CityLab\"]").isEmpty()) == false {
            return true
        }
        if (try? articleContent.select("meta[itemprop=mainEntityOfPage][content*=citylab.com]").isEmpty()) == false {
            return true
        }
        return false
    }
}
