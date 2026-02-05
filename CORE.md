# Phase 4 Core Scoring Algorithm - Difference Analysis

This document analyzes the differences between our Swift implementation and Mozilla's original Readability.js in Phase 4 (Core Scoring Algorithm).

**Goal:** Achieve maximum compatibility with Mozilla's implementation.

---

## 1. Critical Differences Overview

| Feature | Our Implementation | Mozilla Readability.js | Impact |
|---------|-------------------|------------------------|--------|
| Top Candidates Selection | Single best candidate | Top N (default 5) with competition analysis | HIGH - Affects sibling merging |
| Ancestor Score Propagation | Parent only (1 level) | Up to 5 levels with dividers | MEDIUM - Affects scoring accuracy |
| Sibling Content Merging | Not implemented | Full sibling analysis and merging | HIGH - Missing related content |
| Multi-attempt Fallback | Not implemented | 3 flags with progressive fallback | HIGH - Reduced extraction success |
| Unlikely Candidate Removal | Not implemented | Full regex-based removal | HIGH - Noise in extraction |
| DIV to P Conversion | Simplified | Full phrasing content analysis | MEDIUM - Structural differences |
| Link Density Calculation | Basic | Hash URL coefficient (0.3) | LOW-MEDIUM - Minor scoring difference |
| Node Initialization | Partial | Full `_initializeNode` with all tags | MEDIUM - Missing base scores |

---

## 2. Detailed Difference Analysis

### 2.1 Top Candidates Selection (HIGH IMPACT)

**Mozilla's Implementation:**
```javascript
// Lines 1304-1332: Maintains top N candidates sorted by score
var topCandidates = [];
for (var c = 0, cl = candidates.length; c < cl; c += 1) {
  var candidate = candidates[c];
  var candidateScore = candidate.readability.contentScore * (1 - this._getLinkDensity(candidate));
  
  for (var t = 0; t < this._nbTopCandidates; t++) {
    var aTopCandidate = topCandidates[t];
    if (!aTopCandidate || candidateScore > aTopCandidate.readability.contentScore) {
      topCandidates.splice(t, 0, candidate);
      if (topCandidates.length > this._nbTopCandidates) {
        topCandidates.pop();
      }
      break;
    }
  }
}
```

**Our Implementation:**
```swift
// Only selects single best element
var bestElement: Element?
var bestScore: Double = 0
for (_, (element, score)) in scoreMap {
  if score > bestScore {
    bestScore = score
    bestElement = element
  }
}
```

**Impact:** Without Top N candidates, we cannot:
1. Analyze competition tightness (lines 1357-1392)
2. Find common ancestor of multiple good candidates
3. Properly merge sibling content from related candidates

**Solution:** Implement Top N candidate tracking with `nbTopCandidates` option support.

---

### 2.2 Ancestor Score Propagation (MEDIUM IMPACT)

**Mozilla's Implementation:**
```javascript
// Lines 1273-1299: 5-level ancestor propagation with dividers
var ancestors = this._getNodeAncestors(elementToScore, 5);
this._forEachNode(ancestors, function (ancestor, level) {
  if (typeof ancestor.readability === 'undefined') {
    this._initializeNode(ancestor);
    candidates.push(ancestor);
  }
  // Score divider: parent=1, grandparent=2, great+ = level*3
  if (level === 0) {
    var scoreDivider = 1;
  } else if (level === 1) {
    scoreDivider = 2;
  } else {
    scoreDivider = level * 3;
  }
  ancestor.readability.contentScore += contentScore / scoreDivider;
});
```

**Our Implementation:**
```swift
// Only parent level with fixed multiplier
if let parent = element.parent() {
  let parentScore = score * Configuration.ancestorScoreMultiplier
  if parentScore > 0 {
    candidates.append((parent, parentScore))
  }
}
```

**Impact:** Less accurate scoring for nested content structures.

**Solution:** Implement `_getNodeAncestors` with level-based dividers.

---

### 2.3 Sibling Content Merging (HIGH IMPACT)

