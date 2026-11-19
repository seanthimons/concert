multi_analyte_fixture <- function(values) {
  flagged <- !is.na(values) &
    (grepl("(?<!\\()\\s\\+\\s(?!\\))", values, perl = TRUE) |
      grepl("(?i)\\s+and\\s+", values, perl = TRUE))

  tibble::tibble(
    original_row_id = seq_along(values),
    analyte = values,
    cleaning_flag = ifelse(flagged, "WARNING: potential multi-analyte", NA_character_)
  )
}

test_that("suggest_multi_analyte_parts splits explicit separators and carries isotope element", {
  expect_equal(suggest_multi_analyte_parts("nitrate + nitrite"), c("nitrate", "nitrite"))
  expect_equal(suggest_multi_analyte_parts("Thorium-230 and 232"), c("Thorium-230", "Thorium-232"))
  expect_equal(suggest_multi_analyte_parts("(+)-catechin"), "(+)-catechin")
  expect_equal(suggest_multi_analyte_parts(NA_character_), character(0))
  expect_equal(suggest_multi_analyte_parts(""), character(0))
})

test_that("suggest_multi_analyte_parts splits ' & ' and ' / ' but leaves parenthetical groups intact", {
  expect_equal(suggest_multi_analyte_parts("acetone & ethanol"), c("acetone", "ethanol"))
  expect_equal(suggest_multi_analyte_parts("toluene / benzene"), c("toluene", "benzene"))
  # ' & ' inside parentheses is not a separator -> value stays whole
  expect_equal(suggest_multi_analyte_parts("endosulfan (alpha & beta)"), "endosulfan (alpha & beta)")
})

test_that("resolve_multi_analyte_row split creates rows with lineage and audit trail", {
  df <- multi_analyte_fixture(c("lead and arsenic", "acetone"))

  result <- resolve_multi_analyte_row(df, "analyte", row_index = 1L, action = "split")
  cleaned <- result$cleaned_data

  expect_equal(nrow(cleaned), 3)
  expect_equal(cleaned$analyte[1:2], c("lead", "arsenic"))
  expect_equal(cleaned$original_row_id[1:2], c(1L, 1L))
  expect_equal(cleaned$multi_analyte_resolution[1:2], c("split", "split"))
  expect_equal(cleaned$multi_analyte_part_index[1:2], c(1L, 2L))
  expect_equal(cleaned$multi_analyte_part_count[1:2], c(2L, 2L))
  expect_false(any(is_multi_analyte_review_row(cleaned)))

  expect_equal(result$audit_trail$step, rep("multi_analyte_resolution", 2))
  expect_equal(result$audit_trail$new_value, c("lead", "arsenic"))
})

test_that("resolve_multi_analyte_row keep combined clears repeat review warning", {
  df <- multi_analyte_fixture("nitrate + nitrite")

  result <- resolve_multi_analyte_row(df, "analyte", row_index = 1L, action = "keep")
  cleaned <- result$cleaned_data

  expect_equal(cleaned$analyte, "nitrate + nitrite")
  expect_equal(cleaned$multi_analyte_resolution, "keep_combined")
  expect_false(is_multi_analyte_review_row(cleaned))
  expect_match(cleaned$cleaning_flag, "REVIEWED: multi-analyte kept combined", fixed = TRUE)
  expect_equal(result$audit_trail$reason, "Kept as combined analyte")

  rechecked <- flag_multi_analyte(cleaned, "analyte")$cleaned_data
  expect_false(is_multi_analyte_review_row(rechecked))
  expect_no_match(rechecked$cleaning_flag, "WARNING: potential multi-analyte", fixed = TRUE)
})

test_that("resolve_multi_analyte_row rename updates the analyte and clears warning", {
  df <- multi_analyte_fixture("Thorium-230 and 232")

  result <- resolve_multi_analyte_row(
    df,
    "analyte",
    row_index = 1L,
    action = "rename",
    values = "Thorium-230/232 combined"
  )
  cleaned <- result$cleaned_data

  expect_equal(cleaned$analyte, "Thorium-230/232 combined")
  expect_equal(cleaned$multi_analyte_resolution, "rename")
  expect_false(is_multi_analyte_review_row(cleaned))
  expect_equal(result$audit_trail$new_value, "Thorium-230/232 combined")
})

