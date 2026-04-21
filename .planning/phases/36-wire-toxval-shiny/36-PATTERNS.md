# Phase 36: Wire ToxVal Schema in Shiny Path - Pattern Map

**Mapped:** 2026-04-21
**Files analyzed:** 3 files to modify (mod_harmonize.R, inst/app/app.R, .planning/REQUIREMENTS.md)
**Analogs found:** 3 / 3

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `R/mod_harmonize.R` | module (server) | pipeline / request-response | `R/curate_headless.R` lines 275-283 | exact — same mapper call, same inputs |
| `inst/app/app.R` | config / tab-gate | event-driven | `inst/app/app.R` lines 324-334 | exact — same `shiny::observe` + `shiny::req()` + `show_tab_with_pulse()` pattern |
| `.planning/REQUIREMENTS.md` | documentation | N/A | N/A — markdown edit, no code analog needed |

---

## Pattern Assignments

### `R/mod_harmonize.R` — add mapper call + data_store write

**Change location:** Inside the FULL MODE `withProgress()` block (lines 296-360), after Stage 4 stores
`data_store$harmonize_results` (currently ends at line 360). Insert the mapper call between Stage 4
and the closing brace of the `withProgress()` block.

**Analog:** `R/curate_headless.R` lines 275-283 (Stage 4: Map to ToxVal schema)

**Exact reference implementation** (curate_headless.R lines 275-283):
```r
# Stage 4: Map to ToxVal schema
message("[headless] Stage 4: Mapping to ToxVal schema...")
toxval_tibble <- map_to_toxval_schema(
  curated_data = input_df,
  harmonized_data = harmonize_tibble,
  source_name = tools::file_path_sans_ext(basename(input_path))
)
message(sprintf("[headless] ToxVal schema: %d rows x %d columns", nrow(toxval_tibble), ncol(toxval_tibble)))
```

**Shiny adaptation** (per D-01 through D-05 and D-11/D-12 from CONTEXT.md):
```r
# Stage 5: Map to ToxVal schema
incProgress(0.1, detail = "Mapping to ToxVal schema...")
toxval_tibble <- tryCatch(
  map_to_toxval_schema(
    curated_data = data_store$resolution_state,
    harmonized_data = harmonize_tibble,
    source_name = data_store$file_info$name
  ),
  error = function(e) {
    showNotification(
      paste("ToxVal mapping failed:", conditionMessage(e)),
      type = "warning",
      duration = 8
    )
    NULL
  }
)
data_store$toxval_output <- toxval_tibble
```

**Key differences from headless analog:**
- `curated_data` = `data_store$resolution_state` (not `input_df`; D-04 — resolution_state carries dtxsid/casrn/name from curation)
- `source_name` = `data_store$file_info$name` (D-05 — uploaded filename, not a filesystem path)
- Wrapped in `tryCatch()` with `showNotification()` instead of `message()` (D-12 — Shiny error surface, not console)
- Uses `incProgress()` instead of `message()` for UX continuity (D-03)
- Sets `data_store$toxval_output <- NULL` on error so Sheet 8 shows placeholder (D-12)

**Insertion point in mod_harmonize.R:**
After line 360 (`data_store$harmonize_audit <- dplyr::bind_cols(...)`) and before the closing `})` of the
FULL MODE `withProgress()` block (currently ends at line 361 with `})`).

**incProgress budget note:** The existing FULL MODE stages consume:
- 0.15 (corrections) + 0.30 (parsing) + 0.30 (harmonizing) + 0.25 (finalizing) = 1.00 total
The finalizing step at line 346 (`incProgress(0.25, detail = "Finalizing...")`) must be reduced to 0.15
and the new mapper step takes `incProgress(0.10, detail = "Mapping to ToxVal schema...")` to keep the sum at 1.00.

