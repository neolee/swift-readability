# Swift Readability Porting Plan

This document outlines the phased implementation plan for porting Mozilla Readability.js to Swift.

**Current Status:** Phase 3 Complete  
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
- 10 tests passing (6 with known issues for content structure)
- All basic functionality working

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
- [x] `003-metadata-preferred`: Dublin Core priority working
- [x] `004-metadata-space-separated-properties`: Space-separated properties working
- [x] `parsely-metadata`: Parsely metadata extraction working
- [x] `schema-org-context-object`: JSON-LD parsing working (title, siteName, publishedTime)

**Note:** Byline extraction for `001` and `schema-org-context-object` requires HTML content parsing (Phase 5), as these tests expect bylines from article body content, not metadata.

---

## Phase 4: Core Scoring Algorithm

**Goal:** Complete `_grabArticle` and `_initializeNode` logic

### 4.1 Node Scoring Refinement
- [ ] Precise tag weights
- [ ] Ancestor score propagation (more levels)
- [ ] Link density calculation optimization

### 4.2 Top N Candidate Selection
- [ ] Collect top candidates (not just highest)
- [ ] Sibling node merging
- [ ] Common ancestor lookup

### 4.3 Multi-Attempt Fallback
- [ ] Retry with different selectors
- [ ] Alternative strategies for edge cases

### Verification
- 60%+ Mozilla test pass rate
- Real article pages extract correctly

---

## Phase 5: Content Cleaning

**Goal:** Full `_prepArticle` and `_cleanConditionally` implementation

### 5.1 Conditional Cleaning
Remove elements based on:
- [ ] Image-to-paragraph ratio
- [ ] Input element count
- [ ] Link density thresholds
- [ ] Content length checks
- [ ] Ad/navigation pattern detection

### 5.2 Tag Transformation
- [ ] `<div>` to `<p>` conversion (when appropriate)
- [ ] Attribute cleanup (respecting `keepClasses`)
- [ ] Empty container removal

### 5.3 Image Handling
- [ ] Lazy load image fixing (`data-src` to `src`)
- [ ] Small image/icon removal
- [ ] Meaningful image preservation

### 5.4 SVG Handling (from Phase 2)
- [ ] SVG content in `<head>` removal
- [ ] Inline SVG preservation (when meaningful)
- [ ] SVG reference preservation (`<img src="*.svg">`, `<use>`)

### Verification
- 80%+ Mozilla test pass rate
- Clean output without navigation/ads

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
| Phase 2 | 30% | 20-30 | COMPLETE (8 test cases, limited by small test set) |
| Phase 3 | 40% | 40-50 | IN PROGRESS |
| Phase 4 | 60% | 60-80 | PENDING |
| Phase 5 | 80% | 100-120 | PENDING |
| Phase 6 | 90%+ | 130 (all) | PENDING |

**Current:** 8/130 test cases (6%), 18/18 tests passing with 5 known issues

---

## Mozilla Test Case Import Priority

### Phase 2 Completed
- [x] `replace-font-tags`
- [x] `remove-aria-hidden`
- [x] `style-tags-removal`
- [x] `normalize-spaces`

### Phase 3 (Metadata)
- `003-metadata-preferred`
- `004-metadata-space-separated-properties`
- `parsely-metadata`
- `schema-org-context-object`

### Phase 4 (Scoring)
- `title-en-dash`
- `title-and-h1-discrepancy`

### Phase 5 (Content Cleaning)
- `keep-images`
- `keep-tabular-data`
- `lazy-image-*`
- `svg-parsing` (deferred from Phase 2)
- `cnet-svg-classes` (deferred from Phase 2)

### Complete Set (Phase 6)
All 130 Mozilla test cases for full compatibility verification

---

## See Also

- `AGENTS.md` - Core principles and coding standards
- `TESTS.md` - Detailed testing strategy and current progress
- `INIT.md` - Original project planning (Chinese)
