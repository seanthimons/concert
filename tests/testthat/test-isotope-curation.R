test_that("requested radiochemical isotopes are present in isotope lookup", {
  isotope_lookup <- load_isotope_lookup(resolve_reference_cache_dir())

  requested <- c("Potassium-40", "Lead-212", "Thallium-208")
  missing <- setdiff(requested, isotope_lookup$lookup$canonical)
  if (length(missing) > 0) {
    warning(
      sprintf("ComptoxR isotope table is missing requested isotopes: %s", paste(missing, collapse = ", ")),
      call. = FALSE
    )
  }

  expect_true("Potassium-40" %in% isotope_lookup$lookup$canonical)
})

test_that("unresolved isotope matches remain searchable while pre-resolved isotopes are skipped", {
  clean_data <- tibble::tibble(
    Chemical = c("Potassium-40", "Radium-226"),
    cleaning_flag = c("isotope_match", "isotope_match"),
    isotope_dtxsid = c(NA_character_, "DTXSID8021241")
  )

  skip_rows <- get_pre_resolved_isotope_rows(clean_data)
  dedup <- deduplicate_tagged_columns(
    clean_data,
    list(Chemical = "Name"),
    skip_rows = skip_rows
  )

  expect_equal(skip_rows, 2L)
  expect_true("Potassium-40" %in% dedup$unique_names)
  expect_false("Radium-226" %in% dedup$unique_names)
})

test_that("single-column WQX rows classify as wqx consensus", {
  df <- tibble::tibble(
    Chemical = "Potassium-40",
    dtxsid = NA_character_,
    preferredName = "Potassium-40",
    source_tier = "wqx_exact"
  )

  result <- classify_consensus(df, find_dtxsid_cols(df))

  expect_equal(result$consensus_status[1], "wqx")
  expect_true(is.na(result$consensus_dtxsid[1]))
})

test_that("curation reference cache resolves bundled source cache", {
  source_cache <- file.path("..", "..", "inst", "extdata", "reference_cache")
  skip_if_not(dir.exists(source_cache))

  cache_dir <- resolve_curation_reference_cache_dir()

  expect_true(nzchar(cache_dir))
  expect_true(dir.exists(cache_dir))
  expect_true(file.exists(file.path(cache_dir, "wqx_dictionary.rds")))
})
