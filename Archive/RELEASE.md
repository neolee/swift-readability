# Release Checklist

This checklist is for preparing the first production release of the Swift Readability library.

## 1. API and Behavior Freeze

- [x] Confirm public API signatures are stable (`Readability`, `ReadabilityOptions`, `ReadabilityResult`).
- [x] Confirm default option behavior is documented and tested.
- [x] Add/refresh compatibility baseline tests for representative fixtures.
- [x] Run full test gates and record the final pass state:
  - [x] `swift test`
  - [x] `swift test --filter ExPagesCompatibilityTests`
  - [x] `swift test --filter RealWorldCompatibilityTests`
  - [x] `swift test --filter MozillaCompatibilityTests`

## 2. Documentation (Blocking)

- [x] Write/update the root `README.md` for production usage.
- [x] Validate `CLI/README.md` still matches current CLI behavior.
- [x] Ensure `README.md` includes installation and Swift version requirements.
- [x] Ensure `README.md` includes a minimal usage example (`init` + `parse()`).
- [x] Ensure `README.md` documents diagnostics usage (`parseWithInspection()` / `InspectionReport`).
- [x] Ensure `README.md` documents `ReadabilityOptions` and tuning guidance.
- [x] Ensure `README.md` documents known limitations and compatibility scope.
- [x] Ensure `README.md` includes troubleshooting for common parsing failures.

## 3. Performance (Blocking)

- [ ] Add a reproducible performance baseline test plan and fixture set.
- [ ] Measure parse time on representative small/medium/large inputs.
- [ ] Measure memory profile for the same fixture set.
- [ ] Record baseline results in a committed report file.
- [ ] Define a simple regression gate policy (for example, max allowed delta).
- [ ] Run one post-change comparison to prove the baseline pipeline works.
- [ ] Run benchmark pipeline.
- [ ] Confirm required benchmark reports exist in the repository or a linked release artifact location.
- [ ] Validate allocations trace data.
- [ ] If allocations validation fails, include non-blocking status report and reason:
  - [ ] Record the missing artifact location or reason in release notes.

## 4. Release Notes and Versioning

- [x] Create/update `CHANGELOG.md` for the release.
- [x] Summarize major compatibility milestones and known caveats.
- [x] Tag release version and date in changelog.

## 5. Quality and Operations

- [ ] Verify error handling behavior for invalid HTML and empty content.
- [x] Confirm no temporary debug code or debug-only tests remain.
- [ ] Confirm working tree is clean except intentional release files.

## Current Status Note

- The incremental `ex-pages` baseline currently includes four committed cases: `1a23-1`, `1a23-2`, `1a23-3`, and `antirez-1`.
- The library now exposes `parseWithInspection()` and `InspectionReport` for extraction diagnostics.
- `ReadabilityCLI inspect` is the primary staged-case analysis tool for root-cause diagnosis before introducing new extraction heuristics or site rules.
- Next validation phase is external integration in a real project such as Mercury.

## 6. Final Release Decision

- [ ] Release review completed by maintainer.
- [ ] Go/No-Go decision recorded.
