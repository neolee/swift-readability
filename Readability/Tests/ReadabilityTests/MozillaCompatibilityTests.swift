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

    private let testBaseURL = URL(string: "http://fakehost/test/index.html")!

    // MARK: - Helper Functions

    /// Normalize whitespace like HTML
    private func htmlTransform(_ str: String) -> String {
        return str.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    /// Compare two DOM structures and return detailed diff.
    /// Mirrors Mozilla-style structural traversal:
    /// - In-order node traversal
    /// - Ignore empty text nodes
    /// - Compare node descriptors, text content, and attributes
    private func compareDOM(_ actualHTML: String, _ expectedHTML: String) -> (isEqual: Bool, diff: String) {
        do {
            let actualDoc = try SwiftSoup.parse(actualHTML)
            let expectedDoc = try SwiftSoup.parse(expectedHTML)

            guard let actualRoot = domRoot(actualDoc),
                  let expectedRoot = domRoot(expectedDoc) else {
                return (false, "DOM comparison error: missing root node")
            }

            let actualNodes = flattenedDOMNodes(from: actualRoot)
            let expectedNodes = flattenedDOMNodes(from: expectedRoot)

            let maxCount = max(actualNodes.count, expectedNodes.count)
            for index in 0..<maxCount {
                guard index < actualNodes.count, index < expectedNodes.count else {
                    return (false, "DOM node count mismatch at index \(index). Expected \(expectedNodes.count) nodes, got \(actualNodes.count) nodes.")
                }

                let actualNode = actualNodes[index]
                let expectedNode = expectedNodes[index]

                let actualDesc = nodeDescription(actualNode)
                let expectedDesc = nodeDescription(expectedNode)
                if actualDesc != expectedDesc {
                    return (
                        false,
                        "Node descriptor mismatch at index \(index). Expected: \(expectedDesc), Actual: \(actualDesc)."
                    )
                }

                if let actualTextNode = actualNode as? TextNode,
                   let expectedTextNode = expectedNode as? TextNode {
                    let actualText = htmlTransform(actualTextNode.text())
                    let expectedText = htmlTransform(expectedTextNode.text())
                    if actualText != expectedText {
                        return (
                            false,
                            "Text mismatch at index \(index). Expected: '\(preview(expectedText))', Actual: '\(preview(actualText))'."
                        )
                    }
                } else if let actualElement = actualNode as? Element,
                          let expectedElement = expectedNode as? Element {
                    let actualAttrs = attributesForNode(actualElement)
                    let expectedAttrs = attributesForNode(expectedElement)
                    if actualAttrs.count != expectedAttrs.count {
                        return (
                            false,
                            "Attribute count mismatch at index \(index) for \(actualElement.tagName().lowercased()). Expected \(expectedAttrs.count), got \(actualAttrs.count)."
                        )
                    }
                    for (key, expectedValue) in expectedAttrs {
                        guard let actualValue = actualAttrs[key] else {
                            return (
                                false,
                                "Missing attribute at index \(index): '\(key)' on \(actualElement.tagName().lowercased())."
                            )
                        }
                        if actualValue != expectedValue {
                            return (
                                false,
                                "Attribute mismatch at index \(index): '\(key)'. Expected '\(preview(expectedValue))', got '\(preview(actualValue))'."
                            )
                        }
                    }
                }
            }

            return (true, "DOM structures match")
        } catch {
            return (false, "DOM comparison error: \(error)")
        }
    }

    private func domRoot(_ doc: Document) -> Node? {
        if let root = doc.children().first {
            return root
        }
        if let body = doc.body() {
            return body
        }
        return nil
    }

    private func flattenedDOMNodes(from root: Node) -> [Node] {
        var nodes: [Node] = []
        collectNodesInOrder(root, into: &nodes)
        return nodes.filter { !isIgnorableTextNode($0) }
    }

    private func collectNodesInOrder(_ node: Node, into nodes: inout [Node]) {
        nodes.append(node)
        for child in node.getChildNodes() {
            collectNodesInOrder(child, into: &nodes)
        }
    }

    private func isIgnorableTextNode(_ node: Node) -> Bool {
        guard let textNode = node as? TextNode else { return false }
        return textNode.text().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func nodeDescription(_ node: Node) -> String {
        if let textNode = node as? TextNode {
            return "#text(\(htmlTransform(textNode.text())))"
        }
        if let element = node as? Element {
            var desc = element.tagName().lowercased()
            let id = element.id()
            if !id.isEmpty {
                desc += "#\(id)"
            }
            if let className = try? element.className(), !className.isEmpty {
                desc += ".(\(className))"
            }
            return desc
        }
        return "node(\(node.nodeName()))"
    }

    private func attributesForNode(_ element: Element) -> [String: String] {
        var attrs: [String: String] = [:]
        guard let attributes = element.getAttributes() else { return attrs }

        for attr in attributes {
            let key = attr.getKey()
            if isValidXMLAttributeName(key) {
                attrs[key] = attr.getValue()
            }
        }
        return attrs
    }

    private func isValidXMLAttributeName(_ name: String) -> Bool {
        let pattern = "^[A-Za-z_][A-Za-z0-9._:-]*$"
        return name.range(of: pattern, options: .regularExpression) != nil
    }

    private func preview(_ text: String, limit: Int = 80) -> String {
        if text.count <= limit { return text }
        return String(text.prefix(limit)) + "..."
    }

    // MARK: - 001 Test Case

    @Test("001 - Content extraction produces expected text")
    func test001Content() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "001") else {
            Issue.record("Failed to load test case 001")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
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

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
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

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
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

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
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

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
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

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
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

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
        let result = try readability.parse()

        let comparison = compareDOM(result.content, testCase.expectedHTML)
        #expect(comparison.isEqual, "Content mismatch: \(comparison.diff)")
    }

    @Test("002 - Site name matches expected")
    func test002SiteName() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "002") else {
            Issue.record("Failed to load test case 002")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
        let result = try readability.parse()

        let expectedSiteName = testCase.expectedMetadata.siteName
        #expect(result.siteName == expectedSiteName,
                "Site name mismatch. Expected: '\(expectedSiteName ?? "nil")', Actual: '\(result.siteName ?? "nil")'")
    }

    // MARK: - Phase 6.2: Content Post-Processing Tests

    @Test("remove-extra-brs - Content matches expected")
    func testRemoveExtraBrs() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "remove-extra-brs") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
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

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
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

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
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

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
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

        // Test with default charThreshold to verify retry logic works
        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
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

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
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

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
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

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
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

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
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

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
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

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
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

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
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

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
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

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
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

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
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

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
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

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
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

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
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

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
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

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
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

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
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

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
        let result = try readability.parse()

        let expectedPublishedTime = testCase.expectedMetadata.publishedTime
        #expect(result.publishedTime == expectedPublishedTime,
                "Published time mismatch. Expected: '\(expectedPublishedTime ?? "nil")', Actual: '\(result.publishedTime ?? "nil")'")
    }

    @Test("schema-org-context-object - Title matches expected")
    func testSchemaOrgContextObjectTitle() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "schema-org-context-object") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
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

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
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

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
        let result = try readability.parse()

        let expectedExcerpt = testCase.expectedMetadata.excerpt

        #expect(result.excerpt == expectedExcerpt,
                "Excerpt mismatch. Expected: '\(expectedExcerpt ?? "nil")', Actual: '\(result.excerpt ?? "nil")'")
    }

    @Test("schema-org-context-object - Published time matches expected")
    func testSchemaOrgContextObjectPublishedTime() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "schema-org-context-object") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
        let result = try readability.parse()

        let expectedPublishedTime = testCase.expectedMetadata.publishedTime
        #expect(result.publishedTime == expectedPublishedTime,
                "Published time mismatch. Expected: '\(expectedPublishedTime ?? "nil")', Actual: '\(result.publishedTime ?? "nil")'")
    }

    @Test("schema-org-context-object - Site name matches expected")
    func testSchemaOrgContextObjectSiteName() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "schema-org-context-object") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
        let result = try readability.parse()

        let expectedSiteName = testCase.expectedMetadata.siteName
        #expect(result.siteName == expectedSiteName,
                "Site name mismatch. Expected: '\(expectedSiteName ?? "nil")', Actual: '\(result.siteName ?? "nil")'")
    }

    @Test("003-metadata-preferred - Title matches expected")
    func test003MetadataPreferredTitle() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "003-metadata-preferred") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
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

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
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

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
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

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
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

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
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

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
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

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
        let result = try readability.parse()

        let expectedByline = testCase.expectedMetadata.byline
        #expect(result.byline == expectedByline,
                "Byline mismatch. Expected: '\(expectedByline ?? "nil")', Actual: '\(result.byline ?? "nil")'")
    }

    @Test("keep-images - Published time matches expected")
    func testKeepImagesPublishedTime() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "keep-images") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
        let result = try readability.parse()

        let expectedPublishedTime = testCase.expectedMetadata.publishedTime
        #expect(result.publishedTime == expectedPublishedTime,
                "Published time mismatch. Expected: '\(expectedPublishedTime ?? "nil")', Actual: '\(result.publishedTime ?? "nil")'")
    }

    @Test("keep-images - Site name matches expected")
    func testKeepImagesSiteName() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "keep-images") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
        let result = try readability.parse()

        let expectedSiteName = testCase.expectedMetadata.siteName
        #expect(result.siteName == expectedSiteName,
                "Site name mismatch. Expected: '\(expectedSiteName ?? "nil")', Actual: '\(result.siteName ?? "nil")'")
    }

    @Test("keep-tabular-data - Title matches expected")
    func testKeepTabularDataTitle() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "keep-tabular-data") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
        let result = try readability.parse()

        let expectedTitle = testCase.expectedMetadata.title ?? ""
        #expect(result.title == expectedTitle,
                "Title mismatch. Expected: '\(expectedTitle)', Actual: '\(result.title)'")
    }

    @Test("keep-tabular-data - Site name matches expected")
    func testKeepTabularDataSiteName() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "keep-tabular-data") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
        let result = try readability.parse()

        let expectedSiteName = testCase.expectedMetadata.siteName
        #expect(result.siteName == expectedSiteName,
                "Site name mismatch. Expected: '\(expectedSiteName ?? "nil")', Actual: '\(result.siteName ?? "nil")'")
    }

    // MARK: - Phase 6.3: Conditional Cleaning Tests

    @Test("clean-links - Content matches expected")
    func testCleanLinks() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "clean-links") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
        let result = try readability.parse()

        let comparison = compareDOM(result.content, testCase.expectedHTML)
        #expect(comparison.isEqual, "Content mismatch: \(comparison.diff)")
    }

    @Test("links-in-tables - Content matches expected")
    func testLinksInTables() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "links-in-tables") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
        let result = try readability.parse()

        let comparison = compareDOM(result.content, testCase.expectedHTML)
        #expect(comparison.isEqual, "Content mismatch: \(comparison.diff)")
    }

    @Test("social-buttons - Content matches expected")
    func testSocialButtons() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "social-buttons") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
        let result = try readability.parse()

        let comparison = compareDOM(result.content, testCase.expectedHTML)
        #expect(comparison.isEqual, "Content mismatch: \(comparison.diff)")
    }

    @Test("article-author-tag - Content matches expected")
    func testArticleAuthorTag() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "article-author-tag") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
        let result = try readability.parse()

        let comparison = compareDOM(result.content, testCase.expectedHTML)
        #expect(comparison.isEqual, "Content mismatch: \(comparison.diff)")
    }

    @Test("article-author-tag - Byline matches expected")
    func testArticleAuthorTagByline() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "article-author-tag") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
        let result = try readability.parse()

        let expectedByline = testCase.expectedMetadata.byline
        #expect(result.byline == expectedByline,
                "Byline mismatch. Expected: '\(expectedByline ?? "nil")', Actual: '\(result.byline ?? "nil")'")
    }

    @Test("article-author-tag - Published time matches expected")
    func testArticleAuthorTagPublishedTime() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "article-author-tag") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
        let result = try readability.parse()

        let expectedPublishedTime = testCase.expectedMetadata.publishedTime
        #expect(result.publishedTime == expectedPublishedTime,
                "Published time mismatch. Expected: '\(expectedPublishedTime ?? "nil")', Actual: '\(result.publishedTime ?? "nil")'")
    }

    @Test("article-author-tag - Site name matches expected")
    func testArticleAuthorTagSiteName() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "article-author-tag") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
        let result = try readability.parse()

        let expectedSiteName = testCase.expectedMetadata.siteName
        #expect(result.siteName == expectedSiteName,
                "Site name mismatch. Expected: '\(expectedSiteName ?? "nil")', Actual: '\(result.siteName ?? "nil")'")
    }

    @Test("table-style-attributes - Content matches expected")
    func testTableStyleAttributes() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "table-style-attributes") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
        let result = try readability.parse()

        let comparison = compareDOM(result.content, testCase.expectedHTML)
        #expect(comparison.isEqual, "Content mismatch: \(comparison.diff)")
    }

    @Test("invalid-attributes - Content matches expected")
    func testInvalidAttributes() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "invalid-attributes") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
        let result = try readability.parse()

        let comparison = compareDOM(result.content, testCase.expectedHTML)
        #expect(comparison.isEqual, "Content mismatch: \(comparison.diff)")
    }

    // MARK: - Phase 6.4: Hidden Node & Visibility Handling

    @Test("hidden-nodes - Content matches expected")
    func testHiddenNodes() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "hidden-nodes") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
        let result = try readability.parse()

        let comparison = compareDOM(result.content, testCase.expectedHTML)
        #expect(comparison.isEqual, "Content mismatch: \(comparison.diff)")
    }

    @Test("hidden-nodes - Title matches expected")
    func testHiddenNodesTitle() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "hidden-nodes") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
        let result = try readability.parse()

        let expectedTitle = testCase.expectedMetadata.title ?? ""
        #expect(result.title == expectedTitle,
                "Title mismatch. Expected: '\(expectedTitle)', Actual: '\(result.title)'")
    }

    @Test("visibility-hidden - Content matches expected")
    func testVisibilityHidden() async throws {
        guard let testCase = TestLoader.loadTestCase(named: "visibility-hidden") else {
            Issue.record("Failed to load test case")
            return
        }

        let readability = try Readability(html: testCase.sourceHTML, baseURL: testBaseURL, options: defaultOptions)
        let result = try readability.parse()

        let comparison = compareDOM(result.content, testCase.expectedHTML)
        #expect(comparison.isEqual, "Content mismatch: \(comparison.diff)")
    }
}
