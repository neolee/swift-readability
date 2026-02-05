import Testing
import SwiftSoup
@testable import Readability

/// Tests for NodeScoring utilities
/// These tests verify the score management functionality needed for Readability
@Suite("Node Scoring Tests")
struct NodeScoringTests {

    // MARK: - NodeScoringManager Basic Tests

    @Test("NodeScoringManager stores and retrieves scores")
    func testScoreStorage() throws {
        let manager = NodeScoringManager()
        let html = "<div>Test</div>"
        let doc = try SwiftSoup.parse(html)
        let div = try doc.select("div").first()!

        let score = NodeScore(contentScore: 10.5, initialized: true)
        manager.setScore(score, for: div)

        let retrieved = manager.getScore(for: div)

        #expect(retrieved != nil)
        #expect(retrieved?.contentScore == 10.5)
        #expect(retrieved?.initialized == true)
    }

    @Test("NodeScoringManager returns nil for unscored element")
    func testUnscoredElement() throws {
        let manager = NodeScoringManager()
        let html = "<div>Test</div>"
        let doc = try SwiftSoup.parse(html)
        let div = try doc.select("div").first()!

        let retrieved = manager.getScore(for: div)

        #expect(retrieved == nil)
    }

    @Test("NodeScoringManager getContentScore returns 0 for unscored")
    func testDefaultContentScore() throws {
        let manager = NodeScoringManager()
        let html = "<div>Test</div>"
        let doc = try SwiftSoup.parse(html)
        let div = try doc.select("div").first()!

        let score = manager.getContentScore(for: div)

        #expect(score == 0)
    }

    @Test("NodeScoringManager isInitialized returns false for new element")
    func testIsInitializedFalse() throws {
        let manager = NodeScoringManager()
        let html = "<div>Test</div>"
        let doc = try SwiftSoup.parse(html)
        let div = try doc.select("div").first()!

        let initialized = manager.isInitialized(div)

        #expect(initialized == false)
    }

    @Test("NodeScoringManager addToScore works")
    func testAddToScore() throws {
        let manager = NodeScoringManager()
        let html = "<div>Test</div>"
        let doc = try SwiftSoup.parse(html)
        let div = try doc.select("div").first()!

        manager.addToScore(5.0, for: div)
        manager.addToScore(3.0, for: div)

        let score = manager.getContentScore(for: div)

        #expect(score == 8.0)
    }

    @Test("NodeScoringManager multiplyScore works")
    func testMultiplyScore() throws {
        let manager = NodeScoringManager()
        let html = "<div>Test</div>"
        let doc = try SwiftSoup.parse(html)
        let div = try doc.select("div").first()!

        manager.addToScore(10.0, for: div)
        manager.multiplyScore(by: 0.5, for: div)

        let score = manager.getContentScore(for: div)

        #expect(score == 5.0)
    }

    @Test("NodeScoringManager clear removes all scores")
    func testClear() throws {
        let manager = NodeScoringManager()
        let html = "<div><p>Test</p></div>"
        let doc = try SwiftSoup.parse(html)
        let div = try doc.select("div").first()!
        let p = try doc.select("p").first()!

        manager.addToScore(5.0, for: div)
        manager.addToScore(3.0, for: p)
        manager.clear()

        #expect(manager.getContentScore(for: div) == 0)
        #expect(manager.getContentScore(for: p) == 0)
    }

    @Test("NodeScoringManager removeScore works for specific element")
    func testRemoveScore() throws {
        let manager = NodeScoringManager()
        let html = "<div><p>Test</p></div>"
        let doc = try SwiftSoup.parse(html)
        let div = try doc.select("div").first()!
        let p = try doc.select("p").first()!

        manager.addToScore(5.0, for: div)
        manager.addToScore(3.0, for: p)
        manager.removeScore(for: div)

        #expect(manager.getContentScore(for: div) == 0)
        #expect(manager.getContentScore(for: p) == 3.0)
    }

    // MARK: - initializeNode Tests

    @Test("initializeNode sets DIV base score to 5")
    func testInitializeNodeDiv() throws {
        let manager = NodeScoringManager()
        let html = "<div>Test</div>"
        let doc = try SwiftSoup.parse(html)
        let div = try doc.select("div").first()!

        let score = manager.initializeNode(div)

        #expect(score.contentScore == 5.0)
        #expect(score.initialized == true)
    }

