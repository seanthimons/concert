# Phase 15: Post-Curation QC - Research

**Researched:** 2026-03-09
**Domain:** Data Quality Validation, Unicode Handling, R Shiny QC Integration
**Confidence:** HIGH

## Summary

Phase 15 implements post-curation QC checks for remaining non-ASCII characters in curated chemical data. The implementation has two main components: (1) replacing the existing custom `clean_unicode_field()` function with ComptoxR's chemistry-specific `clean_unicode()` throughout the pre-curation pipeline, and (2) adding QC checks after curation that flag (but don't modify) remaining non-ASCII characters.

The key insight is that POST-01 (CAS re-validation) is already satisfied by the existing pipeline — ComptoxR::as_cas() validates during pre-curation, and CompTox API returns are server-side validated. Phase 15 focuses entirely on unicode QC.

**Primary recommendation:** Replace custom unicode cleaning with ComptoxR::clean_unicode() in pre-curation pipeline, then add post-curation QC layer that flags remaining non-ASCII using the same function in validation mode.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**CAS Re-Validation: Not Needed**
- POST-01 is already satisfied by the existing pipeline: pre-curation CAS cleaning (Phase 11) validates user-uploaded CAS values, and CompTox API returns are authoritative (server-side validated, never ships invalid CAS-RNs)
- No post-curation CAS re-validation step needed
- Mark POST-01 as covered by existing Phases 11 + curation pipeline

**Unicode Function Swap**
- Replace custom `clean_unicode_field()` (stringi transliteration) with `ComptoxR::clean_unicode()` throughout the pre-curation pipeline
- ComptoxR's function is chemistry-specific: Greek letters become `.alpha.`, `.beta.` notation (not `a`, `b`); trademark/registered/copyright symbols are removed (not expanded to `(TM)`, `(R)`, `(C)`)
- ComptoxR has 157 mapped entries in its unicode_map, purpose-built for chemical data
- This affects both `R/cleaning_pipeline.R` and `R/modules/mod_clean_data.R` where `clean_unicode_field()` is currently called

**Post-Curation QC Check**
- After curation completes, run `ComptoxR::clean_unicode()` on the final curated output as a QC pass
- Flag only — do not modify post-curation data; user sees what remains and decides
- Surface `ComptoxR:::check_unhandled()` warnings: specific unmapped characters shown to user (not just console output)

**QC Trigger & Timing**
- QC runs automatically when curation completes (no extra user action)
- "Re-run QC" button available next to the export button for after manual resolutions
- Re-run only on explicit button click (not after every resolution change)
- QC is advisory only — does not gate the export button; user can export with QC warnings present (matches existing pattern where needs_review rows can be exported)

**Results Display: Three Layers**
1. **Value boxes** at top of Review Results alongside existing consensus stats:
   - "X rows with non-ASCII" value box
   - "Y unhandled characters" value box (from check_unhandled)
2. **Inline DT flags** on affected rows using WARN style (yellow), labeled `QC: non-ASCII` — consistent with Phase 13 warning flag pattern
3. **QC summary card** above the export button:
   - Lists specific unhandled characters with unicode codepoint and row count (e.g., "U+27E8 found in 3 rows")
   - Actionable detail so user knows exactly what's in their data

### Claude's Discretion
- Exact value box placement relative to existing consensus value boxes
- How to capture check_unhandled() output (intercept warnings vs. custom detection)
- QC summary card styling and layout details
- Whether to add QC results to the multi-sheet export (e.g., QC sheet or flags in existing sheets)
- Test strategy for the unicode function swap (update existing tests vs. new test file)

### Deferred Ideas (OUT OF SCOPE)
- ENRCH-01: Functional use category enrichment via CompTox API — v1.4+
- ENRCH-02: Safety flag enrichment via CompTox API — v1.4+
- FOOD-01: Food name reference category — v1.4+

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| POST-01 | User can see resolved CAS-RNs re-validated after curation, with any invalid CAS flagged | Already satisfied by existing pipeline: ComptoxR::as_cas() validates in Phase 11 pre-curation, CompTox API returns are server-validated. No additional validation needed. |
| POST-02 | User can see any remaining non-ASCII characters flagged in the final output as a QC check | ComptoxR::clean_unicode() with 157-entry unicode_map detects unmapped characters; check_unhandled() identifies specific problem characters. QC layer uses same function in validation mode to flag rows. |

