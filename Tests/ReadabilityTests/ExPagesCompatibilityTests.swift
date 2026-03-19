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

    // MARK: - Tests

    // MARK: 1a23-1 · Holpxay Calculator (1a23.com)

    @Test("1a23-1 - Title matches expected")
    func test1a231Title() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "1a23-1", in: "ex-pages") else {
            Issue.record("Failed to load test case '1a23-1'")
            return
        }
        let result = try Readability(html: testCase.sourceHTML, options: defaultOptions).parse()
        #expect(result.title == testCase.expectedMetadata.title)
    }

    @Test("1a23-1 - Byline matches expected")
    func test1a231Byline() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "1a23-1", in: "ex-pages") else {
            Issue.record("Failed to load test case '1a23-1'")
            return
        }
        let result = try Readability(html: testCase.sourceHTML, options: defaultOptions).parse()
        #expect(result.byline == testCase.expectedMetadata.byline)
    }

    @Test("1a23-1 - Content matches expected HTML")
    func test1a231Content() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "1a23-1", in: "ex-pages") else {
            Issue.record("Failed to load test case '1a23-1'")
            return
        }
        let result = try Readability(html: testCase.sourceHTML, options: defaultOptions).parse()
        let (isEqual, diff) = DOMComparator.compare(result.content, testCase.expectedHTML)
        #expect(isEqual, "DOM mismatch:\n\(diff)")
    }
}
