# Testing Strategy and Progress

This document tracks testing progress, strategy, and known issues for the Swift Readability port.

**Last Updated:** Phase 4 Complete (Core Scoring Algorithm with A-H sub-phases)
**Current Status:** 32/32 tests, 28 passing, 4 failing (1 known byline issue)

---

## Current Test Coverage

### Test Files

| File | Count | Purpose |
|------|-------|---------|
| `MozillaCompatibilityTests.swift` | 32 | Strict compatibility tests with Mozilla test cases |

### Test Results Summary

| Test Category | Passed | Known Issues | Failed |
|--------------|--------|--------------|--------|
| Title extraction | 14 | 0 | 0 |
| Content extraction | 10 | 0 | 3 |
| Metadata (byline/excerpt) | 10 | 1 | 0 |
| Other | 2 | 0 | 0 |
| **Total** | **28** | **1** | **3** |

**Note:** 32 tests total. 1 byline extraction is a known limitation (metadata only, no HTML content parsing). 3 content tests have text similarity issues (89-98%) due to text node ordering differences.

---

## Mozilla Test Cases Imported

| Test Case | Imported | Status | Notes |
|-----------|----------|--------|-------|
| `001` | [x] | Content (89% similarity) | Real article, title/excerpt match, text node ordering differs |
| `basic-tags-cleaning` | [x] | Passing | DOM structure matches expected |
| `remove-script-tags` | [x] | Passing | DOM structure matches expected |
| `replace-brs` | [x] | Content (92% similarity) | BR handling differs slightly |
| `replace-font-tags` | [x] | Content (98% similarity) | Minor text content differences |
| `remove-aria-hidden` | [x] | Passing | `aria-hidden` elements correctly removed |
| `style-tags-removal` | [x] | Passing | `<style>` tags correctly removed |
| `normalize-spaces` | [x] | Passing | Whitespace normalization working |
| `003-metadata-preferred` | [x] | Passing | Dublin Core metadata priority working |
| `004-metadata-space-separated-properties` | [x] | Passing | Space-separated meta properties working |
| `parsely-metadata` | [x] | Passing | Parsely metadata extraction working |
| `schema-org-context-object` | [x] | Passing | JSON-LD parsing working |
| `title-en-dash` | [x] | Passing | En-dash separator handling working |
| `title-and-h1-discrepancy` | [x] | Passing | Title vs H1 discrepancy handling working |
| `keep-images` | [x] | Passing | Image preservation working |
| `keep-tabular-data` | [x] | Passing | Table data preservation working |

**Coverage:** 16/130 test cases (12%)

---

## Known Issues

### 1. Text Node Ordering in Content Extraction [FIXED]

**Status:** FIXED in Phase 5.1

**Tests Affected:** `001` (was 89%, now 100%)

**Problem:** During DOM manipulation, text nodes and inline elements were reordered because `cloneElement()` processed `children()` first, then `textNodes()`.

**Solution:** Changed all `cloneElement` implementations to use `getChildNodes()` which preserves the original mixed order of elements and text.

**Files Modified:**
- `DOMHelpers.swift` - Added shared `cloneElement()` utility
- `Readability.swift` - Use `DOMHelpers.cloneElement()`
- `SiblingMerger.swift` - Use `DOMHelpers.cloneElement()`
- `ArticleCleaner.swift` - Use `DOMHelpers.cloneElement()`

---

### 2. BR to Paragraph Conversion Differences (1 test)

**Test:** `replace-brs - Content`

**Similarity:** 92%

**Problem:** 
- Expected: Multiple `<p>` paragraphs with `<br />` tags preserved
- Actual: Single paragraph with BRs removed, content merged

**Root Cause:**
- Our `replaceBrs()` merges consecutive BRs into paragraphs differently than Mozilla
- Content wrapper selection differs (keeps `<article>` and `<h1>` tags)

**Impact:** Low - text content is correct, paragraph structure differs

**Resolution:** Phase 6 - Content Cleaning refinement

---

### 3. Font Tag Conversion Differences (1 test)

**Test:** `replace-font-tags - Content`

**Similarity:** 98%

**Problem:** Minor structural differences in output

**Root Cause:** Similar to replace-brs, content wrapper selection differs

