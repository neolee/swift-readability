# DEPRECATED - ARCHIVED

**Status:** Archived (2026-02-07)
**Reason:** Information outdated, superseded by REVIEW.md and AGENTS.md
**Current Status:** See REVIEW.md for latest project status

---

# Swift Readability Porting Plan

This document outlines the phased implementation plan for porting Mozilla Readability.js to Swift.

**Current Status:** Phase 7 In Progress (Stage 3-R Batch 1 imported with quarantined known issues)
**Verification Baseline (2026-02-06):** `cd Readability && swift test` -> 298 tests, 0 failures, 8 known issues (`MozillaCompatibilityTests` 119/119 passing)

### Stage 3-F Import Progress (S3F-T1)

- [x] URL/base handling batch imported:
  - `base-url`
  - `base-url-base-element`
  - `base-url-base-element-relative`
  - `js-link-replacement`
- [x] I18N/entity batch imported:
  - `005-unescape-html-entities`
  - `rtl-1`
  - `rtl-2`
  - `rtl-3`
  - `rtl-4`
  - `mathjax` (content assertion passing)
- [x] Media/SVG batch imported:
  - `data-url-image` (content assertion passing)
  - `lazy-image-1` (content assertion passing)
  - `lazy-image-2` (content assertion passing)
  - `lazy-image-3`
  - `embedded-videos` (content assertion passing)
  - `videos-1` (content assertion now passing)
  - `videos-2` (content assertion now passing)
  - `svg-parsing` (content assertion now passing)
- [x] Edge-case batch imported:
  - `comment-inside-script-parsing` (content assertion passing)
  - `metadata-content-missing` (content assertion passing)
  - `toc-missing` (content assertion passing)
  - `bug-1255978` (content assertion passing)
- [x] Remaining standard functional pages to import: none (`52/52` covered in `MozillaCompatibilityTests`)

## Option Implementation Status (S2-T6)

The following status is the current contract and must be kept in sync with `ReadabilityOptions.swift`.

| Option | Status | Notes |
|--------|--------|-------|
| `maxElemsToParse` | Deferred / no-op | Exposed in API but not yet applied in extraction traversal limits. |
| `useCustomSerializer` | Deferred / no-op | Current output always uses built-in serializer path. |
| `allowedVideoRegex` | Deferred / no-op | Stored in options but not yet consumed in media-cleaning decisions. |
| `debug` | Deferred / no-op | No pipeline logging behavior is currently gated by this flag. |

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
- [x] Historical snapshot at end of Phase 4: 87.5% test pass rate (28/32 tests)

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
- [x] Historical snapshot at end of Phase 4: 28/32 tests passing (87.5%)

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
- [x] Historical snapshot at end of Phase 4: 28/32 tests passing (87.5%)

---

## Phase 5: Content Quality & Byline Extraction

**Goal:** Fix content quality issues and complete byline extraction

### 5.1 Text Node Ordering Fix [COMPLETE]
**Priority:** High
**Issue:** DOM manipulation reorders text nodes and inline elements

**Solution:**
- [x] Extracted shared `DOMHelpers.cloneElement()` utility
- [x] Changed all implementations to use `getChildNodes()` to preserve mixed element/text order
- [x] Refactored `Readability.swift`, `SiblingMerger.swift`, `ArticleCleaner.swift` to use shared utility

**Result:**
- `001` content test: 89% -> 100% FIXED

### 5.2 HTML Byline Extraction [COMPLETE]
**Priority:** High
**Issue:** Byline extraction only works with metadata, not HTML content

**Solution:**
- [x] Implemented byline detection in `NodeCleaner.checkAndExtractByline()`
- [x] Pattern matching for `rel="author"`, `itemprop="author"`, and byline class/id patterns
- [x] Child node search for `itemprop="name"` for more accurate author names
- [x] Integrated extraction into `ContentExtractor.performExtraction()`
- [x] Proper priority: metadata byline > HTML content byline (matching Mozilla behavior)

**Tests affected:** `001 - Byline` - NOW PASSING

