import Testing
import SwiftSoup
@testable import Readability

/// Tests for CandidateSelector functionality
/// These tests verify Top N candidate selection logic
@Suite("Candidate Selector Tests")
struct CandidateSelectorTests {

    // MARK: - selectTopCandidate Tests

    @Test("selectTopCandidate selects highest scored element")
    func testSelectHighestScored() throws {
        let html = """
        <div>
            <p id="low">Short text</p>
            <article id="high">This is a much longer article with more content and commas, and more words here</article>
        </div>
        """
        let doc = try SwiftSoup.parseBodyFragment(html)
        let elements = try doc.body()?.select("p, article").array() ?? []

        let scoringManager = NodeScoringManager()
        let options = ReadabilityOptions(nbTopCandidates: 5)
        let selector = CandidateSelector(options: options, scoringManager: scoringManager)

        // Score elements
        for element in elements {
            _ = try scoringManager.scoreElement(element, options: options)
        }

        let (candidate, neededToCreate) = try selector.selectTopCandidate(from: elements, in: doc)

        #expect(candidate.id() == "high")
        #expect(neededToCreate == false)
    }

    @Test("selectTopCandidate creates fallback when no good candidates")
    func testCreateFallback() throws {
        let html = "<body><p>Short</p></body>"
        let doc = try SwiftSoup.parseBodyFragment(html)
        let body = doc.body()!

        // Only short elements that won't score
        let elements = try body.select("p").array()

        let scoringManager = NodeScoringManager()
        let options = ReadabilityOptions(nbTopCandidates: 5)
        let selector = CandidateSelector(options: options, scoringManager: scoringManager)

        // Score elements (they'll all return 0 due to short text)
        for element in elements {
            _ = try scoringManager.scoreElement(element, options: options)
        }

        let (candidate, neededToCreate) = try selector.selectTopCandidate(from: elements, in: doc)

        #expect(neededToCreate == true)
        #expect(candidate.tagName().lowercased() == "div")
    }

    @Test("selectTopCandidate handles body as candidate")
    func testHandleBodyAsCandidate() throws {
        let html = "<body><div>This is long enough content with commas, and words to be scored properly</div></body>"
        let doc = try SwiftSoup.parseBodyFragment(html)
        let body = doc.body()!

        let elements = [body]

        let scoringManager = NodeScoringManager()
        let options = ReadabilityOptions(nbTopCandidates: 5)
        let selector = CandidateSelector(options: options, scoringManager: scoringManager)

        // Initialize and score body
        scoringManager.initializeNode(body)
        scoringManager.addToScore(100, for: body)

        let (_, neededToCreate) = try selector.selectTopCandidate(from: elements, in: doc)

        // Should create fallback since BODY isn't a good candidate
        #expect(neededToCreate == true)
    }

    // MARK: - Alternative Ancestor Analysis Tests

    @Test("findBetterTopCandidate finds common ancestor")
    func testFindCommonAncestor() throws {
        // Use parse instead of parseBodyFragment to have more control
        // Need at least 4 sections: 1 best + 3 alternatives (MINIMUM_TOPCANDIDATES = 3)
        let html = """
        <html><body>
        <div id="common">
            <section id="sec1"><p>Content one with enough text, and commas, and words</p></section>
            <section id="sec2"><p>Content two with enough text, and commas, and words</p></section>
            <section id="sec3"><p>Content three with enough text, and commas, and words</p></section>
            <section id="sec4"><p>Content four with enough text, and commas, and words</p></section>
        </div>
        </body></html>
        """
        let doc = try SwiftSoup.parse(html)
        let body = doc.body()!

        let sections = try body.select("section").array()
        #expect(sections.count == 4)

        let scoringManager = NodeScoringManager()
        let options = ReadabilityOptions(nbTopCandidates: 5)
        let selector = CandidateSelector(options: options, scoringManager: scoringManager)

        // Score sections with high scores (all above 75% of best)
        for (index, section) in sections.enumerated() {
            scoringManager.initializeNode(section)
            scoringManager.addToScore(Double(100 - index * 5), for: section)  // 100, 95, 90, 85
        }

        let topCandidates = TopCandidates(maxCount: 5)
        for section in sections {
            topCandidates.add(Candidate(element: section, score: scoringManager.getContentScore(for: section)))
        }

        // Verify we have 4 candidates with scores above threshold
        #expect(topCandidates.count == 4)

        let first = sections[0]
        let better = try selector.findBetterTopCandidate(from: first, topCandidates: topCandidates)

        // Should find the common ancestor div (sec1 -> div#common)
        // div#common should be in the ancestor lists of sec2, sec3, and sec4
        #expect(better.id() == "common")
    }