**Error handling pattern** (matches existing outer `tryCatch` in mod_harmonize.R lines 224-376):
```r
# Outer tryCatch already wraps the full pipeline (lines 224-376)
# Inner tryCatch for mapper only catches mapper errors, sets toxval_output NULL
# Outer tryCatch with type = "error" catches everything else and surfaces to user
```

**INCREMENTAL MODE: no mapper call**
The INCREMENTAL MODE block (lines 226-293) re-harmonizes a subset of rows and merges back into existing
results. Do NOT add a mapper call there — the mapper always needs the full resolved dataset. The mapper
call belongs exclusively in the FULL MODE block, consistent with the headless pipeline which always runs
mapper on the full output (curate_headless.R line 277, unconditional within `if (harmonize)`).

---

### `inst/app/app.R` — Harmonize tab gating change

**Change location:** Lines 361-364 (the `shiny::observe()` that calls `show_tab_with_pulse("harmonize_tab")`).

**Current code** (lines 360-364):
```r
# Phase 34: Show Harmonize tab when numeric tags are set
shiny::observe({
  shiny::req(data_store$numeric_tags)
  show_tab_with_pulse("harmonize_tab")
})
```

**Target code** (D-06, D-07, D-08 from CONTEXT.md):
```r
# Phase 36: Show Harmonize tab when numeric tags AND curation are complete
shiny::observe({
  shiny::req(data_store$numeric_tags, data_store$resolution_state)
  show_tab_with_pulse("harmonize_tab")
})
```

**Analog:** `inst/app/app.R` lines 331-335 — same `shiny::observe()` + multi-argument `shiny::req()` + `show_tab_with_pulse()` pattern:
```r
# Show Clean Data tab after tagging
shiny::observe({
  shiny::req(data_store$column_tags)
  show_tab_with_pulse("clean_data")
})
```

The multi-argument `req()` pattern is standard Shiny — all arguments must be truthy/non-NULL for the
observer to proceed. Adding `data_store$resolution_state` as a second argument enforces the full
linear workflow (upload → detect → clean → tag → curate → harmonize) per D-08.

**`show_tab_with_pulse` definition:** Defined in app.R around line 280-300 (search for `show_tab_with_pulse`).
No changes needed to the helper — only the `req()` call changes.

**Tab still hidden until both conditions met:** `bslib::nav_hide("harmonize_tab")` is called inside
`reset_chemical_downstream()` (line 300) and `reset_all_downstream()`. These already clear
`resolution_state`, so hiding the tab is already handled by the reset path. The `req()` gating is
the show-side gate only.

---

### `.planning/REQUIREMENTS.md` — mark SCHM-01, SCHM-04, UITG-06 complete

**Change type:** Documentation-only. No code analog needed.

**Target state per CONTEXT.md decisions D-09, D-10:**

Current lines to change:
```markdown
- [ ] **SCHM-01**: ToxVal 56-column schema transmutation with `*_original` audit columns for all harmonized fields
- [ ] **SCHM-04**: CSV export fallback when arrow unavailable (arrow in Suggests with `requireNamespace()` guard)
- [ ] **UITG-06**: Sheet 8 "ToxVal Output" in existing Excel export (separate sheet, not merged with data)
```

Target state:
```markdown
- [x] **SCHM-01**: ToxVal 56-column schema transmutation with `*_original` audit columns for all harmonized fields
- [x] **SCHM-04**: CSV export fallback when arrow unavailable — superseded by D-02 (arrow as hard dep). CSV available as format choice via `format="csv"` in `curate_headless()`, not as a fallback.
- [x] **UITG-06**: Sheet 8 "ToxVal Output" in existing Excel export (separate sheet, not merged with data)
```

Traceability table (lines 102-113) also needs Phase 36 rows updated from `Pending` to `Complete`:
```markdown
| SCHM-01 | Phase 36 | Complete |
| SCHM-04 | Phase 36 | Complete |
| UITG-06 | Phase 36 | Complete |
```

