test_that("generate_concert_script includes replay settings and combined tag map", {
  script <- generate_concert_script(
    input_path = "uploaded_filename.csv",
    output_path = "uploaded_filename_curated.xlsx",
    tag_map = list(
      chemical = "Name",
      cas = "CASRN",
      result = "Result",
      unit = "Unit",
      species = "Species",
      media = "Media"
    ),
    header_row = 4L,
    wqx_threshold = 0.91,
    starts_with = TRUE,
    harmonize = TRUE,
    review_overrides = NULL
  )

  expect_match(script, 'input_path <- "uploaded_filename.csv"', fixed = TRUE)
  expect_match(script, 'output_path <- "uploaded_filename_curated.xlsx"', fixed = TRUE)
  expect_match(script, 'chemical = "Name"', fixed = TRUE)
  expect_match(script, 'result = "Result"', fixed = TRUE)
  expect_match(script, 'species = "Species"', fixed = TRUE)
  expect_match(script, 'media = "Media"', fixed = TRUE)
  expect_match(script, "header_row = 4L", fixed = TRUE)
  expect_match(script, "wqx_threshold = 0.91", fixed = TRUE)
  expect_match(script, "starts_with = TRUE", fixed = TRUE)
  expect_match(script, "postprocess_candidates = TRUE", fixed = TRUE)
  expect_match(script, "harmonize = TRUE", fixed = TRUE)
  expect_no_match(script, "review_overrides <- NULL", fixed = TRUE)
  expect_no_match(script, "reference_lists", fixed = TRUE)
  expect_no_match(script, "unit_map", fixed = TRUE)
  expect_no_match(script, "corrections", fixed = TRUE)
  expect_no_match(script, "media_map", fixed = TRUE)
  expect_no_match(script, "write_files", fixed = TRUE)
  expect_no_match(script, "verbose", fixed = TRUE)
})

test_that("generate_concert_script omits default arguments and keeps real overrides", {
  script <- generate_concert_script(
    input_path = "input.csv",
    output_path = "input_curated.xlsx",
    tag_map = list(chemical = "Name"),
    header_row = 1L,
    review_overrides = list(list(
      row = 1L,
      values = list(row_flag = "VERIFIED")
    ))
  )

  expect_no_match(script, "wqx_threshold", fixed = TRUE)
  expect_no_match(script, "starts_with", fixed = TRUE)
  expect_no_match(script, "harmonize", fixed = TRUE)
  expect_match(script, "review_overrides <- list", fixed = TRUE)
  expect_match(script, "review_overrides = review_overrides", fixed = TRUE)
  expect_match(script, 'row_flag = "VERIFIED"', fixed = TRUE)
})

test_that("build_review_overrides returns NULL for no-change sessions", {
  baseline <- init_resolution_state(tibble::tibble(
    consensus_status = "agree",
    consensus_dtxsid = "DTXSID1",
    consensus_source = "consensus"
  ))

  expect_null(build_review_overrides(baseline, baseline))
  expect_equal(apply_review_overrides(baseline, NULL), baseline)
  expect_equal(apply_review_overrides(baseline, list()), baseline)
})

test_that("review overrides capture and replay manual, suggestion, skip, flags, and WQX edits", {
  baseline <- init_resolution_state(tibble::tibble(
    chemical = paste0("chem", 1:6),
    consensus_status = c("error", "suggested", "disagree", "agree", "wqx", "wqx"),
    consensus_dtxsid = c(NA_character_, rep(NA_character_, 2), "DTXSID4", rep(NA_character_, 2)),
    consensus_source = c(NA_character_, NA_character_, NA_character_, "consensus", NA_character_, NA_character_),
    dtxsid_chemical = c(NA_character_, "DTXSID2", "DTXSID3", "DTXSID4", NA_character_, NA_character_),
    preferredName_chemical = c(NA_character_, "Suggestion", "Candidate", "Resolved", "WQX Name", "WQX Reject")
  ))
  baseline$.suggested_column <- c(NA_character_, "dtxsid_chemical", rep(NA_character_, 4))

  final <- baseline
  final$consensus_status[1] <- "manual"
  final$consensus_dtxsid[1] <- "DTXSID999"
  final$consensus_source[1] <- "manual_entry"
  final$.manual_entry[1] <- TRUE
  final$manual_preferredName <- NA_character_
  final$manual_preferredName[1] <- "Manual Chemical"

  final$consensus_dtxsid[2] <- "DTXSID2"
  final$consensus_source[2] <- "chemical"
  final$.pinned[2] <- TRUE
  final$.resolution_method[2] <- "suggested-accept"

  final$.pinned[3] <- TRUE
  final$row_flag[4] <- "BAD"
  final$wqx_override_name <- NA_character_
  final$wqx_override_name[5] <- "User WQX Name"
  final$consensus_status[6] <- "unresolvable"

  overrides <- build_review_overrides(baseline, final)
  replayed <- apply_review_overrides(baseline, overrides)

  cols <- c(
    "consensus_status",
    "consensus_dtxsid",
    "consensus_source",
    ".pinned",
    ".manual_entry",
    ".resolution_method",
    "manual_preferredName",
    "row_flag",
    "wqx_override_name"
  )
  for (col in cols) {
    expect_equal(replayed[[col]], final[[col]], info = col)
  }
})

test_that("curate_headless applies review overrides after automated curation replay", {
  skip_if_not_installed("withr")

  input_path <- tempfile(fileext = ".csv")
  readr::write_csv(
    tibble::tibble(
      chemical = "Acetone",
      result = "1.2"
    ),
    input_path
  )
  withr::defer(unlink(input_path))

  baseline <- init_resolution_state(tibble::tibble(
    chemical = "Acetone",
    result = "1.2",
    consensus_status = "agree",
    consensus_dtxsid = "DTXSID1",
    consensus_source = "consensus"
  ))
  final <- baseline
  final$row_flag <- "VERIFIED"
  overrides <- build_review_overrides(baseline, final)
  seen_tags <- NULL

  reference_lists <- list(
    stop_words = tibble::tibble(term = character(), source = character(), active = logical()),
    functional_categories = tibble::tibble(term = character(), source = character(), active = logical()),
    block_patterns = tibble::tibble(term = character(), source = character(), active = logical()),
    strip_terms = tibble::tibble(term = character(), source = character(), active = logical()),
    isotope_lookup = tibble::tibble()
  )

  local_mocked_bindings(
    run_cleaning_pipeline = function(df, tag_map, reference_lists, ...) {
      list(cleaned_data = df, audit_trail = tibble::tibble(), new_tags = list())
    },
    run_curation_pipeline = function(clean_data, column_tags, ...) {
      seen_tags <<- column_tags
      list(
        results = baseline,
        consensus_summary = recalc_consensus_summary(baseline),
        search_summary = list(n_exact = 1, n_cas_valid = 0, n_wqx = 0, n_starts_with = 0, n_miss = 0),
        dedup_summary = list(n_names = 1, n_cas = 0)
      )
    }
  )

  result <- curate_headless(
    input_path = input_path,
    output_path = NULL,
    tag_map = list(chemical = "Name", result = "Result"),
    header_row = 1L,
    reference_lists = reference_lists,
    review_overrides = overrides,
    write_files = FALSE,
    verbose = FALSE
  )

  expect_equal(result$data$row_flag, "VERIFIED")
  expect_equal(seen_tags, list(chemical = "Name"))
})
