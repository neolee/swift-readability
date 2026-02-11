import Testing
import SwiftSoup
@testable import Readability

/// Tests for NodeCleaner functionality
/// These tests verify noise removal and content cleaning
@Suite("Node Cleaner Tests")
struct NodeCleanerTests {

    // MARK: - Unlikely Candidate Removal Tests

    @Test("removeUnlikelyCandidates removes real-world supplemental modules")
    func testRemoveRealWorldSupplementalModule() throws {
        guard let testCase = TestLoader.loadRealWorldTestCase(named: "nytimes-1") else {
            Issue.record("Failed to load real-world test case nytimes-1")
            return
        }

        let doc = try SwiftSoup.parse(testCase.sourceHTML)
        guard let body = doc.body() else {
            Issue.record("Missing body in nytimes-1 source")
            return
        }

        let cleaner = NodeCleaner(options: .default)
        try cleaner.removeUnlikelyCandidates(from: body, stripUnlikelyCandidates: true)

        let supplemental = try doc.select("#supplemental-1")
        #expect(supplemental.isEmpty())
    }

    @Test("removeUnlikelyCandidates removes banner elements")
    func testRemoveBannerElements() throws {
        let html = """
        <div>
            <div class="article-content">Real content here</div>
            <div class="banner-ad">Advertisement</div>
        </div>
        """
        let doc = try SwiftSoup.parseBodyFragment(html)
        let root = try doc.select("div").first()!

        let cleaner = NodeCleaner(options: .default)
        try cleaner.removeUnlikelyCandidates(from: root, stripUnlikelyCandidates: true)

        let banner = try doc.select(".banner-ad")
        #expect(banner.isEmpty())
        let content = try doc.select(".article-content")
        #expect(!content.isEmpty())
    }

    @Test("removeUnlikelyCandidates removes comment sections")
    func testRemoveCommentSections() throws {
        let html = """
        <div>
            <article>Article content</article>
            <div class="comments">User comments</div>
        </div>
        """
        let doc = try SwiftSoup.parseBodyFragment(html)
        let root = try doc.select("div").first()!

        let cleaner = NodeCleaner(options: .default)
        try cleaner.removeUnlikelyCandidates(from: root, stripUnlikelyCandidates: true)

        let comments = try doc.select(".comments")
        #expect(comments.isEmpty())
    }

    @Test("removeUnlikelyCandidates keeps content elements")
    func testKeepContentElements() throws {
        let html = """
        <div>
            <article class="main-content">Article</article>
            <div class="article-body">Body</div>
        </div>
        """
        let doc = try SwiftSoup.parseBodyFragment(html)
        let root = try doc.select("div").first()!

        let cleaner = NodeCleaner(options: .default)
        try cleaner.removeUnlikelyCandidates(from: root, stripUnlikelyCandidates: true)

        let article = try doc.select("article")
        #expect(!article.isEmpty())
        let body = try doc.select(".article-body")
        #expect(!body.isEmpty())
    }

    @Test("removeUnlikelyCandidates removes by ARIA role")
    func testRemoveByARiarole() throws {
        let html = """
        <div>
            <article>Content</article>
            <nav role="navigation">Menu</nav>
            <div role="complementary">Sidebar</div>
        </div>
        """
        let doc = try SwiftSoup.parseBodyFragment(html)
        let root = try doc.select("div").first()!

        let cleaner = NodeCleaner(options: .default)
        try cleaner.removeUnlikelyCandidates(from: root, stripUnlikelyCandidates: true)

        let nav = try doc.select("nav")
        #expect(nav.isEmpty())
        let complementary = try doc.select("[role=complementary]")
        #expect(complementary.isEmpty())
        let article = try doc.select("article")
        #expect(!article.isEmpty())
    }

    @Test("removeUnlikelyCandidates removes empty containers")
    func testRemoveEmptyContainers() throws {
        let html = """
        <div>
            <section></section>
            <div>Content</div>
            <header>   </header>
        </div>
        """
        let doc = try SwiftSoup.parseBodyFragment(html)
        let root = try doc.select("div").first()!

        let cleaner = NodeCleaner(options: .default)
        try cleaner.removeUnlikelyCandidates(from: root, stripUnlikelyCandidates: true)

        let sections = try doc.select("section")
        #expect(sections.isEmpty())
        let headers = try doc.select("header")
        #expect(headers.isEmpty())
    }