</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| ComptoxR | 1.2+ | Chemistry-specific unicode cleaning and validation | EPA-maintained package with 157 chemistry-specific unicode mappings (Greek letters, chemical symbols, trademark handling) |
| stringi | 1.8+ | Text manipulation and unicode detection (existing) | Already in use for current unicode operations; serves as fallback and complementary tool |
| DT | 0.33+ | Interactive datatable with conditional formatting (existing) | Already established for Review Results table; supports JavaScript-based row styling |
| bslib | 0.8+ | Value box dashboard components (existing) | Phase 11 established value_box() pattern for statistics display |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| tools | base R | showNonASCII() for detecting non-ASCII bytes | Validation during test suite to verify unicode handling |
| withr | 2.5+ | Capture warnings programmatically | If intercepting check_unhandled() warnings instead of custom detection |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| ComptoxR::clean_unicode() | stringi::stri_trans_general() (current) | Custom solution loses chemistry-specific mappings (α→a instead of α→.alpha.); ComptoxR is purpose-built for chemical data |
| Manual unicode detection | iconv() encoding checks | Lower-level approach requires more custom logic; ComptoxR's check_unhandled() provides ready-made detection |
| Separate QC module | Inline validation during curation | Separate QC allows users to see final state and re-run validation after manual edits; more flexible UX |

**Installation:**
```r
# ComptoxR is already in load_packages.R
# No new dependencies needed
source("load_packages.R")
```

## Architecture Patterns

### Recommended Function Replacement Pattern
```
Pre-curation pipeline (R/cleaning_pipeline.R):
├── clean_unicode_field() → DELETE
├── Line 98: dplyr::across(where(is.character), clean_unicode_field)
│   └── REPLACE: dplyr::across(where(is.character), ComptoxR::clean_unicode)

Inline cleaning (R/modules/mod_clean_data.R):
└── Line 98: dplyr::mutate(df, dplyr::across(where(is.character), clean_unicode_field))
    └── REPLACE: dplyr::mutate(df, dplyr::across(where(is.character), ComptoxR::clean_unicode))
```

### Pattern 1: Unicode Function Swap
**What:** Replace custom stringi-based unicode cleaning with ComptoxR's chemistry-specific implementation
**When to use:** Pre-curation pipeline unicode cleaning step
**Example:**
```r
# OLD (current implementation in R/cleaning_pipeline.R:28-32)
clean_unicode_field <- function(x) {
  result <- ifelse(is.na(x), NA_character_, stringi::stri_trans_general(x, "Any-Latin; Latin-ASCII"))
  return(result)
}

# NEW (use ComptoxR directly)
# Delete clean_unicode_field() function entirely
# Replace calls with:
df <- dplyr::mutate(df, dplyr::across(where(is.character), ComptoxR::clean_unicode))
```
**Source:** ComptoxR package documentation; Phase 11 established pattern of using ComptoxR functions directly

### Pattern 2: Post-Curation QC Detection
**What:** Run unicode validation on final curated data without modifying values
**When to use:** After curation completes or when user clicks "Re-run QC"
**Example:**
```r
# QC validation function (new in R/cleaning_pipeline.R)
perform_unicode_qc <- function(df) {
  # Detect rows with non-ASCII characters
  has_non_ascii <- function(x) {
    if (is.na(x) || !is.character(x)) return(FALSE)
    cleaned <- ComptoxR::clean_unicode(x)
    return(!identical(x, cleaned))
  }

  # Check each character column
  char_cols <- names(df)[sapply(df, is.character)]
  non_ascii_rows <- rep(FALSE, nrow(df))

  for (col in char_cols) {
    non_ascii_rows <- non_ascii_rows | sapply(df[[col]], has_non_ascii)
  }

  # Detect unhandled characters (requires capturing check_unhandled() logic)
  # ComptoxR:::check_unhandled() is internal — need to replicate detection
  unhandled_chars <- detect_unhandled_unicode(df)

  list(
    rows_with_non_ascii = sum(non_ascii_rows),
    row_indices = which(non_ascii_rows),
    unhandled_chars = unhandled_chars
  )
}
```
**Source:** Adapted from ComptoxR::clean_unicode() behavior and R tools::showNonASCII() patterns

