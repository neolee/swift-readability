import Foundation
import SwiftSoup

/// Internal mutable accumulator for per-pass extraction diagnostics.
/// Incrementally populated as extraction proceeds; converted to `InspectionReport` on completion.
final class InspectionContext {

    // MARK: - Internal Raw Data Structures

    struct RawClassWeightComponent {
        let attribute: String
        let side: String
        let matchedPatterns: [String]
        let points: Double
    }

    struct RawCandidateInfo {
        let descriptor: String
        let path: String
        let depth: Int
        let finalScore: Double
        let baseScore: Double
        let classWeightTotal: Double
        let classWeightComponents: [RawClassWeightComponent]
        let childrenScore: Double
    }

    struct RawPromotionStep {
        let descriptor: String
        let path: String
        let score: Double
        let action: String
    }

    struct RawCandidateContext {
        let candidateDescriptor: String
        let candidatePath: String
        let parentDescriptor: String?
        let parentPath: String?
        let ancestorChain: [String]
        let siblingDescriptors: [String]
    }

    struct RawSiblingDecision {
        let descriptor: String
        let path: String
        let tagName: String
        let className: String
        let score: Double
        let bonus: Double
        let threshold: Double
        let visible: Bool
        let decision: String
        let reason: String
        let siteRuleDecisionID: String?
    }

    struct RawSiteRuleDecision {
        let phase: String
        let ruleID: String
        let targetDescriptor: String
        let targetPath: String
        let action: String
        let resultDescriptor: String?
        let resultPath: String?
        let reason: String
    }

    struct RawContentSnapshot {
        let selectedCandidateDescriptor: String
        let selectedCandidatePath: String
        let articleChildDescriptors: [String]
        let leadingBlockDescriptors: [String]
        let contentLength: Int
    }

    struct RawPass {
        var passNumber: Int
        var flagBits: UInt32
        var topCandidates: [RawCandidateInfo] = []
        var initialWinner: RawCandidateInfo?
        var promotionTrace: [RawPromotionStep] = []
        var finalCandidate: RawCandidateInfo?
        var candidateContext: RawCandidateContext?
        var siblingDecisions: [RawSiblingDecision] = []
        var siteRuleDecisions: [RawSiteRuleDecision] = []
        var contentSnapshot: RawContentSnapshot?
        var contentLength: Int = 0
        var accepted: Bool = false
    }

    // MARK: - State

    private var passes: [RawPass] = []
    private var currentPass: RawPass?

    /// Flag bits of the currently active pass (used by CandidateSelector to branch on flag state).
    var currentPassFlagBits: UInt32 { currentPass?.flagBits ?? 0 }

    // MARK: - Pass Lifecycle

    func beginPass(number: Int, flagBits: UInt32) {
        currentPass = RawPass(passNumber: number, flagBits: flagBits)
    }

    func recordTopCandidates(_ candidates: [RawCandidateInfo]) {
        currentPass?.topCandidates = candidates
    }

    func recordInitialWinner(_ info: RawCandidateInfo?) {
        currentPass?.initialWinner = info
    }

    func recordPromotionStep(descriptor: String, path: String, score: Double, action: String) {
        currentPass?.promotionTrace.append(
            RawPromotionStep(descriptor: descriptor, path: path, score: score, action: action)
        )
    }

    func recordFinalCandidate(_ info: RawCandidateInfo?) {
        currentPass?.finalCandidate = info
    }

    func recordCandidateContext(candidate: Element) {
        let parent = candidate.parent()
        currentPass?.candidateContext = RawCandidateContext(
            candidateDescriptor: DOMDebugFormatting.conciseElementDescriptor(candidate),
            candidatePath: InspectionDOMHelpers.nodePath(candidate),
            parentDescriptor: parent.map(DOMDebugFormatting.conciseElementDescriptor),
            parentPath: parent.map(InspectionDOMHelpers.nodePath),
            ancestorChain: candidate.ancestors().map {
                "\(DOMDebugFormatting.conciseElementDescriptor($0)) @ \(InspectionDOMHelpers.nodePath($0))"
            },
            siblingDescriptors: parent.map {
                $0.children().map {
                    "\(DOMDebugFormatting.conciseElementDescriptor($0)) @ \(InspectionDOMHelpers.nodePath($0))"
                }
            } ?? []
        )
    }

    func recordSiblingDecision(
        sibling: Element,
        score: Double,
        bonus: Double,
        threshold: Double,
        visible: Bool,
        decision: String,
        reason: String,
        siteRuleDecisionID: String? = nil
    ) {
        currentPass?.siblingDecisions.append(
            RawSiblingDecision(
                descriptor: DOMDebugFormatting.conciseElementDescriptor(sibling),
                path: InspectionDOMHelpers.nodePath(sibling),
                tagName: sibling.tagName().lowercased(),
                className: ((try? sibling.className()) ?? ""),
                score: score,
                bonus: bonus,
                threshold: threshold,
                visible: visible,
                decision: decision,
                reason: reason,
                siteRuleDecisionID: siteRuleDecisionID
            )
        )
    }

    func recordSiteRuleDecision(
        phase: String,
        ruleID: String,
        target: Element,
        action: String,
        result: Element? = nil,
        reason: String
    ) {
        currentPass?.siteRuleDecisions.append(
            RawSiteRuleDecision(
                phase: phase,
                ruleID: ruleID,
                targetDescriptor: DOMDebugFormatting.conciseElementDescriptor(target),
                targetPath: InspectionDOMHelpers.nodePath(target),
                action: action,
                resultDescriptor: result.map(DOMDebugFormatting.conciseElementDescriptor),
                resultPath: result.flatMap { $0.parent() != nil ? InspectionDOMHelpers.nodePath($0) : nil },
                reason: reason
            )
        )
    }

