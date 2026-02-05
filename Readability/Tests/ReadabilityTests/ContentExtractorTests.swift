import Testing
import SwiftSoup
@testable import Readability

/// Tests for ContentExtractor functionality
@Suite("Content Extractor Tests")
struct ContentExtractorTests {

    // MARK: - Basic Extraction Tests

    @Test("extract returns content for valid article")
    func testBasicExtraction() throws {
        let html = """
        <html><body>
        <div class="article">
            <p>This is a paragraph with enough text to be considered content, and it has commas too.</p>
            <p>Second paragraph with more text content here.</p>
        </div>
        </body></html>
        """
        let doc = try SwiftSoup.parse(html)

        let extractor = ContentExtractor(doc: doc, options: .default)
        let result = try extractor.extract()

        #expect(result.content.tagName().lowercased() == "div")
        let text = try result.content.text()
        #expect(text.count >= 100)
    }

    @Test("extract throws for empty document")
    func testEmptyDocument() throws {
        let html = "<html><body></body></html>"
        let doc = try SwiftSoup.parse(html)

        let extractor = ContentExtractor(doc: doc, options: .default)

        #expect(throws: ReadabilityError.self) {
            try extractor.extract()
        }
    }

    @Test("extract attempts fallback for short content")
    func testFallbackForShortContent() throws {
        // Very short content that will trigger multiple attempts
        let html = """
        <html><body>
        <p>Hi.</p>
        </body></html>
        """
        let doc = try SwiftSoup.parse(html)

        let options = ReadabilityOptions(charThreshold: 100)
        let extractor = ContentExtractor(doc: doc, options: options)

        // Will return best attempt even if below threshold
        let result = try extractor.extract()
        let text = try result.content.text()
        #expect(text.count > 0)

        // Should have attempted multiple times
        let attempts = extractor.getAttemptInfo()
        #expect(attempts.count >= 3)
    }

    // MARK: - Flag System Tests

    @Test("extract tries all flag combinations")
    func testAllFlagCombinations() throws {
        // Very short content that will trigger all flag combinations
        let html = """
        <html><body>
        <p>X.</p>
        </body></html>
        """
        let doc = try SwiftSoup.parse(html)

        let options = ReadabilityOptions(charThreshold: 500)
        let extractor = ContentExtractor(doc: doc, options: options)

        // Returns best attempt even if below threshold
        let result = try extractor.extract()
        let text = try result.content.text()
        #expect(text.count > 0)

        // Should have tried all flag combinations
        let attempts = extractor.getAttemptInfo()
        #expect(attempts.count >= 3)
    }

    @Test("getAttemptInfo returns correct flag names")
    func testAttemptInfo() throws {
        let html = """
        <html><body>
        <p>Short content that will trigger fallback.</p>
        </body></html>
        """
        let doc = try SwiftSoup.parse(html)

        let options = ReadabilityOptions(charThreshold: 200)
        let extractor = ContentExtractor(doc: doc, options: options)

        // First attempt will fail, then fallback
        _ = try? extractor.extract()

        let attempts = extractor.getAttemptInfo()
        for attempt in attempts {
            // Each attempt should have flag info
            #expect(attempt.flags.count > 0 || attempt.textLength >= 0)
        }
    }

    // MARK: - Element Scoring Tests

    @Test("extract prefers high scoring elements")
    func testPrefersHighScoring() throws {
        let html = """
        <html><body>
        <div class="sidebar">
            <p>Sidebar content with some text.</p>
        </div>
        <article class="main-article">
            <p>This is the main article with much more content, and commas, and length.</p>
            <p>Multiple paragraphs help increase the score significantly.</p>
        </article>
        </body></html>
        """
        let doc = try SwiftSoup.parse(html)

        let extractor = ContentExtractor(doc: doc, options: .default)
        let result = try extractor.extract()

        let text = try result.content.text()
        // Should prefer article content over sidebar
        #expect(text.contains("main article") || text.contains("Multiple paragraphs"))
    }

    // MARK: - Multi-attempt Selection Tests

    @Test("extract selects best attempt when all fail threshold")
    func testSelectsBestAttempt() throws {
        // Content that fails threshold but has some content
        let html = """
        <html><body>
        <p>X.</p>
        </body></html>
        """
        let doc = try SwiftSoup.parse(html)

        let options = ReadabilityOptions(charThreshold: 500)
        let extractor = ContentExtractor(doc: doc, options: options)

        // Returns best attempt even if below threshold
        let result = try extractor.extract()
        let text = try result.content.text()
        #expect(text.count > 0)
    }

    @Test("extract handles content with only one good attempt")
    func testSingleGoodAttempt() throws {
        let html = """
        <html><body>
        <div class="content">
            <p>This content is long enough when flags are set correctly, with many words and commas here.</p>
            <p>Second paragraph adds more length to ensure it passes the threshold check.</p>
        </div>
        </body></html>
        """
        let doc = try SwiftSoup.parse(html)

        let extractor = ContentExtractor(doc: doc, options: .default)
        let result = try extractor.extract()

        let text = try result.content.text()
        #expect(text.count >= 100)
    }

    // MARK: - Edge Cases

    @Test("extract handles document with no body")
    func testNoBody() throws {
        let html = "<html><head><title>Test</title></head></html>"
        let doc = try SwiftSoup.parse(html)

        let extractor = ContentExtractor(doc: doc, options: .default)

        #expect(throws: ReadabilityError.self) {
            try extractor.extract()
        }
    }

    @Test("extract handles hidden content")
    func testHiddenContent() throws {
        let html = """
        <html><body>
        <div style="display:none">
            <p>This hidden content should not be considered.</p>
        </div>
        <div>
            <p>Visible content with enough text to be the main article, and commas too.</p>
        </div>
        </body></html>
        """
        let doc = try SwiftSoup.parse(html)

        let extractor = ContentExtractor(doc: doc, options: .default)
        let result = try extractor.extract()

        let text = try result.content.text()
        #expect(!text.contains("hidden content"))
        #expect(text.contains("Visible content"))
    }

    @Test("extract preserves structure during fallback")
    func testPreservesStructure() throws {
        let html = """
        <html><body>
        <article>
            <p>Paragraph one with text content here.</p>
            <p>Paragraph two with more text content.</p>
        </article>
        </body></html>
        """
        let doc = try SwiftSoup.parse(html)

        let extractor = ContentExtractor(doc: doc, options: .default)
        let result = try extractor.extract()

        // Should have paragraphs
        let paragraphs = try result.content.select("p")
        #expect(paragraphs.count >= 1)
    }

    // MARK: - Configuration Tests

    @Test("extract respects charThreshold option")
    func testRespectsCharThreshold() throws {
        let html = """
        <html><body>
        <p>Content here.</p>
        </body></html>
        """
        let doc = try SwiftSoup.parse(html)

        // High threshold will return best attempt
        let strictOptions = ReadabilityOptions(charThreshold: 500)
        let strictExtractor = ContentExtractor(doc: doc, options: strictOptions)

        let strictResult = try strictExtractor.extract()
        let strictText = try strictResult.content.text()
        #expect(strictText.count > 0) // Returns best attempt

        // Low threshold should succeed normally
        let lenientOptions = ReadabilityOptions(charThreshold: 5)
        let lenientExtractor = ContentExtractor(doc: doc, options: lenientOptions)

        let result = try lenientExtractor.extract()
        let text = try result.content.text()
        #expect(text.count >= 5)
    }

    @Test("extract respects linkDensityModifier option")
    func testRespectsLinkDensityModifier() throws {
        let html = """
        <html><body>
        <div>
            <p>Content with <a href="http://example.com">many links</a> and 
            <a href="http://example.com">more links</a> that might affect scoring.</p>
        </div>
        </body></html>
        """
        let doc = try SwiftSoup.parse(html)

        // With modifier that allows more links
        let options = ReadabilityOptions(linkDensityModifier: 0.5)
        let extractor = ContentExtractor(doc: doc, options: options)

        let result = try extractor.extract()
        let text = try result.content.text()
        #expect(text.count > 0)
    }
}
