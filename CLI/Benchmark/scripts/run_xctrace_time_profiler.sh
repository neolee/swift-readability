#!/usr/bin/env bash
set -euo pipefail

SIZE="${1:-medium}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CLI_DIR="$ROOT/CLI"
LIST="$ROOT/CLI/Benchmark/fixtures/lists/${SIZE}.txt"
TRACE_OUT="$ROOT/CLI/Benchmark/reports/raw/time-profiler-${SIZE}.trace"

if [[ ! -f "$LIST" ]]; then
  echo "missing fixture list: $LIST" >&2
  exit 1
fi

cd "$CLI_DIR"
swift build -c release
rm -rf "$TRACE_OUT"

xctrace record \
  --template "Time Profiler" \
  --output "$TRACE_OUT" \
  --time-limit 45s \
  --launch -- /usr/bin/env READABILITY_SIGNPOSTS=1 "$CLI_DIR/.build/release/ReadabilityCLI" \
  --benchmark \
  --benchmark-input-list "$LIST" \
  --benchmark-iterations 3 \
  --benchmark-warmup 1

echo "time profiler trace: $TRACE_OUT"
