import Foundation
import SwiftSoup

/// Extracts article content with multi-attempt fallback support
/// Implements Mozilla Readability.js grabArticle logic with FLAG-based retry
final class ContentExtractor {
    private let doc: Document
    private let options: ReadabilityOptions
    private let articleTitle: String
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

    init(doc: Document, options: ReadabilityOptions, articleTitle: String = "") {
        self.doc = doc
        self.options = options
        self.articleTitle = articleTitle
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
        cleaner.setArticleTitle(articleTitle)
        let selector = CandidateSelector(options: options, scoringManager: scoringManager)

        // Phase 1: Remove unlikely candidates and extract byline
        if isFlagActive(Configuration.flagStripUnlikelies) {
            try cleaner.removeUnlikelyCandidates(
                from: body,
                stripUnlikelyCandidates: true
            )
        }

        // Ensure hidden nodes never leak into scoring or fallback attempts.
        try VisibilityRules.removeHiddenElements(from: body)

        // Extract byline from document if not already found
        if articleByline == nil {
            articleByline = try extractByline(from: body, cleaner: cleaner)
        }

        // Phase 2: Collect and score elements
        let elementsToScore = try collectElementsToScore(from: body, cleaner: cleaner)

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

    private func collectElementsToScore(from body: Element, cleaner: NodeCleaner) throws -> [Element] {
        var elements: [Element] = []
        let defaultTags = Set(Configuration.defaultTagsToScore.map { $0.uppercased() })
        let blockTags = Set(Configuration.divToPElements.map { $0.uppercased() })

        var node: Element? = body
        while let current = node {
            let tag = current.tagName().uppercased()

            if (tag == "H1" || tag == "H2"), cleaner.headerDuplicatesTitle(current) {
                node = DOMTraversal.removeAndGetNext(current)
                continue
            }

            if ["H1", "H2", "H3", "H4", "H5", "H6"].contains(tag),
               DOMTraversal.isElementWithoutContent(current) {
                node = DOMTraversal.removeAndGetNext(current)
                continue
            }

            if defaultTags.contains(current.tagName().uppercased()) {
                elements.append(current)
            }

            if current.tagName().uppercased() == "DIV" {
                var childNode = current.getChildNodes().first
                while let child = childNode {
                    var nextSibling = child.nextSibling()

                    if isPhrasingContent(child) {
                        var fragment: [Node] = []
                        var cursor: Node? = child
                        while let phrasingNode = cursor, isPhrasingContent(phrasingNode) {
                            nextSibling = phrasingNode.nextSibling()
                            fragment.append(phrasingNode)
                            cursor = nextSibling
                        }

                        while let first = fragment.first, DOMTraversal.isWhitespace(first) {
                            try first.remove()
                            fragment.removeFirst()
                        }
                        while let last = fragment.last, DOMTraversal.isWhitespace(last) {
                            try last.remove()
                            fragment.removeLast()
                        }

                        if !fragment.isEmpty {
                            let p = try doc.createElement("p")
                            if let next = nextSibling {
                                try next.before(p)
                            } else {
                                try current.appendChild(p)
                            }
                            for fragmentNode in fragment where fragmentNode.parent() != nil {
                                try p.appendChild(fragmentNode)
                            }
                        }
                    }

                    childNode = nextSibling
                }

                if hasSingleTagInsideElement(current, tag: "P"),
                   try getLinkDensity(current) < 0.25,
                   !shouldPreserveSingleParagraphWrapper(current) {
                    if let newNode = current.children().first {
                        try current.replaceWith(newNode)
                        elements.append(newNode)
                        node = DOMTraversal.getNextNode(newNode)
                        continue
                    }
                } else if !hasChildBlockElement(current, blockTags: blockTags) {
                    if hasContainerIdentity(current) {
                        node = DOMTraversal.getNextNode(current)
                        continue
                    }
                    let newNode = try setNodeTag(current, newTag: "p")
                    elements.append(newNode)
                    node = DOMTraversal.getNextNode(newNode)
                    continue
                }
            }

            node = DOMTraversal.getNextNode(current)
        }

        return elements
    }

    private func hasSingleTagInsideElement(_ element: Element, tag: String) -> Bool {
        let children = element.children()
        guard children.count == 1,
              children.first?.tagName().uppercased() == tag.uppercased() else {
            return false
        }

        for textNode in element.textNodes() {
            if !textNode.text().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return false
            }
        }

        return true
    }

    private func hasChildBlockElement(_ element: Element, blockTags: Set<String>) -> Bool {
        for childNode in element.getChildNodes() {
            guard let child = childNode as? Element else { continue }
            if blockTags.contains(child.tagName().uppercased()) {
                return true
            }
            if hasChildBlockElement(child, blockTags: blockTags) {
                return true
            }
        }
        return false
    }

    private func isPhrasingContent(_ node: Node) -> Bool {
        if node is TextNode {
            return true
        }
        guard let element = node as? Element else { return false }

        let phrasingTags = Set(Configuration.phrasingElements.map { $0.uppercased() })
        let tagName = element.tagName().uppercased()
        if phrasingTags.contains(tagName) {
            return true
        }

        if ["A", "DEL", "INS"].contains(tagName) {
            for child in element.children() where !isPhrasingContent(child) {
                return false
            }
            return true
        }

        return false
    }

    private func getLinkDensity(_ element: Element) throws -> Double {
        let textLength = try DOMHelpers.getInnerText(element).count
        if textLength == 0 {
            return 0
        }

        let links = try element.select("a")
        var linkLength = 0.0
        for link in links {
            let href = (try? link.attr("href")) ?? ""
            let coefficient = href.hasPrefix("#") ? 0.3 : 1.0
            linkLength += Double(try DOMHelpers.getInnerText(link).count) * coefficient
        }
        return linkLength / Double(textLength)
    }

    private func setNodeTag(_ element: Element, newTag: String) throws -> Element {
        let newElement = try doc.createElement(newTag.lowercased())
        try DOMHelpers.copyAttributes(from: element, to: newElement)
        while let firstChild = element.getChildNodes().first {
            try newElement.appendChild(firstChild)
        }
        try element.replaceWith(newElement)
        return newElement
    }

    private func hasContainerIdentity(_ element: Element) -> Bool {
        if !element.id().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        let className = ((try? element.className()) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return !className.isEmpty
    }

    private func shouldPreserveSingleParagraphWrapper(_ element: Element) -> Bool {
        guard hasContainerIdentity(element) else { return false }
        // Keep explicit container identity for embedded media blocks only.
        return ((try? element.select("iframe, embed, object, video").isEmpty()) == false)
    }

    // MARK: - Element Scoring

    private func scoreElement(
        _ element: Element,
        scoringManager: NodeScoringManager
    ) throws -> Double {
        if !DOMHelpers.isProbablyVisible(element) {
            return 0
        }

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
