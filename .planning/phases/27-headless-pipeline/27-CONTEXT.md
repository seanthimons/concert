# Phase 27: Headless Pipeline - Context

**Gathered:** 2026-04-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Provide a scriptable entry point (`curate_headless()`) to the full curation pipeline — file read, frontmatter detection, cleaning, CompTox search, consensus classification, and XLSX export — without requiring the Shiny UI.

</domain>

<decisions>
## Implementation Decisions

### Verbosity / Progress Reporting
- **D-01:** Add `verbose = TRUE/FALSE` parameter for explicit control over progress messages
- Default to `verbose = TRUE` (messages shown); user can set `verbose = FALSE` for silent operation
- When `verbose = FALSE`, suppress all `message()` calls from pipeline functions

### Reference List Handling
- **D-02:** Add `reference_lists = NULL` parameter
- When NULL, load package defaults from `system.file("extdata", "reference_cache", package = "chemreg")`
- When provided, use the custom list (must match expected structure: stop_words, functional_categories, block_patterns, strip_terms, isotope_lookup)

### Frontmatter Detection
- **D-03:** Add `header_row = NULL` parameter for optional manual override
- When NULL, run the 3-algorithm ensemble detection (`detect_data_start()`)
- When specified (integer), skip detection and use that row as the header

### Error Handling
- **D-04:** Fail fast on first error with informative message
- No partial results — if API call fails or file can't be read, stop immediately
- User fixes the issue and re-runs

### Function Signature (Confirmed)
```r
curate_headless(
  input_path,
  output_path,
  tag_map,
  skip_flags = NULL,
  header_row = NULL,
  reference_lists = NULL,
  verbose = TRUE
)
```

### Return Value (Per HDL-04)
- **D-05:** Return a list with `$data` (curated data frame) and `$audit_trail` (cleaning audit tibble)
- Return invisibly so the XLSX export is the primary output; return value is for programmatic access

### Claude's Discretion
- Internal helper functions (if any) vs. inline implementation
- Exact error message wording
- Whether to add `@examples` in roxygen docs (nice to have, not required)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` — HDL-01 through HDL-04 define success criteria

### Existing Pipeline Code
- `R/file_handlers.R` — `safely_read_file()`, `validate_file()` for file I/O
- `R/data_detection.R` — `detect_data_start()`, `extract_clean_data()` for frontmatter handling
- `R/cleaning_pipeline.R` — 15-step cleaning pipeline with audit trail
- `R/cleaning_reference.R` — `load_all_reference_lists()` for reference data
- `R/curation.R` — `run_curation_pipeline()` orchestrates dedup → search → consensus
- `R/consensus.R` — `classify_consensus()`, resolution state handling
- `R/export_helpers.R` — `build_export_sheets()` for 7-sheet workbook construction

### Prior Phase Context
- `.planning/phases/26-app-relocation/26-CONTEXT.md` — Reference cache location decision (`system.file()` pattern)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `run_curation_pipeline()` already accepts `progress_callback` — can be adapted for verbose control
- `build_export_sheets()` handles all 7-sheet workbook construction
- `load_all_reference_lists(cache_dir)` already parameterized for directory path
- Cleaning pipeline functions already return audit trail tibbles

### Established Patterns
- Functions use `message()` for progress reporting (not `cat()` or `print()`)
- Audit trail structure: `(row_id, field, step, original_value, new_value, reason)`
- Error handling: `tryCatch()` with informative `stop()` messages

### Integration Points
- `curate_headless()` will be a new file `R/curate_headless.R` (single exported function)
- Needs `@export` tag and roxygen documentation
- Must work after `devtools::install()` — all dependencies resolved via NAMESPACE

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches for wiring existing functions together.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 27-headless-pipeline*
*Context gathered: 2026-04-13*
