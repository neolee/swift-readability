# Agent Guidelines for Swift Readability

This document helps AI agents work effectively in the Swift Readability codebase.

## Critical Testing Principles (MUST READ)

These principles override all other considerations when writing or modifying tests:

### 1. Tests Must NOT Accommodate Flawed Implementations

**FORBIDDEN - Never write tests like this:**
```swift
// ❌ WRONG: Accepts any containment relationship
#expect(result.title.contains(expectedTitle) || expectedTitle.contains(result.title))

// ❌ WRONG: Only checks length, not content quality
#expect(result.length > 500)

// ❌ WRONG: Vague existence checks
#expect(result.textContent.contains("some content"))
```

**REQUIRED - Write tests like this:**
```swift
// ✅ CORRECT: Exact match or clear deviation tracking
#expect(result.title == expectedTitle, "Title mismatch. Expected: '\(expectedTitle)', got: '\(result.title)'")

// ✅ CORRECT: Compare against expected output structure
let normalizedResult = normalizeHTML(result.content)
let normalizedExpected = normalizeHTML(testCase.expectedHTML)
#expect(normalizedResult == normalizedExpected, "HTML structure doesn't match")

// ✅ CORRECT: Measure semantic similarity
let matchRatio = calculateContentMatch(result.textContent, expectedText)
#expect(matchRatio > 0.85, "Content match ratio \(matchRatio) below threshold")
```

### 2. Mozilla Test Cases Must Be Used As-Is

When importing Mozilla test cases:
- ✅ Use `source.html` exactly as provided - no modifications
- ✅ Use `expected.html` as the gold standard for verification
- ✅ Use `expected-metadata.json` for exact metadata assertions
- ✅ Replicate Mozilla's test behavior and assertion logic

**The goal is behavioral equivalence with Mozilla Readability.js, not just "working" code.**

### 3. Failed Tests Must Be Investigated, Not Worked Around

When a test fails:
1. **STOP** - Do not modify the test to pass
2. **ANALYZE** - Is our implementation incorrect?
3. **INVESTIGATE** - Is it a technical limitation (SwiftSoup vs JSDOM)?
4. **DECIDE** - Can we fix it, or should we document it as a known limitation?
5. **DOCUMENT** - If intentionally not matching, explain why in comments

**Never comment out failing tests or make them less strict to get a "passing" build.**

### 4. Test Categorization for Known Issues

If a test cannot pass due to technical limitations:
```swift
@Test("Known limitation: Byline extraction from JSON-LD")
func testBylineExtraction() async throws {
    // Known issue: We don't yet implement JSON-LD parsing
    // Tracked in: PLAN.md Phase 3
    // Original Mozilla test: test-pages/001/expected-metadata.json
    withKnownIssue("JSON-LD metadata extraction not yet implemented") {
        let result = try readability.parse()
        #expect(result.byline == "Nicolas Perriault")
    }
}
```

### 5. Importance-Based Prioritization

When encountering difficult test failures, assess by frequency of real-world occurrence:
- **P0 (Critical)**: Common news sites, major blogs - must fix
- **P1 (High)**: Moderate traffic sites - should fix
- **P2 (Medium)**: Edge cases - document and decide
- **P3 (Low)**: Rare formats - can defer with documentation

---

## Core Porting Principle

### "Port First, Improve Later"

**Unless there are exceptional circumstances (e.g., implementation is prohibitively difficult or unreasonably complex), the default answer is always: replicate the original logic and target standards as closely as possible.**

This is what "porting" means. We are creating a Swift version of Mozilla Readability.js that produces **identical output** to the original.

### Implementation Guidelines

1. **Default to Copy**: When in doubt, copy Mozilla's implementation exactly
2. **Document Deviations**: If we MUST deviate, document why in code comments
3. **Improvements are Secondary**: Better ideas should be recorded for future enhancement via options, not implemented as default behavior

### Examples

**Title Processing** (current issue):
- ❌ Wrong: Remove all separators, keep longest part
- ✅ Right: Follow Mozilla's algorithm: split by `| - – — \ / > »`, use h1 as fallback, word count checks, etc.

**Excerpt Extraction** (current issue):
- ❌ Wrong: Always use first paragraph
- ✅ Right: Priority order: JSON-LD > dc:description > og:description > twitter:description > meta description > first paragraph

### Future Improvements

If we identify improvements over Mozilla's implementation:
1. First achieve 1:1 compatibility
2. Record improvement ideas in IMPROVEMENTS.md
3. Implement as **opt-in options** via `ReadabilityOptions`, never as default behavior
4. Clearly document differences from Mozilla behavior

---

## Project Overview

---

## Project Overview

This is a pure Swift implementation of Mozilla's Readability.js algorithm for extracting article content from HTML. It consists of two Swift packages:

- **`Readability/`** - Core library (Swift Package)
- **`ReadabilityCLI/`** - Command-line tool that uses the library