    @Test("initializeNode sets PRE base score to 3")
    func testInitializeNodePre() throws {
        let manager = NodeScoringManager()
        let html = "<pre>Test</pre>"
        let doc = try SwiftSoup.parse(html)
        let pre = try doc.select("pre").first()!

        let score = manager.initializeNode(pre)

        #expect(score.contentScore == 3.0)
    }

    @Test("initializeNode sets TD base score to 3")
    func testInitializeNodeTd() throws {
        let manager = NodeScoringManager()
        let html = "<table><tr><td>Test</td></tr></table>"
        let doc = try SwiftSoup.parse(html)
        let td = try doc.select("td").first()!

        let score = manager.initializeNode(td)

        #expect(score.contentScore == 3.0)
    }

    @Test("initializeNode sets BLOCKQUOTE base score to 3")
    func testInitializeNodeBlockquote() throws {
        let manager = NodeScoringManager()
        let html = "<blockquote>Test</blockquote>"
        let doc = try SwiftSoup.parse(html)
        let bq = try doc.select("blockquote").first()!

        let score = manager.initializeNode(bq)

        #expect(score.contentScore == 3.0)
    }

    @Test("initializeNode subtracts 3 for address elements")
    func testInitializeNodeAddress() throws {
        let manager = NodeScoringManager()
        let html = "<address>Test</address>"
        let doc = try SwiftSoup.parse(html)
        let addr = try doc.select("address").first()!

        let score = manager.initializeNode(addr)

        #expect(score.contentScore == -3.0)
    }

    @Test("initializeNode subtracts 3 for list elements")
    func testInitializeNodeLists() throws {
        let manager = NodeScoringManager()
        let html = "<ol><li>Test</li></ol>"
        let doc = try SwiftSoup.parse(html)
        let ol = try doc.select("ol").first()!
        let li = try doc.select("li").first()!

        let olScore = manager.initializeNode(ol)
        let liScore = manager.initializeNode(li)

        #expect(olScore.contentScore == -3.0)
        #expect(liScore.contentScore == -3.0)
    }

    @Test("initializeNode subtracts 5 for heading elements")
    func testInitializeNodeHeadings() throws {
        let manager = NodeScoringManager()
        let html = "<h1>Test</h1><h2>Test</h2><h3>Test</h3><h4>Test</h4><h5>Test</h5><h6>Test</h6>"
        let doc = try SwiftSoup.parse(html)

        for i in 1...6 {
            let h = try doc.select("h\(i)").first()!
            let score = manager.initializeNode(h)
            #expect(score.contentScore == -5.0, "h\(i) should have score -5")
        }
    }

    @Test("initializeNodeIfNeeded only initializes once")
    func testInitializeNodeIfNeeded() throws {
        let manager = NodeScoringManager()
        let html = "<div>Test</div>"
        let doc = try SwiftSoup.parse(html)
        let div = try doc.select("div").first()!

        let first = manager.initializeNodeIfNeeded(div)
        let second = manager.initializeNodeIfNeeded(div)

        // First should set to 5
        #expect(first.contentScore == 5.0)
        // Second should return existing
        #expect(second.contentScore == 5.0)

        // Add to score
        manager.addToScore(10.0, for: div)

        // Third should still return the same (with added score)
        let third = manager.initializeNodeIfNeeded(div)
        #expect(third.contentScore == 15.0)
    }

    // MARK: - getClassWeight Tests

    @Test("getClassWeight returns positive for positive patterns")
    func testClassWeightPositive() throws {
        let manager = NodeScoringManager()
        let html = "<div class='article-content'>Test</div>"
        let doc = try SwiftSoup.parse(html)
        let div = try doc.select("div").first()!

        let weight = manager.getClassWeight(for: div)

        #expect(weight == 25.0)
    }

    @Test("getClassWeight returns negative for negative patterns")
    func testClassWeightNegative() throws {
        let manager = NodeScoringManager()
        let html = "<div class='comment-section'>Test</div>"
        let doc = try SwiftSoup.parse(html)
        let div = try doc.select("div").first()!

        let weight = manager.getClassWeight(for: div)

        #expect(weight == -25.0)
    }

