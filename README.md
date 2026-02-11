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
- `MozillaCompatibilityTests`
- `RealWorldCompatibilityTests`

Current imported suites are passing in this repository state.

## Performance and Benchmarking

Use `CLI` as benchmark entry point:
- `./CLI/README.md`
- `./CLI/Benchmark/README.md`

## Known Limitations

- Parsing quality depends on source HTML quality; heavily script-dependent pages may not have enough static content.
- Some site-specific cleanup is handled via `SiteRules`; behavior is fixture-driven to reduce broad regressions.
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
  - Run `swift test --filter MozillaCompatibilityTests` first, then `RealWorldCompatibilityTests`.

## License

Open sourced under MIT license. See [LICENSE.md](LICENSE.md).

## Acknowledgments

- [Mozilla Readability](https://github.com/mozilla/readability)
- [SwiftSoup](https://github.com/scinfu/SwiftSoup)