**Mozilla's Implementation:**
```javascript
// Lines 1441-1532: Extensive sibling analysis
var articleContent = doc.createElement("DIV");
var siblingScoreThreshold = Math.max(10, topCandidate.readability.contentScore * 0.2);
var siblings = parentOfTopCandidate.children;

for (var s = 0, sl = siblings.length; s < sl; s++) {
  var sibling = siblings[s];
  var append = false;
  
  // Give bonus if sibling has same classname
  if (sibling.className === topCandidate.className && topCandidate.className !== "") {
    contentBonus += topCandidate.readability.contentScore * 0.2;
  }
  
  // Append if score above threshold
  if (sibling.readability && sibling.readability.contentScore + contentBonus >= siblingScoreThreshold) {
    append = true;
  } else if (sibling.nodeName === "P") {
    // Special P tag handling with link density checks
    var linkDensity = this._getLinkDensity(sibling);
    var nodeContent = this._getInnerText(sibling);
    var nodeLength = nodeContent.length;
    
    if (nodeLength > 80 && linkDensity < 0.25) {
      append = true;
    } else if (nodeLength < 80 && nodeLength > 0 && linkDensity === 0 && nodeContent.search(/\.( |$)/) !== -1) {
      append = true;
    }
  }
}
```

**Our Implementation:** NOT IMPLEMENTED

**Impact:** Missing preambles, content split by ads, and related sections.

**Solution:** Implement full sibling merging logic after selecting top candidate.

---

### 2.4 Multi-attempt Fallback (HIGH IMPACT)

**Mozilla's Implementation:**
```javascript
// Lines 1055-1622: While loop with flag-based retry
while (true) {
  var stripUnlikelyCandidates = this._flagIsActive(this.FLAG_STRIP_UNLIKELYS);
  // ... scoring logic ...
  
  if (textLength < this._charThreshold) {
    parseSuccessful = false;
    page.innerHTML = pageCacheHtml; // Restore original
    
    if (this._flagIsActive(this.FLAG_STRIP_UNLIKELYS)) {
      this._removeFlag(this.FLAG_STRIP_UNLIKELYS);
    } else if (this._flagIsActive(this.FLAG_WEIGHT_CLASSES)) {
      this._removeFlag(this.FLAG_WEIGHT_CLASSES);
    } else if (this._flagIsActive(this.FLAG_CLEAN_CONDITIONALLY)) {
      this._removeFlag(this.FLAG_CLEAN_CONDITIONALLY);
    } else {
      // Return longest attempt
      this._attempts.sort(function (a, b) { return b.textLength - a.textLength; });
      articleContent = this._attempts[0].articleContent;
      parseSuccessful = true;
    }
  }
}
```

**Our Implementation:** Single pass only

**Impact:** Lower success rate on difficult pages.

**Solution:** Implement attempt tracking and flag-based retry mechanism.

---

### 2.5 Unlikely Candidate Removal (HIGH IMPACT)

**Mozilla's Implementation:**
```javascript
// Lines 1127-1151: Remove unlikely candidates during traversal
if (stripUnlikelyCandidates) {
  if (
    this.REGEXPS.unlikelyCandidates.test(matchString) &&
    !this.REGEXPS.okMaybeItsACandidate.test(matchString) &&
    !this._hasAncestorTag(node, "table") &&
    !this._hasAncestorTag(node, "code") &&
    node.tagName !== "BODY" &&
    node.tagName !== "A"
  ) {
    node = this._removeAndGetNext(node);
    continue;
  }
  
  if (this.UNLIKELY_ROLES.includes(node.getAttribute("role"))) {
    node = this._removeAndGetNext(node);
    continue;
  }
}
```

**Regex Patterns:**
- `unlikelyCandidates`: `-ad-|ai2html|banner|breadcrumbs|combx|comment|community|cover-wrap|disqus|extra|footer|gdpr|header|legends|menu|related|remark|replies|rss|shoutbox|sidebar|skyscraper|social|sponsor|supplemental|ad-break|agegate|pagination|pager|popup|yom-remote`
- `okMaybeItsACandidate`: `and|article|body|column|content|main|mathjax|shadow`

**Our Implementation:** NOT IMPLEMENTED

**Impact:** Navigation, ads, sidebars included in extraction.

**Solution:** Add `FLAG_STRIP_UNLIKELYS` and regex-based removal during DOM traversal.

---

### 2.6 DIV to P Conversion (MEDIUM IMPACT)

