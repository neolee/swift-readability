# Real-world Test Pages

This directory `Readability/Tests/ReadabilityTests/Resources/realworld-pages/` stores Mozilla Readability real-world page fixtures for the final stage of our project.

## Scope

- Keep all real-world website cases in this directory.
- Do not mix real-world fixtures with `Resources/test-pages` (functional/core fixtures).

## Expected Layout

Each test case should use the same three-file format as functional tests:

```text
realworld-pages/<case-name>/
  source.html
  expected.html
  expected-metadata.json
```

## Notes


# Real-world Import Batches

- Import real-world cases in small batches and keep a per-batch pass/fail report.
- Track unresolved real-world issues separately from functional/core baseline.

## Current Status Snapshot (2026-02-07)

- Stage: Batch 5 completed (all cases resolved)
- `RealWorldCompatibilityTests`: 49 tests imported, **0 failures**
- `MozillaCompatibilityTests`: 119/119 passing

Latest confirmed regression guardrails:
- `nytimes-3` and `nytimes-4` are passing after byline normalization rollback/narrowing.
- Real-world fixes must preserve full Mozilla suite pass status.

Execution cadence (applies to Batch 4 and later):
1. One iteration fixes one case only.
2. Run targeted case test.
3. Run full `RealWorldCompatibilityTests`.
4. Run full `MozillaCompatibilityTests`.
5. Report explicit failure delta and next case queue.

## Inventory

- Mozilla `test-pages` total: 130
- Imported in `Resources/test-pages`: 52
- Imported in `Resources/realworld-pages`: 49
- Imported unique total: 101
- Remaining not imported: 29

## Batch Plan

### Batch 1 (P1) - Major Sites (5) 
`wikipedia`, `medium-1`, `nytimes-1`, `cnn`, `wapo-1`

### Batch 2 (P1) - Major News Sites (11)
`bbc-1`, `guardian-1`, `telegraph`, `seattletimes-1`, `nytimes-2`, `nytimes-3`, `nytimes-4`, `nytimes-5`, `wapo-2`, `yahoo-1`, `yahoo-2`

### Batch 3 (P1) - Mainstream Media & Portals (10)
`cnet`, `cnet-svg-classes`, `engadget`, `theverge`, `buzzfeed-1`, `citylab-1`, `tmz-1`, `medicalnewstoday`, `msn`, `salon-1`

### Batch 4 (P1) - Engineering/Technical Content (12)
`ars-1`, `daringfireball-1`, `dropbox-blog`, `firefox-nightly-blog`, `gitlab-blog`, `google-sre-book-1`, `ietf-1`, `lwn-1`, `v8-blog`, `mozilla-1`, `medium-2`, `medium-3`

### Batch 5 (P2) - CMS/Blog Platforms (11)
`blogger`, `wordpress`, `tumblr`, `lifehacker-working`, `lifehacker-post-comment-load`, `ehow-1`, `ehow-2`, `dev418`, `simplyfound-1`, `spiceworks`, `royal-road`

### Batch 6 (P2) - International/Multilingual Sites (11)
`aktualne`, `folha`, `heise`, `herald-sun-1`, `la-nacion`, `lemonde-1`, `liberation-1`, `pixnet`, `qq`, `yahoo-3`, `yahoo-4`

### Batch 7 (P2) - Community/Knowledge Sites (10)
`aclu`, `archive-of-our-own`, `iab-1`, `mercurial`, `mozilla-2`, `topicseed-1`, `wikia`, `wikipedia-2`, `wikipedia-3`, `wikipedia-4`

### Batch 8 (P2) - Long-tail/Edge Structures (8)
`ebb-org`, `gmw`, `hukumusume`, `quanta-1`, `webmd-1`, `webmd-2`, `youth`, `breitbart`

## Import Workflow

The standard procedure for importing a new batch of real-world test pages:

### Step 1: Copy Test Fixtures
Copy the test case directory from the Mozilla reference `ref/mozilla-readability/test/test-pages` to our repository `Readability/Tests/ReadabilityTests/Resources/realworld-pages`. Each case must contain `source.html`, `expected.html`, and `expected-metadata.json`.

### Step 2: Register Test Cases
Add corresponding test methods to `RealWorldCompatibilityTests.swift`.

### Step 3: Run Baseline Tests
Execute the test suite to collect failures. Run in `./Readability` directory:
```shell
swift test --filter RealWorldCompatibilityTests
```
Record the first-diff mismatch for each failing case.

### Step 4: Analyze and Cluster
Group failing cases by root cause into issue clusters:
- Create `BATCH-N-CLUSTERS.md` documenting each cluster
- Assign a unique identifier (e.g., B6-C1, B6-C2)
- Describe failure signals, hypothesis, and priority
- Do not proceed to fixes until all cases are classified

### Step 5: Fix Clusters Iteratively
Resolve one cluster at a time. For each iteration:
1. Select one cluster to fix
2. Implement minimal, mechanism-driven changes (prefer `SiteRules` for site-specific issues)
3. Run three-level validation:
   - Targeted case test first
   - Full `RealWorldCompatibilityTests`
   - Full `MozillaCompatibilityTests` as safety gate
4. Update cluster status to CLOSED in `BATCH-N-CLUSTERS.md`
5. Report failure delta and remaining queue

See "Real-world Debugging Playbook" in `AGENTS.md` for detailed debugging methodology.

## Acceptance Standard Per Batch

1. Import acceptance
- Test fixtures are copied into `Resources/realworld-pages/<case>/`.
- `RealWorldCompatibilityTests` includes matching tests and runs.

2. Baseline analysis acceptance
- First-diff mismatch is captured per case.
- Divergences are grouped into issue clusters.

3. Closure acceptance
- All cases in the batch pass strict assertions (no `withKnownIssue` for that batch).

4. Global safety gate
- `swift test --filter RealWorldCompatibilityTests` remains fully passing.
- `swift test --filter MozillaCompatibilityTests` remains fully passing.
