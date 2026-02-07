# Batch 4 Failure Clusters

Date: 2026-02-07
Scope: Stage 3-R Batch 4 baseline import (`ars-1`, `daringfireball-1`, `dropbox-blog`, `firefox-nightly-blog`, `gitlab-blog`, `google-sre-book-1`, `ietf-1`, `lwn-1`, `v8-blog`, `mozilla-1`, `medium-2`, `medium-3`)

## Baseline Snapshot

- `RealWorldCompatibilityTests`: 38 tests total, 7 failing cases, 12 issues
- Failing cases:
  - `v8-blog`
  - `mozilla-1`
  - `lwn-1`
  - `gitlab-blog`
  - `ietf-1`
  - `firefox-nightly-blog`
  - `google-sre-book-1`

## Cluster C1 - Intro Block Fragmentation (`<p></p>` + heading/body split)

Cases:
- `firefox-nightly-blog`
- `v8-blog`

Signals:
- First mismatch appears near root with unexpected leading `<p></p>` and heading/body container displacement.
- Example:
  - expected `div#content` vs actual `p` (`firefox-nightly-blog`)
  - expected early `h2#...` vs actual `p` (`v8-blog`)

Hypothesis:
- Current div-to-p / wrapper-collapsing path is producing invalid paragraph wrappers around block headings and then serializer reparses into fragmented siblings.

Priority:
- P0 for Batch 4 progression (shared mechanism likely fixes 2 cases).

Acceptance for cluster:
1. `testFirefoxNightlyBlog` and `testV8Blog` pass.
2. No regression in existing high-sensitivity canaries (`nytimes-*`, `engadget`, `ars-1`).

## Cluster C2 - Container Flattening vs Expected Grouping

Cases:
- `lwn-1`

Signals:
- expected wrapper `div` containing `h2 + p...`; actual starts directly with `h2`.

Hypothesis:
- Over-flattening in nested-wrapper simplification or post-process grouping.

Priority:
- P1.

Acceptance for cluster:
1. `testLWN1` content passes.
2. Byline exact-match also passes (currently newline-normalized difference).

## Cluster C3 - Attribute Preservation Mismatch (framework attrs)

Cases:
- `gitlab-blog`

Signals:
- Attribute count mismatch at early root node (`data-v-*` expected 3, actual 2).

Hypothesis:
- Attribute stripped during tag replacement or cleanup pass.

Priority:
- P1 (strict parity issue; content mostly aligned).

Acceptance for cluster:
1. `testGitLabBlog` attribute parity passes.
2. No broad keep-attribute change that affects unrelated pages.

## Cluster C4 - RFC/Preformatted Content + Metadata Extraction Drift

Cases:
- `ietf-1`

Signals:
- Content text mismatch inside deep `<pre>` section.
- Title mismatch (`draft-... - remoteStorage` vs expected `remoteStorage`).
- Byline mismatch (`AUTHORING` vs expected author name).

Hypothesis:
- Combined issue:
  - parser cleanup around RFC-like preformatted references,
  - metadata/title heuristics preferring document title noise over expected metadata,
  - byline extraction polluted by section headings.

Priority:
- P0 (multi-field mismatch, likely nontrivial).

Acceptance for cluster:
1. `testIETF1` passes content + metadata assertions.
2. No regression in Mozilla metadata tests (`metadata-content-missing`, `schema-org-*`, `article-author-tag`).

## Cluster C5 - Whitespace-Sensitive Metadata Normalization

Cases:
- `google-sre-book-1` (byline)
- `mozilla-1` (excerpt)
- `lwn-1` (byline; overlaps C2)

Signals:
- Same text semantics but newline/spacing formatting differs from expected strict string.

Hypothesis:
- Current metadata normalization compacts whitespace too aggressively compared to expected fixture format.

Priority:
- P2 (after structural mismatches).

Acceptance for cluster:
1. Metadata exact strings match expected fixtures.
2. Changes are narrowly scoped to avoid breaking previously passing metadata cases.

## Cluster C6 - Extra Tail Content Retention

Cases:
- `mozilla-1`

Signals:
- DOM node count mismatch (expected 95, actual 109), trailing `<br>`/`<a>` nodes retained.

Hypothesis:
- Residual CTA/footer block not removed in post-cleaning.

Priority:
- P1.

Acceptance for cluster:
1. `testMozilla1` content node count/structure parity passes.
2. Keep current passing `mozilla` core suite unaffected.

## Proposed Execution Order (Cluster Iterations)

1. C1 (`firefox-nightly-blog`, `v8-blog`) - highest shared structural leverage.
2. C4 (`ietf-1`) - highest severity and multi-signal drift.
3. C6 (`mozilla-1` content tail) + C3 (`gitlab-blog` attrs).
4. C2 (`lwn-1` wrapper shape).
5. C5 (metadata whitespace exactness sweep).

## Iteration Protocol (per cluster)

1. Run targeted case tests for the cluster.
2. Run full `RealWorldCompatibilityTests` and record failure delta.
3. Run full `MozillaCompatibilityTests` as safety gate.
4. Update this file with resolved cluster status and remaining queue.
