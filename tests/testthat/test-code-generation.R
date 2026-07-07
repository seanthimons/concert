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

test_that("generate_concert_script embeds reference snapshot and activate-all replay setting", {
  mock_snapshot <- list(
    functional_categories = list(
      default_hash = "func-hash",
      overrides = empty_reference_list_tbl()
    ),
    stop_words = list(
      default_hash = "stop-hash",
      overrides = tibble::tibble(
        term = "field blank",
        pattern = "field blank",
        match_mode = "literal_word",
        source = "user",
        active = TRUE,
        notes = NA_character_
      )
    ),
    block_patterns = list(
      default_hash = "block-hash",
      overrides = empty_reference_list_tbl()
    ),
    strip_terms = list(
      default_hash = "strip-hash",
      overrides = empty_reference_list_tbl()
    )
  )

  local_mocked_bindings(
    build_reference_list_snapshot = function(reference_lists, cache_dir = NULL) mock_snapshot
  )

  script <- generate_concert_script(
    input_path = "input.csv",
    output_path = "input_curated.xlsx",
    tag_map = list(chemical = "Name", cas_number = "CASRN"),
    header_row = 1L,
    reference_lists = list(stop_words = tibble::tibble()),
    activate_all_references = TRUE
  )

  expect_match(script, "reference_list_snapshot <- list(", fixed = TRUE)
  expect_match(script, 'term = "field blank"', fixed = TRUE)
  expect_match(script, "reference_list_snapshot = reference_list_snapshot", fixed = TRUE)
  expect_match(script, "activate_all_references = TRUE", fixed = TRUE)
  expect_no_match(script, "reference_lists =", fixed = TRUE)
  expect_silent(parse(text = script))
})

test_that("compact reference snapshot literal round-trips through normalization", {
  overrides <- tibble::tibble(
    term = c("additive", "isomer", "na", "unknown"),
    pattern = c("additive", "isomer", "na", "unknown"),
    match_mode = rep("literal_word", 4),
    source = c("legacy_review", "user", "legacy_seed", "legacy_seed"),
    active = c(FALSE, TRUE, TRUE, TRUE),
    notes = rep(NA_character_, 4)
  )
  snapshot <- list(
    functional_categories = list(default_hash = "func-hash", overrides = empty_reference_list_tbl()),
    stop_words = list(default_hash = "stop-hash", overrides = overrides),
    block_patterns = list(default_hash = "block-hash", overrides = empty_reference_list_tbl()),
    strip_terms = list(default_hash = "strip-hash", overrides = empty_reference_list_tbl())
  )

  literal <- reference_snapshot_script_literal(snapshot)
  # Derivable columns are dropped from the emission; active compresses to a
  # membership test on the smaller (inactive) set.
  expect_no_match(literal, "pattern =", fixed = TRUE)
  expect_no_match(literal, "match_mode =", fixed = TRUE)
  expect_no_match(literal, "notes =", fixed = TRUE)
  expect_match(literal, 'active = !(term %in% "additive")', fixed = TRUE)

  evaluated <- eval(parse(text = literal))
  for (type in names(snapshot)) {
    reconstructed <- normalize_reference_list_tbl(evaluated[[type]]$overrides, type)
    expect_equal(reconstructed, snapshot[[type]]$overrides, info = type)
    expect_identical(evaluated[[type]]$default_hash, snapshot[[type]]$default_hash)
  }
})

test_that("compact reference snapshot keeps non-derivable columns", {
  overrides <- tibble::tibble(
    term = c("alpha", "beta"),
    pattern = c("alpha[0-9]", "beta"),
    match_mode = c("regex", "literal_word"),
    source = c("user", "user"),
    active = c(TRUE, TRUE),
    notes = c("custom pattern", NA_character_)
  )
  snapshot <- list(
    functional_categories = list(default_hash = "f", overrides = empty_reference_list_tbl()),
    stop_words = list(default_hash = "s", overrides = overrides),
    block_patterns = list(default_hash = "b", overrides = empty_reference_list_tbl()),
    strip_terms = list(default_hash = "t", overrides = empty_reference_list_tbl())
  )

  literal <- reference_snapshot_script_literal(snapshot)
  expect_match(literal, "pattern =", fixed = TRUE)
  expect_match(literal, "match_mode =", fixed = TRUE)
  expect_match(literal, "notes =", fixed = TRUE)

  evaluated <- eval(parse(text = literal))
  reconstructed <- normalize_reference_list_tbl(evaluated$stop_words$overrides, "stop_words")
  expect_equal(reconstructed, overrides)
})