### Verification
- [x] 90%+ Mozilla test pass rate
- [x] Clean output without navigation/ads
- [x] Text content ordering matches expected

---

## Phase 6: Content Cleaning & Test Suite Completion

**Goal:** Complete all standard Mozilla test cases (non real-world sites) and achieve 95%+ pass rate

**Scope:** 52 standard functional tests (excluding 78 real-world site tests)
**Current:** 52/52 standard functional tests imported (100%)
**Target:** 52/52 tests imported and passing

### Ordering Principle

Tasks are ordered by **dependency complexity** (not just priority):
- **Earlier sections** (6.1-6.3): More integrated with core algorithm, affect multiple downstream features
- **Later sections** (6.4-6.9): More independent, can be implemented in isolation
- **Final section** (6.10): Comprehensive test import and known issue resolution

This ensures foundational improvements are in place before adding specialized handling.

---

### 6.1 Legacy Issue Resolution [P0 - Blocking]

Complete deferred issues from Phase 5 before proceeding.

#### 6.1.1 BR to Paragraph Conversion
**Tests:** `replace-brs` (fixed)

**Issues:**
- BR tag to paragraph conversion differs from Mozilla
- Multiple consecutive BRs should create separate paragraphs
- Content wrapper selection includes extra elements

**Tasks:**
- [ ] Fix `replaceBrs()` to match Mozilla's paragraph splitting
- [ ] Preserve `<br />` tags within paragraphs
- [ ] Proper paragraph boundary detection

#### 6.1.2 Font Tag Conversion Refinement
**Tests:** `replace-font-tags` (fixed)

**Issues:**
- Minor structural differences in output

**Tasks:**
- [ ] Refine font tag to span conversion
- [ ] Match Mozilla's exact output structure

---

### 6.2 Content Post-Processing (`_prepArticle`) [P1 - Core]
**Dependency:** Core scoring algorithm
**Impact:** Affects all content output quality

**Tests:**
- `002` - Basic content extraction validation (passing)
- `reordering-paragraphs` - Paragraph ordering preservation
- `missing-paragraphs` - Detect and preserve missing paragraphs
- `remove-extra-brs` - Remove trailing/consecutive BRs
- `remove-extra-paragraphs` - Remove empty paragraphs
- `ol` - Ordered list handling

**Tasks:**
- [ ] Remove extra BRs (trailing BRs before P tags)
- [ ] Remove extra paragraphs (empty P with no content)
- [ ] H1→H2 replacement (H1 should only be title)
- [ ] Single-cell table flattening (convert to P or DIV)
- [ ] Paragraph reordering validation
- [ ] Missing paragraph detection and recovery

---

### 6.3 Conditional Cleaning Enhancement [P1 - Core]
**Dependency:** Content extraction
**Impact:** Content quality, noise removal

**Tests:**
- `clean-links` - Link cleaning and filtering
- `links-in-tables` - Table link handling
- `social-buttons` - Social button removal
- `article-author-tag` - Author tag byline extraction
- `table-style-attributes` - Presentational attribute removal
- `invalid-attributes` - Invalid attribute cleanup

**Tasks:**
- [ ] Complete `_cleanConditionally` implementation
- [ ] Image-to-paragraph ratio checks
- [ ] Input element count thresholds
- [ ] Link density with hash URL coefficient (0.3)
- [ ] Heading density calculation
- [ ] Ad/loading words pattern detection (`adWords`, `loadingWords`)
- [ ] Video embed preservation (`iframe` / `object` with video URLs)
- [ ] Share elements removal
- [ ] Invalid/presentational attributes cleanup

---

### 6.4 Hidden Node & Visibility Handling [P2]
**Dependency:** DOM preprocessing
**Impact:** Content accuracy

**Tests:**
- `hidden-nodes` - `display: none` and `hidden` attribute
- `visibility-hidden` - `visibility: hidden` handling

**Tasks:**
- [ ] Remove elements with `display: none`
- [ ] Remove elements with `hidden` attribute
- [ ] Handle `visibility: hidden` elements
- [ ] Respect `aria-hidden` (already implemented, verify)

