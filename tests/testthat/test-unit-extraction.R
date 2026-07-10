# test-unit-extraction.R
# Tests for one-time unit inventory helpers.

test_that("extract_wqx_alias_units inventories unit-bearing alias patterns", {
  alias_path <- tempfile(fileext = ".csv")
  readr::write_csv(
    tibble::tibble(
      Domain = rep("Characteristic Alias()", 4),
      `Unique Identifier` = as.character(1:4),
      `Alias Name` = c(
        "Deciview|No Units|||",
        "00010 ~ Temperature, water, degrees Celsius",
        "00076 ~ Turbidity, water, unfiltered, nephelometric turbidity units",
        "01080 -- STRONTIUM SR,DISS  UG/L"
      ),
      Description = c(
        "AQS pipe-delimited alias",
        "NWIS temperature alias",
        "NWIS turbidity alias",
        "STORET code alias"
      ),
      `Characteristic Name` = c("Deciview", "Temperature, water", "Turbidity", "Strontium"),
      `Alias Type Name` = c(
        "AQS PARM CODE",
        "NWIS PARM CODE",
        "NWIS PARM CODE",
        "STORET PARM CODE"
      ),
      `Last Change Date` = rep("1/1/2026 12:00:00 AM", 4)
    ),
    alias_path
  )

  result <- concert:::extract_wqx_alias_units(alias_path)

  expect_true(all(c(
    "No Units",
    "degrees Celsius",
    "nephelometric turbidity units",
    "UG/L"
  ) %in% result$candidate_unit))
  expect_true(all(result$evidence_count >= 1))
  expect_false("conversion_factor" %in% names(result))
})
