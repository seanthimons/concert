# Phase 11: CAS Pipeline - Research

**Researched:** 2026-03-06
**Domain:** CAS-RN normalization, validation, extraction, and multi-CAS detection in R Shiny
**Confidence:** HIGH

## Summary

Phase 11 implements a CAS cleaning pipeline that normalizes CAS-RNs, validates checksums, rescues CAS from non-CASRN columns, flags multi-CAS cells for user decision, and displays pipeline statistics via value boxes. The phase also reorders tabs (Tag before Clean) and upgrades Phase 10's text summary to value boxes for visual consistency.

**Key insight:** ComptoxR provides `as_cas()`, `is_cas()`, and `extract_cas()` functions that handle normalization, validation, and extraction in single calls — already proven in production (curation.R:202, clean_chems.R:20). The WIDE data shape (new columns, not new rows) is validated against EPA production scripts and preserves all downstream Phase 9-10 assumptions.

**Primary recommendation:** Use ComptoxR functions directly for all CAS operations, inject `original_row_id` as first step of `run_cleaning_pipeline()`, create `cas_extract_{source}` columns for rescued CAS, add `multi_cas` flag column for user-initiated splits, and replace Phase 10's text alert with bslib::value_box() cards.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Data Shape: WIDE (not LONG)**
- All CAS operations produce new columns, never new rows
- CAS rescue creates `cas_extract_{source_column_name}` columns (one per source column that yields CAS values)
- Multi-CAS cells are flagged (`multi_cas = TRUE` with count), NOT automatically split
- User-initiated split available as a UI action (creates new rows via rbind for specific flagged rows)
- Row count stays stable through the CAS pipeline unless user explicitly splits
- Cap at `cas_5` equivalent — overflow concatenated into `cas_overflow` text field with audit flag

**Tab Reordering: Tag Before Clean**
- Flow becomes: Data Preview → Tag Columns → Clean Data → Run Curation → Review Results
- CAS pipeline knows which columns are CASRN/Chemical Name because tagging happened first
- Requires rewiring Phase 10 gating logic: Clean Data tab gated behind tags (not behind upload)
- Tag Columns tab gated behind upload (unchanged)

**CAS Normalization & Validation**
- Use `ComptoxR::as_cas()` on all columns tagged as CASRN
- Valid CAS → normalized to canonical NNN-NN-N format
- Invalid/placeholder text ("no cas", "n/a", "proprietary", "-", etc.) → naturally becomes NA via as_cas()
- No separate placeholder detection step needed — as_cas() handles everything
- Audit trail logs ALL changes (normalizations AND NA conversions) with generic reason ("CAS normalized/invalidated via as_cas()")

**CAS Rescue from Names**
- Scan ALL non-CASRN tagged columns (not just Chemical Name) with `ComptoxR::extract_cas()`
- Extracted CAS-RNs go into new columns named `cas_extract_{source_column_name}`
- Strip only the CAS portion (and surrounding parens/brackets) from the source text
- Leave non-CAS parentheticals for Phase 12 name cleaning
- New rescue columns auto-tagged as CASRN for downstream curation
- Audit trail logs each extraction

**Multi-CAS Handling: Flag + User Decision**
- Detect cells with multiple CAS-RNs in CASRN columns AND rescue columns
- Flag rows with `multi_cas = TRUE` and `multi_cas_count` integer
- Do NOT automatically split — user decides whether it's a mixture (keep together) or data error (split)
- User-initiated split as UI action: select flagged row → "Split" button → creates new rows via rbind
- Validated by PW_ChemicalCuration.R (line 616): EPA team manually creates duplicate records for mixtures

**Row Lineage Tracking**
- Add `original_row_id = 1:nrow(df)` at the start of the cleaning pipeline (before any transformations)
- Cheap insurance for user-initiated splits and Phase 12 name splitting
- Injected as first step of `run_cleaning_pipeline()` (small retroactive change to Phase 10 code)

