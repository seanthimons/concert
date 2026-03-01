# Phase 6: Search Pipeline Refinement - Research

**Researched:** 2026-03-01
**Domain:** R/Shiny Chemical Curation Pipeline
**Confidence:** HIGH

## Summary

Phase 6 improves chemical curation accuracy by reordering the CompTox search tier chain from (exact → starts-with → CAS) to (exact → CAS → starts-with) and enabling "Other" tagged columns to participate fully in the search and consensus workflows. Additionally, it adds a "Match Type" results column showing which tier resolved each chemical, with a transient notification summarizing tier breakdown.

**All work is code refactoring within existing functions** — no new packages, no new pipeline stages, just reordering, expanding tag inclusion, and surfacing existing `source_tier` data to the UI.

**Primary recommendation:** Implement tier reorder with 3-character minimum for starts-with, then expand "Other" tag participation, then add Match Type column. Test empirically with sample data to validate that CAS-before-starts improves consensus rates.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**"Other" Tag Behavior:**
- Treat "Other" column values as chemical names (search as Name type)
- Run full tier chain on Other values: exact → CAS → starts-with
- Multiple columns can be tagged as "Other" — each searched independently
- Other column misses handled identically to Name/CASRN misses (same error/unresolved status)
- Other column DTXSID results get equal vote weight in consensus classification

**Tier Reorder:**
- New order: exact → CAS → starts-with (CAS moves from tier 3 to tier 2)
- No migration or backward-compatibility handling — new order is strictly better
- All exact-miss values flow through CAS tier regardless of format (the CAS function already coerces and handles non-CAS values gracefully)
- Starts-with tier (now last resort) gets a 3-character minimum length filter — values shorter than 3 chars skip starts-with to avoid overly broad matches

**Search Feedback & Transparency:**
- Add a "Match Type" column to the results table showing which tier resolved each row
- Use friendly labels: "Exact Match", "CAS Lookup", "Starts-With", "No Match"
- Search summary (count breakdown by tier) shown as transient notification after search completes
- Match Type column shows tier only, not which tagged column produced the match

### Claude's Discretion

- Exact column placement of Match Type in results table
- Notification styling and duration for search summary
- Internal refactoring approach for tier reorder in `run_tiered_search()`

### Deferred Ideas (OUT OF SCOPE)

- Molecular formula search via Other columns — future phase (user mentioned having access to formula/mass searches)
- Mass-based search capability — future phase
- Badge/pill visual indicators for match tier — could replace or supplement the column approach later
- Persistent summary bar instead of notification — if users want always-visible tier breakdown

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SRCH-01 | Search tier order is exact → CAS → starts-with (starts-with moved to last resort) | Tier reorder pattern documented; CAS validation already coerces non-CAS inputs gracefully (R/curation.R lines 199-201); 3-char minimum filter prevents overly broad starts-with matches |
| SRCH-02 | "Other" tagged columns are searched against CompTox using the full search chain (exact → CAS → starts-with) | Deduplication already tracks all tag types via `dedup_key_map` (R/curation.R line 38); just add Other values to `unique_names` extraction (lines 43-46); `map_results_to_rows()` already handles all tagged columns (line 390) |
| SRCH-03 | "Other" column DTXSID results participate equally in consensus classification (same vote weight as Name/CASRN) | Consensus already auto-detects all `dtxsid_*` columns via `find_dtxsid_cols()` (R/consensus.R line 17); equal vote weight is default behavior — no code change needed, just ensure Other columns create dtxsid_* columns |

</phase_requirements>

## Standard Stack

### Core (Existing — No Additions)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| ComptoxR | 1.4.0 | CompTox API access | Project already uses custom fork; provides `ct_chemical_search_equal_bulk`, `ct_chemical_search_start_with`, `as_cas`, `is_cas` |
| dplyr | Latest CRAN | Data manipulation | Standard tidyverse tool for pipeline operations (filtering, grouping, joining) |
| tibble | Latest CRAN | Data frame creation | Used throughout curation.R for result construction |
| purrr | Latest CRAN | Functional programming | Used for `safely()` wrappers in pipeline error handling |
| shiny | Latest CRAN | Reactive framework | App infrastructure for notifications and reactive updates |

