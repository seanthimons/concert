# Phase 49: Conflict Scoring Engine - Pattern Map

**Mapped:** 2026-05-08
**Files analyzed:** 7 (5 modified, 2 test additions, 1 new script)
**Analogs found:** 7 / 7

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `R/curation.R` (new `enrich_synonyms()`) | service | request-response / batch | `R/curation.R` `enrich_candidates()` §960-1064 | exact — same file, same incremental-caching pattern |
| `R/consensus.R` (new `compute_similarity_scores()`) | service | transform | `R/consensus.R` `classify_consensus()` / `get_resolution_options()` §190-258 | exact — same file, same pure-function-over-resolution-state pattern |
| `R/mod_run_curation.R` (wire synonym fetch + scoring) | server | request-response | `R/mod_run_curation.R` §220-264 (existing enrichment wiring) | exact — same block, same tryCatch + data_store update pattern |
| `R/mod_review_results.R` (Sim. Score colDef + modal badge) | UI server | request-response | `R/mod_review_results.R` §766-788 (WQX Conf. colDef) and §1213-1247 (candidate cards) | exact — direct template copy |
| `R/export_helpers.R` (include `similarity_score` in Curated Data sheet) | utility | transform | `R/export_helpers.R` §47-57 (enrichment left_join block) | exact — same left_join pattern |
| `tests/testthat/test-enrichment.R` (add `enrich_synonyms()` tests) | test | — | `tests/testthat/test-enrichment.R` §1-78 (existing `enrich_candidates()` tests) | exact — same mock + assertion style |
| `tests/testthat/test-consensus.R` (add `compute_similarity_scores()` tests) | test | — | `tests/testthat/test-consensus.R` §1-80 (existing consensus tests) | exact — same synthetic-df + expect_equal style |
| `scripts/prototype_conflict_scoring.R` (offline validation script) | utility | batch | `scripts/prototype_wqx_matching.R` §1-60 | exact — same structure: SETUP / GUARDS / LOAD / RUN |

---

## Pattern Assignments

### `R/curation.R` — new `enrich_synonyms()` function

**Analog:** `R/curation.R` `enrich_candidates()` (lines 960-1064)

**Imports / namespace pattern** (lines 960-966 — empty cache definition):
```r
empty_cache <- tibble::tibble(
  dtxsid            = character(0),
  casrn             = character(0),
  molecular_formula = character(0),
  molecular_weight  = numeric(0)
)
```
New function adds one column to this schema:
```r
# synonyms column appended to empty_cache in enrich_synonyms():
empty_cache <- tibble::tibble(
  dtxsid   = character(0),
  synonyms = character(0)   # pipe-joined string; NA_character_ if API returned 0 rows
)
```

**Incremental-caching pattern** (lines 979-991):
```r
dtxsids_to_fetch <- unique_dtxsids
if (!is.null(existing_cache) && nrow(existing_cache) > 0) {
  already_cached <- existing_cache$dtxsid
  dtxsids_to_fetch <- setdiff(unique_dtxsids, already_cached)
}

if (length(dtxsids_to_fetch) == 0) {
  message("[enrich] All DTXSIDs already cached — skipping API call")
  return(list(cache = existing_cache, failed_dtxsids = character(0)))
}
```

**API call + error handling pattern** (lines 996-1009):
```r
api_error <- NULL
raw <- tryCatch(
  suppressMessages(ComptoxR::ct_chemical_detail_search_bulk(dtxsids_to_fetch)),
  error = function(e) {
    message(sprintf("[enrich] API call failed: %s", conditionMessage(e)))
    api_error <<- conditionMessage(e)
    NULL
  }
)

if (!is.null(api_error)) {
  combined <- existing_cache %||% empty_cache
  return(list(cache = combined, failed_dtxsids = dtxsids_to_fetch))
}
```
Substitute `ComptoxR::ct_chemical_synonym_search_bulk(dtxsids_to_fetch)` for the synonym fetch and prefix messages with `[synonyms]`.

**Empty API response pattern** (lines 1011-1022):
```r
if (is.null(raw) || (is.data.frame(raw) && nrow(raw) == 0)) {
  message("[enrich] API returned no results")
  missing_rows <- tibble::tibble(
    dtxsid            = dtxsids_to_fetch,
    casrn             = NA_character_,
    molecular_formula = NA_character_,
    molecular_weight  = NA_real_
  )
  combined <- dplyr::bind_rows(existing_cache, missing_rows)
  return(list(cache = combined, failed_dtxsids = character(0)))
}
```
For synonyms: store `synonyms = NA_character_` in the missing_rows tibble.