### Pattern 3: Value Box Dashboard Extension
**What:** Add QC metrics to existing consensus statistics dashboard
**When to use:** Review Results module UI rendering
**Example:**
```r
# In R/modules/mod_review_results.R, extend output$curation_stats
output$curation_stats <- renderUI({
  req(data_store$consensus_summary, data_store$resolution_state)

  summary <- data_store$consensus_summary
  qc_results <- data_store$qc_results  # NEW: QC results from post-curation check

  # Existing consensus value boxes...
  row1 <- layout_columns(
    col_widths = c(3, 3, 3, 3),
    value_box(title = "Resolved", value = resolved, ...),
    value_box(title = "Disagree", value = summary$n_disagree, ...),
    value_box(title = "Errors", value = errors, ...),
    value_box(title = "Match Rate", value = paste0(match_rate, "%"), ...)
  )

  # NEW: QC value boxes row
  row2 <- if (!is.null(qc_results)) {
    layout_columns(
      col_widths = c(6, 6),
      value_box(
        title = "Rows with Non-ASCII",
        value = qc_results$rows_with_non_ascii,
        showcase = bsicons::bs_icon("exclamation-circle"),
        theme = if (qc_results$rows_with_non_ascii == 0) "success" else "warning"
      ),
      value_box(
        title = "Unhandled Characters",
        value = length(qc_results$unhandled_chars),
        showcase = bsicons::bs_icon("question-circle"),
        theme = if (length(qc_results$unhandled_chars) == 0) "success" else "info"
      )
    )
  } else {
    NULL
  }

  tagList(row1, row2)
})
```
**Source:** Phase 11 established value_box() pattern (R/modules/mod_review_results.R:133-160)

### Pattern 4: DT Warning Flag Integration
**What:** Add qc_flag column to resolution_state datatable with WARN: prefix
**When to use:** Review Results table rendering
**Example:**
```r
# In R/modules/mod_review_results.R curation_table rendering
output$curation_table <- renderDT(server = FALSE, {
  req(data_store$resolution_state, data_store$dtxsid_cols)

  df <- data_store$resolution_state

  # Add qc_flag column if QC results exist
  if (!is.null(data_store$qc_results)) {
    qc_indices <- data_store$qc_results$row_indices
    df$qc_flag <- ifelse(seq_len(nrow(df)) %in% qc_indices, "WARN: non-ASCII", NA_character_)
  }

  # Existing DT rendering...
  dt <- datatable(df, ...)

  # Conditional formatting for qc_flag (reuse Phase 13 pattern)
  if ("qc_flag" %in% names(df)) {
    dt <- dt %>%
      DT::formatStyle(
        "qc_flag",
        target = "row",
        backgroundColor = DT::JS(
          "function(rowData, rowIndex, colIndex, row) {
            var flag = rowData[colIndex];
            if (flag && typeof flag === 'string') {
              if (flag.startsWith('WARN:')) {
                return '#fff3cd';  // Yellow warning background
              }
            }
            return '';
          }"
        )
      )
  }

  dt
})
```
**Source:** Phase 13 BLOCK/WARN conditional formatting (R/modules/mod_clean_data.R:700-714)

### Pattern 5: QC Summary Card
**What:** Detailed breakdown of unhandled characters above export button
**When to use:** When QC detects unmapped unicode characters
**Example:**
```r
# In R/modules/mod_review_results.R UI, add above download button
output$qc_summary_card <- renderUI({
  req(data_store$qc_results)

  qc <- data_store$qc_results

  if (length(qc$unhandled_chars) == 0) {
    return(NULL)  # No issues, hide card
  }

  # Build unhandled character details
  char_details <- lapply(qc$unhandled_chars, function(char_info) {
    tags$li(
      sprintf("U+%04X (%s) found in %d rows",
              char_info$codepoint,
              char_info$char,
              char_info$count)
    )
  })

  div(
    class = "card mb-3 border-warning",
    div(class = "card-header bg-warning text-dark",
        bsicons::bs_icon("exclamation-triangle"), " QC Warning: Unmapped Unicode Characters"),
    div(
      class = "card-body",
      p("The following characters have no chemistry-specific mapping and were not cleaned:"),
      tags$ul(char_details),
      p(class = "mb-0 text-muted",
        "These characters will remain in your exported data. Review and resolve if needed, then re-run QC.")
    )
  )
})

# In UI definition
uiOutput(ns("qc_summary_card")),
actionButton(ns("rerun_qc"), "Re-run QC", icon = icon("sync"), class = "btn-sm btn-outline-secondary me-2"),
downloadButton(ns("download_curated"), "Download Excel", class = "btn-primary")
```
**Source:** Bootstrap card pattern from existing mod_clean_data.R summary cards; Phase 13 warning styling

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Chemistry-specific unicode mapping | Custom unicode normalization rules for Greek letters, chemical symbols | ComptoxR::clean_unicode() | ComptoxR maintains 157 chemistry-specific mappings (α→.alpha., β→.beta., trademark removal); replicating this mapping table is error-prone and duplicates EPA-maintained logic |
| Unicode character detection | Regex patterns for non-ASCII ranges | tools::showNonASCII() or ComptoxR::check_unhandled() | Built-in tools handle all Unicode ranges correctly; custom regex risks missing edge cases (combining marks, surrogate pairs, etc.) |
| Warning capture in tests | Global option hooks or sink() | withr::with_options() or testthat::expect_warning() | Safer scope management; test-specific capture without side effects |
| DT conditional formatting logic | Custom HTML rendering for table cells | DT::formatStyle() with JavaScript callbacks | DT provides optimized rendering pipeline; custom HTML breaks pagination and filtering |

