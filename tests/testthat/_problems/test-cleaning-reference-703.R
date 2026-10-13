# Extracted from test-cleaning-reference.R:703

# prequel ----------------------------------------------------------------------
library(withr)
reference_schema <- c("term", "pattern", "match_mode", "source", "active", "notes")

# test -------------------------------------------------------------------------
cache_dir <- system.file("extdata/reference_cache", package = "concert")
result <- load_toxval_schema(cache_dir)
expect_true("dtxsid" %in% names(result))
expect_true("casrn" %in% names(result))
expect_true("name" %in% names(result))
expect_true("toxval_type" %in% names(result))
expect_true("toxval_numeric" %in% names(result))
expect_true("toxval_units" %in% names(result))
expect_true("toxval_numeric_qualifier" %in% names(result))
expect_true("toxval_numeric_original" %in% names(result))
expect_true("toxval_units_original" %in% names(result))
expect_true("conversion_factor" %in% names(result))
expect_true("parse_flag" %in% names(result))
