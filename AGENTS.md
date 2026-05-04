# Agent Guidelines for Swift Readability

This document contains **principles, coding standards, and development guidelines** for working in this codebase.

**For implementation status and progress tracking, see `PLAN.md`.**

---

## Core Principles

### 1. Language Policy

- Communicate with the user in Chinese.
- Write code comments and repository documentation in English unless explicitly requested otherwise.

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

This remains the default meaning of "porting": Mozilla parity is the baseline and the first reference point for implementation decisions.

**Guidelines:**
- When in doubt, copy Mozilla's implementation exactly
- If we MUST deviate, document why in code comments
- Improvements should be opt-in via `ReadabilityOptions`, never default behavior
- If downstream integration requires stable serialization hints, keep them narrow, explicit, and documented as an output contract instead of changing generic extraction semantics

#### Ex-pages Quality Bar

For curated `ex-pages` fixtures, do **not** assume Mozilla output is automatically the desired final target.

- Treat Mozilla output as the starting reference, not the ceiling
- If Swift output is clearly better for the intended reading experience, prefer the better result
- Keep such deviations narrow, intentional, and backed by a concrete captured case
- Document the intended target in fixture expectations instead of forcing ex-pages back to Mozilla when Mozilla retains obvious noise or misses useful content
- Avoid broad heuristic changes just to satisfy a single ex-pages fixture; prefer targeted logic and explicit rationale

This means the project is no longer aiming for Mozilla-identical output in every curated case. The goal is:

1. Preserve Mozilla compatibility as the default behavior and regression baseline
2. Improve selected real captured cases where the desired output is clearly better than Mozilla
3. Encode those intentional improvements in `ex-pages` fixtures and supporting documentation

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
4. **Path Dependencies**: `CLI` uses `..` path dependency
5. **SPM Build Cache**: When adding or removing Swift source files, the build system may cache stale file lists. If a new file fails to compile (e.g. "cannot find 'Xxx' in scope"), delete `.build/` directories and rebuild:
   ```bash
   rm -rf .build CLI/.build && cd CLI && swift run ReadabilityCLI ...
   ```

### Site-Specific Rule Architecture

To reduce regression risk in real-world fixtures, all site-specific cleanup logic should be isolated under:
- `Sources/Readability/Internal/SiteRules/`

Current mechanism:
- Shared protocols live in `SiteRule.swift`
- Rule orchestration lives in `SiteRuleRegistry.swift`
- `ArticleCleaner` and `Readability` call registry entry points at fixed phases:
  - unwanted element cleanup
  - pre-conversion cleanup
  - share/social cleanup
  - serialization cleanup

Serialization compatibility contract:
1. If a site-specific serialization rule must annotate a `<pre>` block for downstream consumers, use `data-readability-pre-type`.
2. Allowed stable values are `markdown`, `code`, and `text`.
3. Omit the attribute when default `<pre>` behavior is desired.
4. Do not repurpose unrelated ad-hoc attributes for `<pre>` semantics.
5. Any intentional Mozilla-parity deviation that introduces this attribute must be documented in `README.md`, fixture expectations, and release notes/changelog.

Authoring rules:
1. Keep each rule focused on one site/mechanism (small selector surface).
2. Use deterministic selectors/thresholds; avoid broad global heuristics in site rules.
3. Prefer registry-based wiring over inlining site logic back into `ArticleCleaner`/`Readability`.
4. For Swift 6 strict concurrency, avoid static stored arrays of protocol metatypes in registry; use method-local rule lists.

Migration decision standard (should this be a site rule?):
1. Hard gate: the trigger is primarily site-specific (brand-specific id/class/data attributes, fixed module URL params, or stable site wording) and not reliably generalizable.
2. Score dimensions (practical checklist):
   - Trigger specificity: high
   - Cross-site generality: low
   - Regression blast radius if kept inline: high
   - Evidence strength: at least one reproducible real-world fixture
   - Lifecycle phase fit: clear placement in `unwanted` / `preConversion` / `share` / `postProcess` / `serialization`
   - Maintenance clarity: can be named and documented as one site+mechanism rule
3. Migration recommendation threshold:
   - Hard gate satisfied, and
   - At least 4 of 6 dimensions are site-rule leaning, and
   - Lifecycle phase is unambiguous.
4. Do not migrate when:
   - Logic is core Mozilla semantics or broadly reusable heuristics.
   - Rule depends on generic content structure without site identity.
   - Moving it would hide cross-site behavior that should remain in shared algorithm paths.
5. Exception (keep in core even with site markers):
   - If logic is a flow-compensation step inside a shared cleanup/extraction transaction
     (for example, rescue-before-remove behavior tightly coupled to the same traversal),
     keep it in core pipeline code instead of `SiteRules`.

Current candidate decisions:
1. `rescueStoryContinueLinks()` in `ArticleCleaner`: KEEP IN CORE.
   - Result: removing this rescue path regressed `realworld/nytimes-2` (loss of `#story-continues-1` jump block parity).