**Key insight:** Unicode handling is deceptively complex — character encoding edge cases (combining marks, normalization forms, surrogate pairs) create subtle bugs. ComptoxR's chemistry-specific solution is domain-tested and EPA-maintained.

## Common Pitfalls

### Pitfall 1: Assuming ComptoxR::clean_unicode() modifies in-place
**What goes wrong:** Expecting clean_unicode() to add attributes or modify the original vector; treating it like a validator that returns TRUE/FALSE
**Why it happens:** Function name suggests cleaning action; easy to confuse with validation-only functions like is_cas()
**How to avoid:** Always capture return value — `cleaned <- ComptoxR::clean_unicode(x)` — then compare to original for QC detection
**Warning signs:** Tests fail because original data isn't modified; QC detection shows no differences

### Pitfall 2: Missing audit trail updates for unicode function swap
**What goes wrong:** Changing clean_unicode_field() calls but forgetting to update test expectations; audit trail reason strings still reference old function
**Why it happens:** Tests hardcode expected output ("a-tocopherol" from stringi vs ".alpha.-tocopherol" from ComptoxR); audit trail strings mention "Unicode to ASCII" generically
**How to avoid:** Update test expectations to match ComptoxR behavior (Greek letters become dot-notation); review all test_cleaning_pipeline.R assertions
**Warning signs:** Tests fail with "a-tocopherol" != ".alpha.-tocopherol"; audit trail doesn't reflect chemistry-specific cleaning

### Pitfall 3: ComptoxR::check_unhandled() is internal and not exported
**What goes wrong:** Calling ComptoxR:::check_unhandled() directly in production code; function signature may change without notice
**Why it happens:** Context documentation references check_unhandled() as if it's public API; tempting to use triple-colon accessor
**How to avoid:** Replicate check_unhandled() logic by comparing pre/post clean_unicode() and extracting unmapped characters; don't rely on internal functions
**Warning signs:** R CMD check warnings about ::: accessor; code breaks on ComptoxR updates

### Pitfall 4: QC re-run button observer not properly isolated
**What goes wrong:** Clicking "Re-run QC" triggers multiple times or causes reactive loops; QC runs on every resolution change
**Why it happens:** observeEvent() without proper isolation; mixing reactive() with observe()
**How to avoid:** Use observeEvent(input$rerun_qc) with explicit trigger, not reactive dependencies on resolution_state
**Warning signs:** QC runs continuously; performance degrades; console shows repeated QC messages

### Pitfall 5: Forgetting to handle qc_flag column in export
**What goes wrong:** qc_flag column appears in exported Excel with WARN: prefixes; or QC results are lost entirely in export
**Why it happens:** DT table includes qc_flag for display but export logic doesn't handle it; unclear if QC results should persist in export
**How to avoid:** Decide explicitly: either (1) strip qc_flag before export, or (2) add QC Results sheet to multi-sheet export with detailed findings
**Warning signs:** User questions about mysterious "WARN: non-ASCII" column in Excel; QC warnings disappear after export/re-import

## Code Examples

Verified patterns from official sources and existing codebase:

### Unicode Function Replacement (Delete + Replace)
```r
# Source: R/cleaning_pipeline.R lines 28-32 (CURRENT — DELETE THIS)
clean_unicode_field <- function(x) {
  result <- ifelse(is.na(x), NA_character_, stringi::stri_trans_general(x, "Any-Latin; Latin-ASCII"))
  return(result)
}

# Source: R/cleaning_pipeline.R line 98 (CURRENT — REPLACE THIS)
df <- dplyr::mutate(df, dplyr::across(where(is.character), clean_unicode_field))

# NEW IMPLEMENTATION (single line replacement)
df <- dplyr::mutate(df, dplyr::across(where(is.character), ComptoxR::clean_unicode))
```

