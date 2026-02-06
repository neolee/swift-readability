# Stage 3-R Batch 1 Baseline Report

Date: 2026-02-06
Batch: `wikipedia`, `medium-1`, `nytimes-1`, `cnn`, `wapo-1`

## Summary

- Total cases: 5
- Strict pass: 2 (`nytimes-1`, `cnn`)
- Known issue instances: 5
- Known issue clusters: 4

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
- Content: expected `p`, actual `div#gallery-embed_*`.
- Metadata: expected byline `By Erin Cunningham`, actual `@erinmcunningham`.
- Cluster: embedded gallery filtering + byline normalization priority.

4. `medium-1`
- Content: expected `figure > div`, actual `figure > p` at first divergence.
- Cluster: figure/caption structural conversion parity.

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
