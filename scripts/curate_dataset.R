# curate_dataset.R
# Portable cleaning + curation + harmonization script
#
# Sources ChemReg's pure-logic files to get the full pipeline.
# No Shiny dependency — runs in any R session.
#
# Usage:
#   1. Set CHEMREG_ROOT to wherever you cloned/copied chemreg
#   2. Define your tag_map (which columns are Name, CASRN, Other)
#   3. Load your dataframe as `raw_df`
#   4. Fill in manual annotations in Section 5
#   5. Source this file or run interactively
#
# Output: `result` list in memory with $cleaned, $curated, $enrichment_cache, $audit

# ============================================================================
# 0. CONFIGURATION
# ============================================================================

library(dplyr)
library(stringr)
library(tibble)
library(purrr)
library(ComptoxR)

# -- Path to chemreg repo (adjust for your machine) --
CHEMREG_ROOT <- here::here()  # works if you're inside the repo; otherwise hardcode

# Source the 4 pure-logic files
source(file.path(CHEMREG_ROOT, "R", "cleaning_pipeline.R"))
source(file.path(CHEMREG_ROOT, "R", "cleaning_reference.R"))
source(file.path(CHEMREG_ROOT, "R", "curation.R"))
source(file.path(CHEMREG_ROOT, "R", "consensus.R"))

# ============================================================================
# 1. INPUT DATA
# ============================================================================

# Replace this with your actual data loading
# raw_df <- readr::read_csv("path/to/your/data.csv")
# raw_df <- readxl::read_xlsx("path/to/your/data.xlsx")
# raw_df <- your_existing_dataframe

stopifnot(
  "raw_df must exist in the environment" = exists("raw_df"),
  "raw_df must be a data.frame" = is.data.frame(raw_df)
)

# ============================================================================
# 2. COLUMN TAG MAP
# ============================================================================

# Map YOUR column names to roles. Only 3 roles matter:
#   "Name"  — chemical name columns (primary search target)
#   "CASRN" — CAS registry number columns
#   "Other" — other searchable text (synonyms, trade names, etc.)
#
# Columns not listed here are carried through untouched.

tag_map <- c(
  # "your_chemical_name_col" = "Name",
  # "your_cas_col"           = "CASRN",
  # "your_synonym_col"       = "Other"
)

stopifnot(
  "tag_map must have at least one entry" = length(tag_map) > 0,
  "tag_map values must be Name, CASRN, or Other" = all(tag_map %in% c("Name", "CASRN", "Other")),
  "all tagged columns must exist in raw_df" = all(names(tag_map) %in% names(raw_df))
)

# ============================================================================
# 3. CLEANING
# ============================================================================

message("=== CLEANING ===")

# Load reference lists (stop words, block patterns, strip terms)
# Uses disk cache in data/reference_cache/ — created on first run
ref_lists <- load_all_reference_lists(
  cache_dir = file.path(CHEMREG_ROOT, "data", "reference_cache")
)

# Run the full 19-step cleaning pipeline
# Returns: list(cleaned_data, audit_trail, new_tags)
cleaning_result <- run_cleaning_pipeline(
  df = raw_df,
  tag_map = tag_map,
  reference_lists = ref_lists
)

cleaned_df <- cleaning_result$cleaned_data
audit_trail <- cleaning_result$audit_trail

# Update tag_map if new columns were created (e.g., cas_extract_*)
if (!is.null(cleaning_result$new_tags)) {
  tag_map <- c(tag_map, cleaning_result$new_tags)
}

message(sprintf(
  "  Cleaned: %d rows (%+d from synonyms/removals), %d audit entries",
  nrow(cleaned_df),
  nrow(cleaned_df) - nrow(raw_df),
  nrow(audit_trail)
))

# ============================================================================
# 4. CURATION (API search + consensus)
# ============================================================================

message("=== CURATION ===")

# Requires ComptoxR API key — set via:
#   Sys.setenv(ctx_api_key = "your-key-here")
# Or in .Renviron

curation_result <- run_curation_pipeline(
  clean_data = cleaned_df,
  column_tags = tag_map,
  progress_callback = function(stage, msg) message(sprintf("  [%s] %s", stage, msg))
)

