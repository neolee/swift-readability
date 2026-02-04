# Swift Readability

A pure Swift implementation of Mozilla's Readability.js, providing article extraction for HTML documents without WKWebView dependencies.

## Features

- **Pure Swift Implementation** — Built entirely in Swift using SwiftSoup, no JavaScript or WebView required
- **Concurrency-Friendly** — No `@MainActor` constraints, fully compatible with Swift's structured concurrency
- **Cancellation Support** — Responsive to `Task` cancellation, no indefinite blocking on JavaScript execution
- **WKWebView-Free** — Eliminates WebView-based deadlocks and timeout issues present in other implementations
- **Tested Against Mozilla Original** — Aligns with Mozilla's official test suite for consistent behavior
- **Configurable** — Fine-tune extraction parameters via `ReadabilityOptions`

## Installation

Add Swift Readability to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/neolee/swift-readability.git", from: "1.0.0")
]
```

Or in Xcode: **File → Add Package Dependencies** and enter the repository URL.

## Usage

```swift
import Readability

// Parse HTML string
let html = "<html>...</html>"
let result = try await Readability().parse(html: html, baseURL: url)

// Or parse from URL
let result = try await Readability().parse(url: articleURL)

print(result.title)         // Article title
print(result.content)       // Extracted HTML content
print(result.textContent)   // Plain text content
print(result.byline)        // Author name
print(result.excerpt)       // First paragraph for preview
```

## Configuration

Customize extraction behavior via `ReadabilityOptions`:

```swift
var options = ReadabilityOptions()
options.nbTopCandidates = 5      // Number of top candidates to consider
options.charThreshold = 500      // Minimum character count for valid content
options.keepClasses = false      // Preserve CSS classes in output
options.disableJSONLD = false    // Skip JSON-LD metadata parsing

let readability = Readability(options: options)
```

## Error Handling

```swift
do {
    let result = try await Readability().parse(html: html, baseURL: nil)
} catch ReadabilityError.noContent {
    print("Could not find article content")
} catch ReadabilityError.contentTooShort {
    print("Extracted content is too brief")
} catch {
    print("Parsing failed: \(error)")
}
```

## Why This Library?

Existing Swift Readability implementations often wrap JavaScript execution in `WKWebView`, causing:

- **Main thread blocking** — Forced `@MainActor` isolation
- **Uncancellable operations** — `withCheckedThrowingContinuation` doesn't respond to `Task` cancellation
- **Deadlocks** — JavaScript execution that never returns can hang `TaskGroup` indefinitely
- **Unreliable timeouts** — No way to force-terminate stuck WebView operations

This implementation solves all these issues by porting the algorithm to native Swift.

## Algorithm Overview

Based on Mozilla's Readability.js (~2,500 LOC), the extraction process:

1. **Pre-process** — Remove scripts, styles, and normalize document structure
2. **Score Nodes** — Calculate content scores based on text density, link ratio, and semantic hints
3. **Select Best** — Choose top candidate and merge related siblings
4. **Clean Up** — Remove clutter (ads, navigation, social widgets)
5. **Extract Metadata** — Parse JSON-LD, Open Graph, and meta tags

## Testing

The library is tested against Mozilla's official test suite, covering 50+ real-world websites including news, blogs, and forums.

```swift
// Example test
func testArticleExtraction() async throws {
    let html = loadTestResource("news-article")
    let result = try await Readability().parse(html: html, baseURL: nil)
    
    XCTAssertEqual(result.title, "Expected Title")
    XCTAssertTrue(result.textContent.contains("Expected content"))
}
```

## Requirements

- Swift 5.9+
- iOS 13+ / macOS 10.15+ / watchOS 6+ / tvOS 13+

## License

MIT License. See [LICENSE](LICENSE.md) for details.

## Acknowledgments

- [Mozilla Readability](https://github.com/mozilla/readability) — The original JavaScript implementation
- [SwiftSoup](https://github.com/scinfu/SwiftSoup) — HTML parsing library for Swift
