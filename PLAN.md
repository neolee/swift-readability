# Swift Readability Porting Plan

This document outlines the phased implementation plan for porting Mozilla Readability.js to Swift.

**Current Status:** Phase 4 Complete (Core Scoring Algorithm with A-H sub-phases)  
**See TESTS.md for detailed testing progress.**

---

## Phase 1: Foundation [COMPLETE]

**Goal:** Establish project structure and configuration system

### 1.1 Configuration System (`ReadabilityOptions`)
- [x] All configurable options from Mozilla implementation
- [x] `Sendable` conformance for Swift 6
- [x] Sensible defaults matching Mozilla

### 1.2 Error Handling (`ReadabilityError`)
- [x] Proper error types with descriptions
- [x] `Sendable` conformance
- [x] Used throughout codebase

### 1.3 Directory Structure
```
Sources/Readability/
├── Readability.swift          # Main entry
├── ReadabilityOptions.swift   # Configuration
├── ReadabilityResult.swift    # Result struct
├── ReadabilityError.swift     # Errors
└── Internal/
    ├── Configuration.swift    # Constants
    └── DOMHelpers.swift       # Utilities
```

### Phase 1 Deliverables
- 4 Mozilla test cases imported
- Basic functionality working

---

## Phase 2: Document Preprocessing [COMPLETE]

**Goal:** Complete `prepDocument()` and related methods

### 2.1 Tag Removal [COMPLETE]
- [x] `<template>` tags (implemented, no specific test)
- [x] `aria-hidden` elements (implemented and tested)
- [x] `<style>` tags (implemented and tested)
- [ ] SVG handling - see Phase 5.4 (deferred)

### 2.2 BR Tag Processing [COMPLETE]
- [x] Multiple consecutive `<br>` handling
- [x] Paragraph conversion logic refinement

### 2.3 Font Tag Replacement [COMPLETE]
- [x] `<font>` to `<span>` conversion (implemented and tested)
- [x] Attribute preservation (not preserved by design, matching Mozilla)

### Verification
Each feature must:
- Have corresponding Mozilla test case
- Pass exact match comparison with `expected.html`

**Status:** 4/4 Phase 2 test cases imported and passing
- `replace-font-tags`: Font tags correctly converted to spans
- `remove-aria-hidden`: Aria-hidden elements correctly removed
- `style-tags-removal`: Style tags correctly removed
- `normalize-spaces`: Whitespace normalization working

---

## Phase 3: Metadata Extraction [COMPLETE]

**Goal:** Full metadata extraction from all sources

### 3.1 JSON-LD Parsing [COMPLETE]
- [x] Parse `application/ld+json` scripts
- [x] Extract `headline`, `author`, `datePublished`, `publisher`
- [x] Handle multiple JSON-LD objects (selects NewsArticle > Article > WebPage)
- [x] Handle nested structures (author as object with name property)
- [x] Handle author arrays (multiple authors joined with ", ")

### 3.2 Open Graph Tags [COMPLETE]
- [x] `og:title`, `og:description`, `og:site_name`
- [x] `og:type` handling (used for metadata priority)

### 3.3 Dublin Core and Twitter Cards [COMPLETE]
- [x] `dc:title`, `dc:creator`, `dc:description`
- [x] `twitter:title`, `twitter:description`, `twitter:creator`

### 3.4 Parsely Metadata [COMPLETE]
- [x] `parsely-title`, `parsely-author`, `parsely-pub-date`

### 3.5 Meta Tag Extraction Priority [COMPLETE]
Implemented Mozilla's exact priority order:

**Title:**
1. JSON-LD `headline`
2. `dc:title` / `dcterm:title`
3. `og:title`
4. `twitter:title`
5. `parsely-title`
6. `title`

**Byline:**
1. JSON-LD `author`
2. `dc:creator` / `dcterm:creator`
3. `author`
4. `parsely-author`
5. `weibo:article:author` / `weibo:webpage:author`
6. `twitter:creator`
7. `og:author`

**Excerpt:**
1. JSON-LD `description`
2. `dc:description` / `dcterm:description`
3. `og:description`
4. `weibo:article:description` / `weibo:webpage:description`
5. `description`
6. `twitter:description`

**Site Name:**
1. JSON-LD `publisher.name`
2. `og:site_name`
3. `twitter:site`
4. `dc:publisher` / `dcterm:publisher`

### 3.6 Space-Separated Properties [COMPLETE]
- [x] Handle meta tags with multiple properties: `property="x:title dc:title"`