---

### 6.5 Lazy Images & Media Handling [P2]
**Dependency:** Image processing
**Impact:** Media content quality

**Tests:**
- `lazy-image-1`, `lazy-image-2`, `lazy-image-3` - Lazy loading images
- `data-url-image` - Base64 data URL handling
- `embedded-videos` - Video embed detection
- `videos-1`, `videos-2` - Video element handling

**Tasks:**
- [ ] Fix lazy images from `data-src`, `data-original` attributes
- [ ] Base64 data URL validation (remove tiny placeholder images)
- [ ] Figure element image creation
- [ ] Video embed preservation (iframe, object, embed)
- [ ] Picture element handling

---

### 6.6 SVG Handling [P3]
**Dependency:** Content parsing
**Impact:** Visual content accuracy

**Tests:**
- `svg-parsing` - Inline SVG preservation
- `cnet-svg-classes` (deferred to Phase 7 - real-world site)

**Tasks:**
- [ ] Inline SVG preservation in content
- [ ] SVG in `<head>` removal
- [ ] SVG reference preservation (`<img src="*.svg">`)
- [ ] Data URI SVG detection (preserve even if small)

---

### 6.7 Link & URL Processing [P3]
**Dependency:** URL parsing
**Impact:** Link accuracy

**Tests:**
- `base-url` - Base URL handling
- `base-url-base-element` - `<base>` element support
- `base-url-base-element-relative` - Relative base URL
- `js-link-replacement` - JavaScript link handling

**Tasks:**
- [ ] Parse `<base>` element for relative URL resolution
- [ ] Resolve relative URLs in links and images
- [ ] Handle JavaScript: links appropriately

---

### 6.8 Internationalization & Special Content [P3]
**Dependency:** Text processing
**Impact:** Multi-language support

**Tests:**
- `rtl-1`, `rtl-2`, `rtl-3`, `rtl-4` - RTL text direction
- `mathjax` - MathJax content preservation
- `005-unescape-html-entities` - HTML entity decoding

**Tasks:**
- [x] Preserve `dir` attribute for RTL content
- [x] Preserve `lang` attribute
- [ ] MathJax content handling
- [ ] HTML entity unescaping in metadata

---

### 6.9 Edge Cases & Script Handling [P4]
**Dependency:** Parser robustness
**Impact:** Stability

**Tests:**
- `comment-inside-script-parsing` - Script content parsing
- `toc-missing` - Table of contents handling
- `metadata-content-missing` - Missing metadata handling
- `bug-1255978` - Specific bug regression test

**Tasks:**
- [ ] Handle comments inside script tags
- [ ] TOC detection and handling
- [ ] Graceful handling of missing metadata
- [ ] Bug fix verification

---

### 6.10 Test Suite Completion & Known Issues Resolution [P5 - Final]

**Goal:** Keep full standard set green and resolve any newly introduced issues

**Import Queue:**

| Batch | Tests | Purpose |
|-------|-------|---------|
| Batch 1 | `002`, `005-unescape-html-entities` | Basic validation |
| Batch 2 | `reordering-paragraphs`, `missing-paragraphs`, `ol`, `remove-extra-brs`, `remove-extra-paragraphs` | Content structure |
| Batch 3 | `clean-links`, `links-in-tables`, `social-buttons`, `article-author-tag`, `invalid-attributes`, `table-style-attributes` | Conditional cleaning |
| Batch 4 | `hidden-nodes`, `visibility-hidden` | Visibility |
| Batch 5 | `lazy-image-1/2/3`, `data-url-image`, `embedded-videos`, `videos-1/2` | Media |
| Batch 6 | `svg-parsing` | SVG |
| Batch 7 | `base-url`, `base-url-base-element`, `base-url-base-element-relative`, `js-link-replacement` | URL handling |
| Batch 8 | `rtl-1/2/3/4`, `mathjax` | I18N |
| Batch 9 | `comment-inside-script-parsing`, `toc-missing`, `metadata-content-missing`, `bug-1255978` | Edge cases |

