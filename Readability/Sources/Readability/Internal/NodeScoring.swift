import Foundation
import SwiftSoup

/// Score data associated with a DOM node
struct NodeScore: Equatable {
    var contentScore: Double = 0
    var initialized: Bool = false

    init(contentScore: Double = 0, initialized: Bool = false) {
        self.contentScore = contentScore
        self.initialized = initialized
    }
}

/// Manages content scores for DOM elements
/// Uses ObjectIdentifier to associate scores with Element instances
final class NodeScoringManager {
    private var scores: [ObjectIdentifier: NodeScore] = [:]

    /// Get score for an element
    /// - Parameter element: Element to get score for
    /// - Returns: NodeScore, or nil if not initialized
    func getScore(for element: Element) -> NodeScore? {
        let key = ObjectIdentifier(element)
        return scores[key]
    }

    /// Get content score value (returns 0 if not initialized)
    /// - Parameter element: Element to get score for
    /// - Returns: Content score value
    func getContentScore(for element: Element) -> Double {
        return getScore(for: element)?.contentScore ?? 0
    }

    /// Check if element has been initialized
    /// - Parameter element: Element to check
    /// - Returns: True if element has been initialized
    func isInitialized(_ element: Element) -> Bool {
        return getScore(for: element)?.initialized ?? false
    }

    /// Set score for an element
    /// - Parameters:
    ///   - score: Score to set
    ///   - element: Element to associate score with
    func setScore(_ score: NodeScore, for element: Element) {
        let key = ObjectIdentifier(element)
        scores[key] = score
    }

    /// Initialize a node with base score based on its tag name
    /// Mirrors Mozilla's _initializeNode function
    /// - Parameter element: Element to initialize
    /// - Returns: The initialized NodeScore
    @discardableResult
    func initializeNode(_ element: Element) -> NodeScore {
        var score = NodeScore(contentScore: 0, initialized: true)
        let tagName = element.tagName().uppercased()

        switch tagName {
        case "DIV":
            score.contentScore += Configuration.baseScoreDiv
        case "PRE", "TD", "BLOCKQUOTE":
            score.contentScore += Configuration.baseScorePre
        case "ADDRESS", "OL", "UL", "DL", "DD", "DT", "LI", "FORM":
            score.contentScore -= 3
        case "H1", "H2", "H3", "H4", "H5", "H6", "TH":
            score.contentScore -= 5
        default:
            break
        }

        score.contentScore += getClassWeight(for: element)
        setScore(score, for: element)
        return score
    }

    /// Initialize node if not already initialized
    /// - Parameter element: Element to initialize
    /// - Returns: The NodeScore (existing or new)
    @discardableResult
    func initializeNodeIfNeeded(_ element: Element) -> NodeScore {
        if let existing = getScore(for: element), existing.initialized {
            return existing
        }
        return initializeNode(element)
    }

    /// Add to content score
    /// - Parameters:
    ///   - value: Value to add
    ///   - element: Element to update
    func addToScore(_ value: Double, for element: Element) {
        var score = getScore(for: element) ?? NodeScore()
        score.contentScore += value
        score.initialized = true
        setScore(score, for: element)
    }

    /// Replace content score while preserving initialization marker.
    /// Mirrors Mozilla behavior where candidate score is overwritten
    /// after link-density scaling.
    func setContentScore(_ value: Double, for element: Element) {
        var score = getScore(for: element) ?? NodeScore()
        score.contentScore = value
        score.initialized = true
        setScore(score, for: element)
    }

    /// Multiply content score by a factor
    /// - Parameters:
    ///   - factor: Factor to multiply by
    ///   - element: Element to update
    func multiplyScore(by factor: Double, for element: Element) {
        var score = getScore(for: element) ?? NodeScore()
        score.contentScore *= factor
        setScore(score, for: element)
    }

    /// Clear all scores
    func clear() {
        scores.removeAll()
    }

    /// Remove score for a specific element
    /// - Parameter element: Element to remove score for
    func removeScore(for element: Element) {
        let key = ObjectIdentifier(element)
        scores.removeValue(forKey: key)
    }
}

// MARK: - Scoring Extensions

extension NodeScoringManager {

