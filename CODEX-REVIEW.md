# CODEX Review: Deep Assessment for Next-Stage Build

Date: 2026-02-06
Scope: `INIT.md`, `AGENTS.md`, `PLAN.md`, `Readability/` source and tests  
Explicit exclusion: `README.md` (deferred by project decision)

## Context and Assumptions

This review is reorganized around your three core concerns:

1. Gap between `MozillaCompatibilityTests` and Mozilla original test methodology
2. Structural/logical risks in the ported implementation that may block future progress
3. Whether auxiliary unit suites are strong enough to protect refactors

Working assumptions applied:

- `MozillaCompatibilityTests` is the final parity gate.
- `002` mismatch has been resolved under structural DOM comparison.
- Immediate focus is risk reduction and forward-compatibility of the codebase.
- Test import/execution strategy is explicitly two-phase:
  - Phase F (Functional): complete and pass all core functional Mozilla tests first.
  - Phase R (Real-world): import and stabilize real-world web page tests in a separate later phase.
- Highest concern is current code logic/structure quality, even when many tests are green.

## Snapshot (Current Local Reality)

From local `cd Readability && swift test`:

- Total: `298` tests
- Failed: `0`
- Known issues: `8` (real-world suite quarantine)

Imported Mozilla pages in this repo:

- Current local resources: `52` functional/core test pages (non real-world set)
- Mozilla upstream test pages in local ref: `130`

Test taxonomy alignment for planning:

- Functional/core set: approximately current imported scope and remaining standard feature pages.
- Real-world set: large site-based corpus (news/blog/community pages), to be handled in an isolated stage after Functional closure.

## 1) MozillaCompatibility vs Mozilla Original: Gap, Cost, Priority

### 1.1 What Mozilla original does

Mozilla test harness compares DOM structure node-by-node, not just text:

- In-order DOM traversal while ignoring empty text nodes
- Node type and node identity checks (`tag#id.class`)
- Text node value comparison (whitespace-collapsed)
- Element attribute count and value comparison (valid XML names only)
- Exact metadata assertions (`title`, `byline`, `excerpt`, `siteName`, optional `dir`, `lang`, `publishedTime`)

Reference:

- `ref/mozilla-readability/test/test-readability.js:39`
- `ref/mozilla-readability/test/test-readability.js:136`
- `ref/mozilla-readability/test/test-readability.js:158`
- `ref/mozilla-readability/test/test-readability.js:200`

### 1.2 What current Swift compatibility tests do

Current `DOMComparator.compare()`:

- Parses actual/expected HTML and normalizes through parser round-trip
- Performs in-order DOM traversal while ignoring ignorable text nodes
- Compares node descriptors, text content, and attributes
- Emits first-divergence diagnostics with node path and mismatch detail

Reference:

- `Readability/Tests/ReadabilityTests/MozillaCompatibilityTests.swift:27`
- `Readability/Tests/ReadabilityTests/TestSupport/DOMComparator.swift:11`

### 1.3 Additional parity deltas beyond comparator

1. `dir`/`lang` parity path is now implemented and validated:
   - `ReadabilityResult` now exposes `dir` and `lang`.
   - Compatibility tests now assert `dir`/`lang` on imported RTL/language cases.
   - References:
     - `Readability/Sources/Readability/ReadabilityResult.swift:3`
     - `Readability/Tests/ReadabilityTests/MozillaCompatibilityTests.swift:17`
     - `ref/mozilla-readability/test/test-readability.js:216`

2. Coverage status update (must respect two-phase strategy):
   - Local imported functional/core cases: `52`
   - Upstream total: `130`
   - Remaining imports are now in the real-world phase only.
   - Real-world pages remain intentionally deferred to Phase R.

### 1.4 Bridging plan for Mozilla parity (recommended, functional-first)

Priority update: comparator replacement, functional/core import, and `dir`/`lang` parity are complete; current priority is **P1** for Stage 3-R readiness.

Phase A (high value, low-medium cost, 1-2 days):

- Completed: structural DOM comparator now mirrors Mozilla-style traversal checks.
- Completed: first-divergence diagnostics are emitted with path + mismatch detail.

Phase B (medium cost, 2-4 days):

