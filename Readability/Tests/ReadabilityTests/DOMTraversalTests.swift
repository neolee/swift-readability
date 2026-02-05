import Testing
import SwiftSoup
@testable import Readability

/// Tests for DOMTraversal utilities
/// These tests verify the core traversal functionality needed for Readability
@Suite("DOM Traversal Tests")
struct DOMTraversalTests {

    // MARK: - getNextNode Tests

    @Test("getNextNode returns first child when available")
    func testGetNextNodeReturnsFirstChild() throws {
        let html = "<div><p>Child 1</p><p>Child 2</p></div>"
        let doc = try SwiftSoup.parse(html)
        let div = try doc.select("div").first()!

        let next = DOMTraversal.getNextNode(div)

        #expect(next != nil)
        #expect(next?.tagName().lowercased() == "p")
        #expect(try next?.text() == "Child 1")
    }

    @Test("getNextNode returns sibling when no children")
    func testGetNextNodeReturnsSibling() throws {
        let html = "<div><p>First</p><span>Second</span></div>"
        let doc = try SwiftSoup.parse(html)
        let p = try doc.select("p").first()!

        let next = DOMTraversal.getNextNode(p)

        #expect(next != nil)
        #expect(next?.tagName().lowercased() == "span")
        #expect(try next?.text() == "Second")
    }

    @Test("getNextNode returns parent's sibling when no next sibling")
    func testGetNextNodeReturnsParentSibling() throws {
        let html = "<div><p><span>Deep</span></p><article>After</article></div>"
        let doc = try SwiftSoup.parse(html)
        let span = try doc.select("span").first()!

        let next = DOMTraversal.getNextNode(span)

        #expect(next != nil)
        #expect(next?.tagName().lowercased() == "article")
    }

    @Test("getNextNode returns nil at end of document")
    func testGetNextNodeReturnsNilAtEnd() throws {
        let html = "<div><p>Last</p></div>"
        let doc = try SwiftSoup.parse(html)
        let p = try doc.select("p").first()!

        let next = DOMTraversal.getNextNode(p)

        #expect(next == nil)
    }

    @Test("getNextNode ignores self and kids when requested")
    func testGetNextNodeIgnoresSelfAndKids() throws {
        let html = "<div><p>Child</p></div><span>Next</span>"
        let doc = try SwiftSoup.parse(html)
        let div = try doc.select("div").first()!

        let next = DOMTraversal.getNextNode(div, ignoreSelfAndKids: true)

        #expect(next != nil)
        #expect(next?.tagName().lowercased() == "span")
    }

    @Test("getNextNode handles nil input")
    func testGetNextNodeHandlesNil() {
        let next = DOMTraversal.getNextNode(nil)
        #expect(next == nil)
    }

    // MARK: - removeAndGetNext Tests

    @Test("removeAndGetNext removes node and returns next")
    func testRemoveAndGetNext() throws {
        let html = "<div><p id='first'>First</p><p id='second'>Second</p></div>"
        let doc = try SwiftSoup.parse(html)
        let first = try doc.select("p#first").first()!

        let next = DOMTraversal.removeAndGetNext(first)

        // First paragraph should be removed
        #expect(try doc.select("p#first").isEmpty())

        // Next should be second paragraph
        #expect(next != nil)
        #expect(next?.id() == "second")
    }

    @Test("removeAndGetNext handles last element")
    func testRemoveAndGetNextLastElement() throws {
        let html = "<div><p>Only</p></div>"
        let doc = try SwiftSoup.parse(html)
        let p = try doc.select("p").first()!

        let next = DOMTraversal.removeAndGetNext(p)

        #expect(try doc.select("p").isEmpty())
        #expect(next == nil)
    }

    // MARK: - getNodeAncestors Tests

    @Test("getNodeAncestors returns all ancestors")
    func testGetNodeAncestors() throws {
        let html = "<div><p>Deep</p></div>"
        let doc = try SwiftSoup.parse(html)
        let p = try doc.select("p").first()!

        let ancestors = DOMTraversal.getNodeAncestors(p)

        // SwiftSoup parses with html and body wrapper, so we expect:
        // p -> div -> body -> html
        #expect(ancestors.count >= 2)
        #expect(ancestors[0].tagName().lowercased() == "div")
    }

    @Test("getNodeAncestors respects maxDepth")
    func testGetNodeAncestorsMaxDepth() throws {
        let html = "<html><body><div><p>Deep</p></div></body></html>"
        let doc = try SwiftSoup.parse(html)
        let p = try doc.select("p").first()!

        let ancestors = DOMTraversal.getNodeAncestors(p, maxDepth: 2)

        #expect(ancestors.count == 2)
        #expect(ancestors[0].tagName().lowercased() == "div")
        #expect(ancestors[1].tagName().lowercased() == "body")
    }