    @Test("removeUnlikelyCandidates skips when flag disabled")
    func testSkipWhenFlagDisabled() throws {
        let html = """
        <div>
            <div class="banner-ad">Ad</div>
        </div>
        """
        let doc = try SwiftSoup.parseBodyFragment(html)
        let root = try doc.select("div").first()!

        let cleaner = NodeCleaner(options: .default)
        try cleaner.removeUnlikelyCandidates(from: root, stripUnlikelyCandidates: false)

        let banner = try doc.select(".banner-ad")
        #expect(!banner.isEmpty())
    }

    @Test("removeUnlikelyCandidates protects table contents")
    func testProtectTableContents() throws {
        let html = """
        <table>
            <tr>
                <td class="comment">Cell in table</td>
            </tr>
        </table>
        """
        let doc = try SwiftSoup.parseBodyFragment(html)
        let root = try doc.select("table").first()!

        let cleaner = NodeCleaner(options: .default)
        try cleaner.removeUnlikelyCandidates(from: root, stripUnlikelyCandidates: true)

        let cell = try doc.select("td")
        #expect(!cell.isEmpty())
    }

    // MARK: - Byline Extraction Tests

    @Test("checkAndExtractByline extracts author from rel attribute")
    func testExtractBylineFromRel() throws {
        let html = "<span rel='author'>John Doe</span>"
        let doc = try SwiftSoup.parseBodyFragment(html)
        let span = try doc.select("span").first()!

        let cleaner = NodeCleaner(options: .default)
        let shouldRemove = cleaner.checkAndExtractByline(span, matchString: "")

        #expect(shouldRemove == true)
        #expect(cleaner.getExtractedByline() == "John Doe")
    }

    @Test("checkAndExtractByline extracts author from itemprop")
    func testExtractBylineFromItemprop() throws {
        let html = "<span itemprop='author'>Jane Smith</span>"
        let doc = try SwiftSoup.parseBodyFragment(html)
        let span = try doc.select("span").first()!

        let cleaner = NodeCleaner(options: .default)
        let shouldRemove = cleaner.checkAndExtractByline(span, matchString: "")

        #expect(shouldRemove == true)
        #expect(cleaner.getExtractedByline() == "Jane Smith")
    }

    @Test("checkAndExtractByline extracts from byline class")
    func testExtractBylineFromClass() throws {
        let html = "<div class='byline'>Written by Bob</div>"
        let doc = try SwiftSoup.parseBodyFragment(html)
        let div = try doc.select("div").first()!

        let cleaner = NodeCleaner(options: .default)
        let shouldRemove = cleaner.checkAndExtractByline(div, matchString: "byline")

        #expect(shouldRemove == true)
        #expect(cleaner.getExtractedByline() == "Written by Bob")
    }

    @Test("checkAndExtractByline prefers itemprop name child")
    func testExtractBylinePrefersItempropName() throws {
        let html = """
        <div itemprop="author">
            <span itemprop="name">Actual Author</span>
            <span>Other text</span>
        </div>
        """
        let doc = try SwiftSoup.parseBodyFragment(html)
        let div = try doc.select("div").first()!

        let cleaner = NodeCleaner(options: .default)
        let shouldRemove = cleaner.checkAndExtractByline(div, matchString: "")

        #expect(shouldRemove == true)
        #expect(cleaner.getExtractedByline() == "Actual Author")
    }

    @Test("checkAndExtractByline prefers author-link text over title suffix")
    func testExtractBylinePrefersAuthorLinkText() throws {
        let html = """
        <div class="author">
            <a class="author-link" href="/author/ben-silverman">Ben Silverman</a>
            <div class="author-title">Games Editor</div>
        </div>
        """
        let doc = try SwiftSoup.parseBodyFragment(html)
        let div = try doc.select("div.author").first()!

        let cleaner = NodeCleaner(options: .default)
        let shouldRemove = cleaner.checkAndExtractByline(div, matchString: "author")

        #expect(shouldRemove == true)
        #expect(cleaner.getExtractedByline() == "Ben Silverman")
    }

    @Test("checkAndExtractByline skips if too long")
    func testSkipLongByline() throws {
        let longName = String(repeating: "A", count: 101)
        let html = "<span rel='author'>\(longName)</span>"
        let doc = try SwiftSoup.parseBodyFragment(html)
        let span = try doc.select("span").first()!

        let cleaner = NodeCleaner(options: .default)
        let shouldRemove = cleaner.checkAndExtractByline(span, matchString: "")

        #expect(shouldRemove == false)
        #expect(cleaner.getExtractedByline() == nil)
    }

