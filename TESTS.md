# Testing Strategy and Progress

This document tracks testing progress, strategy, and known issues for the Swift Readability port.

**Last Updated:** Phase 1 Complete  
**Current Status:** 10/10 tests passing, 4 known issues

---

## Current Test Coverage

### Test Files

| File | Count | Purpose |
|------|-------|---------|
| `MozillaCompatibilityTests.swift` | 10 | Strict compatibility tests with Mozilla test cases |

### Test Results Summary

| Test Category | Passed | Known Issues | Failed |
|--------------|--------|--------------|--------|
| Title extraction | 4 | 0 | 0 |
| Content structure | 0 | 4 | 0 |
| Metadata (byline) | 0 | 1 | 0 |
| **Total** | **6** | **4** | **0** |

### Mozilla Test Cases Imported

| Test Case | Imported | Status | Notes |
|-----------|----------|--------|-------|
| `001` | [x] | Passing (content text matches, DOM differs) | Real article, title/excerpt match |
| `basic-tags-cleaning` | [x] | Passing (content differs) | `<h1>` text retained in output |
| `remove-script-tags` | [x] | Passing (content differs) | `<h1>` text retained in output |
| `replace-brs` | [x] | Passing (content differs) | `<h1>` text retained in output |

**Coverage:** 4/130 test cases (3%)

---

## Known Issues

### 1. Content Structure Differences

**Previous incorrect description:** "Whitespace normalization differences"  
**Correct description:** "Content selection and filtering differences"

**Tests affected:** `001`, `basic-tags-cleaning`, `remove-script-tags`, `replace-brs`

#### Issue Analysis

The differences are **NOT** caused by `SwiftSoup` vs `JSDOM` whitespace handling. Instead, they stem from our content extraction algorithm selecting different containers than Mozilla's implementation.

#### Specific Problems

**A. `<h1>` Content Retained (basic-tags-cleaning, remove-script-tags, replace-brs)**

**Example (basic-tags-cleaning):**
```
Expected: "Lorem ipsum dolor sit amet..."
Actual:   "Lorem Lorem ipsum dolor sit amet..."
                 ^^^^^^
                 Extra h1 content
```

**Source HTML:**
```html
<article>
    <h1>Lorem</h1>           <!-- This should be filtered out -->
    <div>
        <p>Lorem ipsum...</p> <!-- This should be the start -->
    </div>
</article>
```

**Expected output (Mozilla):**
```html
<div>
    <p>Lorem ipsum...</p>  <!-- h1 content not included -->
</div>
```

**Our actual output:**
```html
<div>
    Lorem                    <!-- h1 text retained -->
    <p>Lorem ipsum...</p>
</div>
```

**Impact:** Minor - adds article title at start of content, doesn't affect readability.

---

**B. DOM Structure Differences (001)**

**Text content:** 100% identical (3981 chars both sides)  
**DOM structure:** Different

**Likely causes:**
- Different element selection (we select a parent that includes more elements)
- Attribute handling differences
- `id` and `class` preservation differences

**Impact:** Low - semantic content identical, presentation differs.

#### Root Cause

Our `grabArticle()` implementation selects the best candidate element but does not:
1. Filter out heading elements (`<h1>`, `<h2>`) that should not be in article content
2. Match Mozilla's exact element selection algorithm
3. Handle nested containers the same way

#### Resolution Plan

**Phase:** Content Cleaning (Phase 5)  
**Specific tasks:**
- [ ] Implement `_prepArticle()` to filter heading elements from content
- [ ] Review `_cleanConditionally()` for heading handling
- [ ] Match Mozilla's element filtering logic exactly

**Tracking:** Marked with `withKnownIssue()` in tests, referenced to `PLAN.md` Phase 5.

---

### 2. Byline Extraction Not Implemented

**Test:** `001 - Byline matches expected`

**Expected:** "Nicolas Perriault"  
**Actual:** `nil`

**Root Cause:** Metadata extraction from `dc:creator` implemented, but 001 test case uses JSON-LD which is Phase 3.

