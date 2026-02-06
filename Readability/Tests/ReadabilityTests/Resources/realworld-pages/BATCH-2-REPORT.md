# Stage 3-R Batch 2 Baseline Report

Date: 2026-02-06
Batch: `bbc-1`, `guardian-1`, `telegraph`, `seattletimes-1`, `nytimes-2`, `nytimes-3`, `nytimes-4`, `nytimes-5`, `wapo-2`, `yahoo-1`, `yahoo-2`

## Summary

- Total new cases: 11
- Strict pass: 1 (`wapo-2`)
- Cases with known issues: 10
- Known issue instances: 13

## First-Diff Snapshot (Batch 2)

1. `bbc-1`
- Content: expected `p`, actual `p#84457006` (id retention drift).
- Metadata: byline mismatch (`@BBCWorld` vs `BBC News`).

2. `guardian-1`
- Content: expected `figure#img-2`, actual `ul`.

3. `telegraph`
- Content: expected inline `span`, actual `figure`.

4. `seattletimes-1`
- Content: expected `p`, actual `div`.

5. `nytimes-2`
- Content: expected `div#story-continues-1`, actual `div` (id stripped).

6. `nytimes-3`
- Content: expected `article#story`, actual `div#site-content` (container selection drift).

7. `nytimes-4`
- Content: expected `article#story`, actual `div#site-content` (same cluster as `nytimes-3`).

8. `nytimes-5`
- Content: expected `div#collection-highlights-container`, actual `section#collection-highlights-container`.
- Metadata: excerpt mismatch (`""` vs expected non-empty Spanish excerpt).

9. `yahoo-1`
- Content: expected `figure > p`, actual `figure > div`.
- Metadata: byline mismatch (`Ben Silverman Games Editor` vs `Ben Silverman`).

10. `yahoo-2`
- Content: expected `p`, actual `div` in article wrapper.

11. `wapo-2`
- Status: strict pass in baseline import.

## Notes

- Batch 1 remains strict green.
- Batch 2 tests are imported and executable in `RealWorldCompatibilityTests`.
- Next step is clustering these 13 known-issue instances, then fixing in priority order with Mozilla suite gating.