    @Test("checkAndExtractByline skips if already have byline")
    func testSkipIfBylineExists() throws {
        let html = "<span rel='author'>Second Author</span>"
        let doc = try SwiftSoup.parseBodyFragment(html)
        let span = try doc.select("span").first()!

        let cleaner = NodeCleaner(options: .default)
        cleaner.setArticleByline("First Author")
        let shouldRemove = cleaner.checkAndExtractByline(span, matchString: "")

        #expect(shouldRemove == false)
        #expect(cleaner.getExtractedByline() == "First Author")
    }

    // MARK: - Header Duplicate Title Tests

    @Test("headerDuplicatesTitle detects matching H1")
    func testHeaderDuplicatesTitleH1() throws {
        let html = "<h1>Article Title Here</h1>"
        let doc = try SwiftSoup.parseBodyFragment(html)
        let h1 = try doc.select("h1").first()!

        let cleaner = NodeCleaner(options: .default)
        cleaner.setArticleTitle("Article Title Here")

        #expect(cleaner.headerDuplicatesTitle(h1) == true)
    }

    @Test("headerDuplicatesTitle detects similar H2")
    func testHeaderDuplicatesTitleH2() throws {
        let html = "<h2>The Article Title</h2>"
        let doc = try SwiftSoup.parseBodyFragment(html)
        let h2 = try doc.select("h2").first()!

        let cleaner = NodeCleaner(options: .default)
        cleaner.setArticleTitle("Article Title")

        #expect(cleaner.headerDuplicatesTitle(h2) == true)
    }

    @Test("headerDuplicatesTitle skips different content")
    func testHeaderNotDuplicate() throws {
        let html = "<h1>Completely Different Title</h1>"
        let doc = try SwiftSoup.parseBodyFragment(html)
        let h1 = try doc.select("h1").first()!

        let cleaner = NodeCleaner(options: .default)
        cleaner.setArticleTitle("Article Title")

        #expect(cleaner.headerDuplicatesTitle(h1) == false)
    }

    @Test("headerDuplicatesTitle skips non-heading elements")
    func testHeaderOnlyChecksHeadings() throws {
        let html = "<div>Article Title</div>"
        let doc = try SwiftSoup.parseBodyFragment(html)
        let div = try doc.select("div").first()!

        let cleaner = NodeCleaner(options: .default)
        cleaner.setArticleTitle("Article Title")

        #expect(cleaner.headerDuplicatesTitle(div) == false)
    }

    // MARK: - Visibility Check Tests

    @Test("isProbablyVisible returns false for display:none")
    func testNotVisibleDisplayNone() throws {
        let html = "<div style='display:none'>Hidden</div>"
        let doc = try SwiftSoup.parseBodyFragment(html)
        let div = try doc.select("div").first()!

        let cleaner = NodeCleaner(options: .default)

        #expect(cleaner.isProbablyVisible(div) == false)
    }

    @Test("isProbablyVisible returns false for visibility:hidden")
    func testNotVisibleVisibilityHidden() throws {
        let html = "<div style='visibility:hidden'>Hidden</div>"
        let doc = try SwiftSoup.parseBodyFragment(html)
        let div = try doc.select("div").first()!

        let cleaner = NodeCleaner(options: .default)

        #expect(cleaner.isProbablyVisible(div) == false)
    }

    @Test("isProbablyVisible returns false for hidden attribute")
    func testNotVisibleHiddenAttribute() throws {
        let html = "<div hidden>Hidden</div>"
        let doc = try SwiftSoup.parseBodyFragment(html)
        let div = try doc.select("div").first()!

        let cleaner = NodeCleaner(options: .default)

        #expect(cleaner.isProbablyVisible(div) == false)
    }

    @Test("isProbablyVisible returns false for aria-hidden")
    func testNotVisibleAriaHidden() throws {
        let html = "<div aria-hidden='true'>Hidden</div>"
        let doc = try SwiftSoup.parseBodyFragment(html)
        let div = try doc.select("div").first()!

        let cleaner = NodeCleaner(options: .default)

        #expect(cleaner.isProbablyVisible(div) == false)
    }

