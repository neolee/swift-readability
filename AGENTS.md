# Agent Guidelines for Swift Readability

This document contains **principles and long-term guidelines** for working in this codebase. For specific implementation status and testing progress, see `PLAN.md` and `TESTS.md`.

---

## Core Principles

### 1. Language Policy

**All documentation and code comments must be in English**, except:
- `INIT.md` (project planning document in Chinese)
- User-facing documentation (can be multilingual)

**Rationale**: This is an open-source project that may be used globally. English ensures accessibility for all contributors.

### 2. Documentation Style

#### No Emoji
Do not use emoji in documentation. Use text-based indicators instead.

**Wrong:**
```markdown
- (checkmark) Completed feature
- (cross) Broken implementation  
- (warning) Warning message
```

**Correct:**
```markdown
- [x] Completed feature
- [ ] Broken implementation
- WARNING: Warning message
```

#### Code Formatting
Use backticks `` ` `` for:
- Class names: `Readability`, `ReadabilityOptions`
- Function names: `parse()`, `extractTitle()`
- Variable/property names: `charThreshold`, `keepClasses`
- Type names: `String`, `Sendable`, `Element`
- Library names: `SwiftSoup`, `Mozilla Readability.js`
- HTML tags: `<div>`, `<article>`, `<script>`
- File names: `Readability.swift`, `Package.swift`
- Swift language features: `@MainActor`, `throws`, `async`

**Examples:**
- Use `Sendable` for public types
- Call `parse()` to extract content
- Remove `<script>` tags during preprocessing
- Configure via `ReadabilityOptions`

### 3. "Port First, Improve Later"

**Unless there are exceptional circumstances (e.g., implementation is prohibitively difficult or unreasonably complex), the default answer is always: replicate the original `Mozilla Readability.js` logic and output as closely as possible.**

This is what "porting" means. We are creating a Swift version that produces **identical output** to the original JavaScript implementation.

**Guidelines:**
- When in doubt, copy Mozilla's implementation exactly
- If we MUST deviate, document why in code comments
- Improvements should be opt-in via `ReadabilityOptions`, never default behavior

**Examples:**
- WRONG: Custom title cleaning that removes all separators
- CORRECT: Follow Mozilla's exact algorithm (split by `| - – -- \ / > >>`, `h1` fallback, word count checks, etc.)

### 4. Testing Philosophy

#### Tests Must NOT Accommodate Flawed Implementations

**FORBIDDEN:**
```swift
// WRONG: Accepts any containment relationship
#expect(result.title.contains(expectedTitle) || expectedTitle.contains(result.title))

// WRONG: Only checks length, not content quality
#expect(result.length > 500)
```

**REQUIRED:**
```swift
// CORRECT: Exact match or clear deviation tracking
#expect(result.title == expectedTitle)

// CORRECT: Compare against expected HTML structure
#expect(normalizeHTML(result.content) == normalizeHTML(expectedHTML))
```

#### Mozilla Test Cases Must Be Used As-Is

- Use `source.html` exactly as provided - no modifications
- Use `expected.html` as the gold standard
- Use `expected-metadata.json` for exact assertions
- Replicate Mozilla's test behavior exactly

#### Failed Tests Must Be Investigated

When a test fails:
1. **STOP** - Do not modify the test to pass
2. **ANALYZE** - Is implementation incorrect?
3. **INVESTIGATE** - Is it a technical limitation (`SwiftSoup` vs `JSDOM`)?
4. **DECIDE** - Fix it or document as known limitation
5. **DOCUMENT** - Explain why in comments

**Never** comment out failing tests or make them less strict.

### 5. Issue Prioritization

When encountering test failures or bugs:

- **P0 (Critical)**: Common news sites, major blogs - must fix immediately
- **P1 (High)**: Moderate traffic sites - should fix soon
- **P2 (Medium)**: Edge cases - document and schedule
- **P3 (Low)**: Rare formats - can defer with documentation

---

## Code Standards

### Swift Style

- **Swift 6.2** with strict concurrency checking
- **No `@MainActor`** - concurrency-friendly by design
- Use `Sendable` for public types
- Prefer `throws` over `Result` types for error handling

### Public API

```swift
public struct Readability {
    public init(html: String, baseURL: URL? = nil, options: ReadabilityOptions = .default) throws
    public func parse() throws -> ReadabilityResult
}

public struct ReadabilityResult: Sendable {
    public let title: String
    public let byline: String?
    public let content: String        // HTML
    public let textContent: String    // Plain text
    public let excerpt: String?
    public let length: Int
}
```

### Common Patterns

**SwiftSoup DOM manipulation:**
```swift
import SwiftSoup

let doc = try SwiftSoup.parse(html)
let elements = try doc.select("p, div, article")
try elements.remove()
let text = try element.text()
```

**Swift Testing:**
```swift
import Testing
@Test func example() async throws {
    let result = try Readability(html: html).parse()
    #expect(result.title == "Expected")
}
```

### Gotchas

1. **Two Package Directories**: Always `cd` into correct directory before `swift` commands
2. **SwiftSoup Tag Replacement**: Cannot change tag names directly - create new `Element` and move children
3. **Concurrency**: Never add `@MainActor` - this defeats the purpose of `WKWebView`-free implementation
4. **Path Dependencies**: `ReadabilityCLI` uses `../Readability` path dependency

---

## Quick Reference

### Commands
```bash
cd Readability && swift build && swift test
cd ReadabilityCLI && swift run ReadabilityCLI <url> --text-only
```

### Key Files
- `Sources/Readability/Readability.swift` - Main implementation
- `Tests/ReadabilityTests/MozillaCompatibilityTests.swift` - Compatibility tests
- `Package.swift` - Swift 6.2, depends on `SwiftSoup`

### External Resources
- Mozilla Readability: https://github.com/mozilla/readability
  - Local clone at `./ref/mozilla-readability`
- SwiftSoup: https://github.com/scinfu/SwiftSoup

---

## See Also

- `PLAN.md` - Feature roadmap and implementation phases
- `TESTS.md` - Testing strategy and progress tracking
- `INIT.md` - Original project planning (Chinese)