    @Test("findBetterTopCandidate keeps original when no common ancestor")
    func testKeepOriginalWhenNoCommonAncestor() throws {
        let html = """
        <div>
            <section id="sec1"><p>Content one with enough text, and commas</p></section>
        </div>
        <div>
            <section id="sec2"><p>Content two with enough text, and commas</p></section>
        </div>
        """
        let doc = try SwiftSoup.parseBodyFragment(html)
        let body = doc.body()!

        let sections = try body.select("section").array()

        let scoringManager = NodeScoringManager()
        let options = ReadabilityOptions(nbTopCandidates: 5)
        let selector = CandidateSelector(options: options, scoringManager: scoringManager)

        // Score sections
        for section in sections {
            scoringManager.initializeNode(section)
            scoringManager.addToScore(100, for: section)
        }

        let topCandidates = TopCandidates(maxCount: 5)
        for section in sections {
            topCandidates.add(Candidate(element: section, score: scoringManager.getContentScore(for: section)))
        }

        let first = sections[0]
        let better = try selector.findBetterTopCandidate(from: first, topCandidates: topCandidates)

        // Should keep original since no common ancestor found with 3+ candidates
        #expect(better.id() == "sec1")
    }

    // MARK: - Single Child Promotion Tests

    @Test("promoteSingleChildCandidate promotes single children")
    func testPromoteSingleChild() throws {
        let html = """
        <div id="grandparent">
            <div id="parent">
                <div id="child">Content here with enough text for scoring purposes</div>
            </div>
        </div>
        """
        let doc = try SwiftSoup.parseBodyFragment(html)
        let child = try doc.select("#child").first()!

        let scoringManager = NodeScoringManager()
        let options = ReadabilityOptions()
        let selector = CandidateSelector(options: options, scoringManager: scoringManager)

        scoringManager.initializeNode(child)

        let promoted = try selector.promoteSingleChildCandidate(child)

        // Should promote to grandparent since all are single children
        #expect(promoted.id() == "grandparent")
    }

    @Test("promoteSingleChildCandidate stops at body")
    func testPromoteStopsAtBody() throws {
        let html = "<div id='parent'><div id='child'>Content with enough text for scoring</div></div>"
        let doc = try SwiftSoup.parseBodyFragment(html)
        let child = try doc.select("#child").first()!

        let scoringManager = NodeScoringManager()
        let options = ReadabilityOptions()
        let selector = CandidateSelector(options: options, scoringManager: scoringManager)

        scoringManager.initializeNode(child)

        let promoted = try selector.promoteSingleChildCandidate(child)

        // Should stop at body level
        #expect(promoted.id() == "parent")
    }

    // MARK: - Parent Score Traversal Tests