    @Test("getClassWeight checks id attribute")
    func testClassWeightId() throws {
        let manager = NodeScoringManager()
        let html = "<div id='sidebar'>Test</div>"
        let doc = try SwiftSoup.parse(html)
        let div = try doc.select("div").first()!

        let weight = manager.getClassWeight(for: div)

        #expect(weight == -25.0)
    }

    @Test("getClassWeight returns 0 when flag disabled")
    func testClassWeightFlagDisabled() throws {
        let manager = NodeScoringManager()
        let html = "<div class='article'>Test</div>"
        let doc = try SwiftSoup.parse(html)
        let div = try doc.select("div").first()!

        let weight = manager.getClassWeight(for: div, flagWeightClasses: false)

        #expect(weight == 0)
    }

    @Test("getClassWeight combines class and id")
    func testClassWeightCombined() throws {
        let manager = NodeScoringManager()
        let html = "<div class='article' id='sidebar'>Test</div>"
        let doc = try SwiftSoup.parse(html)
        let div = try doc.select("div").first()!

        let weight = manager.getClassWeight(for: div)

        // +25 for article, -25 for sidebar = 0
        #expect(weight == 0)
    }

    // MARK: - getLinkDensity Tests

    @Test("getLinkDensity returns 0 for no links")
    func testLinkDensityNoLinks() throws {
        let manager = NodeScoringManager()
        let html = "<div>Just text without links</div>"
        let doc = try SwiftSoup.parse(html)
        let div = try doc.select("div").first()!

        let density = try manager.getLinkDensity(for: div)

        #expect(density == 0)
    }

    @Test("getLinkDensity calculates correctly")
    func testLinkDensityCalculation() throws {
        let manager = NodeScoringManager()
        let html = "<div>Text <a href='http://example.com'>link text</a> more text</div>"
        let doc = try SwiftSoup.parse(html)
        let div = try doc.select("div").first()!

        let density = try manager.getLinkDensity(for: div)

        // Total text: "Text link text more text" = 24 chars
        // Link text: "link text" = 9 chars
        // Density: 9/24 = 0.375
        #expect(density > 0.3 && density < 0.4)
    }

    @Test("getLinkDensity applies hash URL coefficient")
    func testLinkDensityHashUrl() throws {
        let manager = NodeScoringManager()
        let html = """
        <div>
            Text before
            <a href='#anchor'>hash link</a>
            <a href='http://example.com'>normal link</a>
            Text after
        </div>
        """
        let doc = try SwiftSoup.parse(html)
        let div = try doc.select("div").first()!

        let density = try manager.getLinkDensity(for: div)

        // Hash link gets 0.3 coefficient
        // Normal link gets 1.0 coefficient
        // Should be less than if both were normal links
        #expect(density > 0)
    }

    @Test("getLinkDensity returns 0 for empty element")
    func testLinkDensityEmpty() throws {
        let manager = NodeScoringManager()
        let html = "<div></div>"
        let doc = try SwiftSoup.parse(html)
        let div = try doc.select("div").first()!

        let density = try manager.getLinkDensity(for: div)

        #expect(density == 0)
    }

    // MARK: - scoreElement Tests

    @Test("scoreElement returns 0 for short text")
    func testScoreElementShortText() throws {
        let manager = NodeScoringManager()
        let html = "<div>Short</div>"
        let doc = try SwiftSoup.parse(html)
        let div = try doc.select("div").first()!

        let score = try manager.scoreElement(div, options: .default)

        #expect(score == 0)
    }

    @Test("scoreElement returns 0 for hidden elements")
    func testScoreElementHidden() throws {
        let manager = NodeScoringManager()
        let html = "<div style='display:none'>This is a longer text that should be scored but it's hidden from view</div>"
        let doc = try SwiftSoup.parse(html)
        let div = try doc.select("div").first()!

        let score = try manager.scoreElement(div, options: .default)

        #expect(score == 0)
    }

    @Test("scoreElement calculates score for valid content")
    func testScoreElementValid() throws {
        let manager = NodeScoringManager()
        // Text with commas and sufficient length (>25 chars)
        let html = "<div class='article'>This is a longer text, with some commas, for testing purposes</div>"
        let doc = try SwiftSoup.parse(html)
        let div = try doc.select("div").first()!

        let score = try manager.scoreElement(div, options: .default)

        // Should have base score (5) + comma count (2) + length score (~0.7) + class weight (25)
        // Minus link density penalty (0 in this case)
        #expect(score > 25) // At least the class weight
    }

