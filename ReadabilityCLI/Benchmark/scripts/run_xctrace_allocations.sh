#!/usr/bin/env bash
set -euo pipefail

SIZE="${1:-medium}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CLI_DIR="$ROOT/ReadabilityCLI"
LIST="$ROOT/ReadabilityCLI/Benchmark/fixtures/lists/${SIZE}.txt"
TRACE_OUT="$ROOT/ReadabilityCLI/Benchmark/reports/raw/allocations-${SIZE}.trace"
LOG_OUT="$ROOT/ReadabilityCLI/Benchmark/reports/raw/allocations-${SIZE}.log"
TARGET_BIN="$CLI_DIR/.build/release/ReadabilityCLI"
ENTITLEMENTS_FILE="$ROOT/ReadabilityCLI/Benchmark/scripts/allocations-debug.entitlements"
ITERATIONS="${BENCH_ALLOC_ITERATIONS:-20}"
WARMUP="${BENCH_ALLOC_WARMUP:-1}"
HOLD_SECONDS="${BENCH_ALLOC_HOLD_SECONDS:-8}"
TIME_LIMIT="${BENCH_ALLOC_TIME_LIMIT:-120s}"
MAX_RETRIES="${BENCH_ALLOC_MAX_RETRIES:-3}"
SKIP_SIGNING="${BENCH_ALLOC_SKIP_SIGNING:-0}"

if [[ ! -f "$LIST" ]]; then
  echo "missing fixture list: $LIST" >&2
  exit 1
fi

cd "$CLI_DIR"
swift build -c release

if [[ ! -f "$TARGET_BIN" ]]; then
  echo "missing benchmark binary: $TARGET_BIN" >&2
  exit 1
fi

if [[ ! -f "$ENTITLEMENTS_FILE" ]]; then
  echo "missing allocations entitlements file: $ENTITLEMENTS_FILE" >&2
  exit 1
fi

if [[ "$SKIP_SIGNING" != "1" ]]; then
  echo "signing benchmark binary for xctrace attach: $TARGET_BIN"
  codesign --force --sign - --entitlements "$ENTITLEMENTS_FILE" "$TARGET_BIN"
fi

ENTITLEMENTS_DUMP="$(codesign -d --entitlements - "$TARGET_BIN" 2>&1 || true)"
if ! printf '%s\n' "$ENTITLEMENTS_DUMP" | rg -q "com.apple.security.get-task-allow"; then
  echo "benchmark binary is not debuggable (missing get-task-allow key): $TARGET_BIN" >&2
  echo "$ENTITLEMENTS_DUMP" >&2
  exit 1
fi

if ! printf '%s\n' "$ENTITLEMENTS_DUMP" | rg -q "<true/>|\\[Bool\\]\\s+true"; then
  echo "benchmark binary is not debuggable (missing get-task-allow=true): $TARGET_BIN" >&2
  echo "$ENTITLEMENTS_DUMP" >&2
  exit 1
fi

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
    --launch -- "$TARGET_BIN" \
    --benchmark \
    --benchmark-input-list "$LIST" \
    --benchmark-iterations "$ITERATIONS" \
    --benchmark-warmup "$WARMUP" \
    --benchmark-hold-seconds "$HOLD_SECONDS" >"$LOG_OUT" 2>&1
  status=$?
  set -e

  has_attach_failure=0
  if rg -q "Failed to attach to target process|Recording failed with errors" "$LOG_OUT"; then
    has_attach_failure=1
  fi

  has_recording_completed=0
  if rg -q "Recording completed\\. Saving output file" "$LOG_OUT"; then
    has_recording_completed=1
  fi

  if [[ "$has_attach_failure" -eq 0 ]] && [[ "$has_recording_completed" -eq 1 ]] && [[ -d "$TRACE_OUT" ]]; then
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
