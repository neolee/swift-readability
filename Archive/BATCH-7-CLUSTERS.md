# Stage 3-R Batch 7 Issue Clusters

Date: 2026-02-10  
Scope: `aclu`, `archive-of-our-own`, `iab-1`, `mercurial`, `mozilla-2`, `topicseed-1`, `wikia`, `wikipedia-2`, `wikipedia-3`, `wikipedia-4`

## Baseline Snapshot

- Import status: 10/10 cases imported and registered
- `RealWorldCompatibilityTests`: 70 tests total, 6 failing cases (12 issues)
- `MozillaCompatibilityTests`: not run in baseline import step

Failing cases from baseline:
- `wikia`
- `mercurial`
- `mozilla-2`
- `wikipedia-2`
- `wikipedia-3`
- `wikipedia-4`

## Current Snapshot (after C1 partial + C2 done)

- `RealWorldCompatibilityTests`: 70 tests total, 5 failing cases (7 issues)
- `MozillaCompatibilityTests`: PASS (119 tests)
- Failure delta: `6 cases / 12 issues -> 5 cases / 7 issues`

Remaining failing cases:
- `wikipedia-2` (content, excerpt)
- `wikipedia-3` (content)
- `wikipedia-4` (excerpt)
- `mercurial` (content, excerpt)
- `mozilla-2` (content attr)

## Cluster B7-C1 - Wikipedia Lead-Block / Shortdescription Drift

- Type: Structural + metadata parity
- Impacted cases:
  - `wikipedia-2` (leading `div[role=note]` selected before expected body)
  - `wikipedia-4` (dynamic-list note block retained at top)
  - `wikipedia-3` (title pulled from shortdescription headline instead of page title)
- Signals:
  - article starts with hatnote/disambiguation note instead of content paragraph
  - title/excerpt drift to shortdescription-like strings
- Priority: P1
- Status: PARTIAL
  - fixed: Wikipedia title drift via Wikimedia JSON-LD `name` override
  - fixed: top-level hatnote/shortdescription leakage in `wikipedia-2` and `wikipedia-4`
  - remaining: `wikipedia-2` content/excerpt, `wikipedia-3` content, `wikipedia-4` excerpt

## Cluster B7-C2 - Wikia Byline Time Suffix Drift

- Type: Metadata parity
- Impacted cases:
  - `wikia` (byline includes trailing relative-time fragment)
- Signals:
  - expected byline is author-only; actual includes `• 8h` tail
- Priority: P2
- Status: DONE

## Cluster B7-C3 - Mercurial TOC/Section Ordering Drift

- Type: Structural + excerpt parity
- Impacted cases:
  - `mercurial` (section mismatch around repeated examples; excerpt mismatch)
- Signals:
  - candidate extraction diverges in mid-article sequence selection
  - excerpt should remain `Contents`
- Priority: P1
- Status: OPEN

## Cluster B7-C4 - Mozilla-2 Root Attribute Parity

- Type: Structural attribute parity
- Impacted cases:
  - `mozilla-2` (missing `role="main"` on top wrapper)
- Signals:
  - descriptor matches but root attribute count/value differs
- Priority: P2
- Status: OPEN

## Planned Iteration Order

1. B7-C1 (Wikipedia lead-block/title drift)
2. B7-C3 (Mercurial structure drift)
3. B7-C2 (Wikia byline suffix)
4. B7-C4 (Mozilla-2 attribute parity)

## Iteration Protocol

1. Run targeted case test(s) for one cluster.
2. Run full `RealWorldCompatibilityTests` and record failure delta.
3. Run full `MozillaCompatibilityTests` as safety gate.
4. Update this file with cluster status and remaining queue.
