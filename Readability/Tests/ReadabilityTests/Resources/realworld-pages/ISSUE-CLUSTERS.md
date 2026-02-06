# Stage 3-R Issue Clusters (Batch 1)

Date: 2026-02-06  
Scope: `wikipedia`, `medium-1`, `nytimes-1`, `cnn`, `wapo-1`

## Cluster Taxonomy

### RW-C1: Wrapper Identity Drift
- Type: Structural DOM parity
- Signature:
  - Expected wrapper identity (`id`/`class`) missing or transformed.
  - Example: expected `div#page.page`, actual `div`.
- Impacted cases:
  - `nytimes-1`
- Priority: P1
- Candidate areas:
  - Wrapper creation/normalization in post-processing and serialization path.

### RW-C2: Embedded Media/Gallery Drift
- Type: Structural DOM + metadata side effect
- Signature:
  - Embedded gallery container kept/placed differently from Mozilla output.
  - Byline source/normalization diverges (`@handle` vs `By Name`).
- Impacted cases:
  - `wapo-1`
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
  - `cnn` (title whitespace)
  - `wapo-1` (byline normalization)
  - `wikipedia` (excerpt behavior)
- Priority: P1
- Candidate areas:
  - Title trimming parity.
  - Byline normalization parity.
  - Excerpt fallback/length parity.

## Mapping Matrix

| Case | First Divergence | Secondary Divergence | Clusters |
|------|------------------|----------------------|----------|
| `cnn` | `h2` vs `div#js-ie-storytop` | title trailing space | `RW-C1`, `RW-C5` |
| `nytimes-1` | wrapper identity mismatch | - | `RW-C1` |
| `wapo-1` | gallery `div` vs expected `p` | byline format mismatch | `RW-C2`, `RW-C5` |
| `medium-1` | `figure > div` vs `figure > p` | - | `RW-C3` |
| `wikipedia` | `p#toctitle` vs `div#toctitle` | excerpt mismatch | `RW-C4`, `RW-C5` |

## Suggested Fix Order

1. `RW-C1` (wrapper identity drift): broadest structural leverage with low ambiguity.
2. `RW-C5` (metadata normalization): low-risk parity polish, likely unlocks multiple cases.
3. `RW-C2` (embedded media/gallery): medium risk, site-template specific.
4. `RW-C3`/`RW-C4` (tag-conversion edge paths): medium-high risk; validate against functional suite after each change.

## Acceptance Standard Per Cluster

- Cluster is "closed" only when:
  - all impacted real-world cases pass strict assertions without `withKnownIssue`, and
  - `MozillaCompatibilityTests` remains fully passing.