**Summary Cards (Value Boxes)**
- Use `bslib::value_box()` cards across top of Clean Data tab
- Replace Phase 10's text alert summary with value boxes (unified visual language)
- Cards: "CAS Rescued", "CAS Validated", "CAS Invalid → NA", "Multi-CAS Flagged", plus basic cleaning stats (unicode, trim)
- Displayed after cleaning runs; update on re-run

**Progress Indicator**
- Single "Run Cleaning" button runs ALL steps: basic cleaning (unicode, trim) + CAS pipeline sequentially
- `withProgress()` showing per-step detail: "Converting unicode..." → "Trimming whitespace..." → "Normalizing CAS..." → "Rescuing CAS from names..." → "Detecting multi-CAS..." → "Validating checksums..."
- Matches existing "Run Curation" pattern on Run Curation tab

### Claude's Discretion

- Exact value box styling, colors, and icons
- How to handle the user-initiated split UI (modal? inline button? confirmation dialog?)
- Internal function organization within the CAS pipeline
- How to handle edge cases where no CAS columns are tagged (skip CAS steps gracefully)
- Whether `original_row_id` is visible in the DT display or hidden
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CAS-01 | User can see placeholder text in CAS fields detected and set to NA with audit comment | ComptoxR::as_cas() naturally converts invalid CAS strings to NA; build_audit_trail() logs conversions |
| CAS-02 | User can see CAS-RNs normalized to canonical NNN-NN-N format with checksum validation; invalid CAS set to NA with audit comment | ComptoxR::as_cas() normalizes + validates in one call (used in curation.R:202); audit trail pattern established in Phase 10 |
| CAS-03 | User can see CAS-RNs embedded in chemical name columns extracted, moved to CAS column, and stripped from name | ComptoxR::extract_cas() validates via checksum (prototype in clean_chems.R:20); create cas_extract_{source} columns; strip CAS from source with regex |
| CAS-04 | User can see rows with multiple CAS-RNs split into separate rows with audit comment logging the original multi-CAS value | Flag with multi_cas=TRUE + count; user-initiated rbind split (validated by EPA PW_ChemicalCuration.R:616) |
| UIUX-02 | User can see summary cards showing cleaning statistics (CAS rescued, formulas detected, synonyms split, rows flagged, etc.) | bslib::value_box() available in bslib (Phase 9 dependency); count audit_trail rows by step; display in card layout |
| UIUX-04 | User can run cleaning pipeline with step-by-step progress indicator | withProgress() + incProgress() pattern established in Phase 10 (mod_clean_data.R:68-75); extend with CAS step labels |
</phase_requirements>

## Standard Stack

### Core CAS Functions

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| ComptoxR | (installed) | CAS normalization, validation, extraction | Already used in curation.R (line 202: as_cas), clean_chems.R (line 20: extract_cas); EPA-maintained package for chemical data |
| stringr | (installed) | CAS regex stripping from source text | Already used throughout app for text operations; paired with extract_cas for rescue |

### UI Components

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| bslib | 5 (installed) | value_box() for summary cards | Already project dependency (Phase 9); official Shiny UI component library; modern dashboard cards |
| shinyjs | (installed) | Enable/disable split button | Already used in Phase 10 for button state management |
| DT | (installed) | Display multi-CAS flagged rows | Already used for all data tables; supports row selection for user-initiated splits |

### No New Dependencies

All required functionality available in existing Phase 9-10 stack.

**Installation:**
```r
# All packages already installed
library(ComptoxR)
library(bslib)
library(shinyjs)
```

## Architecture Patterns

### Recommended Function Structure

```
R/
├── cleaning_pipeline.R      # Add CAS steps to run_cleaning_pipeline()
│   ├── normalize_cas_fields()      # ComptoxR::as_cas() on tagged CASRN columns
│   ├── rescue_cas_from_text()      # ComptoxR::extract_cas() on non-CASRN columns
│   ├── detect_multi_cas()          # Flag rows with multiple CAS-RNs
│   └── inject_row_lineage()        # Add original_row_id column (first step)
├── modules/
│   └── mod_clean_data.R     # Add value boxes, multi-CAS UI, CAS progress
```