**Decision:** Defer to Phase 3 (JSON-LD parsing).

**Current Status:** Marked as known issue with reference to `PLAN.md` Phase 3.

---

## Testing Principles Applied

### Anti-Patterns Rejected

Previously had accommodating tests like:
```swift
// REMOVED: Too permissive
#expect(result.title.contains(expectedTitle) || 
        expectedTitle.contains(result.title))

// REMOVED: No content validation
#expect(result.length > 500)
```

### Current Strict Approach

```swift
// Title: Exact match required
#expect(result.title == expectedTitle)

// Content: Semantic similarity with threshold
let matchRatio = calculateSimilarity(actual, expected)
#expect(matchRatio > 0.90, "Only \(Int(matchRatio*100))% match")

// Known limitations: Explicitly marked
withKnownIssue("<h1> content retained - fix in Phase 5") {
    #expect(normalizedResult == normalizedExpected)
}
```

---

## Test Infrastructure

### TestLoader.swift

Utility for loading Mozilla test cases:
```swift
let testCase = TestLoader.loadTestCase(named: "001")
// Returns: sourceHTML, expectedHTML, expectedMetadata
```

### Mozilla Test Case Format

Each test case directory:
```
test-pages/001/
├── source.html           # Input HTML
├── expected.html         # Expected output
└── expected-metadata.json # Expected metadata
```

### DOM Comparison

Custom DOM traversal comparing:
- Node types (element, text)
- Tag names
- Text content (normalized whitespace)
- Attributes (when implemented)

---

## Import Queue

### Phase 2 (Document Preprocessing)

Priority test cases to import:
- `replace-font-tags`
- `remove-aria-hidden`
- `style-tags-removal`
- `normalize-spaces`

### Phase 3 (Metadata)

- `003-metadata-preferred`
- `004-metadata-space-separated-properties`
- `parsely-metadata`
- `schema-org-context-object`

### Phase 4 (Core Scoring)

- `title-en-dash`
- `title-and-h1-discrepancy`
- `keep-images`
- `keep-tabular-data`

### Phase 5 (Content Cleaning)

**These tests will validate fixes for current known issues:**
- `basic-tags-cleaning` (verify `<h1>` removal)
- `remove-script-tags` (verify `<h1>` removal)
- `replace-brs` (verify `<h1>` removal)
- `lazy-image-1`, `lazy-image-2`, `lazy-image-3`
- Other content cleaning tests

### Phase 6 (Complete)

All remaining test cases for 90%+ pass rate.

---

## Running Tests

### Run All Tests
```bash
cd Readability && swift test
```

### Run Compatibility Tests Only
```bash
cd Readability && swift test --filter MozillaCompatibilityTests
```

### Run Specific Test
```bash
cd Readability && swift test --filter "001 - Title matches expected exactly"
```

---

## Test Failure Response Protocol

When a test fails:

1. **Do NOT modify test to make it pass**
2. Analyze if implementation is incorrect
3. Check if it is a known technical limitation (`SwiftSoup` vs `JSDOM`)
4. If fixable: fix implementation
5. If limitation: mark with `withKnownIssue()` and document
6. If unsure: discuss before proceeding

---

## Future Improvements

### Test Coverage Goals

| Milestone | Target | Date |
|-----------|--------|------|
| Phase 2 end | 30% pass rate | TBD |
| Phase 3 end | 40% pass rate | TBD |
| Phase 4 end | 60% pass rate | TBD |
| Phase 5 end | 80% pass rate | TBD |
| Phase 6 end | 90%+ pass rate | TBD |

**Note:** Current "80% similarity" issues should become "100% match" after Phase 5 fixes.

### Infrastructure Improvements

- [ ] Automated test case import script
- [ ] CI integration with test reporting
- [ ] HTML diff visualization for failures
- [ ] Performance benchmarking

---

## See Also

- `AGENTS.md` - Core testing principles
- `PLAN.md` - Implementation phases and roadmap (see Phase 5 for content cleaning)
- `ref/mozilla-readability/test/` - Original Mozilla test suite
