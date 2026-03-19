# Readability CLI v2 Refactoring Plan (Issue Capture & Ground Truth Toolchain)

## 1. Background & Motivation

As the Readability library sees wider use in the RSS reader app Mercury, edge cases and site-specific extraction failures are inevitable. To make fault diagnosis systematic and to prevent regressions, the existing CLI tool will be thoroughly redesigned.

**Limitations of the current CLI and rationale for redesign:**

1. **Basic parsing is superseded**: The original "input HTML, output result" flow is fully covered by the new pipeline design.
2. **Benchmarking and profiling removed**: The existing benchmark tool, profiling infrastructure, and `Instrumentation.swift` in the main library (which used `os_signpost` for performance tracing) were not reliable in practice. All of these will be deleted in this refactor. Performance tooling will be redesigned from scratch when genuine need arises.
3. **Isolated incremental baseline**: Newly captured test cases will live in `Tests/ReadabilityTests/Resources/ex-pages/`, kept separate from Mozilla's official baseline (`test-pages/` and `realworld-pages/`). The name `ex-pages` denotes test cases added beyond the Mozilla official test set.

The redesigned CLI becomes an **Issue Capture & Ground Truth Calibration Pipeline** — a set of cohesive, composable atomic subcommands. The working directory remains `CLI/`, with a local staging area for in-progress work. Once a case is finalized, it is promoted into the main library's test suite.

---

## 2. Prerequisites

The `parse` command requires **Node.js** (`node` on `$PATH`) to execute the reference Mozilla Readability.js implementation for side-by-side comparison.

The bridge script (`CLI/scripts/mozilla-bridge.js`) uses CommonJS modules and `jsdom`, neither of which Deno supports out of the box. Node.js is the only supported runtime.

First-time setup for the bridge script:
```bash
cd CLI/scripts && npm install
```

---

## 3. Invoking the Tool

From within the `CLI/` directory:

```bash
swift run ReadabilityCLI <subcommand> [arguments]
```

A convenience shell script wrapper at the repo root may be added in a future iteration for brevity.

---

## 4. Core Architecture & Staging Area Design

The CLI operates on a local staging area at `CLI/.staging/<case-name>/`. This directory is listed in `.gitignore` and is never committed to the repository.

A complete case lifecycle may produce the following files within the staging directory:

| File | Description |
|---|---|
| `source.html` | Raw HTML snapshot taken at fetch time |
| `meta.json` | Fetch metadata (origin URL, timestamp) |
| `swift-out.html` | Content extracted by the Swift library |
| `swift-result.json` | Metadata extracted by the Swift library |
| `mozilla-out.html` | Content extracted by Mozilla Readability.js |
| `mozilla-result.json` | Metadata extracted by Mozilla Readability.js |
| `draft-expected.html` | Candidate ground truth (for human review) |
| `draft-expected-metadata.json` | Candidate metadata (for human review) |
| `expected.html` | Finalized ground truth content |
| `expected-metadata.json` | Finalized ground truth metadata |

**Case identity**: Once established by `fetch --name <case-name>`, all subsequent subcommands accept `<case-name>` as the sole case identifier. The `.staging/<case-name>/` path is an internal detail that users never need to type directly.

**Immutability policy**: Captured cases (`source.html`) are never updated in place. If a site changes and a new extraction issue arises, it is a new case with a new name.

---

## 5. Subcommand Design

The pipeline is composed of seven atomic subcommands plus one diagnostic tool.

### 5.1 `fetch` — Snapshot Acquisition
**Goal**: Freeze the page at the moment a problem is observed, eliminating the effect of dynamic content changes.
- **Syntax**: `ReadabilityCLI fetch <URL> --name <case-name>`
- **Process**:
  1. Validate the URL: only `http`/`https` schemes accepted; private/loopback ranges (`127.x`, `10.x`, `192.168.x`, `169.254.x`, `::1`) rejected; configurable timeout applies.
  2. Download the complete HTML of the page.
  3. Create `CLI/.staging/<case-name>/`.
  4. Write `source.html` and `meta.json` (recording origin URL and fetch timestamp).
- **Output**: Staging base files ready for subsequent steps.

### 5.2 `parse` — Dual-Engine Comparison
**Goal**: Run `source.html` through both the Swift library and Mozilla Readability.js, surfacing divergences and defects.
- **Syntax**: `ReadabilityCLI parse <case-name>`
- **Process**:
  1. **Swift side**: Invoke `Sources/Readability`, write `swift-out.html` and `swift-result.json` to staging.
  2. **Mozilla side**: Invoke the JS bridge script at `CLI/scripts/mozilla-bridge.js` via `Process`, using Node.js and `ref/mozilla-readability`. Write `mozilla-out.html` and `mozilla-result.json` to staging. The bridge script accepts the path to `source.html` as input and emits JSON to stdout.
- **Output**: Four comparison files written to the staging directory.

### 5.3 `review` — Side-by-Side Visual Comparison
**Goal**: Let the developer see at a glance how the Swift and Mozilla outputs differ, before deciding what the correct ground truth should be.
- **Syntax**: `ReadabilityCLI review <case-name>`
- **Process**:
  1. Read whatever output files are present in staging: `swift-out.html`, `mozilla-out.html`, and `draft-expected.html` (if it exists).
  2. Generate a self-contained `report.html` with one column per available file; each column renders the extracted content in an iframe.
  3. Open `report.html` in the default browser.
