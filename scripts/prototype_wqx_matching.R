# prototype_wqx_matching.R
# Standalone WQX matcher prototype -- validates match_wqx() against training data.
# No Shiny dependency -- runs in any R session.
#
# Prerequisites:
#   1. inst/extdata/reference_cache/wqx_dictionary.rds (built by Phase 43)
#   2. detections_uat_sample_50.csv in repo root
#
# Usage: Rscript scripts/prototype_wqx_matching.R
#
# Output: tier breakdown + fuzzy matches printed to console

# ============================================================================
# 1. SETUP
# ============================================================================

CONCERT_ROOT <- here::here()

source(file.path(CONCERT_ROOT, "R", "cleaning_reference.R"))
source(file.path(CONCERT_ROOT, "R", "wqx_matching.R"))

# ============================================================================
# 2. PREREQUISITE GUARDS
# ============================================================================

cache_path <- file.path(CONCERT_ROOT, "inst", "extdata", "reference_cache", "wqx_dictionary.rds")
stopifnot(
  "wqx_dictionary.rds not found -- run scripts/build_wqx_dictionary.R first" = file.exists(cache_path)
)

train_path <- file.path(CONCERT_ROOT, "detections_uat_sample_50.csv")
stopifnot(
  "detections_uat_sample_50.csv not found in repo root" = file.exists(train_path)
)

# ============================================================================
# 3. LOAD DICTIONARY
# ============================================================================

cache_dir <- file.path(CONCERT_ROOT, "inst", "extdata", "reference_cache")
dict <- load_wqx_dictionary(cache_dir)
message(sprintf(
  "Dictionary loaded: %d rows (%d canonical, %d alias)",
  nrow(dict),
  sum(dict$type == "canonical"),
  sum(dict$type != "canonical")
))

# ============================================================================
# 4. LOAD TRAINING DATA
# ============================================================================

train <- readr::read_csv(train_path, show_col_types = FALSE)
message(sprintf(
  "Training data loaded: %s (%d rows, analyte column: %d unique names)",
  basename(train_path),
  nrow(train),
  length(unique(train$analyte))
))

# ============================================================================
# 5. RUN MATCHER
# ============================================================================

results <- match_wqx(train$analyte, dict, threshold = 0.85, verbose = TRUE)

# ============================================================================
# 6. ACCURACY REPORT
# ============================================================================

message("\n=== TIER BREAKDOWN ===")
tier_counts <- table(results$match_tier)
print(tier_counts)

message("\n=== FUZZY MATCHES FOR REVIEW ===")
fuzzy_hits <- results[results$match_tier == "fuzzy", ]
if (nrow(fuzzy_hits) > 0) {
  print(fuzzy_hits[, c("input_name", "wqx_name", "match_distance")])
} else {
  message("  (no fuzzy matches)")
}

message("\n=== UNRESOLVED NAMES ===")
unresolved <- results[results$match_tier == "none", ]
if (nrow(unresolved) > 0) {
  print(unresolved[, c("input_name", "match_distance")])
} else {
  message("  (all names resolved)")
}

message(sprintf(
  "\n=== SUMMARY: %d/%d names resolved (%.0f%%) ===",
  sum(results$match_tier != "none"),
  nrow(results),
  100 * sum(results$match_tier != "none") / nrow(results)
))