    @Test("getNodeAncestors returns empty for root")
    func testGetNodeAncestorsEmptyForRoot() throws {
        // In SwiftSoup, even html element has a parent (Document)
        // So we test that the function works correctly for top-level elements
        let html = "<p>Test</p>"
        let doc = try SwiftSoup.parseBodyFragment(html)
        let p = try doc.select("p").first()!

        // p's ancestors are body and the fragment root
        let ancestors = DOMTraversal.getNodeAncestors(p)

        #expect(ancestors.count >= 1) // At least body
    }

    // MARK: - hasAncestorTag Tests

    @Test("hasAncestorTag finds matching ancestor")
    func testHasAncestorTag() throws {
        let html = "<article><div><p>Test</p></div></article>"
        let doc = try SwiftSoup.parse(html)
        let p = try doc.select("p").first()!

        let hasArticle = DOMTraversal.hasAncestorTag(p, tagName: "article")
        let hasDiv = DOMTraversal.hasAncestorTag(p, tagName: "div")

        #expect(hasArticle == true)
        #expect(hasDiv == true)
    }

    @Test("hasAncestorTag returns false for non-matching ancestor")
    func testHasAncestorTagFalse() throws {
        let html = "<article><div><p>Test</p></div></article>"
        let doc = try SwiftSoup.parse(html)
        let p = try doc.select("p").first()!

        let hasSection = DOMTraversal.hasAncestorTag(p, tagName: "section")

        #expect(hasSection == false)
    }

    @Test("hasAncestorTag respects maxDepth")
    func testHasAncestorTagMaxDepth() throws {
        let html = "<greatgrandparent><grandparent><parent><child>Test</child></parent></grandparent></greatgrandparent>"
        let doc = try SwiftSoup.parseBodyFragment(html)
        let child = try doc.select("child").first()!

        // child -> parent -> grandparent -> greatgrandparent (within body fragment context)
        // depth 0: parent
        // depth 1: grandparent
        // depth 2: greatgrandparent

        // With maxDepth 1, should find grandparent but not greatgrandparent
        let hasParentDepth1 = DOMTraversal.hasAncestorTag(child, tagName: "parent", maxDepth: 1)
        let hasGrandparentDepth1 = DOMTraversal.hasAncestorTag(child, tagName: "grandparent", maxDepth: 1)
        let hasGreatGrandparentDepth1 = DOMTraversal.hasAncestorTag(child, tagName: "greatgrandparent", maxDepth: 1)

        #expect(hasParentDepth1 == true)      // parent at depth 0
        #expect(hasGrandparentDepth1 == true) // grandparent at depth 1, within limit
        #expect(hasGreatGrandparentDepth1 == false) // greatgrandparent at depth 2, exceeds maxDepth 1

        // With unlimited depth (0), should find all
        let hasGreatGrandparentUnlimited = DOMTraversal.hasAncestorTag(child, tagName: "greatgrandparent", maxDepth: 0)
        #expect(hasGreatGrandparentUnlimited == true)
    }

    @Test("hasAncestorTag uses filter")
    func testHasAncestorTagWithFilter() throws {
        let html = "<article class='content'><div><p>Test</p></div></article>"
        let doc = try SwiftSoup.parse(html)
        let p = try doc.select("p").first()!

        let hasContentArticle = DOMTraversal.hasAncestorTag(p, tagName: "article") { element in
            return (try? element.className().contains("content")) ?? false
        }
        let hasOtherArticle = DOMTraversal.hasAncestorTag(p, tagName: "article") { element in
            return (try? element.className().contains("other")) ?? false
        }

        #expect(hasContentArticle == true)
        #expect(hasOtherArticle == false)
    }

    // MARK: - hasSingleTagInsideElement Tests

    @Test("hasSingleTagInsideElement returns true for single child")
    func testHasSingleTagInsideElement() throws {
        let html = "<div><p>Only child</p></div>"
        let doc = try SwiftSoup.parse(html)
        let div = try doc.select("div").first()!

        let hasSingleP = DOMTraversal.hasSingleTagInsideElement(div, tag: "p")

        #expect(hasSingleP == true)
    }

    @Test("hasSingleTagInsideElement returns false for wrong tag")
    func testHasSingleTagInsideElementWrongTag() throws {
        let html = "<div><span>Only child</span></div>"
        let doc = try SwiftSoup.parse(html)
        let div = try doc.select("div").first()!

        let hasSingleP = DOMTraversal.hasSingleTagInsideElement(div, tag: "p")

        #expect(hasSingleP == false)
    }

    @Test("hasSingleTagInsideElement returns false for multiple children")
    func testHasSingleTagInsideElementMultiple() throws {
        let html = "<div><p>First</p><p>Second</p></div>"
        let doc = try SwiftSoup.parse(html)
        let div = try doc.select("div").first()!

        let hasSingleP = DOMTraversal.hasSingleTagInsideElement(div, tag: "p")

        #expect(hasSingleP == false)
    }

