import Foundation
import SwiftSoup

/// Removes CityLab inline newsletter signup promo blocks from article body.
///
/// SiteRule Metadata:
/// - Scope: CityLab newsletter promo module
/// - Phase: `unwanted` cleanup
/// - Trigger: `form#promo-email` or `form[name=promo-email]`
/// - Evidence: `realworld/citylab-1`
/// - Risk if misplaced: may remove unrelated forms on non-CityLab pages
enum CityLabPromoSignupRule: ArticleCleanerSiteRule {
    static let id = "citylab-promo-signup"

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        guard isCityLabContent(articleContent) else { return }

        let forms = try articleContent.select("form#promo-email, form[name=promo-email]")
        for form in forms.reversed() {
            try form.remove()
        }
    }

    private static func isCityLabContent(_ articleContent: Element) -> Bool {
        if (try? articleContent.select("meta[itemprop=name][content=\"CityLab\"]").isEmpty()) == false {
            return true
        }
        if (try? articleContent.select("meta[itemprop=mainEntityOfPage][content*=citylab.com]").isEmpty()) == false {
            return true
        }
        return false
    }
}
