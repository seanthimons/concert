# Extracted from test-cleaning-reference.R:725

# prequel ----------------------------------------------------------------------
library(withr)
reference_schema <- c("term", "pattern", "match_mode", "source", "active", "notes")

# test -------------------------------------------------------------------------
cache_dir <- system.file("extdata/reference_cache", package = "concert")
result <- load_toxval_schema(cache_dir)
col_types <- sapply(result, typeof)
expect_false(any(col_types == "logical"))
expect_equal(typeof(result$dtxsid), "character")
expect_equal(typeof(result$toxval_numeric), "double")
expect_equal(typeof(result$year), "integer")
