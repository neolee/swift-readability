import Foundation
import SwiftSoup

/// Extracts article content with multi-attempt fallback support
/// Implements Mozilla Readability.js grabArticle logic with FLAG-based retry
final class ContentExtractor {
    private let doc: Document
    private let options: ReadabilityOptions
    private var flags: UInt32
    private var attempts: [ExtractionAttempt]
    private var pageCacheHtml: String?
    private var articleByline: String?

    /// Represents a single extraction attempt
    struct ExtractionAttempt {
        let articleContent: Element
        let textLength: Int
        let flags: UInt32
    }

    init(doc: Document, options: ReadabilityOptions) {
        self.doc = doc
        self.options = options
        self.flags = Configuration.flagStripUnlikelies |
                     Configuration.flagWeightClasses |
                     Configuration.flagCleanConditionally
        self.attempts = []
    }

    // MARK: - Main Extraction

    /// Extract article content with multi-attempt fallback
    /// - Returns: Tuple of (article content element, byline, neededToCreate)
    /// - Throws: ReadabilityError if extraction fails
    func extract() throws -> (content: Element, byline: String?, neededToCreate: Bool) {
        guard let body = doc.body() else {
            throw ReadabilityError.elementNotFound("body")
        }

        // Cache original HTML for restoration
        pageCacheHtml = try body.html()

        var result: (content: Element, byline: String?, neededToCreate: Bool)?

        // Multi-attempt loop
        while true {
            // Reset byline for each attempt
            articleByline = nil

            // Create fresh scorer for each attempt
            let scoringManager = NodeScoringManager()

            // Perform extraction
            let attemptResult = try performExtraction(
                from: body,
                scoringManager: scoringManager
            )

            // Check if content is long enough
            let textLength = try attemptResult.content.text().count

            if textLength >= options.charThreshold {
                // Success!
                result = (
                    content: attemptResult.content,
                    byline: articleByline ?? attemptResult.byline,
                    neededToCreate: attemptResult.neededToCreate
                )
                break
            }

            // Content too short, track attempt
            attempts.append(ExtractionAttempt(
                articleContent: attemptResult.content,
                textLength: textLength,
                flags: flags
            ))

            // Try with different flags
            if tryNextFlag() {
                // Restore original HTML for next attempt
                try body.html(pageCacheHtml!)
                continue
            } else {
                // No more flags to try, use best attempt
                if let bestAttempt = attempts.max(by: { $0.textLength < $1.textLength }),
                   bestAttempt.textLength > 0 {
                    result = (
                        content: bestAttempt.articleContent,
                        byline: articleByline,
                        neededToCreate: false
                    )
                    break
                } else {
                    // Complete failure
                    throw ReadabilityError.contentTooShort(
                        actualLength: textLength,
                        threshold: options.charThreshold
                    )
                }
            }
        }

        guard let finalResult = result else {
            throw ReadabilityError.noContent
        }

        return finalResult
    }

    // MARK: - Single Extraction Attempt

    private func performExtraction(
        from body: Element,
        scoringManager: NodeScoringManager
    ) throws -> (content: Element, byline: String?, neededToCreate: Bool) {
        let cleaner = NodeCleaner(options: options)
        let selector = CandidateSelector(options: options, scoringManager: scoringManager)

        // Phase 1: Remove unlikely candidates and extract byline
        if isFlagActive(Configuration.flagStripUnlikelies) {
            try cleaner.removeUnlikelyCandidates(
                from: body,
                stripUnlikelyCandidates: true
            )
        }

        // Extract byline from document if not already found
        if articleByline == nil {
            articleByline = try extractByline(from: body, cleaner: cleaner)
        }

        // Phase 2: Collect and score elements
        let elementsToScore = try collectElementsToScore(from: body)

        for element in elementsToScore {
            let score = try scoreElement(element, scoringManager: scoringManager)
            if score > 0 {
                // Propagate score to ancestors
                selector.propagateScoreToAncestors(element, score: score)
            }
        }

        // Phase 3: Select top candidate from all scored elements
        // Get all elements that have been initialized (have scores)
        let scoredElements = try body.select("*").filter { element in
            scoringManager.isInitialized(element)
        }

        let (topCandidate, neededToCreate) = try selector.selectTopCandidate(
            from: scoredElements,
            in: doc
        )

        // Phase 4: Merge siblings
        let merger = SiblingMerger(options: options, scoringManager: scoringManager)
        let articleContent = try merger.mergeSiblings(
            topCandidate: topCandidate,
            in: doc
        )

        return (content: articleContent, byline: articleByline, neededToCreate: neededToCreate)
    }