- **Design rationale**: Uses `srcdoc` iframes (not `src=`) to guarantee cross-browser local file loading without an HTTP server.
- **Output**: `report.html` written to the shared location `CLI/.staging/report.html` (overwritten on every invocation). Not stored per-case. No other files overwritten.

### 5.4 `judge` — Ground Truth Draft Generation
**Goal**: Provide a starting point for "what the correct output should look like", reducing manual effort.
- **Syntax**: `ReadabilityCLI judge <case-name> [--strategy <mozilla|ai>]`
- **Strategies**: `mozilla` (default): copies `mozilla-out.html` as `draft-expected.html`; `ai` (Phase 3, experimental): details TBD when implemented.
- **Output**: `draft-expected.html` and `draft-expected-metadata.json` written to staging.

### 5.5 `commit` — Test Case Promotion
**Goal**: Copy a finalized case into the library's test suite so development can begin against it.
- **Syntax**: `ReadabilityCLI commit <case-name>`
- **Process**:
  1. Validate that staging contains `source.html`, `expected.html`, and `expected-metadata.json`. If only `draft-expected.*` exist, print an instructive error.
  2. Copy the three files into `Tests/ReadabilityTests/Resources/ex-pages/<case-name>/`.
  3. Print a template snippet for adding a test method to `ExPagesCompatibilityTests.swift` (see Section 6).
- **Non-destructive**: Staging directory is NOT cleaned up. Use `clean` explicitly.
- **Output**: Test case files written to `ex-pages/`. Staging untouched.

---

### 5.6 `clean` — Staging Cleanup
**Goal**: Remove staging files when they are no longer needed.
- **Syntax**: `ReadabilityCLI clean <case-name>` (one case) or `ReadabilityCLI clean` (entire `.staging/`).
- **Process**: Prompts for confirmation, then deletes the specified staging directory. Does not affect anything under `Tests/`.

---

### 5.7 `inspect` — White-Box Diagnostics
**Goal**: When a case is under active investigation, surface the library's internal decision trace to guide whether to fix core logic or add a Site Rule.
- **Syntax**: `ReadabilityCLI inspect <case-name> [--trace]`
- **Process**: Execute a single Swift parse of `source.html` with diagnostics enabled, emitting a structured decision log covering:
  - **NodeCleaner phase**: Which large blocks were pruned as noise (ads, hidden elements) and why.
  - **Scoring phase**: Top-5 candidate nodes with their scores and penalty reasons.
  - **Fallback phase**: Whether all candidates were discarded, triggering `<body>` extraction.
- **Diagnostic guidance**:
  - If broad structural heuristics (density, tag penalties) are miscategorizing legitimate content, investigate and fix **core algorithms**.
  - If site-specific DOM structures (brand-specific class names, proprietary elements) are the root cause, write a **Site Rule**. Do not use Site Rules to mask core logic defects.

---

## 6. Test Integration

The `ex-pages/` test cases follow the same conventions as `realworld-pages/` tests. No changes to `TestLoader.swift` or existing test infrastructure are required.

A dedicated file `Tests/ReadabilityTests/ExPagesCompatibilityTests.swift` holds one test method per case, added **manually** after running `commit`. The `commit` command prints a ready-to-use template snippet:

```swift
@Test("<case-name> - Title matches expected")
func test<CaseName>Title() async throws {
    guard let testCase = TestLoader.loadTestCase(named: "<case-name>", in: "ex-pages") else {
        Issue.record("Failed to load test case")
        return
    }
    let result = try Readability(html: testCase.sourceHTML, options: defaultOptions).parse()
    #expect(result.title == testCase.expectedMetadata.title)
}
```

The `expected-metadata.json` format matches the Mozilla test page schema exactly, which maps directly to `ReadabilityResult` field names.

---

## 7. Implementation Phases

### Phase 1: Core Pipeline (Scaffold & Automation)
1. **Clean up the current CLI**: Delete benchmark components, the profiling infrastructure, and `Instrumentation.swift` from the main library.
2. **Add `swift-argument-parser`** to `CLI/Package.swift` and rebuild the CLI with a multi-subcommand architecture.
3. **Add `CLI/.staging/` to `.gitignore`**.
4. **Implement `fetch`, `parse`, `review`, `commit`, `clean`**:
   - Write the Mozilla JS bridge script at `CLI/scripts/mozilla-bridge.js`.
   - Run `npm install` in `CLI/scripts/` to install `jsdom`.
   - Implement Node.js detection and subprocess invocation in the `parse` command.
5. **Create `ExPagesCompatibilityTests.swift`** as an empty-but-compilable placeholder, to be filled case-by-case.

From Phase 1 onward, `judge` remains **manual**: copy `mozilla-out.html` to `draft-expected.html`, edit as needed, rename to `expected.*`, then call `commit`.

### Phase 2: Diagnostics System
1. Design a `DiagnosticsTrace` protocol in the main library, distinct from the deleted performance signpost infrastructure.
2. Extend `ReadabilityOptions` with an optional diagnostics callback (disabled by default, zero overhead when not set).
3. Implement the `inspect` command using this callback.

### Phase 3: Assisted Calibration (Judge)
1. Implement the `judge --strategy mozilla` default in code (manual copy in Phase 1).
2. (Experimental) Define the `judge --strategy ai` interface — opt-in flag, explicit user confirmation before any external call, no raw content forwarded without acknowledgment — and implement when requirements are clear.