**Final combine + return pattern** (lines 1055-1064):
```r
combined <- dplyr::bind_rows(existing_cache, new_cache)
message(sprintf("[enrich] Cache now has %d entries", nrow(combined)))
list(
  cache          = combined,
  failed_dtxsids = character(0)
)
```

**Synonym-specific: flatten tiers before storing** (no existing analog — new logic, derived from RESEARCH.md Pattern 1):
```r
# All tiers treated equally (D-04). Flatten into pipe-separated string.
flatten_synonym_tiers <- function(row) {
  tier_cols <- c("valid", "good", "other", "deleted", "beilstein", "alternate", "pcCode")
  syns <- unlist(lapply(tier_cols, function(col) {
    vals <- row[[col]]
    if (!is.null(vals)) as.character(unlist(vals)) else character(0)
  }))
  syns <- unique(syns[!is.na(syns) & nchar(syns) > 0])
  if (length(syns) == 0) NA_character_ else paste(syns, collapse = "|")
}
```

---

### `R/consensus.R` — new `compute_similarity_scores()` function

**Analog:** `R/consensus.R` `get_resolution_options()` (lines 190-258)

**Function signature pattern** (lines 190-193):
```r
get_resolution_options <- function(df, row_idx, dtxsid_cols, enrichment_cache = NULL) {
  if (df$consensus_status[row_idx] != "disagree") {
    return(list())
  }
```
Mirror this: `compute_similarity_scores(resolution_state, enrichment_cache, dtxsid_cols, column_tags)` — guard on `consensus_status == "disagree"` before inner work.

**Column-name derivation pattern** (lines 210-216):
```r
pref_col  <- sub("^dtxsid_", "preferredName_", col)
rank_col  <- sub("^dtxsid_", "rank_", col)
tier_col  <- sub("^dtxsid_", "source_tier_", col)
pref_name <- if (pref_col %in% names(df)) df[[pref_col]][row_idx] else NA_character_
rank_val  <- if (rank_col %in% names(df)) df[[rank_col]][row_idx] else NA_real_
```
Exact copy — same prefix substitution needed in `compute_similarity_scores()`.

**Enrichment cache lookup pattern** (lines 229-235):
```r
if (!is.null(enrichment_cache) && nrow(enrichment_cache) > 0) {
  match_idx <- which(enrichment_cache$dtxsid == val)
  if (length(match_idx) > 0) {
    enrich_casrn <- enrichment_cache$casrn[match_idx[1]]
    enrich_formula <- enrichment_cache$molecular_formula[match_idx[1]]
    enrich_mw <- enrichment_cache$molecular_weight[match_idx[1]]
  }
}
```
For synonyms, substitute:
```r
if (!is.null(enrichment_cache) && nrow(enrichment_cache) > 0 &&
    "synonyms" %in% names(enrichment_cache)) {
  match_idx <- which(enrichment_cache$dtxsid == dtxsid_val)
  if (length(match_idx) > 0) {
    synonyms_str <- enrichment_cache$synonyms[match_idx[1]]
  }
}
```

**JW similarity pattern** — from `R/wqx_matching.R` §112-116:
```r
# stringdist() returns DISTANCE (0=identical, 1=maximally different)
# Similarity = 1 - distance
dist_matrix <- stringdist::stringdistmatrix(
  names_clean[still_unresolved_idx],
  tolower(canonical_name_vec),
  method = "jw"
)
```
For scoring, use `stringdist::stringdist()` (not the matrix form — single input vs. vector):
```r
sims <- 1 - stringdist::stringdist(
  tolower(input_name),
  tolower(all_names),   # preferredName + all synonyms flattened
  method = "jw"
)
base_score <- max(sims, na.rm = TRUE)
bonus      <- if (!is.na(rank_val) && rank_val <= 3) 0.05 else 0.0
candidate_score <- min(1.0, base_score + bonus)
```

**Output column assignment pattern** — from `R/consensus.R` `classify_consensus()` style:
```r
# Assign result column back to state df, return full df
resolution_state$similarity_score <- scores
resolution_state
```

**`max()` on empty vector guard** (anti-pattern, see Pitfall 1 in RESEARCH.md):
```r
if (length(candidate_scores) > 0) {
  scores[i] <- max(candidate_scores)
}
# Do NOT call max(numeric(0)) — produces a warning and -Inf
```

