# Stage 3-R Batch 2 Issue Clusters

Date: 2026-02-06
Scope: `bbc-1`, `guardian-1`, `telegraph`, `seattletimes-1`, `nytimes-2`, `nytimes-3`, `nytimes-4`, `nytimes-5`, `wapo-2`, `yahoo-1`, `yahoo-2`

## Summary

- Cases: 11
- Strict pass: 8 (`wapo-2`, `seattletimes-1`, `yahoo-1`, `yahoo-2`, `bbc-1`, `nytimes-2`, `nytimes-3`, `nytimes-4`)
- Cases with known issues: 3
- Known issue instances: 3

## Cluster Taxonomy

### B2-C1: Metadata Source Priority/Normalization Drift
- Type: Metadata parity
- Signature:
  - social handle selected over expected organization/author name
  - empty JSON-LD excerpt blocks non-empty meta excerpt fallback
  - byline includes role suffix not present in expected
- Impacted cases:
  - `bbc-1` (byline) - resolved in current branch
  - `nytimes-5` (excerpt) - resolved in current branch
  - `yahoo-1` (byline) - resolved in current branch
- Priority: P1

### B2-C2: Container Selection Drift
- Type: Structural DOM parity
- Signature:
  - NYTimes article tail print-info block differs in wrapper shape (`div` vs `p`)
- Impacted cases:
  - `nytimes-3` - resolved in current branch
  - `nytimes-4` - resolved in current branch
- Priority: P1

### B2-C3: DIV/P/SECTION Tag Conversion Drift
- Type: Structural DOM parity
- Signature:
  - expected `p/div`, actual `div/section` under comparable subtree
  - expected identity attributes retained/removed differently
  - list wrapper boundaries drift (`ol > li` vs nested `div` inside item content)
- Impacted cases:
  - `nytimes-5`
  - `seattletimes-1` - resolved in current branch
  - `yahoo-1` - resolved in current branch
  - `yahoo-2` - resolved in current branch
  - `bbc-1` - resolved in current branch
  - `nytimes-2` - resolved in current branch
- Priority: P1

### B2-C4: Figure/Inline Block Boundary Drift
- Type: Structural DOM parity
- Signature:
  - expected inline/paragraph content where actual output keeps/promotes figure/list block
- Impacted cases:
  - `telegraph`
  - `guardian-1`
- Priority: P2

## Proposed Fix Order

1. B2-C1 (metadata parity)
- closed for current Batch 2 scope (`bbc-1`, `nytimes-5`, `yahoo-1`)

2. B2-C3 (tag conversion parity)
- shared mechanics across remaining core cases (`nytimes-5`)
- likely medium-impact changes, requires tight regression gating

3. B2-C4 (figure/inline boundary)
- likely needs targeted media/cleaning heuristics

## Acceptance Gates

- Batch-level target: reduce known issues monotonically without opening new strict failures.
- Global gate: `MozillaCompatibilityTests` stays fully passing.
- Batch 1 gate: existing strict-pass real-world cases remain strict-pass.