**Known Issues to Resolve:**
- [x] None currently active in imported standard set

**Verification Criteria:**
- [x] 52/52 standard functional tests imported
- [x] 0 known issues remaining
- [x] 95%+ test pass rate on standard tests
- [ ] Document any technical limitations with clear explanations

---

### Phase 6 Verification

| Metric | Target | Status |
|--------|--------|--------|
| Standard tests imported | 52/52 | 52/52 (100%) |
| Standard tests passing | 95%+ | 119/119 `MozillaCompatibilityTests` tests passing |
| Known issues | 0 | 0 active known issues |
| Real-world tests | Phase 7 | 5/78 (6.4%) imported, 8 known issues (quarantined) |

### Stage 3-F Gate Checkpoint (S3F-T4)

- [x] `cd Readability && swift test --filter MozillaCompatibilityTests` -> 119/119 passing (2026-02-06)
- [x] `cd Readability && swift test` -> 293 tests, 0 failures (2026-02-06)
- [x] Stage 3-F gate passed; Stage 3-R can begin under strict functional/real-world separation

---

## Phase 7: Performance and Polish

### 7.0 Stage 3-R Batch 1 Baseline [IN PROGRESS]

- Imported fixtures (`Resources/realworld-pages`):
  - `wikipedia`
  - `medium-1`
  - `nytimes-1`
  - `cnn`
  - `wapo-1`
- Test suite:
  - `Readability/Tests/ReadabilityTests/RealWorldCompatibilityTests.swift`
- Baseline result:
  - `swift test --filter RealWorldCompatibilityTests` -> 5 tests, 8 known issues (quarantined)
- Report:
  - `Readability/Tests/ReadabilityTests/Resources/realworld-pages/BATCH-1-REPORT.md`
- Cluster ledger:
  - `Readability/Tests/ReadabilityTests/Resources/realworld-pages/ISSUE-CLUSTERS.md`

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

### Test Case Classification

Mozilla Readability has **130 test cases** total, divided into:

| Category | Count | Description |
|----------|-------|-------------|
| Standard Functional Tests | 52 | Feature-specific tests (replace-brs, lazy-images, etc.) |
| Real-World Site Tests | 78 | Tests from actual websites (wikipedia, nytimes, etc.) |
| **Total** | **130** | |

### Phase Coverage Overview

| Phase | Scope | Target Pass Rate | Test Cases | Status |
|-------|-------|------------------|------------|--------|
| Phase 1 | Foundation | N/A | 4 | COMPLETE |
| Phase 2 | Preprocessing | 100% | 8 | COMPLETE |
| Phase 3 | Metadata | 100% | 12 | COMPLETE |
| Phase 4 | Core Scoring | 100% | 16 | COMPLETE |
| Phase 5 | Content Quality | 100% | 4 | COMPLETE |
| **Phase 6** | **Standard Tests** | **95%+** | **52** | **COMPLETE (import + current baseline)** |
| Phase 7 | Real-World Sites | 90%+ | 78 | IN PROGRESS (Batch 1 imported) |

### Current Status

**Standard Tests:** 52/52 imported (100%), currently passing in compatibility suite
**Real-world Tests:** 5/78 imported in `Resources/realworld-pages` (Batch 1 baseline)
**Known Issues:** 0 active in functional suite; 8 active (quarantined) in real-world suite

### Phase 6 Detailed Progress

#### 6.1 Legacy Issues [COMPLETE]
- [x] `replace-brs` content mismatch (FIXED - was 92%, now 100%)
- [x] `replace-font-tags` content mismatch (FIXED - was 98%, now 100%)

#### 6.2 Content Post-Processing (6 tests) [COMPLETE]
- [x] Import `002` - PASS
- [x] Import `reordering-paragraphs` - PASS
- [x] Import `missing-paragraphs` - PASS
- [x] Import `remove-extra-brs` - PASS
- [x] Import `remove-extra-paragraphs` - PASS
- [x] Import `ol` - PASS

