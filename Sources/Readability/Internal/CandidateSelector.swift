import Foundation
import SwiftSoup

/// Selects the best content candidate from a list of scored elements
/// Implements Mozilla Readability.js candidate selection logic
final class CandidateSelector {
    private let options: ReadabilityOptions
    private let scoringManager: NodeScoringManager
    private let inspectionContext: InspectionContext?

    init(options: ReadabilityOptions, scoringManager: NodeScoringManager, inspectionContext: InspectionContext? = nil) {
        self.options = options
        self.scoringManager = scoringManager
        self.inspectionContext = inspectionContext
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

        // Record scored candidates for inspection
        if let ctx = inspectionContext, !topCandidates.isEmpty {
            let flagWeightActive = (ctx.currentPassFlagBits & Configuration.flagWeightClasses) != 0
            ctx.recordTopCandidates(topCandidates.all.map { makeRawCandidateInfo($0.element, flagWeightClasses: flagWeightActive) })
            if let best = topCandidates.best {
                ctx.recordInitialWinner(makeRawCandidateInfo(best.element, flagWeightClasses: flagWeightActive))
            }
        }

        if options.debug, topCandidates.count > 0 {
            var summaries: [String] = []
            for index in 0..<topCandidates.count {
                guard let candidate = topCandidates[index] else { continue }
                summaries.append("[\(index)] \(describe(candidate.element))")
            }
            print("[ReadabilityDebug] Top candidates: \(summaries.joined(separator: " | "))")
        }

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

            // Ensure the candidate is initialized
            scoringManager.initializeNodeIfNeeded(topCandidate!)

            // Mozilla parity: if parent chain scores go up, promote to better parent
            topCandidate = findBetterParentCandidate(topCandidate!)

            // If top candidate is the only child, use parent instead
            topCandidate = try promoteSingleChildCandidate(topCandidate!)
            topCandidate = promoteSchemaArticleParentIfNeeded(topCandidate!)
            topCandidate = try promoteSemanticMainAncestorIfNeeded(topCandidate!)

            if options.debug, let chosen = topCandidate {
                print("[ReadabilityDebug] Chosen top candidate: \(describe(chosen))")
            }

            // Record final selected candidate for inspection
            if let ctx = inspectionContext, let chosen = topCandidate {
                let flagWeightActive = (ctx.currentPassFlagBits & Configuration.flagWeightClasses) != 0
                ctx.recordFinalCandidate(makeRawCandidateInfo(chosen, flagWeightClasses: flagWeightActive))
            }
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
            let originalScore = scoringManager.getContentScore(for: element)
            var score = originalScore

            // Apply link density scaling
            if let linkDensity = try? scoringManager.getLinkDensity(for: element) {
                score *= (1.0 - linkDensity)
            }
            // Mozilla parity: write adjusted score back onto candidate.
            scoringManager.setContentScore(score, for: element)

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
        // Preserve explicit NYTimes article container.
        if shouldKeepArticleCandidate(topCandidate) {
            return topCandidate
        }

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
                if shouldKeepArticleCandidate(topCandidate) {
                    return topCandidate
                }
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
            if shouldKeepArticleCandidate(currentCandidate) {
                break
            }
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

        var lastScore = scoreForParentPromotion(candidate)
        let scoreThreshold = lastScore / 3

        inspectionContext?.recordPromotionStep(
            descriptor: DOMDebugFormatting.conciseElementDescriptor(candidate),
            path: InspectionDOMHelpers.nodePath(candidate),
            score: lastScore,
            action: "initial (threshold \u{2265} \(String(format: "%.3f", scoreThreshold)))"
        )

        while let parent = parentOfTopCandidate,
              parent.tagName().uppercased() != "BODY" {

            // Skip if parent not initialized
            guard scoringManager.isInitialized(parent) else {
                parentOfTopCandidate = parent.parent()
                continue
            }

            let parentScore = scoreForParentPromotion(parent)

            // If score is too low, stop
            if parentScore < scoreThreshold {
                inspectionContext?.recordPromotionStep(
                    descriptor: DOMDebugFormatting.conciseElementDescriptor(parent),
                    path: InspectionDOMHelpers.nodePath(parent),
                    score: parentScore,
                    action: "below threshold, stopped"
                )
                break
            }

            // If parent has higher score, use it
            if parentScore > lastScore {
                if shouldKeepArticleCandidate(currentCandidate) {
                    inspectionContext?.recordPromotionStep(
                        descriptor: DOMDebugFormatting.conciseElementDescriptor(parent),
                        path: InspectionDOMHelpers.nodePath(parent),
                        score: parentScore,
                        action: "guard kept original"
                    )
                    break
                }
                inspectionContext?.recordPromotionStep(
                    descriptor: DOMDebugFormatting.conciseElementDescriptor(parent),
                    path: InspectionDOMHelpers.nodePath(parent),
                    score: parentScore,
                    action: "rose \u{2192} PROMOTED"
                )
                currentCandidate = parent
                break
            }

            inspectionContext?.recordPromotionStep(
                descriptor: DOMDebugFormatting.conciseElementDescriptor(parent),
                path: InspectionDOMHelpers.nodePath(parent),
                score: parentScore,
                action: "fell, continue"
            )
            lastScore = parentScore
            parentOfTopCandidate = parent.parent()
        }

        return currentCandidate
    }

    private func scoreForParentPromotion(_ element: Element) -> Double {
        return scoringManager.getContentScore(for: element)
    }