test_that("generate_concert_script emits content-matched rows_update tables", {
  baseline <- init_resolution_state(tibble::tibble(
    chemical = c("Acetone", "Benzene"),
    cas_number = c("67-64-1", "71-43-2"),
    consensus_status = c("agree", "agree"),
    consensus_dtxsid = c("DTXSID7020182", "DTXSID9020453"),
    consensus_source = c("consensus", "consensus"),
    qc_tier = c(1L, 1L)
  ))
  final <- baseline
  final$row_flag[1] <- "VERIFIED"

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
  expect_match(script, "state <- resolution_state", fixed = TRUE)
  expect_match(script, "# Review Results — row_flag corrections (1)", fixed = TRUE)
  expect_match(script, "row_flag_fixes <- tibble::tribble(", fixed = TRUE)
  expect_match(script, "~chemical", fixed = TRUE)
  expect_match(script, '"Acetone"', fixed = TRUE)
  expect_match(script, '"VERIFIED"', fixed = TRUE)
  expect_match(
    script,
    'state <- dplyr::rows_update(state, row_flag_fixes, by = "chemical", unmatched = "ignore")',
    fixed = TRUE
  )
  expect_no_match(script, 'cas_number = "67-64-1"', fixed = TRUE)
  expect_no_match(script, "dplyr::case_when(", fixed = TRUE)
  expect_match(script, 'attr(apply_review_overrides, "review_override_columns")', fixed = TRUE)
  expect_match(script, "review_overrides = apply_review_overrides", fixed = TRUE)
  expect_no_match(script, "review_overrides <- tibble::tibble", fixed = TRUE)
  expect_no_match(script, "row = c(", fixed = TRUE)
  expect_no_match(script, "list(list", fixed = TRUE)
  expect_silent(parse(text = script))
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
  final$row_flag_reason[4] <- "No valid DTXSID or WQX match"
  final$wqx_override_name <- NA_character_
  final$wqx_override_name[5] <- "User WQX Name"
  final$consensus_status[6] <- "unresolvable"
  final$qc_tier[6] <- NA_integer_

  overrides <- build_review_overrides(baseline, final)
  expect_s3_class(overrides, "concert_review_override_spec")
  expect_named(overrides, c("workflow", "column", "value", "signature"))
  expect_true(all(overrides$workflow == "review"))
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
    "row_flag_reason",
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
  final$row_flag_reason[2] <- "Needs second pass"

  overrides <- build_review_overrides(baseline, final)
  replayed <- apply_review_overrides(baseline[c(3, 1, 2), ], overrides)

  expect_equal(replayed$row_flag[replayed$chemical == "Benzene"], "FOLLOW-UP")
  expect_equal(replayed$row_flag_reason[replayed$chemical == "Benzene"], "Needs second pass")
  expect_true(all(is.na(replayed$row_flag[replayed$chemical != "Benzene"])))
  expect_true(all(is.na(replayed$row_flag_reason[replayed$chemical != "Benzene"])))
})

test_that("duplicate stable-content rows require identical intended edits", {
  baseline <- init_resolution_state(tibble::tibble(
    chemical = c("Acetone", "Acetone", "Benzene"),
    cas_number = c("67-64-1", "67-64-1", "71-43-2"),
    consensus_status = c("agree", "agree", "agree"),
    consensus_dtxsid = c("DTXSID1", "DTXSID1", "DTXSID2"),
    consensus_source = c("consensus", "consensus", "consensus"),
    qc_tier = c(1L, 1L, 1L)
  ))

  ambiguous <- baseline
  ambiguous$row_flag[1] <- "VERIFIED"
  expect_error(
    build_review_overrides(baseline, ambiguous),
    "ambiguous"
  )

  identical_edits <- baseline
  identical_edits$row_flag <- c("VERIFIED", "VERIFIED", NA_character_)
  overrides <- build_review_overrides(baseline, identical_edits)

  expect_equal(nrow(overrides), 1L)
  expect_named(overrides$signature[[1]], "chemical")
  replayed <- apply_review_overrides(baseline, overrides)
  expect_equal(replayed$row_flag, c("VERIFIED", "VERIFIED", NA_character_))

  script <- generate_concert_script(
    input_path = "input.csv",
    output_path = "input_curated.xlsx",
    tag_map = list(chemical = "Name", cas_number = "CASRN"),
    header_row = 1L,
    review_overrides = overrides
  )
  branch_matches <- gregexpr('"VERIFIED"', script, fixed = TRUE)[[1]]
  expect_equal(sum(branch_matches > 0), 1L)
})