    /// Calculate link density for an element
    /// Link density = length of link text / total text length
    /// Hash URLs (#) get a 0.3 coefficient
    /// - Parameter element: Element to calculate for
    /// - Returns: Link density (0.0 to 1.0+)
    func getLinkDensity(for element: Element) throws -> Double {
        let textLength = try DOMHelpers.getInnerText(element).count
        if textLength == 0 {
            return 0
        }

        let links = try element.select("a")
        var linkLength = 0

        for link in links {
            let href = (try? link.attr("href")) ?? ""
            let coefficient = href.hasPrefix("#") ? 0.3 : 1.0
            let linkTextLength = try DOMHelpers.getInnerText(link).count
            linkLength += Int(Double(linkTextLength) * coefficient)
        }

        return Double(linkLength) / Double(textLength)
    }

    /// Get class/id weight for an element
    /// Uses positive/negative patterns from Configuration
    /// - Parameters:
    ///   - element: Element to get weight for
    ///   - flagWeightClasses: Whether to apply class weighting (FLAG_WEIGHT_CLASSES)
    /// - Returns: Weight value
    func getClassWeight(for element: Element, flagWeightClasses: Bool = true) -> Double {
        guard flagWeightClasses else { return 0 }

        var weight: Double = 0

        // Check class name
        if let className = try? element.className(), !className.isEmpty {
            if Configuration.negativePatterns.contains(where: { className.lowercased().contains($0) }) {
                weight -= Configuration.classWeightPositive
            }
            if Configuration.positivePatterns.contains(where: { className.lowercased().contains($0) }) {
                weight += Configuration.classWeightPositive
            }
        }

        // Check id
        let id = element.id()
        if !id.isEmpty {
            if Configuration.negativePatterns.contains(where: { id.lowercased().contains($0) }) {
                weight -= Configuration.classWeightPositive
            }
            if Configuration.positivePatterns.contains(where: { id.lowercased().contains($0) }) {
                weight += Configuration.classWeightPositive
            }
        }

        return weight
    }

    /// Score an element for content extraction
    /// This is the main scoring logic used during grabArticle
    /// - Parameters:
    ///   - element: Element to score
    ///   - options: Readability options
    /// - Returns: Calculated score, or 0 if element should be skipped
    func scoreElement(_ element: Element, options: ReadabilityOptions) throws -> Double {
        let text = try element.text()
        let textLength = text.count

        // Skip elements with too little text
        if textLength < 25 {
            return 0
        }

        // Skip hidden elements
        if !DOMHelpers.isProbablyVisible(element) {
            return 0
        }

        // Initialize node if needed
        var score = initializeNodeIfNeeded(element)

        // Add points for any commas within this paragraph
        let commaCount = text.filter { $0 == "," }.count
        score.contentScore += Double(commaCount)

        // For every 100 characters in this paragraph, add another point. Up to 3 points.
        let lengthScore = min(Double(textLength) / 100.0, 3.0)
        score.contentScore += lengthScore

        // Add class/id weight
        score.contentScore += getClassWeight(for: element, flagWeightClasses: true)

        // Scale the final candidates score based on link density
        let linkDensity = try getLinkDensity(for: element)
        score.contentScore *= (1.0 - linkDensity + options.linkDensityModifier)

        setScore(score, for: element)
        return score.contentScore
    }
}

// MARK: - Candidate Structure

/// A candidate element with its associated score
struct Candidate {
    let element: Element
    let score: Double

    init(element: Element, score: Double) {
        self.element = element
        self.score = score
    }
}

// MARK: - Top Candidates Collection

/// Manages the top N candidates sorted by score
final class TopCandidates {
    private var candidates: [Candidate] = []
    private let maxCount: Int

    init(maxCount: Int) {
        self.maxCount = maxCount
    }

    /// Add a candidate to the collection
    /// Maintains sorted order by score (highest first)
    /// - Parameter candidate: Candidate to add
    func add(_ candidate: Candidate) {
        // Find insertion point
        var inserted = false
        for i in 0..<candidates.count {
            if candidate.score > candidates[i].score {
                candidates.insert(candidate, at: i)
                inserted = true
                break
            }
        }

        // If not inserted and we have room, append
        if !inserted && candidates.count < maxCount {
            candidates.append(candidate)
        }

        // Trim to max count
        if candidates.count > maxCount {
            candidates.removeLast(candidates.count - maxCount)
        }
    }

    /// Get all candidates
    var all: [Candidate] { candidates }

    /// Get the best candidate (highest score)
    var best: Candidate? { candidates.first }

    /// Get candidate at index
    subscript(index: Int) -> Candidate? {
        guard index >= 0 && index < candidates.count else { return nil }
        return candidates[index]
    }

    /// Number of candidates
    var count: Int { candidates.count }

    /// Check if empty
    var isEmpty: Bool { candidates.isEmpty }

    /// Clear all candidates
    func clear() {
        candidates.removeAll()
    }
}