### Supporting (Existing — No Additions)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| stringr | Latest CRAN | String manipulation | If adding filtering logic for 3-char minimum (e.g., `nchar()` is base R, but `str_length()` handles UTF-8 better) |
| DT | Latest CRAN | Interactive tables | For rendering Match Type column in Review Results table |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| ComptoxR | ctxR (CRAN) | ctxR has similar functionality but different API; switching would break existing code |
| Manual tier reorder | Pipeline config file | Config adds indirection; current approach is simple function call reordering |

**Installation:**
None required — all packages already in `load_packages.R`.

## Architecture Patterns

### Recommended Project Structure

No new files. All work in existing modules:

```
R/
├── curation.R              # Modify: deduplicate_tagged_columns, run_tiered_search
├── consensus.R             # No changes (already detects all dtxsid_* columns)
app.R                       # Modify: Add Match Type column rendering, add notification
```

### Pattern 1: Tier Reordering in run_tiered_search()

**What:** Move CAS validation from tier 3 (after starts-with) to tier 2 (after exact, before starts-with).

**When to use:** When search precision should increase (exact matches first, then CAS validation, then fuzzy starts-with as last resort).

**Current flow (R/curation.R lines 274-363):**
```r
run_tiered_search <- function(dedup_result) {
  # Tier 1: Exact match on names
  exact_results <- search_exact(unique_names)
  matched_names <- exact_results$searchValue[!is.na(exact_results$dtxsid)]
  missed_names <- setdiff(unique_names, matched_names)

  # Tier 2: Starts-with fallback on misses
  sw_results <- search_starts_with(missed_names)
  sw_matched <- sw_results$searchValue[!is.na(sw_results$dtxsid)]
  still_missed <- setdiff(missed_names, sw_matched)

  # Tier 3: CAS validation (separate from Name chain)
  cas_results <- validate_and_lookup_cas(unique_cas)
}
```

**New flow (SRCH-01):**
```r
run_tiered_search <- function(dedup_result) {
  # Tier 1: Exact match on names
  exact_results <- search_exact(unique_names)
  matched_names <- exact_results$searchValue[!is.na(exact_results$dtxsid)]
  missed_names <- setdiff(unique_names, matched_names)

  # Tier 2: CAS validation on exact misses (MOVED UP)
  # Feed exact misses to CAS tier — as_cas() coerces everything gracefully
  cas_results <- validate_and_lookup_cas(missed_names)
  cas_matched <- cas_results$original_cas[!is.na(cas_results$dtxsid)]
  still_missed <- setdiff(missed_names, cas_matched)

  # Tier 3: Starts-with fallback (MOVED TO LAST, with 3-char minimum)
  # Filter: only query starts-with if string is 3+ characters
  sw_candidates <- still_missed[nchar(still_missed) >= 3]
  sw_results <- search_starts_with(sw_candidates)
}
```

**Key consideration:** `validate_and_lookup_cas()` already uses `ComptoxR::as_cas()` to normalize inputs (R/curation.R line 200). Non-CAS values get coerced to NA, then filtered out (line 217: `is_valid == TRUE`). So feeding exact misses to CAS tier is safe — it won't error on chemical names, just mark them as invalid and return no DTXSID.

**Source:** Existing codebase R/curation.R lines 176-264

### Pattern 2: Expanding Tag Type Participation in deduplicate_tagged_columns()

**What:** Add "Other" tagged column values to the `unique_names` set so they flow through the full search chain.

**When to use:** When a tag type (Other) should be treated identically to existing Name tags.

**Current extraction (R/curation.R lines 16-58):**
```r
deduplicate_tagged_columns <- function(df, tag_map) {
  name_cols <- names(tag_map)[tag_map == "Name"]
  cas_cols <- names(tag_map)[tag_map == "CASRN"]

  # Extract unique values by type
  if (length(name_cols) > 0) {
    all_names <- unlist(lapply(name_cols, function(col) df[[col]]))
    unique_names <- unique(all_names[!is.na(all_names) & all_names != ""])
  }

  if (length(cas_cols) > 0) {
    all_cas <- unlist(lapply(cas_cols, function(col) df[[col]]))
    unique_cas <- unique(all_cas[!is.na(all_cas) & all_cas != ""])
  }
}
```