**Mozilla's Implementation:**
```javascript
// Lines 1175-1230: Complex phrasing content analysis
if (node.tagName === "DIV") {
  var childNode = node.firstChild;
  while (childNode) {
    var nextSibling = childNode.nextSibling;
    if (this._isPhrasingContent(childNode)) {
      var fragment = doc.createDocumentFragment();
      // Collect consecutive phrasing content
      do {
        nextSibling = childNode.nextSibling;
        fragment.appendChild(childNode);
        childNode = nextSibling;
      } while (childNode && this._isPhrasingContent(childNode));
      
      // Wrap in P tag
      if (fragment.firstChild) {
        var p = doc.createElement("p");
        p.appendChild(fragment);
        node.insertBefore(p, nextSibling);
      }
    }
    childNode = nextSibling;
  }
  
  // Convert DIV with single P and low link density
  if (this._hasSingleTagInsideElement(node, "P") && this._getLinkDensity(node) < 0.25) {
    var newNode = node.children[0];
    node.parentNode.replaceChild(newNode, node);
    node = newNode;
    elementsToScore.push(node);
  } else if (!this._hasChildBlockElement(node)) {
    node = this._setNodeTag(node, "P");
    elementsToScore.push(node);
  }
}
```

**Our Implementation:** Simplified BR replacement only

**Impact:** Structural differences in output, potentially affecting scoring.

**Solution:** Implement `_isPhrasingContent`, `_hasSingleTagInsideElement`, `_hasChildBlockElement`.

---

### 2.7 Node Initialization (MEDIUM IMPACT)

**Mozilla's Implementation:**
```javascript
// Lines 903-940: Full initialization with tag-based scores
_initializeNode(node) {
  node.readability = { contentScore: 0 };
  
  switch (node.tagName) {
    case "DIV":
      node.readability.contentScore += 5;
      break;
    case "PRE":
    case "TD":
    case "BLOCKQUOTE":
      node.readability.contentScore += 3;
      break;
    case "ADDRESS":
    case "OL":
    case "UL":
    case "DL":
    case "DD":
    case "DT":
    case "LI":
    case "FORM":
      node.readability.contentScore -= 3;
      break;
    case "H1":
    case "H2":
    case "H3":
    case "H4":
    case "H5":
    case "H6":
    case "TH":
      node.readability.contentScore -= 5;
      break;
  }
  
  node.readability.contentScore += this._getClassWeight(node);
}
```

**Our Implementation:** Score calculation inline during `scoreElement`

**Impact:** Different base scores, no `readability` property on nodes.

**Solution:** Create `_initializeNode` equivalent and store scores on elements.

---

### 2.8 Link Density Calculation (LOW-MEDIUM IMPACT)

**Mozilla's Implementation:**
```javascript
// Lines 2143-2158: Hash URL coefficient
_getLinkDensity(element) {
  var textLength = this._getInnerText(element).length;
  if (textLength === 0) {
    return 0;
  }
  
  var linkLength = 0;
  this._forEachNode(element.getElementsByTagName("a"), function (linkNode) {
    var href = linkNode.getAttribute("href");
    var coefficient = href && this.REGEXPS.hashUrl.test(href) ? 0.3 : 1;
    linkLength += this._getInnerText(linkNode).length * coefficient;
  });
  
  return linkLength / textLength;
}
```

**Our Implementation:** Basic calculation without hash URL handling

**Solution:** Add hash URL coefficient to link density calculation.

---

## 3. Technical Barriers and Solutions

### 3.1 SwiftSoup vs JSDOM Differences

| Feature | JSDOM | SwiftSoup | Solution |
|---------|-------|-----------|----------|
| Custom properties on nodes | `node.readability = {}` | Not supported directly | Use external Dictionary `[Element: NodeScore]` |
| Live NodeList | Supported | Not supported | Create static arrays before iteration |
| `textContent` | Direct property | `try element.text()` | Wrap in helper function |
| `innerText` vs `textContent` | Different semantics | Only text() | Implement `_getInnerText` with visibility check |
| `ownerDocument.createElement` | Supported | `Element(Tag("div"), "")` | Create DOM helper extension |

### 3.2 Reference Semantics

**Barrier:** SwiftSoup `Element` is a class (reference type), but we need to associate scores with specific instances.

**Solution:** Use `ObjectIdentifier` as dictionary key:
```swift
struct NodeScore {
  var contentScore: Double
  var initialized: Bool
}

var nodeScores: [ObjectIdentifier: NodeScore] = [:]
```