- Completed: metadata parity checks for `dir`/`lang` are active.
- Completed: `dir`/`lang` are exposed in `ReadabilityResult` during internal development phase.

Phase C-F (closure, Functional stage only):

- Functional/core import set is complete.
- Keep functional baseline green under strict structural comparator.

Phase C-R (separate later stage):

- After Functional set closure, import real-world pages as a dedicated compatibility-hardening phase.
- Track regressions separately from functional baseline to avoid blocking core algorithm stabilization.

## 2) Core Ported Code: Structural/Logical Risks

Below are key risks that may not fail current tests immediately but can derail future parity work.
This section is intentionally the highest-priority engineering focus.

### 2.1 Candidate promotion bug discards "better top candidate" result

In `selectTopCandidate`, result of `findBetterTopCandidate(...)` is immediately overwritten by promotion based on the old candidate variable, not the updated one.

- `topCandidate = try findBetterTopCandidate(...)`
- then `topCandidate = try promoteSingleChildCandidate(candidate)` (uses stale `candidate`)

Reference:

- `Readability/Sources/Readability/Internal/CandidateSelector.swift:35`
- `Readability/Sources/Readability/Internal/CandidateSelector.swift:40`

Impact:

- Alternative ancestor logic can silently become ineffective.
- Future complex pages may regress despite unit tests passing.

Priority: **P0**

### 2.2 Fallback candidate creation drops non-element child nodes

Fallback moves `body.children().first` repeatedly, which excludes text nodes/comments by design.

Reference:

- `Readability/Sources/Readability/Internal/CandidateSelector.swift:210`

Impact:

- Potential data loss in body-level mixed content edge cases.
- Hard-to-trace differences on long-tail pages.

Priority: **P1**

### 2.3 Score mutation side effect during candidate collection

`collectTopCandidates` applies link-density scaling and also mutates stored scores again (`multiplyScore`), even though scoring was already applied earlier.

Reference:

- `Readability/Sources/Readability/Internal/CandidateSelector.swift:63`
- `Readability/Sources/Readability/Internal/CandidateSelector.swift:72`

Impact:

- Selection stage mutates global scoring state, increasing coupling and making debugging nondeterministic.

Priority: **P1**

### 2.4 Several public options are currently dead/unimplemented

No effective usage found outside `ReadabilityOptions.swift` for:

- `maxElemsToParse`
- `useCustomSerializer`
- `allowedVideoRegex`
- `debug`

Evidence: no operational references in core pipeline files.

Impact:

- API appears feature-complete but behavior is missing.
- Future parity tasks may depend on these knobs.

Priority: **P1**

### 2.5 Class preservation can be stripped at final serialization

`ArticleCleaner` preserves configured classes, but final serializer later keeps only `"page"` when `keepClasses == false`, dropping option-preserved classes.

Reference:

- `Readability/Sources/Readability/Internal/ArticleCleaner.swift:227`
- `Readability/Sources/Readability/Readability.swift:610`

Impact:

- Behavior conflicts with declared options semantics.
- Can produce subtle output drift from Mozilla and test expectations.

Priority: **P1**

### 2.6 Paragraph wrapping algorithm risks order/content drift

`wrapPhrasingContentInParagraphs` iterates `children()` (elements only) and wrapping helper clones/appends, not move-in-place semantics for full child node stream.

Reference:

- `Readability/Sources/Readability/Internal/ArticleCleaner.swift:62`
- `Readability/Sources/Readability/Internal/ArticleCleaner.swift:81`

Impact:

- Mixed text + inline + block cases can reorder or duplicate effectively visible content.

Priority: **P1**

### 2.7 `replaceBrs` trailing whitespace cleanup likely incomplete

Cleanup loop checks `p.children().last` (elements only), so trailing text nodes are not handled by this branch.

Reference:

- `Readability/Sources/Readability/Readability.swift:377`

Impact:

- Can contribute to minor but persistent whitespace/content drift (relevant to deferred `002` class of issues).

Priority: **P2**

### 2.8 Parse lifecycle semantics are implicit and mutation-based

`parse()` mutates internal document state; repeated calls on same instance have undefined expectations (single-use vs repeatable).

Reference:

- `Readability/Sources/Readability/Readability.swift:7`
- `Readability/Sources/Readability/Readability.swift:17`

