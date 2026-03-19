import Foundation
import SwiftSoup

protocol SiteRule {
    static var id: String { get }
}

enum ArticleCleanerSiteRulePhase: String {
    case unwantedElements = "unwanted-elements"
    case preConversion = "pre-conversion"
    case shareCleanup = "share-cleanup"
    case postParagraph = "post-paragraph"
    case postProcess = "post-process"
}

enum SiblingMergeSiteRulePhase: String {
    case leadingAssociatedContent = "leading-associated-content"
    case siblingInclude = "sibling-include"
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

protocol BylineSiteRule: SiteRule {
    static func apply(byline: String?, sourceURL: URL?, document: Document) throws -> String?
}

protocol BylineContainerRetentionSiteRule: SiteRule {
    static func shouldKeepBylineContainer(_ node: Element, sourceURL: URL?, document: Document) throws -> Bool
}

/// Allows a site rule to force-include a sibling of the top candidate.
/// Return `true` to include, `false` to exclude, `nil` to defer to default logic.
protocol SiblingInclusionSiteRule: SiteRule {
    static func shouldIncludeSibling(_ sibling: Element, topCandidate: Element) throws -> Bool?
}

/// Allows a site rule to extract a sub-element from a sibling and include only that sub-element.
/// If a rule returns a non-nil element, the full sibling is skipped and the extracted element is
/// appended to article content instead. Return `nil` to defer to default logic.
protocol SiblingExtractSiteRule: SiteRule {
    static func extractFromSibling(_ sibling: Element, topCandidate: Element) throws -> Element?
}
