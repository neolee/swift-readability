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
        try assertContentAndMetadataMatch("wikipedia")
    }

    @Test("realworld/medium-1 - content and metadata match")
    func testMedium1() async throws {
        try assertContentAndMetadataMatch("medium-1")
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

    // Stage 3-R Batch 2 (baseline import)
    @Test("realworld/bbc-1 - content and metadata match")
    func testBBC1() async throws {
        try assertContentAndMetadataMatch("bbc-1")
    }

    @Test("realworld/guardian-1 - content and metadata match")
    func testGuardian1() async throws {
        try assertContentAndMetadataMatch("guardian-1")
    }

    @Test("realworld/telegraph - content and metadata match")
    func testTelegraph() async throws {
        try assertContentAndMetadataMatch("telegraph")
    }

    @Test("realworld/seattletimes-1 - content and metadata match")
    func testSeattleTimes1() async throws {
        try assertContentAndMetadataMatch("seattletimes-1")
    }

    @Test("realworld/nytimes-2 - content and metadata match")
    func testNYTimes2() async throws {
        try assertContentAndMetadataMatch("nytimes-2")
    }

    @Test("realworld/nytimes-3 - content and metadata match")
    func testNYTimes3() async throws {
        try assertContentAndMetadataMatch("nytimes-3")
    }

    @Test("realworld/nytimes-4 - content and metadata match")
    func testNYTimes4() async throws {
        try assertContentAndMetadataMatch("nytimes-4")
    }

    @Test("realworld/nytimes-5 - content and metadata match")
    func testNYTimes5() async throws {
        try assertContentAndMetadataMatch("nytimes-5")
    }

    @Test("realworld/wapo-2 - content and metadata match")
    func testWaPo2() async throws {
        try assertContentAndMetadataMatch("wapo-2")
    }

    @Test("realworld/yahoo-1 - content and metadata match")
    func testYahoo1() async throws {
        try assertContentAndMetadataMatch("yahoo-1")
    }

    @Test("realworld/yahoo-2 - content and metadata match")
    func testYahoo2() async throws {
        try assertContentAndMetadataMatch("yahoo-2")
    }

    // Stage 3-R Batch 3 (baseline import)
    @Test("realworld/cnet - content and metadata match")
    func testCNET() async throws {
        try assertContentAndMetadataMatch("cnet")
    }

    @Test("realworld/cnet-svg-classes - content and metadata match")
    func testCNETSVGClasses() async throws {
        try assertContentAndMetadataMatch("cnet-svg-classes")
    }

    @Test("realworld/engadget - content and metadata match")
    func testEngadget() async throws {
        try assertContentAndMetadataMatch("engadget")
    }

    @Test("realworld/theverge - content and metadata match")
    func testTheVerge() async throws {
        try assertContentAndMetadataMatch("theverge")
    }

    @Test("realworld/buzzfeed-1 - content and metadata match")
    func testBuzzFeed1() async throws {
        try assertContentAndMetadataMatch("buzzfeed-1")
    }

    @Test("realworld/citylab-1 - content and metadata match")
    func testCityLab1() async throws {
        try assertContentAndMetadataMatch("citylab-1")
    }

    @Test("realworld/tmz-1 - content and metadata match")
    func testTMZ1() async throws {
        try assertContentAndMetadataMatch("tmz-1")
    }

    @Test("realworld/medicalnewstoday - content and metadata match")
    func testMedicalNewsToday() async throws {
        try assertContentAndMetadataMatch("medicalnewstoday")
    }

    @Test("realworld/msn - content and metadata match")
    func testMSN() async throws {
        try assertContentAndMetadataMatch("msn")
    }

    @Test("realworld/salon-1 - content and metadata match")
    func testSalon1() async throws {
        try assertContentAndMetadataMatch("salon-1")
    }

    // Stage 3-R Batch 4 (baseline import)
    @Test("realworld/ars-1 - content and metadata match")
    func testArs1() async throws {
        try assertContentAndMetadataMatch("ars-1")
    }

}
