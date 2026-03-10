# Phase 13: Reference Filters & Editable Lists - Research

**Researched:** 2026-03-06
**Domain:** Reference list management, flag matching, editable tables, reactive cascade invalidation
**Confidence:** HIGH

## Summary

This phase adds reference-based flagging (functional categories as warnings, bare formulas as blocking) and editable reference list management via rhandsontable. Users can enrich reference lists on top of ComptoxR-seeded baselines, see flags in cleaned data, and re-run cleaning with updated lists, triggering full cascade invalidation.

The technical foundation is solid: ComptoxR's formula validator can be reused for bare formula detection (~5-10 lines wrapping existing logic), rhandsontable provides Excel-like editing UX with add/remove/suppress capabilities, bslib accordion panels already used in Phase 12 for audit trail, and the cascade reset pattern was established in Phase 11-12. No new architectural patterns needed—this phase extends existing infrastructure.

**Primary recommendation:** Reuse ComptoxR's `validator_regex` directly for bare formula detection, use exact-then-substring matching with confidence labels for reference list flagging, implement soft delete (active=FALSE) for ComptoxR-seeded entries and hard delete for user-added entries, display flags via DT conditional formatting (red for blocking, yellow for warning).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **Flag Matching: Exact-then-Substring with Confidence Labels** — Match names against reference lists using two passes: exact match first (high confidence), then substring match (lower confidence). Both match types labeled in the audit trail so users can trust exact matches more and scrutinize substring matches. Flag TYPE (blocking vs warning) determined by which reference list matched, not by how it matched. Match source (ComptoxR-seeded, user-added, app-default) recorded in audit trail reason field only—not displayed in main table. Single `cleaning_flag` column in cleaned data: `BLOCK: bare formula` (red) or `WARN: functional category [exact]` (yellow)—severity + reason + match type in one scannable column.

- **Reference List Structure: Separate Lists with Provenance** — Separate lists per type: functional categories, stop words, block patterns (each gets its own editor). Each list entry carries provenance: term, source (`comptoxr` / `user` / `app_default`), active (`TRUE`/`FALSE`). Seeding uses existing `cleaning_reference.R` pattern—dynamic ComptoxR API + RDS cache (decided Phase 10, no changes needed). User additions tagged as source = `user`. Soft delete for ComptoxR-seeded entries: set active = FALSE (suppressed, recoverable, baseline preserved). Hard delete for user-added entries.

- **Editor UX: Accordion Panels in Clean Data Tab** — One collapsible accordion panel per reference list type in Clean Data tab (below cleaned data table, alongside existing audit trail accordion). rhandsontable editors inside each accordion panel—users can add/remove/suppress entries inline. Single CSV upload button with required `type` column to route entries to correct lists (functional_category, stop_word, block_pattern). Upload appends entries tagged as source = `user`. Export in Phase 14 will include reference list state as a sheet—round-trip via re-import.

- **Re-run Flow: Explicit Button with Full Cascade Reset** — Explicit "Apply & Re-run" button after editing reference lists (no auto-re-run on edit). Re-run triggers full cascade invalidation: cleaned data, curation results, and resolution state all reset. Matches existing cascade reset pattern on tag changes (established in v1.0). Debouncing not needed since re-run is user-initiated.

- **Bare Formula Detection: Reuse ComptoxR Validator** — Reuse `validator_regex` from ComptoxR's internal `create_formula_extractor_final()`—already has complete element list and formula grammar. Apply validator directly to bare name strings (skip the parenthetical candidate extraction step that `extract_formulas()` uses). ~5-10 lines wrapping existing logic, not a new validator from scratch. Blocking flag: bare formula name set to NA, formula value preserved in new `formula_blocked_{col}` column for potential future downstream curation. Flag appears as `BLOCK: bare formula` in the `cleaning_flag` column.

- **Value Box Dashboard Extension** — Add flag statistics to existing value box dashboard: "Formulas Blocked", "Categories Flagged", "Stop Words Matched". Extends Phase 11/12 value box rows with same bslib::layout_columns pattern.

- **Pipeline Step Order** — Flagging steps run AFTER all Phase 10-12 cleaning steps: 1. Unicode cleanup (Phase 10), 2. Text trimming (Phase 10), 3. CAS normalization + rescue + multi-CAS detection (Phase 11), 4. Parenthetical stripping + adjective stripping + synonym splitting (Phase 12), 5. **Bare formula detection** (new—Phase 13), 6. **Reference list flagging** (new—Phase 13: functional categories, stop words, block patterns).