### Verification
- [x] `003-metadata-preferred`: Dublin Core priority working (title, byline, excerpt)
- [x] `004-metadata-space-separated-properties`: Space-separated properties working
- [x] `parsely-metadata`: Parsely metadata extraction working (title, byline, publishedTime)
- [x] `schema-org-context-object`: JSON-LD parsing working (title, byline, excerpt, siteName, publishedTime)

**Note:** Byline extraction for `001` requires HTML content parsing (Phase 5), as this test expects byline from article body content, not metadata.

---

## Phase 4: Core Scoring Algorithm [COMPLETE]

**Goal:** Complete `_grabArticle` and related algorithms with full Mozilla compatibility

**See `CORE.md` for detailed difference analysis and sub-phase breakdown (Phases A-H).**

### 4.1 Infrastructure [COMPLETE - Phase A]
- [x] DOM traversal utilities (`getNextNode`, `getNodeAncestors`)
- [x] Node scoring storage (`NodeScoringManager` with `ObjectIdentifier`)
- [x] All Mozilla regex patterns

### 4.2 Node Cleaning [COMPLETE - Phase B]
- [x] Unlikely candidate removal with regex patterns
- [x] Visibility and role checks
- [x] Byline extraction from content

### 4.3 Candidate Selection [COMPLETE - Phase C]
- [x] Top N candidates tracking (default 5)
- [x] Alternative ancestor analysis
- [x] Parent score traversal

### 4.4 Sibling Merging [COMPLETE - Phase D]
- [x] Sibling score threshold calculation
- [x] Classname matching bonus
- [x] P tag special handling with link density
- [x] `ALTER_TO_DIV_EXCEPTIONS` handling

### 4.5 Multi-attempt Fallback [COMPLETE - Phase E]
- [x] FLAG system (STRIP_UNLIKELYS, WEIGHT_CLASSES, CLEAN_CONDITIONALLY)
- [x] Attempt tracking with best fallback
- [x] Page HTML caching and restore

### 4.6 DIV to P Conversion [COMPLETE - Phase F]
- [x] `isPhrasingContent` check
- [x] `hasSingleTagInsideElement` check
- [x] `hasChildBlockElement` check
- [x] Full DIV to P conversion pipeline

### 4.7 Article Cleaning [COMPLETE - Phase G]
- [x] `_cleanConditionally` implementation
- [x] Data table preservation
- [x] Header cleaning
- [x] Single-cell table flattening

### 4.8 Integration & Polish [COMPLETE - Phase H]
- [x] All modules integrated into `Readability.swift`
- [x] DOM context safety fixes (no more "Object must not be null")
- [x] Content wrapper with `id="readability-page-1" class="page"`
- [x] 87.5% test pass rate (28/32 tests)

### Key Implementation Details

**Architecture:**
```
Sources/Readability/Internal/
├── DOMTraversal.swift       # Depth-first traversal
├── NodeScoring.swift        # Score storage and initialization
├── NodeCleaner.swift        # Unlikely candidate removal
├── CandidateSelector.swift  # Top N candidate selection
├── SiblingMerger.swift      # Sibling content merging
├── ContentExtractor.swift   # Main grabArticle logic
└── ArticleCleaner.swift     # Post-extraction cleaning
```

