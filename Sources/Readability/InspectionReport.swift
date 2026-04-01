import Foundation

/// Detailed extraction process report returned by `Readability.parseWithInspection()`.
///
/// Shows exactly which elements were considered as candidates, their score breakdown,
/// which multi-pass attempts were made, and how the final candidate was selected
/// and/or promoted through the ancestor chain.
///
/// Use this to diagnose incorrect content extraction without inserting temporary debug code.
public struct InspectionReport: Sendable {

    // MARK: - Nested Types

    /// One group of class/id patterns that fired a weight adjustment.
    /// All matching patterns within a group collectively contribute `points` (not per-pattern).
    public struct ClassWeightComponent: Sendable {
        /// The attribute that was checked: "class" or "id".
        public let attribute: String
        /// Whether the match was positive or negative: "positive" or "negative".
        public let side: String
        /// All pattern strings from the configuration that matched within this attribute.
        public let matchedPatterns: [String]
        /// Points contributed: +25.0 (positive) or -25.0 (negative).
        public let points: Double
    }

    /// Snapshot of a scored candidate element captured during extraction.
    public struct CandidateInfo: Sendable {
        /// CSS-like descriptor, e.g. "div.entry-content" or "div#main".
        public let descriptor: String
        /// DOM path for this element.
        public let path: String
        /// DOM depth: number of ancestor elements above this node.
        public let depth: Int
        /// Final content score (after link-density scaling).
        public let score: Double
        /// Tag-based score component only (before class weight and child propagation).
        public let baseScore: Double
        /// Total class/id weight applied. Zero when WEIGHT flag was inactive.
        public let classWeightTotal: Double
        /// Matched pattern groups that make up classWeightTotal, by attribute and side.
        public let classWeightComponents: [ClassWeightComponent]
        /// Approximate score from child propagation: score - baseScore - classWeightTotal.
        public let childrenScore: Double
    }

    /// One step captured during the `findBetterParentCandidate` traversal.
    public struct PromotionStep: Sendable {
        /// CSS-like descriptor of the element checked at this step.
        public let descriptor: String
        /// DOM path for this element.
        public let path: String
        /// Content score of this element.
        public let score: Double
        /// Human-readable outcome, e.g. "initial winner", "fell, continue", "rose → PROMOTED".
        public let action: String
    }

    /// Summary of the selected candidate's immediate DOM context.
    public struct CandidateContext: Sendable {
        public let candidateDescriptor: String
        public let candidatePath: String
        public let parentDescriptor: String?
        public let parentPath: String?
        public let ancestorChain: [String]
        public let siblingDescriptors: [String]
    }

    /// One explicit sibling-merge decision recorded during content assembly.
    public struct SiblingDecision: Sendable {
        public let descriptor: String
        public let path: String
        public let tagName: String
        public let className: String
        public let score: Double
        public let bonus: Double
        public let threshold: Double
        public let visible: Bool
        public let decision: String
        public let reason: String
        public let siteRuleDecisionID: String?
    }

    /// One explicit site-rule decision recorded during extraction.
    public struct SiteRuleDecision: Sendable {
        public let phase: String
        public let ruleID: String
        public let targetDescriptor: String
        public let targetPath: String
        public let action: String
        public let resultDescriptor: String?
        public let resultPath: String?
        public let reason: String
    }

    /// Compact summary of the merged article content produced by one pass.
    public struct ContentSnapshotSummary: Sendable {
        public struct BlockSummary: Sendable {
            public let descriptor: String
            public let path: String
            public let childCount: Int
            public let textPreview: String
        }

        public let selectedCandidateDescriptor: String
        public let selectedCandidatePath: String
        public let articleChildCount: Int
        public let articleChildDescriptors: [String]
        public let usesSingleWrapper: Bool
        public let wrapperDescriptor: String?
        public let wrapperPath: String?
        public let leadingBlocks: [BlockSummary]
        public let contentLength: Int
    }

    /// Final snapshot after article cleanup and title-header removal.
    public struct FinalContentSnapshotSummary: Sendable {
        public struct BlockSummary: Sendable {
            public let descriptor: String
            public let path: String
            public let childCount: Int
            public let textPreview: String
        }

        public let contentLength: Int
        public let articleChildCount: Int
        public let articleChildDescriptors: [String]
        public let leadingBlocks: [BlockSummary]
    }

    /// Snapshot captured at a named cleanup stage.
    public struct CleanupSnapshotSummary: Sendable {
        public let stage: String
        public let contentLength: Int
        public let articleChildCount: Int
        public let articleChildDescriptors: [String]
        public let leadingBlocks: [FinalContentSnapshotSummary.BlockSummary]
    }

    /// Data captured during one complete pass of the multi-pass extraction loop.
    public struct PassAttempt: Sendable {
        /// 1-indexed pass number.
        public let passNumber: Int
        /// Flag names active during this pass, e.g. ["STRIP", "WEIGHT", "CLEAN"].
        public let activeFlags: [String]
        /// Top-N candidates sorted by final score descending.
        public let topCandidates: [CandidateInfo]
        /// The best candidate immediately after scoring, before any promotion logic runs.
        public let initialWinner: CandidateInfo?
        /// Steps taken by `findBetterParentCandidate`, including the starting element.
        public let promotionTrace: [PromotionStep]
        /// Candidate actually selected after all promotion passes completed.
        public let finalCandidate: CandidateInfo?
        /// Candidate ancestry and sibling context for the selected candidate.
        public let candidateContext: CandidateContext?
        /// Explicit sibling decisions recorded while assembling article content.
        public let siblingDecisions: [SiblingDecision]
        /// Explicit site-rule decisions recorded during extraction.
        public let siteRuleDecisions: [SiteRuleDecision]
        /// Compact content-shape summary for this pass.
        public let contentSnapshot: ContentSnapshotSummary?
        /// Character count of extracted text content for this attempt.
        public let contentLength: Int
        /// The configured `charThreshold` for comparison.
        public let charThreshold: Int
        /// Whether this pass met `charThreshold` and became the accepted final result.
        public let accepted: Bool
    }

    // MARK: - Properties

    /// One entry per pass of the extraction loop, in ascending order.
    public let passes: [PassAttempt]

    /// Final article snapshot after cleanup, before serialization.
    public let finalContentSnapshot: FinalContentSnapshotSummary?

    /// Intermediate snapshots captured during cleanup.
    public let cleanupSnapshots: [CleanupSnapshotSummary]
}
