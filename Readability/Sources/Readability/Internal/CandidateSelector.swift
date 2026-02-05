import Foundation
import SwiftSoup

/// Selects the best content candidate from a list of scored elements
/// Implements Mozilla Readability.js candidate selection logic
final class CandidateSelector {
    private let options: ReadabilityOptions
    private let scoringManager: NodeScoringManager

    init(options: ReadabilityOptions, scoringManager: NodeScoringManager) {
        self.options = options
        self.scoringManager = scoringManager
    }

    // MARK: - Top Candidate Selection

    /// Select the top candidate from a list of elements
    /// - Parameters:
    ///   - elements: Elements to score and select from
    ///   - doc: The document for creating fallback elements
    /// - Returns: The selected top candidate element
    /// - Throws: SwiftSoup errors
    func selectTopCandidate(from elements: [Element], in doc: Document) throws -> (candidate: Element, neededToCreate: Bool) {
        let topCandidates = collectTopCandidates(from: elements)

        var topCandidate = topCandidates.best?.element
        var neededToCreateTopCandidate = false

        // If we still have no top candidate, just use the body as a last resort
        if topCandidate == nil || topCandidate?.tagName().uppercased() == "BODY" {
            if let body = doc.body() {
                topCandidate = createFallbackCandidate(from: body, in: doc)
                neededToCreateTopCandidate = true
            }
        } else if let candidate = topCandidate {
            // Find a better top candidate if it contains multiple top candidates
            topCandidate = try findBetterTopCandidate(from: candidate, topCandidates: topCandidates)

            // If top candidate is the only child, use parent instead
            topCandidate = try promoteSingleChildCandidate(candidate)

            // Ensure the candidate is initialized
            scoringManager.initializeNodeIfNeeded(topCandidate!)
        }

        // If still no candidate, create one
        if topCandidate == nil {
            topCandidate = doc.body() ?? doc
            neededToCreateTopCandidate = true
        }

        return (topCandidate!, neededToCreateTopCandidate)
    }

    // MARK: - Candidate Collection

    /// Collect and score elements into top candidates
    private func collectTopCandidates(from elements: [Element]) -> TopCandidates {
        let topCandidates = TopCandidates(maxCount: options.nbTopCandidates)

        for element in elements {
            // Get the score (already calculated during grabArticle)
            var score = scoringManager.getContentScore(for: element)

            // Apply link density scaling
            if let linkDensity = try? scoringManager.getLinkDensity(for: element) {
                score *= (1.0 - linkDensity)
            }

            // Update the score in the manager
            let linkDensity = (try? scoringManager.getLinkDensity(for: element)) ?? 0
            scoringManager.multiplyScore(by: (1.0 - linkDensity), for: element)

            // Add to top candidates
            if score > 0 {
                topCandidates.add(Candidate(element: element, score: score))
            }
        }

        return topCandidates
    }

    // MARK: - Alternative Ancestor Analysis

    /// Find a better top candidate if the current one contains multiple good candidates
    /// This implements the alternative ancestor analysis from Mozilla Readability.js
    func findBetterTopCandidate(from topCandidate: Element, topCandidates: TopCandidates) throws -> Element {
        // Need at least 2 other candidates to perform this analysis
        guard topCandidates.count >= 2 else { return topCandidate }

        let topScore = topCandidates.best?.score ?? 0
        guard topScore > 0 else { return topCandidate }

        // Find alternative candidates that are close in score
        var alternativeAncestors: [[Element]] = []

        for i in 1..<topCandidates.count {
            guard let candidate = topCandidates[i] else { continue }

            // If score is at least 75% of top candidate, consider it
            let scoreRatio = candidate.score / topScore
            if scoreRatio >= Configuration.minScoreRatioForAlternative {
                let ancestors = candidate.element.ancestors()
                alternativeAncestors.append(ancestors)
            }
        }

        // Need at least 3 alternative candidates
        guard alternativeAncestors.count >= Configuration.minimumTopCandidates else {
            return topCandidate
        }

        // Find a common ancestor that appears in at least 3 alternative ancestor lists
        var parentOfTopCandidate: Element? = topCandidate.parent()

        while let parent = parentOfTopCandidate,
              parent.tagName().uppercased() != "BODY" {

            var listsContainingAncestor = 0

            for ancestorList in alternativeAncestors {
                if ancestorList.contains(where: { $0 === parent }) {
                    listsContainingAncestor += 1
                }
                // Stop early if we've already found enough
                if listsContainingAncestor >= Configuration.minimumTopCandidates {
                    break
                }
            }

            if listsContainingAncestor >= Configuration.minimumTopCandidates {
                return parent
            }

            parentOfTopCandidate = parent.parent()
        }

        return topCandidate
    }