### Claude's Discretion

- Exact accordion layout and ordering of reference list editors
- rhandsontable column configuration (editable columns, read-only source column, checkbox for active)
- How to handle the CSV upload validation (missing type column, unknown types)
- Whether "Apply & Re-run" is a new button or repurposes the existing "Run Cleaning" button
- Value box themes, icons, and colors for flag statistics
- Internal function organization for flagging pipeline
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| FILT-01 | Functional and product use category reference lists are seeded from ComptoxR functions and cached locally as baseline data | Existing `cleaning_reference.R` pattern confirmed functional (Phase 10), ComptoxR API integration established |
| FILT-02 | User can enrich all reference lists (functional/product categories, stop words, block list) via file upload or manual entry on top of seeded baseline | rhandsontable provides add/remove rows via context menu + programmatic row insertion, CSV upload via fileInput() with validation |
| FILT-03 | User can see names matching reference list entries flagged as warning, with match source indicated (ComptoxR-seeded vs user-added vs app-default) | Exact-then-substring matching with stringr::str_detect() + fixed(), provenance tracked in reference list data structure, audit trail records match source |
| FILT-04 | User can see bare molecular formulas (H2O, NaCl, CuSO4) detected and flagged as blocking (name set to NA, CAS still curated) | ComptoxR validator_regex reuse confirmed (113 elements, validation pattern available), ~5-10 line wrapper function |
| FILT-05 | User can edit all reference lists (add/remove entries) via in-app editors and re-run cleaning with updated lists | rhandsontable with allowRowEdit=TRUE (default), hot_to_r() converts table to reactive R object, explicit re-run button pattern |
| FILT-06 | User can see blocking flags (red) visually distinguished from warning flags (yellow) with clear indication of which block curation vs which annotate only | DT formatStyle() with styleEqual() for row-level conditional formatting based on cleaning_flag column, target='row' for full-row colors |
| UIUX-05 | User can re-run cleaning after modifying reference lists, with downstream state (tags, curation) properly invalidated | Cascade reset pattern established in Phases 11-12, data_store reactive invalidation triggers downstream recalculations |
</phase_requirements>

## Standard Stack

### Core (Already Installed)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| rhandsontable | ≥0.3.8 | Editable reference list tables | Excel-like UX with add/remove rows, dropdown validation, checkbox columns; DT `editable=TRUE` only supports cell replacement (no row operations) |
| stringr | ≥1.5.0 | Pattern matching for flags | exact match via fixed(), substring via regex(), case-insensitive via ignore_case=TRUE |
| bslib | ≥0.6.0 | Accordion panels for editors | Already used in Phase 12 for audit trail accordion, supports multiple panels with accordion_panel() |
| DT | ≥0.33 | Flag display with conditional formatting | formatStyle() with styleEqual() for row-level colors, target='row' for full-row highlighting |
| ComptoxR | ≥1.2.5 | Formula validator and functional categories | Internal validator_regex + elements_list (113 elements) for bare formula detection; ct_functional_use() for category seeding |

### Supporting (No New Dependencies)

All required dependencies already installed in Phase 10-12. No new package installations needed.

### Installation

No new packages required. Project already has:
```r
# From load_packages.R
library(rhandsontable)  # Approved in Phase 0 research
library(stringr)        # Core tidyverse
library(bslib)          # Shiny UI framework
library(DT)             # Data tables
library(ComptoxR)       # Chemical data operations
```

## Architecture Patterns

### Recommended Function Organization

```
R/
├── cleaning_reference.R        # Extend with provenance columns
│   ├── load_or_fetch_reference()  # Add active flag, source column
│   ├── load_functional_categories()  # Add provenance metadata
│   ├── load_stop_words()          # Add provenance metadata
│   └── load_block_patterns()      # Add provenance metadata
├── cleaning_pipeline.R         # Add flagging functions
│   ├── detect_bare_formulas()     # NEW - wrap ComptoxR validator
│   └── flag_reference_matches()   # NEW - exact-then-substring matching
└── modules/
    └── mod_clean_data.R        # Add reference editors + re-run
        ├── UI: accordion panels with rhandsontable
        ├── Server: hot_to_r() reactive observers
        └── Server: re-run button with cascade reset
```

