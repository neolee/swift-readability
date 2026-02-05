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
            // If no parent, just append the top candidate
            if let clone = topCandidate.copy() as? Element {
                try articleContent.appendChild(clone)
            }
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
                let alteredSibling = try alterToDivIfNeeded(sibling)
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
    private func alterToDivIfNeeded(_ element: Element) throws -> Element {
        let tagName = element.tagName().uppercased()

        // Check if element is in exception list
        if Configuration.alterToDIVExceptions.contains(tagName) {
            if let clone = element.copy() as? Element {
                return clone
            }
            return element
        }

        // Create new DIV and move children
        let div = Element(Tag("div"), "")

        // Copy attributes
        if let attributes = element.getAttributes() {
            for attr in attributes {
                try div.attr(attr.getKey(), attr.getValue())
            }
        }

        // Copy children
        for child in element.children() {
            if let clone = child.copy() as? Element {
                try div.appendChild(clone)
            }
        }

        // Copy text nodes
        for textNode in element.textNodes() {
            try div.appendText(textNode.text())
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

    // MARK: - Content Appending with Shifting

    /// Append siblings to article content with proper index handling
    /// This mirrors Mozilla's approach of re-fetching children after append
    func appendSiblingsToArticle(
        from parent: Element,
        to articleContent: Element,
        topCandidate: Element,
        threshold: Double
    ) throws {
        let topCandidateClassName = (try? topCandidate.className()) ?? ""
        var siblingsToProcess = parent.children()

        var index = 0
        while index < siblingsToProcess.count {
            let sibling = siblingsToProcess[index]

            let shouldAppend = try shouldAppendSibling(
                sibling,
                topCandidate: topCandidate,
                topCandidateClassName: topCandidateClassName,
                threshold: threshold
            )

            if shouldAppend {
                let alteredSibling = try alterToDivIfNeeded(sibling)
                try articleContent.appendChild(alteredSibling)

                // Re-fetch children since we modified the DOM
                siblingsToProcess = parent.children()
                // Don't increment index since we removed the current element
            } else {
                index += 1
            }
        }
    }

    // MARK: - Link Density Check for Siblings

    /// Check if sibling has acceptable link density
    private func hasAcceptableLinkDensity(_ element: Element, isList: Bool = false) throws -> Bool {
        let linkDensity = try scoringManager.getLinkDensity(for: element)

        if isList {
            // Lists are allowed to have higher link density
            return linkDensity < 0.5 + options.linkDensityModifier
        } else {
            return linkDensity < 0.25 + options.linkDensityModifier
        }
    }

    // MARK: - Content Length Check

    /// Check if element has meaningful content length
    private func hasContentLength(_ element: Element, minLength: Int = 25) throws -> Bool {
        let text = try element.text()
        return text.count >= minLength
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
