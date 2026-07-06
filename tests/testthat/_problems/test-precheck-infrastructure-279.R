# Extracted from test-precheck-infrastructure.R:279

# setup ------------------------------------------------------------------------
library(testthat)
test_env <- simulate_test_env(package = "concert", path = "..")
attach(test_env, warn.conflicts = FALSE)

# prequel ----------------------------------------------------------------------
make_isotope_lookup <- function() {
  tibble::tibble(
    shortcode = c("u234", "Pb210", "C14"),
    full_name = c("Uranium-234", "Lead-210", "Carbon-14")
  )
}

# test -------------------------------------------------------------------------
df <- tibble::tibble(name = c("acetone & ethanol", "toluene / benzene", "methanol"))
result <- precheck_multi_analyte(df, "name")
expect_true(result$should_run)
