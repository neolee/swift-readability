# Release Checklist

This checklist is for preparing the first production release of the Swift Readability library.

## 1. API and Behavior Freeze

- [ ] Confirm public API signatures are stable (`Readability`, `ReadabilityOptions`, `ReadabilityResult`).
- [ ] Confirm default option behavior is documented and tested.
- [ ] Add/refresh compatibility baseline tests for representative fixtures.
- [ ] Run full test gates and record the final pass state:
  - [ ] `swift test --filter RealWorldCompatibilityTests`
  - [ ] `swift test --filter MozillaCompatibilityTests`

## 2. Documentation (Blocking)

- [ ] Write/update the root `README.md` for production usage.
- [ ] Validate `ReadabilityCLI/README.md` still matches current CLI behavior.
- [ ] Ensure `README.md` includes installation and Swift version requirements.
- [ ] Ensure `README.md` includes a minimal usage example (`init` + `parse()`).
- [ ] Ensure `README.md` documents `ReadabilityOptions` and tuning guidance.
- [ ] Ensure `README.md` documents known limitations and compatibility scope.
- [ ] Ensure `README.md` includes troubleshooting for common parsing failures.

## 3. Performance (Blocking)

- [ ] Add a reproducible performance baseline test plan and fixture set.
- [ ] Measure parse time on representative small/medium/large inputs.
- [ ] Measure memory profile for the same fixture set.
- [ ] Record baseline results in a committed report file.
- [ ] Define a simple regression gate policy (for example, max allowed delta).
- [ ] Run one post-change comparison to prove the baseline pipeline works.

## 4. Release Notes and Versioning

- [ ] Create/update `CHANGELOG.md` for the release.
- [ ] Summarize major compatibility milestones and known caveats.
- [ ] Tag release version and date in changelog.

## 5. Quality and Operations

- [ ] Verify error handling behavior for invalid HTML and empty content.
- [ ] Confirm no temporary debug code or debug-only tests remain.
- [ ] Confirm working tree is clean except intentional release files.

## 6. Final Release Decision

- [ ] Release review completed by maintainer.
- [ ] Go/No-Go decision recorded.
