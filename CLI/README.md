# ReadabilityCLI

`ReadabilityCLI` is the executable entry point for the `Readability` library and can be used as:

- a simple local parser tool
- a reproducible benchmark/profiling runner

## Basic Usage

Parse from `stdin`:

```bash
cat test.html | swift run ReadabilityCLI --text-only 2> /dev/null
```

Parse from URL:

```bash
swift run ReadabilityCLI https://example.com --json
```

## Benchmark Entry

Run benchmark mode with a fixture list (one HTML path per line):

```bash
swift run ReadabilityCLI --benchmark \
  --benchmark-input-list Benchmark/fixtures/lists/medium.txt \
  --benchmark-iterations 5 \
  --benchmark-warmup 1 \
  --benchmark-hold-seconds 0 \
  --benchmark-output Benchmark/reports/raw/benchmark-medium.json
```

For full benchmark/profiling workflow, see:

- `Benchmark/README.md`
