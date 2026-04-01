import Testing
import Foundation
@testable import Readability

/// Compatibility tests for cases captured via ReadabilityCLI (ex-pages/).
///
/// Each test method corresponds to one case committed with `swift run ReadabilityCLI commit`.
/// Add methods here manually after running `commit` — the command prints a ready-to-use template.
@Suite("Ex-pages Compatibility Tests")
struct ExPagesCompatibilityTests {

    private let defaultOptions = ReadabilityOptions(
        charThreshold: 500,
        classesToPreserve: ["caption"]
    )

    private func parse(_ testCase: TestLoader.TestCase) throws -> ReadabilityResult {
        try Readability(
            html: testCase.sourceHTML,
            baseURL: testCase.sourceURL,
            options: defaultOptions
        ).parse()
    }

    // MARK: - Tests

    // MARK: 1a23-1 · Holpxay Calculator (1a23.com)

    @Test("1a23-1 - Title matches expected")
    func test1a231Title() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "1a23-1", in: "ex-pages") else {
            Issue.record("Failed to load test case '1a23-1'")
            return
        }
        let result = try parse(testCase)
        #expect(result.title == testCase.expectedMetadata.title)
    }

    @Test("1a23-1 - Byline matches expected")
    func test1a231Byline() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "1a23-1", in: "ex-pages") else {
            Issue.record("Failed to load test case '1a23-1'")
            return
        }
        let result = try parse(testCase)
        #expect(result.byline == testCase.expectedMetadata.byline)
    }

    @Test("1a23-1 - Content matches expected HTML")
    func test1a231Content() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "1a23-1", in: "ex-pages") else {
            Issue.record("Failed to load test case '1a23-1'")
            return
        }
        let result = try parse(testCase)
        let (isEqual, diff) = DOMComparator.compare(result.content, testCase.expectedHTML)
        #expect(isEqual, "DOM mismatch:\n\(diff)")
    }

    // MARK: 1a23-2 · Have a wonderful 2026! (1a23.com)

    @Test("1a23-2 - Title matches expected")
    func test1a232Title() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "1a23-2", in: "ex-pages") else {
            Issue.record("Failed to load test case '1a23-2'")
            return
        }
        let result = try parse(testCase)
        #expect(result.title == testCase.expectedMetadata.title)
    }

    @Test("1a23-2 - Byline matches expected")
    func test1a232Byline() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "1a23-2", in: "ex-pages") else {
            Issue.record("Failed to load test case '1a23-2'")
            return
        }
        let result = try parse(testCase)
        #expect(result.byline == testCase.expectedMetadata.byline)
    }

    @Test("1a23-2 - Content matches expected HTML")
    func test1a232Content() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "1a23-2", in: "ex-pages") else {
            Issue.record("Failed to load test case '1a23-2'")
            return
        }
        let result = try parse(testCase)
        let (isEqual, diff) = DOMComparator.compare(result.content, testCase.expectedHTML)
        #expect(isEqual, "DOM mismatch:\n\(diff)")
    }

    // MARK: 1a23-3 · TRMNL recipies (1a23.com)

    @Test("1a23-3 - Title matches expected")
    func test1a233Title() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "1a23-3", in: "ex-pages") else {
            Issue.record("Failed to load test case '1a23-3'")
            return
        }
        let result = try parse(testCase)
        #expect(result.title == testCase.expectedMetadata.title)
    }

    @Test("1a23-3 - Byline matches expected")
    func test1a233Byline() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "1a23-3", in: "ex-pages") else {
            Issue.record("Failed to load test case '1a23-3'")
            return
        }
        let result = try parse(testCase)
        #expect(result.byline == testCase.expectedMetadata.byline)
    }

    @Test("1a23-3 - Content matches expected HTML")
    func test1a233Content() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "1a23-3", in: "ex-pages") else {
            Issue.record("Failed to load test case '1a23-3'")
            return
        }
        let result = try parse(testCase)
        let (isEqual, diff) = DOMComparator.compare(result.content, testCase.expectedHTML)
        #expect(isEqual, "DOM mismatch:\n\(diff)")
    }

    // MARK: antirez-1 · Coding with LLMs in the summer of 2025 (an update) (antirez.com)

    @Test("antirez-1 - Title matches expected")
    func testAntirezTitle() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "antirez-1", in: "ex-pages") else {
            Issue.record("Failed to load test case 'antirez-1'")
            return
        }
        let result = try parse(testCase)
        #expect(result.title == testCase.expectedMetadata.title)
    }

    @Test("antirez-1 - Byline matches expected")
    func testAntirezByline() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "antirez-1", in: "ex-pages") else {
            Issue.record("Failed to load test case 'antirez-1'")
            return
        }
        let result = try parse(testCase)
        #expect(result.byline == testCase.expectedMetadata.byline)
    }

    @Test("antirez-1 - Excerpt matches expected")
    func testAntirezExcerpt() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "antirez-1", in: "ex-pages") else {
            Issue.record("Failed to load test case 'antirez-1'")
            return
        }
        let result = try parse(testCase)
        #expect(result.excerpt == testCase.expectedMetadata.excerpt)
    }

    @Test("antirez-1 - Content matches expected HTML")
    func testAntirezContent() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "antirez-1", in: "ex-pages") else {
            Issue.record("Failed to load test case 'antirez-1'")
            return
        }
        let result = try parse(testCase)
        let (isEqual, diff) = DOMComparator.compare(result.content, testCase.expectedHTML)
        #expect(isEqual, "DOM mismatch:\n\(diff)")
    }

    // MARK: antirez-2 · GNU and the AI reimplementations (antirez.com)

    @Test("antirez-2 - Title matches expected")
    func testAntirez2Title() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "antirez-2", in: "ex-pages") else {
            Issue.record("Failed to load test case 'antirez-2'")
            return
        }
        let result = try parse(testCase)
        #expect(result.title == testCase.expectedMetadata.title)
    }

    @Test("antirez-2 - Byline matches expected")
    func testAntirez2Byline() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "antirez-2", in: "ex-pages") else {
            Issue.record("Failed to load test case 'antirez-2'")
            return
        }
        let result = try parse(testCase)
        #expect(result.byline == testCase.expectedMetadata.byline)
    }

    @Test("antirez-2 - Excerpt matches expected")
    func testAntirez2Excerpt() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "antirez-2", in: "ex-pages") else {
            Issue.record("Failed to load test case 'antirez-2'")
            return
        }
        let result = try parse(testCase)
        #expect(result.excerpt == testCase.expectedMetadata.excerpt)
    }

    @Test("antirez-2 - Content matches expected HTML")
    func testAntirez2Content() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "antirez-2", in: "ex-pages") else {
            Issue.record("Failed to load test case 'antirez-2'")
            return
        }
        let result = try parse(testCase)
        let (isEqual, diff) = DOMComparator.compare(result.content, testCase.expectedHTML)
        #expect(isEqual, "DOM mismatch:\n\(diff)")
    }

    // MARK: antirez-3 · Scaling HNSWs - <antirez> (antirez.com)

    @Test("antirez-3 - Title matches expected")
    func testAntirez3Title() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "antirez-3", in: "ex-pages") else {
            Issue.record("Failed to load test case 'antirez-3'")
            return
        }
        let result = try parse(testCase)
        #expect(result.title == testCase.expectedMetadata.title)
    }

    @Test("antirez-3 - Byline matches expected")
    func testAntirez3Byline() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "antirez-3", in: "ex-pages") else {
            Issue.record("Failed to load test case 'antirez-3'")
            return
        }
        let result = try parse(testCase)
        #expect(result.byline == testCase.expectedMetadata.byline)
    }

    @Test("antirez-3 - Excerpt matches expected")
    func testAntirez3Excerpt() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "antirez-3", in: "ex-pages") else {
            Issue.record("Failed to load test case 'antirez-3'")
            return
        }
        let result = try parse(testCase)
        #expect(result.excerpt == testCase.expectedMetadata.excerpt)
    }

    @Test("antirez-3 - Content matches expected HTML")
    func testAntirez3Content() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "antirez-3", in: "ex-pages") else {
            Issue.record("Failed to load test case 'antirez-3'")
            return
        }
        let result = try parse(testCase)
        let (isEqual, diff) = DOMComparator.compare(result.content, testCase.expectedHTML)
        #expect(isEqual, "DOM mismatch:\n\(diff)")
    }

    // MARK: mariozechner · Thoughts on slowing the fuck down (mariozechner.at)

    @Test("mariozechner - Title matches expected")
    func testMariozechnerTitle() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "mariozechner", in: "ex-pages") else {
            Issue.record("Failed to load test case 'mariozechner'")
            return
        }
        let result = try parse(testCase)
        #expect(result.title == testCase.expectedMetadata.title)
    }

    @Test("mariozechner - Excerpt matches expected")
    func testMariozechnerExcerpt() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "mariozechner", in: "ex-pages") else {
            Issue.record("Failed to load test case 'mariozechner'")
            return
        }
        let result = try parse(testCase)
        #expect(result.excerpt == testCase.expectedMetadata.excerpt)
    }

    @Test("mariozechner - Content matches expected HTML")
    func testMariozechnerContent() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "mariozechner", in: "ex-pages") else {
            Issue.record("Failed to load test case 'mariozechner'")
            return
        }
        let result = try parse(testCase)
        let (isEqual, diff) = DOMComparator.compare(result.content, testCase.expectedHTML)
        #expect(isEqual, "DOM mismatch:\n\(diff)")
    }

    // MARK: simonwillison-1 · Release: datasette-llm 0.1a2 (simonwillison.net)

    @Test("simonwillison-1 - Title matches expected")
    func testSimonwillison1Title() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "simonwillison-1", in: "ex-pages") else {
            Issue.record("Failed to load test case 'simonwillison-1'")
            return
        }
        let result = try parse(testCase)
        #expect(result.title == testCase.expectedMetadata.title)
    }

    @Test("simonwillison-1 - Byline matches expected")
    func testSimonwillison1Byline() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "simonwillison-1", in: "ex-pages") else {
            Issue.record("Failed to load test case 'simonwillison-1'")
            return
        }
        let result = try parse(testCase)
        #expect(result.byline == testCase.expectedMetadata.byline)
    }

    @Test("simonwillison-1 - Excerpt matches expected")
    func testSimonwillison1Excerpt() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "simonwillison-1", in: "ex-pages") else {
            Issue.record("Failed to load test case 'simonwillison-1'")
            return
        }
        let result = try parse(testCase)
        #expect(result.excerpt == testCase.expectedMetadata.excerpt)
    }

    @Test("simonwillison-1 - Content matches expected HTML")
    func testSimonwillison1Content() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "simonwillison-1", in: "ex-pages") else {
            Issue.record("Failed to load test case 'simonwillison-1'")
            return
        }
        let result = try parse(testCase)
        let (isEqual, diff) = DOMComparator.compare(result.content, testCase.expectedHTML)
        #expect(isEqual, "DOM mismatch:\n\(diff)")
    }

    // MARK: simonwillison-2 · Release: llm-echo 0.4 (simonwillison.net)

    @Test("simonwillison-2 - Title matches expected")
    func testSimonwillison2Title() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "simonwillison-2", in: "ex-pages") else {
            Issue.record("Failed to load test case 'simonwillison-2'")
            return
        }
        let result = try parse(testCase)
        #expect(result.title == testCase.expectedMetadata.title)
    }

    @Test("simonwillison-2 - Byline matches expected")
    func testSimonwillison2Byline() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "simonwillison-2", in: "ex-pages") else {
            Issue.record("Failed to load test case 'simonwillison-2'")
            return
        }
        let result = try parse(testCase)
        #expect(result.byline == testCase.expectedMetadata.byline)
    }

    @Test("simonwillison-2 - Excerpt matches expected")
    func testSimonwillison2Excerpt() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "simonwillison-2", in: "ex-pages") else {
            Issue.record("Failed to load test case 'simonwillison-2'")
            return
        }
        let result = try parse(testCase)
        #expect(result.excerpt == testCase.expectedMetadata.excerpt)
    }

    @Test("simonwillison-2 - Content matches expected HTML")
    func testSimonwillison2Content() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "simonwillison-2", in: "ex-pages") else {
            Issue.record("Failed to load test case 'simonwillison-2'")
            return
        }
        let result = try parse(testCase)
        let (isEqual, diff) = DOMComparator.compare(result.content, testCase.expectedHTML)
        #expect(isEqual, "DOM mismatch:\n\(diff)")
    }

    // MARK: simonwillison-3 · Release: llm 0.30 (simonwillison.net)

    @Test("simonwillison-3 - Title matches expected")
    func testSimonwillison3Title() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "simonwillison-3", in: "ex-pages") else {
            Issue.record("Failed to load test case 'simonwillison-3'")
            return
        }
        let result = try parse(testCase)
        #expect(result.title == testCase.expectedMetadata.title)
    }

    @Test("simonwillison-3 - Byline matches expected")
    func testSimonwillison3Byline() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "simonwillison-3", in: "ex-pages") else {
            Issue.record("Failed to load test case 'simonwillison-3'")
            return
        }
        let result = try parse(testCase)
        #expect(result.byline == testCase.expectedMetadata.byline)
    }

    @Test("simonwillison-3 - Excerpt matches expected")
    func testSimonwillison3Excerpt() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "simonwillison-3", in: "ex-pages") else {
            Issue.record("Failed to load test case 'simonwillison-3'")
            return
        }
        let result = try parse(testCase)
        #expect(result.excerpt == testCase.expectedMetadata.excerpt)
    }

    @Test("simonwillison-3 - Content matches expected HTML")
    func testSimonwillison3Content() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "simonwillison-3", in: "ex-pages") else {
            Issue.record("Failed to load test case 'simonwillison-3'")
            return
        }
        let result = try parse(testCase)
        let (isEqual, diff) = DOMComparator.compare(result.content, testCase.expectedHTML)
        #expect(isEqual, "DOM mismatch:\n\(diff)")
    }
}