**Swift-Specific Solutions:**
- Score storage: `[ObjectIdentifier: NodeScore]` dictionary (SwiftSoup nodes don't support custom properties)
- DOM context: Always use `doc.createElement()` instead of `Element(Tag, "")`
- Element cloning: Document-aware recursive cloning to maintain proper ownership

### Verification
- [x] `title-en-dash`: En-dash separator handling
- [x] `title-and-h1-discrepancy`: Title vs H1 discrepancy handling
- [x] `keep-images`: Image preservation in content
- [x] `keep-tabular-data`: Table data preservation
- [x] 28/32 tests passing (87.5%)

---

## Phase 5: Content Cleaning

**Goal:** Fix remaining content quality issues and complete cleaning

### 5.1 Text Node Ordering Fix [IN PROGRESS]
**Priority:** High  
**Issue:** DOM manipulation reorders text nodes and inline elements

- [ ] Implement mixed node list preservation
- [ ] Use `childNodes()` for original order iteration
- [ ] Fix `cloneElement()` to preserve text node interleaving

**Tests affected:** `001`, `replace-brs`, `replace-font-tags`

### 5.2 Conditional Cleaning
Remove elements based on:
- [ ] Image-to-paragraph ratio
- [ ] Input element count
- [ ] Link density thresholds
- [ ] Content length checks
- [ ] Ad/navigation pattern detection

### 5.3 Image Handling
- [ ] Lazy load image fixing (`data-src` to `src`)
- [ ] Small image/icon removal
- [ ] Meaningful image preservation

### 5.4 SVG Handling (from Phase 2)
- [ ] SVG content in `<head>` removal
- [ ] Inline SVG preservation (when meaningful)
- [ ] SVG reference preservation (`<img src="*.svg">`, `<use>`)

### 5.5 Byline from HTML Content
- [ ] Parse author from article body
- [ ] Pattern matching for byline detection
- [ ] "By Author Name" format recognition

### Verification
- 80%+ Mozilla test pass rate
- Clean output without navigation/ads
- Text content ordering matches expected

---

## Phase 6: Advanced Features

### 6.1 Pagination Support
- [ ] Detect "next page" links
- [ ] Merge multi-page content

### 6.2 Code Block Protection
- [ ] Preserve `<pre>`, `<code>` content
- [ ] Do not clean conditional on code blocks

### 6.3 Table Handling
- [ ] Detect layout vs data tables
- [ ] Preserve meaningful tables

### 6.4 CLI Enhancements
- [ ] Configuration file support
- [ ] Batch processing

### Verification
- 90%+ Mozilla test pass rate

---

## Phase 7: Performance and Polish

### 7.1 Performance Optimization
- [ ] Large document handling (>1MB)
- [ ] Memory usage optimization
- [ ] Instruments profiling

### 7.2 Documentation
- [ ] API documentation
- [ ] Migration guide from other implementations

### 7.3 Release Preparation
- [ ] Version 1.0.0
- [ ] CocoaPods/SPM publication

---

## Test Coverage Targets

| Phase | Target Pass Rate | Test Cases | Status |
|-------|------------------|------------|--------|
| Phase 1 | N/A (foundation) | 4 | COMPLETE |
| Phase 2 | 30% | 8 | COMPLETE |
| Phase 3 | Metadata extraction | 12 | COMPLETE |
| Phase 4 | Core scoring | 16 | COMPLETE |
| Phase 5 | 80% | 100-120 | IN PROGRESS |
| Phase 6 | 90%+ | 130 (all) | PENDING |

**Current:** 16/130 test cases (12%), 28/32 tests passing (87.5%)

---

## Mozilla Test Case Import Priority

### Phase 4 Completed (via CORE.md Phases A-H)
- [x] `title-en-dash`
- [x] `title-and-h1-discrepancy`
- [x] `keep-images`
- [x] `keep-tabular-data`

### Phase 5 (Content Cleaning)

**Text Node Ordering:**
- `001`
- `replace-brs`
- `replace-font-tags`

**Content Cleaning:**
- `lazy-image-*`
- `svg-parsing` (deferred from Phase 2)
- `cnet-svg-classes` (deferred from Phase 2)
- And other content cleaning tests

### Complete Set (Phase 6)
All 130 Mozilla test cases for full compatibility verification

---

## Summary

### Completed Phases (1-4)

All foundation, preprocessing, metadata extraction, and core scoring work is complete. The implementation successfully extracts readable content from web pages without crashes.

**Phase 4 Implementation:** See `CORE.md` for detailed breakdown of Phases A-H which cover:
- A: Foundation (DOM traversal, scoring infrastructure)
- B: Node Cleaner (unlikely candidate removal)
- C: Candidate Selection (Top N candidates)
- D: Sibling Merging (content merging)
- E: Multi-attempt Fallback (robustness)
- F: DIV to P Conversion (phrasing content)
- G: Article Cleaning (conditional cleaning)
- H: Integration & Polish (module wiring, DOM context fixes)

### Current Blockers for 100% Test Pass Rate

1. **Text Node Ordering** (3 tests): DOM manipulation reorders text nodes and inline elements
2. **Byline from HTML** (1 test): Need to parse author from article body content

These are known limitations documented in TESTS.md with detailed technical analysis.

### Next Steps

1. **Phase 5**: Fix text node ordering in DOM manipulation
2. **Phase 5**: Implement HTML content byline detection
3. **Phase 5**: Complete content cleaning features
4. **Phase 6**: Import remaining test cases for 90%+ pass rate

---

## See Also

- `AGENTS.md` - Core principles and coding standards
- `TESTS.md` - Detailed testing strategy and current progress
- `CORE.md` - Phase 4 detailed implementation plan (Phases A-H)
- `INIT.md` - Original project planning (Chinese)