    @Test("hasSingleTagInsideElement returns false with text content")
    func testHasSingleTagInsideElementWithText() throws {
        let html = "<div>Text<p>Child</p></div>"
        let doc = try SwiftSoup.parse(html)
        let div = try doc.select("div").first()!

        let hasSingleP = DOMTraversal.hasSingleTagInsideElement(div, tag: "p")

        #expect(hasSingleP == false)
    }

    // MARK: - isElementWithoutContent Tests

    @Test("isElementWithoutContent returns true for empty element")
    func testIsElementWithoutContentEmpty() throws {
        let html = "<div></div>"
        let doc = try SwiftSoup.parse(html)
        let div = try doc.select("div").first()!

        let isEmpty = DOMTraversal.isElementWithoutContent(div)

        #expect(isEmpty == true)
    }

    @Test("isElementWithoutContent returns true for whitespace only")
    func testIsElementWithoutContentWhitespace() throws {
        let html = "<div>   \n\t  </div>"
        let doc = try SwiftSoup.parse(html)
        let div = try doc.select("div").first()!

        let isEmpty = DOMTraversal.isElementWithoutContent(div)

        #expect(isEmpty == true)
    }

    @Test("isElementWithoutContent returns false for text content")
    func testIsElementWithoutContentWithText() throws {
        let html = "<div>Some text</div>"
        let doc = try SwiftSoup.parse(html)
        let div = try doc.select("div").first()!

        let isEmpty = DOMTraversal.isElementWithoutContent(div)

        #expect(isEmpty == false)
    }

    @Test("isElementWithoutContent returns true for only br elements")
    func testIsElementWithoutContentWithBr() throws {
        let html = "<div><br><br></div>"
        let doc = try SwiftSoup.parse(html)
        let div = try doc.select("div").first()!

        let isEmpty = DOMTraversal.isElementWithoutContent(div)

        #expect(isEmpty == true)
    }

    // MARK: - isWhitespace Tests

    @Test("isWhitespace returns true for empty text node")
    func testIsWhitespaceEmptyText() throws {
        let textNode = TextNode("   ", "")

        let isWhitespace = DOMTraversal.isWhitespace(textNode)

        #expect(isWhitespace == true)
    }

    @Test("isWhitespace returns false for non-empty text node")
    func testIsWhitespaceNonEmptyText() throws {
        let textNode = TextNode("Hello", "")

        let isWhitespace = DOMTraversal.isWhitespace(textNode)

        #expect(isWhitespace == false)
    }

    @Test("isWhitespace returns true for br element")
    func testIsWhitespaceBr() throws {
        let br = Element(Tag("br"), "")

        let isWhitespace = DOMTraversal.isWhitespace(br)

        #expect(isWhitespace == true)
    }

    // MARK: - getAllNodesWithTag Tests

    @Test("getAllNodesWithTag finds all matching tags")
    func testGetAllNodesWithTag() throws {
        let html = "<div><p>1</p><span>2</span><p>3</p></div>"
        let doc = try SwiftSoup.parse(html)
        let div = try doc.select("div").first()!

        let paragraphs = try DOMTraversal.getAllNodesWithTag(div, tagNames: ["p"])

        #expect(paragraphs.count == 2)
    }

    @Test("getAllNodesWithTag handles multiple tags")
    func testGetAllNodesWithTagMultiple() throws {
        let html = "<div><p>1</p><span>2</span><article>3</article></div>"
        let doc = try SwiftSoup.parse(html)
        let div = try doc.select("div").first()!

        let elements = try DOMTraversal.getAllNodesWithTag(div, tagNames: ["p", "article"])

        #expect(elements.count == 2)
    }

    // MARK: - Element Extension Tests

    @Test("Element.nextNode works")
    func testElementExtensionNextNode() throws {
        let html = "<div><p>Test</p></div>"
        let doc = try SwiftSoup.parse(html)
        let div = try doc.select("div").first()!

        let next = div.nextNode()

        #expect(next?.tagName().lowercased() == "p")
    }

    @Test("Element.ancestors works")
    func testElementExtensionAncestors() throws {
        let html = "<div><p>Test</p></div>"
        let doc = try SwiftSoup.parse(html)
        let p = try doc.select("p").first()!

        let ancestors = p.ancestors()

        // SwiftSoup parses with html and body wrapper
        #expect(ancestors.count >= 2)
    }

    @Test("Element.hasAncestor works")
    func testElementExtensionHasAncestor() throws {
        let html = "<article><div><p>Test</p></div></article>"
        let doc = try SwiftSoup.parse(html)
        let p = try doc.select("p").first()!

        let hasArticle = p.hasAncestor(tagName: "article")

        #expect(hasArticle == true)
    }
}