test_that("minimal row signatures add only enough columns to disambiguate near duplicates", {
  baseline <- init_resolution_state(tibble::tibble(
    site = c("A", "A", "A", "B", "C"),
    chemical = c("Acetone", "Acetone", "Benzene", "Acetone", "Toluene"),
    cas_number = c("67-64-1", "67-64-1", "71-43-2", "75-07-0", "67-64-1"),
    sample_id = c("S1", "S2", "S1", "S1", "S1"),
    consensus_status = rep("agree", 5),
    consensus_dtxsid = paste0("DTXSID", 1:5),
    consensus_source = rep("consensus", 5),
    qc_tier = rep(1L, 5)
  ))
  final <- baseline
  final$row_flag[1] <- "FOLLOW-UP"

  overrides <- build_review_overrides(baseline, final)

  expect_equal(nrow(overrides), 1L)
  expect_named(overrides$signature[[1]], c("site", "chemical", "sample_id"))
  replayed <- apply_review_overrides(baseline, overrides)
  expect_equal(replayed$row_flag, c("FOLLOW-UP", rep(NA_character_, 4)))

  script <- generate_concert_script(
    input_path = "input.csv",
    output_path = "input_curated.xlsx",
    tag_map = list(chemical = "Name"),
    header_row = 1L,
    review_overrides = overrides
  )
  expect_match(
    script,
    'by = c("site", "chemical", "sample_id"), unmatched = "ignore"',
    fixed = TRUE
  )
  expect_match(script, '"FOLLOW-UP"', fixed = TRUE)
  expect_no_match(script, "cas_number", fixed = TRUE)
})

test_that("generated rows_update tables preserve typed NA values", {
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
  expect_match(script, "consensus_dtxsid_fixes <- tibble::tribble(", fixed = TRUE)
  expect_match(script, "qc_tier_fixes <- tibble::tribble(", fixed = TRUE)
  expect_silent(parse(text = script))
})

test_that("review replay predicates ignore tagged measurement columns", {
  baseline <- init_resolution_state(tibble::tibble(
    chemical = c("Acetone", "Benzene"),
    result = c("1.2", "3.4"),
    consensus_status = c("agree", "agree"),
    consensus_dtxsid = c("DTXSID1", "DTXSID2"),
    consensus_source = c("consensus", "consensus"),
    qc_tier = c(1L, 1L)
  ))
  final <- baseline
  final$row_flag[1] <- "VERIFIED"

  script <- generate_concert_script(
    input_path = "input.csv",
    output_path = "input_curated.xlsx",
    tag_map = list(chemical = "Name", result = "Result"),
    header_row = 1L,
    review_overrides = build_review_overrides(
      baseline,
      final,
      tag_map = list(chemical = "Name", result = "Result")
    )
  )

  expect_match(script, "row_flag_fixes <- tibble::tribble(", fixed = TRUE)
  expect_match(script, '"Acetone"', fixed = TRUE)
  expect_match(script, '"VERIFIED"', fixed = TRUE)
  expect_match(
    script,
    'state <- dplyr::rows_update(state, row_flag_fixes, by = "chemical", unmatched = "ignore")',
    fixed = TRUE
  )
  expect_no_match(script, "result_fixes", fixed = TRUE)
})

test_that("tagged Result edits replay in a measurement workflow block", {
  baseline <- init_resolution_state(tibble::tibble(
    chemical = c("Acetone", "Benzene"),
    sample_id = c("S1", "S2"),
    result = c("1.2", "3.4"),
    consensus_status = c("agree", "agree"),
    consensus_dtxsid = c("DTXSID1", "DTXSID2"),
    consensus_source = c("consensus", "consensus"),
    qc_tier = c(1L, 1L)
  ))
  final <- baseline
  final$result[1] <- "1.5"

  overrides <- build_review_overrides(
    baseline,
    final,
    tag_map = list(chemical = "Name", result = "Result")
  )
  expect_equal(unique(overrides$workflow), "measurement_tags")

  replayed <- apply_review_overrides(baseline, overrides)
  expect_equal(replayed$result, c("1.5", "3.4"))

  script <- generate_concert_script(
    input_path = "input.csv",
    output_path = "input_curated.xlsx",
    tag_map = list(chemical = "Name", result = "Result"),
    header_row = 1L,
    review_overrides = overrides
  )

  expect_match(script, "# Measurement tags — result corrections (1)", fixed = TRUE)
  expect_match(script, "result_fixes <- tibble::tribble(", fixed = TRUE)
  expect_match(script, '"Acetone"', fixed = TRUE)
  expect_match(script, '"1.5"', fixed = TRUE)
  expect_no_match(script, "row_flag", fixed = TRUE)
})

