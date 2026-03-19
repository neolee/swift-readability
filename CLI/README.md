# ReadabilityCLI

`ReadabilityCLI` is the issue-capture and calibration tool for this repository.
It is used to:

- fetch and stage problematic pages
- compare Swift output against Mozilla Readability.js
- inspect extraction internals for a staged case
- review HTML outputs side by side
- promote finalized cases into `Tests/ReadabilityTests/Resources/ex-pages/`

This README documents the current CLI workflow. Older benchmark-oriented instructions are obsolete and intentionally removed.

## Working Directory

Run the CLI from the `CLI/` package directory:

```bash
cd CLI
swift run ReadabilityCLI --help
```

The CLI writes staging files relative to the current directory, so running from `CLI/` keeps all temporary output under `CLI/.staging/`.

## Prerequisites

- Swift toolchain matching the repository
- Node.js on `PATH` if you want Mozilla comparison during `parse`

Mozilla comparison is optional. If Node.js is missing, Swift output is still generated.

## Command Summary

```bash
swift run ReadabilityCLI fetch <url> --name <case>
swift run ReadabilityCLI inspect <case>
swift run ReadabilityCLI parse <case>
swift run ReadabilityCLI review <case>
swift run ReadabilityCLI commit <case>
swift run ReadabilityCLI clean [<case>]
```

## Staging Layout

For a case named `1a23-1`, the CLI uses:

```text
CLI/.staging/1a23-1/
├── source.html
├── meta.json
├── swift-out.html
├── swift-result.json
├── mozilla-out.html
├── mozilla-result.json
├── draft-expected-metadata.json
├── expected.html
└── expected-metadata.json
```

Not every file exists at every step. The initial `fetch` step only creates `source.html` and `meta.json`.

## Subcommands

### `fetch`

Fetches a remote page and creates a new staged case.

```bash
swift run ReadabilityCLI fetch https://example.com/article --name example-1
```

Behavior:

- validates the URL and blocks obvious reserved/private hosts
- creates `CLI/.staging/<case>/`
- writes `source.html`
- writes `meta.json` with original URL and fetch time

Use `fetch` when you want a reproducible local copy of a problematic page before any parsing work begins.

### `inspect`

Runs Swift extraction with instrumentation and prints a compact trace.

```bash
swift run ReadabilityCLI inspect 1a23-1
```

Current report sections:

- pass summary
- active flags per pass
- content length vs `charThreshold`
- top candidates for the selected pass
- base score, class weight, and children score breakdown
- promotion trace when final selection differs from top scorer
- class/id weight component reference for passes where `WEIGHT` is active

Use `inspect` before changing extraction logic. It is the fastest way to see whether the problem is caused by candidate scoring, pass retry behavior, or candidate promotion.

### `parse`

Runs Swift Readability on a staged case and, when Node.js is available, also runs Mozilla Readability.js through the local bridge script.

```bash
swift run ReadabilityCLI parse 1a23-1
```

Outputs:

- `swift-out.html`
- `swift-result.json`
- `mozilla-out.html` when Node.js is available
- `mozilla-result.json` when Node.js is available
- `draft-expected-metadata.json` when Mozilla returns extracted content

If Mozilla Readability.js returns `null` for a staged page, `parse` no longer fails the whole command. Swift outputs are still written, `mozilla-result.json` records that Mozilla considered the page unreadable, and `review` can still be used with the available columns.

Use `parse` after `inspect` to compare actual rendered extraction results.

### `review`

Builds a local side-by-side HTML review page and opens it in the default browser.

```bash
swift run ReadabilityCLI review 1a23-1
```

The review page can include these columns when present:

- source HTML
- Swift output
- Mozilla output
- draft expected HTML

Use `review` when DOM diff text is not enough and you need visual comparison.

### `commit`

Promotes a finalized staged case into the `ex-pages` fixture set.

```bash
swift run ReadabilityCLI commit 1a23-1
```

Required staged files before commit:

- `source.html`
- `expected.html`
- `expected-metadata.json`

Behavior:

- copies finalized files into `Tests/ReadabilityTests/Resources/ex-pages/<case>/`
- prints a ready-to-paste test template for `ExPagesCompatibilityTests.swift`
- leaves staging files in place until you explicitly clean them

### `clean`

Deletes staging data.

```bash
swift run ReadabilityCLI clean 1a23-1
swift run ReadabilityCLI clean
```

Behavior:

- `clean <case>` removes one staged case after confirmation
- `clean` with no argument removes the entire `.staging/` directory after confirmation

## Standard Debugging Workflow For A Problem Page

Use this flow for a new problematic real-world page:

1. Stage the page.

```bash
swift run ReadabilityCLI fetch <url> --name <case>
```

2. Inspect pass behavior and candidate selection.

```bash
swift run ReadabilityCLI inspect <case>
```

3. Generate Swift and Mozilla outputs.

```bash
swift run ReadabilityCLI parse <case>
```

4. Review outputs side by side.

```bash
swift run ReadabilityCLI review <case>
```

5. Decide what kind of bug this is.

- candidate scoring or promotion problem
- sibling merge problem
- cleaner/post-process problem
- serialization mismatch
- metadata mismatch
- SwiftSoup-vs-Mozilla environment difference

6. Fix the smallest mechanism that explains the mismatch.

7. Re-run validation in repository test order.

```bash
cd ..
swift test --filter ExPagesCompatibilityTests
swift test --filter RealWorldCompatibilityTests
swift test --filter MozillaCompatibilityTests
```

8. When the case is finalized, promote it into `ex-pages`.

```bash
cd CLI
cp .staging/<case>/mozilla-out.html .staging/<case>/expected.html
cp .staging/<case>/draft-expected-metadata.json .staging/<case>/expected-metadata.json
# edit if needed
swift run ReadabilityCLI commit <case>
```

9. Add the generated test template to `Tests/ReadabilityTests/ExPagesCompatibilityTests.swift`.

10. Clean staging when the case is no longer needed.

```bash
swift run ReadabilityCLI clean <case>
```

## Practical Notes

- `parse` does not mutate your repository fixtures. It only writes under `.staging/`.
- `commit` does not remove staging data. This is intentional so you can diff or re-open the case.
- `inspect` is intended for extraction reasoning, not for visual review.
- `review` is intended for visual comparison, not for score diagnostics.
- If Mozilla output is missing, check whether `mozilla-result.json` says Mozilla returned `null`, and otherwise verify that `CLI/scripts/mozilla-bridge.js` exists and Node.js dependencies are installed in `CLI/scripts/`.

## When To Run Which Tests

For normal case work, prefer this order:

1. `swift test --filter ExPagesCompatibilityTests`
2. `swift test --filter RealWorldCompatibilityTests`
3. `swift test --filter MozillaCompatibilityTests`

Run full `swift test` only for milestone validation, larger refactors, or when you explicitly want the additional library-level regression suites.
