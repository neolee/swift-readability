# Stage 3-R Batch 2 Baseline Report

Date: 2026-02-06
Batch: `bbc-1`, `guardian-1`, `telegraph`, `seattletimes-1`, `nytimes-2`, `nytimes-3`, `nytimes-4`, `nytimes-5`, `wapo-2`, `yahoo-1`, `yahoo-2`

## Summary

- Total new cases: 11
- Strict pass: 1 (`wapo-2`)
- Cases with known issues: 10
- Known issue instances: 10

## First-Diff Snapshot (Batch 2)

1. `bbc-1`
- Content: expected `p`, actual `p#84457006` (id retention drift).
- Metadata: byline mismatch is resolved in current branch (`BBC News` now matches expected).

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
- Metadata: excerpt mismatch is resolved in current branch (meta excerpt now used when JSON-LD excerpt is empty).

9. `yahoo-1`
- Content: expected `figure > p`, actual `figure > div`.
- Metadata: byline mismatch is resolved in current branch (`Ben Silverman` now matches expected).

10. `yahoo-2`
- Content: expected `p`, actual `div` in article wrapper.

11. `wapo-2`
- Status: strict pass in baseline import.

## Notes

- Batch 1 remains strict green.
- Batch 2 tests are imported and executable in `RealWorldCompatibilityTests`.
- Batch 2 first metadata fix pass closed 3 known-issue instances (`bbc-1` byline, `nytimes-5` excerpt, `yahoo-1` byline).
- Next step is fixing remaining structural clusters first (`DIV/P/SECTION` conversion and container selection).