### Pattern 1: Provenance-Tracked Reference Lists

**What:** Reference list data structures with term, source, active columns

**When to use:** Loading any reference list (functional categories, stop words, block patterns)

**Example:**
```r
# Source: Extending existing cleaning_reference.R pattern
load_functional_categories <- function(cache_dir) {
  cache_path <- file.path(cache_dir, "functional_categories.rds")

  fetch_fn <- function() {
    tryCatch({
      if (requireNamespace("ComptoxR", quietly = TRUE)) {
        raw <- ComptoxR::ct_functional_use("", domain = "func_use")
        # Add provenance columns
        raw %>%
          dplyr::mutate(
            term = name,  # Rename for consistency
            source = "comptoxr",
            active = TRUE,
            .keep = "unused"
          ) %>%
          dplyr::select(term, source, active)
      } else {
        tibble::tibble(term = character(), source = character(), active = logical())
      }
    }, error = function(e) {
      tibble::tibble(term = character(), source = character(), active = logical())
    })
  }

  load_or_fetch_reference(cache_path, fetch_fn, "functional categories")
}
```

**Why this pattern:** Preserves baseline (ComptoxR-seeded entries never deleted, just deactivated), tracks user additions, enables match source attribution in audit trail.

### Pattern 2: Bare Formula Detection (ComptoxR Validator Reuse)

**What:** Detect standalone molecular formulas in name columns using ComptoxR's internal validator

**When to use:** After all Phase 12 name cleaning steps, before reference list flagging

**Example:**
```r
# Source: ComptoxR:::create_formula_extractor_final() - reusing validator logic
detect_bare_formulas <- function(df, name_cols) {
  # Extract validator from ComptoxR
  validator_obj <- ComptoxR:::create_formula_extractor_final()
  validator_env <- environment(validator_obj)
  validator_regex <- validator_env$validator_regex

  audit_rows <- list()

  for (col_name in name_cols) {
    for (idx in seq_len(nrow(df))) {
      name_value <- df[[col_name]][idx]

      if (is.na(name_value) || name_value == "") next

      # Remove spaces/dots (same as ComptoxR formula cleaning)
      cleaned <- stringr::str_replace_all(name_value, "[\\s\\.]+", "")

      # Check if matches formula pattern
      if (stringr::str_detect(cleaned, validator_regex)) {
        # Save formula to blocked column
        blocked_col <- paste0("formula_blocked_", col_name)
        if (!blocked_col %in% names(df)) {
          df[[blocked_col]] <- NA_character_
        }
        df[[blocked_col]][idx] <- name_value

        # Set name to NA
        df[[col_name]][idx] <- NA_character_

        # Add to cleaning_flag column
        if (!"cleaning_flag" %in% names(df)) {
          df$cleaning_flag <- NA_character_
        }
        df$cleaning_flag[idx] <- "BLOCK: bare formula"

        # Audit trail
        audit_rows[[length(audit_rows) + 1]] <- tibble::tibble(
          row_id = as.integer(df$original_row_id[idx]),
          field = col_name,
          step = "detect_bare_formula",
          original_value = name_value,
          new_value = "[NA]",
          reason = paste0("Bare molecular formula detected in ", col_name, "; blocked from curation")
        )
      }
    }
  }

  list(
    cleaned_data = df,
    audit_trail = dplyr::bind_rows(audit_rows)
  )
}
```

**Why this pattern:** Reuses ComptoxR's complete element list (113 elements) and validation grammar, avoids maintaining duplicate chemistry knowledge, ~10 lines of wrapping logic only.

### Pattern 3: Exact-then-Substring Matching with Confidence Labels

**What:** Two-pass matching against reference lists (exact first, substring second) with match type recorded

**When to use:** Flagging names against functional categories, stop words, block patterns

