#!/usr/bin/env bash
set -euo pipefail

IN="${1:-}"
OUT="${2:-}"

if [[ -z "$IN" || -z "$OUT" ]]; then
  echo "usage: summarize_benchmark.sh <input.json> <output.md>" >&2
  exit 1
fi

if [[ ! -f "$IN" ]]; then
  echo "missing input file: $IN" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUT")"

{
  echo "# Benchmark Summary"
  echo
  echo "- Source: \`$IN\`"
  echo "- Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo
  echo "## Overall"
  echo
  jq -r '
    [
      "| Metric | Value |",
      "|---|---:|",
      "| Cases | \(.totalCases) |",
      "| Runs | \(.totalMeasuredRuns) |",
      "| p50 (ms) | \(.overallP50Ms|tostring) |",
      "| p95 (ms) | \(.overallP95Ms|tostring) |",
      "| Avg (ms) | \(.overallAverageMs|tostring) |",
      "| Throughput (pages/s) | \(.throughputPagesPerSecond|tostring) |"
    ] | .[]' "$IN"
  echo
  echo "## Slowest Cases by p95"
  echo
  jq -r '
    [
      "| Case | p50 (ms) | p95 (ms) | avg (ms) | max (ms) |",
      "|---|---:|---:|---:|---:|"
    ] + (
      .cases
      | sort_by(.p95Ms)
      | reverse
      | .[0:10]
      | map("| \(.path) | \(.p50Ms) | \(.p95Ms) | \(.averageMs) | \(.maxMs) |")
    ) | .[]' "$IN"
} > "$OUT"

echo "summary report: $OUT"