---

### `R/mod_run_curation.R` — wire synonym fetch and score computation

**Analog:** `R/mod_run_curation.R` §220-264 (existing enrichment wiring)

**Enrichment call site pattern** (lines 221-254) — copy this block for synonym fetch immediately after it:
```r
if (length(all_unique_dtxsids) > 0) {
  showNotification(
    sprintf("Enriching %d candidates...", length(all_unique_dtxsids)),
    type    = "message",
    duration = 3,
    id      = "enrich-progress"
  )

  enrich_result <- enrich_candidates(
    dtxsids        = all_unique_dtxsids,
    existing_cache = data_store$enrichment_cache
  )

  data_store$enrichment_cache  <- enrich_result$cache
  data_store$enrichment_failed <- enrich_result$failed_dtxsids

  ...
}
```
Synonym fetch follows immediately after the existing block ends (line 254), inside the same `tryCatch`:
```r
# Synonym fetch — same incremental pattern as enrich_candidates()
synonym_result <- enrich_synonyms(
  dtxsids        = all_unique_dtxsids,
  existing_cache = data_store$enrichment_cache   # cache already has casrn/formula/mw
)
data_store$enrichment_cache <- synonym_result$cache
```
Then score computation:
```r
data_store$resolution_state <- compute_similarity_scores(
  resolution_state = data_store$resolution_state,
  enrichment_cache = data_store$enrichment_cache,
  dtxsid_cols      = data_store$dtxsid_cols,
  column_tags      = data_store$column_tags
)
```

**tryCatch error notification pattern** (lines 256-264):
```r
error = function(e) {
  warning(sprintf("[enrich] Enrichment failed: %s", e$message))
  showNotification(
    paste("Enrichment failed (curation results still valid):", e$message),
    type     = "warning",
    duration = 8
  )
}
```
Reuse verbatim — synonym/scoring failures are non-fatal; curation results remain valid.

---

### `R/mod_review_results.R` — Sim. Score colDef and modal badge

**Analog (colDef):** `R/mod_review_results.R` §766-788 (WQX Conf. block)

**Full WQX Conf. colDef pattern to copy** (lines 769-788):
```r
wqx_conf_cols    <- grep("^wqx_confidence", names(df_display), value = TRUE)
wqx_conf_visible <- Filter(function(col) !all(is.na(df_display[[col]])), wqx_conf_cols)
wqx_conf_hidden  <- setdiff(wqx_conf_cols, wqx_conf_visible)
for (whc in wqx_conf_hidden) {
  col_defs[[whc]] <- reactable::colDef(show = FALSE)
}
for (wcc in wqx_conf_visible) {
  col_defs[[wcc]] <- reactable::colDef(
    name     = "WQX Conf.",
    minWidth = 80,
    align    = "right",
    cell     = function(value, index) {
      if (is.na(value)) return("")
      formatC(value, digits = 2, format = "f")
    }
  )
}
```
For Sim. Score, use a simpler gate (single column, no multi-tag variants):
```r
if ("similarity_score" %in% names(df_display)) {
  col_defs[["similarity_score"]] <- reactable::colDef(
    name     = "Sim. Score",
    minWidth = 80,
    align    = "right",
    cell     = function(value, index) {
      if (is.na(value)) return("")
      formatC(value, digits = 2, format = "f")
    }
  )
}
```

**Analog (modal candidate cards):** `R/mod_review_results.R` §1213-1247

**Existing card structure to extend** (lines 1213-1247):
```r
cards <- lapply(names(options), function(col) {
  opt <- options[[col]]
  div(
    class = "candidate-card card mb-2",
    ...
    div(
      class = "d-flex justify-content-between align-items-start",
      div(
        tags$h6(class = "mb-1 fw-bold", opt$dtxsid),
        if (!is.na(opt$preferredName)) tags$p(class = "mb-1 text-muted", opt$preferredName) else NULL
      ),
      tags$button(class = "modal-select-btn btn btn-sm btn-outline-success", ...)
    ),
    tags$hr(class = "my-2"),
    div(
      class = "row small",
      div(class = "col-4", tags$strong("CASRN"), ...),
      div(class = "col-4", tags$strong("Formula"), ...),
      div(class = "col-4", tags$strong("Mol. Weight"), ...)
    ),
    ...
  )
})
```
Inject per-candidate score badge into the header `div` alongside the DTXSID heading. Compute inline using a helper `score_one_candidate()` (factored from `compute_similarity_scores()` inner loop body) — call it with `opt$dtxsid`, `opt$preferredName`, `opt$rank`, and the synonyms string from `data_store$enrichment_cache`.

