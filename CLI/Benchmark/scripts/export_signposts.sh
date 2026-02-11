#!/usr/bin/env bash
set -euo pipefail

SIZE="${1:-medium}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TRACE_IN="$ROOT/CLI/Benchmark/reports/raw/time-profiler-${SIZE}.trace"
OUT_XML="$ROOT/CLI/Benchmark/reports/raw/time-profiler-${SIZE}-poi-signposts.xml"

if [[ ! -d "$TRACE_IN" ]]; then
  echo "missing trace directory: $TRACE_IN" >&2
  exit 1
fi

TMP_XML="${OUT_XML}.tmp"
rm -f "$TMP_XML"

xctrace export \
  --input "$TRACE_IN" \
  --xpath '/trace-toc/run[@number="1"]/data/table[@schema="os-signpost" and @category="PointsOfInterest"]' \
  > "$TMP_XML"

if [[ ! -s "$TMP_XML" ]]; then
  echo "xctrace export produced empty signpost xml" >&2
  rm -f "$TMP_XML"
  exit 2
fi

mv "$TMP_XML" "$OUT_XML"

echo "signpost xml: $OUT_XML"