### 3.3 DOM Traversal

**Barrier:** Mozilla uses `_getNextNode` for depth-first traversal with removal support.

**Solution:** Implement equivalent traversal:
```swift
func getNextNode(_ node: Element, ignoreSelfAndKids: Bool = false) -> Element? {
  if !ignoreSelfAndKids, let firstChild = node.children().first {
    return firstChild
  }
  if let nextSibling = try? node.nextElementSibling() {
    return nextSibling
  }
  var current: Element? = node
  while let parent = current?.parent() {
    if let sibling = try? parent.nextElementSibling() {
      return sibling
    }
    current = parent
  }
  return nil
}
```

### 3.4 Tag Name Changes

**Barrier:** SwiftSoup doesn't support direct tag name modification.

**Solution:** Implement `_setNodeTag` equivalent:
```swift
func setNodeTag(_ node: Element, newTag: String) throws -> Element {
  let newNode = Element(Tag(newTag), try node.baseUri())
  // Copy children
  for child in node.children() {
    try newNode.appendChild(child)
  }
  // Copy attributes
  for attr in node.getAttributes() {
    try newNode.attr(attr.getKey(), attr.getValue())
  }
  // Replace in DOM
  try node.replaceWith(newNode)
  return newNode
}
```

---

## 4. Implementation Priority

### P0 (Critical - Must Fix)
1. **Unlikely Candidate Removal** - Currently including navigation/ads
2. **Multi-attempt Fallback** - Reduces extraction success rate
3. **Top N Candidates** - Required for sibling merging

### P1 (High - Should Fix)
4. **Sibling Content Merging** - Missing related content sections
5. **Ancestor Score Propagation** - Affects scoring accuracy
6. **DIV to P Conversion** - Structural compatibility

### P2 (Medium - Nice to Have)
7. **Node Initialization** - Code organization and scoring consistency
8. **Link Density Hash URL** - Minor scoring improvement

---

## 5. Recommended Implementation Order

```
Step 1: Add FLAG system and Unlikely Candidate Removal
        - Add FLAG_STRIP_UNLIKELYS, FLAG_WEIGHT_CLASSES, FLAG_CLEAN_CONDITIONALLY
        - Implement REGEXPS.unlikelyCandidates and REGEXPS.okMaybeItsACandidate
        - Add to grabArticle loop

Step 2: Implement Top N Candidates
        - Change candidate selection to maintain sorted array
        - Add nbTopCandidates option support
        - Implement alternative ancestor analysis

Step 3: Add Sibling Merging
        - After top candidate selection
        - Implement siblingScoreThreshold logic
        - Handle special P tag cases

Step 4: Add Multi-attempt Fallback
        - Wrap grabArticle in while loop
        - Implement _attempts tracking
        - Add flag removal progression

Step 5: Fix Ancestor Propagation
        - Implement _getNodeAncestors
        - Add level-based score dividers

Step 6: Add DIV to P Conversion
        - Implement _isPhrasingContent
        - Implement _hasSingleTagInsideElement
        - Implement _hasChildBlockElement
```

---

## 6. Test Case Verification

After implementing changes, verify against these Mozilla test cases:

| Test Case | Validates |
|-----------|-----------|
| `title-en-dash` | Title extraction with en-dash separator |
| `title-and-h1-discrepancy` | Title/h1 comparison logic |
| `keep-images` | Image preservation in content |
| `keep-tabular-data` | Table handling |
| `lazy-image-*` | Lazy image fixing |
| `hidden-nodes` | Visibility-based filtering |
| `basic-tags-cleaning` | Basic content cleaning |
| `remove-extra-paragraphs` | Paragraph cleanup |

---

## 7. Source Code Architecture

Given the complexity of the Core Scoring Algorithm, we will split the implementation into focused source files rather than keeping everything in `Readability.swift`.

### 7.1 Proposed File Structure