    func recordContentSnapshot(articleContent: Element, selectedCandidate: Element, contentLength: Int) {
        let articleChildren = articleContent.children().map(DOMDebugFormatting.conciseElementDescriptor)
        let leadingSource: Elements
        if articleContent.children().count == 1,
           let onlyChild = articleContent.children().first,
           onlyChild.tagName().uppercased() == "DIV" {
            leadingSource = onlyChild.children()
        } else {
            leadingSource = articleContent.children()
        }
        currentPass?.contentSnapshot = RawContentSnapshot(
            selectedCandidateDescriptor: DOMDebugFormatting.conciseElementDescriptor(selectedCandidate),
            selectedCandidatePath: InspectionDOMHelpers.nodePath(selectedCandidate),
            articleChildDescriptors: articleChildren,
            leadingBlockDescriptors: Array(leadingSource.prefix(8)).map(DOMDebugFormatting.conciseElementDescriptor),
            contentLength: contentLength
        )
    }

    func endPass(contentLength: Int, accepted: Bool) {
        guard var pass = currentPass else { return }
        pass.contentLength = contentLength
        pass.accepted = accepted
        passes.append(pass)
        currentPass = nil
    }

    // MARK: - Report Construction

    func buildReport(charThreshold: Int) -> InspectionReport {
        InspectionReport(passes: passes.map { buildPassAttempt($0, charThreshold: charThreshold) })
    }

    private func buildPassAttempt(_ raw: RawPass, charThreshold: Int) -> InspectionReport.PassAttempt {
        InspectionReport.PassAttempt(
            passNumber: raw.passNumber,
            activeFlags: flagNames(raw.flagBits),
            topCandidates: raw.topCandidates.map(makePublicCandidateInfo),
            initialWinner: raw.initialWinner.map(makePublicCandidateInfo),
            promotionTrace: raw.promotionTrace.map {
                InspectionReport.PromotionStep(
                    descriptor: $0.descriptor, path: $0.path, score: $0.score, action: $0.action)
            },
            finalCandidate: raw.finalCandidate.map(makePublicCandidateInfo),
            candidateContext: raw.candidateContext.map {
                InspectionReport.CandidateContext(
                    candidateDescriptor: $0.candidateDescriptor,
                    candidatePath: $0.candidatePath,
                    parentDescriptor: $0.parentDescriptor,
                    parentPath: $0.parentPath,
                    ancestorChain: $0.ancestorChain,
                    siblingDescriptors: $0.siblingDescriptors
                )
            },
            siblingDecisions: raw.siblingDecisions.map {
                InspectionReport.SiblingDecision(
                    descriptor: $0.descriptor,
                    path: $0.path,
                    tagName: $0.tagName,
                    className: $0.className,
                    score: $0.score,
                    bonus: $0.bonus,
                    threshold: $0.threshold,
                    visible: $0.visible,
                    decision: $0.decision,
                    reason: $0.reason,
                    siteRuleDecisionID: $0.siteRuleDecisionID
                )
            },
            siteRuleDecisions: raw.siteRuleDecisions.map {
                InspectionReport.SiteRuleDecision(
                    phase: $0.phase,
                    ruleID: $0.ruleID,
                    targetDescriptor: $0.targetDescriptor,
                    targetPath: $0.targetPath,
                    action: $0.action,
                    resultDescriptor: $0.resultDescriptor,
                    resultPath: $0.resultPath,
                    reason: $0.reason
                )
            },
            contentSnapshot: raw.contentSnapshot.map {
                InspectionReport.ContentSnapshotSummary(
                    selectedCandidateDescriptor: $0.selectedCandidateDescriptor,
                    selectedCandidatePath: $0.selectedCandidatePath,
                    articleChildDescriptors: $0.articleChildDescriptors,
                    leadingBlockDescriptors: $0.leadingBlockDescriptors,
                    contentLength: $0.contentLength
                )
            },
            contentLength: raw.contentLength,
            charThreshold: charThreshold,
            accepted: raw.accepted
        )
    }

    private func makePublicCandidateInfo(_ raw: RawCandidateInfo) -> InspectionReport.CandidateInfo {
        InspectionReport.CandidateInfo(
            descriptor: raw.descriptor,
            path: raw.path,
            depth: raw.depth,
            score: raw.finalScore,
            baseScore: raw.baseScore,
            classWeightTotal: raw.classWeightTotal,
            classWeightComponents: raw.classWeightComponents.map {
                InspectionReport.ClassWeightComponent(
                    attribute: $0.attribute,
                    side: $0.side,
                    matchedPatterns: $0.matchedPatterns,
                    points: $0.points
                )
            },
            childrenScore: raw.childrenScore
        )
    }

    private func flagNames(_ bits: UInt32) -> [String] {
        var names: [String] = []
        if bits & Configuration.flagStripUnlikelies    != 0 { names.append("STRIP") }
        if bits & Configuration.flagWeightClasses      != 0 { names.append("WEIGHT") }
        if bits & Configuration.flagCleanConditionally != 0 { names.append("CLEAN") }
        return names
    }
}