test_that("resolve_multi_analyte_row split tolerates duplicate values after expansion", {
  df <- multi_analyte_fixture(c("Thorium-230 and 232", "Thorium-232"))
  df$cleaning_flag[2] <- NA_character_

  result <- resolve_multi_analyte_row(df, "analyte", row_index = 1L, action = "split")
  cleaned <- result$cleaned_data

  expect_equal(cleaned$analyte, c("Thorium-230", "Thorium-232", "Thorium-232"))
  expect_equal(sum(cleaned$analyte == "Thorium-232"), 2L)
})

test_that("resolve_multi_analyte_row validates empty and NA names", {
  df <- multi_analyte_fixture(c(NA_character_, ""))

  expect_error(
    resolve_multi_analyte_row(df, "analyte", row_index = 1L, action = "split"),
    "at least two"
  )
  expect_error(
    resolve_multi_analyte_row(df, "analyte", row_index = 2L, action = "rename", values = ""),
    "exactly one"
  )
})

test_that("apply_multi_analyte_resolutions applies specs in descending row order", {
  df <- multi_analyte_fixture(c("lead and arsenic", "nitrate + nitrite"))
  spec <- tibble::tibble(
    row_index = c(1L, 2L),
    action = c("split", "keep"),
    values = I(list(c("lead", "arsenic"), NULL))
  )

  result <- apply_multi_analyte_resolutions(df, "analyte", spec)

  expect_equal(result$cleaned_data$analyte, c("lead", "arsenic", "nitrate + nitrite"))
  expect_equal(result$cleaned_data$multi_analyte_resolution, c("split", "split", "keep_combined"))
  expect_equal(nrow(result$audit_trail), 3L)
  expect_false(any(is_multi_analyte_review_row(result$cleaned_data)))
})

test_that("apply_multi_analyte_resolutions keys row_index by original_row_id after a prior split", {
  # A synonym split upstream appends rows at the end, so position != original_row_id.
  df <- multi_analyte_fixture(c("acetone", "lead and arsenic", "benzene"))
  df <- df[c(1L, 3L, 2L), ] # row 2 by id now sits at position 3

  spec <- tibble::tibble(row_index = 2L, action = "split", values = I(list(c("lead", "arsenic"))))
  result <- apply_multi_analyte_resolutions(df, "analyte", spec)

  expect_equal(result$cleaned_data$analyte, c("acetone", "benzene", "lead", "arsenic"))
  expect_equal(result$cleaned_data$original_row_id, c(1L, 3L, 2L, 2L))
})

test_that("apply_multi_analyte_resolutions errors on missing or duplicated original_row_id", {
  df <- multi_analyte_fixture(c("lead and arsenic", "nitrate + nitrite"))
  df$original_row_id <- c(1L, 1L)

  expect_error(
    apply_multi_analyte_resolutions(df, "analyte", tibble::tibble(row_index = 1L, action = "keep")),
    "exactly one original_row_id"
  )
  expect_error(
    apply_multi_analyte_resolutions(df, "analyte", tibble::tibble(row_index = 9L, action = "keep")),
    "bad ids: 9"
  )
})