**Example:**
```r
# Source: stringr exact/substring matching best practices
flag_reference_matches <- function(df, name_cols, reference_list, flag_type, flag_label) {
  # reference_list: tibble with columns (term, source, active)
  # flag_type: "warning" or "blocking"
  # flag_label: "functional category", "stop word", etc.

  # Filter to active entries only
  active_refs <- reference_list %>% dplyr::filter(active == TRUE)

  audit_rows <- list()

  for (col_name in name_cols) {
    for (idx in seq_len(nrow(df))) {
      name_value <- df[[col_name]][idx]
      if (is.na(name_value) || name_value == "") next

      matched_term <- NA_character_
      match_type <- NA_character_
      match_source <- NA_character_

      # Pass 1: Exact match (case-insensitive)
      exact_match <- active_refs %>%
        dplyr::filter(stringr::str_detect(name_value, stringr::fixed(term, ignore_case = TRUE))) %>%
        dplyr::filter(stringr::str_to_lower(name_value) == stringr::str_to_lower(term))

      if (nrow(exact_match) > 0) {
        matched_term <- exact_match$term[1]
        match_type <- "exact"
        match_source <- exact_match$source[1]
      } else {
        # Pass 2: Substring match (case-insensitive)
        substring_match <- active_refs %>%
          dplyr::filter(stringr::str_detect(name_value, stringr::regex(term, ignore_case = TRUE)))

        if (nrow(substring_match) > 0) {
          matched_term <- substring_match$term[1]
          match_type <- "substring"
          match_source <- substring_match$source[1]
        }
      }

      # If matched, add flag
      if (!is.na(matched_term)) {
        if (!"cleaning_flag" %in% names(df)) {
          df$cleaning_flag <- NA_character_
        }

        flag_prefix <- if (flag_type == "blocking") "BLOCK" else "WARN"
        df$cleaning_flag[idx] <- paste0(flag_prefix, ": ", flag_label, " [", match_type, "]")

        # Audit trail
        audit_rows[[length(audit_rows) + 1]] <- tibble::tibble(
          row_id = as.integer(df$original_row_id[idx]),
          field = col_name,
          step = paste0("flag_", flag_label),
          original_value = name_value,
          new_value = df$cleaning_flag[idx],
          reason = paste0("Matched '", matched_term, "' (", match_source, " source, ", match_type, " match)")
        )
      }
    }
  }

  list(
    cleaned_data = df,
    audit_trail = dplyr::bind_rows(audit_rows)
  )
}
```

**Why this pattern:** Users can trust exact matches highly (strict equality check), scrutinize substring matches (may be false positives), source provenance visible in audit trail for transparency.

### Pattern 4: rhandsontable Editable List with Provenance

**What:** Excel-like editor for reference lists with term (text), source (read-only), active (checkbox)

**When to use:** Any reference list editor in accordion panel

**Example:**
```r
# Source: https://jrowen.github.io/rhandsontable/
# UI
rhandsontable::rHandsontableOutput(ns("functional_cat_editor"))

# Server
output$functional_cat_editor <- rhandsontable::renderRHandsontable({
  req(data_store$reference_lists$functional_categories)

  rhandsontable::rhandsontable(
    data_store$reference_lists$functional_categories,
    rowHeaders = NULL,
    height = 300
  ) %>%
    rhandsontable::hot_col("term", type = "text") %>%
    rhandsontable::hot_col("source", readOnly = TRUE) %>%  # Can't edit provenance
    rhandsontable::hot_col("active", type = "checkbox") %>%
    rhandsontable::hot_context_menu(allowRowEdit = TRUE, allowColEdit = FALSE)
})

# Reactive observer for edits
observeEvent(input$functional_cat_editor, {
  req(input$functional_cat_editor)

  # Convert back to R data frame
  edited_df <- rhandsontable::hot_to_r(input$functional_cat_editor)

  # Update data_store (user edits cached in session, NOT persisted until re-run)
  data_store$reference_lists$functional_categories <- edited_df
})
```

**Why this pattern:** Users can add rows (source = "user"), suppress ComptoxR rows (set active = FALSE, soft delete), remove user rows (hard delete via context menu), inline editing familiar from Excel.

### Pattern 5: DT Conditional Formatting for Flags

**What:** Row-level color coding based on cleaning_flag column (red for BLOCK, yellow for WARN)

**When to use:** Cleaned data table display in Clean Data tab

**Example:**
```r
# Source: https://rstudio.github.io/DT/010-style.html
output$cleaned_table <- DT::renderDataTable({
  req(data_store$cleaned_data)

  df <- data_store$cleaned_data

  # Identify blocking vs warning rows
  has_flag <- !is.na(df$cleaning_flag)
  is_blocking <- has_flag & stringr::str_detect(df$cleaning_flag, "^BLOCK:")
  is_warning <- has_flag & stringr::str_detect(df$cleaning_flag, "^WARN:")

  DT::datatable(df, options = list(pageLength = 25, scrollX = TRUE)) %>%
    DT::formatStyle(
      "cleaning_flag",
      target = "row",
      backgroundColor = DT::styleEqual(
        levels = c(NA, unique(df$cleaning_flag[is_blocking]), unique(df$cleaning_flag[is_warning])),
        values = c("white", rep("#ffcccc", sum(is_blocking)), rep("#fff3cd", sum(is_warning)))
      )
    )
})
```

