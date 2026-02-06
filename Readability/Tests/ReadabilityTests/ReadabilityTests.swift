import Testing
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
}
