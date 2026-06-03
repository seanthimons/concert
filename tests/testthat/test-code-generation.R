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

test_that("generate_concert_script emits content-matched case_when overrides", {
  baseline <- init_resolution_state(tibble::tibble(
    chemical = "Acetone",
    cas_number = "67-64-1",
    consensus_status = "agree",
    consensus_dtxsid = "DTXSID7020182",
    consensus_source = "consensus",
    qc_tier = 1L
  ))
  final <- baseline
  final$row_flag <- "VERIFIED"

  script <- generate_concert_script(
    input_path = "input.csv",
    output_path = "input_curated.xlsx",
    tag_map = list(chemical = "Name", cas_number = "CASRN"),
    header_row = 1L,
    review_overrides = build_review_overrides(baseline, final)
  )

  expect_no_match(script, "wqx_threshold", fixed = TRUE)
  expect_no_match(script, "starts_with", fixed = TRUE)
  expect_no_match(script, "harmonize", fixed = TRUE)
  expect_match(script, "apply_review_overrides <- function(resolution_state)", fixed = TRUE)
  expect_match(script, "dplyr::mutate(", fixed = TRUE)
  expect_match(script, "row_flag = dplyr::case_when(", fixed = TRUE)
  expect_match(script, 'chemical == "Acetone"', fixed = TRUE)
  expect_match(script, 'cas_number == "67-64-1"', fixed = TRUE)
  expect_match(script, 'TRUE ~ row_flag', fixed = TRUE)
  expect_match(script, 'attr(apply_review_overrides, "review_override_columns")', fixed = TRUE)
  expect_match(script, "review_overrides = apply_review_overrides", fixed = TRUE)
  expect_no_match(script, "review_overrides <- tibble::tibble", fixed = TRUE)
  expect_no_match(script, "row = c(", fixed = TRUE)
  expect_no_match(script, "list(list", fixed = TRUE)
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
  expect_equal(
    apply_review_overrides(
      baseline,
      tibble::tibble(row = integer(), column = character(), value = list())
    ),
    baseline
  )
})