    // MARK: - Single Child Promotion

    /// If the top candidate is the only child, promote to parent
    /// This helps sibling joining logic find adjacent content
    func promoteSingleChildCandidate(_ candidate: Element) throws -> Element {
        var currentCandidate: Element = candidate
        var parentOfTopCandidate: Element? = candidate.parent()

        while let parent = parentOfTopCandidate,
              parent.tagName().uppercased() != "BODY",
              parent.children().count == 1 {
            currentCandidate = parent
            parentOfTopCandidate = parent.parent()
        }

        // Ensure the promoted candidate is initialized
        scoringManager.initializeNodeIfNeeded(currentCandidate)

        return currentCandidate
    }

    // MARK: - Parent Score Traversal

    /// Look up the tree for a better parent candidate based on scores
    /// This is used after selecting the top candidate to potentially find
    /// a parent with higher or similar score
    func findBetterParentCandidate(_ candidate: Element) -> Element {
        var currentCandidate = candidate
        var parentOfTopCandidate: Element? = candidate.parent()

        let lastScore = scoringManager.getContentScore(for: candidate)
        let scoreThreshold = lastScore / 3

        while let parent = parentOfTopCandidate,
              parent.tagName().uppercased() != "BODY" {

            // Skip if parent not initialized
            guard scoringManager.isInitialized(parent) else {
                parentOfTopCandidate = parent.parent()
                continue
            }

            let parentScore = scoringManager.getContentScore(for: parent)

            // If score is too low, stop
            if parentScore < scoreThreshold {
                break
            }

            // If parent has higher score, use it
            if parentScore > lastScore {
                currentCandidate = parent
                break
            }

            parentOfTopCandidate = parent.parent()
        }

        return currentCandidate
    }

    // MARK: - Fallback Candidate Creation

    /// Create a fallback candidate when no good candidates found
    /// Moves all body children into a new DIV
    private func createFallbackCandidate(from body: Element, in doc: Document) -> Element? {
        guard let div = try? doc.createElement("div") else { return nil }

        // Move all children from body to the new div
        while let child = body.children().first {
            do {
                try div.appendChild(child)
            } catch {
                break
            }
        }

        // Append the div to body
        do {
            try body.appendChild(div)
        } catch {
            return nil
        }

        // Initialize the new candidate
        scoringManager.initializeNode(div)

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

    // MARK: - Ancestor Score Propagation

    /// Propagate scores to ancestor elements
    /// This is called during grabArticle to give parent elements scores
    /// - Parameters:
    ///   - element: Element that was scored
    ///   - score: The score to propagate
    func propagateScoreToAncestors(_ element: Element, score: Double) {
        let ancestors = element.ancestors(maxDepth: 5)

        for (index, ancestor) in ancestors.enumerated() {
            // Skip nodes without valid parent
            guard ancestor.parent() != nil else { continue }

            // Initialize ancestor if needed
            if !scoringManager.isInitialized(ancestor) {
                scoringManager.initializeNode(ancestor)
            }

            // Calculate score divider based on level
            let scoreDivider: Double
            if index == 0 {
                scoreDivider = Configuration.ancestorScoreDividerParent // 1
            } else if index == 1 {
                scoreDivider = Configuration.ancestorScoreDividerGrandparent // 2
            } else {
                scoreDivider = Double(index) * Configuration.ancestorScoreDividerMultiplier // level * 3
            }

            let ancestorScore = score / scoreDivider
            scoringManager.addToScore(ancestorScore, for: ancestor)
        }
    }
}

// MARK: - Candidate Score Info

/// Information about a scored candidate for debugging/analysis
struct CandidateScoreInfo {
    let tagName: String
    let classAndId: String
    let score: Double
    let linkDensity: Double
}