    @Test("isProbablyVisible allows fallback-image with aria-hidden")
    func testVisibleFallbackImage() throws {
        let html = "<div aria-hidden='true' class='fallback-image'>Math</div>"
        let doc = try SwiftSoup.parseBodyFragment(html)
        let div = try doc.select("div").first()!

        let cleaner = NodeCleaner(options: .default)

        #expect(cleaner.isProbablyVisible(div) == true)
    }

    @Test("isProbablyVisible returns true for normal elements")
    func testVisibleNormal() throws {
        let html = "<div>Visible content</div>"
        let doc = try SwiftSoup.parseBodyFragment(html)
        let div = try doc.select("div").first()!

        let cleaner = NodeCleaner(options: .default)

        #expect(cleaner.isProbablyVisible(div) == true)
    }

    // MARK: - Modal Dialog Check Tests

    @Test("isModalDialog detects modal dialog")
    func testIsModalDialog() throws {
        let html = "<div aria-modal='true' role='dialog'>Modal</div>"
        let doc = try SwiftSoup.parseBodyFragment(html)
        let div = try doc.select("div").first()!

        let cleaner = NodeCleaner(options: .default)

        #expect(cleaner.isModalDialog(div) == true)
    }

    @Test("isModalDialog returns false for non-modal")
    func testNotModalDialog() throws {
        let html = "<div role='dialog'>Regular dialog</div>"
        let doc = try SwiftSoup.parseBodyFragment(html)
        let div = try doc.select("div").first()!

        let cleaner = NodeCleaner(options: .default)

        #expect(cleaner.isModalDialog(div) == false)
    }

    // MARK: - Text Similarity Tests

    @Test("textSimilarity returns 1 for identical strings")
    func testSimilarityIdentical() {
        let cleaner = NodeCleaner(options: .default)
        let similarity = cleaner.textSimilarity("Hello World", "Hello World")

        #expect(similarity == 1.0)
    }

    @Test("textSimilarity returns 0 for completely different strings")
    func testSimilarityDifferent() {
        let cleaner = NodeCleaner(options: .default)
        let similarity = cleaner.textSimilarity("Hello World", "Completely Different")

        #expect(similarity == 0.0)
    }

    @Test("textSimilarity returns high value for similar strings")
    func testSimilarityHigh() {
        let cleaner = NodeCleaner(options: .default)
        let similarity = cleaner.textSimilarity("Article Title Here", "The Article Title")

        #expect(similarity > 0.75)
    }

    @Test("textSimilarity handles case insensitivity")
    func testSimilarityCaseInsensitive() {
        let cleaner = NodeCleaner(options: .default)
        let similarity = cleaner.textSimilarity("HELLO WORLD", "hello world")

        #expect(similarity == 1.0)
    }

    @Test("textSimilarity handles empty strings")
    func testSimilarityEmpty() {
        let cleaner = NodeCleaner(options: .default)
        let similarity = cleaner.textSimilarity("", "Hello")

        #expect(similarity == 0.0)
    }

    // MARK: - Remove Matching Elements Tests

    @Test("removeMatchingElements removes based on filter")
    func testRemoveMatchingElements() throws {
        let html = """
        <div>
            <p class="keep">Keep</p>
            <p class="remove">Remove</p>
        </div>
        """
        let doc = try SwiftSoup.parseBodyFragment(html)
        let root = try doc.select("div").first()!

        let cleaner = NodeCleaner(options: .default)
        try cleaner.removeMatchingElements(from: root) { element, matchString in
            return matchString.contains("remove")
        }

        let keep = try doc.select(".keep")
        let remove = try doc.select(".remove")

        #expect(!keep.isEmpty())
        #expect(remove.isEmpty())
    }

    // MARK: - Edge Cases

    @Test("checkAndExtractByline skips empty elements")
    func testSkipEmptyByline() throws {
        let html = "<span rel='author'>   </span>"
        let doc = try SwiftSoup.parseBodyFragment(html)
        let span = try doc.select("span").first()!

        let cleaner = NodeCleaner(options: .default)
        let shouldRemove = cleaner.checkAndExtractByline(span, matchString: "")

        #expect(shouldRemove == false)
    }

    @Test("textSimilarity handles partial overlap")
    func testSimilarityPartial() {
        let cleaner = NodeCleaner(options: .default)
        let similarity = cleaner.textSimilarity("Hello World Test", "Hello World Example")

        // Should be between 0 and 1
        #expect(similarity > 0.0)
        #expect(similarity < 1.0)
    }
}
