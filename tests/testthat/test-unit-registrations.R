# test-unit-registrations.R
# Tests for domain-specific unit registrations
# These units are registered by R/zzz.R on package load
#
# NOTE: No skip_if_not_installed("units") needed - units is a hard Imports
# dependency (D-03). If these tests run, units is installed.

# ---- Molarity conversions ----

test_that("M (molar) is recognized", {
  x <- units::set_units(1, "M")
  expect_true(inherits(x, "units"))
})

test_that("mM (millimolar) is recognized", {
  x <- units::set_units(1, "mM")
  expect_true(inherits(x, "units"))
})

test_that("uM (micromolar) is recognized", {
  x <- units::set_units(1, "uM")
  expect_true(inherits(x, "units"))
})

test_that("nM (nanomolar) is recognized", {
  x <- units::set_units(1, "nM")
  expect_true(inherits(x, "units"))
})

test_that("pM (picomolar) is recognized", {
  x <- units::set_units(1, "pM")
  expect_true(inherits(x, "units"))
})

test_that("M -> mM conversion is correct (x1000)", {
  x <- units::set_units(1, "M")
  y <- units::set_units(x, "mM")
  expect_equal(as.numeric(y), 1000)
})

test_that("mM -> uM conversion is correct (x1000)", {
  x <- units::set_units(1, "mM")
  y <- units::set_units(x, "uM")
  expect_equal(as.numeric(y), 1000)
})

test_that("uM -> nM conversion is correct (x1000)", {
  x <- units::set_units(1, "uM")
  y <- units::set_units(x, "nM")
  expect_equal(as.numeric(y), 1000)
})

test_that("nM -> pM conversion is correct (x1000)", {
  x <- units::set_units(1, "nM")
  y <- units::set_units(x, "pM")
  expect_equal(as.numeric(y), 1000)
})

test_that("M -> mol/L conversion is correct (x1)", {
  x <- units::set_units(1, "M")
  y <- units::set_units(x, "mol/L")
  expect_equal(as.numeric(y), 1)
})

# ---- Turbidity (dimensionless) ----

test_that("NTU is recognized", {
  x <- units::set_units(5, "NTU")
  expect_true(inherits(x, "units"))
  expect_equal(as.numeric(x), 5)
})

test_that("FTU is recognized", {
  x <- units::set_units(10, "FTU")
  expect_true(inherits(x, "units"))
})

test_that("JTU is recognized", {
  x <- units::set_units(3, "JTU")
  expect_true(inherits(x, "units"))
})

# ---- Microbial (dimensionless) ----

test_that("CFU is recognized", {
  x <- units::set_units(100, "CFU")
  expect_true(inherits(x, "units"))
})

test_that("MPN is recognized", {
  x <- units::set_units(50, "MPN")
  expect_true(inherits(x, "units"))
})

# ---- udunits2 built-in units still work ----

test_that("mg/L (udunits2 built-in) still works", {
  x <- units::set_units(1, "mg/L")
  expect_true(inherits(x, "units"))
})

test_that("ug/L -> mg/L conversion works", {
  x <- units::set_units(1000, "ug/L")
  y <- units::set_units(x, "mg/L")
  expect_equal(as.numeric(y), 1)
})
