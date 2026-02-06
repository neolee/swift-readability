# Real-world Test Pages

This directory stores Mozilla Readability real-world page fixtures for Stage 3-R.

## Scope

- Keep all real-world website cases in this directory.
- Do not mix real-world fixtures with `Resources/test-pages` (functional/core fixtures).

## Expected Layout

Each test case should use the same three-file format as functional tests:

```text
realworld-pages/<case-name>/
  source.html
  expected.html
  expected-metadata.json
```

## Notes

- Import real-world cases in small batches and keep a per-batch pass/fail report.
- Track unresolved real-world issues separately from functional/core baseline.