**Key characteristics:**
- Pure Swift implementation using SwiftSoup (no WKWebView/JavaScript)
- Concurrency-friendly (no `@MainActor` constraints)
- Swift 6.2+ with macOS 13+ / iOS 16+ targets

## Essential Commands

### Building

```bash
# Build the library
cd Readability && swift build

# Build the CLI
cd ReadabilityCLI && swift build

# Build both (from repo root)
cd Readability && swift build && cd ../ReadabilityCLI && swift build
```

### Testing

```bash
# Run library tests
cd Readability && swift test

# Tests use Swift Testing framework (not XCTest)
# Test files: Readability/Tests/ReadabilityTests/*.swift
```

### Running the CLI

```bash
# From ReadabilityCLI directory
swift run ReadabilityCLI <url>
swift run ReadabilityCLI --text-only <url>
swift run ReadabilityCLI --json <url>

# From stdin
cat file.html | swift run ReadabilityCLI --text-only
```

### Dependency Management

```bash
# Resolve dependencies
cd Readability && swift package resolve

# Update dependencies
cd Readability && swift package update
```

## Project Structure

```
Readability/                    # Core library package
├── Package.swift              # Swift 6.2, depends on SwiftSoup
├── Sources/
│   └── Readability/
│       ├── Readability.swift       # Main entry point
│       └── ReadabilityResult.swift # Result struct (Sendable)
└── Tests/
    └── ReadabilityTests/
        └── ReadabilityTests.swift  # Swift Testing tests

ReadabilityCLI/                # CLI executable package
├── Package.swift              # Depends on local Readability package
├── Sources/
│   └── main.swift             # CLI implementation (@main struct)
└── README.md                  # CLI usage examples
```

**Important:** These are two separate Swift packages, not a workspace. ReadabilityCLI references Readability via path dependency: `.package(path: "../Readability")`.

## Code Patterns & Conventions

### Swift Style

- **Swift 6.2** with strict concurrency checking
- **No `@MainActor`** - keep code concurrency-friendly
- Use **`Sendable`** for public types (see `ReadabilityResult`)
- Prefer **`throws`** over Result types for error handling

### Public API Design

```swift
// Main entry point
public struct Readability {
    public init(html: String, baseURL: URL? = nil) throws
    public func parse() throws -> ReadabilityResult
}

// Result type - must be Sendable
public struct ReadabilityResult: Sendable {
    public let title: String
    public let byline: String?
    public let content: String        // HTML
    public let textContent: String    // Plain text
    public let excerpt: String?
    public let length: Int
}
```

### Error Handling

```swift
// Use specific error types when needed
enum ReadabilityError: Error {
    case noContent
    case contentTooShort
    case parsingFailed(underlying: Error)
}

// Functions that can fail should throw
func parse() throws -> ReadabilityResult
```

### HTML Parsing with SwiftSoup

```swift
import SwiftSoup

// Common patterns:
let doc = try SwiftSoup.parse(html)
let elements = try doc.select("p, div, article")
try elements.remove()  // Remove elements
let text = try element.text()  // Get text content
let html = try element.outerHtml()  // Get HTML
```

### Testing Patterns

Uses **Swift Testing** (not XCTest):

```swift
import Testing
@testable import Readability

@Test func example() async throws {
    let html = "<html>...</html>"
    let readability = try Readability(html: html, baseURL: nil)
    let result = try readability.parse()

    #expect(result.title == "Expected Title")
    #expect(result.textContent.contains("Expected content"))
}
```

Use `#expect()` for assertions, not `XCTAssert*`.

## Key Dependencies

- **SwiftSoup** (^2.11.3) - HTML parsing library
  - GitHub: https://github.com/scinfu/SwiftSoup
  - Docs: CSS selector support, DOM manipulation

## Implementation Notes

### Current Implementation Status

**Phase 1 Complete**: Architecture and configuration system ready. See **PLAN.md** for detailed roadmap.

**Completed** (Phase 1):
- ✅ `ReadabilityOptions` - Configuration system with all major options
- ✅ `ReadabilityError` - Proper error types with descriptions
- ✅ `Internal/` directory structure with `Configuration.swift` and `DOMHelpers.swift`
- ✅ Mozilla test suite integration (4 test cases, 9 tests passing)
- ✅ Test loader infrastructure for easy test case addition

**Completed** (MVP):
- Basic document preparation (script/style removal, template removal)
- BR tag handling
- Font tag replacement
- Title extraction from `<title>` and `<h1>` with separator cleaning
- Content scoring (tag weights, text length, comma count, link density, class/id patterns)
- Article extraction with ancestor score propagation
- Attribute cleanup with `keepClasses` option
- Character threshold validation

**Pending** (see **PLAN.md** for roadmap):
- Phase 2: Advanced document preprocessing
- Phase 3: JSON-LD, Open Graph, Twitter Cards metadata
- Phase 4: Enhanced scoring algorithm (top N candidates, sibling merging)
- Phase 5: Conditional cleaning (`_cleanConditionally`)
- Phase 6: Advanced features (pagination, code block protection)

### Algorithm Structure (Readability.swift)