**New extraction (SRCH-02):**
```r
deduplicate_tagged_columns <- function(df, tag_map) {
  name_cols <- names(tag_map)[tag_map == "Name"]
  cas_cols <- names(tag_map)[tag_map == "CASRN"]
  other_cols <- names(tag_map)[tag_map == "Other"]  # NEW

  # Extract unique values by type
  # Combine Name and Other columns into unique_names
  searchable_cols <- c(name_cols, other_cols)  # NEW

  if (length(searchable_cols) > 0) {
    all_names <- unlist(lapply(searchable_cols, function(col) df[[col]]))
    unique_names <- unique(all_names[!is.na(all_names) & all_names != ""])
  } else {
    unique_names <- character(0)
  }

  if (length(cas_cols) > 0) {
    all_cas <- unlist(lapply(cas_cols, function(col) df[[col]]))
    unique_cas <- unique(all_cas[!is.na(all_cas) & all_cas != ""])
  } else {
    unique_cas <- character(0)
  }
}
```

**Why this works:** The `dedup_key_map` (line 20-36) already tracks ALL tag types via the loop `for (col_name in names(tag_map))`. So Other columns already create dedup_key_map entries. The `map_results_to_rows()` function (lines 375-414) joins back via `dedup_key_map$dedup_key = lookup_results$searchValue`, creating `dtxsid_Other`, `preferredName_Other`, etc. columns. The consensus function `find_dtxsid_cols()` (R/consensus.R line 17) uses `grep("^dtxsid_", names(df))` to find all dtxsid columns, so it auto-detects `dtxsid_Other` without code changes.

**Source:** Existing codebase R/curation.R lines 16-58, 375-414; R/consensus.R lines 10-19

### Pattern 3: Surfacing source_tier to UI as Match Type

**What:** Map internal `source_tier` column (values: "exact", "cas", "starts_with", "miss") to user-friendly labels in DT table.

**When to use:** When backend data needs human-readable presentation in Review Results UI.

**Implementation (app.R output$curation_table):**
```r
# In server logic before rendering DT
df <- data_store$resolution_state

# Add Match Type column (friendly labels)
df$match_type <- dplyr::case_when(
  df$source_tier == "exact" ~ "Exact Match",
  df$source_tier == "cas" ~ "CAS Lookup",
  df$source_tier == "starts_with" ~ "Starts-With",
  df$source_tier == "miss" ~ "No Match",
  df$source_tier %in% c("cas_no_match", "cas_invalid") ~ "No Match",
  TRUE ~ "Unknown"
)

# Render DT with match_type visible, source_tier hidden
datatable(
  df,
  options = list(
    columnDefs = list(
      list(visible = FALSE, targets = which(names(df) == "source_tier") - 1)
    )
  )
)
```

**Notification after search (app.R observeEvent(input$run_curation)):**
```r
# After run_curation_pipeline() completes
search_summary <- curation_result$search_summary

notification_msg <- sprintf(
  "Search complete: %d exact, %d CAS, %d starts-with, %d no match",
  search_summary$n_exact,
  search_summary$n_cas_valid,
  search_summary$n_starts_with,
  search_summary$n_miss
)

showNotification(
  notification_msg,
  type = "message",
  duration = 8  # seconds
)
```

**Key consideration:** `source_tier` column already exists in pipeline output (R/curation.R line 282, 294, 310, 329). For rows with multiple tagged columns, each column has its own `source_tier_columnname` column. To create a single Match Type column, need to pick ONE source_tier per row — user decision says "tier only, not which tagged column produced the match", so pick first non-NA source_tier across all columns, or use consensus logic (if multiple columns, show tier of consensus_dtxsid source).

**Source:** Existing codebase R/curation.R lines 282-363 (source_tier assignment); app.R example notification pattern

### Anti-Patterns to Avoid

**Anti-pattern 1: Running CAS validation on already-validated CAS columns**
- **What people might do:** Feed `unique_cas` to CAS tier even after running it on exact misses
- **Why it's wrong:** CAS columns already go through `validate_and_lookup_cas()` (tier 3 in current code). If you move CAS to tier 2 on exact misses, don't double-validate the CAS columns.
- **Do this instead:** Keep CAS column validation separate from Name column CAS fallback. Only feed exact-miss Names to CAS tier, not the original `unique_cas` set.

**Anti-pattern 2: Assuming source_tier is row-level when it's column-level**
- **What people might do:** Create Match Type from `df$source_tier` when there's actually `source_tier_Name`, `source_tier_CASRN`, `source_tier_Other` columns
- **Why it's wrong:** With multiple tagged columns, each has its own source_tier. A single row might have "exact" from Name column and "cas" from CASRN column.
- **Do this instead:** Derive Match Type from `consensus_source` column — if consensus came from Name column, use `source_tier_Name`; if from CASRN, use `source_tier_CASRN`.