curated_df <- curation_result$results
dtxsid_cols <- find_dtxsid_cols(curated_df)

message(sprintf(
  "  Consensus: %d agree, %d disagree, %d caveat, %d single, %d error",
  curation_result$consensus_summary$n_agree,
  curation_result$consensus_summary$n_disagree,
  curation_result$consensus_summary$n_agree_caveat,
  curation_result$consensus_summary$n_single,
  curation_result$consensus_summary$n_error
))

# ============================================================================
# 5. MANUAL ANNOTATIONS
# ============================================================================

# Use case_when to override consensus for specific rows.
# Refer to rows by original_row_id (stable across synonym expansion)
# or by any column value that uniquely identifies the row.
#
# After manual annotations, re-run consensus to update status.

# -- Example: pin specific DTXSIDs by original_row_id --
# curated_df <- curated_df %>%
#   mutate(
#     consensus_dtxsid = case_when(
#       original_row_id == 42 ~ "DTXSID7020182",   # override: Benzene
#       original_row_id == 55 ~ "DTXSID5021821",   # override: Toluene
#       TRUE ~ consensus_dtxsid
#     ),
#     .pinned = case_when(
#       original_row_id %in% c(42, 55) ~ TRUE,
#       TRUE ~ .pinned
#     )
#   )

# -- Example: pin by chemical name pattern --
# curated_df <- curated_df %>%
#   mutate(
#     consensus_dtxsid = case_when(
#       str_detect(your_name_col, "(?i)^aspirin$") ~ "DTXSID5020108",
#       TRUE ~ consensus_dtxsid
#     ),
#     .pinned = case_when(
#       str_detect(your_name_col, "(?i)^aspirin$") ~ TRUE,
#       TRUE ~ .pinned
#     )
#   )

# -- Auto-resolve remaining disagree rows via column priority --
# Walks columns in order; picks first non-NA DTXSID for unpinned disagree rows.
# curated_df <- apply_priority_chain(
#   curated_df,
#   priority_order = dtxsid_cols,  # or reorder: c("dtxsid_cas_col", "dtxsid_name_col")
#   dtxsid_cols = dtxsid_cols
# )

# ============================================================================
# 6. ENRICHMENT (optional — fetch CASRN, formula, MW for resolved DTXSIDs)
# ============================================================================

message("=== ENRICHMENT ===")

resolved_dtxsids <- unique(na.omit(curated_df$consensus_dtxsid))

enrichment <- if (length(resolved_dtxsids) > 0) {
  enrich_candidates(resolved_dtxsids)
} else {
  list(cache = tibble(dtxsid = character(), casrn = character(),
                      molecular_formula = character(), molecular_weight = numeric()),
       failed_dtxsids = character())
}

message(sprintf(
  "  Enriched: %d DTXSIDs fetched, %d failed",
  nrow(enrichment$cache),
  length(enrichment$failed_dtxsids)
))

# Join enrichment back to curated data
curated_df <- curated_df %>%
  left_join(enrichment$cache, by = c("consensus_dtxsid" = "dtxsid"), suffix = c("", "_enriched"))

# ============================================================================
# 7. RESULT
# ============================================================================

# Everything stays in memory. Pick what you need downstream.
result <- list(
  cleaned = cleaned_df,
  curated = curated_df,
  audit_trail = audit_trail,
  enrichment_cache = enrichment$cache,
  tag_map = tag_map,
  summaries = list(
    cleaning = list(
      input_rows = nrow(raw_df),
      output_rows = nrow(cleaned_df),
      audit_entries = nrow(audit_trail)
    ),
    curation = curation_result$consensus_summary,
    search = curation_result$search_summary,
    enrichment = list(
      n_fetched = nrow(enrichment$cache),
      n_failed = length(enrichment$failed_dtxsids)
    )
  )
)

message("=== DONE ===")
message(sprintf(
  "  result$curated: %d rows x %d cols — ready for downstream use",
  nrow(result$curated),
  ncol(result$curated)
))
message("  result$cleaned, result$audit_trail, result$enrichment_cache also available")
