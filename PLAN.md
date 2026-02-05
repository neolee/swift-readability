# Swift Readability Porting Plan

This document outlines the phased implementation plan for porting Mozilla Readability.js to Swift.

**Current Status:** Phase 1 Complete  
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

## Phase 2: Document Preprocessing

**Goal:** Complete `prepDocument()` and related methods

### 2.1 Tag Removal
- [ ] `<template>` tags
- [ ] SVG handling (preserve references, optionally inline)
- [ ] Special character handling

### 2.2 BR Tag Processing
- [ ] Multiple consecutive `<br>` handling
- [ ] Paragraph conversion logic refinement

### 2.3 Font Tag Replacement
- [ ] Complete `<font>` to `<span>` conversion
- [ ] Attribute preservation

### Verification
Each feature must:
- Have corresponding Mozilla test case
- Pass exact match comparison with `expected.html`

---

## Phase 3: Metadata Extraction

**Goal:** Full metadata extraction from all sources

### 3.1 JSON-LD Parsing
- [ ] Parse `application/ld+json` scripts
- [ ] Extract `headline`, `author`, `datePublished`, `publisher`
- [ ] Handle nested structures

### 3.2 Open Graph Tags
- [ ] `og:title`, `og:description`, `og:site_name`
- [ ] `og:type` handling

### 3.3 Dublin Core and Twitter Cards
- [ ] `dc:title`, `dc:creator`
- [ ] `twitter:title`, `twitter:description`

### 3.4 Meta Tag Extraction Priority
Implement Mozilla's exact priority order:
1. JSON-LD
2. `dc:description` / `dcterm:description`
3. `og:description`
4. `weibo:article:description`
5. `description`
6. `twitter:description`

### Verification
- All 001 test metadata fields must match exactly
- Byline extraction: "Nicolas Perriault"
- Excerpt extraction: "Nicolas Perriault's homepage."

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

| Phase | Target Pass Rate | Test Cases |
|-------|------------------|------------|
| Phase 1 | N/A (foundation) | 4 |
| Phase 2 | 30% | 20-30 |
| Phase 3 | 40% | 40-50 |
| Phase 4 | 60% | 60-80 |
| Phase 5 | 80% | 100-120 |
| Phase 6 | 90%+ | 130 (all) |

**Current:** 4/130 test cases (3%), 10/10 tests passing with 4 known issues

---

## Mozilla Test Case Import Priority

### Immediate (Phase 2-3)
- `003-metadata-preferred`
- `004-metadata-space-separated-properties`
- `parsely-metadata`
- `schema-org-context-object`
- `replace-font-tags`
- `remove-aria-hidden`
- `style-tags-removal`

### Near-term (Phase 4-5)
- `title-en-dash`
- `title-and-h1-discrepancy`
- `normalize-spaces`
- `keep-images`
- `keep-tabular-data`
- `lazy-image-*`

### Complete Set (Phase 6)
All 130 Mozilla test cases for full compatibility verification

---

## See Also

- `AGENTS.md` - Core principles and coding standards
- `TESTS.md` - Detailed testing strategy and current progress
- `INIT.md` - Original project planning (Chinese)
