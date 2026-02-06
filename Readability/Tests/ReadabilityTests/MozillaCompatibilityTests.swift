import Testing
import Foundation
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

    private let testBaseURL = URL(string: "http://fakehost/test/index.html")!

    private enum TestCaseField {
        case title
        case byline
        case excerpt
        case siteName
        case publishedTime
    }

    private struct MissingTestCaseError: Error {
        let name: String
    }

    private func requireTestCase(named name: String) throws -> TestLoader.TestCase {
        guard let testCase = TestLoader.loadTestCase(named: name) else {
            Issue.record("Failed to load test case \(name)")
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

    private func assertContentMatches(_ testCaseName: String) throws {
        let (testCase, result) = try parseResult(for: testCaseName)
        let comparison = DOMComparator.compare(result.content, testCase.expectedHTML)
        #expect(comparison.isEqual, "Content mismatch: \(comparison.diff)")
    }

    private func assertMetadataFieldMatches(_ field: TestCaseField, for testCaseName: String) throws {
        let (testCase, result) = try parseResult(for: testCaseName)

        switch field {
        case .title:
            let expected = testCase.expectedMetadata.title ?? ""
            #expect(result.title == expected, "Title mismatch. Expected: '\(expected)', Actual: '\(result.title)'")
        case .byline:
            let expected = testCase.expectedMetadata.byline
            #expect(result.byline == expected, "Byline mismatch. Expected: '\(expected ?? "nil")', Actual: '\(result.byline ?? "nil")'")
        case .excerpt:
            let expected = testCase.expectedMetadata.excerpt
            #expect(result.excerpt == expected, "Excerpt mismatch. Expected: '\(expected ?? "nil")', Actual: '\(result.excerpt ?? "nil")'")
        case .siteName:
            let expected = testCase.expectedMetadata.siteName
            #expect(result.siteName == expected, "Site name mismatch. Expected: '\(expected ?? "nil")', Actual: '\(result.siteName ?? "nil")'")
        case .publishedTime:
            let expected = testCase.expectedMetadata.publishedTime
            #expect(result.publishedTime == expected, "Published time mismatch. Expected: '\(expected ?? "nil")', Actual: '\(result.publishedTime ?? "nil")'")
        }
    }

    // MARK: - 001 Test Case

    @Test("001 - Content extraction produces expected text")
    func test001Content() async throws { try assertContentMatches("001") }

    @Test("001 - Title matches expected exactly")
    func test001Title() async throws { try assertMetadataFieldMatches(.title, for: "001") }

    @Test("001 - Byline matches expected")
    func test001Byline() async throws { try assertMetadataFieldMatches(.byline, for: "001") }

    @Test("001 - Excerpt matches expected")
    func test001Excerpt() async throws { try assertMetadataFieldMatches(.excerpt, for: "001") }

    // MARK: - 002 Test Case

    @Test("002 - Title matches expected")
    func test002Title() async throws { try assertMetadataFieldMatches(.title, for: "002") }

    @Test("002 - Byline matches expected")
    func test002Byline() async throws { try assertMetadataFieldMatches(.byline, for: "002") }

    @Test("002 - Content extraction produces expected text")
    func test002Content() async throws { try assertContentMatches("002") }

    @Test("002 - Site name matches expected")
    func test002SiteName() async throws { try assertMetadataFieldMatches(.siteName, for: "002") }

    // MARK: - Phase 6.2: Content Post-Processing Tests

    @Test("remove-extra-brs - Content matches expected")
    func testRemoveExtraBrs() async throws { try assertContentMatches("remove-extra-brs") }

    @Test("remove-extra-paragraphs - Content matches expected")
    func testRemoveExtraParagraphs() async throws { try assertContentMatches("remove-extra-paragraphs") }

    @Test("reordering-paragraphs - Content matches expected")
    func testReorderingParagraphs() async throws { try assertContentMatches("reordering-paragraphs") }

    @Test("missing-paragraphs - Content matches expected")
    func testMissingParagraphs() async throws { try assertContentMatches("missing-paragraphs") }

    @Test("ol - Content matches expected")
    func testOl() async throws { try assertContentMatches("ol") }

    // MARK: - Basic Tags Cleaning Tests

    @Test("basic-tags-cleaning - Content matches expected")
    func testBasicTagsCleaning() async throws { try assertContentMatches("basic-tags-cleaning") }

    @Test("basic-tags-cleaning - Title matches expected")
    func testBasicTagsCleaningTitle() async throws { try assertMetadataFieldMatches(.title, for: "basic-tags-cleaning") }

    // MARK: - Remove Script Tags Tests

    @Test("remove-script-tags - Content matches expected")
    func testRemoveScriptTags() async throws { try assertContentMatches("remove-script-tags") }

    @Test("remove-script-tags - Title matches expected")
    func testRemoveScriptTagsTitle() async throws { try assertMetadataFieldMatches(.title, for: "remove-script-tags") }

    // MARK: - Replace BRs Tests

    @Test("replace-brs - Content matches expected")
    func testReplaceBrs() async throws { try assertContentMatches("replace-brs") }

    @Test("replace-brs - Title matches expected")
    func testReplaceBrsTitle() async throws { try assertMetadataFieldMatches(.title, for: "replace-brs") }

    // MARK: - Phase 2: Document Preprocessing Tests

    @Test("replace-font-tags - Content matches expected")
    func testReplaceFontTags() async throws { try assertContentMatches("replace-font-tags") }

    @Test("replace-font-tags - Title matches expected")
    func testReplaceFontTagsTitle() async throws { try assertMetadataFieldMatches(.title, for: "replace-font-tags") }

    @Test("remove-aria-hidden - Content matches expected")
    func testRemoveAriaHidden() async throws { try assertContentMatches("remove-aria-hidden") }

    @Test("remove-aria-hidden - Title matches expected")
    func testRemoveAriaHiddenTitle() async throws { try assertMetadataFieldMatches(.title, for: "remove-aria-hidden") }

    @Test("style-tags-removal - Content matches expected")
    func testStyleTagsRemoval() async throws { try assertContentMatches("style-tags-removal") }

    @Test("style-tags-removal - Title matches expected")
    func testStyleTagsRemovalTitle() async throws { try assertMetadataFieldMatches(.title, for: "style-tags-removal") }

    @Test("normalize-spaces - Content matches expected")
    func testNormalizeSpaces() async throws { try assertContentMatches("normalize-spaces") }

    @Test("normalize-spaces - Title matches expected")
    func testNormalizeSpacesTitle() async throws { try assertMetadataFieldMatches(.title, for: "normalize-spaces") }

    // MARK: - Phase 3: Metadata Extraction Tests

    @Test("parsely-metadata - Title matches expected")
    func testParselyMetadataTitle() async throws { try assertMetadataFieldMatches(.title, for: "parsely-metadata") }

    @Test("parsely-metadata - Byline matches expected")
    func testParselyMetadataByline() async throws { try assertMetadataFieldMatches(.byline, for: "parsely-metadata") }

    @Test("parsely-metadata - Published time matches expected")
    func testParselyMetadataPublishedTime() async throws { try assertMetadataFieldMatches(.publishedTime, for: "parsely-metadata") }

    @Test("schema-org-context-object - Title matches expected")
    func testSchemaOrgContextObjectTitle() async throws { try assertMetadataFieldMatches(.title, for: "schema-org-context-object") }

    @Test("schema-org-context-object - Byline matches expected")
    func testSchemaOrgContextObjectByline() async throws { try assertMetadataFieldMatches(.byline, for: "schema-org-context-object") }

    @Test("schema-org-context-object - Excerpt matches expected")
    func testSchemaOrgContextObjectExcerpt() async throws { try assertMetadataFieldMatches(.excerpt, for: "schema-org-context-object") }

    @Test("schema-org-context-object - Published time matches expected")
    func testSchemaOrgContextObjectPublishedTime() async throws { try assertMetadataFieldMatches(.publishedTime, for: "schema-org-context-object") }

    @Test("schema-org-context-object - Site name matches expected")
    func testSchemaOrgContextObjectSiteName() async throws { try assertMetadataFieldMatches(.siteName, for: "schema-org-context-object") }

    @Test("003-metadata-preferred - Title matches expected")
    func test003MetadataPreferredTitle() async throws { try assertMetadataFieldMatches(.title, for: "003-metadata-preferred") }

    @Test("003-metadata-preferred - Byline matches expected")
    func test003MetadataPreferredByline() async throws { try assertMetadataFieldMatches(.byline, for: "003-metadata-preferred") }

    @Test("004-metadata-space-separated-properties - Title matches expected")
    func test004MetadataSpaceSeparatedTitle() async throws { try assertMetadataFieldMatches(.title, for: "004-metadata-space-separated-properties") }

    // MARK: - Phase 4: Core Scoring Tests

    @Test("title-en-dash - Title matches expected")
    func testTitleEnDash() async throws { try assertMetadataFieldMatches(.title, for: "title-en-dash") }

    @Test("title-and-h1-discrepancy - Title matches expected")
    func testTitleAndH1Discrepancy() async throws { try assertMetadataFieldMatches(.title, for: "title-and-h1-discrepancy") }

    @Test("keep-images - Title matches expected")
    func testKeepImagesTitle() async throws { try assertMetadataFieldMatches(.title, for: "keep-images") }

    @Test("keep-images - Byline matches expected")
    func testKeepImagesByline() async throws { try assertMetadataFieldMatches(.byline, for: "keep-images") }

    @Test("keep-images - Published time matches expected")
    func testKeepImagesPublishedTime() async throws { try assertMetadataFieldMatches(.publishedTime, for: "keep-images") }

    @Test("keep-images - Site name matches expected")
    func testKeepImagesSiteName() async throws { try assertMetadataFieldMatches(.siteName, for: "keep-images") }

    @Test("keep-tabular-data - Title matches expected")
    func testKeepTabularDataTitle() async throws { try assertMetadataFieldMatches(.title, for: "keep-tabular-data") }

    @Test("keep-tabular-data - Site name matches expected")
    func testKeepTabularDataSiteName() async throws { try assertMetadataFieldMatches(.siteName, for: "keep-tabular-data") }

    // MARK: - Phase 6.3: Conditional Cleaning Tests

    @Test("clean-links - Content matches expected")
    func testCleanLinks() async throws { try assertContentMatches("clean-links") }

    @Test("links-in-tables - Content matches expected")
    func testLinksInTables() async throws { try assertContentMatches("links-in-tables") }

    @Test("social-buttons - Content matches expected")
    func testSocialButtons() async throws { try assertContentMatches("social-buttons") }

    @Test("article-author-tag - Content matches expected")
    func testArticleAuthorTag() async throws { try assertContentMatches("article-author-tag") }

    @Test("article-author-tag - Byline matches expected")
    func testArticleAuthorTagByline() async throws { try assertMetadataFieldMatches(.byline, for: "article-author-tag") }

    @Test("article-author-tag - Published time matches expected")
    func testArticleAuthorTagPublishedTime() async throws { try assertMetadataFieldMatches(.publishedTime, for: "article-author-tag") }

    @Test("article-author-tag - Site name matches expected")
    func testArticleAuthorTagSiteName() async throws { try assertMetadataFieldMatches(.siteName, for: "article-author-tag") }

    @Test("table-style-attributes - Content matches expected")
    func testTableStyleAttributes() async throws { try assertContentMatches("table-style-attributes") }

    @Test("invalid-attributes - Content matches expected")
    func testInvalidAttributes() async throws { try assertContentMatches("invalid-attributes") }

    // MARK: - Phase 6.4: Hidden Node & Visibility Handling

    @Test("hidden-nodes - Content matches expected")
    func testHiddenNodes() async throws { try assertContentMatches("hidden-nodes") }

    @Test("hidden-nodes - Title matches expected")
    func testHiddenNodesTitle() async throws { try assertMetadataFieldMatches(.title, for: "hidden-nodes") }

    @Test("visibility-hidden - Content matches expected")
    func testVisibilityHidden() async throws { try assertContentMatches("visibility-hidden") }
}
