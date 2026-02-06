# Stage 3-R Batch 1 Baseline Report

Date: 2026-02-06
Batch: `wikipedia`, `medium-1`, `nytimes-1`, `cnn`, `wapo-1`

## Summary

- Total cases: 5
- Strict pass: 0
- Known issue instances: 8
- Known issue clusters: 5

## Case Findings (first divergence)

1. `cnn`
- Content: expected `h2`, actual `div#js-ie-storytop` at first structural divergence.
- Metadata: title trailing whitespace mismatch.
- Cluster: leading container normalization + title whitespace cleanup.

2. `nytimes-1`
- Content: wrapper path now aligns to `div#page.page > main#main > article#story`, but output keeps an extra trailing `main > section` block (expected node count 85, actual 98).
- Cluster: sibling boundary / trailing section cleanup.

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

- These tests are intentionally kept as `withKnownIssue` while Stage 3-R failure clusters are being fixed.
- Functional/core baseline remains separate and fully green.
- Deep-dive update (2026-02-06): candidate scoring pipeline was aligned closer to Mozilla (paragraph scoring + ancestor propagation semantics + candidate score write-back), which resolved the prior `nytimes-1` wrapper-selection drift and exposed the remaining tail-section issue as the next actionable delta.