---

### `R/export_helpers.R` — include `similarity_score` in Curated Data sheet

**Analog:** `R/export_helpers.R` §47-57 (enrichment left_join block)

**Existing enrichment join pattern** (lines 47-57):
```r
if (!is.null(enrichment_cache) && nrow(enrichment_cache) > 0) {
  enrich_lookup <- enrichment_cache[, c("dtxsid", "casrn", "molecular_formula", "molecular_weight")]
  names(enrich_lookup) <- c("consensus_dtxsid", "consensus_casrn", "consensus_formula", "consensus_mw")
  curated_data_sheet <- curated_data_sheet %>%
    dplyr::left_join(enrich_lookup, by = "consensus_dtxsid")
} else {
  curated_data_sheet$consensus_casrn   <- NA_character_
  curated_data_sheet$consensus_formula <- NA_character_
  curated_data_sheet$consensus_mw      <- NA_real_
}
```
`similarity_score` is already a column on `resolution_state`, so it flows through to `curated_data_sheet` automatically via the `curated_data_sheet <- resolution_state %>% ...` assignment at the top of `build_export_sheets()`. No join needed — just ensure it is not dropped by the `dplyr::select(-any_of(...))` call. Verify the exclusion list at line 44-45 does not accidentally remove it.

---

### `tests/testthat/test-enrichment.R` — new `enrich_synonyms()` tests

**Analog:** `tests/testthat/test-enrichment.R` §1-78 (existing `enrich_candidates()` tests)

**Mock + assertion pattern** (lines 5-36):
```r
test_that("enrich_candidates returns structured cache tibble for valid DTXSIDs", {
  mock_response <- tibble::tibble(
    dtxsid          = c("DTXSID7021360", "DTXSID9020584"),
    casrn           = c("108-88-3", "64-17-5"),
    molFormula      = c("C7H8", "C2H6O"),
    molecularWeight = c(92.14, 46.07)
  )

  testthat::local_mocked_bindings(
    ct_chemical_detail_search_bulk = function(...) mock_response,
    .package = "ComptoxR"
  )

  result <- enrich_candidates(dtxsids = c("DTXSID7021360", "DTXSID9020584"))

  expect_type(result, "list")
  expect_true("cache" %in% names(result))
  cache <- result$cache
  expect_s3_class(cache, "tbl_df")
  expect_true(all(c("dtxsid", "casrn", "molecular_formula", "molecular_weight") %in% names(cache)))
})
```
Adapt by mocking `ct_chemical_synonym_search_bulk` in `.package = "ComptoxR"`. Key assertions to add:
- `synonyms` column present in cache
- Pipe-joined string correct when API returns rows
- `NA_character_` stored when API returns 0 rows (Pitfall 1)
- Incremental cache skips already-cached DTXSIDs (same §42-78 pattern)

**Incremental caching test pattern** (lines 42-78):
```r
existing_cache <- tibble::tibble(
  dtxsid = "DTXSID7021360",
  casrn  = "108-88-3",
  molecular_formula = "C7H8",
  molecular_weight  = 92.14
)
result <- enrich_candidates(
  dtxsids        = c("DTXSID7021360", "DTXSID9020584"),
  existing_cache = existing_cache
)
expect_equal(nrow(result$cache), 2)
```

---

### `tests/testthat/test-consensus.R` — new `compute_similarity_scores()` tests

**Analog:** `tests/testthat/test-consensus.R` §29-80 (existing `classify_consensus()` tests)

**Synthetic df construction pattern** (lines 29-44):
```r
test_that("classify_consensus: all columns agree -> agree status", {
  df <- data.frame(
    Chemical      = c("Toluene"),
    CAS           = c("108-88-3"),
    dtxsid_Chemical = c("DTXSID7021360"),
    dtxsid_CAS    = c("DTXSID7021360"),
    stringsAsFactors = FALSE
  )
  dtxsid_cols <- c("dtxsid_Chemical", "dtxsid_CAS")

  result <- classify_consensus(df, dtxsid_cols)

  expect_equal(result$consensus_status[1], "agree")
})
```
For scoring tests, build a `resolution_state` df with `consensus_status = "disagree"` and `dtxsid_*`, `preferredName_*`, `rank_*` columns; pair with a synthetic `enrichment_cache` that has the `synonyms` column. Key test cases (from SCORE-02 requirements):
- Score is numeric for disagree rows, NA for non-disagree rows
- High-similarity pair (Silica / "Silica gel" synonym) scores higher than low-similarity pair (Silica / Estradiol)
- Rank bonus: rank ≤ 3 adds +0.05, clamped at 1.0
- Missing synonyms column in cache falls back to preferredName-only comparison (Pitfall 2)

