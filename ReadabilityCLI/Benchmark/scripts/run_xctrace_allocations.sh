#!/usr/bin/env bash
set -euo pipefail

SIZE="${1:-medium}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CLI_DIR="$ROOT/ReadabilityCLI"
LIST="$ROOT/ReadabilityCLI/Benchmark/fixtures/lists/${SIZE}.txt"
TRACE_OUT="$ROOT/ReadabilityCLI/Benchmark/reports/raw/allocations-${SIZE}.trace"
LOG_OUT="$ROOT/ReadabilityCLI/Benchmark/reports/raw/allocations-${SIZE}.log"
ITERATIONS="${BENCH_ALLOC_ITERATIONS:-20}"
WARMUP="${BENCH_ALLOC_WARMUP:-1}"
HOLD_SECONDS="${BENCH_ALLOC_HOLD_SECONDS:-8}"
TIME_LIMIT="${BENCH_ALLOC_TIME_LIMIT:-120s}"
MAX_RETRIES="${BENCH_ALLOC_MAX_RETRIES:-3}"

if [[ ! -f "$LIST" ]]; then
  echo "missing fixture list: $LIST" >&2
  exit 1
fi

cd "$CLI_DIR"
swift build -c release
rm -rf "$TRACE_OUT"
rm -f "$LOG_OUT"

attempt=1
while [[ "$attempt" -le "$MAX_RETRIES" ]]; do
  echo "allocations attempt ${attempt}/${MAX_RETRIES} ..."
  set +e
  xctrace record \
    --template "Allocations" \
    --output "$TRACE_OUT" \
    --time-limit "$TIME_LIMIT" \
    --launch -- "$CLI_DIR/.build/release/ReadabilityCLI" \
    --benchmark \
    --benchmark-input-list "$LIST" \
    --benchmark-iterations "$ITERATIONS" \
    --benchmark-warmup "$WARMUP" \
    --benchmark-hold-seconds "$HOLD_SECONDS" >"$LOG_OUT" 2>&1
  status=$?
  set -e

  if [[ "$status" -eq 0 ]] && ! rg -q "Failed to attach to target process" "$LOG_OUT"; then
    echo "allocations trace: $TRACE_OUT"
    exit 0
  fi

  if [[ "$attempt" -lt "$MAX_RETRIES" ]]; then
    echo "allocations profiling did not attach, retrying ..."
    rm -rf "$TRACE_OUT"
    sleep 1
  fi
  attempt=$((attempt + 1))
done

echo "allocations profiling failed after ${MAX_RETRIES} attempts" >&2
echo "see log: $LOG_OUT" >&2
exit 2