test_that("curate_headless applies multi-analyte resolutions before curation", {
  skip_if_not_installed("withr")
  skip_if_not_installed("readr")

  input_path <- tempfile(fileext = ".csv")
  readr::write_csv(tibble::tibble(analyte = "lead and arsenic"), input_path)
  withr::defer(unlink(input_path))

  seen_clean_data <- NULL

  local_mocked_bindings(
    run_cleaning_pipeline = function(clean_data, tag_map, reference_lists = NULL, ...) {
      list(
        cleaned_data = multi_analyte_fixture("lead and arsenic"),
        audit_trail = empty_cleaning_audit(),
        new_tags = list()
      )
    },
    run_curation_pipeline = function(clean_data, column_tags, ...) {
      seen_clean_data <<- clean_data
      results <- init_resolution_state(tibble::tibble(
        analyte = clean_data$analyte,
        consensus_status = rep("error", nrow(clean_data)),
        consensus_dtxsid = rep(NA_character_, nrow(clean_data)),
        consensus_source = rep(NA_character_, nrow(clean_data))
      ))
      list(
        results = results,
        consensus_summary = recalc_consensus_summary(results),
        search_summary = list(n_exact = 0, n_cas_valid = 0, n_wqx = 0, n_starts_with = 0, n_miss = nrow(clean_data)),
        dedup_summary = list(n_names = nrow(clean_data), n_cas = 0)
      )
    }
  )

  result <- curate_headless(
    input_path = input_path,
    output_path = NULL,
    tag_map = list(analyte = "Name"),
    multi_analyte_resolutions = tibble::tibble(
      row_index = 1L,
      action = "split",
      values = I(list(c("lead", "arsenic")))
    ),
    write_files = FALSE,
    verbose = FALSE
  )

  expect_equal(seen_clean_data$analyte, c("lead", "arsenic"))
  expect_equal(result$data$analyte, c("lead", "arsenic"))
  expect_true("multi_analyte_resolution" %in% result$audit_trail$step)
})

test_that("scripted splits record repeated source CAS and keep children provisional (#95)", {
  input_path <- tempfile(fileext = ".csv")
  readr::write_csv(tibble::tibble(
    chemical = c("Cypermethrin and alpha-Cypermethrin", "Alpha + Beta"),
    cas = c("52315-07-8", NA)
  ), input_path)
  withr::defer(unlink(input_path))

  state <- stage_ingest(input_path, tag_map = list(chemical = "Name", cas = "CASRN"))
  cleaned <- suppressMessages(stage_clean(state,
    multi_analyte_resolutions = tibble::tibble(row_index = 1:2, action = "split")))
  out <- cleaned$cleaning_result$cleaned_data
  cas_rows <- out$original_row_id == 1L
  expect_equal(sum(cas_rows), 2L)
  expect_equal(out$multi_analyte_source_cas[cas_rows], rep("52315-07-8", 2))
  expect_equal(out$component_cas_unresolved, c(TRUE, TRUE, FALSE, FALSE))

  # Successful lookups cannot clear the correspondence obligation.
  out$consensus_dtxsid <- c("DTXSID1023998", "DTXSID7041201", "DTXSID1", "DTXSID2")
  out$consensus_status <- "single"
  identity <- identity_review_state(out)
  expect_equal(identity$identity_eligible[cas_rows], c(FALSE, FALSE))
  expect_match(identity$identity_blockers[cas_rows], "unresolved_scope")

  # The scripted and coordinated paths record the same scope provenance.
  df <- flag_multi_analyte(tibble::tibble(original_row_id = 1L, Name = "Alpha + Beta", CASRN = "64-17-5"), "Name")$cleaned_data
  scripted <- apply_multi_analyte_resolutions(df, "Name", tibble::tibble(row_index = 1L, action = "split"),
    cas_cols = "CASRN")$cleaned_data
  coordinated <- resolve_review_row(df, "Name", 1L, list(name_action = "split", pairing = "broadcast"),
    cas_cols = "CASRN")$cleaned_data
  cols <- c("Name", "CASRN", "multi_analyte_source_cas", "component_cas_unresolved")
  expect_identical(scripted[cols], coordinated[cols])
})

keyed_fixture <- function(lead_rows = 0L) {
  df <- tibble::tibble(
    Name = c(rep("Lead", lead_rows), "Alpha + Beta", "Alpha + Beta", "Alpha + Beta", "Nitrate and nitrite"),
    CASRN = c(rep("7439-92-1", lead_rows), NA, "64-17-5", NA, "")
  )
  df$original_row_id <- seq_len(nrow(df))
  flag_multi_analyte(df, "Name")$cleaned_data
}