```
Sources/Readability/
├── Readability.swift              # Main entry point, public API
├── ReadabilityOptions.swift       # Configuration options
├── ReadabilityResult.swift        # Result structure
├── ReadabilityError.swift         # Error types
├── Internal/
│   ├── Configuration.swift        # Constants and regex patterns
│   ├── DOMHelpers.swift           # DOM utility functions
│   ├── DOMTraversal.swift         # Node traversal utilities
│   ├── NodeScoring.swift          # Score storage and management
│   ├── ContentExtractor.swift     # Main _grabArticle logic
│   ├── CandidateSelector.swift    # Top N candidate selection
│   ├── SiblingMerger.swift        # Sibling content merging
│   ├── NodeCleaner.swift          # Unlikely candidate removal
│   └── ArticleCleaner.swift       # _prepArticle and _cleanConditionally
```

### 7.2 File Responsibilities

#### `DOMTraversal.swift`
- `getNextNode(_:ignoreSelfAndKids:)` - Depth-first traversal
- `removeAndGetNext(_:)` - Remove node and continue traversal
- `getNodeAncestors(_:maxDepth:)` - Ancestor chain collection
- `hasAncestorTag(_:tagName:maxDepth:filter:)` - Ancestor checking

#### `NodeScoring.swift`
- `NodeScore` struct for score storage
- `NodeScoringManager` class - `[ObjectIdentifier: NodeScore]` management
- `initializeNode(_:)` - Base score assignment by tag
- `getClassWeight(_:)` - Class/id pattern scoring
- `getLinkDensity(_:)` - Link density with hash URL handling

#### `ContentExtractor.swift`
- `ContentExtractor` class - Main article extraction orchestrator
- `grabArticle()` - Main entry with multi-attempt loop
- `prepDocument()` - Document preparation
- `flags` management (FLAG_STRIP_UNLIKELYS, etc.)

#### `CandidateSelector.swift`
- `Candidate` struct - Element + score wrapper
- `TopCandidates` class - Sorted top N maintenance
- `selectTopCandidate(from:)` - Selection with alternative ancestor analysis
- `findBetterTopCandidate(_:)` - Parent traversal logic

#### `SiblingMerger.swift`
- `SiblingMerger` class
- `mergeSiblings(topCandidate:into:)` - Main merging logic
- `shouldAppendSibling(_:threshold:topCandidate:)` - Decision logic

#### `NodeCleaner.swift`
- `NodeCleaner` class
- `removeUnlikelyCandidates(from:)` - Regex-based removal
- `isProbablyVisible(_:)` - Visibility checking
- `headerDuplicatesTitle(_:)` - Title duplicate detection
- `isValidByline(_:matchString:)` - Byline detection

#### `ArticleCleaner.swift`
- `ArticleCleaner` class
- `prepArticle(_:)` - Post-extraction cleaning
- `cleanConditionally(_:tag:)` - Conditional element removal
- `cleanHeaders(_:)` - Header cleanup
- `markDataTables(_:)` - Data table detection
- `fixLazyImages(_:)` - Lazy image handling
- `hasSingleTagInsideElement(_:tag:)` - Single tag check
- `hasChildBlockElement(_:)` - Block child detection
- `isPhrasingContent(_:)` - Phrasing content check
- `setNodeTag(_:newTag:)` - Tag name change

---

## 8. Implementation Plan

### Phase A: Foundation (Week 1)
**Goal:** Establish infrastructure for scoring algorithm

| Task | File | Description | Est. Time |
|------|------|-------------|-----------|
| A.1 | `DOMTraversal.swift` | Implement traversal utilities | 4h |
| A.2 | `NodeScoring.swift` | Score storage and initialization | 6h |
| A.3 | `Configuration.swift` | Add missing regex patterns | 2h |
| A.4 | Tests | Unit tests for traversal and scoring | 4h |

**Deliverables:**
- `getNextNode`, `getNodeAncestors` working
- `NodeScoringManager` with `[ObjectIdentifier: NodeScore]`
- All Mozilla regex patterns added

**Verification:**
```swift
// Test: Node scoring storage
let manager = NodeScoringManager()
manager.initializeNode(divElement)
XCTAssertEqual(manager.getScore(divElement), 5.0) // DIV base score
```

---

### Phase B: Node Cleaner (Week 1-2)
**Goal:** Implement noise reduction

| Task | File | Description | Est. Time |
|------|------|-------------|-----------|
| B.1 | `NodeCleaner.swift` | Unlikely candidate removal | 6h |
| B.2 | `NodeCleaner.swift` | Visibility and role checks | 2h |
| B.3 | `NodeCleaner.swift` | Byline extraction from content | 4h |
| B.4 | Tests | Node cleaner unit tests | 4h |