    @Test("findBetterParentCandidate finds parent with higher score")
    func testFindParentWithHigherScore() throws {
        let html = """
        <div id="parent">
            <div id="child">Content with enough text for scoring purposes</div>
        </div>
        """
        let doc = try SwiftSoup.parseBodyFragment(html)
        let parent = try doc.select("#parent").first()!
        let child = try doc.select("#child").first()!

        let scoringManager = NodeScoringManager()
        let options = ReadabilityOptions()
        let selector = CandidateSelector(options: options, scoringManager: scoringManager)

        // Parent has higher score
        scoringManager.initializeNode(parent)
        scoringManager.addToScore(100, for: parent)

        scoringManager.initializeNode(child)
        scoringManager.addToScore(50, for: child)

        let better = selector.findBetterParentCandidate(child)

        #expect(better.id() == "parent")
    }

    @Test("findBetterParentCandidate respects threshold")
    func testParentRespectsThreshold() throws {
        let html = """
        <div id="parent">
            <div id="child">Content with enough text for scoring purposes</div>
        </div>
        """
        let doc = try SwiftSoup.parseBodyFragment(html)
        let parent = try doc.select("#parent").first()!
        let child = try doc.select("#child").first()!

        let scoringManager = NodeScoringManager()
        let options = ReadabilityOptions()
        let selector = CandidateSelector(options: options, scoringManager: scoringManager)

        // Parent score is too low (below 1/3 of child score)
        scoringManager.initializeNode(parent)
        scoringManager.addToScore(10, for: parent) // Below 100/3

        scoringManager.initializeNode(child)
        scoringManager.addToScore(100, for: child)

        let better = selector.findBetterParentCandidate(child)

        // Should keep child since parent score is below threshold
        #expect(better.id() == "child")
    }

    // MARK: - Sibling Score Threshold Tests

    @Test("calculateSiblingScoreThreshold uses minimum")
    func testSiblingThresholdMinimum() throws {
        let html = "<div id='candidate'>Content</div>"
        let doc = try SwiftSoup.parseBodyFragment(html)
        let candidate = try doc.select("#candidate").first()!

        let scoringManager = NodeScoringManager()
        let options = ReadabilityOptions()
        let selector = CandidateSelector(options: options, scoringManager: scoringManager)

        // Low score
        scoringManager.initializeNode(candidate)
        scoringManager.addToScore(5, for: candidate)

        let threshold = selector.calculateSiblingScoreThreshold(for: candidate)

        // Should use minimum of 10
        #expect(threshold == 10)
    }

    @Test("calculateSiblingScoreThreshold uses ratio for high scores")
    func testSiblingThresholdRatio() throws {
        let html = "<div id='candidate'>Content</div>"
        let doc = try SwiftSoup.parseBodyFragment(html)
        let candidate = try doc.select("#candidate").first()!

        let scoringManager = NodeScoringManager()
        let options = ReadabilityOptions()
        let selector = CandidateSelector(options: options, scoringManager: scoringManager)

        // High score
        scoringManager.initializeNode(candidate)
        scoringManager.addToScore(100, for: candidate)

        let threshold = selector.calculateSiblingScoreThreshold(for: candidate)

        // Should use 20% of 105 = 21 (including DIV base score of 5)
        #expect(threshold == 21)
    }

    // MARK: - Ancestor Score Propagation Tests

    @Test("propagateScoreToAncestors adds scores at different levels")
    func testPropagateScores() throws {
        let html = """
        <div id="grandparent">
            <div id="parent">
                <p id="child">Content with enough text for scoring</p>
            </div>
        </div>
        """
        let doc = try SwiftSoup.parseBodyFragment(html)
        let child = try doc.select("#child").first()!

        let scoringManager = NodeScoringManager()
        let options = ReadabilityOptions()
        let selector = CandidateSelector(options: options, scoringManager: scoringManager)

        scoringManager.initializeNode(child)
        selector.propagateScoreToAncestors(child, score: 60)

        let parent = try doc.select("#parent").first()!
        let grandparent = try doc.select("#grandparent").first()!

        // Parent (level 0): 60/1 + 5 (DIV base) = 65
        #expect(scoringManager.getContentScore(for: parent) == 65)

        // Grandparent (level 1): 60/2 + 5 (DIV base) = 35
        #expect(scoringManager.getContentScore(for: grandparent) == 35)
    }