**Impact:** Low - text content is nearly identical

**Resolution:** Phase 6 - Content Cleaning refinement

---

### 4. Byline Extraction from HTML Content (1 test)

**Test:** `001 - Byline`

**Expected:** "Nicolas Perriault"
**Actual:** `nil`

**Analysis:**
- Source HTML contains NO metadata author tags
- Author name appears only in:
  - `<title>` tag: "Get your Frontend JavaScript Code Covered | Code | Nicolas Perriault"
  - HTML content header: "Hi, I'm Nicolas."

**Status:** Metadata-based byline extraction WORKING (parsely-metadata, 003-metadata-preferred, schema-org all pass)

**Resolution:** Phase 5.2 will implement HTML content byline detection for cases without metadata

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

// Content: Exact DOM comparison
let comparison = compareDOM(result.content, expectedHTML)
#expect(comparison.isEqual, "Content mismatch: \(comparison.diff)")
```

---

## Phase 4 (A-H) Implementation Summary

Phase 4 was implemented via 8 sub-phases (A-H) as documented in `CORE.md`:

- **Phase A:** DOM traversal and scoring infrastructure
- **Phase B:** Node cleaner (unlikely candidate removal)
- **Phase C:** Candidate selection (Top N candidates)
- **Phase D:** Sibling merging (content merging)
- **Phase E:** Multi-attempt fallback (robustness)
- **Phase F:** DIV to P conversion (phrasing content)
- **Phase G:** Article cleaning (conditional cleaning)
- **Phase H:** Integration & polish (module wiring, DOM context fixes)

### Completed Work

1. **DOM Context Fixes** (Phase H)
   - Fixed "Object must not be null" SwiftSoup errors
   - Changed all `Element(Tag, "")` to `doc.createElement()`
   - Added document-aware element cloning throughout

2. **Content Wrapper** (Phase H)
   - Added `id="readability-page-1" class="page"` wrapper to match Mozilla output format
   - Preserved readability attributes during cleaning

3. **Test Suite Cleanup** (Phase H)
   - Removed incorrect `withKnownIssue()` wrappers from passing tests
   - 5 tests previously marked with known issues are now passing

### Remaining Issues

3 content tests with text similarity 89-98% - text node ordering during DOM manipulation.

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
- Full text similarity ratio for reporting

---

## Import Queue

### Phase 4 (Core Scoring) [COMPLETE]

Test cases imported (via CORE.md Phases A-H):
- [x] `title-en-dash` - En-dash separator handling
- [x] `title-and-h1-discrepancy` - Title vs H1 discrepancy handling
- [x] `keep-images` - Image preservation
- [x] `keep-tabular-data` - Table data preservation

**Implemented Features:**
- [x] ContentExtractor with multi-attempt fallback
- [x] ArticleCleaner post-processing
- [x] DOM context safety fixes
- [x] Page wrapper with readability attributes
- [x] Top N candidate selection
- [x] Sibling content merging

### Phase 5 (Content Cleaning) [IN PROGRESS]

**Goal:** Fix text node ordering and complete content cleaning

Test cases to validate fixes:
- `001` (text node ordering)
- `replace-brs` (text node ordering)
- `replace-font-tags` (text node ordering)
- `lazy-image-*`
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

| Milestone | Target | Date | Status |
|-----------|--------|------|--------|
| Phase 1 end | Foundation | - | COMPLETE |
| Phase 2 end | 30% pass rate | - | COMPLETE |
| Phase 3 end | Metadata extraction | - | COMPLETE |
| Phase 4 end | Core scoring | - | COMPLETE |
| Phase 5 end | Content cleaning | TBD | IN PROGRESS |
| Phase 6 end | 90%+ pass rate | TBD | PENDING |

**Current:** 28/32 tests passing (87.5%), 3 text similarity issues to resolve.

### Infrastructure Improvements

- [ ] Automated test case import script
- [ ] CI integration with test reporting
- [ ] HTML diff visualization for failures
- [ ] Performance benchmarking

---

## See Also

- `AGENTS.md` - Core testing principles
- `PLAN.md` - Implementation phases and roadmap
- `ref/mozilla-readability/test/` - Original Mozilla test suite
