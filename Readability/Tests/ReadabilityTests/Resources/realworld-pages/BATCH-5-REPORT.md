# Stage 3-R Batch 5 Progress Report

Date: 2026-02-07
Batch: `blogger`, `wordpress`, `tumblr`, `lifehacker-working`, `lifehacker-post-comment-load`, `ehow-1`, `ehow-2`, `dev418`, `simplyfound-1`, `spiceworks`, `royal-road`

## Baseline Summary

- Total new cases: 11
- Strict pass: 5 (`blogger`, `lifehacker-working`, `lifehacker-post-comment-load`, `dev418`, `spiceworks`)
- Failing cases: 6 (`ehow-1`, `ehow-2`, `simplyfound-1`, `wordpress`, `tumblr`, `royal-road`)
- Known issues: 0 (not added in this baseline pass)

## First-Diff Snapshot (Batch 5)

1. `blogger`
- Status: strict pass.

2. `wordpress`
- Status: failing.
- First diff: DOM node count mismatch (`expected 54`, `actual 65`), with extra retained tail subtree under `main > div`.

3. `tumblr`
- Status: failing.
- First diff: byline mismatch (`expected nil`, `actual "mcupdate"`).

4. `lifehacker-working`
- Status: strict pass.

5. `lifehacker-post-comment-load`
- Status: strict pass.

6. `ehow-1`
- Status: failing.
- First diff: wrapper shape mismatch (`expected div`, `actual p`) inside article header helper block.

7. `ehow-2`
- Status: failing.
- First diff: early structural drift (`expected author-profile div block`, `actual headline h2`).

8. `dev418`
- Status: strict pass.

9. `simplyfound-1`
- Status: failing.
- First diff: media/caption region drift (`expected caption paragraph`, `actual image wrapper div`).

10. `spiceworks`
- Status: strict pass.

11. `royal-road`
- Status: failing.
- First diff: byline mismatch (`expected "Follow Author"`, `actual "Sleyca"`).

## C1 Iteration Update

- Cluster fixed: `B5-C1` (`ehow-1`, `ehow-2`)
- Main mechanisms addressed:
  - eHow author-profile/byline preservation through extraction + cleanup
  - eHow header helper wrapper parity (`Found This Helpful`)
  - eHow related-content rail removal + featured tombstone trimming
- Validation:
  - Targeted: `testEHow1` / `testEHow2` pass
  - Full `RealWorldCompatibilityTests`: failures `6 -> 4`
  - Full `MozillaCompatibilityTests`: pass (`119/119`)

## Current Validation Snapshot

- `RealWorldCompatibilityTests`: 49 tests total, 4 failures (`simplyfound-1`, `wordpress`, `tumblr`, `royal-road`).
- `MozillaCompatibilityTests`: pass (`119/119`).

## C3 Iteration Update

- Cluster fixed: `B5-C3` (`wordpress`)
- Main mechanism addressed:
  - WordPress template previous/next post navigation rail removal
  - Implemented via site-specific post-process rule (`WordPressPrevNextNavigationRule`)
- Validation:
  - Targeted: `testWordpress` pass
  - Full `RealWorldCompatibilityTests`: failures `4 -> 3`
  - Full `MozillaCompatibilityTests`: pass (`119/119`)

## Latest Validation Snapshot

- `RealWorldCompatibilityTests`: 49 tests total, 3 failures (`simplyfound-1`, `tumblr`, `royal-road`).
- `MozillaCompatibilityTests`: pass (`119/119`).