The main parsing follows Mozilla's Readability.js algorithm:

1. **`prepDocument()`** - Remove scripts, styles, normalize structure
2. **`extractTitle()`** - Extract and clean title from `<title>` or `<h1>`
3. **`grabArticle()`** - Score nodes and find best content container
4. **`cleanArticle()`** - Remove unwanted attributes and elements
5. **`extractExcerpt()`** - Get first substantial paragraph

### Scoring Algorithm

When modifying content scoring in `scoreElement()`:

- Base scores: div/article/section (+5), pre/td/blockquote (+3), p (+1)
- Text length: +1 per 100 characters
- Commas: +1 per comma (density indicator)
- Link density penalty: `score * (1 - linkDensity)`
- Class/ID patterns: +25 for positive (article, content, post), -25 for negative (comment, footer, nav)

### Gotchas

1. **Two Package Directories**: Always `cd` into the correct package directory before running `swift` commands. The packages are independent.

2. **SwiftSoup Tag Replacement**: SwiftSoup doesn't support changing tag names directly. To replace a tag, create a new Element and move children:
   ```swift
   let replacement = Element(Tag("div"), baseUri)
   for child in element.children() {
       try? replacement.appendChild(child)
   }
   try? element.replaceWith(replacement)
   ```

3. **Concurrency**: Do NOT add `@MainActor` to types. The whole point of this library is to avoid WKWebView's main-thread constraints.

4. **Sendable**: Keep `ReadabilityResult` and other public types `Sendable` for Swift 6 concurrency.

5. **Path Dependencies**: ReadabilityCLI uses a local path dependency. If you restructure directories, update the path in `ReadabilityCLI/Package.swift`.

## Build Artifacts

Build artifacts are in `.build/` directories (gitignored):
- `Readability/.build/`
- `ReadabilityCLI/.build/`

These are separate - building one doesn't build the other.

## Reference Documentation

- **INIT.md** - Original project planning document (Chinese)
- **README.md** - User-facing documentation
- **PLAN.md** - Step-by-step porting roadmap (read this next)
- **Mozilla Readability**: https://github.com/mozilla/readability
- **SwiftSoup**: https://github.com/scinfu/SwiftSoup

## Development Workflow

### Before Starting Work

1. Check **PLAN.md** for current phase and priorities
2. Run existing tests to establish baseline: `cd Readability && swift test`
3. Test CLI with real URLs: `cd ReadabilityCLI && swift run ReadabilityCLI <url> --text-only`

### During Development

1. **Make incremental changes** - one feature/method at a time
2. **Test frequently** - run `swift test` after each change
3. **Use CLI for real-world testing**:
   ```bash
   cd ReadabilityCLI
   swift run ReadabilityCLI https://example.com/article --text-only
   ```
4. **Add test cases** for new functionality

### Verifying Changes

```bash
# Full verification script
cd Readability && swift build && swift test && \
cd ../ReadabilityCLI && swift build && \
echo "Build and tests passed!"
```

## Adding New Features

1. **Library changes**: Edit files in `Readability/Sources/Readability/`
2. **CLI changes**: Edit `ReadabilityCLI/Sources/main.swift`
3. **Tests**: Add to `Readability/Tests/ReadabilityTests/` using Swift Testing
4. **Build and test** from respective package directories
5. **Update README.md** if adding user-facing features

## Project Evolution

### File Structure Changes

As we implement more features from the roadmap, the source structure will evolve:

**Current (MVP)**:
```
Sources/Readability/
├── Readability.swift
└── ReadabilityResult.swift
```

**Target (Full Implementation)**:
```
Sources/Readability/
├── Readability.swift              # Main entry (simplified)
├── ReadabilityOptions.swift       # Configuration
├── ReadabilityResult.swift        # Result struct
├── ReadabilityError.swift         # Error types
└── Internal/
    ├── Configuration.swift        # Constants, regex patterns
    ├── DOMHelpers.swift           # DOM utilities
    ├── DocumentPreparer.swift     # prepDocument logic
    ├── ArticleGrabber.swift       # grabArticle core
    ├── ContentScorer.swift        # Scoring algorithm
    ├── ContentCleaner.swift       # Cleanup logic
    └── MetadataExtractor.swift    # Metadata extraction
```

When moving code to new files, ensure:
1. Imports are preserved
2. Access modifiers are correct (internal vs public)
3. Tests still pass
4. No duplicate symbols

## Common Tasks

### Add a new configuration option

1. Add property to `Readability` struct (internal)
2. Initialize via constructor parameter
3. Use in parsing logic
4. Add test coverage

### Add a new metadata extractor

1. Add private method in `Readability.swift`
2. Call from `parse()` or `extractTitle()`
3. Add to `ReadabilityResult` if exposing publicly
4. Update Sendable conformance if needed

### Fix extraction for specific site

1. Add test case with that site's HTML pattern
2. Modify scoring in `scoreElement()` or
3. Add selector to `removeJunkElements()` or
4. Adjust title extraction in `extractTitle()`/`cleanTitle()`
