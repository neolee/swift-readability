import Foundation
import Testing
@testable import Readability

/// Stage 3-R baseline compatibility tests for real-world Mozilla pages.
@Suite("Real-world Compatibility Tests")
struct RealWorldCompatibilityTests {
    private let defaultOptions = ReadabilityOptions(
        charThreshold: 500,
        classesToPreserve: ["caption"]
    )

    private let testBaseURL = URL(string: "http://fakehost/test/index.html")!

    private struct MissingTestCaseError: Error {
        let name: String
    }

    private func requireTestCase(named name: String) throws -> TestLoader.TestCase {
        guard let testCase = TestLoader.loadRealWorldTestCase(named: name) else {
            Issue.record("Failed to load real-world test case \(name)")
            throw MissingTestCaseError(name: name)
        }
        return testCase
    }

    private func parseResult(for testCaseName: String) throws -> (testCase: TestLoader.TestCase, result: ReadabilityResult) {
        let testCase = try requireTestCase(named: testCaseName)
        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
        let result = try readability.parse()
        return (testCase, result)
    }

    private func assertContentAndMetadataMatch(_ testCaseName: String) throws {
        let (testCase, result) = try parseResult(for: testCaseName)
        let comparison = DOMComparator.compare(result.content, testCase.expectedHTML)
        #expect(comparison.isEqual, "Content mismatch: \(comparison.diff)")

        #expect(result.title == (testCase.expectedMetadata.title ?? ""), "Title mismatch")
        #expect(result.byline == testCase.expectedMetadata.byline, "Byline mismatch")
        #expect(result.excerpt == testCase.expectedMetadata.excerpt, "Excerpt mismatch")
        #expect(result.siteName == testCase.expectedMetadata.siteName, "Site name mismatch")

        if let expectedDir = testCase.expectedMetadata.dir {
            #expect(result.dir == expectedDir, "Direction mismatch")
        }

        if let expectedLang = testCase.expectedMetadata.lang {
            #expect(result.lang == expectedLang, "Language mismatch")
        }

        if let expectedPublishedTime = testCase.expectedMetadata.publishedTime {
            #expect(result.publishedTime == expectedPublishedTime, "Published time mismatch")
        }
    }

    // Stage 3-R Batch 1 (initial baseline)
    @Test("realworld/wikipedia - content and metadata match")
    func testWikipedia() async throws {
        withKnownIssue("S3R Batch 1 baseline [RW-C4, RW-C5]: structural TOC/excerpt mismatch against Mozilla expected output.") {
            try assertContentAndMetadataMatch("wikipedia")
        }
    }

    @Test("realworld/medium-1 - content and metadata match")
    func testMedium1() async throws {
        withKnownIssue("S3R Batch 1 baseline [RW-C3]: figure/caption structural mismatch against Mozilla expected output.") {
            try assertContentAndMetadataMatch("medium-1")
        }
    }

    @Test("realworld/nytimes-1 - content and metadata match")
    func testNYTimes1() async throws {
        try assertContentAndMetadataMatch("nytimes-1")
    }

    @Test("realworld/cnn - content and metadata match")
    func testCNN() async throws {
        try assertContentAndMetadataMatch("cnn")
    }

    @Test("realworld/wapo-1 - content and metadata match")
    func testWaPo1() async throws {
        try assertContentAndMetadataMatch("wapo-1")
    }
}