Impact:

- Refactor risk and surprising behavior for integrators.

Priority: **P2**

### 2.9 Performance hotspot likely in full rescans

Selection phase scans `body.select("*")` then filters by initialized score.

Reference:

- `Readability/Sources/Readability/Internal/ContentExtractor.swift:146`

Impact:

- Increased overhead on large documents.
- Will hurt when importing more real-world test pages.

Priority: **P3**

## 3) Auxiliary Unit Suites: Are They Strong Enough for Refactor Safety?

### 3.1 Strengths

- Good module-level coverage footprint (`NodeCleaner`, `NodeScoring`, `DOMTraversal`, `CandidateSelector`, `SiblingMerger`, `ContentExtractor`, `ArticleCleaner`).
- Useful for catching local algorithm regressions quickly.

### 3.2 Critical weaknesses

1. Weak assertions in several tests (`contains`, `count > 0`, permissive OR conditions), which are poor guards for exact parity work.
   - `ContentExtractorTests` examples:
     - `Readability/Tests/ReadabilityTests/ContentExtractorTests.swift:59`
     - `Readability/Tests/ReadabilityTests/ContentExtractorTests.swift:135`
   - `ArticleCleanerTests` permissive example:
     - `Readability/Tests/ReadabilityTests/ArticleCleanerTests.swift:202`

2. At least one effectively non-asserting test:
   - `cleanStyles preserves classes when keepClasses is true` has no `#expect`.
   - `Readability/Tests/ReadabilityTests/ArticleCleanerTests.swift:220`

3. The main integration test file is still placeholder:
   - `Readability/Tests/ReadabilityTests/ReadabilityTests.swift`

4. Options coverage is incomplete:
   - No effective tests for currently unimplemented options (`maxElemsToParse`, `allowedVideoRegex`, custom serializer path, debug behavior).

5. Auxiliary tests may validate current implementation details rather than Mozilla-intended behavior in some spots, which can lock in drift.

### 3.3 Recommendation for auxiliary suites

Priority: **P1**

- Tighten weak assertions to deterministic structure/content checks.
- Remove permissive "either/or" expectations where exact expected state is known.
- Add missing asserts to no-op tests.
- Add focused high-level characterization tests for `Readability.parse()` (pre-refactor safety net).

## Stage Task Breakdown (Executable Backlog)

Legend:

- Priority: `P0` (blocking), `P1` (high), `P2` (important), `P3` (later)
- Acceptance method types:
  - `Code`: code diff + targeted tests
  - `Test`: command-based test run
  - `Doc`: document consistency check

### Stage 0: Code Risk Stabilization First

#### S0-T1: Fix top-candidate stale variable overwrite

- Priority: `P0`
- Scope:
  - `Readability/Sources/Readability/Internal/CandidateSelector.swift`
  - `Readability/Tests/ReadabilityTests/CandidateSelectorTests.swift`
- Implementation:
  - Ensure `selectTopCandidate()` promotes the post-`findBetterTopCandidate` candidate, not the stale pre-update candidate reference.
- Acceptance method:
  - `Code`: add/adjust test that fails on old behavior and passes on fixed behavior.
  - `Test`: `cd Readability && swift test --filter CandidateSelectorTests`
- Pass standard:
  - New regression test passes.
  - No existing `CandidateSelectorTests` regressions.

#### S0-T2: Normalize project status single-source-of-truth

- Priority: `P1`
- Scope:
  - `PLAN.md`
- Implementation:
  - Remove conflicting metric blocks and stale "current status" sections.
  - Keep one canonical status snapshot with date and verification command.
- Acceptance method:
  - `Doc`: manual consistency review of `PLAN.md`.
- Pass standard:
  - No conflicting counts for imported tests/pass rate/known issues in active sections.

#### S0-T3: Formalize `002` deferred-known-issue record

- Priority: `P1`
- Scope:
  - `PLAN.md`
  - `CODEX-REVIEW.md`
- Implementation:
  - Record `002` as intentionally deferred with owner, rationale, and trigger condition (Stage 3-F closure).
- Acceptance method:
  - `Doc`: check that defer status and closure gate are both explicit.
- Pass standard:
  - `002` appears exactly as deferred in planning docs, with no contradictory "must-fix-now" wording.