#### 6.3 Conditional Cleaning (6 tests) [COMPLETE]
- [x] Import `clean-links` - PASS
- [x] Import `links-in-tables` - PASS
- [x] Import `social-buttons` - PASS
- [x] Import `article-author-tag` - PASS
- [x] Import `table-style-attributes` - PASS
- [x] Import `invalid-attributes` - PASS

#### 6.4 Hidden Node Handling (2 tests) [COMPLETE]
- [x] Import `hidden-nodes` - PASS
- [x] Import `visibility-hidden` - PASS

#### 6.5 Lazy Images & Media (6 tests) [COMPLETE]
- [x] Import `lazy-image-1/2/3` - PASS
- [x] Import `data-url-image` - PASS
- [x] Import `embedded-videos` - PASS
- [x] Import `videos-1/2` - PASS

#### 6.6 SVG Handling (1 test) [COMPLETE]
- [x] Import `svg-parsing` - PASS

#### 6.7 Link & URL Processing (4 tests) [COMPLETE]
- [x] Import `base-url` (3 variants) - PASS
- [x] Import `js-link-replacement` - PASS

#### 6.8 Internationalization (6 tests) [COMPLETE]
- [x] Import `rtl-1/2/3/4` - PASS
- [x] Import `mathjax` - PASS
- [x] Import `005-unescape-html-entities` - PASS

#### 6.9 Edge Cases (4 tests)
- [x] Import `comment-inside-script-parsing` - PASS
- [x] Import `metadata-content-missing` - PASS
- [x] Import `toc-missing` - PASS
- [x] Import `bug-1255978` - PASS

---

## Mozilla Test Case Import Priority

### Completed Test Imports

**Phase 1-4 (Foundation & Core):**
- [x] `title-en-dash`, `title-and-h1-discrepancy` - Title handling
- [x] `keep-images`, `keep-tabular-data` - Content preservation
- [x] `003-metadata-preferred`, `004-metadata-space-separated-properties` - Metadata
- [x] `parsely-metadata`, `schema-org-context-object` - JSON-LD

**Phase 5 (Content Quality):**
- [x] `001` - Byline extraction from HTML
- [x] `basic-tags-cleaning`, `remove-script-tags` - Basic cleaning
- [x] `replace-brs`, `replace-font-tags` - Tag conversion (resolved)
- [x] `remove-aria-hidden`, `style-tags-removal`, `normalize-spaces` - Preprocessing

### Phase 6 Import Queue (by priority)

**Batch 1: Deferred Core Gap (1 test)**
- `002` - PASS

**Batch 2: Content Post-Processing (6 tests)**
- `002`, `ol` - Basic validation
- `reordering-paragraphs`, `missing-paragraphs` - Paragraph handling
- `remove-extra-brs`, `remove-extra-paragraphs` - Cleanup

**Batch 3: Conditional Cleaning (6 tests)**
- `clean-links`, `links-in-tables`, `social-buttons`
- `article-author-tag`, `table-style-attributes`, `invalid-attributes`

**Batch 4: Visibility (2 tests)**
- `hidden-nodes`, `visibility-hidden`

**Batch 5: Media (6 tests)**
- `lazy-image-1/2/3`, `data-url-image`
- `embedded-videos`, `videos-1/2`

**Batch 6: SVG (1 test)**
- `svg-parsing`

**Batch 7: URL Processing (4 tests)**
- `base-url`, `base-url-base-element`, `base-url-base-element-relative`
- `js-link-replacement`

**Batch 8: Internationalization (6 tests)**
- `rtl-1/2/3/4`, `mathjax`, `005-unescape-html-entities`

**Batch 9: Edge Cases (4 tests)**
- `comment-inside-script-parsing`, `toc-missing`
- `metadata-content-missing`, `bug-1255978`

### Phase 7: Real-World Sites (78 tests)

Real-world site tests from major websites (wikipedia, nytimes, medium, bbc, cnn, etc.)

---

## Summary

### Completed Phases (1-5)

All foundation work is complete through Phase 5:

