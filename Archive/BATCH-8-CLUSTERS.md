# Stage 3-R Batch 8 Issue Clusters

Date: 2026-02-10  
Scope: `ebb-org`, `gmw`, `hukumusume`, `quanta-1`, `webmd-1`, `webmd-2`, `youth`, `breitbart`

## Baseline Snapshot

- Import status: 8/8 cases imported and registered
- `RealWorldCompatibilityTests`: 78 tests total, 6 failing cases (9 issues)
- `MozillaCompatibilityTests`: PASS (119 tests)

Failing cases from baseline:
- `ebb-org` (content)
- `breitbart` (content)
- `webmd-1` (content + byline)
- `webmd-2` (content + byline)
- `hukumusume` (content)
- `quanta-1` (content + byline)

## Cluster B8-C1 - Lead Noise Blocks Before Article Body

- Type: Structural parity
- Impacted cases:
  - `ebb-org` (`#prevlink` block retained ahead of first content paragraph)
  - `webmd-1` / `webmd-2` (leading "Reviewed by ..." block retained)
- Signals:
  - first mismatch at top of extracted body (`expected p`, `actual div`)
- Priority: P1
- Status: OPEN

## Cluster B8-C2 - Byline Canonicalization Drift

- Type: Metadata parity
- Impacted cases:
  - `webmd-1` / `webmd-2` (expected full WebMD byline string, actual reduced author only)
  - `quanta-1` (expected author-only, actual includes date line)
- Signals:
  - strict byline equality mismatch
- Priority: P1
- Status: OPEN

## Cluster B8-C3 - Breitbart Hero/Figure Ordering Drift

- Type: Structural parity
- Impacted cases:
  - `breitbart` (expected opening `figure`, actual starts with `h2`)
- Signals:
  - early-node mismatch near root (`expected figure`, `actual h2`)
- Priority: P1
- Status: OPEN

## Cluster B8-C4 - Legacy URL Decoding/Normalization Drift

- Type: Attribute parity
- Impacted cases:
  - `hukumusume` (`img[src]` percent/canonicalization mismatch in `file:///C:/...` path)
- Signals:
  - attribute value mismatch on `src`
- Priority: P2
- Status: OPEN

## Cluster B8-C5 - Volatile Framework Attributes + Quanta Byline Drift

- Type: Attribute parity + metadata parity
- Impacted cases:
  - `quanta-1` (`data-reactid` mismatch; byline includes date suffix)
- Signals:
  - strict attribute mismatch (`data-reactid` expected fixed token)
  - byline contains extra timestamp content
- Priority: P2
- Status: OPEN

## Planned Iteration Order

1. B8-C1 (WebMD first, then EFF/ebb-org lead block)
2. B8-C2 (byline canonicalization)
3. B8-C3 (breitbart figure ordering)
4. B8-C4 (hukumusume legacy path normalization)
5. B8-C5 (quanta react attr + byline)

## Iteration Protocol

1. Run targeted case test(s) for one cluster.
2. Run full `RealWorldCompatibilityTests` and record failure delta.
3. Run full `MozillaCompatibilityTests` as safety gate.
4. Update this file with cluster status and remaining queue.
