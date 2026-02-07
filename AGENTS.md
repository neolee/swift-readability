# Agent Guidelines for Swift Readability

This document contains **principles, coding standards, and development guidelines** for working in this codebase.

**For implementation status and progress tracking, see `PLAN.md`.**

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

### Site-Specific Rule Architecture

To reduce regression risk in real-world fixtures, all site-specific cleanup logic should be isolated under:
- `Readability/Sources/Readability/Internal/SiteRules/`

Current mechanism:
- Shared protocols live in `SiteRule.swift`
- Rule orchestration lives in `SiteRuleRegistry.swift`
- `ArticleCleaner` and `Readability` call registry entry points at fixed phases:
  - unwanted element cleanup
  - pre-conversion cleanup
  - share/social cleanup
  - serialization cleanup

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

---

## Testing Guidelines

### Running Tests

**Run All Tests:**
```bash
cd Readability && swift test
```

**Run Compatibility Tests Only:**
```bash
cd Readability && swift test --filter MozillaCompatibilityTests
```

**Run Specific Test:**
```bash
cd Readability && swift test --filter "001 - Title matches expected exactly"
```

### Test Infrastructure

**TestLoader.swift** - Utility for loading Mozilla test cases:
```swift
let testCase = TestLoader.loadTestCase(named: "001")
// Returns: sourceHTML, expectedHTML, expectedMetadata
```

**Mozilla Test Case Format:**
```
test-pages/001/
├── source.html            # Input HTML
├── expected.html          # Expected output
└── expected-metadata.json # Expected metadata
```

**DOM Comparison:** Structural traversal comparing:
- Node types (element, text)
- Tag names / descriptors
- Text content (normalized whitespace)
- Attributes (with path-based first-diff diagnostics)

### Importing New Mozilla Tests

When adding a new test case from Mozilla:

1. Copy test directory from `ref/mozilla-readability/test/test-pages/<name>/`
2. Add test methods to `MozillaCompatibilityTests.swift`:
   ```swift
   @Test("<name> - Title matches expected")
   func test<name>Title() async throws {
       guard let testCase = TestLoader.loadTestCase(named: "<name>") else {
           Issue.record("Failed to load test case")
           return
       }
       let readability = try Readability(html: testCase.sourceHTML, options: defaultOptions)
       let result = try readability.parse()
       #expect(result.title == testCase.expectedMetadata.title)
   }
   ```
3. Use `withKnownIssue()` for expected failures with clear documentation
4. Update PLAN.md to mark test as imported

### Test Failure Response Protocol

When a test fails:

1. **Do NOT modify test to make it pass**
2. Analyze if implementation is incorrect
3. Check if it is a known technical limitation (`SwiftSoup` vs `JSDOM`)
4. If fixable: fix implementation
5. If limitation: mark with `withKnownIssue()` and document
6. If unsure: discuss before proceeding

### Compatibility Debugging Playbook

When working on `MozillaCompatibilityTests`, use this workflow to keep iterations small and verifiable:

1. Reproduce with a single test first:
   - `cd Readability && swift test --filter testLinksInTables`
   - Only run full `MozillaCompatibilityTests` after the targeted case is stable.

2. Diagnose structurally, not by string output:
   - Capture the exact failing DOM path (`/html/body/...`) for both expected and actual nodes.
   - Compare node type, tag, and attributes at that path before changing implementation.

3. Identify mechanism-level root cause:
   - Trace where the mismatched node/attribute is introduced (`setNodeTag`, wrapper insertion, sibling merge, post-cleaning, serialization).
   - Avoid attribute-level patches unless the structural decision point is proven correct.

4. Port Mozilla control flow before local heuristics:
   - For `DIV -> P` behavior, keep Mozilla’s two-stage sequence:
     - wrap consecutive phrasing fragments in `<p>`
     - then apply `_hasSingleTagInsideElement("P")` + `linkDensity < 0.25` decision
   - Validate with tests that are sensitive to table/link density behavior (e.g., `links-in-tables`).

5. Keep temporary diagnostics if they improve future iterations:
   - Enhanced diff output (attribute maps + node paths) is allowed in tests.
   - Do not weaken assertions or relax matching rules.

6. Verify no regression after each fix:
   - Run the targeted test(s)
   - Then run `cd Readability && swift test --filter MozillaCompatibilityTests`
   - Track failure count deltas explicitly (e.g., `10 -> 9`).

### Real-world Debugging Playbook (Stage 3-R)

When working on `RealWorldCompatibilityTests`, use this workflow to keep scope controlled and outcomes verifiable:

1. One iteration fixes one case only.
   - Do not mix multiple failing real-world fixtures in one patch.
   - If a shared change is needed, still validate and merge case-by-case.

2. Keep fixes minimal and mechanism-driven.
   - Prefer rule-level, deterministic changes.
   - Prefer `SiteRules` for site-specific behavior; keep core logic generic unless behavior is clearly cross-site.

3. Use three-level validation for every iteration:
   - Targeted case test first (single fixture).
   - Full `RealWorldCompatibilityTests` next (report remaining failures explicitly).
   - Full `MozillaCompatibilityTests` as global safety gate.

4. Regression handling policy:
   - If a fix introduces unrelated regressions, rollback or narrow the rule before moving to the next case.
   - Keep `nytimes-*` and imported functional parity cases as high-sensitivity canaries.

5. Status reporting format per iteration:
   - Case fixed: `<case-name>`
   - Full real-world delta: `<before> -> <after>` failures
   - Mozilla gate: `pass/fail`
   - Remaining case queue in priority order

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

## Future Enhancements

### Comparator Diagnostics (P2)

**Current State:** `MozillaCompatibilityTests` now uses structural DOM comparison with node-path first-diff diagnostics.

**Remaining Enhancement Opportunity:**
1. Improve mismatch summarization for very large fixtures (multiple strategic diff anchors, not only first mismatch).
2. Add optional debug output grouping by mismatch type (descriptor / text / attribute).
3. Keep assertions strict; diagnostics should improve developer speed only.

**Priority:** P2 (Medium) - correctness gate is in place; this is developer efficiency work.

---

## See Also

- `PLAN.md` - Feature road map, implementation phases, and known issues
- `CORE.md` - Core scoring algorithm detailed design
- `INIT.md` - Original project planning (Chinese)