- **Phase 1**: Configuration and error handling
- **Phase 2**: Document preprocessing (tag removal, BR handling)
- **Phase 3**: Metadata extraction (JSON-LD, OpenGraph, Dublin Core)
- **Phase 4**: Core scoring algorithm (Top N candidates, sibling merging, multi-attempt fallback)
- **Phase 5**: Content quality improvements (text node ordering fix, HTML byline extraction)

**Phase 4 Implementation:** See `CORE.md` for detailed breakdown of Phases A-H.

### Current Focus: Phase 6

**Goal:** Maintain all 52 standard functional tests at 95%+ pass rate.

**Current Status:** 52/52 standard tests imported, compatibility suite fully passing

**Active Work:**
1. Maintain functional/core baseline (`52/52`) while preventing regressions
2. Keep imported standard suite green with strict DOM comparator
3. Keep Stage 3-F baseline stable while preparing Stage 3-R

### Phase 7 Preview

After completing Phase 6, Phase 7 will focus on:
- Importing 78 real-world site tests
- Performance optimization
- API documentation
- Release preparation

---

## Known Issues History

This section tracks resolved and active known issues for reference.

### Resolved Issues

#### 1. Text Node Ordering in Content Extraction [FIXED in Phase 5.1]

**Tests Affected:** `001` (was 89%, now 100%)

**Problem:** During DOM manipulation, text nodes and inline elements were reordered because `cloneElement()` processed `children()` first, then `textNodes()`.

**Solution:** Changed all `cloneElement` implementations to use `getChildNodes()` which preserves the original mixed order of elements and text.

**Files Modified:**
- `DOMHelpers.swift` - Added shared `cloneElement()` utility
- `Readability.swift`, `SiblingMerger.swift`, `ArticleCleaner.swift` - Use `DOMHelpers.cloneElement()`

#### 2. Byline Extraction from HTML Content [FIXED in Phase 5.2]

**Test:** `001 - Byline`

**Implementation:**
- Added byline detection in `NodeCleaner.checkAndExtractByline()`
- Detects `rel="author"`, `itemprop="author"`, and byline class/id patterns
- Searches for `itemprop="name"` child nodes for accurate author names
- Proper priority: metadata byline > HTML content byline

### Resolved Issues (Phase 6.1)

#### 1. BR to Paragraph Conversion [FIXED]

**Test:** `replace-brs`

**Status:** FIXED - Similarity improved from 92% to 100%

**Problem:**
- Expected: Multiple `<p>` paragraphs with `<br />` tags preserved
- Actual: Single paragraph with BRs removed, content merged

**Root Cause:** Original `replaceBrs()` didn't correctly implement Mozilla's algorithm for:
- Skipping whitespace text nodes between BR elements (using `_nextNode` equivalent)
- Properly handling phrasing content collection after creating paragraph
- Removing trailing whitespace from new paragraphs

**Solution:**
- Implemented `nextNode()` helper to skip whitespace text nodes (matching Mozilla's `_nextNode`)
- Properly detect BR chains (2+ consecutive BRs)
- Move phrasing content into new paragraph until next BR chain or non-phrasing content
- Remove trailing whitespace from paragraphs
- Handle parent P tag conversion to DIV

**Files Modified:** `Readability.swift`

#### 2. Font Tag Conversion [FIXED]

**Test:** `replace-font-tags`

**Status:** FIXED - Similarity improved from 98% to 100%

**Problem:** Minor structural differences in output, missing attributes and text content

**Root Cause:** Original `replaceFontTags()` only copied child elements, not:
- Attributes (face, size, etc.)
- Text nodes directly inside font tags

**Solution:**
- Copy all attributes from `<font>` to `<span>`
- Use `getChildNodes()` to include text nodes, not just `children()`
- Move all child nodes (not copy) to preserve document structure

**Files Modified:** `Readability.swift`

### Active Issues

- None currently active in imported set.

---

## See Also

- `AGENTS.md` - Core principles, coding standards, and testing guidelines
- `CORE.md` - Phase 4 detailed implementation plan (Phases A-H)
- `INIT.md` - Original project planning (Chinese)
