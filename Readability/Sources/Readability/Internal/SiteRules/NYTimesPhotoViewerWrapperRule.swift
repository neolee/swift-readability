import Foundation
import SwiftSoup

/// Flattens NYTimes photoviewer wrapper internals to align with Mozilla output shape.
///
/// SiteRule Metadata:
/// - Scope: NYTimes `photoviewer-wrapper` nested child container flattening
/// - Phase: `postProcess` cleanup
/// - Trigger: `div[data-testid=photoviewer-wrapper] > div[data-testid=photoviewer-children]`
/// - Evidence: `realworld/nytimes-4`, `realworld/nytimes-5`
/// - Risk if misplaced: extra wrapper depth in serialized article body
enum NYTimesPhotoViewerWrapperRule: ArticleCleanerSiteRule {
    static let id = "nytimes-photoviewer-wrapper"

    static func apply(to articleContent: Element, context _: ArticleCleanerSiteRuleContext) throws {
        for inner in try articleContent.select("div[data-testid=photoviewer-wrapper] > div[data-testid=photoviewer-children]") {
            while let node = inner.getChildNodes().first {
                try inner.before(node)
            }
            try inner.remove()
        }
    }
}
