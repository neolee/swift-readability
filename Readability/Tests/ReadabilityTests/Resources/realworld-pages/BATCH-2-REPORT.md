# Stage 3-R Batch 2 Baseline Report

Date: 2026-02-06
Batch: `bbc-1`, `guardian-1`, `telegraph`, `seattletimes-1`, `nytimes-2`, `nytimes-3`, `nytimes-4`, `nytimes-5`, `wapo-2`, `yahoo-1`, `yahoo-2`

## Summary

- Total new cases: 11
- Strict pass: 4 (`wapo-2`, `seattletimes-1`, `yahoo-1`, `yahoo-2`)
- Cases with known issues: 7
- Known issue instances: 7

## First-Diff Snapshot (Batch 2)

1. `bbc-1`
- Content: expected plain `p`, actual `p` retains `data-media-type` / `data-media-meta` from removed media placeholder.
- Metadata: byline mismatch is resolved in current branch (`BBC News` now matches expected).

2. `guardian-1`
- Content: expected `figure#img-2`, actual `ul`.

3. `telegraph`
- Content: expected inline `span`, actual `figure`.

4. `seattletimes-1`
- Status: strict pass in current branch.

5. `nytimes-2`
- Content: expected `div#story-continues-1`, actual `div` (id stripped).

6. `nytimes-3`
- Content: expected `article#story`, actual `div#site-content` (container selection drift).

7. `nytimes-4`
- Content: expected `article#story`, actual `div#site-content` (same cluster as `nytimes-3`).

8. `nytimes-5`
- Content: expected `div#collection-highlights-container`, actual `section#collection-highlights-container`.
- Metadata: excerpt mismatch is resolved in current branch (meta excerpt now used when JSON-LD excerpt is empty).

9. `yahoo-1`
- Status: strict pass in current branch.

10. `yahoo-2`
- Status: strict pass in current branch.

11. `wapo-2`
- Status: strict pass in baseline import.

## Notes

- Batch 1 remains strict green.
- Batch 2 tests are imported and executable in `RealWorldCompatibilityTests`.
- Batch 2 has now closed 3 structural/content instances (`seattletimes-1`, `yahoo-1`, `yahoo-2`) in addition to earlier metadata closures.
- Next step is fixing remaining structural clusters (`nytimes` container/tag drift, `telegraph`/`guardian` media-boundary drift, `bbc-1` id parity).
