import Foundation
import SwiftSoup

/// Removes antirez trailing Disqus promo/footer block from extracted article content.
///
/// SiteRule Metadata:
/// - Scope: antirez trailing comment promo footer
/// - Phase: `unwanted` cleanup
/// - Trigger: trailing `<p>` containing `https://disqus.com/` link and `blog comments powered by Disqus`
/// - Evidence: `ex-pages/antirez-*`
/// - Risk if misplaced: could remove legitimate footer links if the exact Disqus promo text is reused elsewhere
enum AntirezDisqusFooterRule: ArticleCleanerSiteRule {
    static let id = "antirez-disqus-footer"

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        for paragraph in try articleContent.select("p").reversed() {
            let text = (try? paragraph.text())?
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard text.caseInsensitiveCompare("blog comments powered by Disqus") == .orderedSame else {
                continue
            }

            let hasDisqusLink = (try? paragraph.select("a[href*='disqus.com']").isEmpty()) == false
            guard hasDisqusLink else { continue }

            try paragraph.remove()
        }

        try articleContent.select("a.dsq-brlink[href*='disqus.com']").remove()
        try articleContent.select("div#disqus_thread_outdiv, div#disqus_thread").remove()
    }
}
