import Foundation
import SwiftSoup

protocol SiteRule {
    static var id: String { get }
}

protocol ArticleCleanerSiteRule: SiteRule {
    static func apply(to articleContent: Element, context: ArticleCleanerSiteRuleContext) throws
}

struct ArticleCleanerSiteRuleContext {
    let getLinkDensity: (Element) throws -> Double
}

protocol SerializationSiteRule: SiteRule {
    static func apply(to articleContent: Element) throws
}
