# Architecture Research: CONCERT v2.0 Pipeline Performance & Date/Media Harmonization

**Domain:** R/Shiny chemical data curation pipeline — v2.0 integration patterns
**Researched:** 2026-04-24
**Confidence:** HIGH (based on direct source reading of all relevant files: cleaning_pipeline.R, unit_harmonizer.R, numeric_parser.R, curate_headless.R, tag_helpers.R, toxval_mapper.R, mod_harmonize.R, mod_clean_data.R, cleaning_reference.R)

---

## System Overview

The existing architecture has three layers. v2.0 adds performance infrastructure to the pipeline layer and two new step types to the harmonization layer — without touching upload, detection, or curation.

```
┌──────────────────────────────────────────────────────────────────┐
│                    Shiny UI Layer (inst/app/app.R)                │
│  mod_file_upload  mod_clean_data  mod_harmonize  mod_tag_columns  │
│                    + 5 other modules                              │
├──────────────────────────────────────────────────────────────────┤
│                   Pipeline Function Layer (R/*.R)                 │
│                                                                   │
│  run_cleaning_pipeline()          harmonize_units()               │
│    ├─ [NEW] dedup wrapper         parse_numeric_results()         │
│    ├─ [NEW] short-circuit checks  map_to_toxval_schema()          │
│    └─ 15 step functions                                           │
│         each: df → list(          [NEW] parse_dates()             │
│           cleaned_data,           [NEW] harmonize_durations()     │
│           audit_trail)            [NEW] harmonize_media()         │
│                                                                   │
├──────────────────────────────────────────────────────────────────┤
│                   Reference Data Layer                            │
│  inst/extdata/reference_cache/   inst/extdata/unit_table.csv     │
│    stop_words.rds                                                 │
│    unit_conversion.rds     +     [NEW] media_map.rds             │
│    unit_synonyms.rds             [NEW] amos_media.rds            │
│    isotope_lookup.rds                                             │
│    corrections.rds                                               │
├──────────────────────────────────────────────────────────────────┤
│              Headless Entry Point (R/curate_headless.R)           │
│                curate_headless(harmonize = TRUE)                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## Integration Point Answers (Per Research Question)

### Q1: Where does distinct-string dedup sit — wrapper vs internal change?

**Answer: Wrapper layer in the orchestrator (`run_cleaning_pipeline()`), not inside step functions.**

Step functions stay unchanged. `run_cleaning_pipeline()` calls an internal helper (`dedup_step()`) that:
1. Extracts distinct values of the target column(s)
2. Builds a single-column tmp_df from those distinct values
3. Calls the step function on the tmp_df
4. Joins results back to the parent df by original value
5. Rebuilds the audit_trail with parent row_ids (not the dedup-slice row_ids)

The wrapper logic lives in `cleaning_pipeline.R` as a private utility function — not a new file, since it is pipeline infrastructure.

**Which steps are dedup-eligible:** Any step that processes column values independently of other columns in the same row. Specifically:
- `normalize_cas_fields()` — CAS string lookup, no row context needed
- `strip_terminal_enclosures()` — text pattern matching, no row context
- `strip_quality_adjectives()` — text matching, no row context
- `strip_salt_references()` — text matching, no row context
- `strip_terminal_unspecified()` — text matching, no row context
- `strip_reference_terms()` — text matching, no row context
- `expand_isotope_shortcodes()` — lookup table, no row context
- `ComptoxR::clean_unicode` (Steps 1-2) — character mapping, no row context

**Not dedup-eligible (row context required):**
- `rescue_cas_from_text()` — writes to new columns, cross-column interaction
- `detect_multi_cas()` — counts across CASRN columns per row
- `split_synonyms()` — expands rows (changes cardinality)
- `flag_multi_analyte()` — examines row content for multi-value patterns
- `protect_chiral_designations()` / `restore_chiral_designations()` — placeholder state is row-scoped

### Q2: Short-circuit checkers — new functions or integrated into step signatures?

**Answer: New predicate functions, called from orchestrators. Step function signatures do not change.**

Each checker is a small function that examines a column vector and returns FALSE if the step can be skipped. They live in the same file as the step they gate.

```r
# In cleaning_pipeline.R
needs_unicode_cleaning <- function(df, cols) {
  any(grepl("[^\x01-\x7F]",
    unlist(df[, cols, use.names = FALSE]),
    perl = TRUE
  ), na.rm = TRUE)
}

