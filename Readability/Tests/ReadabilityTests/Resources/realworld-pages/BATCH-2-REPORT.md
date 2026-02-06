# Stage 3-R Batch 2 Baseline Report

Date: 2026-02-06
Batch: `bbc-1`, `guardian-1`, `telegraph`, `seattletimes-1`, `nytimes-2`, `nytimes-3`, `nytimes-4`, `nytimes-5`, `wapo-2`, `yahoo-1`, `yahoo-2`

## Summary

- Total new cases: 11
- Strict pass: 8 (`wapo-2`, `seattletimes-1`, `yahoo-1`, `yahoo-2`, `bbc-1`, `nytimes-2`, `nytimes-3`, `nytimes-4`)
- Cases with known issues: 3
- Known issue instances: 3

## First-Diff Snapshot (Batch 2)

1. `bbc-1`
- Status: strict pass in current branch.

2. `guardian-1`
- Content: expected `figure#img-2`, actual `ul`.

3. `telegraph`
- Content: expected inline `span`, actual `figure`.

4. `seattletimes-1`
- Status: strict pass in current branch.

5. `nytimes-2`
- Status: strict pass in current branch.

6. `nytimes-3`
- Status: strict pass in current branch.

7. `nytimes-4`
- Status: strict pass in current branch.

8. `nytimes-5`
- Content: expected list structure under highlights block (`ol > li`), actual nested `div` inside first list item.
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
- Batch 2 has now closed 7 structural/content instances (`seattletimes-1`, `yahoo-1`, `yahoo-2`, `bbc-1`, `nytimes-2`, `nytimes-3`, `nytimes-4`) in addition to earlier metadata closures.
- Next step is fixing remaining structural clusters (`nytimes-5` list structure drift, `telegraph`/`guardian-1` media-boundary drift).
