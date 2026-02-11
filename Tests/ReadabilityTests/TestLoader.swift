import Foundation

/// Utility for loading Mozilla test cases
enum TestLoader {
    struct TestCase {
        let name: String
        let sourceHTML: String
        let expectedHTML: String
        let expectedMetadata: TestMetadata
    }

    struct TestMetadata: Codable {
        let title: String?
        let byline: String?
        let dir: String?
        let lang: String?
        let excerpt: String?
        let siteName: String?
        let publishedTime: String?
        let readerable: Bool?

        enum CodingKeys: String, CodingKey {
            case title
            case byline
            case dir
            case lang
            case excerpt
            case siteName
            case publishedTime
            case readerable
        }
    }

    /// Get the resources directory for a specific test group.
    private static func resourcesDirectory(for group: String) -> URL? {
        // Try to find resources relative to the test executable
        let fileManager = FileManager.default

        // Get the directory of this source file
        let thisFile = #file
        let thisDir = URL(fileURLWithPath: thisFile).deletingLastPathComponent()

        // Navigate to the selected Resources subdirectory.
        let resourcesURL = thisDir
            .appendingPathComponent("Resources")
            .appendingPathComponent(group)

        if fileManager.fileExists(atPath: resourcesURL.path) {
            return resourcesURL
        }

        // Fallback: try to find in current working directory
        let cwd = fileManager.currentDirectoryPath
        let cwdResources = URL(fileURLWithPath: cwd)
            .appendingPathComponent("Tests")
            .appendingPathComponent("ReadabilityTests")
            .appendingPathComponent("Resources")
            .appendingPathComponent(group)

        if fileManager.fileExists(atPath: cwdResources.path) {
            return cwdResources
        }

        return nil
    }

    /// Load all available test cases
    static func loadAllTestCases() -> [TestCase] {
        let testNames = [
            "001",
            "basic-tags-cleaning",
            "remove-script-tags",
            "replace-brs",
            "replace-font-tags",
            "remove-aria-hidden",
            "style-tags-removal",
            "normalize-spaces",
            // Phase 3: Metadata extraction
            "003-metadata-preferred",
            "004-metadata-space-separated-properties",
            "parsely-metadata",
            "schema-org-context-object",
            // Phase 4: Core scoring
            "title-en-dash",
            "title-and-h1-discrepancy",
            "keep-images",
            "keep-tabular-data",
            // Phase 6.3: Conditional Cleaning
            "clean-links",
            "links-in-tables",
            "social-buttons",
            "article-author-tag",
            "table-style-attributes",
            "invalid-attributes",
            // Phase 6.4: Hidden Node & Visibility Handling
            "hidden-nodes",
            "visibility-hidden"
        ]
        return testNames.compactMap { loadTestCase(named: $0) }
    }

    /// Load a specific test case
    static func loadTestCase(named name: String, in group: String = "test-pages") -> TestCase? {
        guard let resourcesURL = resourcesDirectory(for: group) else {
            print("Failed to locate resources directory for group '\(group)'")
            return nil
        }

        let testPageURL = resourcesURL.appendingPathComponent(name)

        guard FileManager.default.fileExists(atPath: testPageURL.path) else {
            print("Test case directory not found: \(testPageURL.path)")
            return nil
        }

        do {
            let sourceURL = testPageURL.appendingPathComponent("source.html")
            let expectedURL = testPageURL.appendingPathComponent("expected.html")
            let metadataURL = testPageURL.appendingPathComponent("expected-metadata.json")

            let sourceHTML = try String(contentsOf: sourceURL, encoding: .utf8)
            let expectedHTML = try String(contentsOf: expectedURL, encoding: .utf8)
            let metadataData = try Data(contentsOf: metadataURL)
            let metadata = try JSONDecoder().decode(TestMetadata.self, from: metadataData)

            return TestCase(
                name: name,
                sourceHTML: sourceHTML,
                expectedHTML: expectedHTML,
                expectedMetadata: metadata
            )
        } catch {
            print("Failed to load test case '\(name)': \(error)")
            return nil
        }
    }

    /// Load a real-world test case from `Resources/realworld-pages`.
    static func loadRealWorldTestCase(named name: String) -> TestCase? {
        loadTestCase(named: name, in: "realworld-pages")
    }
}