**Anti-pattern 3: Filtering starts-with by length after API call**
- **What people might do:** Call `search_starts_with(missed_names)` then filter results by length
- **Why it's wrong:** Wastes API calls on short strings that you'll discard anyway
- **Do this instead:** Filter `missed_names` to 3+ characters BEFORE calling `search_starts_with()`

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| CAS number normalization | Custom regex for hyphen placement | `ComptoxR::as_cas()` | Handles edge cases (leading zeros, malformed strings) |
| CAS checksum validation | Custom Luhn algorithm | `ComptoxR::is_cas()` | Already tested, handles NA inputs |
| DTXSID format validation | Custom regex `^DTXSID\\d+$` | Accept any format, let CompTox API reject invalid IDs | API is source of truth for validity |
| Fuzzy string matching | levenshtein distance on chemical names | CompTox starts-with API | CompTox already ranks results; don't re-implement fuzzy logic |

**Key insight:** CompTox API is authoritative for chemical identifier validation. Don't duplicate its logic client-side — trust the API and handle errors gracefully.

## Common Pitfalls

### Pitfall 1: Starts-With Precision Collapse (CRITICAL for SRCH-01)

**What goes wrong:** Moving starts-with to the end of the search chain (exact → CAS → starts-with) seems logical for prioritizing exact matches, but starts-with has no precision control — it returns all chemicals starting with the query string. For short queries like "Acet" or "Prop", this produces 100+ matches per query, and `slice_min(rank, n=1)` arbitrarily picks the top-ranked one, which may not be the user's intended chemical. This degrades match quality compared to exact-then-starts-with order.

**Why it happens:** The CompTox API's starts-with search is "identifier substring search" and returns all matching substances with no fuzzy matching score. When CAS search runs before starts-with, CAS failures (invalid format, no DTXSID mapping) fall through to starts-with, polluting results with unintended prefix matches.

**How to avoid:**
1. **Add 3-character minimum filter** (user decision locked this in) — only call `search_starts_with()` if query length is 3+ characters
2. **Test empirically** — run curation on sample data with both orders and compare consensus_status distributions
3. **Log tier attribution** — ensure `source_tier` column tracks which tier matched, audit post-curation
4. **Consider CAS-first only for CAS-tagged columns** — if Name columns work better with exact → starts → CAS, keep that order for Names only

**Warning signs:**
- Consensus rate drops after reordering (e.g., 85% agree → 75% agree)
- Review Results shows chemicals with names completely different from uploaded data
- Tier attribution shows unexpected starts_with dominance

**Phase to address:** This phase (Phase 6) — mitigated by 3-char minimum filter

**Source:** .planning/research/PITFALLS.md lines 36-58

### Pitfall 2: Consensus Algorithm Doesn't Weight Tag Types (CRITICAL for SRCH-02, SRCH-03)

**What goes wrong:** The consensus logic (`find_dtxsid_cols`) assumes all dtxsid_* columns are semantically equivalent. When "Other" columns become curation participants, you now have dtxsid_Name, dtxsid_CASRN, and dtxsid_Other columns. The consensus algorithm counts `k = length(dtxsid_cols)` for QC tier calculation but doesn't weight by tag type — a 2-name + 1-CAS agreement gets the same QC tier as a 3-name agreement, even though CAS is more reliable.

**Why it happens:** The original design assumed two tag types (Name, CASRN) and that all tagged columns should vote equally. Adding Other as a third type without revising consensus logic creates semantic ambiguity.

**How to avoid:**
1. **User decision: Other columns vote equally** (locked in CONTEXT.md) — this is explicit choice, so just ensure it's documented
2. **Test mixed tag scenarios** — 1 Name + 1 CAS + 1 Other (all agree), 1 Name + 1 CAS + 1 Other (Other disagrees)
3. **Consider future weighted voting** — if QC tier becomes misleading, add `mode = "weighted"` parameter to `classify_consensus()` in future phase

**Warning signs:**
- QC tiers look wrong (e.g., 1 Name + 1 Other agreement gets qc_tier=1 like 3-column full consensus)
- User confusion: "Why is my supplier code affecting chemical ID consensus?"

**Phase to address:** This phase (Phase 6) — accepted as design decision, document for future refinement

**Source:** .planning/research/PITFALLS.md lines 60-87

### Pitfall 3: DT Column Index Drift After Hiding Columns