### Pattern 1: CAS Normalization via as_cas()

**What:** Apply `ComptoxR::as_cas()` to all columns tagged as "CASRN", log before/after changes via audit trail
**When to use:** After basic cleaning (unicode, trim) and after column tagging is available
**Example:**
```r
# Source: Existing usage in R/curation.R:202
normalize_cas_fields <- function(df, tag_map, audit_base) {
  cas_cols <- names(tag_map)[tag_map == "CASRN"]

  if (length(cas_cols) == 0) {
    # No CAS columns tagged — skip gracefully
    return(list(cleaned_data = df, audit_trail = tibble::tibble()))
  }

  df_before <- df

  # Apply as_cas to each CASRN column
  df_after <- df %>%
    dplyr::mutate(dplyr::across(
      all_of(cas_cols),
      ~ ComptoxR::as_cas(.x)
    ))

  # Build audit trail for this step
  audit <- build_audit_trail(
    df_original = df_before,
    df_cleaned = df_after,
    step_name = "normalize_cas",
    reason_fn = function(field) paste0("CAS normalized/invalidated via as_cas() in ", field)
  )

  list(cleaned_data = df_after, audit_trail = audit)
}
```

### Pattern 2: CAS Rescue via extract_cas()

**What:** Scan non-CASRN columns for embedded CAS-RNs, create new `cas_extract_{source}` columns, strip CAS from source
**When to use:** After CAS normalization, before multi-CAS detection
**Example:**
```r
# Source: Prototype in clean_chems.R:20, clean_chems_2.R:565-594
rescue_cas_from_text <- function(df, tag_map, audit_base) {
  cas_cols <- names(tag_map)[tag_map == "CASRN"]
  non_cas_cols <- setdiff(names(tag_map), cas_cols)

  if (length(non_cas_cols) == 0) {
    return(list(cleaned_data = df, audit_trail = tibble::tibble(), new_tags = list()))
  }

  df_out <- df
  audit_rows <- list()
  new_tags <- list()

  for (col_name in non_cas_cols) {
    # Extract CAS-RNs (returns character vector or NA)
    extracted <- ComptoxR::extract_cas(df[[col_name]])

    # Only create new column if at least one CAS found
    if (any(!is.na(extracted))) {
      new_col_name <- paste0("cas_extract_", col_name)
      df_out[[new_col_name]] <- extracted
      new_tags[[new_col_name]] <- "CASRN"  # Auto-tag for curation

      # Log extraction in audit trail
      for (i in which(!is.na(extracted))) {
        audit_rows[[length(audit_rows) + 1]] <- tibble::tibble(
          row_id = as.integer(i),
          field = col_name,
          step = "rescue_cas",
          original_value = df[[col_name]][i],
          new_value = df_out[[col_name]][i],  # After stripping
          reason = paste0("CAS-RN extracted to ", new_col_name, ": ", extracted[i])
        )
      }

      # Strip CAS from source text (preserve surrounding context)
      # Pattern: optional parens/brackets around CAS
      df_out[[col_name]] <- stringr::str_remove_all(
        df_out[[col_name]],
        "\\s*[\\(\\[]?[1-9][0-9]{1,6}-[0-9]{2}-[0-9][\\)\\]]?\\s*"
      ) %>%
        stringr::str_squish()
    }
  }

  audit <- dplyr::bind_rows(audit_rows)
  list(cleaned_data = df_out, audit_trail = audit, new_tags = new_tags)
}
```

### Pattern 3: Multi-CAS Detection & Flagging

