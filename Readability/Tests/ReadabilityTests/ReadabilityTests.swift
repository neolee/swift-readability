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
}
