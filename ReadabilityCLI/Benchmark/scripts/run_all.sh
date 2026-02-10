#!/usr/bin/env bash
set -euo pipefail

SIZE="${1:-medium}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

bash "$ROOT/ReadabilityCLI/Benchmark/scripts/run_benchmark.sh" "$SIZE"
bash "$ROOT/ReadabilityCLI/Benchmark/scripts/summarize_benchmark.sh" \
  "$ROOT/ReadabilityCLI/Benchmark/reports/raw/benchmark-${SIZE}.json" \
  "$ROOT/ReadabilityCLI/Benchmark/reports/analysis/benchmark-${SIZE}.md"
bash "$ROOT/ReadabilityCLI/Benchmark/scripts/run_xctrace_time_profiler.sh" "$SIZE"
bash "$ROOT/ReadabilityCLI/Benchmark/scripts/export_signposts.sh" "$SIZE"
bash "$ROOT/ReadabilityCLI/Benchmark/scripts/summarize_signposts.sh" \
  "$ROOT/ReadabilityCLI/Benchmark/reports/raw/time-profiler-${SIZE}-poi-signposts.xml" \
  "$ROOT/ReadabilityCLI/Benchmark/reports/analysis/time-profiler-${SIZE}-phases.md"
if bash "$ROOT/ReadabilityCLI/Benchmark/scripts/run_xctrace_allocations.sh" "$SIZE"; then
  VALIDATE_OUTPUT="$(bash "$ROOT/ReadabilityCLI/Benchmark/scripts/validate_allocations_trace.sh" "$SIZE" 2>&1 || true)"
  if [[ "$VALIDATE_OUTPUT" == VALID:* ]]; then
    echo "allocations profiling completed and validated"
  else
    LOG_PATH="$ROOT/ReadabilityCLI/Benchmark/reports/raw/allocations-${SIZE}.log"
    STATUS_MD="$ROOT/ReadabilityCLI/Benchmark/reports/analysis/allocations-${SIZE}-status.md"
    {
      echo "# Allocations Profiling Status"
      echo
      echo "- Status: INVALID TRACE (non-blocking)"
      echo "- Log: \`$LOG_PATH\`"
      echo "- Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
      echo
      echo "## Validation"
      echo
      echo '```text'
      echo "$VALIDATE_OUTPUT"
      echo '```'
      echo
      echo "## Last Log Lines"
      echo
      echo '```text'
      tail -n 30 "$LOG_PATH" 2>/dev/null || true
      echo '```'
    } > "$STATUS_MD"
    echo "allocations trace validation failed (non-blocking). status report: $STATUS_MD"
  fi
else
  LOG_PATH="$ROOT/ReadabilityCLI/Benchmark/reports/raw/allocations-${SIZE}.log"
  STATUS_MD="$ROOT/ReadabilityCLI/Benchmark/reports/analysis/allocations-${SIZE}-status.md"
  {
    echo "# Allocations Profiling Status"
    echo
    echo "- Status: FAILED (non-blocking)"
    echo "- Log: \`$LOG_PATH\`"
    echo "- Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo
    echo "## Last Log Lines"
    echo
    echo '```text'
    tail -n 30 "$LOG_PATH" 2>/dev/null || true
    echo '```'
  } > "$STATUS_MD"
  echo "allocations profiling failed (non-blocking). status report: $STATUS_MD"
fi