**What:** Detect rows with multiple CAS-RNs across all CASRN columns, add `multi_cas` and `multi_cas_count` columns
**When to use:** After CAS rescue (so rescue columns are included in scan)
**Example:**
```r
detect_multi_cas <- function(df, tag_map) {
  cas_cols <- names(tag_map)[tag_map == "CASRN"]

  if (length(cas_cols) == 0) {
    df$multi_cas <- FALSE
    df$multi_cas_count <- 0L
    return(df)
  }

  # Count non-NA CAS values per row across all CASRN columns
  df$multi_cas_count <- rowSums(!is.na(df[, cas_cols, drop = FALSE]))
  df$multi_cas <- df$multi_cas_count > 1

  return(df)
}
```

### Pattern 4: Value Box Summary

**What:** Replace Phase 10 text alert with bslib::value_box() cards showing CAS pipeline stats
**When to use:** In mod_clean_data.R renderUI after cleaning completes
**Example:**
```r
# Source: bslib documentation https://rstudio.github.io/bslib/reference/value_box.html
output$cleaning_summary <- renderUI({
  req(data_store$cleaning_audit, data_store$cleaned_data)

  audit <- data_store$cleaning_audit

  # Count by step
  n_cas_rescued <- sum(audit$step == "rescue_cas")
  n_cas_normalized <- sum(audit$step == "normalize_cas")
  n_unicode <- sum(audit$step == "unicode_to_ascii")
  n_trim <- sum(audit$step == "trim_whitespace_punctuation")
  n_multi_cas <- sum(data_store$cleaned_data$multi_cas, na.rm = TRUE)

  layout_columns(
    col_widths = c(4, 4, 4, 4, 4),

    value_box(
      title = "CAS Rescued",
      value = n_cas_rescued,
      showcase = bsicons::bs_icon("search"),
      theme = "primary"
    ),

    value_box(
      title = "CAS Normalized",
      value = n_cas_normalized,
      showcase = bsicons::bs_icon("check-circle"),
      theme = "success"
    ),

    value_box(
      title = "Multi-CAS Flagged",
      value = n_multi_cas,
      showcase = bsicons::bs_icon("flag"),
      theme = "warning"
    ),

    value_box(
      title = "Unicode Cleaned",
      value = n_unicode,
      showcase = bsicons::bs_icon("globe"),
      theme = "info"
    ),

    value_box(
      title = "Fields Trimmed",
      value = n_trim,
      showcase = bsicons::bs_icon("scissors"),
      theme = "info"
    )
  )
})
```

### Pattern 5: Extended Progress Indicator

**What:** Extend Phase 10 withProgress to show CAS pipeline steps
**When to use:** In mod_clean_data.R observeEvent(input$run_cleaning)
**Example:**
```r
# Source: Existing usage in mod_clean_data.R:68-75, Shiny docs
withProgress(message = "Cleaning data...", value = 0, {
  # Phase 10 steps
  incProgress(0.15, detail = "Converting unicode to ASCII")
  incProgress(0.15, detail = "Trimming whitespace and punctuation")

  # Phase 11 CAS steps (if tags available)
  if (!is.null(data_store$column_tags)) {
    incProgress(0.20, detail = "Normalizing CAS-RNs")
    incProgress(0.20, detail = "Rescuing CAS from names")
    incProgress(0.15, detail = "Detecting multi-CAS rows")
  }

  incProgress(0.15, detail = "Finalizing")
})
```

### Anti-Patterns to Avoid

