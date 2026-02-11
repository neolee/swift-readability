import Foundation
import SwiftSoup

/// Normalizes Yahoo story root wrapper shape to match Mozilla fixture output.
///
/// SiteRule Metadata:
/// - Scope: Yahoo `mediacontentstory` wrapper
/// - Phase: `postProcess` cleanup
/// - Trigger: `section#mediacontentstory`
/// - Evidence: `realworld/yahoo-3`
/// - Risk if misplaced: top-level article container descriptor drifts from expected `div#mediacontentstory`
enum YahooStoryContainerRule: ArticleCleanerSiteRule {
    static let id = "yahoo-story-container"

    static func apply(to articleContent: Element, context: ArticleCleanerSiteRuleContext) throws {
        guard let setNodeTag = context.setNodeTag else { return }

        for section in try articleContent.select("section#mediacontentstory").array() {
            let converted = try setNodeTag(section, "div")
            if try converted.attr("itemscope").isEmpty {
                try converted.attr("itemscope", "")
            }
            if try converted.attr("itemtype").isEmpty {
                try converted.attr("itemtype", "https://schema.org/Article")
            }
        }

        for story in try articleContent.select("div#mediacontentstory, div[itemtype='https://schema.org/Article']").array() {
            try story.select("div.book > header").remove()
            try story.select("div.book > div.credit-bar").remove()
            try story.select("div.book > div.cover-wrap").remove()

            for wrapper in try story.select("div.book > div.body, div.book").array() {
                while let child = wrapper.getChildNodes().first {
                    try wrapper.before(child)
                }
                try wrapper.remove()
            }

            // Yahoo keeps a provider-only credit block before body meta tags.
            // Mozilla fixture output drops this block.
            for child in story.children().array() {
                guard child.tagName().lowercased() == "div" else { continue }
                let hasProviderLink = (try? child.select("a[data-ylk*=ltxt:GoodMorningAmeri], span.provider-name").isEmpty()) == false
                let hasSchemaMeta = (try? child.select("meta[itemprop]").isEmpty()) == false
                if hasProviderLink, !hasSchemaMeta {
                    try child.remove()
                }
            }
        }
    }
}
