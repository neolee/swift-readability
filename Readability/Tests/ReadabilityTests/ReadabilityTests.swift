import Testing
import SwiftSoup
@testable import Readability

@Suite("Readability Lifecycle Tests")
struct ReadabilityTests {

    @Test("parse succeeds once and rejects repeated invocation")
    func testParseIsSingleUseAfterSuccess() throws {
        let html = """
        <html>
        <body>
          <article>
            <h1>Sample Title</h1>
            <p>This is a sufficiently long paragraph, with commas, to satisfy scoring and extraction.</p>
          </article>
        </body>
        </html>
        """

        let readability = try Readability(html: html)
        let first = try readability.parse()
        #expect(first.title == "Sample Title")

        do {
            _ = try readability.parse()
            Issue.record("Expected second parse to throw alreadyParsed")
        } catch ReadabilityError.alreadyParsed {
            // expected
        } catch {
            Issue.record("Expected alreadyParsed, got: \(error)")
        }
    }

    @Test("parse rejects repeated invocation after failure")
    func testParseIsSingleUseAfterFailure() throws {
        let html = "<html><body></body></html>"
        let readability = try Readability(html: html)

        do {
            _ = try readability.parse()
            Issue.record("Expected first parse to fail on empty document")
        } catch ReadabilityError.alreadyParsed {
            Issue.record("First parse must not fail with alreadyParsed")
        } catch {
            // Expected: parse may fail with noContent/contentTooShort depending internals.
        }

        do {
            _ = try readability.parse()
            Issue.record("Expected second parse to throw alreadyParsed")
        } catch ReadabilityError.alreadyParsed {
            // expected
        } catch {
            Issue.record("Expected alreadyParsed, got: \(error)")
        }
    }

    @Test("parse prefers extracted byline over social handle metadata")
    func testBylinePrefersExtractedNameOverSocialHandle() throws {
        let html = """
        <html>
        <head>
          <meta property="twitter:creator" content="@erinmcunningham">
        </head>
        <body>
          <article>
            <div class="byline">By Erin Cunningham</div>
            <p>This is a sufficiently long paragraph, with commas, to satisfy scoring and extraction for article content.</p>
          </article>
        </body>
        </html>
        """

        let readability = try Readability(html: html)
        let result = try readability.parse()
        #expect(result.byline == "By Erin Cunningham")
    }

    @Test("parse preserves figure inner div wrapper")
    func testParsePreservesFigureInnerDivWrapper() throws {
        let html = """
        <html>
        <body>
          <article>
            <figure>
              <div contenteditable="false" data-syndicationrights="false"><p><img src="https://example.com/photo.jpg"></p></div>
              <figcaption>Caption text</figcaption>
            </figure>
            <p>This is a sufficiently long paragraph, with commas, to satisfy scoring and extraction behavior.</p>
          </article>
        </body>
        </html>
        """

        let readability = try Readability(html: html)
        let result = try readability.parse()
        let doc = try SwiftSoup.parseBodyFragment(result.content)
        #expect((try doc.select("figure > div > p > img").isEmpty()) == false)
        let wrapper = try doc.select("figure > div").first()
        #expect(wrapper != nil)
        #expect((try wrapper?.attr("contenteditable")) == "false")
        #expect((try wrapper?.attr("data-syndicationrights")) == "false")
    }

    @Test("parse uses full first paragraph as excerpt fallback")
    func testParseUsesFullFirstParagraphAsExcerptFallback() throws {
        let firstParagraph = """
        Mozilla readability fallback excerpt should keep the full first paragraph text without a hard cap, even when the paragraph is much longer than two hundred characters so that metadata parity can stay aligned with expected outputs for long-form articles.
        """
        let html = """
        <html>
        <body>
          <article>
            <h1>Long Excerpt Article</h1>
            <p>\(firstParagraph)</p>
            <p>This is another paragraph.</p>
          </article>
        </body>
        </html>
        """

        let readability = try Readability(html: html)
        let result = try readability.parse()
        #expect(result.excerpt == firstParagraph)
    }

    @Test("parse prefers og article author over social handle metadata")
    func testParsePrefersOGArticleAuthorOverSocialHandle() throws {
        let html = """
        <html>
        <head>
          <meta property="og:article:author" content="BBC News">
          <meta name="twitter:creator" content="@BBCWorld">
        </head>
        <body>
          <article>
            <p>This is a sufficiently long paragraph, with commas, to satisfy scoring and extraction behavior.</p>
          </article>
        </body>
        </html>
        """

        let readability = try Readability(html: html)
        let result = try readability.parse()
        #expect(result.byline == "BBC News")
    }

    @Test("parse falls back to meta excerpt when JSON-LD excerpt is empty")
    func testParseFallsBackToMetaExcerptWhenJSONLDEmpty() throws {
        let metaDescription = "This meta description should be used when JSON-LD description is empty."
        let html = """
        <html>
        <head>
          <script type="application/ld+json">
          {"@context":"https://schema.org","@type":"NewsArticle","description":""}
          </script>
          <meta property="og:description" content="\(metaDescription)">
        </head>
        <body>
          <article>
            <p>Paragraph content for extraction.</p>
          </article>
        </body>
        </html>
        """

        let readability = try Readability(html: html)
        let result = try readability.parse()
        #expect(result.excerpt == metaDescription)
    }
}