test_that("mixed replay edits are grouped by workflow blocks", {
  baseline <- init_resolution_state(tibble::tibble(
    chemical = c("Acetone", "Benzene"),
    sample_id = c("S1", "S2"),
    result = c("1.2", "3.4"),
    unit = c("mg/L", "ug/L"),
    media = c("water", "sediment"),
    species = c("Daphnia", "Fish"),
    consensus_status = c("agree", "agree"),
    consensus_dtxsid = c("DTXSID1", "DTXSID2"),
    consensus_source = c("consensus", "consensus"),
    qc_tier = c(1L, 1L)
  ))
  final <- baseline
  final$row_flag[1] <- "FOLLOW-UP"
  final$result[1] <- "1.5"
  final$unit[1] <- "ug/L"
  final$media[1] <- "surface water"
  final$species[1] <- "Daphnia magna"

  tag_map <- list(
    chemical = "Name",
    result = "Result",
    unit = "Unit",
    media = "Media",
    species = "Species"
  )
  overrides <- build_review_overrides(baseline, final, tag_map = tag_map)

  expect_equal(
    unique(overrides$workflow),
    c("review", "measurement_tags", "study_tags", "metadata_tags")
  )

  replayed <- apply_review_overrides(baseline, overrides)
  expect_equal(replayed$row_flag, final$row_flag)
  expect_equal(replayed$result, final$result)
  expect_equal(replayed$unit, final$unit)
  expect_equal(replayed$media, final$media)
  expect_equal(replayed$species, final$species)

  script <- generate_concert_script(
    input_path = "input.csv",
    output_path = "input_curated.xlsx",
    tag_map = tag_map,
    header_row = 1L,
    review_overrides = overrides
  )
  update_matches <- gregexpr("state <- dplyr::rows_update(", script, fixed = TRUE)[[1]]

  # result and unit share one signature, so they merge into a single table.
  expect_equal(sum(update_matches > 0), 4L)
  expect_match(script, "# Measurement tags — result, unit corrections (1)", fixed = TRUE)
  expect_match(script, "# Review Results — row_flag corrections (1)", fixed = TRUE)
  expect_match(script, '"FOLLOW-UP"', fixed = TRUE)
  expect_match(script, '"1.5"', fixed = TRUE)
  expect_match(script, '"ug/L"', fixed = TRUE)
  expect_match(script, '"surface water"', fixed = TRUE)
  expect_match(script, '"Daphnia magna"', fixed = TRUE)
  # Review Results section renders before the chemical-identity-keyed workflows.
  expect_lt(
    regexpr("row_flag_fixes", script, fixed = TRUE),
    regexpr("species_fixes", script, fixed = TRUE)
  )
  expect_silent(parse(text = script))
})

test_that("tagged measurement edits fail when only the edited field disambiguates duplicates", {
  baseline <- init_resolution_state(tibble::tibble(
    chemical = c("Acetone", "Acetone"),
    result = c("1.2", "3.4"),
    consensus_status = c("agree", "agree"),
    consensus_dtxsid = c("DTXSID1", "DTXSID1"),
    consensus_source = c("consensus", "consensus"),
    qc_tier = c(1L, 1L)
  ))
  final <- baseline
  final$result[1] <- "1.5"

  expect_error(
    build_review_overrides(
      baseline,
      final,
      tag_map = list(chemical = "Name", result = "Result")
    ),
    "ambiguous"
  )
})