2. `story-continues` candidate-preservation checks in `ContentExtractor` / `ArticleCleaner`: REMOVED after verification.
   - Result: removing both checks caused no regressions in `RealWorldCompatibilityTests` and `MozillaCompatibilityTests`.
3. `normalizeKnownSectionWrappers()` in `ArticleCleaner`: MIGRATED to `SiteRules`.
   - Rule: `NYTimesCollectionHighlightsRule`
4. `normalizePhotoViewerWrappers()` in `ArticleCleaner`: MIGRATED to `SiteRules`.
   - Rule: `NYTimesPhotoViewerWrapperRule`
5. `trimLeadingCardSummaryPanels()` in `ArticleCleaner`: MIGRATED to `SiteRules`.
   - Rule: `NYTimesSpanishCardSummaryRule`
6. `normalizeSplitPrintInfoParagraphs()` in `ArticleCleaner`: MIGRATED to `SiteRules`.
   - Rule: `NYTimesSplitPrintInfoRule`
7. NYTimes-specific protection in `CandidateSelector.shouldKeepArticleCandidate()` (`article#story`): KEEP IN CORE.
   - Result: removing this guard regressed `realworld/nytimes-3` and `realworld/nytimes-4` (`article#story` promoted to outer `div#site-content`).
8. `photoviewer-wrapper` branch in `Readability.simplifyNestedElements()`: REMOVED after verification.
   - Result: after migrating NYTimes wrapper normalization to `SiteRules`, removing the branch caused no regressions in `RealWorldCompatibilityTests` and `MozillaCompatibilityTests`.
9. `ContentExtractor.shouldPreserveFigureImageWrapper()` `aspectratioplaceholder` guard: KEEP IN CORE.
   - Result: removing this guard regressed `realworld/medium-1` (`figure > div` collapsed to `figure > p`).
10. `ArticleCleaner.convertDivsToParagraphs()` single-paragraph wrapper preservation gate (`!shouldPreserveSingleParagraphWrapper(div)`): REMOVED after verification.
   - Result: removing this gate caused no regressions in `RealWorldCompatibilityTests` and `MozillaCompatibilityTests`; redundant `ArticleCleaner.shouldPreserveSingleParagraphWrapper()` helper removed.
11. `ArticleCleaner.convertDivsToParagraphs()` media-control hierarchy gate (`!isWithinMediaControlHierarchy(div)`): REMOVED after verification.
   - Result: removing this gate caused no regressions in `RealWorldCompatibilityTests` and `MozillaCompatibilityTests`; redundant `ArticleCleaner.isWithinMediaControlHierarchy()` helper removed.
12. `ArticleCleaner.collapseSingleDivWrappers()` `data-testid` skip guard: KEEP IN CORE.
   - Result: removing this guard regressed `realworld/nytimes-3` and `realworld/nytimes-4` (expected `data-testid="photoviewer-wrapper"` collapsed to `photoviewer-children`).

Validation requirements for any new/modified site rule:
1. Run targeted fixture(s) first (single real-world test).
2. Run full `RealWorldCompatibilityTests`.
3. Run full `MozillaCompatibilityTests`.
4. If behavior intentionally deviates from Mozilla parity, document rationale near the rule and in planning docs.
5. If the rule adds serialized compatibility attributes, document the exact contract and downstream expectation.

---

## Testing Guidelines

### Running Tests

Repository test work is usually done in four buckets:

- `MozillaCompatibilityTests`
- `RealWorldCompatibilityTests`
- `ExPagesCompatibilityTests`
- other library-level regression suites

#### Commands

**Run Our Extra Real-world Pages Tests**
```bash
swift test --filter ExPagesCompatibilityTests
```

**Run Mozilla Real-world Page Tests**
```bash
swift test --filter RealWorldCompatibilityTests
```

**Run Mozilla Feature Compatibility Tests**
```bash
swift test --filter MozillaCompatibilityTests
```

**Run Specific Test**
```bash
swift test --filter ExPagesCompatibilityTests.test1a232Content
```

#### General Workflow for Case Verification

Default validation order during case work:

1. Run `ExPagesCompatibilityTests` for locally captured cases.
2. Run `RealWorldCompatibilityTests`.
3. Run `MozillaCompatibilityTests`.

For staged-case workflow and CLI-based debugging steps, see `CLI/README.md`.

### Test Failure Response Protocol

When a test fails:

1. **Do NOT modify test to make it pass**
2. Analyze if implementation is incorrect
3. Check if it is a known technical limitation (`SwiftSoup` vs `JSDOM`)
4. If fixable: fix implementation
5. If limitation: mark with `withKnownIssue()` and document
6. If unsure: discuss before proceeding

---

## Quick Reference

### Debugging Tool Usage
```bash
cd CLI
swift run ReadabilityCLI fetch <url> --name <case>
swift run ReadabilityCLI parse <case>
swift run ReadabilityCLI review <case>
swift run ReadabilityCLI commit <case>

swift run ReadabilityCLI inspect <case>
```

### External Resources
- Mozilla Readability: https://github.com/mozilla/readability
  - Local clone at `./ref/mozilla-readability`
- SwiftSoup: https://github.com/scinfu/SwiftSoup
