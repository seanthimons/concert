# Extracted from test-cleaning-reference.R:468

# setup ------------------------------------------------------------------------
library(testthat)
test_env <- simulate_test_env(package = "concert", path = "..")
attach(test_env, warn.conflicts = FALSE)

# prequel ----------------------------------------------------------------------
library(withr)
reference_schema <- c("term", "pattern", "match_mode", "source", "active", "notes")

# test -------------------------------------------------------------------------
candidates <- c(
    file.path(getwd(), "inst", "extdata"),
    file.path(getwd(), "..", "..", "inst", "extdata")
  )
cache_dir <- candidates[sapply(candidates, function(d) file.exists(file.path(d, "unit_conversion.rds")))][1]
if (is.na(cache_dir)) skip("unit_conversion.rds not found")
result <- load_unit_map(cache_dir)
expect_s3_class(result, "tbl_df")
expected_cols <- c("from_unit", "to_unit", "multiplier", "category", "confidence", "source")
expect_true(all(expected_cols %in% names(result)))
expect_type(result$from_unit, "character")
expect_type(result$to_unit, "character")
expect_type(result$multiplier, "double")
expect_type(result$category, "character")
expect_type(result$confidence, "character")
expect_type(result$source, "character")
expect_gte(nrow(result), 100)
