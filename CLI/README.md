# Readability CLI Guide

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
swift run ReadabilityCLI parse <case> [--mozilla-timeout <seconds>]
swift run ReadabilityCLI probe-dom --html '<pre><code>...</code></pre>' --selector 'pre code'
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
├── swift-expected-metadata.json
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

The Mozilla bridge has a default timeout of 30 seconds. Override it when diagnosing unusually large pages:

```bash
swift run ReadabilityCLI parse 1a23-1 --mozilla-timeout 60
```

Outputs:

- `swift-out.html`
- `swift-result.json`
- `swift-expected-metadata.json`
- `mozilla-out.html` when Node.js is available
- `mozilla-result.json` when Node.js is available
- `draft-expected-metadata.json` when Mozilla returns extracted content

`parse` uses the original page URL stored in `meta.json` as the document base URL for both Swift and Mozilla runs. This keeps relative `href`, `src`, `srcset`, and similar media URLs resolvable in staged output.

`swift-result.json` is a full Swift-side metadata dump for debugging. `swift-expected-metadata.json` mirrors the fixture schema used by library tests and is intended as the starting point for `expected-metadata.json`.

If Mozilla Readability.js returns `null` for a staged page, `parse` no longer fails the whole command. Swift outputs are still written, `mozilla-result.json` records that Mozilla considered the page unreadable, and `review` can still be used with the available columns.

If the Mozilla bridge exits with an error, emits invalid JSON, or exceeds `--mozilla-timeout`, `parse` writes a structured failure object to `mozilla-result.json` and continues to the usual follow-up instructions instead of hanging or failing the whole command. The bridge stdout and stderr are redirected through temporary files in the staged case directory to avoid pipe backpressure on large Mozilla JSON output.

Use `parse` after `inspect` to compare actual rendered extraction results.

### `probe-dom`

Probes SwiftSoup parse, clone, and serialization behavior without running the full Readability pipeline.

```bash
swift run ReadabilityCLI probe-dom \
  --html '<pre><code><span class="line">    return value</span></code></pre>' \
  --selector 'span.line' \
  --outer \
  --strip-classes \
  --visible-whitespace
```

For a staged case, read from `source.html`:

```bash
swift run ReadabilityCLI probe-dom \
  --file .staging/matklad/source.html \
  --selector 'pre code' \
  --outer \
  --strip-classes \
  --visible-whitespace
```

Useful options:

- `--selector <selector>` chooses the node to serialize. Selection happens before `--strip-classes`, so class-based selectors such as `span.line` remain usable.
- `--outer` prints the selected element itself. Without it, the command prints inner HTML.
- `--strip-classes` removes `class` attributes from the output subtree, matching the default Readability fixture shape more closely.
- `--visible-whitespace` renders tabs, spaces, and newlines visibly as `⇥`, `·`, and `⏎`.
- `--copy` serializes SwiftSoup's native `copy()` of the selected element.
- `--manual-clone` serializes a manual clone that copies text with `TextNode.getWholeText()`.
- `--document` parses the input as a full document instead of a body fragment.
- `--pretty` enables SwiftSoup pretty printing before serialization.

Use `probe-dom` when you need to isolate SwiftSoup behavior from extraction logic, especially for whitespace-sensitive HTML such as `<pre>` / `<code>` blocks, syntax-highlighted line spans, or small DOM fragments that are hard to reason about inside the full parser.

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
- copies `meta.json` too when present, so ex-pages tests can preserve the original page URL
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

Use this flow for one problematic real-world page at a time. Do not mix multiple cases together in the same debugging loop.

1. In `./CLI`, fetch the raw HTML for the case.

```bash
./readability fetch <url> --name <case>
```

2. Run `parse` to generate both our output and Mozilla's output.

```bash
./readability parse <case>
```

3. Run `review` to open the side-by-side comparison view.

```bash
./readability review <case>
```

Use this step to prompt human review, identify the meaningful differences, and make an initial judgment about whether the mismatch is in content selection, cleanup, serialization, or metadata.

4. Collaboratively decide the ideal target output for this case.

This means the developer and the agent should agree on the desired `expected.html` and `expected-metadata.json`, rather than assuming Mozilla output can always be promoted unchanged. In most cases, start from `swift-out.html` and `swift-expected-metadata.json`, then edit to the intended target state with Mozilla output used as reference.

5. Commit the raw HTML and finalized expected output into `ex-pages`.

```bash
./readability commit <case>
```

6. Add the committed test to `Tests/ReadabilityTests/ExPagesCompatibilityTests.swift`.

7. In the repository root, run the ex-pages suite first and read the failure details.

```bash
cd ..
swift test --filter ExPagesCompatibilityTests
```

8. Return to `./CLI` and use `inspect` and related commands to diagnose the problem and fix the implementation.

```bash
cd CLI
./readability inspect <case>
```

9. In the repository root, re-run `ExPagesCompatibilityTests` to confirm the fix.

```bash
cd ..
swift test --filter ExPagesCompatibilityTests
```

If the case still fails, go back to the previous step and continue iterating. If it passes, then run the broader compatibility suites.

```bash
swift test --filter RealWorldCompatibilityTests
swift test --filter MozillaCompatibilityTests
```

10. Clean staging when the case is no longer needed.

```bash
cd CLI
./readability clean <case>
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