**What goes wrong:** When hiding columns via `columnDefs: list(visible = FALSE, targets = hidden_indices)`, JavaScript callbacks using `data-row` attributes refer to R-side row indices (1-based), but DT's internal column indices (0-based) shift when columns are hidden. If you add Match Type column and hide source_tier columns, need to ensure indices are computed correctly.

**Why it happens:** The DT package maintains separate R-side (1-based with all columns) and JS-side (0-based, visible columns only) indexing.

**How to avoid:**
1. Compute `hidden_indices` as `which(names(df) %in% hidden_cols) - 1` (0-indexed for JS)
2. Test with multiple columns hidden (source_tier_Name, source_tier_CASRN, source_tier_Other)
3. Use `target = 'row'` for formatStyle to avoid index issues

**Warning signs:**
- Match Type column appears in wrong position
- formatStyle applies to wrong column

**Phase to address:** This phase (Phase 6) — test DT rendering after adding Match Type column

**Source:** .planning/research/PITFALLS.md lines 9-32

## Code Examples

Verified patterns from existing codebase:

### Tier Reordering in run_tiered_search()

```r
# Source: R/curation.R lines 274-363 (current implementation)
# Modification for SRCH-01:

run_tiered_search <- function(dedup_result) {
  all_results <- list()

  # Tier 1: Exact match on names
  if (length(dedup_result$unique_names) > 0) {
    exact_results <- search_exact(dedup_result$unique_names)

    if (nrow(exact_results) > 0) {
      exact_results$source_tier <- "exact"
      all_results[[length(all_results) + 1]] <- exact_results
    }

    matched_names <- exact_results$searchValue[!is.na(exact_results$dtxsid)]
    missed_names <- setdiff(dedup_result$unique_names, matched_names)

    # Tier 2: CAS validation on exact misses (MOVED UP)
    if (length(missed_names) > 0) {
      cas_results <- validate_and_lookup_cas(missed_names)

      if (nrow(cas_results) > 0) {
        # Convert to common format
        cas_common <- tibble::tibble(
          searchValue = cas_results$original_cas,
          dtxsid = cas_results$dtxsid,
          preferredName = cas_results$preferredName,
          searchName = dplyr::if_else(!is.na(cas_results$dtxsid), "CAS-RN", NA_character_),
          rank = cas_results$rank,
          source_tier = dplyr::case_when(
            !is.na(cas_results$dtxsid) ~ "cas",
            cas_results$is_valid == TRUE ~ "cas_no_match",
            TRUE ~ "cas_invalid"
          )
        )
        all_results[[length(all_results) + 1]] <- cas_common
      }

      cas_matched <- cas_results$original_cas[!is.na(cas_results$dtxsid)]
      still_missed <- setdiff(missed_names, cas_matched)

      # Tier 3: Starts-with on remaining misses (MOVED TO LAST, with 3-char filter)
      if (length(still_missed) > 0) {
        # Filter: only query if 3+ characters
        sw_candidates <- still_missed[nchar(still_missed) >= 3]

        if (length(sw_candidates) > 0) {
          sw_results <- search_starts_with(sw_candidates)

          if (nrow(sw_results) > 0) {
            sw_results$source_tier <- "starts_with"
            all_results[[length(all_results) + 1]] <- sw_results
          }

          sw_matched <- sw_results$searchValue[!is.na(sw_results$dtxsid)]
          final_missed <- setdiff(sw_candidates, sw_matched)
        } else {
          final_missed <- still_missed  # All too short for starts-with
        }

        # Add misses
        if (length(final_missed) > 0) {
          miss_rows <- tibble::tibble(
            searchValue = final_missed,
            dtxsid = NA_character_,
            preferredName = NA_character_,
            searchName = NA_character_,
            rank = NA_integer_,
            source_tier = "miss"
          )
          all_results[[length(all_results) + 1]] <- miss_rows
        }
      }
    }
  }

  # Original CAS column validation (unchanged)
  if (length(dedup_result$unique_cas) > 0) {
    cas_results <- validate_and_lookup_cas(dedup_result$unique_cas)
    # ... same as current implementation
  }

  dplyr::bind_rows(all_results)
}
```

### Expanding Other Tag in deduplicate_tagged_columns()

