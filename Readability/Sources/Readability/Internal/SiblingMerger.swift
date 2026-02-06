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

        let hasRTLDirectionInContext = hasRTLDirection(from: topCandidate)
        try unwrapRedundantSingleDivWrapper(
            in: articleContent,
            preserveWrapper: hasRTLDirectionInContext
        )
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

        // Preserve trailing BR nodes that follow included content.
        if sibling.tagName().uppercased() == "BR" && (try? sibling.nextElementSibling()) == nil {
            return true
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
        try DOMHelpers.copyAttributes(from: element, to: div)
        try DOMHelpers.cloneChildNodes(from: element, to: div, in: doc)

        return div
    }

    /// Mozilla output often has direct children under article content.
    /// If we end up with a single anonymous DIV wrapper, unwrap it.
    private func unwrapRedundantSingleDivWrapper(
        in articleContent: Element,
        preserveWrapper: Bool
    ) throws {
        if preserveWrapper {
            return
        }

        guard articleContent.children().count == 1,
              let onlyChild = articleContent.children().first,
              onlyChild.tagName().uppercased() == "DIV" else {
            return
        }

        var attrCount = 0
        if let attrs = onlyChild.getAttributes() {
            for _ in attrs {
                attrCount += 1
            }
        }

        guard onlyChild.id().isEmpty,
              ((try? onlyChild.className()) ?? "").isEmpty,
              attrCount == 0 else {
            return
        }

        // Keep wrappers that contain only paragraph children.
        let elementChildren = onlyChild.children()
        if !elementChildren.isEmpty,
           elementChildren.allSatisfy({ $0.tagName().uppercased() == "P" }) {
            return
        }

        // Do not unwrap wrappers that only contain tabular structure.
        if try onlyChild.select("table").count > 0 && onlyChild.children().count == 1 {
            return
        }

        let children = onlyChild.getChildNodes()
        for node in children {
            try articleContent.appendChild(node)
        }
        try onlyChild.remove()
    }

    /// Preserve wrapper when extraction context is in RTL direction.
    /// Mozilla keeps extra wrapper structure for several RTL fixtures.
    private func hasRTLDirection(from element: Element) -> Bool {
        func isRTL(_ candidate: Element) -> Bool {
            let dir = ((try? candidate.attr("dir")) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            return dir == "rtl"
        }

        if isRTL(element) {
            return true
        }

        if let nestedRTL = try? element.select("[dir=rtl]"),
           !nestedRTL.isEmpty() {
            return true
        }

        for ancestor in element.ancestors() where isRTL(ancestor) {
            return true
        }

        return false
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
