# Real-world Import Batches

Date: 2026-02-06
Scope: Mozilla `test-pages` remaining real-world imports

## Current Status Snapshot (2026-02-07)

- Stage: Batch 4 kickoff in progress
- `RealWorldCompatibilityTests`: 27 tests imported (`ars-1` added), validation in progress
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
- Imported in `Resources/realworld-pages`: 27
- Imported unique total: 79
- Remaining not imported: 51

All 51 remaining cases were checked and contain:
- `source.html`
- `expected.html`
- `expected-metadata.json`

## Batch Plan

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
- `swift test --filter MozillaCompatibilityTests` remains fully passing.