test_that("stable context disambiguates tagged measurement edits without Result predicates", {
  baseline <- init_resolution_state(tibble::tibble(
    chemical = c("Acetone", "Acetone"),
    sample_id = c("S1", "S2"),
    result = c("1.2", "3.4"),
    consensus_status = c("agree", "agree"),
    consensus_dtxsid = c("DTXSID1", "DTXSID1"),
    consensus_source = c("consensus", "consensus"),
    qc_tier = c(1L, 1L)
  ))
  final <- baseline
  final$result[1] <- "1.5"

  overrides <- build_review_overrides(
    baseline,
    final,
    tag_map = list(chemical = "Name", result = "Result")
  )

  expect_named(overrides$signature[[1]], c("chemical", "sample_id"))
  replayed <- apply_review_overrides(baseline, overrides)
  expect_equal(replayed$result, c("1.5", "3.4"))

  script <- generate_concert_script(
    input_path = "input.csv",
    output_path = "input_curated.xlsx",
    tag_map = list(chemical = "Name", result = "Result"),
    header_row = 1L,
    review_overrides = overrides
  )

  expect_match(script, '"Acetone"', fixed = TRUE)
  expect_match(script, '"S1"', fixed = TRUE)
  expect_match(
    script,
    'by = c("chemical", "sample_id"), unmatched = "ignore"',
    fixed = TRUE
  )
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

test_that("generated rows_update function matches the in-memory spec apply", {
  baseline <- init_resolution_state(tibble::tibble(
    chemical = c("Acetone", "Benzene", "Toluene"),
    sample_id = c("S1", "S2", "S1"),
    result = c("1.2", "3.4", "5.6"),
    unit = c("mg/L", "ug/L", "mg/L"),
    consensus_status = rep("agree", 3),
    consensus_dtxsid = paste0("DTXSID", 1:3),
    consensus_source = rep("consensus", 3),
    qc_tier = rep(1L, 3)
  ))
  final <- baseline
  final$row_flag[1] <- "VERIFIED"
  final$result[2] <- "9.9"
  final$unit[3] <- "ug/L"

  tag_map <- list(chemical = "Name", result = "Result", unit = "Unit")
  spec <- build_review_overrides(baseline, final, tag_map = tag_map)

  fn_src <- review_overrides_function_literal(spec)
  env <- new.env(parent = globalenv())
  eval(parse(text = fn_src), envir = env)
  target_cols <- attr(env$apply_review_overrides, "review_override_columns")
  prepared <- init_review_override_columns(
    baseline,
    intersect(target_cols, review_override_columns())
  )
  generated <- env$apply_review_overrides(prepared)
  in_memory <- apply_review_overrides(baseline, spec)

  for (col in unique(spec$column)) {
    expect_equal(generated[[col]], in_memory[[col]], info = col)
    expect_equal(generated[[col]], final[[col]], info = col)
  }
})

test_that("large replay sessions emit deterministic, parseable grouped tables", {
  n <- 300L
  baseline <- init_resolution_state(tibble::tibble(
    chemical = paste0("Chem", seq_len(n)),
    sample_id = paste0("S", seq_len(n)),
    result = as.character(seq_len(n)),
    unit = rep("mg/L", n),
    consensus_status = rep("agree", n),
    consensus_dtxsid = paste0("DTXSID", seq_len(n)),
    consensus_source = rep("consensus", n),
    qc_tier = rep(1L, n)
  ))
  final <- baseline
  edited <- seq_len(120L)
  final$result[edited] <- paste0(final$result[edited], ".5")
  final$unit[edited] <- "ug/L"

  tag_map <- list(chemical = "Name", result = "Result", unit = "Unit")
  script <- generate_concert_script(
    input_path = "input.csv",
    output_path = "input_curated.xlsx",
    tag_map = tag_map,
    header_row = 1L,
    review_overrides = build_review_overrides(baseline, final, tag_map = tag_map)
  )

  expect_silent(parse(text = script))
  expect_match(script, "# Measurement tags — result corrections (120)", fixed = TRUE)
  expect_match(script, "result_fixes <- tibble::tribble(", fixed = TRUE)
  # unit is a constant-value bulk edit: induced to a %in% mask, no table.
  expect_match(script, "# Measurement tags — unit corrections (120)", fixed = TRUE)
  expect_match(script, "matched <- state$chemical %in% c(", fixed = TRUE)
  expect_match(script, 'state$unit[matched] <- "ug/L"', fixed = TRUE)
  expect_no_match(script, "unit_fixes", fixed = TRUE)

  script2 <- generate_concert_script(
    input_path = "input.csv",
    output_path = "input_curated.xlsx",
    tag_map = tag_map,
    header_row = 1L,
    review_overrides = build_review_overrides(baseline, final, tag_map = tag_map)
  )
  expect_identical(script, script2)
})

test_that("chemical-tag edits render after other workflows and replay correctly", {
  baseline <- init_resolution_state(tibble::tibble(
    chemical = c("Acetone", "Benzene"),
    sample_id = c("S1", "S2"),
    result = c("1.2", "3.4"),
    consensus_status = c("agree", "agree"),
    consensus_dtxsid = c("DTXSID1", "DTXSID2"),
    consensus_source = c("consensus", "consensus"),
    qc_tier = c(1L, 1L)
  ))
  final <- baseline
  final$result[1] <- "1.5"
  final$chemical[1] <- "Acetone (verified)"

  tag_map <- list(chemical = "Name", result = "Result")
  spec <- build_review_overrides(baseline, final, tag_map = tag_map)

  expect_setequal(unique(spec$workflow), c("measurement_tags", "chemical_tags"))

  script <- generate_concert_script(
    input_path = "input.csv",
    output_path = "input_curated.xlsx",
    tag_map = tag_map,
    header_row = 1L,
    review_overrides = spec
  )
  expect_silent(parse(text = script))
  # The measurement table keyed on chemical must run before the rename.
  expect_lt(
    regexpr("result_fixes", script, fixed = TRUE),
    regexpr("chemical_fixes", script, fixed = TRUE)
  )

  replayed <- apply_review_overrides(baseline, spec)
  expect_equal(replayed$result, c("1.5", "3.4"))
  expect_equal(replayed$chemical, c("Acetone (verified)", "Benzene"))
})

test_that("same-signature multi-column edits merge into one rows_update table", {
  baseline <- init_resolution_state(tibble::tibble(
    chemical = c("Acetone", "Benzene", "Toluene"),
    cas_number = c("67-64-1", "71-43-2", "108-88-3"),
    consensus_status = rep("agree", 3),
    consensus_dtxsid = paste0("DTXSID", 1:3),
    consensus_source = rep("consensus", 3),
    qc_tier = rep(1L, 3)
  ))
  final <- baseline
  final$manual_preferredName <- NA_character_
  final$consensus_status[2] <- "manual"
  final$consensus_dtxsid[2] <- "DTXSID00000000"
  final$consensus_source[2] <- "user"
  final$manual_preferredName[2] <- "Benzol"
  final$row_flag[2] <- "VERIFIED"

  spec <- build_review_overrides(baseline, final)
  fn_src <- review_overrides_function_literal(spec)

  update_matches <- gregexpr("dplyr::rows_update(", fn_src, fixed = TRUE)[[1]]
  expect_equal(sum(update_matches > 0), 1L)
  expect_match(
    fn_src,
    "# Review Results — consensus_status, consensus_dtxsid, consensus_source, manual_preferredName, row_flag corrections (1)",
    fixed = TRUE
  )

  env <- new.env(parent = globalenv())
  eval(parse(text = fn_src), envir = env)
  prepared <- init_review_override_columns(
    baseline,
    intersect(attr(env$apply_review_overrides, "review_override_columns"), review_override_columns())
  )
  generated <- env$apply_review_overrides(prepared)
  in_memory <- apply_review_overrides(baseline, spec)
  for (col in unique(spec$column)) {
    expect_equal(generated[[col]], in_memory[[col]], info = col)
    expect_equal(generated[[col]], final[[col]], info = col)
  }
})

test_that("single-key constant-value bulk edits emit a vectorized %in% assignment", {
  n <- 30L
  baseline <- init_resolution_state(tibble::tibble(
    chemical = paste0("Chem", seq_len(n)),
    result = as.character(seq_len(n)),
    unit = rep("mg/L", n),
    consensus_status = rep("agree", n),
    consensus_dtxsid = paste0("DTXSID", seq_len(n)),
    consensus_source = rep("consensus", n),
    qc_tier = rep(1L, n)
  ))
  final <- baseline
  final$unit[seq_len(12L)] <- "ug/L"

  tag_map <- list(chemical = "Name", result = "Result", unit = "Unit")
  spec <- build_review_overrides(baseline, final, tag_map = tag_map)
  fn_src <- review_overrides_function_literal(spec)

  expect_match(fn_src, "# Measurement tags — unit corrections (12)", fixed = TRUE)
  expect_match(fn_src, "matched <- state$chemical %in% c(", fixed = TRUE)
  expect_match(fn_src, 'state$unit[matched] <- "ug/L"', fixed = TRUE)
  expect_no_match(fn_src, "rows_update", fixed = TRUE)
  expect_silent(parse(text = fn_src))

  env <- new.env(parent = globalenv())
  eval(parse(text = fn_src), envir = env)
  prepared <- init_review_override_columns(
    baseline,
    intersect(attr(env$apply_review_overrides, "review_override_columns"), review_override_columns())
  )
  generated <- env$apply_review_overrides(prepared)
  in_memory <- apply_review_overrides(baseline, spec)
  expect_equal(generated$unit, in_memory$unit)
  expect_equal(generated$unit, final$unit)
})

test_that("bulk induction refuses when unchanged rows share the predicate value", {
  baseline <- init_resolution_state(tibble::tibble(
    chemical = rep(c("Benzene", "Toluene"), each = 2),
    sample_id = rep(c("S1", "S2"), times = 2),
    consensus_status = rep("agree", 4),
    consensus_dtxsid = rep(c("DTXSID1", "DTXSID2"), each = 2),
    consensus_source = rep("consensus", 4),
    qc_tier = rep(1L, 4)
  ))
  final <- baseline
  # Diagonal of the chemical x sample grid: no single column separates the
  # edited set, so replay must fall back to per-row content matching.
  final$row_flag[c(1L, 4L)] <- "SUSPECT"

  spec <- build_review_overrides(baseline, final)
  expect_equal(nrow(spec), 2L)
  fn_src <- review_overrides_function_literal(spec)
  expect_match(fn_src, "row_flag_fixes <- tibble::tribble(", fixed = TRUE)
  expect_no_match(fn_src, "%in%", fixed = TRUE)

  env <- new.env(parent = globalenv())
  eval(parse(text = fn_src), envir = env)
  prepared <- init_review_override_columns(baseline, "row_flag")
  generated <- env$apply_review_overrides(prepared)
  expect_equal(generated$row_flag, final$row_flag)
  expect_equal(apply_review_overrides(baseline, spec)$row_flag, final$row_flag)
})

test_that("bulk induction collapses whole-group edits to one set signature", {
  baseline <- init_resolution_state(tibble::tibble(
    chemical = rep(c("Benzene", "Toluene", "Xylene"), each = 4),
    sample_id = paste0("S", 1:12),
    consensus_status = rep("agree", 12),
    consensus_dtxsid = rep(paste0("DTXSID", 1:3), each = 4),
    consensus_source = rep("consensus", 12),
    qc_tier = rep(1L, 12)
  ))
  final <- baseline
  final$row_flag[baseline$chemical %in% c("Benzene", "Xylene")] <- "SUSPECT"

  spec <- build_review_overrides(baseline, final)
  expect_equal(nrow(spec), 1L)
  expect_equal(spec$signature[[1]], list(chemical = c("Benzene", "Xylene")))

  fn_src <- review_overrides_function_literal(spec)
  expect_match(fn_src, 'matched <- state$chemical %in% c("Benzene", "Xylene")', fixed = TRUE)
  expect_match(fn_src, 'state$row_flag[matched] <- "SUSPECT"', fixed = TRUE)

  env <- new.env(parent = globalenv())
  eval(parse(text = fn_src), envir = env)
  prepared <- init_review_override_columns(baseline, "row_flag")
  generated <- env$apply_review_overrides(prepared)
  expect_equal(generated$row_flag, final$row_flag)
  expect_equal(apply_review_overrides(baseline, spec)$row_flag, final$row_flag)
})

test_that("review edits with chemical tags capture as one compound-keyed curation map", {
  baseline <- init_resolution_state(tibble::tibble(
    site = rep(c("Raw PW", "MBR Feed", "Distillate"), times = 3),
    chemical = rep(c("Acetone", "Benzene", "Toluene"), each = 3),
    cas_number = rep(c("67-64-1", "71-43-2", "108-88-3"), each = 3),
    consensus_status = rep("suggested", 9),
    consensus_dtxsid = rep(paste0("DTXSID", 1:3), each = 3),
    consensus_source = rep("consensus", 9),
    qc_tier = rep(1L, 9)
  ))
  final <- baseline
  # Compound-scoped edits: every row of the compound carries the change.
  acetone <- baseline$chemical == "Acetone"
  benzene <- baseline$chemical == "Benzene"
  final$consensus_status[acetone] <- "manual"
  final$consensus_dtxsid[acetone] <- "DTXSID999"
  final$consensus_source[acetone] <- "manual_entry"
  final$row_flag[benzene] <- "SUSPECT"

  tag_map <- list(chemical = "Name", cas_number = "CASRN")
  spec <- build_review_overrides(baseline, final, tag_map = tag_map)

  expect_true(all(spec$workflow == "review"))
  # Two compounds x four changed columns, all keyed on chemical identity.
  expect_equal(nrow(spec), 8L)
  expect_true(all(vapply(
    spec$signature,
    function(sig) identical(names(sig), c("chemical", "cas_number")),
    logical(1)
  )))

  fn_src <- review_overrides_function_literal(spec)
  # Identical signature sets merge every review column into one table.
  update_matches <- gregexpr("dplyr::rows_update(", fn_src, fixed = TRUE)[[1]]
  expect_equal(sum(update_matches > 0), 1L)
  expect_match(
    fn_src,
    "# Review Results — consensus_status, consensus_dtxsid, consensus_source, row_flag corrections (2)",
    fixed = TRUE
  )
  expect_no_match(fn_src, '"Raw PW"', fixed = TRUE)

  env <- new.env(parent = globalenv())
  eval(parse(text = fn_src), envir = env)
  prepared <- init_review_override_columns(
    baseline,
    intersect(attr(env$apply_review_overrides, "review_override_columns"), review_override_columns())
  )
  generated <- env$apply_review_overrides(prepared)
  in_memory <- apply_review_overrides(baseline, spec)
  for (col in unique(spec$column)) {
    expect_equal(generated[[col]], in_memory[[col]], info = col)
    expect_equal(generated[[col]], final[[col]], info = col)
  }
})

test_that("compound-keyed overrides propagate to rows the user never opened", {
  baseline <- init_resolution_state(tibble::tibble(
    site = c("A", "B", "C"),
    chemical = rep("Acetone", 3),
    cas_number = rep("67-64-1", 3),
    consensus_status = rep("suggested", 3),
    consensus_dtxsid = rep("DTXSID1", 3),
    consensus_source = rep("consensus", 3),
    qc_tier = rep(1L, 3)
  ))
  final <- baseline
  final$consensus_dtxsid <- rep("DTXSID999", 3)

  spec <- build_review_overrides(
    baseline,
    final,
    tag_map = list(chemical = "Name", cas_number = "CASRN")
  )

  expect_equal(nrow(spec), 1L)
  # Replay against a state with extra rows of the same compound: all match.
  wider <- baseline[c(1, 2, 3, 1), ]
  replayed <- apply_review_overrides(wider, spec)
  expect_equal(replayed$consensus_dtxsid, rep("DTXSID999", 4))
})

test_that("non-uniform compound edits fail the compound-scope assertion", {
  baseline <- init_resolution_state(tibble::tibble(
    site = c("A", "B"),
    chemical = rep("Acetone", 2),
    cas_number = rep("67-64-1", 2),
    consensus_status = rep("suggested", 2),
    consensus_dtxsid = rep("DTXSID1", 2),
    consensus_source = rep("consensus", 2),
    qc_tier = rep(1L, 2)
  ))
  final <- baseline
  final$consensus_dtxsid[1] <- "DTXSID999"

  expect_error(
    build_review_overrides(
      baseline,
      final,
      tag_map = list(chemical = "Name", cas_number = "CASRN")
    ),
    "not compound-scoped"
  )
})

test_that("compound identity falls back to formula-blocked columns for blanked names", {
  baseline <- init_resolution_state(tibble::tibble(
    chemical = c("Acetone", NA_character_, NA_character_),
    cas_number = c("67-64-1", NA_character_, NA_character_),
    formula_blocked_chemical = c(NA_character_, "Bi212", "Pb212"),
    consensus_status = c("agree", "error", "error"),
    consensus_dtxsid = c("DTXSID1", NA_character_, NA_character_),
    consensus_source = c("consensus", NA_character_, NA_character_),
    qc_tier = c(1L, 4L, 4L)
  ))
  final <- baseline
  final$consensus_status[2:3] <- "manual"
  final$consensus_dtxsid[2:3] <- c("DTXSID201", "DTXSID202")

  spec <- build_review_overrides(
    baseline,
    final,
    tag_map = list(chemical = "Name", cas_number = "CASRN")
  )

  expect_true(all(vapply(
    spec$signature,
    function(sig) "formula_blocked_chemical" %in% names(sig),
    logical(1)
  )))
  replayed <- apply_review_overrides(baseline, spec)
  expect_equal(replayed$consensus_status, final$consensus_status)
  expect_equal(replayed$consensus_dtxsid, final$consensus_dtxsid)
})

test_that("all-NA identity key columns drop from the curation map key", {
  baseline <- init_resolution_state(tibble::tibble(
    chemical = c("Acetone", "Benzene"),
    cas_number = c("67-64-1", "71-43-2"),
    formula_blocked_chemical = c(NA_character_, NA_character_),
    consensus_status = c("agree", "agree"),
    consensus_dtxsid = c("DTXSID1", "DTXSID2"),
    consensus_source = c("consensus", "consensus"),
    qc_tier = c(1L, 1L)
  ))
  final <- baseline
  final$row_flag[1] <- "VERIFIED"

  spec <- build_review_overrides(
    baseline,
    final,
    tag_map = list(chemical = "Name", cas_number = "CASRN")
  )

  expect_equal(names(spec$signature[[1]]), c("chemical", "cas_number"))
  expect_equal(apply_review_overrides(baseline, spec)$row_flag, final$row_flag)
})