### Stage 1: Make Functional Tests Parity-Capable

#### S1-T1: Replace similarity comparator with structural DOM comparator

- Priority: `P0`
- Scope:
  - `Readability/Tests/ReadabilityTests/MozillaCompatibilityTests.swift`
- Implementation:
  - Implement Mozilla-style traversal comparison:
    - in-order traversal
    - skip empty text nodes
    - compare node identity (`tag#id.class`)
    - compare text node content (whitespace-normalized)
    - compare element attributes
- Acceptance method:
  - `Code`: comparator no longer uses word-set similarity as primary verdict.
  - `Test`: `cd Readability && swift test --filter MozillaCompatibilityTests`
- Pass standard:
  - Comparator fails on structural mismatch even when text overlap is high.
  - Comparator provides deterministic pass/fail independent of token overlap.

#### S1-T2: Add first-divergence diagnostics for compatibility failures

- Priority: `P1`
- Scope:
  - `Readability/Tests/ReadabilityTests/MozillaCompatibilityTests.swift`
- Implementation:
  - Output path-like locator and expected/actual node descriptors at first mismatch.
- Acceptance method:
  - `Code`: mismatch message includes location + expected/actual details.
- Pass standard:
  - For forced mismatch sample, failure message pinpoints first divergent node.

#### S1-T3: Tighten weak auxiliary tests and remove no-op tests

- Priority: `P1`
- Scope:
  - `Readability/Tests/ReadabilityTests/ContentExtractorTests.swift`
  - `Readability/Tests/ReadabilityTests/ArticleCleanerTests.swift`
  - `Readability/Tests/ReadabilityTests/ReadabilityTests.swift`
- Implementation:
  - Replace permissive assertions (`contains`, `count > 0`, permissive OR) with deterministic expected-state checks.
  - Add missing assertions to currently non-asserting tests.
  - Replace placeholder integration file with minimal meaningful parse-pipeline characterization tests.
- Acceptance method:
  - `Test`: `cd Readability && swift test --filter "Content Extractor Tests|Article Cleaner Tests|ReadabilityTests"`
- Pass standard:
  - No test body without assertions in these suites.
  - Updated tests fail under intentional regressions in targeted logic.

### Stage 2: Remove Hidden Technical Debt

#### S2-T1: Resolve class-preservation conflict across cleaner and serializer

- Priority: `P1`
- Scope:
  - `Readability/Sources/Readability/Internal/ArticleCleaner.swift`
  - `Readability/Sources/Readability/Readability.swift`
  - tests for class preservation behavior
- Implementation:
  - Ensure one coherent class-retention policy between prep and final serialization.
- Acceptance method:
  - `Code`: end-to-end output keeps/removes classes according to option contract.
  - `Test`: add explicit output assertion for configured preserved classes.
- Pass standard:
  - `classesToPreserve` behavior is deterministic and documented.

#### S2-T2: Refactor paragraph wrapping to node-order-safe semantics

- Priority: `P1`
- Status: `Completed` (2026-02-06)
- Scope:
  - `Readability/Sources/Readability/Internal/ArticleCleaner.swift`
  - related cleaner tests
- Implementation:
  - Operate on full child-node stream (`getChildNodes`), preserve mixed text/element order, avoid clone-based duplication.
- Acceptance method:
  - `Code`: add mixed-content regression fixtures.
  - `Test`: targeted article cleaner tests for text+inline+block sequences.
- Pass standard:
  - No duplication/reordering in crafted mixed-content edge cases.

#### S2-T3: Remove score-mutation side effects in candidate collection

- Priority: `P1`
- Status: `Completed` (2026-02-06)
- Scope:
  - `Readability/Sources/Readability/Internal/CandidateSelector.swift`
  - selector/scoring tests
- Implementation:
  - Prevent double-scaling/mutable side effects during top-candidate collection.
- Acceptance method:
  - `Code`: score calculation path is single-responsibility and traceable.
  - `Test`: deterministic score expectations remain stable before/after candidate selection.
- Pass standard:
  - Candidate ordering unaffected by hidden repeated multipliers.

#### S2-T4: Preserve non-element nodes in fallback candidate construction