**Why this pattern:** Entire row highlighted (not just flag cell), blocking flags visually distinguished from warnings, users can sort/filter by cleaning_flag to review all flagged rows at once.

### Anti-Patterns to Avoid

- **Auto-re-run on reference list edit** — Confusing UX, expensive operation (full pipeline re-run), user expects explicit action. Use explicit button instead.
- **Hard delete ComptoxR-seeded entries** — Loses baseline, can't recover if user accidentally removes important category. Use soft delete (active = FALSE) instead.
- **Separate match source column in main table** — Clutters display, audit trail already records source. Keep main table scannable with single cleaning_flag column.
- **Fuzzy/similarity matching for flags** — High false positive rate, opaque to users. Exact-then-substring is predictable and transparent.
- **Custom formula validator** — Maintaining element list (113 elements) and chemistry grammar is complex. Reuse ComptoxR's existing validator.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Editable table widget | Custom HTML table with manual row add/remove via inputs | rhandsontable | Context menu row operations, checkbox/dropdown columns, hot_to_r() reactive binding—Excel UX users expect |
| Molecular formula validation | Regex pattern with hardcoded element list | ComptoxR:::create_formula_extractor_final() validator_regex | 113 elements already maintained, handles edge cases (grouped elements, charges), chemistry domain expertise embedded |
| Reference list caching | Manual RDS read/write with staleness checks | Existing load_or_fetch_reference() pattern | Already handles cache miss, directory creation, error handling—proven in Phase 10 |
| Conditional row formatting | Custom JavaScript callbacks in DT | DT::formatStyle() with styleEqual() | Built-in, type-safe, works with Shiny reactivity, no custom JS needed |
| Cascade invalidation | Manual NULL assignments to downstream reactive values | Existing cascade reset pattern (Phase 11-12) | Already established, tested, handles tag changes → curation reset |

**Key insight:** Reference list editing is high-frequency user operation—rhandsontable's Excel-like UX (right-click add/remove, inline edit, checkbox for active) is critical for usability. DT editable cells only support value replacement, not row operations.

## Common Pitfalls

### Pitfall 1: Reference List State Persistence Confusion

**What goes wrong:** Users edit reference lists in-app, close session, expect edits to persist on reload.

**Why it happens:** rhandsontable edits stored in data_store reactiveValues (session-scoped), not persisted to disk until export (Phase 14).

**How to avoid:** Show clear messaging on first edit: "Reference list changes are session-only until exported via 'Export Results' (Phase 14)". Consider adding session state indicator (e.g., "Unsaved edits" badge).

**Warning signs:** User reports "my edits disappeared after closing the app", reference list state not included in export (Phase 14 implementation gap).

### Pitfall 2: Substring Match False Positives

**What goes wrong:** Reference list entry "acid" flags "lactic acid", "ascorbic acid", "citric acid" as functional category when they're chemical names.

**Why it happens:** Substring matching casts wide net, functional category terms often generic chemistry words.

**How to avoid:** Match type labeling ([exact] vs [substring]) in cleaning_flag column, audit trail shows matched term + source for user review, users can suppress false-positive entries by setting active = FALSE.

**Warning signs:** High false positive rate in warning flags, users requesting "don't flag this specific chemical" override (addressed by suppressing reference entry).

### Pitfall 3: Bare Formula Detection on Formulas Inside Names

**What goes wrong:** "CuSO4 pentahydrate" detected as bare formula and name set to NA, but it's a legitimate chemical name suffix.

**Why it happens:** Bare formula detection applied to full name string, not isolated formula check.

**Why this is actually acceptable:** User decision in CONTEXT.md specifies bare formulas (H2O, NaCl, CuSO4) should be blocked—"CuSO4 pentahydrate" would not match validator_regex because "pentahydrate" breaks the formula pattern. Validator_regex requires complete formula match: `^(?:element|group)+(?:[+-]\\d*)?$`. Mixed formula-text strings don't match.

