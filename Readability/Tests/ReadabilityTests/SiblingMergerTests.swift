import Testing
import SwiftSoup
@testable import Readability

/// Tests for SiblingMerger functionality
@Suite("Sibling Merger Tests")
struct SiblingMergerTests {

    // MARK: - mergeSiblings Tests

    @Test("mergeSiblings includes top candidate")
    func testMergeIncludesTopCandidate() throws {
        let html = """
        <div id="parent">
            <p id="top">This is the main content with enough text and commas, to be considered the top candidate</p>
            <p id="sibling">Sibling content</p>
        </div>
        """
        let doc = try SwiftSoup.parseBodyFragment(html)
        let top = try doc.select("#top").first()!

        let scoringManager = NodeScoringManager()
        scoringManager.initializeNode(top)
        scoringManager.addToScore(100, for: top)

        let merger = SiblingMerger(options: .default, scoringManager: scoringManager)
        let article = try merger.mergeSiblings(topCandidate: top, in: doc)

        // Should include top candidate
        let paragraphs = try article.select("p")
        #expect(paragraphs.count >= 1)
    }

    @Test("mergeSiblings includes siblings with same class")
    func testMergeSameClassSiblings() throws {
        let html = """
        <div id="parent">
            <p class="content" id="top">Main content with enough text and commas, for scoring</p>
            <p class="content" id="sibling">Sibling with same class</p>
        </div>
        """
        let doc = try SwiftSoup.parseBodyFragment(html)
        let top = try doc.select("#top").first()!
        let sibling = try doc.select("#sibling").first()!

        let scoringManager = NodeScoringManager()
        scoringManager.initializeNode(top)
        scoringManager.addToScore(100, for: top)

        // Sibling has lower score but same class
        scoringManager.initializeNode(sibling)
        scoringManager.addToScore(10, for: sibling)

        let merger = SiblingMerger(options: .default, scoringManager: scoringManager)
        let article = try merger.mergeSiblings(topCandidate: top, in: doc)

        // Should include both due to class name bonus
        let paragraphs = try article.select("p")
        #expect(paragraphs.count >= 2)
    }

    @Test("mergeSiblings includes high scoring siblings")
    func testMergeHighScoringSiblings() throws {
        let html = """
        <div id="parent">
            <p id="top">Main content with enough text and commas, for scoring purposes</p>
            <p id="sibling">Sibling with high score</p>
        </div>
        """
        let doc = try SwiftSoup.parseBodyFragment(html)
        let top = try doc.select("#top").first()!
        let sibling = try doc.select("#sibling").first()!

        let scoringManager = NodeScoringManager()
        scoringManager.initializeNode(top)
        scoringManager.addToScore(100, for: top)

        // Sibling has score above threshold (20% of 100 = 20)
        scoringManager.initializeNode(sibling)
        scoringManager.addToScore(30, for: sibling)

        let merger = SiblingMerger(options: .default, scoringManager: scoringManager)
        let article = try merger.mergeSiblings(topCandidate: top, in: doc)

        // Should include both
        let paragraphs = try article.select("p")
        #expect(paragraphs.count >= 2)
    }

    @Test("mergeSiblings excludes low scoring siblings")
    func testExcludeLowScoringSiblings() throws {
        let html = """
        <div id="parent">
            <p id="top">Main content with enough text and commas, for scoring</p>
            <p id="low">Low score sibling</p>
        </div>
        """
        let doc = try SwiftSoup.parseBodyFragment(html)
        let top = try doc.select("#top").first()!
        let low = try doc.select("#low").first()!

        let scoringManager = NodeScoringManager()
        scoringManager.initializeNode(top)
        scoringManager.addToScore(100, for: top)

        // Low score sibling (below 20% threshold)
        scoringManager.initializeNode(low)
        scoringManager.addToScore(5, for: low)

        let merger = SiblingMerger(options: .default, scoringManager: scoringManager)
        let article = try merger.mergeSiblings(topCandidate: top, in: doc)

        // Should only include top
        let lowParagraphs = try article.select("#low")
        #expect(lowParagraphs.isEmpty())
    }

    // MARK: - P Tag Special Handling Tests