    // MARK: - Byline Extraction

    /// Extract byline from HTML content
    /// Traverses all nodes looking for author indicators
    private func extractByline(from body: Element, cleaner: NodeCleaner) throws -> String? {
        var node: Element? = body

        while let current = node {
            let matchString = getMatchString(current)

            // Check if this node contains a valid byline
            if cleaner.checkAndExtractByline(current, matchString: matchString) {
                // Found byline, remove the node and return
                let byline = cleaner.getExtractedByline()
                _ = DOMTraversal.removeAndGetNext(current)
                return byline
            }

            node = DOMTraversal.getNextNode(current)
        }

        return nil
    }

    /// Get match string (class + id) for pattern matching
    private func getMatchString(_ element: Element) -> String {
        let className = (try? element.className()) ?? ""
        let id = element.id()
        return "\(className) \(id)".lowercased()
    }

    // MARK: - Element Collection

    private func collectElementsToScore(from body: Element) throws -> [Element] {
        var elements: [Element] = []

        for tagName in Configuration.defaultTagsToScore {
            let found = try body.select(tagName.lowercased())
            for element in found {
                // Skip hidden elements
                if DOMHelpers.isProbablyVisible(element) {
                    elements.append(element)
                }
            }
        }

        return elements
    }

    // MARK: - Element Scoring

    private func scoreElement(
        _ element: Element,
        scoringManager: NodeScoringManager
    ) throws -> Double {
        let text = try element.text()
        let textLength = text.count

        // Skip short elements
        if textLength < 25 {
            return 0
        }

        // Initialize and score
        var score = scoringManager.initializeNode(element).contentScore

        // Add comma score
        let commaCount = text.filter { $0 == "," }.count
        score += Double(commaCount)

        // Add length score (max 3)
        score += min(Double(textLength) / 100.0, 3.0)

        // Add class weight if flag enabled
        if isFlagActive(Configuration.flagWeightClasses) {
            score += scoringManager.getClassWeight(for: element)
        }

        // Apply link density penalty
        let linkDensity = try scoringManager.getLinkDensity(for: element)
        score *= (1.0 - linkDensity + options.linkDensityModifier)

        // Update score in manager
        scoringManager.addToScore(score, for: element)

        return score
    }

    // MARK: - Flag Management

    private func isFlagActive(_ flag: UInt32) -> Bool {
        return (flags & flag) != 0
    }

    private func removeFlag(_ flag: UInt32) {
        flags &= ~flag
    }

    /// Try next flag configuration
    /// Returns true if there are more flags to try
    private func tryNextFlag() -> Bool {
        if isFlagActive(Configuration.flagStripUnlikelies) {
            removeFlag(Configuration.flagStripUnlikelies)
            return true
        } else if isFlagActive(Configuration.flagWeightClasses) {
            removeFlag(Configuration.flagWeightClasses)
            // Restore STRIP_UNLIKELYS for next iteration
            flags |= Configuration.flagStripUnlikelies
            return true
        } else if isFlagActive(Configuration.flagCleanConditionally) {
            removeFlag(Configuration.flagCleanConditionally)
            // Restore other flags
            flags |= Configuration.flagStripUnlikelies | Configuration.flagWeightClasses
            return true
        }
        return false
    }

    // MARK: - Debug Info

    /// Get information about extraction attempts (for debugging)
    func getAttemptInfo() -> [(textLength: Int, flags: String)] {
        return attempts.map { attempt in
            let flagNames = [
                (Configuration.flagStripUnlikelies, "STRIP_UNLIKELYS"),
                (Configuration.flagWeightClasses, "WEIGHT_CLASSES"),
                (Configuration.flagCleanConditionally, "CLEAN_COND")
            ].filter { attempt.flags & $0.0 != 0 }.map { $0.1 }

            return (textLength: attempt.textLength, flags: flagNames.joined(separator: ", "))
        }
    }
}