And the Coverage summary at line 117-119:
```markdown
- Complete: 27
- Pending (Phase 36 gap closure): 0
```

---

## Shared Patterns

### withProgress + incProgress (pipeline progress reporting)
**Source:** `R/mod_harmonize.R` lines 296-361 (FULL MODE block)
**Apply to:** The new mapper call inside the same `withProgress()` block
```r
withProgress(message = "Running harmonization...", value = 0, {
  incProgress(0.15, detail = "Applying corrections...")
  # ... stage work ...
  incProgress(0.30, detail = "Parsing numeric results...")
  # ... stage work ...
  incProgress(0.30, detail = "Harmonizing units...")
  # ... stage work ...
  incProgress(0.15, detail = "Finalizing...")   # reduced from 0.25 to 0.15
  # ... store harmonize_results ...
  incProgress(0.10, detail = "Mapping to ToxVal schema...")
  # ... mapper call + store toxval_output ...
})
```

### tryCatch + showNotification (inner error handling for optional steps)
**Source:** `R/mod_harmonize.R` lines 112-128 (apply_corrections per-row guard)
**Apply to:** The mapper `tryCatch` — same `type = "warning"` surface for non-fatal failures
```r
tryCatch(
  { ... },
  error = function(e) {
    showNotification(
      paste("ToxVal mapping failed:", conditionMessage(e)),
      type = "warning",
      duration = 8
    )
    NULL
  }
)
```
Note: The outer pipeline `tryCatch` (lines 224-376) uses `type = "error"` with `duration = NULL`
for fatal failures. The inner mapper `tryCatch` uses `type = "warning"` with `duration = 8` because
a mapper failure is non-fatal (export Sheet 8 will show placeholder, not crash the session).

### data_store reactive write at end of pipeline
**Source:** `R/mod_harmonize.R` lines 347-359 (Stage 4 store)
**Apply to:** `data_store$toxval_output <- toxval_tibble` write immediately after mapper call
```r
# Existing pattern:
data_store$harmonize_results <- list(
  parsed = parse_tibble,
  harmonized = harmonize_tibble,
  input_data = input_df
)
data_store$harmonize_audit <- dplyr::bind_cols(...)

# New write follows same pattern:
data_store$toxval_output <- toxval_tibble
```

### map_to_toxval_schema() function signature
**Source:** `R/toxval_mapper.R` lines 7-50 (function docs)
**Apply to:** The mapper call in mod_harmonize.R
```r
map_to_toxval_schema(
  curated_data  = <tibble from curation pipeline>,
  harmonized_data = <tibble from harmonize_units()>,
  source_name   = <character, optional — defaults to "user_upload">
)
```
`harmonized_data` must be the direct output of `harmonize_units()` (i.e., `harmonize_tibble` in
FULL MODE, not `data_store$harmonize_results$harmonized`). Use the local variable, not the stored
list element, to avoid an extra reactive read inside `observeEvent`.

### build_export_sheets toxval_output wire (already complete — DO NOT MODIFY)
**Source:** `R/mod_review_results.R` lines 1456-1467
**Status:** Already passes `toxval_output = data_store$toxval_output`. Phase 36 only needs to
populate `data_store$toxval_output` — the export path is already wired.
```r
sheets <- build_export_sheets(
  raw = data_store$raw,
  resolution_state = data_store$resolution_state,
  # ...
  toxval_output = data_store$toxval_output   # line 1466 — already present
)
```

---

## No Analog Found

None — all three files have concrete analogs or are documentation-only.

---

## Metadata

**Analog search scope:** `R/`, `inst/app/`, `.planning/`
**Key files scanned:** mod_harmonize.R (1124 lines), curate_headless.R (351 lines), inst/app/app.R (~410 lines), mod_review_results.R (lines 1440-1470), toxval_mapper.R (lines 1-50), REQUIREMENTS.md (122 lines)
**Pattern extraction date:** 2026-04-21