**Deliverables:**
- `FLAG_STRIP_UNLIKELYS` support
- Regex-based unlikely candidate removal
- ARIA role filtering (`UNLIKELY_ROLES`)
- Byline detection from article content

**Verification:**
- Test: `hidden-nodes` - Visibility-based filtering
- Test: `remove-aria-hidden` - Aria hidden removal
- Test: `title-and-h1-discrepancy` - Header duplicate detection

---

### Phase C: Candidate Selection (Week 2)
**Goal:** Implement Top N candidate selection

| Task | File | Description | Est. Time |
|------|------|-------------|-----------|
| C.1 | `CandidateSelector.swift` | TopCandidates sorted array | 4h |
| C.2 | `CandidateSelector.swift` | Alternative ancestor analysis | 4h |
| C.3 | `CandidateSelector.swift` | Parent score traversal | 3h |
| C.4 | `ContentExtractor.swift` | Integration with grabArticle | 3h |
| C.5 | Tests | Candidate selection tests | 4h |

**Deliverables:**
- Top N candidates maintained during scoring
- Alternative ancestor selection (MINIMUM_TOPCANDIDATES = 3)
- Parent traversal for better candidate

**Verification:**
```swift
// Test: Multiple candidates
let selector = CandidateSelector(options: .default)
// Score multiple elements
// Verify top 5 are tracked and sorted
```

---

### Phase D: Sibling Merging (Week 3)
**Goal:** Merge related sibling content

| Task | File | Description | Est. Time |
|------|------|-------------|-----------|
| D.1 | `SiblingMerger.swift` | Threshold calculation | 2h |
| D.2 | `SiblingMerger.swift` | Classname bonus logic | 2h |
| D.3 | `SiblingMerger.swift` | P tag special handling | 4h |
| D.4 | `SiblingMerger.swift` | DIV to P conversion during merge | 4h |
| D.5 | Tests | Sibling merging tests | 4h |

**Deliverables:**
- `siblingScoreThreshold` calculation
- Classname matching bonus
- P tag link density checks
- `ALTER_TO_DIV_EXCEPTIONS` handling

**Verification:**
- Test: `basic-tags-cleaning` - Proper content merging
- Test: `remove-extra-paragraphs` - P tag handling

---

### Phase E: Multi-attempt Fallback (Week 3-4)
**Goal:** Robust extraction with progressive fallback

| Task | File | Description | Est. Time |
|------|------|-------------|-----------|
| E.1 | `ContentExtractor.swift` | While loop wrapper | 2h |
| E.2 | `ContentExtractor.swift` | Attempt tracking | 3h |
| E.3 | `ContentExtractor.swift` | Flag progression logic | 3h |
| E.4 | `ContentExtractor.swift` | Page cache restore | 2h |
| E.5 | Tests | Fallback behavior tests | 4h |

**Deliverables:**
- `FLAG_STRIP_UNLIKELYS` -> `FLAG_WEIGHT_CLASSES` -> `FLAG_CLEAN_CONDITIONALLY` progression
- `_attempts` array tracking
- Page HTML caching and restore

**Verification:**
```swift
// Test: Fallback progression
// 1. First attempt with all flags - may fail
// 2. Second attempt without STRIP_UNLIKELYS
// 3. Third attempt without WEIGHT_CLASSES
// 4. Fourth attempt without CLEAN_CONDITIONALLY
```

---

### Phase F: DIV to P Conversion (Week 4)
**Goal:** Proper phrasing content handling

| Task | File | Description | Est. Time |
|------|------|-------------|-----------|
| F.1 | `ArticleCleaner.swift` | `isPhrasingContent` | 2h |
| F.2 | `ArticleCleaner.swift` | `hasSingleTagInsideElement` | 2h |
| F.3 | `ArticleCleaner.swift` | `hasChildBlockElement` | 2h |
| F.4 | `ArticleCleaner.swift` | DIV to P conversion logic | 4h |
| F.5 | `ArticleCleaner.swift` | `setNodeTag` helper | 2h |
| F.6 | Tests | DIV to P conversion tests | 3h |

**Deliverables:**
- `PHRASING_ELEMS` set
- `DIV_TO_P_ELEMS` set
- Full DIV to P conversion pipeline