- Priority: `P1`
- Status: `Completed` (2026-02-06)
- Scope:
  - `Readability/Sources/Readability/Internal/CandidateSelector.swift`
  - selector tests
- Implementation:
  - Ensure fallback path handles text nodes correctly, not only `children()` elements.
- Acceptance method:
  - `Code`: regression test with body-level text node content.
  - `Test`: selector tests pass with explicit text-node preservation check.
- Pass standard:
  - Fallback extraction does not silently drop body-level text nodes.

#### S2-T5: Define parse lifecycle semantics

- Priority: `P2`
- Status: `Completed` (2026-02-06)
- Scope:
  - `Readability/Sources/Readability/Readability.swift`
  - integration tests
  - docs (`PLAN.md`/API notes)
- Implementation:
  - Choose and enforce one behavior:
    - single-use parser instance, or
    - idempotent repeated `parse()` via fresh clone path.
- Acceptance method:
  - `Code`: lifecycle contract represented in tests.
  - `Doc`: behavior documented consistently.
- Pass standard:
  - Repeated parse behavior is deterministic and explicitly tested.

#### S2-T6: Mark unimplemented option status explicitly

- Priority: `P2`
- Status: `Completed` (2026-02-06)
- Scope:
  - `Readability/Sources/Readability/ReadabilityOptions.swift`
  - `PLAN.md`
  - `CODEX-REVIEW.md`
- Implementation:
  - Mark each option as implemented/deferred/drop-candidate with rationale.
- Acceptance method:
  - `Doc`: option status matrix present and consistent.
- Pass standard:
  - No option appears "supported" without implementation status.

### Stage 3-F: Functional Parity Expansion

#### S3F-T1: Import remaining functional Mozilla pages in batches

- Priority: `P1`
- Status: `Complete` (2026-02-06)
- Scope:
  - `Readability/Tests/ReadabilityTests/Resources/test-pages/*`
  - `Readability/Tests/ReadabilityTests/MozillaCompatibilityTests.swift`
- Implementation:
  - Import by feature clusters:
    - URL/base handling: `base-url*`, `js-link-replacement`
    - I18N: `rtl-*`, `005-unescape-html-entities`, `mathjax`
    - Media/SVG: `lazy-image-*`, `data-url-image`, `embedded-videos`, `videos-*`, `svg-parsing`
    - Edge behavior: `comment-inside-script-parsing`, `toc-missing`, `metadata-content-missing`, `bug-1255978`
- Acceptance method:
  - `Test`: `cd Readability && swift test --filter MozillaCompatibilityTests`
- Pass standard:
  - Each imported case has content + metadata assertions with no relaxed matching.
  - Current imported batches:
    - URL/base: `base-url`, `base-url-base-element`, `base-url-base-element-relative`, `js-link-replacement`
    - I18N/entities: `005-unescape-html-entities`, `rtl-1..4`, `mathjax` (content passing)
    - Media/SVG: `data-url-image`, `lazy-image-1`, `lazy-image-2`, `lazy-image-3`, `embedded-videos`, `videos-1`, `videos-2`, `svg-parsing` (all currently passing in local compatibility run)
    - Edge behavior: `comment-inside-script-parsing`, `toc-missing`, `metadata-content-missing`, `bug-1255978` (all currently passing in local compatibility run)
  - Remaining standard functional imports: none.

#### S3F-T2: Implement/validate `dir`/`lang` parity path for functional RTL scope

- Priority: `P1`
- Status: `Complete` (2026-02-06)
- Scope:
  - extraction pipeline + compatibility tests
- Implementation:
  - Ensure testable extraction and assertion path for `dir`/`lang` in RTL cases.
  - Public API exposure remains pre-release decision (already agreed).
- Acceptance method:
  - `Test`: RTL functional cases assert expected direction/language metadata.
- Pass standard:
  - Imported RTL functional cases have explicit `dir`/`lang` parity checks.

#### S3F-T3: Resolve deferred `002` mismatch as stage-closing item

- Priority: `P1` (stage gate critical)
- Status: `Complete` (2026-02-06)
- Scope:
  - extraction/cleanup path around `002`
  - compatibility test expectations
- Implementation:
  - Use structural mismatch diagnostics to isolate first divergent node and fix implementation path.
