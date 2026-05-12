# Phase 12: Name Cleaning - Research

**Researched:** 2026-03-06
**Domain:** Chemical name text processing, synonym splitting, parenthetical extraction
**Confidence:** MEDIUM-HIGH

## Summary

Phase 12 implements chemical name cleaning operations: parenthetical stripping, synonym splitting, and quality adjective removal. The phase extends Phase 11's CAS pipeline with name-specific transformations that prepare chemical names for CompTox API curation.

**Critical decision:** Synonym splitting creates NEW ROWS (long format), contrasting with Phase 11's WIDE approach for multi-CAS. This design prevents incorrect CAS-to-synonym pairings — each synonym row gets NA for CAS columns and curates independently.

**Primary recommendation:** Port Python reference implementation (`clean_chems.py`) functions for parenthetical/adjective stripping, implement custom IUPAC-aware synonym splitter with digit-comma-digit protection, extend Phase 11's value box dashboard and audit trail patterns. No existing R library handles IUPAC-aware synonym splitting — custom implementation required.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **Synonym splitting: NEW ROWS (LONG)** — Comma/semicolon-separated synonyms auto-split into new rows. Primary name keeps original row; synonyms get new rows with `original_row_id` tracking.
- **Synonym rows get NA for CAS columns** — Avoids wrong CAS-to-name pairing. Each name curated independently.
- **IUPAC comma protection** — digit-comma-digit regex (e.g., `2,2-dimethyl` and `butane, 2,2-dimethyl` inverted forms). Simple regex, covers 95%+ of cases.
- **No existing library** — Neither clean_chems.py nor ComptoxR has synonym splitting. Custom implementation required.
- **Parenthetical stripping** — Strip terminal parentheticals and brackets from chemical names.
- **"yl" protection** — Protect parentheticals containing "yl" (chemical name fragments like "methyl", "ethyl"). Exception words: 'density', 'probably', 'average', 'combination'.
- **Stripped content preserved** — Formula extracts saved in `formula_extract_{source}` column (low cost, useful for Phase 13 formula flagging).
- **CAS handling** — CAS numbers inside parentheticals handled by existing Phase 11 `extract_cas` — no duplication needed.
- **Quality adjective & salt stripping** — Strip quality adjectives ('pure', 'purified', 'tech', 'grade', 'chemical') and salt references ('and its salts', 'and its [X] salts'). Strip 'unspecified' suffixes.
- **Formula handling: No special detection** — Bare formulas as chemical names (e.g., "H2O") go through curation as regular strings. Bare formula flagging (FILT-04) deferred to Phase 13.
- **Pipeline step order** — (1) Strip parentheticals, (2) Strip quality adjectives/salt refs/unspecified, (3) Synonym split (LAST), (4) Final string cleanup.
- **Before/After Comparison UI (UIUX-03)** — Audit trail table shown in an **accordion (collapsed by default)** below cleaned data table. DT table with columns: row_id, field, original_value, new_value, reason.
- **Value box dashboard extension** — Add 3-4 new value boxes: Parentheticals Stripped, Synonyms Split, Adjectives Removed, Names Cleaned. Extends Phase 11's 6 boxes.
- **Step-by-step progress extension** — Extend Phase 11's incProgress() pattern: unicode → trim → normalize CAS → rescue CAS → detect multi-CAS → **strip parentheticals → strip adjectives → split synonyms → finalize**.

### Claude's Discretion
- Exact regex patterns for adjective/salt/unspecified stripping (use clean_chems.py as reference)
- How to handle edge cases where synonym splitting produces empty strings
- Whether formula_extract column is auto-tagged for curation or left as informational
- Value box themes, icons, and layout for name cleaning boxes
- Accordion styling and default state