    @Test("propagateScoreToAncestors initializes ancestors")
    func testPropagateInitializesAncestors() throws {
        let html = "<div><p>Content with enough text for scoring</p></div>"
        let doc = try SwiftSoup.parseBodyFragment(html)
        let p = try doc.select("p").first()!
        let div = try doc.select("div").first()!

        let scoringManager = NodeScoringManager()
        let options = ReadabilityOptions()
        let selector = CandidateSelector(options: options, scoringManager: scoringManager)

        // Div not initialized yet
        #expect(scoringManager.isInitialized(div) == false)

        scoringManager.initializeNode(p)
        selector.propagateScoreToAncestors(p, score: 10)

        // Div should now be initialized
        #expect(scoringManager.isInitialized(div) == true)
    }

    // MARK: - Edge Cases

    @Test("selectTopCandidate handles empty elements array")
    func testSelectFromEmptyArray() throws {
        let html = "<body></body>"
        let doc = try SwiftSoup.parseBodyFragment(html)

        let scoringManager = NodeScoringManager()
        let options = ReadabilityOptions()
        let selector = CandidateSelector(options: options, scoringManager: scoringManager)

        let (_, neededToCreate) = try selector.selectTopCandidate(from: [], in: doc)

        // Should create fallback
        #expect(neededToCreate == true)
    }

    @Test("findBetterTopCandidate handles insufficient alternatives")
    func testInsufficientAlternatives() throws {
        let html = """
        <div>
            <section id="sec1"><p>Content one</p></section>
            <section id="sec2"><p>Content two</p></section>
        </div>
        """
        let doc = try SwiftSoup.parseBodyFragment(html)
        let sections = try doc.select("section").array()

        let scoringManager = NodeScoringManager()
        let options = ReadabilityOptions()
        let selector = CandidateSelector(options: options, scoringManager: scoringManager)

        let topCandidates = TopCandidates(maxCount: 5)
        for section in sections {
            scoringManager.initializeNode(section)
            scoringManager.addToScore(100, for: section)
            topCandidates.add(Candidate(element: section, score: 100))
        }

        let first = sections[0]
        let better = try selector.findBetterTopCandidate(from: first, topCandidates: topCandidates)

        // Only 2 alternatives, need 3 minimum
        #expect(better.id() == "sec1")
    }

    @Test("propagateScoreToAncestors respects maxDepth")
    func testPropagateRespectsMaxDepth() throws {
        let html = """
        <div id="level3">
            <div id="level2">
                <div id="level1">
                    <div id="level0">
                        <p id="child">Content</p>
                    </div>
                </div>
            </div>
        </div>
        """
        let doc = try SwiftSoup.parseBodyFragment(html)
        let child = try doc.select("#child").first()!

        let scoringManager = NodeScoringManager()
        let options = ReadabilityOptions()
        let selector = CandidateSelector(options: options, scoringManager: scoringManager)

        scoringManager.initializeNode(child)
        selector.propagateScoreToAncestors(child, score: 60)

        // Level 0 (parent): 60/1 + 5 = 65
        let level0 = try doc.select("#level0").first()!
        #expect(scoringManager.getContentScore(for: level0) == 65)

        // Level 1 (grandparent): 60/2 + 5 = 35
        let level1 = try doc.select("#level1").first()!
        #expect(scoringManager.getContentScore(for: level1) == 35)

        // Level 2: 60/(2*3) + 5 = 15
        let level2 = try doc.select("#level2").first()!
        #expect(scoringManager.getContentScore(for: level2) == 15)

        // Level 3: 60/(3*3) + 5 = 11.67
        let level3 = try doc.select("#level3").first()!
        let level3Score = scoringManager.getContentScore(for: level3)
        #expect(level3Score > 11 && level3Score < 12)
    }
}
