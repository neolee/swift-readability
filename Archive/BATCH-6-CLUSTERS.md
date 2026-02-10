# Stage 3-R Batch 6 Issue Clusters

Date: 2026-02-10  
Scope: `aktualne`, `folha`, `heise`, `herald-sun-1`, `la-nacion`, `lemonde-1`, `liberation-1`, `pixnet`, `qq`, `yahoo-3`, `yahoo-4`

## Baseline Snapshot

- Import status: 11/11 cases imported and registered
- `RealWorldCompatibilityTests`: 60 tests total, 8 failing cases (10 issues)
- `MozillaCompatibilityTests`: not run in baseline import step

Failing cases from baseline:
- `aktualne`
- `folha`
- `herald-sun-1`
- `la-nacion`
- `liberation-1`
- `pixnet`
- `qq`
- `yahoo-3`

## Current Snapshot (after C1 + herald byline + yahoo-3 + la-nacion fix)

- `RealWorldCompatibilityTests`: 60 tests total, 3 failing cases (3 issues)
- `MozillaCompatibilityTests`: PASS (119 tests)
- Failure delta: `8 cases / 10 issues -> 3 cases / 3 issues`

Remaining failing cases:
- `folha` (content)
- `pixnet` (content)
- `liberation-1` (content)

## Cluster B6-C1 - Share/Embed Widget Retention (Stable IDs)

- Type: Structural DOM parity
- Impacted cases:
  - `aktualne` (`div[id^=twttr_]` kept)
  - `qq` (`div#shareBtn` kept)
  - `herald-sun-1` (`div#read-more-link` kept)
- Signals:
  - non-article share/embed widgets appear before/inside expected paragraph flow.
- Priority: P1
- Status: DONE

## Cluster B6-C2 - Wrapper Shape Drift (Article Container vs Nested Body)

- Type: Structural DOM parity
- Impacted cases:
  - `la-nacion` (`article#nota` expected, `section#cuerpo` selected)
  - `liberation-1` (expected `<p>`, actual extra wrapper `<div><p>...`)
  - `folha` (expected paragraph sequence, actual figure wrapper block retained)
- Signals:
  - candidate container shape differs from Mozilla expected wrapper.
- Priority: P1
- Status: IN_PROGRESS

## Cluster B6-C3 - Residual Tail Block Retention

- Type: Structural DOM parity
- Impacted cases:
  - `pixnet` (node count +17, trailing link-heavy tail block remains)
  - `yahoo-3` (leading/adjacent block selected before expected `#mediacontentstory`)
- Signals:
  - extra recirculation/tail content survives extraction/cleanup.
- Priority: P1
- Status: OPEN

## Cluster B6-C4 - Byline Source/Normalization Drift

- Type: Metadata parity
- Impacted cases:
  - `herald-sun-1` (expected `JOE HILDEBRAND`, actual `Laurie Oakes`)
  - `yahoo-3` (expected byline includes `3:46 PM`, actual trimmed)
- Signals:
  - byline source ranking and time-suffix normalization diverge from expected fixtures.
- Priority: P2
- Status: PARTIAL
  - fixed: `herald-sun-1`
  - fixed: `yahoo-3`

## Planned Iteration Order

1. B6-C1 (stable-ID share/embed widget cleanup)
2. B6-C3 (tail/recirculation retention)
3. B6-C2 (wrapper shape drift)
4. B6-C4 (byline source/normalization)

## Iteration Protocol

1. Run targeted case test(s) for one cluster.
2. Run full `RealWorldCompatibilityTests` and record failure delta.
3. Run full `MozillaCompatibilityTests` as safety gate.
4. Update this file with cluster status and remaining queue.