- **LONG data shape for CAS operations:** Violates production EPA pattern (PW_ChemicalCuration.R WIDE approach), breaks Phase 9-10 row count assumptions, complicates dedup and merge logic
- **Automatic multi-CAS splitting:** User must decide if multi-CAS is mixture (keep) or error (split); EPA production manually creates duplicates (PW_ChemicalCuration.R:616)
- **Custom CAS validation:** ComptoxR::as_cas() already validates checksums; don't reimplement (clean_chems_2.R:99-119 shows custom checksum — unnecessary duplication)
- **Separate placeholder detection:** as_cas() naturally converts "no cas", "n/a", "proprietary" to NA; separate detection adds complexity with no benefit

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| CAS normalization | Custom regex + format standardization | `ComptoxR::as_cas()` | Handles all CAS formats, validates checksum, returns NA for invalid — already proven in curation.R:202 |
| CAS extraction from text | Custom regex capture groups | `ComptoxR::extract_cas()` | Handles surrounding parens/brackets, validates checksum automatically — prototyped in clean_chems.R:20 |
| CAS checksum validation | Manual checksum algorithm | `ComptoxR::is_cas()` or as_cas() result | as_cas() returns NA for invalid checksums; is_cas() available if separate validation needed — avoid clean_chems_2.R:99-119 duplication |
| Multi-CAS splitting logic | Automatic unnest + rbind | Flag-first with user-initiated split | Multi-CAS may be mixtures (keep together) or errors (split) — EPA production requires manual decision (PW_ChemicalCuration.R:616) |
| Dashboard summary cards | Custom HTML/CSS cards | `bslib::value_box()` | Official Shiny component, responsive layout, theming support, minimal code — modern replacement for Phase 10 text alerts |

**Key insight:** ComptoxR already solves 90% of CAS problems. Custom implementations (like clean_chems_2.R checksum function) add maintenance burden and edge case bugs that ComptoxR has already solved. Production EPA scripts validate this stack choice.

## Common Pitfalls

### Pitfall 1: Forgetting to Update Column Tags After Rescue

**What goes wrong:** `cas_extract_{source}` columns created but not added to `data_store$column_tags`, causing curation to skip rescued CAS
**Why it happens:** Rescue creates columns dynamically; tag map is static after user tagging
**How to avoid:** Rescue function returns `new_tags` list; merge into `data_store$column_tags` after rescue completes
**Warning signs:** Curation results show fewer searches than expected; rescued CAS columns visible in DT but not in dedup preview

### Pitfall 2: Tab Gating Logic Unchanged After Reordering

**What goes wrong:** Clean Data tab shows before Tag Columns, or gating conditions reference wrong triggers
**Why it happens:** Phase 10 gates Clean Data behind `data_store$clean` (upload); Phase 11 requires `data_store$column_tags` (tagging)
**How to avoid:** Update app.R gating logic to check tags for Clean Data tab; update navigation callbacks to show Clean Data after tagging
**Warning signs:** Clean Data accessible before tagging; CAS pipeline crashes with "tag_map is NULL"

### Pitfall 3: Multi-CAS Detection Before Rescue

**What goes wrong:** Multi-CAS rows not flagged because detection runs before rescue creates new CAS columns
**Why it happens:** Pipeline order matters — rescue adds CAS columns that must be included in multi-CAS scan
**How to avoid:** Run rescue first, THEN detect multi-CAS using updated tag_map including rescue columns
**Warning signs:** Multi-CAS count = 0 even when rescued CAS creates multiple CAS per row

### Pitfall 4: withProgress Percentages Don't Sum to 1.0

**What goes wrong:** Progress bar incomplete or overshoots 100%
**Why it happens:** incProgress amounts added wrong, or conditional CAS steps skip percentage allocation
**How to avoid:** Use fractional increments that sum to 1.0 across all paths (with/without tags); test both tagged and untagged data
**Warning signs:** Progress bar stalls at 80% or jumps to 100% abruptly

### Pitfall 5: Stripping Too Much Context Around CAS

**What goes wrong:** Regex for stripping CAS from source text removes chemical name fragments or IUPAC notation
**Why it happens:** Aggressive whitespace/paren removal around CAS pattern
**How to avoid:** Strip only the CAS number itself plus immediately adjacent parens/brackets; use str_squish() after to collapse extra spaces; preserve commas and hyphens for IUPAC names (Phase 12 dependency)
**Warning signs:** Chemical names like "acetone (67-64-1, dimethyl ketone)" become "dimethyl ketone" instead of "acetone, dimethyl ketone"