test_that("name + casrn resolutions survive rows inserted ahead of the decided rows", {
  keyed <- tibble::tibble(
    name = c("Alpha + Beta", "Alpha + Beta", "Nitrate and nitrite"),
    casrn = c(NA, "64-17-5", NA),
    action = c("split", "keep", "rename"),
    value = c("Alpha; Beta", NA, "Nitrate-nitrite")
  )
  by_row <- tibble::tibble(
    row_index = 1:4,
    action = c("split", "keep", "split", "rename"),
    value = c("Alpha; Beta", NA, "Alpha; Beta", "Nitrate-nitrite")
  )
  cols <- c("Name", "CASRN", "multi_analyte_resolution", "multi_analyte_part_index")

  base <- apply_multi_analyte_resolutions(keyed_fixture(), "Name", by_row, cas_cols = "CASRN")
  same <- apply_multi_analyte_resolutions(keyed_fixture(), "Name", keyed, cas_cols = "CASRN")
  expect_identical(same$cleaned_data[cols], base$cleaned_data[cols])
  expect_identical(same$audit_trail, base$audit_trail)

  # The row_index table now points at the wrong rows; the keyed one does not.
  shifted <- apply_multi_analyte_resolutions(keyed_fixture(lead_rows = 2L), "Name", keyed, cas_cols = "CASRN")
  expect_identical(shifted$cleaned_data[-(1:2), cols], base$cleaned_data[cols])
  expect_equal(shifted$cleaned_data$Name[1:2], c("Lead", "Lead"))
})

test_that("keyed resolutions stop on unmatched or duplicated keys and carry notes", {
  df <- keyed_fixture()
  # Blank casrn means blank CAS only, so a CAS that matches nothing is an error.
  expect_error(
    apply_multi_analyte_resolutions(
      df,
      "Name",
      tibble::tibble(name = "Alpha + Beta", casrn = "50-00-0", action = "keep"),
      cas_cols = "CASRN"
    ),
    "bad keys: name=Alpha \\+ Beta casrn=50-00-0"
  )
  expect_error(
    apply_multi_analyte_resolutions(
      df,
      "Name",
      tibble::tibble(name = rep("Alpha + Beta", 2), casrn = c(NA, ""), action = "keep"),
      cas_cols = "CASRN"
    ),
    "must be unique"
  )
  noted <- apply_multi_analyte_resolutions(
    df,
    "Name",
    tibble::tibble(name = "Alpha + Beta", casrn = "64-17-5", action = "keep", note = "sold as a blend"),
    cas_cols = "CASRN"
  )
  expect_equal(noted$audit_trail$reason, "Kept as combined analyte (note: sold as a blend)")
  expect_equal(sum(noted$cleaned_data$multi_analyte_resolution %in% "keep_combined"), 1L)
})

test_that("row_index resolutions are rekeyed only when that changes nothing", {
  df <- keyed_fixture()
  rekey <- function(resolutions) key_multi_analyte_resolutions(df, resolutions, "Name", "CASRN")
  keyed <- rekey(tibble::tibble(
    row_index = c(1L, 3L, 2L),
    action = c("split", "split", "keep"),
    values = I(list(c("Alpha", "Beta"), c("Alpha", "Beta"), NULL))
  ))
  expect_equal(
    keyed,
    tibble::tibble(
      name = "Alpha + Beta",
      casrn = c(NA, "64-17-5"),
      action = c("split", "keep"),
      value = c("Alpha; Beta", NA)
    )
  )
  # Same key decided two ways, or only one of its rows decided: keep row_index.
  expect_null(rekey(tibble::tibble(row_index = c(1L, 3L), action = c("split", "keep"))))
  expect_null(rekey(tibble::tibble(row_index = 1L, action = "split")))
  # A split part holding ";" cannot be written as text.
  expect_null(rekey(tibble::tibble(row_index = 2L, action = "split", values = I(list(c("a;b", "c"))))))
})

test_that("apply_multi_analyte_resolutions warns when row_index overrides a name key", {
  df <- multi_analyte_fixture(c("lead and arsenic", "nitrate + nitrite"))
  spec <- tibble::tibble(row_index = 2L, name = "lead and arsenic", action = "keep")

  expect_warning(result <- apply_multi_analyte_resolutions(df, "analyte", spec), "matched by row_index")

  expect_equal(result$cleaned_data$multi_analyte_resolution[2], "keep_combined")
})