    @Test("mergeSiblings includes long P with low link density")
    func testIncludeLongParagraph() throws {
        let html = """
        <div id="parent">
            <p id="top">Main content with enough text and commas, for scoring</p>
            <p id="long">This is a long paragraph with many words and no links so it should be included in the merged content</p>
        </div>
        """
        let doc = try SwiftSoup.parseBodyFragment(html)
        let top = try doc.select("#top").first()!

        let scoringManager = NodeScoringManager()
        scoringManager.initializeNode(top)
        scoringManager.addToScore(100, for: top)

        let merger = SiblingMerger(options: .default, scoringManager: scoringManager)
        let article = try merger.mergeSiblings(topCandidate: top, in: doc)

        let longParagraphs = try article.select("#long")
        #expect(!longParagraphs.isEmpty())
    }

    @Test("mergeSiblings includes short P ending with period")
    func testIncludeShortParagraphWithPeriod() throws {
        let html = """
        <div id="parent">
            <p id="top">Main content with enough text and commas, for scoring</p>
            <p id="short">Short sentence.</p>
        </div>
        """
        let doc = try SwiftSoup.parseBodyFragment(html)
        let top = try doc.select("#top").first()!

        let scoringManager = NodeScoringManager()
        scoringManager.initializeNode(top)
        scoringManager.addToScore(100, for: top)

        let merger = SiblingMerger(options: .default, scoringManager: scoringManager)
        let article = try merger.mergeSiblings(topCandidate: top, in: doc)

        let shortParagraphs = try article.select("#short")
        #expect(!shortParagraphs.isEmpty())
    }

    @Test("mergeSiblings excludes P with high link density")
    func testExcludeHighLinkDensityParagraph() throws {
        let html = """
        <div id="parent">
            <p id="top">Main content with enough text and commas, for scoring</p>
            <p id="linky"><a href="http://example.com">Link text link text link text</a> small text</p>
        </div>
        """
        let doc = try SwiftSoup.parseBodyFragment(html)
        let top = try doc.select("#top").first()!

        let scoringManager = NodeScoringManager()
        scoringManager.initializeNode(top)
        scoringManager.addToScore(100, for: top)

        let merger = SiblingMerger(options: .default, scoringManager: scoringManager)
        let article = try merger.mergeSiblings(topCandidate: top, in: doc)

        // Should exclude due to high link density
        let linkyParagraphs = try article.select("#linky")
        #expect(linkyParagraphs.isEmpty())
    }

    // MARK: - DIV Alteration Tests

    @Test("mergeSiblings alters non-exception tags to DIV")
    func testAlterToDiv() throws {
        let html = """
        <div id="parent">
            <p id="top">Main content with enough text and commas, for scoring</p>
            <span id="spanner" class="test">Span content</span>
        </div>
        """
        let doc = try SwiftSoup.parseBodyFragment(html)
        let top = try doc.select("#top").first()!

        // Give span a score to be included
        let span = try doc.select("#spanner").first()!

        let scoringManager = NodeScoringManager()
        scoringManager.initializeNode(top)
        scoringManager.addToScore(100, for: top)

        scoringManager.initializeNode(span)
        scoringManager.addToScore(30, for: span)

        let merger = SiblingMerger(options: .default, scoringManager: scoringManager)
        let article = try merger.mergeSiblings(topCandidate: top, in: doc)

        // Span should be converted to DIV
        let spans = try article.select("span")
        #expect(spans.isEmpty())

        let divs = try article.select("div.test")
        #expect(!divs.isEmpty())
    }

    @Test("mergeSiblings keeps exception tags unchanged")
    func testKeepExceptionTags() throws {
        let html = """
        <div id="parent">
            <article id="top">Main content with enough text and commas, for scoring</article>
            <section id="section">Section content</section>
        </div>
        """
        let doc = try SwiftSoup.parseBodyFragment(html)
        let top = try doc.select("#top").first()!
        let section = try doc.select("#section").first()!

        let scoringManager = NodeScoringManager()
        scoringManager.initializeNode(top)
        scoringManager.addToScore(100, for: top)

        scoringManager.initializeNode(section)
        scoringManager.addToScore(30, for: section)

        let merger = SiblingMerger(options: .default, scoringManager: scoringManager)
        let article = try merger.mergeSiblings(topCandidate: top, in: doc)

        // Section should remain as section (in exception list)
        let sections = try article.select("section")
        #expect(!sections.isEmpty())
    }