```r
# Source: R/curation.R lines 16-58 (current implementation)
# Modification for SRCH-02:

deduplicate_tagged_columns <- function(df, tag_map) {
  name_cols <- names(tag_map)[tag_map == "Name"]
  cas_cols <- names(tag_map)[tag_map == "CASRN"]
  other_cols <- names(tag_map)[tag_map == "Other"]  # NEW

  # Build dedup key map (unchanged — already handles all tag types)
  key_rows <- list()
  for (col_name in names(tag_map)) {
    tag_type <- tag_map[[col_name]]
    values <- df[[col_name]]

    for (i in seq_along(values)) {
      key_rows[[length(key_rows) + 1]] <- tibble::tibble(
        row_idx = i,
        column_name = col_name,
        tag_type = tag_type,
        dedup_key = as.character(values[i])
      )
    }
  }
  dedup_key_map <- dplyr::bind_rows(key_rows)

  # Extract unique values
  unique_names <- character(0)
  unique_cas <- character(0)

  # Combine Name and Other columns into unique_names (MODIFIED)
  searchable_cols <- c(name_cols, other_cols)

  if (length(searchable_cols) > 0) {
    all_names <- unlist(lapply(searchable_cols, function(col) df[[col]]))
    unique_names <- unique(all_names[!is.na(all_names) & all_names != ""])
  }

  if (length(cas_cols) > 0) {
    all_cas <- unlist(lapply(cas_cols, function(col) df[[col]]))
    unique_cas <- unique(all_cas[!is.na(all_cas) & all_cas != ""])
  }

  list(
    unique_names = unique_names,
    unique_cas = unique_cas,
    dedup_key_map = dedup_key_map
  )
}
```

### Adding Match Type Column to UI

```r
# Source: app.R lines 1370-1484 (output$curation_table)
# Addition for Match Type column:

output$curation_table <- renderDT({
  req(data_store$resolution_state, data_store$dtxsid_cols)

  df <- data_store$resolution_state

  # Derive Match Type from source_tier columns
  # Logic: use source_tier from the column that provided consensus_dtxsid
  df$match_type <- sapply(seq_len(nrow(df)), function(i) {
    # If consensus_source is available, use its source_tier
    source_col <- df$consensus_source[i]

    if (!is.na(source_col) && source_col != "consensus") {
      # Look for source_tier_{source_col} column
      tier_col <- paste0("source_tier_", source_col)
      if (tier_col %in% names(df)) {
        tier_val <- df[[tier_col]][i]
        return(dplyr::case_when(
          tier_val == "exact" ~ "Exact Match",
          tier_val == "cas" ~ "CAS Lookup",
          tier_val == "starts_with" ~ "Starts-With",
          tier_val %in% c("miss", "cas_no_match", "cas_invalid") ~ "No Match",
          TRUE ~ "Unknown"
        ))
      }
    }

    # Fallback: check all source_tier_* columns, pick first non-NA
    tier_cols <- grep("^source_tier_", names(df), value = TRUE)
    for (tc in tier_cols) {
      tier_val <- df[[tc]][i]
      if (!is.na(tier_val) && tier_val != "miss") {
        return(dplyr::case_when(
          tier_val == "exact" ~ "Exact Match",
          tier_val == "cas" ~ "CAS Lookup",
          tier_val == "starts_with" ~ "Starts-With",
          TRUE ~ "Unknown"
        ))
      }
    }

    return("No Match")
  })

  # Hide source_tier_* columns
  hidden_cols <- c(
    data_store$dtxsid_cols,
    grep("^preferredName_", names(df), value = TRUE),
    grep("^searchName_", names(df), value = TRUE),
    grep("^rank_", names(df), value = TRUE),
    grep("^source_tier_", names(df), value = TRUE),  # Hide internal tier columns
    ".pinned"
  )

  hidden_indices <- which(names(df) %in% hidden_cols) - 1

  # Render DT (match_type visible)
  datatable(
    df,
    options = list(
      pageLength = 25,
      scrollX = TRUE,
      dom = 'Bfrtip',
      buttons = c('copy', 'csv'),
      columnDefs = list(
        list(visible = FALSE, targets = hidden_indices)
      )
    ),
    extensions = 'Buttons',
    class = 'cell-border stripe hover compact',
    rownames = FALSE,
    filter = "top",
    escape = FALSE
  )
})
```

### Search Summary Notification