    // MARK: - Candidate Tests

    @Test("Candidate stores element and score")
    func testCandidate() throws {
        let html = "<div>Test</div>"
        let doc = try SwiftSoup.parse(html)
        let div = try doc.select("div").first()!

        let candidate = Candidate(element: div, score: 10.5)

        #expect(candidate.element === div)
        #expect(candidate.score == 10.5)
    }

    // MARK: - TopCandidates Tests

    @Test("TopCandidates maintains sorted order")
    func testTopCandidatesSorted() throws {
        let html = "<div><p id='a'></p><p id='b'></p><p id='c'></p></div>"
        let doc = try SwiftSoup.parse(html)
        let pa = try doc.select("p#a").first()!
        let pb = try doc.select("p#b").first()!
        let pc = try doc.select("p#c").first()!

        let top = TopCandidates(maxCount: 3)
        top.add(Candidate(element: pb, score: 20))
        top.add(Candidate(element: pa, score: 30))
        top.add(Candidate(element: pc, score: 10))

        #expect(top[0]?.score == 30)
        #expect(top[1]?.score == 20)
        #expect(top[2]?.score == 10)
    }

    @Test("TopCandidates respects max count")
    func testTopCandidatesMaxCount() throws {
        let html = "<div><p id='a'></p><p id='b'></p><p id='c'></p><p id='d'></p></div>"
        let doc = try SwiftSoup.parse(html)
        let pa = try doc.select("p#a").first()!
        let pb = try doc.select("p#b").first()!
        let pc = try doc.select("p#c").first()!
        let pd = try doc.select("p#d").first()!

        let top = TopCandidates(maxCount: 2)
        top.add(Candidate(element: pa, score: 10))
        top.add(Candidate(element: pb, score: 20))
        top.add(Candidate(element: pc, score: 30))
        top.add(Candidate(element: pd, score: 5))

        #expect(top.count == 2)
        #expect(top[0]?.score == 30)
        #expect(top[1]?.score == 20)
    }

    @Test("TopCandidates best returns highest")
    func testTopCandidatesBest() throws {
        let html = "<div><p id='a'></p><p id='b'></p></div>"
        let doc = try SwiftSoup.parse(html)
        let pa = try doc.select("p#a").first()!
        let pb = try doc.select("p#b").first()!

        let top = TopCandidates(maxCount: 3)
        top.add(Candidate(element: pa, score: 10))
        top.add(Candidate(element: pb, score: 50))

        #expect(top.best?.score == 50)
    }

    @Test("TopCandidates isEmpty when no candidates")
    func testTopCandidatesEmpty() {
        let top = TopCandidates(maxCount: 5)

        #expect(top.isEmpty == true)
    }

    @Test("TopCandidates clear removes all")
    func testTopCandidatesClear() throws {
        let html = "<div><p>Test</p></div>"
        let doc = try SwiftSoup.parse(html)
        let p = try doc.select("p").first()!

        let top = TopCandidates(maxCount: 5)
        top.add(Candidate(element: p, score: 10))
        top.clear()

        #expect(top.isEmpty == true)
        #expect(top.count == 0)
    }

    @Test("TopCandidates handles same score elements")
    func testTopCandidatesSameScore() throws {
        let html = "<div><p id='a'></p><p id='b'></p></div>"
        let doc = try SwiftSoup.parse(html)
        let pa = try doc.select("p#a").first()!
        let pb = try doc.select("p#b").first()!

        let top = TopCandidates(maxCount: 2)
        top.add(Candidate(element: pa, score: 10))
        top.add(Candidate(element: pb, score: 10))

        #expect(top.count == 2)
    }

    @Test("TopCandidates subscript returns nil for out of bounds")
    func testTopCandidatesSubscriptBounds() throws {
        let html = "<div><p>Test</p></div>"
        let doc = try SwiftSoup.parse(html)
        let p = try doc.select("p").first()!

        let top = TopCandidates(maxCount: 3)
        top.add(Candidate(element: p, score: 10))

        #expect(top[0] != nil)
        #expect(top[-1] == nil)
        #expect(top[1] == nil)
    }
}
