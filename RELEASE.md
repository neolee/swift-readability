# Release Checklist

This checklist is for preparing the first production release of the Swift Readability library.

## 1. API and Behavior Freeze

- [x] Confirm public API signatures are stable (`Readability`, `ReadabilityOptions`, `ReadabilityResult`).
- [x] Confirm default option behavior is documented and tested.
- [ ] Add/refresh compatibility baseline tests for representative fixtures.
- [x] Run full test gates and record the final pass state:
  - [x] `swift test --filter RealWorldCompatibilityTests`
  - [x] `swift test --filter MozillaCompatibilityTests`

## 2. Documentation (Blocking)

- [x] Write/update the root `README.md` for production usage.
- [x] Validate `CLI/README.md` still matches current CLI behavior.
- [x] Ensure `README.md` includes installation and Swift version requirements.
- [x] Ensure `README.md` includes a minimal usage example (`init` + `parse()`).
- [x] Ensure `README.md` documents `ReadabilityOptions` and tuning guidance.
- [x] Ensure `README.md` documents known limitations and compatibility scope.
- [x] Ensure `README.md` includes troubleshooting for common parsing failures.

## 3. Performance (Blocking)

- [x] Add a reproducible performance baseline test plan and fixture set.
- [x] Measure parse time on representative small/medium/large inputs.
- [x] Measure memory profile for the same fixture set.
- [ ] Record baseline results in a committed report file.
- [ ] Define a simple regression gate policy (for example, max allowed delta).
- [x] Run one post-change comparison to prove the baseline pipeline works.
- [x] Run benchmark pipeline:
  - [x] `bash CLI/Benchmark/scripts/run_all.sh medium`
- [x] Confirm required reports exist:
  - [x] `CLI/Benchmark/reports/analysis/benchmark-medium.md`
  - [x] `CLI/Benchmark/reports/analysis/time-profiler-medium-phases.md`
- [x] Validate allocations trace data:
  - [x] `bash CLI/Benchmark/scripts/validate_allocations_trace.sh medium`
- [ ] If allocations validation fails, include non-blocking status report and reason:
  - [ ] `CLI/Benchmark/reports/analysis/allocations-medium-status.md`

## 4. Release Notes and Versioning

- [ ] Create/update `CHANGELOG.md` for the release.
- [ ] Summarize major compatibility milestones and known caveats.
- [ ] Tag release version and date in changelog.

## 5. Quality and Operations

- [ ] Verify error handling behavior for invalid HTML and empty content.
- [ ] Confirm no temporary debug code or debug-only tests remain.
- [ ] Confirm working tree is clean except intentional release files.

## Current Status Note

- Performance optimization work is intentionally paused after low-yield iterations.
- Codebase has been restored to the last verified stable extraction behavior.
- Next validation phase is external integration in a real project.

## 6. Final Release Decision

- [ ] Release review completed by maintainer.
- [ ] Go/No-Go decision recorded.
