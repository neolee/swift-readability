# Changelog

## 1.0.0 - 2026-03-20

First production release of the Swift Readability library.

### Added

- Public diagnostics API via `Readability.parseWithInspection()` and `InspectionReport`.
- `ReadabilityCLI inspect` workflow for staged-case extraction analysis.
- Incremental `ex-pages` compatibility baseline alongside Mozilla and real-world fixture suites.
- Four committed `ex-pages` cases:
  - `1a23-1`
  - `1a23-2`
  - `1a23-3`
  - `antirez-1`

### Changed

- Improved staged-case debugging workflow documentation around `fetch`, `parse`, `inspect`, `review`, `commit`, and `clean`.
- Expanded compatibility tracking to include the incremental `ExPagesCompatibilityTests` suite.
- Improved extraction quality for additional real-world page structures using targeted site rules.
- Documented the stable `data-readability-pre-type` output contract for annotated `<pre>` blocks.

### Site-Specific Compatibility Improvements

- Added antirez-specific cleanup for leading inline metadata mixed into article bodies.
- Added antirez-specific byline recovery from the page's inline metadata block.
- Added antirez-specific removal of trailing Disqus promo/footer content from article output.
- Added antirez-specific excerpt recovery for article bodies that are authored as a leading `<pre>` block.
- Added antirez-specific serialization annotation `data-readability-pre-type="markdown"` for article-body `<pre>` blocks that contain Markdown source rather than code.

### Notes

- Mozilla parity remains the default behavior; site-specific deviations are isolated through the `SiteRules` mechanism to reduce regression risk.
- Release validation includes `ExPagesCompatibilityTests`, `RealWorldCompatibilityTests`, and `MozillaCompatibilityTests`.