### Post-Curation QC Detection
```r
# Source: Custom implementation based on ComptoxR::clean_unicode behavior
perform_unicode_qc <- function(df) {
  char_cols <- names(df)[sapply(df, is.character)]

  # Detect rows with any non-ASCII characters
  non_ascii_rows <- rep(FALSE, nrow(df))
  unhandled_chars <- list()

  for (col in char_cols) {
    for (i in seq_len(nrow(df))) {
      val <- df[[col]][i]
      if (is.na(val)) next

      cleaned <- ComptoxR::clean_unicode(val)
      if (!identical(val, cleaned)) {
        non_ascii_rows[i] <- TRUE

        # Extract specific unmapped characters
        original_chars <- strsplit(val, "")[[1]]
        cleaned_chars <- strsplit(cleaned, "")[[1]]

        # Find characters that weren't handled (simplified detection)
        # Note: This is approximate — true unmapped detection requires ComptoxR internals
        for (char in original_chars) {
          if (grepl("[^\x01-\x7F]", char)) {  # Non-ASCII range
            codepoint <- utf8ToInt(char)
            char_key <- sprintf("U+%04X", codepoint)

            if (is.null(unhandled_chars[[char_key]])) {
              unhandled_chars[[char_key]] <- list(
                char = char,
                codepoint = codepoint,
                count = 1
              )
            } else {
              unhandled_chars[[char_key]]$count <- unhandled_chars[[char_key]]$count + 1
            }
          }
        }
      }
    }
  }

  list(
    rows_with_non_ascii = sum(non_ascii_rows),
    row_indices = which(non_ascii_rows),
    unhandled_chars = unhandled_chars
  )
}
```

### Observer for Auto-Run QC After Curation
```r
# Source: app.R server (new observer after curation completes)
# In app.R server function, add:
observeEvent(data_store$consensus_summary, {
  req(data_store$resolution_state)

  # Run QC automatically when curation completes
  qc_results <- perform_unicode_qc(data_store$resolution_state)
  data_store$qc_results <- qc_results

  # Show notification if issues found
  if (qc_results$rows_with_non_ascii > 0) {
    showNotification(
      sprintf("QC Check: %d rows contain non-ASCII characters", qc_results$rows_with_non_ascii),
      type = "warning",
      duration = 5
    )
  }
}, ignoreInit = TRUE)
```

### Re-run QC Button Observer
```r
# Source: R/modules/mod_review_results.R server (new observer)
observeEvent(input$rerun_qc, {
  req(data_store$resolution_state)

  withProgress(message = "Running QC checks...", value = 0, {
    incProgress(0.5)
    qc_results <- perform_unicode_qc(data_store$resolution_state)
    data_store$qc_results <- qc_results
    incProgress(1.0)

    showNotification(
      if (qc_results$rows_with_non_ascii == 0) {
        "QC Check: No non-ASCII characters detected"
      } else {
        sprintf("QC Check: %d rows with non-ASCII, %d unhandled characters",
                qc_results$rows_with_non_ascii,
                length(qc_results$unhandled_chars))
      },
      type = if (qc_results$rows_with_non_ascii == 0) "message" else "warning",
      duration = 5
    )
  })
})
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Custom stringi transliteration | ComptoxR chemistry-specific unicode_map | Phase 15 (2026-03-09) | Greek letters now preserved as `.alpha.` notation instead of losing meaning as `a`; trademark symbols removed cleanly |
| Generic Unicode to ASCII | Domain-specific cleaning with 157 mappings | ComptoxR development (EPA) | Chemical data quality improves; curation can handle chemistry notation correctly |
| No post-processing QC | Explicit QC validation layer | Phase 15 (2026-03-09) | Users see data quality issues before export; transparency in what cleaning couldn't handle |

**Deprecated/outdated:**
- **clean_unicode_field()**: Phase 15 removes this in favor of ComptoxR::clean_unicode(); old approach used generic transliteration that broke chemical notation
- **Implicit unicode handling**: Old pipeline silently mangled characters without user visibility; new QC layer surfaces unmapped characters explicitly

## Validation Architecture

> workflow.nyquist_validation is not explicitly set to false in .planning/config.json, so including validation architecture.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | testthat 3.2+ |
| Config file | tests/testthat.R (if exists) or inline test runner via testthat::test_dir("tests") |
| Quick run command | `Rscript -e "source('load_packages.R'); testthat::test_file('tests/test_cleaning_pipeline.R')"` |
| Full suite command | `Rscript -e "source('load_packages.R'); testthat::test_dir('tests')"` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| POST-01 | CAS re-validation (already satisfied by Phase 11) | unit (existing) | `Rscript -e "source('load_packages.R'); testthat::test_file('tests/test_cas_pipeline.R')"` | ✅ tests/test_cas_pipeline.R |
| POST-02 | Non-ASCII flagging in final output | unit | `Rscript -e "source('load_packages.R'); testthat::test_file('tests/test_unicode_qc.R')"` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `Rscript -e "source('load_packages.R'); testthat::test_file('tests/test_cleaning_pipeline.R')"`
- **Per wave merge:** `Rscript -e "source('load_packages.R'); testthat::test_dir('tests')"`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/test_unicode_qc.R` — covers POST-02 (detect_unhandled_unicode, perform_unicode_qc, QC integration)
- [ ] Update `tests/test_cleaning_pipeline.R` — change unicode test expectations from `"a-tocopherol"` to `".alpha.-tocopherol"` after function swap

