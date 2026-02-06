# Stage 3-R Issue Clusters (Batch 1)

Date: 2026-02-06  
Scope: `wikipedia`, `medium-1`, `nytimes-1`, `cnn`, `wapo-1`

## Cluster Taxonomy

### RW-C1: Wrapper Identity Drift
- Type: Structural DOM parity
- Signature:
  - Leading container selection differs from Mozilla or extra non-article section is retained.
  - Example A: expected `h2`, actual `div#js-ie-storytop`.
  - Example B: expected article end at paragraph tail, actual keeps extra `main > section`.
- Impacted cases:
  - None (closed for current Batch 1 scope: `nytimes-1`, `cnn`)
- Priority: P1
- Candidate areas:
  - Candidate scoring/parent promotion and sibling merge boundaries.
  - Post-cleaning of trailing non-article sections.

### RW-C2: Embedded Media/Gallery Drift
- Type: Structural DOM + metadata side effect
- Signature:
  - Embedded gallery container kept/placed differently from Mozilla output.
  - Byline source/normalization diverges (`@handle` vs `By Name`).
- Impacted cases:
  - None (closed for current Batch 1 scope: `wapo-1`)
- Priority: P1
- Candidate areas:
  - Conditional cleaner media rules.
  - Byline extraction precedence and normalization.

### RW-C3: Figure/Caption Tag Conversion Drift
- Type: Structural DOM parity
- Signature:
  - Figure descendants converted to different block tags than expected.
  - Example: expected `figure > div`, actual `figure > p`.
- Impacted cases:
  - `medium-1`
- Priority: P1
- Candidate areas:
  - DIV-to-P conversion and phrasing-wrapper rules around media containers.

### RW-C4: TOC/Container Tag Drift
- Type: Structural DOM parity
- Signature:
  - TOC/title container tag differs while id/class survives.
  - Example: expected `p#toctitle`, actual `div#toctitle`.
- Impacted cases:
  - `wikipedia`
- Priority: P1
- Candidate areas:
  - Block normalization around TOC-like sections.

### RW-C5: Metadata Normalization Drift
- Type: Metadata parity
- Signature:
  - Title trailing whitespace mismatch.
  - Byline format mismatch (`By X` vs `@x`).
  - Excerpt truncation/selection mismatch.
- Impacted cases:
  - `wikipedia` (excerpt behavior)
- Priority: P1
- Candidate areas:
  - Title trimming parity.
  - Byline normalization parity.
  - Excerpt fallback/length parity.

## Mapping Matrix

| Case | First Divergence | Secondary Divergence | Clusters |
|------|------------------|----------------------|----------|
| `medium-1` | `figure > div` vs `figure > p` | - | `RW-C3` |
| `wikipedia` | `p#toctitle` vs `div#toctitle` | excerpt mismatch | `RW-C4`, `RW-C5` |

## Suggested Fix Order

1. `RW-C1` (wrapper identity drift): broadest structural leverage with low ambiguity.
2. `RW-C3` (figure/caption conversion): medium risk, currently isolated to one case.
3. `RW-C4`/`RW-C5` (TOC/excerpt parity): medium-high risk; validate against functional suite after each change.

## Current Execution Plan (Approved)

1. Step 1 (`RW-C1`) - fix trailing/leading non-article container drift
- Scope: `nytimes-1`, `cnn`
- Target:
  - remove retained trailing `main > section` in `nytimes-1`
  - resolve leading `h2` vs `div#js-ie-storytop` and in-read ad shell residual in `cnn` without widening regressions
- Acceptance:
  - impacted real-world cases pass strict assertions without `withKnownIssue`
  - `MozillaCompatibilityTests` remains `119/119` pass

2. Step 2 (`RW-C5`) - metadata normalization parity polish
- Scope: title whitespace, byline format, excerpt parity
- Target:
  - trim trailing title whitespace (`cnn`)
  - align byline normalization precedence (`wapo-1`)
  - align excerpt fallback/length behavior (`wikipedia`)
- Acceptance:
  - metadata mismatches for target cases removed or reduced
  - `MozillaCompatibilityTests` remains `119/119` pass

3. Step 3 (`RW-C2`) - embedded media/gallery structural parity
- Scope: gallery/media block handling (`wapo-1`)
- Target:
  - align gallery wrapper/tag outcome to Mozilla expected DOM
- Acceptance:
  - `wapo-1` structural first-diff cluster cleared
  - `MozillaCompatibilityTests` remains `119/119` pass

Status update (2026-02-06):
- Step 2 byline normalization target for `wapo-1` is closed.
- Step 3 gallery/media target for `wapo-1` is closed.

## Acceptance Standard Per Cluster

- Cluster is "closed" only when:
  - all impacted real-world cases pass strict assertions without `withKnownIssue`, and
  - `MozillaCompatibilityTests` remains fully passing.
