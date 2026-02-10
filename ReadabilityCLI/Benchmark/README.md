# Benchmark Guide

This directory contains a reproducible benchmark pipeline for `ReadabilityCLI` as a library usage entrypoint.

## Directory Layout

- `fixtures/lists/`: benchmark input lists (one HTML path per line)
- `reports/raw/`: machine-readable raw outputs (`.json`, `.trace`, `.xml`, logs)
- `reports/analysis/`: human-readable reports (`.md`)
- `scripts/`: fixed benchmark/profiling/report scripts

## Prerequisites

- `swift`
- `xctrace`
- `jq`

## One Command Pipeline

From repository root:

```bash
BENCH_ALLOC_TIME_LIMIT=40s \
BENCH_ALLOC_ITERATIONS=10 \
BENCH_ALLOC_HOLD_SECONDS=12 \
BENCH_ALLOC_MAX_RETRIES=3 \
bash ReadabilityCLI/Benchmark/scripts/run_all.sh medium
```

This runs:
1. benchmark raw JSON generation
2. benchmark markdown summary generation
3. time-profiler trace recording (with signposts enabled)
4. signpost XML export from trace
5. phase-level markdown summary generation from signposts
6. allocations trace recording (with debug signing pre-step)
7. allocations trace validation

## Expected Outputs

For `medium`, a successful run should produce:

- Raw:
  - `ReadabilityCLI/Benchmark/reports/raw/benchmark-medium.json`
  - `ReadabilityCLI/Benchmark/reports/raw/time-profiler-medium.trace`
  - `ReadabilityCLI/Benchmark/reports/raw/time-profiler-medium-poi-signposts.xml`
  - `ReadabilityCLI/Benchmark/reports/raw/allocations-medium.trace`
  - `ReadabilityCLI/Benchmark/reports/raw/allocations-medium.log`
- Human-readable:
  - `ReadabilityCLI/Benchmark/reports/analysis/benchmark-medium.md`
  - `ReadabilityCLI/Benchmark/reports/analysis/time-profiler-medium-phases.md`
  - `ReadabilityCLI/Benchmark/reports/analysis/allocations-medium-status.md` (only if allocations failed)

## Script Reference

- End-to-end pipeline:
  - `bash ReadabilityCLI/Benchmark/scripts/run_all.sh <small|medium|large>`
- Raw benchmark only:
  - `bash ReadabilityCLI/Benchmark/scripts/run_benchmark.sh <small|medium|large>`
- Benchmark summary:
  - `bash ReadabilityCLI/Benchmark/scripts/summarize_benchmark.sh <raw.json> <report.md>`
- Record time profiler trace:
  - `bash ReadabilityCLI/Benchmark/scripts/run_xctrace_time_profiler.sh <small|medium|large>`
- Export signposts from time profiler trace:
  - `bash ReadabilityCLI/Benchmark/scripts/export_signposts.sh <small|medium|large>`
- Generate phase summary from signposts XML:
  - `bash ReadabilityCLI/Benchmark/scripts/summarize_signposts.sh <input.xml> <report.md>`
- Record allocations trace:
  - `bash ReadabilityCLI/Benchmark/scripts/run_xctrace_allocations.sh <small|medium|large>`
- Validate allocations trace data:
  - `bash ReadabilityCLI/Benchmark/scripts/validate_allocations_trace.sh <small|medium|large>`

## Known Problem and Fix in This Pipeline

### Problem: `Allocations` attach flakiness on CLI targets

Observed error:
- `Failed to attach to target process`

### Current mitigation (already implemented in script)

`run_xctrace_allocations.sh` now:
- signs benchmark binary with `get-task-allow=true` before recording
  - entitlement file:
    - `ReadabilityCLI/Benchmark/scripts/allocations-debug.entitlements`
- verifies target entitlements before running `xctrace`
- retries recording (`BENCH_ALLOC_MAX_RETRIES`, default `3`)
- treats "recording completed + no attach/recording error in log + trace exists" as success
- writes a log file:
  - `ReadabilityCLI/Benchmark/reports/raw/allocations-<size>.log`

Tune via environment variables when needed:

```bash
BENCH_ALLOC_TIME_LIMIT=180s \
BENCH_ALLOC_ITERATIONS=30 \
BENCH_ALLOC_HOLD_SECONDS=12 \
BENCH_ALLOC_MAX_RETRIES=5 \
bash ReadabilityCLI/Benchmark/scripts/run_xctrace_allocations.sh medium
```

If all retries fail, the script exits non-zero and points to the log file.

`run_all.sh` validates allocations trace data after recording.

`run_all.sh` treats allocations record/validation failure as non-blocking and writes:

- `ReadabilityCLI/Benchmark/reports/analysis/allocations-<size>-status.md`

This keeps benchmark/time-profiler report generation stable even when allocations attach is flaky.

### Validation rule used by `validate_allocations_trace.sh`

Validation passes when:

- trace exists and TOC export succeeds
- trace TOC includes `Allocations` track with:
  - `Statistics` detail
  - `Allocations List` detail

Fallback path:

- if an allocation-like schema exists in TOC and row export returns at least one `<row>`, validation also passes

## Regression Workflow

Recommended order after parser changes:

1. `BENCH_ALLOC_TIME_LIMIT=40s BENCH_ALLOC_ITERATIONS=10 BENCH_ALLOC_HOLD_SECONDS=12 BENCH_ALLOC_MAX_RETRIES=3 bash ReadabilityCLI/Benchmark/scripts/run_all.sh medium`
2. Compare:
   - `ReadabilityCLI/Benchmark/reports/analysis/benchmark-medium.md`
   - `ReadabilityCLI/Benchmark/reports/analysis/time-profiler-medium-phases.md`
3. If phase hotspot shifts unexpectedly, inspect:
   - `ReadabilityCLI/Benchmark/reports/raw/time-profiler-medium.trace`
   - `ReadabilityCLI/Benchmark/reports/raw/time-profiler-medium-poi-signposts.xml`
4. Confirm allocations status:
   - Pass condition: no `allocations-<size>-status.md` file generated by `run_all.sh`
   - If status file exists, inspect:
     - `ReadabilityCLI/Benchmark/reports/analysis/allocations-<size>-status.md`
     - `ReadabilityCLI/Benchmark/reports/raw/allocations-<size>.log`

## Acceptance Commands

Standard release-oriented performance check:

```bash
BENCH_ALLOC_TIME_LIMIT=40s \
BENCH_ALLOC_ITERATIONS=10 \
BENCH_ALLOC_HOLD_SECONDS=12 \
BENCH_ALLOC_MAX_RETRIES=3 \
bash ReadabilityCLI/Benchmark/scripts/run_all.sh medium
bash ReadabilityCLI/Benchmark/scripts/validate_allocations_trace.sh medium
```

Acceptance criteria:

- `benchmark-medium.md` and `time-profiler-medium-phases.md` are generated.
- Allocations validation returns `VALID`.
- If allocations validation is `INVALID`, keep the generated `allocations-medium-status.md` as explicit non-blocking evidence.
