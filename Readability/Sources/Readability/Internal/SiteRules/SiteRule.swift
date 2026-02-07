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
    let setNodeTag: ((Element, String) throws -> Element)?

    init(
        getLinkDensity: @escaping (Element) throws -> Double,
        setNodeTag: ((Element, String) throws -> Element)? = nil
    ) {
        self.getLinkDensity = getLinkDensity
        self.setNodeTag = setNodeTag
    }
}

protocol SerializationSiteRule: SiteRule {
    static func apply(to articleContent: Element) throws
}