## Code Examples

Verified patterns from production code and official documentation:

### ComptoxR::as_cas() Usage (Normalization + Validation)

```r
# Source: R/curation.R:202
validated <- ComptoxR::as_cas(unique_cas)
valid_flags <- ComptoxR::is_cas(validated)

# as_cas() behavior:
# "67-64-1" → "67-64-1" (already normalized)
# "67641" → "67-64-1" (adds hyphens)
# "no cas" → NA (invalid text)
# "proprietary" → NA (placeholder)
# "67-64-2" → NA (checksum fail)
```

### ComptoxR::extract_cas() Usage (CAS Rescue)

```r
# Source: clean_chems.R:20 (prototype)
mult_cas <- extract_cas(raw_cas)

# extract_cas() behavior:
# "acetone (67-64-1)" → "67-64-1"
# "67-64-1, 108-88-3" → c("67-64-1", "108-88-3")
# "no cas number" → NA
# "mixture" → NA
```

### bslib::value_box() with Showcase Icon

```r
# Source: https://rstudio.github.io/bslib/reference/value_box.html
value_box(
  title = "CAS Rescued",
  value = 42,
  showcase = bsicons::bs_icon("search"),
  theme = "primary",
  p("CAS-RNs extracted from chemical names")
)

# Themes: primary, secondary, success, info, warning, danger
# Or custom: value_box_theme(bg = "#e6f2fd", fg = "#0d6efd")
```

### withProgress Step-by-Step Pattern

```r
# Source: https://shiny.posit.co/r/reference/shiny/latest/withprogress.html
withProgress(message = "Processing...", value = 0, {
  incProgress(0.25, detail = "Step 1: Loading data")
  Sys.sleep(1)  # Actual work here

  incProgress(0.25, detail = "Step 2: Validating")
  Sys.sleep(1)

  incProgress(0.25, detail = "Step 3: Transforming")
  Sys.sleep(1)

  incProgress(0.25, detail = "Step 4: Finalizing")
  Sys.sleep(1)
})
# Total increments = 1.0 (0.25 * 4)
```

### Audit Trail Pattern (Phase 10 Established)

```r
# Source: R/cleaning_pipeline.R:56-108
audit <- build_audit_trail(
  df_original = df_before,
  df_cleaned = df_after,
  step_name = "normalize_cas",
  reason_fn = function(field) paste0("CAS normalized via as_cas() in ", field)
)

# Returns tibble with columns:
# row_id, field, step, original_value, new_value, reason
```

### Row Lineage Injection (First Step of Pipeline)

