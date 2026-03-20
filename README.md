# Swift Readability

Pure Swift port of Mozilla Readability, focused on output parity and production use without `WKWebView`.

## Requirements

- Swift tools `6.2`
- Platforms: `macOS 13+`, `iOS 16+`

## Installation

Add this package in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/neolee/swift-readability.git", from: "1.0.0")
]
```

## Public API

```swift
public struct Readability {
    public init(html: String, baseURL: URL? = nil, options: ReadabilityOptions = .default) throws
    public func parse() throws -> ReadabilityResult
  public func parseWithInspection() throws -> (result: ReadabilityResult, report: InspectionReport)
}
```

```swift
public struct InspectionReport: Sendable {
  public let passes: [PassAttempt]
}
```

```swift
public struct ReadabilityResult: Sendable {
    public let title: String
    public let byline: String?
    public let dir: String?
    public let lang: String?
    public let content: String
    public let textContent: String
    public let excerpt: String?
    public let length: Int
    public let siteName: String?
    public let publishedTime: String?
}
```

## Minimal Usage

```swift
import Foundation
import Readability

let html: String = ...
let baseURL = URL(string: "https://example.com/article")

let readability = try Readability(html: html, baseURL: baseURL)
let result = try readability.parse()

print(result.title)
print(result.textContent)
```

`Readability` is single-use. Calling `parse()` twice on the same instance throws `ReadabilityError.alreadyParsed`.

## Diagnostics

Use `parseWithInspection()` when you need extraction diagnostics instead of just the final article result.

```swift
import Foundation
import Readability

let parser = try Readability(html: html, baseURL: baseURL)
let (result, report) = try parser.parseWithInspection()

print(result.title)
print(report.passes.count)
```

`InspectionReport` captures the multi-pass extraction trace, including candidate scoring, promotion decisions, sibling inclusion decisions, and site-rule decisions. This API is intended for debugging and calibration workflows such as the `ReadabilityCLI inspect` command.

## Options

```swift
var options = ReadabilityOptions()
options.nbTopCandidates = 5
options.charThreshold = 500
options.keepClasses = false
options.disableJSONLD = false
options.classesToPreserve = ["caption"]
options.linkDensityModifier = 0.0

let readability = try Readability(html: html, baseURL: baseURL, options: options)
let result = try readability.parse()
```

Option notes:
- `maxElemsToParse`: currently deferred/no-op.
- `useCustomSerializer`: currently deferred/no-op.
- `allowedVideoRegex`: defaults to Mozilla-compatible built-in pattern when empty.

## Error Handling

```swift
do {
    let parser = try Readability(html: html, baseURL: baseURL)
    let result = try parser.parse()
    print(result.title)
} catch ReadabilityError.noContent {
    print("No readable article content found.")
} catch ReadabilityError.contentTooShort(let actual, let threshold) {
    print("Content too short: \(actual) < \(threshold)")
} catch ReadabilityError.alreadyParsed {
    print("Create a new Readability instance for each parse.")
} catch {
    print("Parse failed: \(error)")
}
```

## Compatibility Scope

This project tracks Mozilla parity with strict fixture-based tests:
- `ExPagesCompatibilityTests`
- `MozillaCompatibilityTests`
- `RealWorldCompatibilityTests`

Current imported suites are passing in this repository state.

## HTML Output Contract

The default goal of this library is Mozilla Readability output parity. However, the serialized HTML may include narrowly-scoped compatibility attributes when a site-specific structure cannot be represented safely by generic HTML semantics alone.

Current stable `<pre>` contract:
- `data-readability-pre-type="markdown"`: the `<pre>` text is Markdown source and downstream HTML-to-Markdown converters may emit the raw text directly instead of wrapping it in a fenced code block.
- `data-readability-pre-type="code"`: the `<pre>` is explicitly a code block and downstream converters should keep fenced-code behavior.
- `data-readability-pre-type="text"`: the `<pre>` is plain preformatted text. Downstream handling may continue to use fenced-code fallback until a better plain-text rendering path is defined.
- No `data-readability-pre-type`: preserve existing default handling for ordinary `<pre>` blocks.

Current usage:
- `antirez-1` emits `data-readability-pre-type="markdown"` on the extracted article-body `<pre>` because the source block contains Markdown prose rather than code.

## Performance and Benchmarking

Use [CLI/README.md](CLI/README.md) for staged-case capture, inspection, review, and promotion into the incremental `ex-pages` baseline.

This repository does not currently ship a committed benchmark guide under `CLI/Benchmark/`. If you maintain an external benchmark workflow for release validation, record the resulting artifacts alongside the release notes.

## Known Limitations

- Parsing quality depends on source HTML quality; heavily script-dependent pages may not have enough static content.
- Some site-specific cleanup is handled via `SiteRules`; behavior is fixture-driven to reduce broad regressions.
- Some site-specific metadata and excerpt recovery is also handled via `SiteRules` when a site uses stable non-Mozilla structures.
- Two `ReadabilityOptions` fields are reserved/deferred (`maxElemsToParse`, `useCustomSerializer`).

## Troubleshooting

- `ReadabilityError.noContent`:
  - Check whether the input HTML contains server-rendered article text.
  - Lower `charThreshold` only if your content is intentionally short.
- Unexpected author/title metadata:
  - Toggle `disableJSONLD` to compare JSON-LD vs meta-tag extraction behavior.
- Output contains unwanted classes:
  - Set `keepClasses = false` and only whitelist required classes with `classesToPreserve`.
- Result mismatch against fixtures:
  - Run `swift test --filter ExPagesCompatibilityTests` first, then `RealWorldCompatibilityTests`, then `MozillaCompatibilityTests`.

## License

Open sourced under MIT license. See [LICENSE.md](LICENSE.md).

## Acknowledgments

- [Mozilla Readability](https://github.com/mozilla/readability)
- [SwiftSoup](https://github.com/scinfu/SwiftSoup)