```r
# Source: app.R observeEvent(input$run_curation) (approximate location ~line 1200)
# Addition after run_curation_pipeline() completes:

observeEvent(input$run_curation, {
  req(data_store$clean, data_store$column_tags)

  withProgress(message = "Running curation pipeline...", {
    curation_result <- run_curation_pipeline(
      clean_data = data_store$clean,
      column_tags = data_store$column_tags,
      progress_callback = function(stage, msg) {
        incProgress(amount = 0.2, detail = msg)
      }
    )

    # Store results
    data_store$resolution_state <- curation_result$results
    data_store$consensus_summary <- curation_result$consensus_summary

    # Show tier breakdown notification (NEW)
    search_summary <- curation_result$search_summary

    notification_msg <- sprintf(
      "Search complete: %d exact, %d CAS, %d starts-with, %d no match",
      search_summary$n_exact,
      search_summary$n_cas_valid,
      search_summary$n_starts_with,
      search_summary$n_miss
    )

    showNotification(
      notification_msg,
      type = "message",
      duration = 8  # seconds
    )
  })
})
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Starts-with before CAS | CAS before starts-with | Phase 6 (v1.2) | Increases precision for CAS-identifiable chemicals; reduces false positives from short prefix matches |
| Name/CASRN tags only | Name/CASRN/Other tags | Phase 6 (v1.2) | Allows users to curate columns like "Supplier Code" or "Synonym" alongside standard identifiers |
| Hidden source_tier metadata | Visible Match Type column | Phase 6 (v1.2) | Improves transparency; users can see which search method resolved each chemical |
| No search summary | Transient notification | Phase 6 (v1.2) | Provides immediate feedback on search effectiveness without cluttering UI |

**Deprecated/outdated:**
- None — this is a refinement phase, not a replacement phase

## Open Questions

1. **Should CAS tier run on ALL exact misses or only CAS-like strings?**
   - What we know: `as_cas()` coerces non-CAS strings to NA, `is_cas()` returns FALSE for invalid formats
   - What's unclear: Performance impact of running CAS validation on 1000+ non-CAS chemical names
   - Recommendation: Run on all exact misses (user decision: "CAS function already coerces and handles non-CAS values gracefully"), but monitor API call volume in testing

2. **Should Match Type column show tier or tier + column name?**
   - What we know: User decision says "tier only, not which tagged column produced the match"
   - What's unclear: If user has 3 Name columns and all agree via "exact", is "Exact Match" sufficient or should it show "Exact Match (Name1)"?
   - Recommendation: Start with tier only per user decision; add column detail if user feedback requests it

3. **Should starts-with 3-char minimum be configurable?**
   - What we know: User decision locks in 3-char minimum
   - What's unclear: Should this be a function parameter or hardcoded constant?
   - Recommendation: Hardcode for v1.2 (3 chars is reasonable default), make configurable in future if users report issues

## Sources

### Primary (HIGH confidence)

- **Existing codebase:** R/curation.R (624 lines), R/consensus.R (229 lines), app.R (1719 lines) — inspected 2026-03-01
- **CONTEXT.md:** .planning/phases/06-search-pipeline-refinement/06-CONTEXT.md — user decisions gathered 2026-03-01
- **REQUIREMENTS.md:** .planning/REQUIREMENTS.md — SRCH-01, SRCH-02, SRCH-03 requirements defined 2026-03-01
- **ComptoxR package:** seanthimons/ComptoxR@1.4.0 — `as_cas()`, `is_cas()`, `ct_chemical_search_equal_bulk()`, `ct_chemical_search_start_with()` functions verified

### Secondary (MEDIUM confidence)

- **PITFALLS.md:** .planning/research/PITFALLS.md lines 36-87 — Starts-with precision collapse and consensus algorithm pitfalls documented 2026-03-01
- **ARCHITECTURE.md:** .planning/research/ARCHITECTURE.md — Integration patterns for tier reorder and Other tag expansion documented 2026-03-01
- **STACK.md:** .planning/research/STACK.md — Confirmed no new packages needed, all features achievable with existing stack

### Tertiary (LOW confidence)

- None — all findings verified via existing codebase or project documentation

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — All packages already installed, verified via load_packages.R
- Architecture: HIGH — Patterns extracted from existing codebase, verified via file inspection
- Pitfalls: MEDIUM-HIGH — Pitfall 1 (starts-with) documented in PITFALLS.md; Pitfall 2 (consensus) is design choice per user decision

**Research date:** 2026-03-01
**Valid until:** 30 days (2026-03-31) — stable codebase, R/Shiny patterns unlikely to change