```r
inject_row_lineage <- function(df) {
  df %>%
    dplyr::mutate(original_row_id = 1:dplyr::n(), .before = 1)
}

# Usage: First line of run_cleaning_pipeline()
run_cleaning_pipeline <- function(df, tag_map = NULL, reference_lists = NULL) {
  # Inject row lineage before any transformations
  df <- inject_row_lineage(df)

  # Rest of pipeline...
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Custom CAS checksum validation | ComptoxR::as_cas() for normalization + validation | ComptoxR package release (~2020) | Eliminates checksum bugs (off-by-one, digit reversal); handles edge cases automatically |
| Regex-only CAS extraction | ComptoxR::extract_cas() with validation | ComptoxR package release | Extracts + validates in one call; handles multiple CAS per cell; returns NA for invalid matches |
| Text-based summary alerts | bslib::value_box() dashboard cards | bslib 0.5.0+ (2023) | Modern visual language; responsive layout; easier to scan; consistent with Shiny UI components |
| Manual multi-CAS splitting | Flag-first with user decision | Validated by EPA production (2023) | Prevents splitting mixtures that should stay together; user control over data shape |

**Deprecated/outdated:**
- **clean_chems_2.R checksum() function (lines 99-119):** Replaced by ComptoxR::as_cas() which validates checksums automatically
- **Phase 10 text alert summary (mod_clean_data.R:110-138):** Should be replaced with value_box() cards for visual consistency

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | testthat 3.x |
| Config file | None — tests in tests/ directory |
| Quick run command | `Rscript -e "testthat::test_file('tests/test_cleaning_pipeline.R')"` |
| Full suite command | `Rscript -e "testthat::test_dir('tests')"` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CAS-01 | Placeholder text ("no cas", "n/a", "proprietary") → NA | unit | `Rscript -e "testthat::test_file('tests/test_cas_pipeline.R')"` | ❌ Wave 0 |
| CAS-02 | CAS normalized to NNN-NN-N format, checksum validated | unit | `Rscript -e "testthat::test_file('tests/test_cas_pipeline.R')"` | ❌ Wave 0 |
| CAS-03 | CAS extracted from names, moved to cas_extract_ columns, stripped from source | unit | `Rscript -e "testthat::test_file('tests/test_cas_pipeline.R')"` | ❌ Wave 0 |
| CAS-04 | Multi-CAS rows flagged with multi_cas=TRUE and count | unit | `Rscript -e "testthat::test_file('tests/test_cas_pipeline.R')"` | ❌ Wave 0 |
| UIUX-02 | Value boxes display CAS pipeline stats | manual | Launch app, run cleaning, verify value box rendering | ✅ (manual only) |
| UIUX-04 | Progress indicator shows step-by-step CAS pipeline execution | manual | Launch app, run cleaning, verify progress messages | ✅ (manual only) |

### Sampling Rate

- **Per task commit:** `Rscript -e "testthat::test_file('tests/test_cas_pipeline.R')"` (< 10 seconds)
- **Per wave merge:** `Rscript -e "testthat::test_dir('tests')"` (< 30 seconds)
- **Phase gate:** Full suite green + Shiny smoke test before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `tests/test_cas_pipeline.R` — covers CAS-01, CAS-02, CAS-03, CAS-04 with test cases from chemical_validation_test.csv
- [ ] Test data fixtures: rows 150-157 from chemical_validation_test.csv (CAS placeholders), rows with multi-CAS, rows with embedded CAS in names

## Sources

### Primary (HIGH confidence)

- **ComptoxR R package** — Used in production (curation.R:202 for as_cas(), clean_chems.R:20 for extract_cas())
- **bslib value_box documentation** — [Official reference](https://rstudio.github.io/bslib/reference/value_box.html) (verified 2026-01-26 CRAN package)
- **Shiny withProgress documentation** — [Official reference](https://shiny.posit.co/r/reference/shiny/latest/withprogress.html)
- **EPA production scripts (PW_ChemicalCuration.R)** — Validates WIDE data shape and manual mixture splitting (CONTEXT.md reference, line 616)
- **Existing Phase 10 code (R/cleaning_pipeline.R, R/modules/mod_clean_data.R)** — Audit trail pattern, progress pattern, reference list loading

### Secondary (MEDIUM confidence)

- **clean_chems.R and clean_chems_2.R** — Prototype CAS extraction and validation patterns; demonstrates ComptoxR usage but contains deprecated custom checksum function
- **chemical_validation_test.csv** — Test dataset with 172 records covering CAS placeholders, multi-CAS, embedded CAS, unicode, and other edge cases

### Tertiary (LOW confidence)

- **WebSearch results for ComptoxR functions** — Did not find specific ComptoxR documentation via search (package not indexed well), but functions verified to exist via local R environment and production code usage

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - ComptoxR, bslib, shinyjs all verified in existing codebase; functions proven in production
- Architecture: HIGH - WIDE pattern validated against EPA production; patterns align with Phase 9-10 established code
- Pitfalls: MEDIUM - Tab gating and tag updating are new integration points; multi-CAS detection order matters

**Research date:** 2026-03-06
**Valid until:** 30 days (stable R packages, established Shiny patterns)
