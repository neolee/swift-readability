# Stage 3-R Batch 2 Baseline Report

Date: 2026-02-06
Batch: `bbc-1`, `guardian-1`, `telegraph`, `seattletimes-1`, `nytimes-2`, `nytimes-3`, `nytimes-4`, `nytimes-5`, `wapo-2`, `yahoo-1`, `yahoo-2`

## Summary

- Total new cases: 11
- Strict pass: 9 (`wapo-2`, `seattletimes-1`, `yahoo-1`, `yahoo-2`, `bbc-1`, `nytimes-2`, `nytimes-3`, `nytimes-4`, `nytimes-5`)
- Cases with known issues: 2
- Known issue instances: 2

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
- Status: strict pass in current branch.

9. `yahoo-1`
- Status: strict pass in current branch.

10. `yahoo-2`
- Status: strict pass in current branch.

11. `wapo-2`
- Status: strict pass in baseline import.

## Notes

- Batch 1 remains strict green.
- Batch 2 tests are imported and executable in `RealWorldCompatibilityTests`.
- Batch 2 has now closed 8 structural/content instances (`seattletimes-1`, `yahoo-1`, `yahoo-2`, `bbc-1`, `nytimes-2`, `nytimes-3`, `nytimes-4`, `nytimes-5`) in addition to earlier metadata closures.
- Next step is fixing remaining structural clusters (`telegraph`/`guardian-1` media-boundary drift).