    // MARK: - Score Threshold Tests

    @Test("calculateSiblingScoreThreshold uses minimum")
    func testThresholdMinimum() throws {
        let html = "<p id='top'>Test</p>"
        let doc = try SwiftSoup.parseBodyFragment(html)
        let top = try doc.select("#top").first()!

        let scoringManager = NodeScoringManager()
        scoringManager.initializeNode(top)
        scoringManager.addToScore(5, for: top) // Low score

        let merger = SiblingMerger(options: .default, scoringManager: scoringManager)
        let threshold = merger.calculateSiblingScoreThreshold(for: top)

        // Should use minimum of 10
        #expect(threshold == 10)
    }

    @Test("calculateSiblingScoreThreshold uses ratio")
    func testThresholdRatio() throws {
        let html = "<p id='top'>Test</p>"
        let doc = try SwiftSoup.parseBodyFragment(html)
        let top = try doc.select("#top").first()!

        let scoringManager = NodeScoringManager()
        scoringManager.initializeNode(top)
        scoringManager.addToScore(100, for: top)

        let merger = SiblingMerger(options: .default, scoringManager: scoringManager)
        let threshold = merger.calculateSiblingScoreThreshold(for: top)

        // Should use 20% of 100 = 20
        #expect(threshold == 20)
    }

    // MARK: - Wrapper Creation Tests

    @Test("createArticleContentWrapper creates div with id")
    func testCreateArticleWrapper() throws {
        let html = "<p>Test</p>"
        let doc = try SwiftSoup.parseBodyFragment(html)

        let merger = SiblingMerger(options: .default, scoringManager: NodeScoringManager())
        let wrapper = try merger.createArticleContentWrapper(in: doc)

        #expect(wrapper.tagName().lowercased() == "div")
        #expect(wrapper.id() == "readability-content")
    }

    @Test("createPageWrapper creates page div")
    func testCreatePageWrapper() throws {
        let html = "<p>Test</p>"
        let doc = try SwiftSoup.parseBodyFragment(html)

        let merger = SiblingMerger(options: .default, scoringManager: NodeScoringManager())
        let wrapper = try merger.createPageWrapper(in: doc, pageNumber: 1)

        #expect(wrapper.tagName().lowercased() == "div")
        #expect(wrapper.id() == "readability-page-1")
        #expect(wrapper.hasClass("page"))
    }

    // MARK: - Edge Cases

    @Test("mergeSiblings handles no parent")
    func testNoParent() throws {
        let html = "<p id='top'>Orphan content</p>"
        let doc = try SwiftSoup.parse(html)
        let top = try doc.select("#top").first()!

        let scoringManager = NodeScoringManager()
        scoringManager.initializeNode(top)
        scoringManager.addToScore(100, for: top)

        let merger = SiblingMerger(options: .default, scoringManager: scoringManager)
        let article = try merger.mergeSiblings(topCandidate: top, in: doc)

        // Should still include top candidate
        let paragraphs = try article.select("p")
        #expect(!paragraphs.isEmpty())
    }

    @Test("mergeSiblings preserves attributes when altering")
    func testPreserveAttributes() throws {
        let html = """
        <div id="parent">
            <p id="top">Main content with enough text and commas, for scoring</p>
            <span id="spanner" class="test-class" data-foo="bar">Span</span>
        </div>
        """
        let doc = try SwiftSoup.parseBodyFragment(html)
        let top = try doc.select("#top").first()!
        let span = try doc.select("#spanner").first()!

        let scoringManager = NodeScoringManager()
        scoringManager.initializeNode(top)
        scoringManager.addToScore(100, for: top)

        scoringManager.initializeNode(span)
        scoringManager.addToScore(30, for: span)

        let merger = SiblingMerger(options: .default, scoringManager: scoringManager)
        let article = try merger.mergeSiblings(topCandidate: top, in: doc)

        // Attributes should be preserved on converted div
        let divs = try article.select("div.test-class")
        #expect(!divs.isEmpty())

        let div = divs.first()!
        #expect(div.hasAttr("data-foo"))
        #expect(try div.attr("data-foo") == "bar")
    }
}