# In run_cleaning_pipeline():
if (needs_unicode_cleaning(df_after_lineage, char_cols)) {
  df_after_unicode <- df_after_lineage %>%
    dplyr::mutate(dplyr::across(tidyselect::where(is.character), ComptoxR::clean_unicode))
  audit_unicode <- build_audit_trail(...)
} else {
  df_after_unicode <- df_after_lineage
  audit_unicode <- empty_audit_trail()  # shared helper returning typed-NA tibble
}
```

Add `empty_audit_trail()` as a package-private helper (already the pattern in step functions — just centralize it). Checkers for harmonization steps go in `unit_harmonizer.R`.

### Q3: Date parser — new R file? How does it fit the step pattern?

**Answer: New `R/date_parser.R` file. It is a harmonization-layer step, NOT a cleaning-pipeline step.**

Date parsing requires knowing which column is tagged `StudyDate` — that is post-tagging information. The cleaning pipeline operates pre-tagging on all character columns. Therefore `parse_dates()` belongs in the harmonization layer, called alongside `parse_numeric_results()`.

Function signature mirrors `parse_numeric_results()`:

```r
# Returns tibble — same shape as parse_numeric_results() output
parse_dates(values)
# → tibble(
#     orig_row_id   = integer,
#     raw_date      = character,
#     parsed_date   = character,  # ISO-8601 "YYYY-MM-DD" or NA
#     date_year     = integer,    # extracted year for ToxVal original_year field
#     date_flag     = character   # "" | "inferred_format" | "partial" | "unparseable"
#   )
```

Wiring:
- `tag_helpers.R`: add `"StudyDate"` to `numeric_types` vector in `classify_tags()` (one-line change) so the Harmonize tab recognizes it
- `mod_harmonize.R` server: call `parse_dates()` when a StudyDate-tagged column exists, store result in `data_store$harmonize_results$dates`
- `curate_headless.R` harmonize block: add Stage 3c call
- `toxval_mapper.R`: populate `original_year` from `date_year` column of dates tibble

### Q4: Duration conversion — extends unit_harmonizer.R or separate?

**Answer: Extends `unit_harmonizer.R` via the unit conversion table — no new file or new dispatch logic.**

Duration units are just more rows in `unit_conversion.rds` (and `unit_table.csv`). `harmonize_units()` already dispatches on unit strings; duration units fall through the same exact-match hash lookup. The ECOTOX builder (ComptoxR section 12) uses hours as the base unit — replicate that convention.

Rows to add to `unit_table.csv`:

| from_unit | to_unit | multiplier |
|-----------|---------|-----------|
| h | h | 1 |
| hr | h | 1 |
| hours | h | 1 |
| d | h | 24 |
| day | h | 24 |
| days | h | 24 |
| wk | h | 168 |
| week | h | 168 |
| weeks | h | 168 |
| mo | h | 730 |
| month | h | 730 |
| months | h | 730 |
| yr | h | 8760 |
| year | h | 8760 |
| years | h | 8760 |

Wiring:
- `DurationUnit` is already in `numeric_types` in `classify_tags()` — no tag type change needed
- `mod_harmonize.R` and `curate_headless.R`: add routing branch that calls `harmonize_units()` for `DurationUnit`-tagged columns (separate from `Unit`-tagged columns, different target column in toxval schema)
- `toxval_mapper.R`: route duration harmonize output to `study_duration_value` and `study_duration_units`

### Q5: Media harmonization — new reference list pattern? New column tag type?

**Answer: New reference list with a `canonical` column extension. New `"Media"` tag type added to `metadata_types`.**

Reference list format differs from existing `(term, source, active)` stop-word pattern — add `canonical` column:

```r
tibble(
  term      = "freshwater fish",   # raw input variant
  canonical = "freshwater",        # target canonical value
  source    = "app_default",
  active    = TRUE
)
```

Stored as `inst/extdata/reference_cache/media_map.rds`. Loaded via `load_or_fetch_reference()` pattern (same as all other caches).

New file `R/media_harmonizer.R` with:
- `harmonize_media(values, media_map)` — returns tibble with `orig_row_id`, `raw_media`, `canonical_media`, `media_flag`
- `load_media_map(cache_dir)` — cache-or-fetch loader

Tag wiring: add `"Media"` to `metadata_types` in `classify_tags()`. This means the harmonize tab shows a media editor panel when a Media-tagged column is present, and routes through `harmonize_media()`.

The canonical media values produced by `harmonize_media()` also feed directly into the existing `media` parameter of `harmonize_units()` — this closes the loop on ppb/ppm routing, which already has `get_media_target()` logic that accepts "aqueous"/"air"/"solid".

### Q6: AMOS ontology pipeline — build-time or runtime?

**Answer: Build-time, analogous to the ECOTOX builder. NOT a runtime call.**

`ComptoxR::chemi_amos_method_pagination()` returns ~7,500 method descriptions. Calling this at runtime is not acceptable (API latency + AMOS data changes rarely). Pattern:

1. Standalone script `scripts/build_amos_media.R` calls `chemi_amos_method_pagination()`, extracts media/matrix terms from method descriptions using regex heuristics, deduplicates, writes `inst/extdata/reference_cache/amos_media.rds`.
2. The RDS is committed to the package (same as `isotope_lookup.rds`).
3. At runtime, `media_harmonizer.R` loads `amos_media.rds` via `system.file()` using the existing `load_or_fetch_reference()` pattern.
4. AMOS data supplements `media_map.rds` — the user-editable map is checked first, AMOS serves as a fallback expansion for terms not in the user map.

The AMOS extraction heuristics will require manual validation before commit — method descriptions are messy free text.

### Q7: Where does the recommendation modal live?

**Answer: In `mod_harmonize.R` — triggered before the Run Harmonization pipeline executes.**

The modal is a pre-flight summary shown when the user clicks "Run Harmonization", before the pipeline commits to full execution. It follows the existing `showModal()`/`easyClose=FALSE` pattern from `mod_file_upload.R`.

The server generates a pre-flight summary: count of unmatched units, detected date columns, media columns, duration columns. The user confirms or cancels. If they confirm, the full harmonization pipeline runs.

This does NOT live in `mod_clean_data.R`. Clean data is a separate workflow stage. The recommendation modal is scoped to the harmonization decision.

### Q8: How does curate_headless() incorporate the new steps?

**Answer: The harmonize block (Step 8b) in `curate_headless.R` is extended with Stages 3b/3c/3d.**

Current harmonize block structure (Steps 1-4):
```
Stage 1: apply_corrections()
Stage 2: parse_numeric_results()
Stage 3: harmonize_units()
Stage 4: map_to_toxval_schema()
```

v2.0 extensions:
```
Stage 1: apply_corrections()           (unchanged)
Stage 2: parse_numeric_results()        (unchanged)
Stage 3: harmonize_units()              (unchanged)
Stage 3b: harmonize_durations()         [NEW — if DurationUnit tag present]
Stage 3c: parse_dates()                 [NEW — if StudyDate tag present]
Stage 3d: harmonize_media()             [NEW — if Media tag present]
Stage 4: map_to_toxval_schema()         (signature extended for new tibbles)
```

Each new stage is conditional on the relevant tag being present in `tag_map` — same guard pattern as the existing `if (length(unit_cols) > 0)` guard already in the harmonize block.

`map_to_toxval_schema()` gains new optional parameters (`dates = NULL`, `media = NULL`) with NULL defaults for backward compatibility.

---

## New vs Modified Components

| Component | Status | File | Change Description |
|-----------|--------|------|--------------------|
| `date_parser.R` | NEW | `R/date_parser.R` | Date/study date parsing; mirrors numeric_parser.R pattern |
| `media_harmonizer.R` | NEW | `R/media_harmonizer.R` | Media classification + AMOS lookup; new canonical reference list type |
| `build_amos_media.R` | NEW | `scripts/build_amos_media.R` | Build-time AMOS ontology extraction; produces amos_media.rds |
| `media_map.rds` | NEW | `inst/extdata/reference_cache/media_map.rds` | User-editable media canonical map |
| `amos_media.rds` | NEW | `inst/extdata/reference_cache/amos_media.rds` | Build-time AMOS ontology table |
| `cleaning_pipeline.R` | MODIFY | `R/cleaning_pipeline.R` | Add dedup wrapper utility; add short-circuit checker calls; add `empty_audit_trail()` helper |
| `unit_harmonizer.R` | MODIFY | `R/unit_harmonizer.R` | Add short-circuit checkers for harmonize steps; no new dispatch logic |
| `unit_table.csv` | MODIFY | `inst/extdata/unit_table.csv` | Add ~15 duration conversion rows (hours base unit) |
| `unit_conversion.rds` | MODIFY | `inst/extdata/reference_cache/unit_conversion.rds` | Regenerate from updated unit_table.csv |
| `toxval_mapper.R` | MODIFY | `R/toxval_mapper.R` | Add optional `dates` and `media` parameters; wire to `original_year`, `media`, `study_duration_*` columns |
| `tag_helpers.R` | MODIFY | `R/tag_helpers.R` | Add `"StudyDate"` to `numeric_types`; add `"Media"` to `metadata_types` |
| `mod_harmonize.R` | MODIFY | `R/mod_harmonize.R` | Recommendation modal; media editor panel; date/duration routing in server |
| `curate_headless.R` | MODIFY | `R/curate_headless.R` | Add Stages 3b/3c/3d in harmonize block |

---

## Data Flow

### Cleaning Pipeline (v2.0 with dedup + short-circuit)

```
run_cleaning_pipeline(df, tag_map, reference_lists)
    │
    ├── inject_row_lineage(df)                      # unchanged
    │
    ├── [short-circuit] needs_unicode_cleaning?
    │     YES → ComptoxR::clean_unicode (dedup wrapped)   # Step 1
    │     NO  → pass through + empty audit
    │
    ├── [short-circuit] needs_trim?
    │     YES → clean_text_field (dedup wrapped)           # Step 2
    │     NO  → pass through + empty audit
    │
    ├── [short-circuit] has CASRN cols?
    │   ├── [dedup wrap] normalize_cas_fields               # Step 3
    │   └── rescue_cas_from_text (NOT dedup — row context) # Step 4
    │
    ├── detect_multi_cas (NOT dedup — cross-column)         # Step 5
    │
    ├── [name cols present?]
    │   ├── protect_chiral_designations (NOT dedup)         # Step 6-pre
    │   ├── [dedup wrap] strip_terminal_enclosures          # Step 6a
    │   ├── [dedup wrap] strip_quality_adjectives           # Step 6b
    │   ├── [dedup wrap] strip_salt_references              # Step 6c
    │   ├── [dedup wrap] strip_terminal_unspecified         # Step 6d
    │   ├── [dedup wrap] strip_reference_terms              # Step 6d1
    │   ├── second pass cleanup + strip_terminal_enclosures # Step 6d2-3
    │   ├── split_synonyms (NOT dedup — changes cardinality) # Step 6e
    │   ├── [dedup wrap] expand_isotope_shortcodes          # Step 7
    │   ├── flag_multi_analyte (NOT dedup)                  # Step 8
    │   └── restore_chiral_designations (NOT dedup)         # Step 9
    │
    └── list(cleaned_data, audit_trail, new_tags)