- Acceptance method:
  - `Test`: `cd Readability && swift test --filter "002 - Content extraction produces expected text"`
- Pass standard:
  - `002` passes under structural DOM comparator.

#### S3F-T4: Stage 3-F gate verification run

- Priority: `P0` (release gate for Stage 3-R entry)
- Status: `Complete` (2026-02-06)
- Scope:
  - full `MozillaCompatibilityTests`
  - status docs
- Implementation:
  - Execute full functional compatibility run and update status snapshot.
- Acceptance method:
  - `Test`: `cd Readability && swift test --filter MozillaCompatibilityTests`
  - `Doc`: gate checklist updated.
- Pass standard:
  - Stage 3-F locked criteria all satisfied (see Stage Gate Criteria).
  - Verification snapshot:
    - `cd Readability && swift test --filter MozillaCompatibilityTests` -> `119/119` passed
    - `cd Readability && swift test` -> `293` tests, `0` failures

### Stage 3-R: Real-world Hardening (Strictly After Stage 3-F)

#### S3R-T1: Import real-world case corpus in manageable batches

- Priority: `P1`
- Status: `In Progress` (2026-02-06)
- Scope:
  - `Readability/Tests/ReadabilityTests/Resources/realworld-pages/*` (real-world subset)
  - compatibility tests
- Implementation:
  - Import per source-family batches (news sites, blogs, forums, mixed templates).
  - Batch 1 imported:
    - `wikipedia`, `medium-1`, `nytimes-1`, `cnn`, `wapo-1`
  - Baseline test suite added:
    - `Readability/Tests/ReadabilityTests/RealWorldCompatibilityTests.swift`
  - Batch 1 report added:
    - `Readability/Tests/ReadabilityTests/Resources/realworld-pages/BATCH-1-REPORT.md`
- Acceptance method:
  - `Test`: full compatibility runs with per-batch reporting.
- Pass standard:
  - No batch import without baseline pass/fail report and issue categorization.

#### S3R-T2: Failure clustering and pattern-based remediation

- Priority: `P1`
- Scope:
  - parser + cleaner + extractor modules
  - issue tracking docs
- Implementation:
  - Cluster failures by root-cause pattern (template noise, embed handling, metadata anomalies, locale artifacts).
- Acceptance method:
  - `Doc`: each cluster has owner, fix strategy, and regression tests.
- Pass standard:
  - New fixes must close at least one failure cluster and not regress functional suite.

#### S3R-T3: Real-world known-issues ledger and quarantine policy

- Priority: `P2`
- Scope:
  - `PLAN.md` (or dedicated issue ledger)
- Implementation:
  - Keep real-world unresolved items separate from functional baseline status.
- Acceptance method:
  - `Doc`: unresolved real-world issues listed with severity and next action.
- Pass standard:
  - Functional and real-world statuses remain clearly separated in tracking.

## Decision Points

1. API option policy:
   - Implement currently dead options now, or mark as intentionally unsupported and trim API surface?
2. Functional vs real-world execution gate:
   - Confirm exact completion criteria for switching from Stage 3-F to Stage 3-R.

## Decision Outcomes (Confirmed)

The following decisions are now fixed for the current development phase:

1. `dir/lang` and related API evolution:
   - Internal development remains API-flexible.
   - Public API shape can continue to evolve before release.
   - Final public API decision is deferred to pre-release hardening.

2. `002` handling:
   - Resolved under structural DOM comparator.
   - Keep as an explicit regression watch item (no defer state).

3. Unimplemented/dead options policy:
   - Mark status explicitly in docs now.
   - Implement selectively during development as needed.
   - If still unnecessary by release planning, allow formal drop/removal.

4. Functional vs real-world gate:
   - Use strict gate.
   - Do not enter Stage 3-R until Stage 3-F completion criteria are met.
   - Exceptions can only be introduced by explicit later decision.

## Stage Gate Criteria (Locked)

Stage 3-F completion requires all of the following:

1. Functional/core Mozilla target set imported according to plan.
2. Structural DOM comparator is the active compatibility assertion mechanism.
3. `002` is resolved or explicitly approved as the only temporary exception.
4. No unresolved P0/P1 structural-risk items that would invalidate parity confidence.

Stage 3-R can begin only after Stage 3-F completion.
