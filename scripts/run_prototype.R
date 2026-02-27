# Prototype Pipeline Runner
#
# Demonstrates the full deduplication + tiered CompTox search pipeline
# against two datasets:
#   1. data/sample_messy.csv (7 rows)
#   2. uncurated_chemicals_2023-05-16_12-43-41.csv (first 100 rows)
#
# Usage:
#   Rscript scripts/run_prototype.R
#
# Requires:
#   - CompTox API key set via: Sys.setenv(ctx_api_key = "your-key")
#   - ComptoxR package installed

library(readr)
library(tibble)
library(dplyr)

# Source pipeline functions
source(file.path(here::here(), "R", "prototype_pipeline.R"))

# Check API key
if (!nzchar(Sys.getenv("ctx_api_key"))) {
  stop(
    "CompTox API key not set. Set it with:\n",
    '  Sys.setenv(ctx_api_key = "your-key-here")\n',
    "Or add to .Renviron: ctx_api_key=your-key-here"
  )
}

message("Pipeline runner starting...")
message(sprintf("API key: %s...%s", substr(Sys.getenv("ctx_api_key"), 1, 4), "****"))

# ============================================================================
# Dataset 1: data/sample_messy.csv (7 rows)
# ============================================================================

message("\n", strrep("=", 60))
message("=== Dataset 1: data/sample_messy.csv ===")
message(strrep("=", 60))

# File has 2 empty rows then header row, then data
df1 <- tryCatch(
  {
    readr::read_csv(
      file.path(here::here(), "data", "sample_messy.csv"),
      skip = 2,
      show_col_types = FALSE
    )
  },
  error = function(e) {
    stop("Failed to read sample_messy.csv: ", e$message)
  }
)

# Clean up: remove fully-empty and unnamed trailing columns
df1 <- df1[, colSums(!is.na(df1)) > 0]
df1 <- df1[, !grepl("^\\.\\.\\.\\d+$", names(df1))]

message(sprintf("Loaded %d rows, %d columns", nrow(df1), ncol(df1)))
message(sprintf("Columns: %s", paste(names(df1), collapse = ", ")))

# Tag Chemical as Name, CAS as CASRN
tag_map1 <- list(Chemical = "Name", CAS = "CASRN")

message("\n--- Deduplication ---")
dedup1 <- deduplicate_tagged_columns(df1, tag_map1)
message(sprintf(
  "Deduplicated: %d unique names, %d unique CAS",
  length(dedup1$unique_names), length(dedup1$unique_cas)
))

message("\n--- Tiered Search ---")
results1 <- tryCatch(
  run_tiered_search(dedup1),
  error = function(e) {
    stop("API error during tiered search: ", e$message)
  }
)

message("\n--- Mapping Results to Rows ---")
joined1 <- map_results_to_rows(df1, dedup1$dedup_key_map, results1)

message("\n--- Lookup Table (unique values) ---")
print(results1, n = 50)

message("\n--- Joined Back Table (all rows) ---")
print(joined1, n = 50)

# ============================================================================
# Dataset 2: uncurated_chemicals (first 100 rows)
# ============================================================================

message("\n", strrep("=", 60))
message("=== Dataset 2: uncurated_chemicals (first 100 rows) ===")
message(strrep("=", 60))

df2 <- tryCatch(
  {
    readr::read_csv(
      file.path(here::here(), "uncurated_chemicals_2023-05-16_12-43-41.csv"),
      col_types = "ccc_",
      n_max = 100
    )
  },
  error = function(e) {
    stop("Failed to read uncurated_chemicals CSV: ", e$message)
  }
)

message(sprintf("Loaded %d rows, %d columns", nrow(df2), ncol(df2)))
message(sprintf("Columns: %s", paste(names(df2), collapse = ", ")))

# Tag raw_chem_name as Name, raw_cas as CASRN
tag_map2 <- list(raw_chem_name = "Name", raw_cas = "CASRN")

message("\n--- Deduplication ---")
dedup2 <- deduplicate_tagged_columns(df2, tag_map2)
message(sprintf(
  "Deduplicated: %d unique names, %d unique CAS (from %d rows)",
  length(dedup2$unique_names), length(dedup2$unique_cas), nrow(df2)
))

message("\n--- Tiered Search ---")
results2 <- tryCatch(
  run_tiered_search(dedup2),
  error = function(e) {
    stop("API error during tiered search: ", e$message)
  }
)

message("\n--- Mapping Results to Rows ---")
joined2 <- map_results_to_rows(df2, dedup2$dedup_key_map, results2)

message("\n--- Lookup Table (unique values) ---")
print(results2, n = 100)

message("\n--- Joined Back Table Summary ---")
message(sprintf("Total rows in joined table: %d", nrow(joined2)))

# Summary statistics
dtxsid_cols <- grep("dtxsid", names(joined2), value = TRUE)
if (length(dtxsid_cols) > 0) {
  for (col in dtxsid_cols) {
    n_found <- sum(!is.na(joined2[[col]]))
    n_missing <- sum(is.na(joined2[[col]]))
    message(sprintf("  %s: %d found, %d missing", col, n_found, n_missing))
  }
}

# Tier breakdown
if ("source_tier" %in% names(results2)) {
  tier_counts <- table(results2$source_tier)
  message("\n--- Tier Breakdown ---")
  for (tier_name in names(tier_counts)) {
    message(sprintf("  %s: %d", tier_name, tier_counts[tier_name]))
  }
}

message("\n", strrep("=", 60))
message("Pipeline runner complete.")
message(strrep("=", 60))
