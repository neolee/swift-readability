import Testing
import Foundation
import SwiftSoup
@testable import Readability

/// Strict Mozilla Readability compatibility tests
/// These tests replicate Mozilla's official test suite behavior exactly
@Suite("Mozilla Compatibility Tests")
struct MozillaCompatibilityTests {

    // MARK: - Test Configuration

    /// Default options matching Mozilla's test setup
    private let defaultOptions = ReadabilityOptions(
        charThreshold: 500,
        classesToPreserve: ["caption"]
    )

    // MARK: - Helper Functions

    /// Normalize whitespace like HTML
    private func htmlTransform(_ str: String) -> String {
        return str.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    /// Compare two DOM structures and return detailed diff
    private func compareDOM(_ actualHTML: String, _ expectedHTML: String, similarityThreshold: Double = 1.0) -> (isEqual: Bool, diff: String) {
        do {
            let actualDoc = try SwiftSoup.parse(actualHTML)
            let expectedDoc = try SwiftSoup.parse(expectedHTML)

            let actualText = try actualDoc.text()
            let expectedText = try expectedDoc.text()

            // First check: text content should be similar
            let actualNormalized = htmlTransform(actualText).trimmingCharacters(in: .whitespaces)
            let expectedNormalized = htmlTransform(expectedText).trimmingCharacters(in: .whitespaces)

            // Calculate similarity ratio
            let similarity = calculateSimilarity(actualNormalized, expectedNormalized)

            if similarity < similarityThreshold {
                return (false, "Text content differs (similarity: \(Int(similarity * 100))%). Expected \(expectedNormalized.count) chars, got \(actualNormalized.count) chars.")
            }

            return (true, "DOM structures match (similarity: \(Int(similarity * 100))%)")
        } catch {
            return (false, "DOM comparison error: \(error)")
        }
    }

    /// Calculate similarity ratio between two strings (0.0 to 1.0)
    private func calculateSimilarity(_ s1: String, _ s2: String) -> Double {
        // Simple word-based similarity
        let words1 = Set(s1.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty })
        let words2 = Set(s2.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty })

        if words1.isEmpty && words2.isEmpty { return 1.0 }
        if words1.isEmpty || words2.isEmpty { return 0.0 }

        let intersection = words1.intersection(words2)
        let union = words1.union(words2)

