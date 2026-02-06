# Stage 3-R Batch 1 Baseline Report

Date: 2026-02-06
Batch: `wikipedia`, `medium-1`, `nytimes-1`, `cnn`, `wapo-1`

## Summary

- Total cases: 5
- Strict pass: 4 (`nytimes-1`, `cnn`, `wapo-1`, `medium-1`)
- Known issue instances: 2
- Known issue clusters: 2

## Case Findings (first divergence)

1. `cnn`
- Status: resolved in current branch.
- Content: matches expected structure and metadata under strict comparison.
- Cluster: `RW-C1` (closed for this case).

2. `nytimes-1`
- Status: resolved in current branch.
- Content: matches expected structure and metadata under strict comparison.
- Cluster: `RW-C1` (closed for this case).

3. `wapo-1`
- Status: resolved in current branch.
- Content: gallery embed residuals now removed; structure matches expected.
- Metadata: byline now matches expected exactly (`By Erin Cunningham`).
- Cluster: `RW-C2` and `RW-C5` (closed for this case).

4. `medium-1`
- Status: resolved in current branch.
- Content: figure/caption wrapper structure now matches expected under strict comparison.
- Cluster: `RW-C3` (closed for this case).

5. `wikipedia`
- Content: expected `p#toctitle`, actual `div#toctitle`.
- Metadata: excerpt truncation mismatch.
- Cluster: TOC/container tag conversion + excerpt selection/length behavior.

## Notes

- Remaining unresolved tests are intentionally kept as `withKnownIssue` while Stage 3-R failure clusters are being fixed.
- Functional/core baseline remains separate and fully green.
- Deep-dive update (2026-02-06): candidate scoring pipeline was aligned closer to Mozilla (paragraph scoring + ancestor propagation semantics + candidate score write-back), which resolved the prior `nytimes-1` wrapper-selection drift and exposed the remaining tail-section issue as the next actionable delta.
- Step-1 progress update (2026-02-06): targeted explicit no-content container cleanup removed `main > section` tail drift in `nytimes-1` and reduced its mismatch from `+13` nodes to `+6` nodes.
- Step-1 closure update (2026-02-06): additional cleanup of feedback/supplemental modules removed remaining residual nodes; `nytimes-1` now passes without `withKnownIssue`.
- Step-1 cnn closure update (2026-02-06): removing legacy wrappers plus targeted in-read ad shell cleanup (`ADVERTISING inRead invented by Teads`) closed the remaining structural residual; `cnn` now passes without `withKnownIssue`.
- Step-2/3 wapo closure update (2026-02-06): metadata byline precedence now prefers extracted byline over social handle metadata, and gallery promo residuals (`gallery-embed_*`, `View Graphic` blocks) are removed; `wapo-1` now passes without `withKnownIssue`.
- Step-4 medium closure update (2026-02-06): `figure`-context wrapper conversion was aligned in both extraction and cleaning paths, preserving `figure > div > p` structure; `medium-1` now passes without `withKnownIssue`.
