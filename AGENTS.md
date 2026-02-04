# Agent Guidelines for Swift Readability

This document helps AI agents work effectively in the Swift Readability codebase.

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
- **Mozilla Readability**: https://github.com/mozilla/readability
- **SwiftSoup**: https://github.com/scinfu/SwiftSoup

## Adding New Features

1. **Library changes**: Edit files in `Readability/Sources/Readability/`
2. **CLI changes**: Edit `ReadabilityCLI/Sources/main.swift`
3. **Tests**: Add to `Readability/Tests/ReadabilityTests/` using Swift Testing
4. **Build and test** from respective package directories
5. **Update README.md** if adding user-facing features

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