test_that("review overrides capture and replay manual, suggestion, skip, flags, and WQX edits", {
  baseline <- init_resolution_state(tibble::tibble(
    chemical = paste0("chem", 1:6),
    consensus_status = c("error", "suggested", "disagree", "agree", "wqx", "wqx"),
    consensus_dtxsid = c(NA_character_, rep(NA_character_, 2), "DTXSID4", rep(NA_character_, 2)),
    consensus_source = c(NA_character_, NA_character_, NA_character_, "consensus", NA_character_, NA_character_),
    qc_tier = c(4L, 3L, 3L, 1L, 3L, 3L),
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
  final$qc_tier[2] <- 1L
  final$.pinned[2] <- TRUE
  final$.resolution_method[2] <- "suggested-accept"

  final$.pinned[3] <- TRUE
  final$consensus_dtxsid[4] <- NA_character_
  final$row_flag[4] <- "BAD"
  final$wqx_override_name <- NA_character_
  final$wqx_override_name[5] <- "User WQX Name"
  final$consensus_status[6] <- "unresolvable"
  final$qc_tier[6] <- NA_integer_

  overrides <- build_review_overrides(baseline, final)
  expect_s3_class(overrides, "concert_review_override_spec")
  expect_named(overrides, c("column", "value", "signature"))
  expect_true(inherits(overrides$value, "list"))
  expect_true(inherits(overrides$signature, "list"))
  expect_false("row" %in% names(overrides))

  dtxsid_na <- which(
    overrides$column == "consensus_dtxsid" &
      vapply(overrides$value, identical, logical(1), y = NA_character_)
  )
  qc_tier_na <- which(
    overrides$column == "qc_tier" &
      vapply(overrides$value, identical, logical(1), y = NA_integer_)
  )
  expect_length(dtxsid_na, 1L)
  expect_length(qc_tier_na, 1L)

  replayed <- apply_review_overrides(baseline, overrides)

  cols <- c(
    "consensus_status",
    "consensus_dtxsid",
    "consensus_source",
    "qc_tier",
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

test_that("content-matched review overrides survive row reordering", {
  baseline <- init_resolution_state(tibble::tibble(
    chemical = c("Acetone", "Benzene", "Toluene"),
    cas_number = c("67-64-1", "71-43-2", "108-88-3"),
    consensus_status = rep("agree", 3),
    consensus_dtxsid = paste0("DTXSID", 1:3),
    consensus_source = rep("consensus", 3),
    qc_tier = rep(1L, 3)
  ))
  final <- baseline
  final$row_flag[2] <- "FOLLOW-UP"

  overrides <- build_review_overrides(baseline, final)
  replayed <- apply_review_overrides(baseline[c(3, 1, 2), ], overrides)

  expect_equal(replayed$row_flag[replayed$chemical == "Benzene"], "FOLLOW-UP")
  expect_true(all(is.na(replayed$row_flag[replayed$chemical != "Benzene"])))
})

test_that("duplicate stable-content rows require identical intended edits", {
  baseline <- init_resolution_state(tibble::tibble(
    chemical = c("Acetone", "Acetone"),
    cas_number = c("67-64-1", "67-64-1"),
    consensus_status = c("agree", "agree"),
    consensus_dtxsid = c("DTXSID1", "DTXSID1"),
    consensus_source = c("consensus", "consensus"),
    qc_tier = c(1L, 1L)
  ))

  ambiguous <- baseline
  ambiguous$row_flag[1] <- "VERIFIED"
  expect_error(
    build_review_overrides(baseline, ambiguous),
    "ambiguous"
  )

  identical_edits <- baseline
  identical_edits$row_flag <- c("VERIFIED", "VERIFIED")
  overrides <- build_review_overrides(baseline, identical_edits)

  expect_equal(nrow(overrides), 1L)
  replayed <- apply_review_overrides(baseline, overrides)
  expect_equal(replayed$row_flag, c("VERIFIED", "VERIFIED"))
})

test_that("generated case_when branches preserve typed NA values", {
  baseline <- init_resolution_state(tibble::tibble(
    chemical = c("Acetone", "Benzene"),
    cas_number = c("67-64-1", "71-43-2"),
    consensus_status = c("agree", "agree"),
    consensus_dtxsid = c("DTXSID1", "DTXSID2"),
    consensus_source = c("consensus", "consensus"),
    qc_tier = c(1L, 1L)
  ))
  final <- baseline
  final$consensus_dtxsid[1] <- NA_character_
  final$qc_tier[2] <- NA_integer_

  script <- generate_concert_script(
    input_path = "input.csv",
    output_path = "input_curated.xlsx",
    tag_map = list(chemical = "Name", cas_number = "CASRN"),
    header_row = 1L,
    review_overrides = build_review_overrides(baseline, final)
  )

  expect_match(script, "NA_character_", fixed = TRUE)
  expect_match(script, "NA_integer_", fixed = TRUE)
  expect_match(script, "consensus_dtxsid = dplyr::case_when(", fixed = TRUE)
  expect_match(script, "qc_tier = dplyr::case_when(", fixed = TRUE)
})

test_that("function review overrides initialize target columns before replay", {
  baseline <- tibble::tibble(
    chemical = "Acetone",
    consensus_status = "agree",
    consensus_dtxsid = "DTXSID1",
    consensus_source = "consensus"
  )

  review_fn <- function(resolution_state) {
    resolution_state |>
      dplyr::mutate(
        row_flag = dplyr::case_when(
          chemical == "Acetone" ~ "VERIFIED",
          TRUE ~ row_flag
        ),
        manual_preferredName = dplyr::case_when(
          chemical == "Acetone" ~ "Manual Acetone",
          TRUE ~ manual_preferredName
        )
      )
  }
  attr(review_fn, "review_override_columns") <- c("row_flag", "manual_preferredName")

  replayed <- apply_review_overrides(baseline, review_fn)

  expect_equal(replayed$row_flag, "VERIFIED")
  expect_equal(replayed$manual_preferredName, "Manual Acetone")
})

test_that("legacy nested-list review overrides still replay correctly", {
  baseline <- init_resolution_state(tibble::tibble(
    consensus_status = c("agree", "error"),
    consensus_dtxsid = c("DTXSID1", NA_character_),
    consensus_source = c("consensus", NA_character_),
    qc_tier = c(1L, 3L)
  ))

  legacy_overrides <- list(
    list(
      row = 2L,
      values = list(
        consensus_status = "manual",
        consensus_dtxsid = "DTXSID2",
        consensus_source = "manual_entry",
        qc_tier = NA_integer_,
        .pinned = TRUE,
        .manual_entry = TRUE,
        row_flag = "VERIFIED"
      )
    )
  )

  replayed <- apply_review_overrides(baseline, legacy_overrides)

  expect_equal(replayed$consensus_status, c("agree", "manual"))
  expect_equal(replayed$consensus_dtxsid, c("DTXSID1", "DTXSID2"))
  expect_equal(replayed$consensus_source, c("consensus", "manual_entry"))
  expect_identical(replayed$qc_tier, c(1L, NA_integer_))
  expect_equal(replayed$.pinned, c(FALSE, TRUE))
  expect_equal(replayed$.manual_entry, c(FALSE, TRUE))
  expect_equal(replayed$row_flag, c(NA_character_, "VERIFIED"))
})

test_that("legacy positional table review overrides still replay correctly", {
  baseline <- init_resolution_state(tibble::tibble(
    consensus_status = c("agree", "error"),
    consensus_dtxsid = c("DTXSID1", NA_character_),
    consensus_source = c("consensus", NA_character_),
    qc_tier = c(1L, 3L)
  ))

  replayed <- apply_review_overrides(
    baseline,
    tibble::tibble(
      row = c(2L, 2L),
      column = c("row_flag", "qc_tier"),
      value = list("VERIFIED", NA_integer_)
    )
  )

  expect_equal(replayed$row_flag, c(NA_character_, "VERIFIED"))
  expect_identical(replayed$qc_tier, c(1L, NA_integer_))
})

test_that("curate_headless applies function review overrides after automated curation replay", {
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
  seen_tags <- NULL

  review_fn <- function(resolution_state) {
    resolution_state |>
      dplyr::mutate(
        row_flag = dplyr::case_when(
          chemical == "Acetone" & result == "1.2" ~ "VERIFIED",
          TRUE ~ row_flag
        )
      )
  }
  attr(review_fn, "review_override_columns") <- "row_flag"

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
    review_overrides = review_fn,
    write_files = FALSE,
    verbose = FALSE
  )

  expect_equal(result$data$row_flag, "VERIFIED")
  expect_equal(seen_tags, list(chemical = "Name"))
})
