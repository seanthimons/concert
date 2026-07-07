mock_isotope_pt <- function(include_bi212 = FALSE) {
  isotopes <- tibble::tibble(
    element = "K",
    Z = "40",
    Name = "Potassium",
    DTXSID = "DTXSID10904161"
  )

  if (isTRUE(include_bi212)) {
    isotopes <- dplyr::bind_rows(
      isotopes,
      tibble::tibble(
        element = "Bi",
        Z = "212",
        Name = "Bismuth",
        DTXSID = "DTXSID_PT_BI212"
      )
    )
  }

  list(
    isotopes = isotopes,
    elements = tibble::tibble(
      Symbol = c("K", "Bi", "Pb", "Tl"),
      Name = c("Potassium", "Bismuth", "Lead", "Thallium")
    )
  )
}

mock_wqx_bi212 <- function() {
  tibble::tibble(
    name = "Bismuth-212",
    canonical_name = "Bismuth-212",
    type = "canonical",
    cas_number = "14913-49-6",
    group_name = "Radiochemical",
    description = NA_character_
  )
}

test_that("requested radiochemical isotopes are present in isotope lookup", {
  isotope_lookup <- load_isotope_lookup(resolve_reference_cache_dir())

  requested <- c("Potassium-40", "Lead-212", "Thallium-208", "Bismuth-212")
  missing <- setdiff(requested, isotope_lookup$lookup$canonical)

  expect_equal(missing, character(0))
  expect_equal(
    isotope_lookup$lookup$dtxsid[match("Bismuth-212", isotope_lookup$lookup$canonical)],
    "DTXSID901016091"
  )
})

test_that("isotope lookup adds missing WQX radiochemical rows with CCD DTXSID", {
  testthat::local_mocked_bindings(
    validate_and_lookup_cas = function(unique_cas) {
      expect_equal(unique_cas, "14913-49-6")
      tibble::tibble(
        original_cas = unique_cas,
        validated_cas = unique_cas,
        is_valid = TRUE,
        dtxsid = "DTXSID901016091",
        preferredName = "Bismuth-212",
        rank = 1L
      )
    },
    .package = "concert"
  )

  isotope_lookup <- .build_isotope_lookup(
    pt = mock_isotope_pt(include_bi212 = FALSE),
    wqx_dictionary = mock_wqx_bi212(),
    resolve_wqx_cas = TRUE
  )

  bi212 <- isotope_lookup$lookup[isotope_lookup$lookup$shortcode == "bi212", ]

  expect_equal(nrow(bi212), 1L)
  expect_equal(bi212$canonical, "Bismuth-212")
  expect_equal(bi212$dtxsid, "DTXSID901016091")
  expect_equal(bi212$source, "wqx_radiochemical")
})

test_that("Comptox PT isotope rows take precedence over WQX rows", {
  validate_called <- FALSE
  testthat::local_mocked_bindings(
    validate_and_lookup_cas = function(unique_cas) {
      validate_called <<- TRUE
      tibble::tibble()
    },
    .package = "concert"
  )

  isotope_lookup <- .build_isotope_lookup(
    pt = mock_isotope_pt(include_bi212 = TRUE),
    wqx_dictionary = mock_wqx_bi212(),
    resolve_wqx_cas = TRUE
  )

  bi212 <- isotope_lookup$lookup[isotope_lookup$lookup$shortcode == "bi212", ]

  expect_equal(nrow(bi212), 1L)
  expect_equal(bi212$canonical, "Bismuth-212")
  expect_equal(bi212$dtxsid, "DTXSID_PT_BI212")
  expect_equal(bi212$source, "comptox_pt")
  expect_false(validate_called)
})

test_that("refresh_isotope_cache writes rebuilt lookup", {
  withr::with_tempdir({
    built <- list(
      lookup = tibble::tibble(
        symbol = "Bi",
        mass = "212",
        element_name = "Bismuth",
        shortcode = "bi212",
        canonical = "Bismuth-212",
        dtxsid = "DTXSID901016091",
        source = "wqx_radiochemical"
      ),
      elem_alt_names = character()
    )

    testthat::local_mocked_bindings(
      .build_isotope_lookup = function(wqx_dictionary, resolve_wqx_cas) {
        expect_equal(wqx_dictionary, mock_wqx_bi212())
        expect_true(resolve_wqx_cas)
        built
      },
      .package = "concert"
    )

    result <- refresh_isotope_cache(cache_dir = ".", wqx_dictionary = mock_wqx_bi212())

    expect_true(file.exists("isotope_lookup.rds"))
    expect_equal(readRDS("isotope_lookup.rds"), built)
    expect_equal(result, built)
  })
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

test_that("BLOCK flagged rows are skipped from curation search pool", {
  clean_data <- tibble::tibble(
    Chemical = c("proprietary", "trade secret", "Acetone", "Radium-226"),
    cleaning_flag = c(
      "BLOCK: block pattern [exact]",
      "WARN: stop word [substring]; BLOCK: block pattern [substring]",
      NA_character_,
      "isotope_match"
    ),
    isotope_dtxsid = c(NA_character_, NA_character_, NA_character_, "DTXSID8021241")
  )

  skip_rows <- sort(unique(c(
    get_blocked_cleaning_rows(clean_data),
    get_pre_resolved_isotope_rows(clean_data)
  )))
  dedup <- deduplicate_tagged_columns(
    clean_data,
    list(Chemical = "Name"),
    skip_rows = skip_rows
  )

  expect_equal(skip_rows, c(1L, 2L, 4L))
  expect_false("proprietary" %in% dedup$unique_names)
  expect_false("trade secret" %in% dedup$unique_names)
  expect_true("Acetone" %in% dedup$unique_names)
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
