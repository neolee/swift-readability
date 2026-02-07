# Stage 3-R Batch 5 Issue Clusters

Date: 2026-02-07
Scope: `blogger`, `wordpress`, `tumblr`, `lifehacker-working`, `lifehacker-post-comment-load`, `ehow-1`, `ehow-2`, `dev418`, `simplyfound-1`, `spiceworks`, `royal-road`

## Baseline Snapshot

- Cases: 11
- Strict pass: 5
- Failing cases: 6
  - `ehow-1`
  - `ehow-2`
  - `simplyfound-1`
  - `wordpress`
  - `tumblr`
  - `royal-road`
- Global safety gate: `MozillaCompatibilityTests` pass (`119/119`)

## Cluster B5-C1 - eHow Intro/Header Wrapper Shape Drift

- Type: Structural DOM parity
- Impacted cases:
  - `ehow-1`
  - `ehow-2`
- Signals:
  - `ehow-1`: expected `header > div > p` helper wrapper, actual `header > p`.
  - `ehow-2`: expected leading author-profile block, actual starts at `h2` headline.
- Hypothesis:
  - Over-flattening and/or early block removal around non-core pre-article modules in eHow templates.
- Priority: P1

## Cluster B5-C2 - Media/Caption Wrapper Normalization Drift

- Type: Structural DOM parity
- Impacted cases:
  - `simplyfound-1`
- Signals:
  - Expected text paragraph caption near top; actual keeps image wrapper `div > p > img` at mismatch point.
- Hypothesis:
  - Figure/media wrapper conversion path keeps container structure where Mozilla collapses/promotes caption text.
- Priority: P1

## Cluster B5-C3 - Extra Tail Content Retention (WordPress)

- Type: Structural DOM parity
- Impacted cases:
  - `wordpress`
- Signals:
  - Node count mismatch with extra retained tail subtree under `main > div`.
- Hypothesis:
  - Sidebar/footer-like sibling block is being retained past candidate extraction and post-cleaning.
- Priority: P1

## Cluster B5-C4 - Byline Source Priority/Filtering Drift

- Type: Metadata parity
- Impacted cases:
  - `tumblr`
  - `royal-road`
- Signals:
  - `tumblr`: expected no byline, actual author handle extracted.
  - `royal-road`: expected CTA label (`Follow Author`), actual extracted author name.
- Hypothesis:
  - Current byline heuristics are over/under-preferring source candidates for platform-style author modules.
- Priority: P2

## Proposed Fix Order

1. B5-C1 (`ehow-1`, `ehow-2`) - shared template mechanism.
2. B5-C3 (`wordpress`) - likely high-leverage tail cleanup.
3. B5-C2 (`simplyfound-1`) - targeted media/caption normalization.
4. B5-C4 (`tumblr`, `royal-road`) - metadata/byline narrowing.

## Acceptance Gates

1. Cluster-level target cases pass strict assertions.
2. Full `RealWorldCompatibilityTests` failure count decreases monotonically.
3. `MozillaCompatibilityTests` remains fully passing (`119/119`).