---

### `scripts/prototype_conflict_scoring.R` — offline validation script

**Analog:** `scripts/prototype_wqx_matching.R` §1-60

**Script skeleton pattern** (lines 1-60):
```r
# prototype_conflict_scoring.R
# Standalone conflict scorer prototype — validates compute_similarity_scores()
# against a real disagree row from a live curation run.
# No Shiny dependency — runs in any R session.
#
# Prerequisites:
#   1. CompTox API key set via Sys.setenv(COMPTOX_API_KEY = "...")
#   2. R/curation.R and R/consensus.R sourced
#
# Usage: Rscript scripts/prototype_conflict_scoring.R

CONCERT_ROOT <- here::here()

source(file.path(CONCERT_ROOT, "R", "curation.R"))
source(file.path(CONCERT_ROOT, "R", "consensus.R"))
```
Follow with SETUP / PREREQUISITE GUARDS / LOAD DATA / RUN sections, matching the section-header comment style of `prototype_wqx_matching.R`.

---

## Shared Patterns

### Incremental Caching (tryCatch + bind_rows)
**Source:** `R/curation.R` `enrich_candidates()` lines 979-1064
**Apply to:** `enrich_synonyms()` in `R/curation.R`

Full pattern: filter already-cached IDs → API call in `tryCatch` → handle NULL/empty response with NA placeholder rows → `dplyr::bind_rows(existing_cache, new_cache)` → return `list(cache, failed_dtxsids)`.

### Enrichment Cache Lookup (single-column index)
**Source:** `R/consensus.R` `get_resolution_options()` lines 229-235
**Apply to:** `compute_similarity_scores()` in `R/consensus.R`, modal card building in `R/mod_review_results.R`
```r
match_idx <- which(enrichment_cache$dtxsid == val)
if (length(match_idx) > 0) {
  value <- enrichment_cache$target_col[match_idx[1]]
}
```

### Numeric Column Rendering (2-decimal, right-aligned, blank for NA)
**Source:** `R/mod_review_results.R` §776-788
**Apply to:** `similarity_score` colDef in `R/mod_review_results.R`
```r
reactable::colDef(
  name     = "...",
  minWidth = 80,
  align    = "right",
  cell     = function(value, index) {
    if (is.na(value)) return("")
    formatC(value, digits = 2, format = "f")
  }
)
```

### Presence-Gated colDef
**Source:** `R/mod_review_results.R` §769-775 (wqx_conf_visible filter)
**Apply to:** Sim. Score colDef gate in `R/mod_review_results.R`
```r
if ("similarity_score" %in% names(df_display)) {
  col_defs[["similarity_score"]] <- reactable::colDef(...)
}
```

### Non-Fatal Enrichment Error Handling
**Source:** `R/mod_run_curation.R` §256-264
**Apply to:** synonym fetch and score computation wiring in `R/mod_run_curation.R`

Pattern: wrap both calls in the same outer `tryCatch`; on failure, log with `warning()` and `showNotification(..., type = "warning")` — do not stop curation results from rendering.

### testthat Mock Pattern
**Source:** `tests/testthat/test-enrichment.R` §14-17
**Apply to:** `enrich_synonyms()` tests in `test-enrichment.R`
```r
testthat::local_mocked_bindings(
  ct_chemical_synonym_search_bulk = function(...) mock_response,
  .package = "ComptoxR"
)
```

---

## No Analog Found

All files have close analogs. No entries in this section.

---

## Metadata

**Analog search scope:** `R/`, `tests/testthat/`, `scripts/`
**Files scanned:** 10 (curation.R, consensus.R, mod_run_curation.R, mod_review_results.R, export_helpers.R, wqx_matching.R, test-enrichment.R, test-consensus.R, test-mod-review-helpers.R, prototype_wqx_matching.R)
**Pattern extraction date:** 2026-05-08