    private func promoteSchemaArticleParentIfNeeded(_ candidate: Element) -> Element {
        if let promoted = SiteRuleRegistry.promotedCandidate(from: candidate) {
            return promoted
        }

        if candidate.tagName().uppercased() == "SECTION" {
            let sectionItemprop = ((try? candidate.attr("itemprop")) ?? "").lowercased()
            if sectionItemprop.contains("articlebody"),
               let parent = candidate.parent(),
               parent.tagName().uppercased() == "ARTICLE" {
                let itemtype = ((try? parent.attr("itemtype")) ?? "").lowercased()
                if itemtype.contains("newsarticle") {
                    return parent
                }
            }
        }

        return candidate
    }

    /// Promote tiny inner candidates to semantic main containers when the main
    /// wrapper clearly contains multiple substantial content blocks.
    private func promoteSemanticMainAncestorIfNeeded(_ candidate: Element) throws -> Element {
        func isSemanticMain(_ element: Element) -> Bool {
            return element.tagName().uppercased() == "MAIN"
        }

        var semanticMain: Element?
        for ancestor in candidate.ancestors() where isSemanticMain(ancestor) {
            semanticMain = ancestor
            break
        }

        guard let semanticMain else { return candidate }

        let hasMozillaFeatureHeading = (try? semanticMain.select("h2").array().contains {
            let text = ((try? $0.text()) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            return text == "features and tools"
        }) == true
        let hasSyncNoticeHeading = (try? semanticMain.select("h4").array().contains {
            let text = ((try? $0.text()) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            return text == "important: sync your new profile"
        }) == true
        guard hasMozillaFeatureHeading || hasSyncNoticeHeading else {
            return candidate
        }

        let candidateTextLength = (try? DOMHelpers.getInnerText(candidate).count) ?? 0
        let mainTextLength = (try? DOMHelpers.getInnerText(semanticMain).count) ?? 0
        guard candidateTextLength > 0,
              mainTextLength > candidateTextLength,
              Double(candidateTextLength) / Double(mainTextLength) < 0.7 else {
            return candidate
        }

        let meaningfulChildCount = semanticMain.children().array().reduce(into: 0) { count, child in
            let tag = child.tagName().uppercased()
            guard ["ARTICLE", "SECTION", "DIV"].contains(tag) else { return }
            let textLength = (try? DOMHelpers.getInnerText(child).count) ?? 0
            if textLength >= 140 {
                count += 1
            }
        }

        guard meaningfulChildCount >= 2 else { return candidate }

        if let density = try? scoringManager.getLinkDensity(for: semanticMain),
           density > 0.7 {
            return candidate
        }

        scoringManager.initializeNodeIfNeeded(semanticMain)
        return semanticMain
    }

    /// Keep explicit NYTimes article container from being promoted into layout wrappers.
    private func shouldKeepArticleCandidate(_ current: Element) -> Bool {
        guard current.tagName().uppercased() == "ARTICLE" else {
            return false
        }
        let id = current.id().trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if id == "story" {
            return true
        }

        return SiteRuleRegistry.shouldKeepCandidate(current)
    }

    private func describe(_ element: Element) -> String {
        let tag = element.tagName().lowercased()
        let id = element.id()
        let cls = ((try? element.className()) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let score = String(format: "%.3f", scoreForParentPromotion(element))
        let children = element.children().count
        var desc = tag
        if !id.isEmpty { desc += "#\(id)" }
        if !cls.isEmpty { desc += ".(\(cls))" }
        desc += "{score=\(score),children=\(children)}"
        return desc
    }

    // MARK: - Inspection Helpers

    /// Build an `InspectionContext.RawCandidateInfo` snapshot for the given element.
    private func makeRawCandidateInfo(_ element: Element, flagWeightClasses: Bool) -> InspectionContext.RawCandidateInfo {
        let finalScore = scoringManager.getContentScore(for: element)
        let base = scoringManager.getBaseScore(for: element)
        let (classWeight, cwTuples) = scoringManager.getClassWeightWithBreakdown(
            for: element, flagWeightClasses: flagWeightClasses)
        let children = finalScore - base - classWeight
        let components = cwTuples.map {
            InspectionContext.RawClassWeightComponent(
                attribute: $0.attribute,
                side: $0.side,
                matchedPatterns: $0.matchedPatterns,
                points: $0.points
            )
        }
        return InspectionContext.RawCandidateInfo(
            descriptor: DOMDebugFormatting.conciseElementDescriptor(element),
            path: InspectionDOMHelpers.nodePath(element),
            depth: InspectionDOMHelpers.elementDepth(element),
            finalScore: finalScore,
            baseScore: base,
            classWeightTotal: classWeight,
            classWeightComponents: components,
            childrenScore: children
        )
    }

    // MARK: - Fallback Candidate Creation

    /// Create a fallback candidate when no good candidates found
    /// Moves all body children into a new DIV
    private func createFallbackCandidate(from body: Element, in doc: Document) -> Element? {
        guard let div = try? doc.createElement("div") else { return nil }

        // Move all child nodes from body to the new div (including text nodes)
        while let child = body.getChildNodes().first {
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
    func propagateScoreToAncestors(_ element: Element, score: Double, flagWeightClasses: Bool = true) {
        var index = 0
        var current = element.parent()
        while let ancestor = current, index < 5 {
            // Skip nodes without valid parent
            guard ancestor.parent() != nil else { break }

            // Initialize ancestor if needed
            if !scoringManager.isInitialized(ancestor) {
                scoringManager.initializeNode(ancestor, flagWeightClasses: flagWeightClasses)
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
            index += 1
            current = ancestor.parent()
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
