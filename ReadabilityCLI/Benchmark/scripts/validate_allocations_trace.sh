#!/usr/bin/env bash
set -euo pipefail

ARG="${1:-medium}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

if [[ "$ARG" == *.trace ]]; then
  TRACE_IN="$ARG"
  base_name="$(basename "$TRACE_IN" .trace)"
  LOG_IN="$(dirname "$TRACE_IN")/${base_name}.log"
else
  SIZE="$ARG"
  TRACE_IN="$ROOT/ReadabilityCLI/Benchmark/reports/raw/allocations-${SIZE}.trace"
  LOG_IN="$ROOT/ReadabilityCLI/Benchmark/reports/raw/allocations-${SIZE}.log"
fi

if [[ ! -d "$TRACE_IN" ]]; then
  echo "INVALID: missing trace directory: $TRACE_IN" >&2
  exit 2
fi

if [[ -f "$LOG_IN" ]] && rg -q "Failed to attach to target process|Recording failed with errors" "$LOG_IN"; then
  echo "INVALID: allocations log reports attach/recording failure: $LOG_IN" >&2
  exit 1
fi

TOC_TMP="$(mktemp -t allocations-toc.XXXXXX.xml)"
ROW_TMP="$(mktemp -t allocations-row.XXXXXX.xml)"
trap 'rm -f "$TOC_TMP" "$ROW_TMP"' EXIT

if ! xctrace export --input "$TRACE_IN" --toc > "$TOC_TMP"; then
  echo "INVALID: failed to export trace TOC from $TRACE_IN" >&2
  exit 1
fi

if [[ ! -s "$TOC_TMP" ]]; then
  echo "INVALID: empty TOC export from $TRACE_IN" >&2
  exit 1
fi

SCHEMA="$(rg -o 'schema="[^"]+"' "$TOC_TMP" | sed -E 's/schema="([^"]+)"/\1/' | rg -i 'alloc' | head -n 1 || true)"
if [[ -z "$SCHEMA" ]]; then
  echo "INVALID: no allocation-related schema found in TOC for $TRACE_IN" >&2
  exit 1
fi

XPATH="/trace-toc/run[@number=\"1\"]/data/table[@schema=\"${SCHEMA}\"]/row[1]"
if ! xctrace export --input "$TRACE_IN" --xpath "$XPATH" > "$ROW_TMP"; then
  echo "INVALID: failed to export first row for schema '$SCHEMA' from $TRACE_IN" >&2
  exit 1
fi

if ! rg -q "<row>" "$ROW_TMP"; then
  echo "INVALID: schema '$SCHEMA' has no row data in $TRACE_IN" >&2
  exit 1
fi

echo "VALID: allocations trace has data (schema=$SCHEMA): $TRACE_IN"