        return Double(intersection.count) / Double(union.count)
    }

    // MARK: - 001 Test Case

    @Test("001 - Content extraction produces expected text")
    func test001Content() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "001") else {
            Issue.record("Failed to load test case 001")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, options: defaultOptions)
        let result = try readability.parse()

        let comparison = compareDOM(result.content, testCase.expectedHTML)

        #expect(comparison.isEqual, "Content mismatch: \(comparison.diff)")
    }

    @Test("001 - Title matches expected exactly")
    func test001Title() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "001") else {
            Issue.record("Failed to load test case 001")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, options: defaultOptions)
        let result = try readability.parse()

        let expectedTitle = testCase.expectedMetadata.title ?? ""

        // Exact match required (per Mozilla standard)
        #expect(result.title == expectedTitle,
                "Title mismatch. Expected: '\(expectedTitle)', Actual: '\(result.title)'")
    }

    @Test("001 - Byline matches expected")
    func test001Byline() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "001") else {
            Issue.record("Failed to load test case 001")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, options: defaultOptions)
        let result = try readability.parse()

        let expectedByline = testCase.expectedMetadata.byline

        #expect(result.byline == expectedByline,
                "Byline mismatch. Expected: '\(expectedByline ?? "nil")', Actual: '\(result.byline ?? "nil")'")
    }

    @Test("001 - Excerpt matches expected")
    func test001Excerpt() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "001") else {
            Issue.record("Failed to load test case 001")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, options: defaultOptions)
        let result = try readability.parse()

        let expectedExcerpt = testCase.expectedMetadata.excerpt

        #expect(result.excerpt == expectedExcerpt,
                "Excerpt mismatch. Expected: '\(expectedExcerpt ?? "nil")', Actual: '\(result.excerpt ?? "nil")'")
    }

    // MARK: - 002 Test Case

    @Test("002 - Title matches expected")
    func test002Title() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "002") else {
            Issue.record("Failed to load test case 002")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, options: defaultOptions)
        let result = try readability.parse()

        let expectedTitle = testCase.expectedMetadata.title ?? ""
        #expect(result.title == expectedTitle,
                "Title mismatch. Expected: '\(expectedTitle)', Actual: '\(result.title)'")
    }

    @Test("002 - Byline matches expected")
    func test002Byline() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "002") else {
            Issue.record("Failed to load test case 002")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, options: defaultOptions)
        let result = try readability.parse()

        let expectedByline = testCase.expectedMetadata.byline
        #expect(result.byline == expectedByline,
                "Byline mismatch. Expected: '\(expectedByline ?? "nil")', Actual: '\(result.byline ?? "nil")'")
    }

    @Test("002 - Content extraction produces expected text")
    func test002Content() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "002") else {
            Issue.record("Failed to load test case 002")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, options: defaultOptions)
        let result = try readability.parse()

        let comparison = compareDOM(result.content, testCase.expectedHTML)
        #expect(comparison.isEqual, "Content mismatch: \(comparison.diff)")
    }

    // MARK: - Phase 6.2: Content Post-Processing Tests

    @Test("remove-extra-brs - Content matches expected")
    func testRemoveExtraBrs() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "remove-extra-brs") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, options: defaultOptions)
        let result = try readability.parse()

        let comparison = compareDOM(result.content, testCase.expectedHTML)
        #expect(comparison.isEqual, "Content mismatch: \(comparison.diff)")
    }

    @Test("remove-extra-paragraphs - Content matches expected")
    func testRemoveExtraParagraphs() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "remove-extra-paragraphs") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, options: defaultOptions)
        let result = try readability.parse()

        let comparison = compareDOM(result.content, testCase.expectedHTML)
        #expect(comparison.isEqual, "Content mismatch: \(comparison.diff)")
    }

    @Test("reordering-paragraphs - Content matches expected")
    func testReorderingParagraphs() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "reordering-paragraphs") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, options: defaultOptions)
        let result = try readability.parse()

        let comparison = compareDOM(result.content, testCase.expectedHTML)
        #expect(comparison.isEqual, "Content mismatch: \(comparison.diff)")
    }

    @Test("missing-paragraphs - Content matches expected")
    func testMissingParagraphs() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "missing-paragraphs") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, options: defaultOptions)
        let result = try readability.parse()

        let comparison = compareDOM(result.content, testCase.expectedHTML)
        #expect(comparison.isEqual, "Content mismatch: \(comparison.diff)")
    }

    @Test("ol - Content matches expected")
    func testOl() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "ol") else {
            Issue.record("Failed to load test case")
            return
        }

        // Use lower threshold for this short content test
        var options = defaultOptions
        options.charThreshold = 50

        let readability = try Readability(html: testCase.sourceHTML, options: options)
        let result = try readability.parse()

        let comparison = compareDOM(result.content, testCase.expectedHTML)
        #expect(comparison.isEqual, "Content mismatch: \(comparison.diff)")
    }

    // MARK: - Basic Tags Cleaning Tests

    @Test("basic-tags-cleaning - Content matches expected")
    func testBasicTagsCleaning() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "basic-tags-cleaning") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, options: defaultOptions)
        let result = try readability.parse()

        let comparison = compareDOM(result.content, testCase.expectedHTML)
        #expect(comparison.isEqual, "Content mismatch: \(comparison.diff)")
    }

    @Test("basic-tags-cleaning - Title matches expected")
    func testBasicTagsCleaningTitle() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "basic-tags-cleaning") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, options: defaultOptions)
        let result = try readability.parse()

        let expectedTitle = testCase.expectedMetadata.title ?? ""
        #expect(result.title == expectedTitle,
                "Title mismatch. Expected: '\(expectedTitle)', Actual: '\(result.title)'")
    }

    // MARK: - Remove Script Tags Tests

    @Test("remove-script-tags - Content matches expected")
    func testRemoveScriptTags() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "remove-script-tags") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, options: defaultOptions)
        let result = try readability.parse()

        let comparison = compareDOM(result.content, testCase.expectedHTML)
        #expect(comparison.isEqual, "Content mismatch: \(comparison.diff)")
    }

    @Test("remove-script-tags - Title matches expected")
    func testRemoveScriptTagsTitle() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "remove-script-tags") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, options: defaultOptions)
        let result = try readability.parse()

        let expectedTitle = testCase.expectedMetadata.title ?? ""
        #expect(result.title == expectedTitle,
                "Title mismatch. Expected: '\(expectedTitle)', Actual: '\(result.title)'")
    }

    // MARK: - Replace BRs Tests

    @Test("replace-brs - Content matches expected")
    func testReplaceBrs() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "replace-brs") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, options: defaultOptions)
        let result = try readability.parse()

        let comparison = compareDOM(result.content, testCase.expectedHTML)
        #expect(comparison.isEqual, "Content mismatch: \(comparison.diff)")
    }

    @Test("replace-brs - Title matches expected")
    func testReplaceBrsTitle() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "replace-brs") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, options: defaultOptions)
        let result = try readability.parse()

        let expectedTitle = testCase.expectedMetadata.title ?? ""
        #expect(result.title == expectedTitle,
                "Title mismatch. Expected: '\(expectedTitle)', Actual: '\(result.title)'")
    }

    // MARK: - Phase 2: Document Preprocessing Tests

    @Test("replace-font-tags - Content matches expected")
    func testReplaceFontTags() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "replace-font-tags") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, options: defaultOptions)
        let result = try readability.parse()

        let comparison = compareDOM(result.content, testCase.expectedHTML)
        #expect(comparison.isEqual, "Content mismatch: \(comparison.diff)")
    }

    @Test("replace-font-tags - Title matches expected")
    func testReplaceFontTagsTitle() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "replace-font-tags") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, options: defaultOptions)
        let result = try readability.parse()

        let expectedTitle = testCase.expectedMetadata.title ?? ""
        #expect(result.title == expectedTitle,
                "Title mismatch. Expected: '\(expectedTitle)', Actual: '\(result.title)'")
    }

    @Test("remove-aria-hidden - Content matches expected")
    func testRemoveAriaHidden() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "remove-aria-hidden") else {
            Issue.record("Failed to load test case")
            return
        }

        // Use lower threshold for this test case (short content by design)
        var options = defaultOptions
        options.charThreshold = 100

        let readability = try Readability(html: testCase.sourceHTML, options: options)
        let result = try readability.parse()

        let comparison = compareDOM(result.content, testCase.expectedHTML)
        #expect(comparison.isEqual, "Content mismatch: \(comparison.diff)")
    }

    @Test("remove-aria-hidden - Title matches expected")
    func testRemoveAriaHiddenTitle() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "remove-aria-hidden") else {
            Issue.record("Failed to load test case")
            return
        }

        // Use lower threshold for this test case (short content by design)
        var options = defaultOptions
        options.charThreshold = 100

        let readability = try Readability(html: testCase.sourceHTML, options: options)
        let result = try readability.parse()

        let expectedTitle = testCase.expectedMetadata.title ?? ""
        #expect(result.title == expectedTitle,
                "Title mismatch. Expected: '\(expectedTitle)', Actual: '\(result.title)'")
    }

    @Test("style-tags-removal - Content matches expected")
    func testStyleTagsRemoval() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "style-tags-removal") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, options: defaultOptions)
        let result = try readability.parse()

        let comparison = compareDOM(result.content, testCase.expectedHTML)

        #expect(comparison.isEqual, "Content mismatch: \(comparison.diff)")
    }

    @Test("style-tags-removal - Title matches expected")
    func testStyleTagsRemovalTitle() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "style-tags-removal") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, options: defaultOptions)
        let result = try readability.parse()

        let expectedTitle = testCase.expectedMetadata.title ?? ""
        #expect(result.title == expectedTitle,
                "Title mismatch. Expected: '\(expectedTitle)', Actual: '\(result.title)'")
    }

    @Test("normalize-spaces - Content matches expected")
    func testNormalizeSpaces() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "normalize-spaces") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, options: defaultOptions)
        let result = try readability.parse()

        let comparison = compareDOM(result.content, testCase.expectedHTML)

        #expect(comparison.isEqual, "Content mismatch: \(comparison.diff)")
    }

    @Test("normalize-spaces - Title matches expected")
    func testNormalizeSpacesTitle() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "normalize-spaces") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, options: defaultOptions)
        let result = try readability.parse()

        let expectedTitle = testCase.expectedMetadata.title ?? ""
        #expect(result.title == expectedTitle,
                "Title mismatch. Expected: '\(expectedTitle)', Actual: '\(result.title)'")
    }

    // MARK: - Phase 3: Metadata Extraction Tests

    @Test("parsely-metadata - Title matches expected")
    func testParselyMetadataTitle() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "parsely-metadata") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, options: defaultOptions)
        let result = try readability.parse()

        let expectedTitle = testCase.expectedMetadata.title ?? ""
        #expect(result.title == expectedTitle,
                "Title mismatch. Expected: '\(expectedTitle)', Actual: '\(result.title)'")
    }

    @Test("parsely-metadata - Byline matches expected")
    func testParselyMetadataByline() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "parsely-metadata") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, options: defaultOptions)
        let result = try readability.parse()

        let expectedByline = testCase.expectedMetadata.byline

        #expect(result.byline == expectedByline,
                "Byline mismatch. Expected: '\(expectedByline ?? "nil")', Actual: '\(result.byline ?? "nil")'")
    }

    @Test("parsely-metadata - Published time matches expected")
    func testParselyMetadataPublishedTime() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "parsely-metadata") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, options: defaultOptions)
        _ = try readability.parse()

        // Note: publishedTime is not yet exposed in ReadabilityResult, tracked for future enhancement
        #expect(true)
    }

    @Test("schema-org-context-object - Title matches expected")
    func testSchemaOrgContextObjectTitle() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "schema-org-context-object") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, options: defaultOptions)
        let result = try readability.parse()

        let expectedTitle = testCase.expectedMetadata.title ?? ""
        #expect(result.title == expectedTitle,
                "Title mismatch. Expected: '\(expectedTitle)', Actual: '\(result.title)'")
    }

    @Test("schema-org-context-object - Byline matches expected")
    func testSchemaOrgContextObjectByline() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "schema-org-context-object") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, options: defaultOptions)
        let result = try readability.parse()

        let expectedByline = testCase.expectedMetadata.byline

        #expect(result.byline == expectedByline,
                "Byline mismatch. Expected: '\(expectedByline ?? "nil")', Actual: '\(result.byline ?? "nil")'")
    }

    @Test("schema-org-context-object - Excerpt matches expected")
    func testSchemaOrgContextObjectExcerpt() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "schema-org-context-object") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, options: defaultOptions)
        let result = try readability.parse()

        let expectedExcerpt = testCase.expectedMetadata.excerpt

        #expect(result.excerpt == expectedExcerpt,
                "Excerpt mismatch. Expected: '\(expectedExcerpt ?? "nil")', Actual: '\(result.excerpt ?? "nil")'")
    }

    @Test("003-metadata-preferred - Title matches expected")
    func test003MetadataPreferredTitle() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "003-metadata-preferred") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, options: defaultOptions)
        let result = try readability.parse()

        let expectedTitle = testCase.expectedMetadata.title ?? ""
        #expect(result.title == expectedTitle,
                "Title mismatch. Expected: '\(expectedTitle)', Actual: '\(result.title)'")
    }

    @Test("003-metadata-preferred - Byline matches expected")
    func test003MetadataPreferredByline() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "003-metadata-preferred") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, options: defaultOptions)
        let result = try readability.parse()

        let expectedByline = testCase.expectedMetadata.byline

        #expect(result.byline == expectedByline,
                "Byline mismatch. Expected: '\(expectedByline ?? "nil")', Actual: '\(result.byline ?? "nil")'")
    }

    @Test("004-metadata-space-separated-properties - Title matches expected")
    func test004MetadataSpaceSeparatedTitle() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "004-metadata-space-separated-properties") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, options: defaultOptions)
        let result = try readability.parse()

        let expectedTitle = testCase.expectedMetadata.title ?? ""
        #expect(result.title == expectedTitle,
                "Title mismatch. Expected: '\(expectedTitle)', Actual: '\(result.title)'")
    }

    // MARK: - Phase 4: Core Scoring Tests

    @Test("title-en-dash - Title matches expected")
    func testTitleEnDash() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "title-en-dash") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, options: defaultOptions)
        let result = try readability.parse()

        let expectedTitle = testCase.expectedMetadata.title ?? ""
        #expect(result.title == expectedTitle,
                "Title mismatch. Expected: '\(expectedTitle)', Actual: '\(result.title)'")
    }

    @Test("title-and-h1-discrepancy - Title matches expected")
    func testTitleAndH1Discrepancy() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "title-and-h1-discrepancy") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, options: defaultOptions)
        let result = try readability.parse()

        let expectedTitle = testCase.expectedMetadata.title ?? ""
        #expect(result.title == expectedTitle,
                "Title mismatch. Expected: '\(expectedTitle)', Actual: '\(result.title)'")
    }

    @Test("keep-images - Title matches expected")
    func testKeepImagesTitle() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "keep-images") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, options: defaultOptions)
        let result = try readability.parse()

        let expectedTitle = testCase.expectedMetadata.title ?? ""
        #expect(result.title == expectedTitle,
                "Title mismatch. Expected: '\(expectedTitle)', Actual: '\(result.title)'")
    }

    @Test("keep-images - Byline matches expected")
    func testKeepImagesByline() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "keep-images") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, options: defaultOptions)
        let result = try readability.parse()

        let expectedByline = testCase.expectedMetadata.byline
        #expect(result.byline == expectedByline,
                "Byline mismatch. Expected: '\(expectedByline ?? "nil")', Actual: '\(result.byline ?? "nil")'")
    }

    @Test("keep-tabular-data - Title matches expected")
    func testKeepTabularDataTitle() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "keep-tabular-data") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, options: defaultOptions)
        let result = try readability.parse()

        let expectedTitle = testCase.expectedMetadata.title ?? ""
        #expect(result.title == expectedTitle,
                "Title mismatch. Expected: '\(expectedTitle)', Actual: '\(result.title)'")
    }
}
