#!/usr/bin/env bash
set -euo pipefail

SIZE="${1:-medium}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CLI_DIR="$ROOT/CLI"
LIST="$ROOT/CLI/Benchmark/fixtures/lists/${SIZE}.txt"
OUT="$ROOT/CLI/Benchmark/reports/raw/benchmark-${SIZE}.json"

if [[ ! -f "$LIST" ]]; then
  echo "missing fixture list: $LIST" >&2
  exit 1
fi

cd "$CLI_DIR"
swift build -c release
"$CLI_DIR/.build/release/ReadabilityCLI" \
  --benchmark \
  --benchmark-input-list "$LIST" \
  --benchmark-output "$OUT" \
  --benchmark-iterations 5 \
  --benchmark-warmup 1

echo "benchmark report: $OUT"
