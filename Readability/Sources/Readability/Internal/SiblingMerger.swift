import Foundation
import SwiftSoup

/// Merges sibling content into the article content
/// Implements Mozilla Readability.js sibling merging logic
final class SiblingMerger {
    private let options: ReadabilityOptions
    private let scoringManager: NodeScoringManager

    init(options: ReadabilityOptions, scoringManager: NodeScoringManager) {
        self.options = options
        self.scoringManager = scoringManager
    }

    // MARK: - Main Sibling Merging

    /// Merge sibling content into article content
    /// - Parameters:
    ///   - topCandidate: The top candidate element
    ///   - doc: The document for creating elements
    /// - Returns: Article content element with merged siblings
    /// - Throws: SwiftSoup errors
    func mergeSiblings(topCandidate: Element, in doc: Document) throws -> Element {
        // Create article content container
        let articleContent = try doc.createElement("div")

        // Calculate sibling score threshold
        let siblingScoreThreshold = calculateSiblingScoreThreshold(for: topCandidate)

        // Get parent and siblings
        guard let parentOfTopCandidate = topCandidate.parent() else {
            // If no parent, clone the top candidate into document context
            let clone = try DOMHelpers.cloneElement(topCandidate, in: doc)
            try articleContent.appendChild(clone)
            return articleContent
        }

        let siblings = parentOfTopCandidate.children()

        // Get top candidate's class name for bonus calculation
        let topCandidateClassName = (try? topCandidate.className()) ?? ""

        for sibling in siblings {
            let shouldAppend = try shouldAppendSibling(
                sibling,
                topCandidate: topCandidate,
                topCandidateClassName: topCandidateClassName,
                threshold: siblingScoreThreshold
            )

            if shouldAppend {
                // Alter tag if needed (convert to DIV unless in exceptions)
                let alteredSibling = try alterToDivIfNeeded(sibling, in: doc)
                try articleContent.appendChild(alteredSibling)
            }
        }

        return articleContent
    }

    // MARK: - Sibling Append Decision

    /// Determine if a sibling should be appended to article content
    private func shouldAppendSibling(
        _ sibling: Element,
        topCandidate: Element,
        topCandidateClassName: String,
        threshold: Double
    ) throws -> Bool {
        // Always append the top candidate itself
        if sibling === topCandidate {
            return true
        }

        var contentBonus: Double = 0

        // Give a bonus if sibling nodes and top candidates have the same class name
        let siblingClassName = (try? sibling.className()) ?? ""
        if !topCandidateClassName.isEmpty && siblingClassName == topCandidateClassName {
            let topScore = scoringManager.getContentScore(for: topCandidate)
            contentBonus += topScore * Configuration.siblingClassNameBonusRatio
        }

        // Check if sibling has a score above threshold
        let siblingScore = scoringManager.getContentScore(for: sibling)
        if siblingScore + contentBonus >= threshold {
            return true
        }

        // Special handling for P tags
        if sibling.tagName().uppercased() == "P" {
            return try shouldAppendParagraph(sibling)
        }

        return false
    }

    // MARK: - Paragraph Special Handling

    /// Special handling for P tag siblings
    private func shouldAppendParagraph(_ p: Element) throws -> Bool {
        let linkDensity = try scoringManager.getLinkDensity(for: p)
        let nodeContent = try p.text()
        let nodeLength = nodeContent.count

        // Long paragraph with low link density
        if nodeLength > Configuration.paragraphLengthLong &&
           linkDensity < Configuration.linkDensityThresholdLong {
            return true
        }

        // Short paragraph with no links and ends with period
        if nodeLength > 0 &&
           nodeLength < Configuration.paragraphLengthLong &&
           linkDensity == 0 &&
           nodeContent.range(of: "\\.( |$)", options: .regularExpression) != nil {
            return true
        }

        return false
    }

    // MARK: - DIV Alteration

    /// Alter sibling to DIV if needed
    /// Elements in ALTER_TO_DIV_EXCEPTIONS are kept as-is
    /// Preserves the original order of child nodes (elements and text)
    private func alterToDivIfNeeded(_ element: Element, in doc: Document) throws -> Element {
        let tagName = element.tagName().uppercased()

        // Check if element is in exception list
        if Configuration.alterToDIVExceptions.contains(tagName) {
            // Clone into document context to ensure proper ownership
            return try DOMHelpers.cloneElement(element, in: doc)
        }

        // Create new DIV and move children using document context
        let div = try doc.createElement("div")

        // Copy attributes
        if let attributes = element.getAttributes() {
            for attr in attributes {
                try div.attr(attr.getKey(), attr.getValue())
            }
        }

        // Clone all child nodes in their original order
        // Use getChildNodes() to preserve mixed element/text order
        for node in element.getChildNodes() {
            if let childElement = node as? Element {
                // Recursively clone element children
                let clone = try DOMHelpers.cloneElement(childElement, in: doc)
                try div.appendChild(clone)
            } else if let textNode = node as? TextNode {
                // Clone text nodes in their original position
                let textClone = TextNode(textNode.text(), doc.location())
                try div.appendChild(textClone)
            }
        }

        return div
    }

    // MARK: - Score Threshold Calculation

    /// Calculate the sibling score threshold for content merging
    /// - Parameter topCandidate: The top candidate element
    /// - Returns: Minimum score for siblings to be included
    func calculateSiblingScoreThreshold(for topCandidate: Element) -> Double {
        let topScore = scoringManager.getContentScore(for: topCandidate)
        return max(
            Configuration.siblingScoreThresholdMinimum,
            topScore * Configuration.siblingScoreThresholdRatio
        )
    }
}

// MARK: - Article Content Creation

extension SiblingMerger {

    /// Create article content wrapper with proper ID and class
    /// - Parameter doc: Document for creating elements
    /// - Returns: Article content div
    func createArticleContentWrapper(in doc: Document) throws -> Element {
        let div = try doc.createElement("div")
        try div.attr("id", "readability-content")
        return div
    }

    /// Create page wrapper for multi-page support
    /// - Parameters:
    ///   - doc: Document for creating elements
    ///   - pageNumber: Page number for ID
    /// - Returns: Page div
    func createPageWrapper(in doc: Document, pageNumber: Int = 1) throws -> Element {
        let div = try doc.createElement("div")
        try div.attr("id", "readability-page-\(pageNumber)")
        try div.addClass("page")
        return div
    }
}