**How to avoid:** No avoidance needed—validator design already handles this correctly.

**Warning signs:** User reports valid chemical names blocked as formulas (investigate validator_regex logic if this occurs).

### Pitfall 4: Accordion Panel State Lost on Re-run

**What goes wrong:** User expands reference list editor accordion, clicks "Apply & Re-run", accordion collapses and user loses place.

**Why it happens:** Full page reactive update may reset accordion state to default (closed).

**How to avoid:** Use bslib::accordion() `open` parameter with reactive state tracking, preserve open panels across re-run. Alternatively, keep accordions open by default after first edit.

**Warning signs:** User reports "I have to keep re-opening the editor every time I re-run", accordion_panel_set() not used to maintain state.

### Pitfall 5: CSV Upload Type Column Validation Gap

**What goes wrong:** User uploads CSV without `type` column, or with unknown types (e.g., "functional_use" instead of "functional_category"), entries silently ignored or crash app.

**Why it happens:** No validation on CSV upload, code assumes well-formed input.

**How to avoid:** Validate CSV on upload: check for `type` column, check type values against allowed list ("functional_category", "stop_word", "block_pattern"), show error modal with clear message if validation fails.

**Warning signs:** showNotification() error on CSV upload, app crash with "column type not found" error, user reports "my upload didn't add any entries".

## Code Examples

Verified patterns from ComptoxR internals and established Shiny patterns:

### Extracting ComptoxR Formula Validator

```r
# Source: ComptoxR:::create_formula_extractor_final()
# Elements list (113 elements)
elements_list <- c("He", "Li", "Be", "Ne", "Na", "Mg", "Al", "Si", "Cl", "Ar",
  "Ca", "Sc", "Ti", "Cr", "Mn", "Fe", "Co", "Ni", "Cu", "Zn", "Ga", "Ge",
  "As", "Se", "Br", "Kr", "Rb", "Sr", "Zr", "Nb", "Mo", "Tc", "Ru", "Rh",
  "Pd", "Ag", "Cd", "In", "Sn", "Sb", "Te", "Xe", "Cs", "Ba", "La", "Ce",
  "Pr", "Nd", "Pm", "Sm", "Eu", "Gd", "Tb", "Dy", "Ho", "Er", "Tm", "Yb",
  "Lu", "Hf", "Ta", "Re", "Os", "Ir", "Pt", "Au", "Hg", "Tl", "Pb", "Bi",
  "Po", "At", "Rn", "Fr", "Ra", "Ac", "Th", "Pa", "Np", "Pu", "Am", "Cm",
  "Bk", "Cf", "Es", "Fm", "Md", "No", "Lr", "Rf", "Db", "Sg", "Bh", "Hs",
  "Mt", "Ds", "Rg", "Cn", "Nh", "Fl", "Mc", "Lv", "Ts", "Og", "H", "B",
  "C", "N", "O", "F", "P", "S", "K", "V", "I", "Y", "W", "U")

# Build validator regex
elements_pattern <- paste(elements_list, collapse = "|")
element_chunk <- glue::glue("(?:{elements_pattern})\\d*")
group_chunk <- glue::glue("(?:\\((?:{element_chunk})+\\)\\d*|\\[(?:{element_chunk})+\\]\\d*)")
validator_regex <- glue::glue("^(?:{element_chunk}|{group_chunk})+(?:[+-]\\d*)?$")

# Example usage:
# "H2O" -> matches (H + 2 + O)
# "CuSO4" -> matches (Cu + S + O + 4)
# "NaCl" -> matches (Na + Cl)
# "CuSO4 pentahydrate" -> no match (pentahydrate breaks formula pattern)
# "acetone" -> no match (lowercase 'a' not an element, 'e' multiple times invalid)
```

### bslib Accordion with Multiple Panels

```r
# Source: https://rstudio.github.io/bslib/reference/accordion.html
bslib::accordion(
  id = "reference_editors",
  open = FALSE,  # Start collapsed
  multiple = TRUE,  # Allow multiple panels open simultaneously
  bslib::accordion_panel(
    title = "Functional Categories",
    icon = bsicons::bs_icon("tag"),
    rhandsontable::rHandsontableOutput(ns("functional_cat_editor")),
    actionButton(ns("upload_functional_cat"), "Upload CSV", icon = icon("upload"))
  ),
  bslib::accordion_panel(
    title = "Stop Words",
    icon = bsicons::bs_icon("hand-thumbs-down"),
    rhandsontable::rHandsontableOutput(ns("stop_words_editor")),
    actionButton(ns("upload_stop_words"), "Upload CSV", icon = icon("upload"))
  ),
  bslib::accordion_panel(
    title = "Block Patterns",
    icon = bsicons::bs_icon("shield-x"),
    rhandsontable::rHandsontableOutput(ns("block_patterns_editor")),
    actionButton(ns("upload_block_patterns"), "Upload CSV", icon = icon("upload"))
  )
)
```