```

### Harmonization Pipeline (v2.0 with new steps)

```
[mod_harmonize.R observeEvent(run_harmonization) / curate_headless harmonize block]
    │
    ├── [NEW] Recommendation modal pre-flight check
    │     → count unmatched units, date cols, media cols, duration cols
    │     → show modal, await confirmation
    │
    ├── Stage 1: apply_corrections(result_col)               (unchanged)
    │
    ├── Stage 2: parse_numeric_results(corrected_values)     (unchanged)
    │     → parsed tibble (orig_row_id, numeric_value, qualifier, ...)
    │
    ├── Stage 3: harmonize_units(parsed, unit_col, unit_map) (unchanged)
    │     → harmonized tibble (orig_row_id, harmonized_value, harmonized_unit, ...)
    │
    ├── Stage 3b: [NEW] harmonize_durations(dur_col, unit_conversion)
    │     → duration tibble (orig_row_id, raw_duration, duration_hours, duration_unit_flag)
    │     → only runs if DurationUnit-tagged column present
    │
    ├── Stage 3c: [NEW] parse_dates(study_date_col)
    │     → dates tibble (orig_row_id, raw_date, parsed_date, date_year, date_flag)
    │     → only runs if StudyDate-tagged column present
    │
    ├── Stage 3d: [NEW] harmonize_media(media_col, media_map)
    │     → media tibble (orig_row_id, raw_media, canonical_media, media_flag)
    │     → only runs if Media-tagged column present
    │     → canonical_media fed back into harmonize_units as media context
    │
    └── Stage 4: map_to_toxval_schema(curated, harmonized, dates=, media=)
          → 56-column ToxVal tibble
          → study_duration_value/units from Stage 3b
          → original_year from Stage 3c
          → media / media_original from Stage 3d