### Deferred Ideas (OUT OF SCOPE)
- Bare formula detection and flagging (FILT-04) — Phase 13
- Functional category filtering — Phase 13
- Food name filtering — Phase 13
- Stop word filtering — Phase 13
- Upstream improvements to ComptoxR::extract_formulas() — separate from CONCERT phases
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| NAME-01 | User can see trailing parentheticals and brackets stripped from chemical names, with protection for chemical name fragments containing "yl" | Python `term_parenth()` and `term_bracket()` functions provide reference implementation with "yl" protection logic; port to R using stringr regex |
| NAME-02 | User can see formulas and CAS-RNs extracted from parentheticals and preserved as separate tagged values for curation | Phase 11 `extract_cas()` already handles CAS extraction; formulas preserved in `formula_extract_{source}` column for Phase 13 use; no auto-tagging needed (Claude's discretion) |
| NAME-03 | User can see comma/semicolon-separated synonyms split into separate entries, with IUPAC inverted-name comma protection (digit-comma-digit patterns preserved) | Custom implementation required (no R library exists); use `tidyr::separate_longer_delim()` with conditional protection via pre-tokenization or negative lookahead regex; PRIMARY name keeps original row, synonyms create new rows with `original_row_id` tracking |
| NAME-04 | User can see quality adjectives ('tech grade', 'pure'), salt references ('and its salts'), and 'unspecified' suffixes stripped from names with audit comments | Python `drop_text()`, `drop_salts()`, `terminal_unspecified()` provide reference patterns; port using stringr `str_remove()` with audit trail logging |
| UIUX-03 | User can see before/after data comparison showing cleaning transformations applied to their data | Extend Phase 11's `cleaning_audit` pattern; add accordion UI below cleaned data table using bslib accordion + DT table; leverage existing `build_audit_trail()` function |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| stringr | 1.5+ | Regex pattern matching and string manipulation | Tidyverse standard for string operations; used throughout Phase 10-11 |
| tidyr | 1.3+ | Row expansion for synonym splitting | `separate_longer_delim()` or `separate_rows()` for comma/semicolon splitting |
| dplyr | 1.1+ | Audit trail building, dataframe manipulation | Existing pipeline dependency |
| bslib | 0.8+ | Accordion UI for audit trail | Existing UI framework; `accordion()` for collapsible sections |
| DT | 0.33+ | Audit trail table rendering | Existing table renderer |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| ComptoxR | 1.4+ | CAS extraction from parentheticals | Already integrated in Phase 11; reuse `extract_cas()` |
| purrr | 1.0+ | Safe function execution | `safely()` wrapper for error handling |
| tibble | 3.2+ | Audit trail construction | `tibble()` for building audit records |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom IUPAC splitter | `strsplit()` with simple comma split | Breaks IUPAC inverted names like "butane, 2,2-dimethyl"; requires custom logic either way |
| Row expansion with tidyr | Manual row duplication with loops | tidyr is cleaner and vectorized; custom loops harder to maintain |
| bslib accordion | Custom collapsible div | bslib provides consistent theming and accessibility out-of-box |

**Installation:**
```r
# All dependencies already installed in Phase 10-11
# No new packages required
```

## Architecture Patterns

### Recommended Function Structure (extends R/cleaning_pipeline.R)
```
R/cleaning_pipeline.R
├── [existing] inject_row_lineage()
├── [existing] clean_unicode_field()
├── [existing] clean_text_field()
├── [existing] build_audit_trail()
├── [existing] normalize_cas_fields()
├── [existing] rescue_cas_from_text()
├── [existing] detect_multi_cas()
├── [NEW] strip_terminal_enclosures()     # NAME-01
├── [NEW] extract_formulas_from_parens()  # NAME-02 (preserves stripped content)
├── [NEW] strip_quality_adjectives()      # NAME-04
├── [NEW] strip_salt_references()         # NAME-04
├── [NEW] strip_terminal_unspecified()    # NAME-04
├── [NEW] split_synonyms()                # NAME-03 (returns expanded df + audit)
└── [existing] run_cleaning_pipeline()    # Extend with name cleaning steps
```

### Pattern 1: Parenthetical Stripping with "yl" Protection
**What:** Remove terminal `(...)` or `[...]` from names, but preserve chemical name fragments
**When to use:** Before synonym splitting (to avoid splitting on commas inside parens)
**Example:**
```r
# Source: clean_chems.py lines 164-242 (term_parenth, term_bracket)
strip_terminal_enclosures <- function(x, type = c("parens", "brackets")) {
  # Only strip if terminal (at end of string)
  # Keep if contains "yl" (methyl, ethyl, butyl, etc.)
  # Exception words: density, probably, average, combination
  pattern <- if ("parens" %in% type) {
    "\\(([^)]+)\\)$"  # Terminal parenthetical
  } else {
    "\\[([^]]+)\\]$"  # Terminal bracket
  }

  # Extract content
  content <- stringr::str_extract(x, pattern)

  # Check for "yl" protection
  keep <- stringr::str_detect(content, "yl") &
          !stringr::str_detect(content, "\\b(density|probably|average|combination)\\b")

  # Strip if not protected
  result <- ifelse(keep, x, stringr::str_remove(x, pattern))

  list(cleaned = result, stripped = content)
}
```

### Pattern 2: IUPAC-Aware Synonym Splitting (NEW ROWS)
**What:** Split comma/semicolon-separated names into multiple rows, protecting IUPAC commas
**When to use:** LAST step in name cleaning (after parentheticals removed)
**Example:**
```r
# No existing library — custom implementation
split_synonyms <- function(df, name_col, comment_col) {
  # Step 1: Protect digit-comma-digit patterns (IUPAC locants)
  # Replace "2,2-" with "2@2-" (temporary placeholder)
  protected <- stringr::str_replace_all(
    df[[name_col]],
    "(\\d),(\\d)",
    "\\1@\\2"
  )

  # Step 2: Split on semicolons first (least ambiguous)
  # Then split on unprotected commas
  df_split <- df %>%
    dplyr::mutate(!!name_col := protected) %>%
    tidyr::separate_longer_delim(!!rlang::sym(name_col), delim = stringr::regex("[;,]")) %>%
    dplyr::mutate(!!name_col := stringr::str_replace_all(!!rlang::sym(name_col), "@", ","))

  # Step 3: Tag new rows with original_row_id
  # First synonym keeps original row_id; subsequent synonyms get new IDs
  df_split <- df_split %>%
    dplyr::group_by(original_row_id) %>%
    dplyr::mutate(
      synonym_count = dplyr::n(),
      synonym_index = dplyr::row_number()
    ) %>%
    dplyr::ungroup()

  # Step 4: Set CAS columns to NA for non-primary synonyms
  cas_cols <- names(tag_map)[tag_map == "CASRN"]
  df_split <- df_split %>%
    dplyr::mutate(dplyr::across(
      dplyr::all_of(cas_cols),
      ~ ifelse(synonym_index > 1, NA_character_, .x)
    ))

  # Step 5: Build audit trail
  # Log BOTH original row split AND each new synonym row created
  # Full traceability per CONTEXT.md

  list(cleaned_data = df_split, audit_trail = audit_records)
}
```

### Pattern 3: Audit Trail Accordion UI (UIUX-03)
**What:** Collapsible section below cleaned data table showing before/after changes
**When to use:** In mod_clean_data.R after data table render
**Example:**
```r
# Source: bslib::accordion() documentation
# In mod_clean_data.R renderUI
output$audit_accordion <- renderUI({
  req(data_store$cleaning_audit)

  audit <- data_store$cleaning_audit

  bslib::accordion(
    open = FALSE,  # Collapsed by default per CONTEXT.md
    bslib::accordion_panel(
      title = sprintf("Audit Trail (%d changes)", nrow(audit)),
      icon = bsicons::bs_icon("journal-text"),
      DT::dataTableOutput(ns("audit_table"))
    )
  )
})

output$audit_table <- DT::renderDataTable({
  req(data_store$cleaning_audit)

  DT::datatable(
    data_store$cleaning_audit,
    options = list(
      pageLength = 10,
      scrollX = TRUE,
      order = list(list(0, "asc"))  # Sort by row_id
    ),
    rownames = FALSE
  )
})
```

### Pattern 4: Value Box Dashboard Extension
**What:** Add name cleaning statistics to Phase 11's 6-box dashboard
**When to use:** In cleaning_summary renderUI
**Example:**
```r
# Extend existing value box layout (Phase 11: 6 boxes in 2 rows)
# Add 4 new boxes for name cleaning
audit <- data_store$cleaning_audit

n_parenth <- sum(audit$step == "strip_parentheticals")
n_synonyms <- sum(audit$step == "split_synonyms")
n_adjectives <- sum(audit$step == "strip_adjectives")
n_salts <- sum(audit$step == "strip_salts")

# Row 3: Name cleaning boxes
bslib::layout_columns(
  col_widths = c(3, 3, 3, 3),
  bslib::value_box(
    title = "Parentheticals Stripped",
    value = n_parenth,
    showcase = bsicons::bs_icon("parentheses"),
    theme = "info"
  ),
  bslib::value_box(
    title = "Synonyms Split",
    value = n_synonyms,
    showcase = bsicons::bs_icon("scissors"),
    theme = "primary"
  ),
  bslib::value_box(
    title = "Adjectives Removed",
    value = n_adjectives,
    showcase = bsicons::bs_icon("eraser"),
    theme = "info"
  ),
  bslib::value_box(
    title = "Salts/Unspecified",
    value = n_salts,
    showcase = bsicons::bs_icon("droplet"),
    theme = "info"
  )
)
```

### Pattern 5: Step-by-Step Progress Extension
**What:** Add incProgress() calls for name cleaning steps
**When to use:** Inside mod_clean_data.R withProgress() block
**Example:**
```r
# Existing: unicode (0.15) → trim (0.15) → normalize CAS (0.20) →
#           rescue CAS (0.20) → detect multi-CAS (0.10) → finalize (0.10)
# Total existing: 0.90

# Extend with name cleaning (use remaining 0.10 budget, add 0.20 more)
incProgress(0.10, detail = "Stripping parentheticals...")
parenth_result <- strip_terminal_enclosures(df, name_cols, tag_map)
df <- parenth_result$cleaned_data
all_audits[[length(all_audits) + 1]] <- parenth_result$audit_trail

incProgress(0.05, detail = "Removing quality adjectives...")
adj_result <- strip_quality_adjectives(df, name_cols)
df <- adj_result$cleaned_data
all_audits[[length(all_audits) + 1]] <- adj_result$audit_trail

incProgress(0.05, detail = "Stripping salt references...")
salt_result <- strip_salt_references(df, name_cols)
df <- salt_result$cleaned_data
all_audits[[length(all_audits) + 1]] <- salt_result$audit_trail

incProgress(0.10, detail = "Splitting synonyms...")
synonym_result <- split_synonyms(df, name_cols, tag_map)
df <- synonym_result$cleaned_data
all_audits[[length(all_audits) + 1]] <- synonym_result$audit_trail

# Note: Row count changes here — downstream must handle
```

### Anti-Patterns to Avoid
- **Don't split synonyms before stripping parentheticals** — commas inside parens will trigger false splits
- **Don't use simple `strsplit()` for synonyms** — breaks IUPAC inverted names ("butane, 2,2-dimethyl")
- **Don't auto-tag formula_extract columns as CASRN** — they're informational for Phase 13, not for immediate curation
- **Don't set original row's CAS to NA after synonym split** — only NEW synonym rows get NA for CAS
- **Don't skip audit logging for synonym split** — must log BOTH original row ("split into N synonyms") AND each new synonym row ("synonym from row X")

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| String pattern matching | Custom regex parser | stringr with vectorized operations | stringr handles NA gracefully, vectorizes across columns, tidyverse-consistent API |
| Row expansion | Manual loops duplicating rows | tidyr::separate_longer_delim() | Handles edge cases (empty splits, NA values), preserves other columns automatically |
| Collapsible UI sections | Custom JavaScript + CSS | bslib::accordion() | Maintains theme consistency, accessible by default, Bootstrap 5 native |
| Data table rendering | HTML table generation | DT::datatable() | Server-side processing, built-in search/sort, handles large audits |

**Key insight:** Synonym splitting is the highest-complexity operation. IUPAC comma protection requires domain knowledge (digit-comma-digit patterns), but the actual row expansion should use tidyr, not custom loops. Pre-tokenization strategy (replace protected commas with placeholder like "@") is simpler than complex negative lookahead regex.

## Common Pitfalls

### Pitfall 1: IUPAC Comma False Splits
**What goes wrong:** Simple comma split breaks inverted IUPAC names like "butane, 2,2-dimethyl" into TWO names instead of keeping as ONE
**Why it happens:** IUPAC uses commas for locant lists (2,2-) AND for inverted naming (compound, substituent)
**How to avoid:** Digit-comma-digit protection via placeholder replacement before split, then restore after
**Warning signs:** Test dataset should include "2,4-dichlorophenol" (single name with comma) and "xylene, dimethylbenzene" (two synonyms)

### Pitfall 2: Parenthetical "yl" False Positives
**What goes wrong:** Keeping "(high density)" because it contains "yl" in "density"
**Why it happens:** Substring match instead of suffix match for "yl" chemical fragments
**How to avoid:** Exception word list ('density', 'probably', 'average', 'combination') from clean_chems.py line 189
**Warning signs:** Test with "compound (high density)" (should strip) vs "dimethyl (methyl group)" (should keep)

### Pitfall 3: Row Count Changes Break Downstream
**What goes wrong:** Synonym splitting adds rows; tag_columns module expects same row count as data_store$clean
**Why it happens:** Synonym split is first operation that changes row count (CAS pipeline kept WIDE format)
**How to avoid:** Update data_store$cleaned_data row count BEFORE calling downstream modules; ensure deduplicate_tagged_columns() and map_results_to_rows() use original_row_id for joins
**Warning signs:** Curation results table shows wrong row count or missing rows after synonym split

### Pitfall 4: Empty Strings After Cleaning
**What goes wrong:** Stripping "tech grade" from "tech grade chemical" leaves empty string ""
**Why it happens:** Adjective is the entire name, not a qualifier
**How to avoid:** Final cleanup step removes rows where cleaned name is empty/whitespace-only; log to audit trail as "name became empty after cleaning"
**Warning signs:** Test with "pure", "tech", "chemical grade" as standalone names

### Pitfall 5: CAS-to-Synonym Pairing Errors
**What goes wrong:** Synonym rows inherit original row's CAS, creating wrong chemical identities
**Why it happens:** Forgetting to set CAS columns to NA for non-primary synonyms
**How to avoid:** Explicit NA assignment for all CASRN-tagged columns where synonym_index > 1
**Warning signs:** Multi-CAS detection in Phase 11 should NOT flag synonym rows (they should have 0-1 CAS each)

## Code Examples

Verified patterns from Python reference and R testing:

### Terminal Parenthetical Stripping (NAME-01)
```r
# Source: clean_chems.py lines 164-201 (term_parenth function)
# Ported to R with stringr

strip_terminal_parens <- function(x) {
  # Extract terminal parenthetical (last occurrence)
  pattern <- "\\(([^)]+)\\)$"
  content <- stringr::str_extract(x, pattern)

  # Check for "yl" protection (chemical name fragment)
  # Exception words: density, probably, average, combination
  has_yl <- stringr::str_detect(content, "yl")
  exception_word <- stringr::str_detect(
    content,
    "\\b(density|probably|average|combination)\\b"
  )

  # Keep if has "yl" and NOT an exception word
  keep <- has_yl & !exception_word

  # Strip if not kept
  cleaned <- ifelse(
    is.na(content) | keep,
    x,
    stringr::str_remove(x, pattern)
  )

  # Return both cleaned text and stripped content
  list(
    cleaned = stringr::str_trim(cleaned),
    stripped = stringr::str_remove_all(content, "[\\(\\)]")
  )
}

# Test cases
strip_terminal_parens("Acetone (ACS reagent)")
# $cleaned: "Acetone"
# $stripped: "ACS reagent"

strip_terminal_parens("dimethyl (methyl)")
# $cleaned: "dimethyl (methyl)"  # KEPT — has "yl"
# $stripped: NA

strip_terminal_parens("compound (high density)")
# $cleaned: "compound"  # STRIPPED — exception word
# $stripped: "high density"
```

### IUPAC-Aware Synonym Splitting (NAME-03)
```r
# No library reference — custom implementation with digit-comma-digit protection
# Strategy: temporary placeholder replacement

split_synonyms_iupac_aware <- function(name_vector) {
  # Step 1: Protect IUPAC commas (digit-comma-digit)
  # Replace "2,2-" with "2@2-", "1,4-" with "1@4-", etc.
  protected <- stringr::str_replace_all(
    name_vector,
    "(\\d+),(\\d+)",  # Digit, comma, digit
    "\\1@\\2"         # Replace comma with @
  )

  # Step 2: Split on semicolons (highest precedence)
  split_semi <- stringr::str_split(protected, ";")

  # Step 3: Further split each part on commas
  split_comma <- lapply(split_semi, function(parts) {
    unlist(stringr::str_split(parts, ","))
  })

  # Step 4: Restore protected commas
  restored <- lapply(split_comma, function(parts) {
    stringr::str_replace_all(parts, "@", ",")
  })

  # Step 5: Trim whitespace
  cleaned <- lapply(restored, stringr::str_trim)

  # Step 6: Remove empty strings
  cleaned <- lapply(cleaned, function(x) x[x != ""])

  cleaned
}

# Test cases
split_synonyms_iupac_aware("xylene, dimethylbenzene, xylol")
# [[1]]: c("xylene", "dimethylbenzene", "xylol")  # 3 names

split_synonyms_iupac_aware("butane, 2,2-dimethyl")
# [[1]]: c("butane, 2,2-dimethyl")  # 1 name (IUPAC inverted)

split_synonyms_iupac_aware("acetone; dimethyl ketone")
# [[1]]: c("acetone", "dimethyl ketone")  # 2 names (semicolon)

split_synonyms_iupac_aware("1,4-Dioxane")
# [[1]]: c("1,4-Dioxane")  # 1 name (protected comma)
```

### Quality Adjective Stripping (NAME-04)
```r
# Source: clean_chems.py lines 521-535 (drop_text function, quality adjectives)
strip_quality_adjectives <- function(x) {
  quality_words <- c("pure", "purif", "tech", "grade", "chemical")

  # Build regex pattern: word boundaries to avoid partial matches
  pattern <- paste0("\\b(", paste(quality_words, collapse = "|"), "\\w*)\\b")

  # Extract what will be removed (for audit trail)
  removed <- stringr::str_extract_all(
    x,
    stringr::regex(pattern, ignore_case = TRUE)
  )

  # Remove quality adjectives
  cleaned <- stringr::str_remove_all(
    x,
    stringr::regex(pattern, ignore_case = TRUE)
  )

  # Clean up extra whitespace left behind
  cleaned <- stringr::str_squish(cleaned)

  list(cleaned = cleaned, removed = removed)
}

# Test cases
strip_quality_adjectives("technical grade ethanol")
# $cleaned: "ethanol"
# $removed: list("technical", "grade")

strip_quality_adjectives("Acetone, 99.5% pure")
# $cleaned: "Acetone, 99.5%"
# $removed: list("pure")
```

### Salt Reference Stripping (NAME-04)
```r
# Source: clean_chems.py lines 562-575 (drop_salts function)
strip_salt_references <- function(x) {
  pattern <- stringr::regex(
    "and its (\\w+ )?salts",  # "and its salts" or "and its sodium salts"
    ignore_case = TRUE
  )

  # Extract for audit trail
  removed <- stringr::str_extract(x, pattern)

  # Remove salt reference
  cleaned <- stringr::str_remove(x, pattern)
  cleaned <- stringr::str_trim(cleaned)

  list(cleaned = cleaned, removed = removed)
}

# Test cases
strip_salt_references("lead and its salts")
# $cleaned: "lead"
# $removed: "and its salts"

strip_salt_references("mercury and its inorganic salts")
# $cleaned: "mercury"
# $removed: "and its inorganic salts"
```

### Audit Trail Accordion UI (UIUX-03)
```r
# Source: bslib documentation + Phase 11 audit trail pattern
# In mod_clean_data.R

output$audit_section <- renderUI({
  req(data_store$cleaning_audit)

  audit <- data_store$cleaning_audit
  n_changes <- nrow(audit)

  # Collapsed by default per CONTEXT.md
  bslib::accordion(
    id = ns("audit_accordion"),
    open = FALSE,
    bslib::accordion_panel(
      title = sprintf("Cleaning Audit Trail — %d Changes", n_changes),
      icon = bsicons::bs_icon("journal-text"),
      value = "audit_panel",

      # Summary stats
      div(
        class = "mb-3",
        p(sprintf(
          "Changes: %d unicode, %d trim, %d CAS, %d parenthetical, %d synonym split",
          sum(audit$step == "unicode_to_ascii"),
          sum(audit$step == "trim_whitespace_punctuation"),
          sum(audit$step == "normalize_cas"),
          sum(audit$step == "strip_parentheticals"),
          sum(audit$step == "split_synonyms")
        ))
      ),

      # Full audit table
      DT::dataTableOutput(ns("audit_table"))
    )
  )
})

output$audit_table <- DT::renderDataTable({
  req(data_store$cleaning_audit)

  DT::datatable(
    data_store$cleaning_audit,
    options = list(
      pageLength = 25,
      scrollX = TRUE,
      order = list(list(0, "asc")),  # Sort by row_id
      columnDefs = list(
        list(width = "80px", targets = 0),  # row_id
        list(width = "120px", targets = 1), # field
        list(width = "150px", targets = 2)  # step
      )
    ),
    rownames = FALSE,
    filter = "top"  # Column filters for step/field
  )
})
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Semicolon/comma split with `strsplit()` | IUPAC-aware splitting with digit-comma-digit protection | Phase 12 (2026) | Prevents breaking IUPAC inverted names; custom implementation required |
| Multi-CAS WIDE format (Phase 11) | Synonym LONG format (Phase 12) | Phase 12 (2026) | Multi-CAS needs user decision (mixtures vs errors); synonyms auto-split (no ambiguity) |
| Python script (`clean_chems.py`) run separately | Integrated R pipeline in Shiny | v1.3 (2026) | Unified workflow, no context switching, immediate visual feedback |
| Manual audit trail review (external CSV) | Interactive accordion in UI | Phase 12 (2026) | Users see transformations inline, expand/collapse as needed |

**Deprecated/outdated:**
- `tidyr::separate_rows()` superseded by `tidyr::separate_longer_delim()` — use newer API for consistency
- Base R `strsplit()` for comma splitting — stringr provides better NA handling and regex support

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | testthat 3.2+ |
| Config file | None — tests in `tests/` directory |
| Quick run command | `testthat::test_file("tests/test_name_cleaning.R")` |
| Full suite command | `testthat::test_dir("tests")` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| NAME-01 | Strip terminal parentheticals/brackets with "yl" protection | unit | `testthat::test_file("tests/test_name_cleaning.R") -x` | ❌ Wave 0 |
| NAME-02 | Preserve stripped formulas in formula_extract column | unit | `testthat::test_file("tests/test_name_cleaning.R") -x` | ❌ Wave 0 |
| NAME-03 | Split synonyms with IUPAC comma protection | unit | `testthat::test_file("tests/test_name_cleaning.R") -x` | ❌ Wave 0 |
| NAME-04 | Strip adjectives, salts, unspecified with audit | unit | `testthat::test_file("tests/test_name_cleaning.R") -x` | ❌ Wave 0 |
| UIUX-03 | Audit trail accordion UI | integration | Manual Shiny smoke test + screenshot | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `testthat::test_file("tests/test_name_cleaning.R")`
- **Per wave merge:** `testthat::test_dir("tests")` (full suite including Phase 10-11)
- **Phase gate:** Full suite green + Shiny smoke test before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/test_name_cleaning.R` — covers NAME-01, NAME-02, NAME-03, NAME-04
  - Test cases for `strip_terminal_enclosures()` (parenthesis, bracket, "yl" protection, exception words)
  - Test cases for `split_synonyms()` (IUPAC digit-comma-digit, semicolon priority, empty string handling)
  - Test cases for `strip_quality_adjectives()`, `strip_salt_references()`, `strip_terminal_unspecified()`
  - Test cases for audit trail generation (all name cleaning steps)
- [ ] Extend `tests/test_cas_pipeline.R` — verify synonym split doesn't break CAS columns
  - Test that synonym rows get NA for CAS columns
  - Test that original_row_id tracking works across split
- [ ] Shiny smoke test — verify UI renders accordion, value boxes, handles row count change
  - Test with `data/chemical_validation_test.csv` extended with synonym examples

**Critical test cases (from PRE_POST_CURATION_PLAN.md live data analysis):**
- "xylene, dimethylbenzene, xylol" → 3 rows (comma-separated synonyms)
- "butane, 2,2-dimethyl" → 1 row (IUPAC inverted name)
- "acetone; dimethyl ketone" → 2 rows (semicolon-separated)
- "1,4-Dioxane" → 1 row (IUPAC locant comma protected)
- "Acetone (ACS reagent)" → "Acetone" + audit (parenthetical stripped)
- "dimethyl (methyl)" → unchanged ("yl" protection)
- "compound (high density)" → "compound" (exception word, stripped)
- "lead and its salts" → "lead" (salt reference stripped)
- "technical grade ethanol" → "ethanol" (quality adjective stripped)

## Sources

### Primary (HIGH confidence)
- `clean_chems.py` (Python reference implementation) — term_parenth (line 164), term_bracket (line 205), drop_text/quality adjectives (line 495), drop_salts (line 557), terminal_unspecified (line 348)
- `PRE_POST_CURATION_PLAN.md` — synonym splitting strategy (lines 500-670), IUPAC protection requirements, live data analysis
- `R/cleaning_pipeline.R` — existing pipeline functions (inject_row_lineage, build_audit_trail, CAS operations)
- `R/modules/mod_clean_data.R` — existing value box dashboard pattern, step-by-step progress pattern
- `tests/test_cas_pipeline.R` — test structure and patterns to follow

### Secondary (MEDIUM confidence)
- [tidyr::separate_longer_delim() documentation](https://tidyr.tidyverse.org/reference/separate_longer_delim.html) — row expansion with delimiters
- [stringr::str_remove() documentation](https://stringr.tidyverse.org/reference/str_remove.html) — pattern removal from strings
- [bslib::accordion() documentation](https://rstudio.github.io/bslib/reference/accordion.html) — collapsible UI sections
- [GeeksforGeeks: Remove Parentheses and Text Within from Strings in R](https://www.geeksforgeeks.org/r-language/remove-parentheses-and-text-within-from-strings-in-r/) — regex pattern examples for parenthetical stripping

### Tertiary (LOW confidence)
- [Built In: How to Use strsplit() Function in R](https://builtin.com/articles/strsplit) — basic string splitting (superseded by tidyr for this use case)
- [IUPAC R-0.1.3 Punctuation](https://www.acdlabs.com/iupac/nomenclature/93/r93_45.htm) — IUPAC comma usage in chemical nomenclature (domain knowledge validation)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — All packages already in use (Phase 10-11); no new dependencies
- Architecture patterns: HIGH — Python reference implementation exists; Phase 11 patterns established
- IUPAC synonym splitting: MEDIUM — Custom implementation required (no library); digit-comma-digit protection is heuristic (95%+ coverage per CONTEXT.md, not 100%)
- Parenthetical stripping: HIGH — Python reference with clear "yl" protection logic; direct port to R stringr
- UI patterns: HIGH — bslib accordion and value boxes already used in Phase 11; extension is straightforward
- Pitfalls: HIGH — Documented from PRE_POST_CURATION_PLAN.md live data analysis (12,144 rows) and Phase 11 lessons

**Research date:** 2026-03-06
**Valid until:** 60 days (stable domain — chemical name processing patterns don't change rapidly)