**Verification:**
- Test: `replace-brs` - BR handling
- Test: `remove-extra-brs` - Extra BR removal
- Test: `remove-extra-paragraphs` - Paragraph cleanup

---

### Phase G: Article Cleaning (Week 5)
**Goal:** Complete `_prepArticle` and `_cleanConditionally`

| Task | File | Description | Est. Time |
|------|------|-------------|-----------|
| G.1 | `ArticleCleaner.swift` | `_cleanConditionally` | 8h |
| G.2 | `ArticleCleaner.swift` | Data table preservation | 3h |
| G.3 | `ArticleCleaner.swift` | Header cleaning | 2h |
| G.4 | `ArticleCleaner.swift` | Single-cell table flattening | 2h |
| G.5 | Tests | Article cleaning tests | 4h |

**Deliverables:**
- Image-to-paragraph ratio checks
- Input count checks
- Link density thresholds
- Content length validation
- Ad/loading words detection

**Verification:**
- Test: `keep-tabular-data` - Table preservation
- Test: `basic-tags-cleaning` - Tag cleaning
- Test: `remove-script-tags` - Script removal

---

### Phase H: Integration & Polish (Week 6)
**Goal:** Full integration and test suite validation

| Task | Description | Est. Time |
|------|-------------|-----------|
| H.1 | Refactor `Readability.swift` to use new modules | 4h |
| H.2 | Integration tests with Mozilla test cases | 6h |
| H.3 | Performance optimization | 4h |
| H.4 | Documentation updates | 2h |

**Deliverables:**
- `Readability.swift` under 300 lines
- All modules integrated
- 80%+ Mozilla test pass rate

**Verification:**
- Full test suite run
- Performance benchmark
- Memory usage check

---

## 9. Milestones

| Milestone | Target | Success Criteria |
|-----------|--------|------------------|
| M1 | End of Week 1 | DOM traversal and scoring infrastructure complete, all unit tests pass |
| M2 | End of Week 2 | Node cleaner and candidate selection complete, 40% Mozilla tests pass |
| M3 | End of Week 3 | Sibling merging and fallback complete, 60% Mozilla tests pass |
| M4 | End of Week 4 | DIV to P conversion complete, 70% Mozilla tests pass |
| M5 | End of Week 5 | Article cleaning complete, 80% Mozilla tests pass |
| M6 | End of Week 6 | Integration complete, 85%+ Mozilla tests pass, performance verified |

---

## 10. Risk Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| SwiftSoup API limitations | Medium | High | Create wrapper extensions, document workarounds |
| Performance degradation | Medium | Medium | Profile early, optimize hot paths, caching |
| Test case divergence | Low | High | Strict Mozilla test compliance, document deviations |
| Memory leaks | Low | Medium | Use weak references where appropriate, ARC verification |
| Swift 6 concurrency issues | Low | High | Ensure Sendable conformance, avoid shared mutable state |

---

## 11. Implementation Guidelines

### 11.1 Code Standards
- Each module has a single responsibility
- All public methods have documentation comments
- Unit tests accompany every module
- Use `throws` for error handling consistently
- Prefer value types (`struct`) where possible

### 11.2 Testing Strategy
- Unit tests for each module in isolation
- Integration tests for module interactions
- Mozilla test case validation
- Performance benchmarks

### 11.3 Documentation
- Update `CORE.md` with implementation details
- Document Swift-specific workarounds
- Maintain API documentation
- Add inline comments for complex logic

---

## 12. Conclusion

Our current Phase 4 implementation is a simplified version that works for basic cases but lacks several critical algorithms:

1. **Noise Reduction**: Missing unlikely candidate removal
2. **Robustness**: No fallback mechanism for difficult pages
3. **Completeness**: Missing sibling content merging
4. **Accuracy**: Simplified scoring propagation

The modular architecture proposed above will:
- Improve maintainability by separating concerns
- Enable independent testing of components
- Make the codebase more approachable for contributors
- Facilitate future enhancements

The 6-week implementation plan prioritizes critical features first (noise reduction, fallback) while building up to full compatibility. Each phase has clear deliverables and verification criteria.

The technical barriers are manageable - primarily requiring:
- External score storage using `ObjectIdentifier`
- Helper functions for DOM manipulation
- Careful porting of regex patterns

Following the recommended implementation order will progressively improve compatibility with Mozilla's test suite.