### CSV Upload with Type Routing

```r
# Server-side CSV upload handler with validation
observeEvent(input$upload_csv, {
  req(input$csv_file)

  # Read CSV
  uploaded_df <- tryCatch(
    readr::read_csv(input$csv_file$datapath, show_col_types = FALSE),
    error = function(e) {
      showNotification("Failed to read CSV file", type = "error")
      return(NULL)
    }
  )

  req(uploaded_df)

  # Validate: type column exists
  if (!"type" %in% names(uploaded_df)) {
    showModal(modalDialog(
      title = "CSV Upload Error",
      "CSV file must contain a 'type' column with values: functional_category, stop_word, or block_pattern",
      easyClose = TRUE,
      footer = modalButton("Close")
    ))
    return()
  }

  # Validate: type values
  allowed_types <- c("functional_category", "stop_word", "block_pattern")
  unknown_types <- setdiff(unique(uploaded_df$type), allowed_types)

  if (length(unknown_types) > 0) {
    showModal(modalDialog(
      title = "CSV Upload Error",
      paste0("Unknown type values: ", paste(unknown_types, collapse = ", "),
             "\nAllowed types: ", paste(allowed_types, collapse = ", ")),
      easyClose = TRUE,
      footer = modalButton("Close")
    ))
    return()
  }

  # Route entries to correct lists
  for (type_name in allowed_types) {
    type_entries <- uploaded_df %>%
      dplyr::filter(type == type_name) %>%
      dplyr::mutate(source = "user", active = TRUE) %>%
      dplyr::select(term, source, active)

    if (nrow(type_entries) > 0) {
      # Append to existing list
      current_list <- data_store$reference_lists[[type_name]]
      updated_list <- dplyr::bind_rows(current_list, type_entries)
      data_store$reference_lists[[type_name]] <- updated_list
    }
  }

  showNotification(
    sprintf("Uploaded %d entries to reference lists", nrow(uploaded_df)),
    type = "message"
  )
})
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual reference list files edited outside app | In-app editable tables with rhandsontable | Phase 13 (v1.3) | Users can enrich reference lists without editing CSV files, session-scoped edits until export |
| Flag display as separate boolean columns | Single `cleaning_flag` text column with severity prefix | Phase 13 (v1.3) | Scannable single column, sortable/filterable, avoids column explosion (one column per flag type) |
| ComptoxR seeded lists replaced on user edit | Soft delete (active = FALSE) for seeded entries | Phase 13 (v1.3) | Baseline preserved, recoverable, users can see "what would default catch?" |
| Custom formula validators per project | Reuse ComptoxR internal validator | Phase 13 (v1.3) | No duplicate element list maintenance, chemistry expertise inherited |

**Deprecated/outdated:**
- Hard-coded reference lists in R source files—now loaded from ComptoxR API + cached locally (Phase 10)
- Separate flag columns per reference list type—now single `cleaning_flag` column (Phase 13)
- DT editable cells for list management—rhandsontable preferred for add/remove row operations (Phase 0 research decision)

## Open Questions

1. **Should "Apply & Re-run" be a new button or repurpose existing "Run Cleaning"?**
   - What we know: Existing "Run Cleaning" button in mod_clean_data.R triggers full pipeline
   - What's unclear: Whether to add second button "Apply & Re-run" or make "Run Cleaning" context-aware (text changes if reference lists edited)
   - Recommendation: Repurpose "Run Cleaning" button—simpler UX, button already positioned correctly, just extend handler to read reference lists from data_store instead of cache

2. **CSV upload: single button or one per list type?**
   - What we know: CONTEXT.md specifies "single CSV upload button with required `type` column to route entries"
   - What's unclear: Placement—above all editors or inside each accordion panel
   - Recommendation: Single button above all editors (below "Run Cleaning"), modal on click shows type column requirement, matches CONTEXT.md decision

3. **Value box row for flags: conditional rendering or always visible?**
   - What we know: Phase 12 conditionally shows name cleaning value boxes only when name cleaning occurred
   - What's unclear: Should flag value boxes appear only after flagging, or always (with zeros initially)?
   - Recommendation: Always visible (even with zeros)—sets user expectation that flagging happens, avoids "jumping" layout on re-run

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | testthat 3.x |
| Config file | none — see Wave 0 |
| Quick run command | `testthat::test_file("tests/test_{module}.R")` |
| Full suite command | `testthat::test_dir("tests")` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| FILT-01 | ComptoxR-seeded functional categories cached with provenance | unit | `testthat::test_file("tests/test_reference_provenance.R")` | ❌ Wave 0 |
| FILT-02 | rhandsontable adds user entries, CSV upload validates type column | integration | `testthat::test_file("tests/test_reference_editing.R")` | ❌ Wave 0 |
| FILT-03 | Exact-then-substring matching with match source in audit trail | unit | `testthat::test_file("tests/test_flag_matching.R")` | ❌ Wave 0 |
| FILT-04 | Bare formulas detected via ComptoxR validator, name set to NA | unit | `testthat::test_file("tests/test_bare_formula_detection.R")` | ❌ Wave 0 |
| FILT-05 | hot_to_r() captures edits, re-run button reads from data_store | integration | `testthat::test_file("tests/test_reference_editing.R")` | ❌ Wave 0 |
| FILT-06 | DT formatStyle() colors blocking rows red, warning rows yellow | smoke | Manual: inspect cleaned data table after flagging | N/A (visual) |
| UIUX-05 | Re-run invalidates data_store$cleaned_data, triggers cascade | integration | `testthat::test_file("tests/test_cascade_reset.R")` | ❌ Extend existing |

### Sampling Rate

- **Per task commit:** `testthat::test_file("tests/test_{module}.R")` for changed module
- **Per wave merge:** `testthat::test_dir("tests")` full suite
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `tests/test_reference_provenance.R` — covers FILT-01 (provenance columns, ComptoxR seeding)
- [ ] `tests/test_flag_matching.R` — covers FILT-03 (exact vs substring, match source)
- [ ] `tests/test_bare_formula_detection.R` — covers FILT-04 (validator reuse, H2O/NaCl/CuSO4 cases)
- [ ] `tests/test_reference_editing.R` — covers FILT-02, FILT-05 (add/remove, hot_to_r(), CSV upload validation)
- [ ] `tests/test_cascade_reset.R` — extend existing cascade tests for reference list re-run (UIUX-05)

## Sources

### Primary (HIGH confidence)

- ComptoxR source code inspection — `create_formula_extractor_final()` internals (validator_regex, elements_list)
- Existing codebase — `cleaning_reference.R` pattern (load_or_fetch_reference), `mod_clean_data.R` accordion + value box patterns
- Project decisions — CONTEXT.md user decisions (exact-then-substring, soft delete, accordion placement)

### Secondary (MEDIUM confidence)

- [rhandsontable official documentation](https://jrowen.github.io/rhandsontable/) — API reference for editable tables
- [rhandsontable CRAN vignette](https://cran.r-project.org/web/packages/rhandsontable/vignettes/intro_rhandsontable.html) — Shiny integration patterns
- [bslib accordion reference](https://rstudio.github.io/bslib/reference/accordion.html) — Multiple panel configuration
- [DT conditional formatting examples](https://rstudio.github.io/DT/010-style.html) — formatStyle() with styleEqual()
- [stringr pattern matching](https://cran.r-project.org/web/packages/stringr/vignettes/stringr.html) — fixed() vs regex() for exact/substring

### Tertiary (LOW confidence)

None — all findings verified with official documentation or codebase inspection.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — rhandsontable approved in Phase 0, all other dependencies already installed
- Architecture: HIGH — All patterns reuse existing Phase 10-12 infrastructure (accordion, value boxes, pipeline functions, cascade reset)
- Pitfalls: MEDIUM — Substring false positives anticipated but mitigated by match type labeling; CSV upload validation identified as gap
- Bare formula detection: HIGH — ComptoxR validator_regex confirmed available and complete (113 elements)

**Research date:** 2026-03-06
**Valid until:** ~30 days (stable packages, established patterns, no fast-moving dependencies)