## Open Questions

1. **Should QC results persist in multi-sheet export?**
   - What we know: Phase 14 established 7-sheet export (raw data, curated data, summary, audit trail, reference lists, column tags, config)
   - What's unclear: Whether to add an 8th sheet "QC Results" with unhandled unicode details, or just strip qc_flag column before export
   - Recommendation: Add QC Results sheet if any non-ASCII detected (conditional sheet); preserves full audit trail and allows users to address issues between sessions

2. **How to handle check_unhandled() internal function?**
   - What we know: ComptoxR:::check_unhandled() is internal (not exported); warns about unmapped characters
   - What's unclear: Whether to replicate its logic or use warning capture (withr::with_warnings)
   - Recommendation: Replicate detection logic by comparing pre/post clean_unicode() strings and extracting non-ASCII characters; more robust than relying on internal function that may change

3. **Should QC flag block export or remain advisory?**
   - What we know: User decision from CONTEXT.md says "advisory only — does not gate the export button"
   - What's unclear: Whether to show modal confirmation if QC warnings present ("Are you sure? X rows contain non-ASCII characters")
   - Recommendation: Pure advisory per user decision; no modal interruption; consistent with needs_review pattern where errors can be exported

## Sources

### Primary (HIGH confidence)
- ComptoxR package (installed and verified): clean_unicode() function with 157-entry unicode_map
- CONCERT codebase: R/cleaning_pipeline.R (lines 28-32, 98), R/modules/mod_clean_data.R (line 98), R/modules/mod_review_results.R (value box pattern, DT formatting)
- Phase 11 implementation: ComptoxR::as_cas() usage pattern (R/cleaning_pipeline.R:164)
- Phase 13 implementation: BLOCK/WARN flag taxonomy and DT conditional formatting (R/modules/mod_clean_data.R:700-714)
- Phase 14 implementation: Multi-sheet export pattern (R/export_helpers.R)

### Secondary (MEDIUM confidence)
- [Shiny Validation in Pharma](https://www.appsilon.com/post/shiny-app-validation-pharma) — Best practices for data validation in regulated environments
- [DT Conditional Formatting Examples](https://rstudio.github.io/DT/010-style.html) — Official DT styleEqual() and formatStyle() patterns
- [R tools::showNonASCII](https://stat.ethz.ch/R-manual/R-devel/library/tools/html/showNonASCII.html) — Base R non-ASCII detection approach

### Tertiary (LOW confidence)
- [R Unicode Handling](https://ssojet.com/character-encoding-decoding/unicode-in-r) — General unicode concepts; not specific to chemistry use case
- [DT Shiny Integration](https://rstudio.github.io/DT/shiny.html) — General guidance; project already has established patterns

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All packages already in use; ComptoxR verified installed and functional
- Architecture: HIGH - Clear patterns from Phases 11, 13, 14 implementations; direct code references
- Pitfalls: MEDIUM - Some based on ComptoxR internals (check_unhandled) that require inference; test update impacts clear

**Research date:** 2026-03-09
**Valid until:** 2026-04-08 (30 days for stable R ecosystem; ComptoxR is EPA-maintained with infrequent breaking changes)

---
*Phase: 15-post-curation-qc*
*Research complete: Ready for planning*