```

### data_store Contract Extension (mod_harmonize.R)

Current contract:
```r
data_store$harmonize_results <- list(
  parsed     = <tibble from parse_numeric_results()>,
  harmonized = <tibble from harmonize_units()>,
  input_data = <data.frame>
)
```

v2.0 extension (backward compatible — new keys appended):
```r
data_store$harmonize_results <- list(
  parsed     = <tibble from parse_numeric_results()>,
  harmonized = <tibble from harmonize_units()>,
  durations  = <tibble from harmonize_durations()> | NULL,   # NEW
  dates      = <tibble from parse_dates()>          | NULL,  # NEW
  media      = <tibble from harmonize_media()>      | NULL,  # NEW
  input_data = <data.frame>
)
```

---

## Build Order (Dependency-Aware)

Build in this order to avoid integration blockers:

**1. Dedup wrapper + short-circuit checkers** (`cleaning_pipeline.R` only)
- Pure performance infrastructure; no new files; no new tag types
- Add `dedup_step()` private helper and `empty_audit_trail()` helper
- Add short-circuit checker predicates and conditional guards in `run_cleaning_pipeline()`
- Tests: dedup output matches non-dedup output for all step functions; short-circuit returns same result as full run on clean data

**2. Performance benchmark harness** (`scripts/bench_pipeline.R`)
- Standalone script using `microbenchmark` or `bench` on a synthetic 100K-row dataset
- Validates speedup before committing to the pattern
- Document the before/after numbers

**3. Duration conversion**
- Add ~15 rows to `unit_table.csv`, regenerate `unit_conversion.rds`
- Add routing branch for `DurationUnit` columns in `mod_harmonize.R` and `curate_headless.R`
- Add duration rows to `toxval_mapper.R` (`study_duration_value`, `study_duration_units`)
- Lowest risk change — reuses `harmonize_units()` entirely unchanged

**4. Date parser** (`R/date_parser.R`)
- New file; no existing code changes except wiring
- Add `"StudyDate"` to `numeric_types` in `tag_helpers.R` (one line)
- Wire into `mod_harmonize.R` server and `curate_headless.R` harmonize block
- Wire `date_year` into `toxval_mapper.R` `original_year` column

**5. Media harmonizer** (`R/media_harmonizer.R` + `media_map.rds`)
- New file + new reference list
- Add `"Media"` to `metadata_types` in `classify_tags()` (one line)
- Wire into `mod_harmonize.R` (editor panel + Stage 3d call)
- Wire canonical_media back into harmonize_units `media` parameter
- Wire into `curate_headless.R` harmonize block Stage 3d

**6. AMOS build script** (`scripts/build_amos_media.R`)
- Standalone; no app code depends on it until `amos_media.rds` is committed
- Build, validate extracted terms manually, commit RDS
- `media_harmonizer.R` automatically falls back to it via `system.file()`

**7. ToxVal schema wiring** (`toxval_mapper.R`)
- Add optional `dates` and `media` parameters
- Add NULL guards — backward compatible with callers passing neither
- Route new tibbles to the appropriate columns

**8. Recommendation modal** (`mod_harmonize.R`)
- Final Shiny touch after all pipeline steps proven
- Pre-flight summary reads from column tag counts, not from running the pipeline
- Modal blocks execution until user confirms

---

## Component Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| Dedup wrapper ↔ step functions | Wrapper calls step fn with sliced single-column df; rebuilds audit trail with parent row_ids | Step function signatures unchanged |
| Short-circuit checkers ↔ orchestrators | Predicate called in orchestrator before step fn; returns logical | One checker per step, same file as step |
| `parse_dates()` ↔ `mod_harmonize.R` | Called in server reactive, result stored in `data_store$harmonize_results$dates` | Same pattern as `parse_numeric_results()` |
| `harmonize_media()` ↔ reference cache | Loads `media_map.rds` via `system.file()`; falls back to `amos_media.rds` | `load_or_fetch_reference()` pattern |
| `harmonize_media()` canonical output ↔ `harmonize_units()` | canonical_media passed as `media` parameter to Stage 3 | Closes ppb/ppm routing loop |
| AMOS build script ↔ ComptoxR | One-time API call during package development | Not called at runtime |
| Recommendation modal ↔ run_harmonization | `observeEvent(run_harmonization)` shows modal; modal confirm button triggers pipeline | In `mod_harmonize.R` only |
| `toxval_mapper.R` ↔ new step tibbles | New optional parameters: `dates = NULL`, `media = NULL` | NULL-safe guards preserve backward compat |

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Dedup Inside Step Functions

**What people do:** Modify each step function to deduplicate internally before processing.
**Why it's wrong:** Pollutes step function contracts; audit trail row_ids from a deduplicated slice no longer correspond to parent df; doubles test surface area; breaks any step that does rely on full-df context.
**Do this instead:** Keep step functions unchanged. Apply dedup as a wrapper layer in `run_cleaning_pipeline()` only.

### Anti-Pattern 2: Separate Duration Harmonization File

**What people do:** Create `R/duration_harmonizer.R` with its own dispatch logic.
**Why it's wrong:** Duration conversion is just more rows in the conversion table. A separate file implies a parallel code path that duplicates `harmonize_units()` logic and must be maintained separately.
**Do this instead:** Add duration unit rows to `unit_conversion.rds` and route `DurationUnit`-tagged columns through `harmonize_units()`.

### Anti-Pattern 3: Runtime AMOS Pagination

**What people do:** Call `ComptoxR::chemi_amos_method_pagination()` at app startup or when media harmonization runs.
**Why it's wrong:** ~7,500 API calls at runtime is unacceptable latency. AMOS data changes rarely.
**Do this instead:** Build-time script writes `amos_media.rds`; app loads from cache via `system.file()`.

### Anti-Pattern 4: Date Parsing in the Cleaning Pipeline

**What people do:** Add a date parsing step to `run_cleaning_pipeline()`.
**Why it's wrong:** The cleaning pipeline operates before tagging — it does not know which column is `StudyDate`. Date interpretation requires the user to have tagged a column. Date parsing belongs in the harmonization layer.
**Do this instead:** `parse_dates()` is called in `mod_harmonize.R` and `curate_headless()` harmonize block, after the tag map is applied.

### Anti-Pattern 5: Media as Metadata Only (No Harmonization Feedback)

**What people do:** Add Media to `metadata_types`, show the raw media column in the UI, and stop there.
**Why it's wrong:** `harmonize_units()` already has `get_media_target()` logic that routes ppb/ppm based on "aqueous"/"air"/"solid" — but only when canonical values are passed. Without media harmonization producing canonical values, ppb/ppm routing stays on the aqueous default for all rows.
**Do this instead:** Wire `canonical_media` from Stage 3d back into the `media` parameter of Stage 3 `harmonize_units()`. The two features are load-bearing for each other.

### Anti-Pattern 6: short-circuit via NULL return from step functions

**What people do:** Modify step functions to return NULL when nothing to do, and add NULL checks in the orchestrator.
**Why it's wrong:** NULL vs list() is a type contract violation; callers of step functions (tests, headless, Shiny) must all handle the new return type.
**Do this instead:** Keep step functions returning `list(cleaned_data, audit_trail)` always. Short-circuit logic is in the orchestrator only, skipping the step function call entirely.

---

## Scaling Considerations

| Scale | Architecture |
|-------|-------------|
| 10K rows | Dedup wrapper provides ~3-5x speedup for repeated-value columns; short-circuit provides ~40% reduction for already-clean data |
| 100K rows | Both optimizations essential; benchmark harness validates targets |
| 1M rows | Would require chunked processing or parallel step execution; out of scope for v2.0 |

**First bottleneck (v2.0 target):** Repeated identical string values processed N times when distinct strings are far fewer — solved by dedup wrapper.
**Second bottleneck (v2.0 target):** Steps running at full O(n) when 100% of values are already clean — solved by short-circuit checkers.
**Third bottleneck (future):** `split_synonyms()` and `rescue_cas_from_text()` have row-context dependencies that prevent dedup; will need column-level result caching if 100K+ rows with heavy synonym splitting emerge regularly.

---

## Sources

- Direct source reading: `R/cleaning_pipeline.R` — `run_cleaning_pipeline()`, step function contracts, `build_audit_trail()`, pre-allocated vector pattern
- Direct source reading: `R/unit_harmonizer.R` — `harmonize_units()`, `apply_synonyms()`, `get_media_target()`, molarity routing
- Direct source reading: `R/numeric_parser.R` — `parse_numeric_results()` return shape and flag vocabulary
- Direct source reading: `R/curate_headless.R` — harmonize block Stage 1-4 structure, conditional guards
- Direct source reading: `R/tag_helpers.R` — `classify_tags()`, `numeric_types`, `metadata_types` membership vectors
- Direct source reading: `R/toxval_mapper.R` — `study_duration_*`, `media`, `original_year` column slots
- Direct source reading: `R/mod_harmonize.R` — `data_store$harmonize_results` contract, editor panel pattern, chip editor CSS/JS
- Direct source reading: `R/cleaning_reference.R` — `load_or_fetch_reference()` cache-or-fetch pattern, `(term, source, active)` tibble format
- Direct source reading: `inst/extdata/reference_cache/` — existing RDS inventory confirming no media_map.rds yet
- Direct source reading: `.planning/PROJECT.md` — v2.0 milestone goals, tech debt, constraints, key decisions

---

*Architecture research for: CONCERT v2.0 Pipeline Performance & Date/Media Harmonization*
*Researched: 2026-04-24*
*Confidence: HIGH — based on direct code inspection of all relevant source files*
