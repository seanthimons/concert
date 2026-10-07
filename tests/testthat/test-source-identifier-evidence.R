test_that("source roles and metadata ignores produce useful diagnostics without lookup", {
  df <- tibble::tibble(name = "Chemical", source_dtxsid = "DTXSID123", dtxsid_raw = "junk", empty_dtxsid = "")
  expect_identical(classify_tags(list(source_dtxsid = "DTXSID"))$chemical_tags, list(source_dtxsid = "DTXSID"))
  diag <- unused_source_identifier_diagnostics(df)
  expect_setequal(diag$column, c("source_dtxsid", "dtxsid_raw"))
  expect_equal(diag$valid_format_count[diag$column == "source_dtxsid"], 1L)
  expect_equal(nrow(unused_source_identifier_diagnostics(df, list(source_dtxsid = "DTXSID"), "dtxsid_raw")), 0L)
  expect_error(unused_source_identifier_diagnostics(df, ignored_identifier_cols = "missing"), "Unknown")
  expect_error(unused_source_identifier_diagnostics(df, list(source_dtxsid = "DTXSID"), "source_dtxsid"), "also be ignored")
})

test_that("source membership retains distinct failure outcomes and original rows", {
  df <- tibble::tibble(source = c(" dtxsid123 ", "DTXSID123", NA, "junk", "DTXSID456"))
  queries <- NULL
  evidence <- source_identifier_evidence(df, list(source = "DTXSID"), function(ids) {
    queries <<- ids
    tibble::tibble(dtxsid = "DTXSID123", preferredName = "Example", casrn = "67-64-1")
  }, checked_at = "fixed")
  expect_identical(queries, c("DTXSID123", "DTXSID456"))
  expect_identical(evidence$source_raw_id, df$source)
  expect_identical(evidence$validation_status, c("validated", "validated", "invalid_format", "invalid_format", "not_found"))
  expect_true(all(evidence$identity_status == "identity_unconfirmed"))
  expect_true(all(evidence$checked_at == "fixed"))
  one <- tibble::tibble(source = "DTXSID123")
  cases <- list(
    unavailable = function(...) stop("offline"),
    returned_id_mismatch = function(...) tibble::tibble(dtxsid = "DTXSID999"),
    ambiguous = function(...) tibble::tibble(dtxsid = rep("DTXSID123", 2)),
    not_found = function(...) tibble::tibble(dtxsid = character())
  )
  for (status in names(cases)) {
    e <- source_identifier_evidence(one, list(source = "DTXSID"), cases[[status]])
    expect_identical(e$validation_status, status)
    expect_identical(e$source_raw_id, one$source)
  }
  expect_identical(source_identifier_evidence(one, list(), function(...) stop("must not query"))$source_raw_id, character())
})

empty_source_lookup_result <- function() tibble::tibble(searchValue = character(), dtxsid = character(),
  preferredName = character(), searchName = character(), rank = integer(), source_tier = character())

test_that("only generated lookup columns vote and raw reserved names survive mapping", {
  df <- tibble::tibble(name = "Example", dtxsid = "DTXSID123", dtxsid_source = "DTXSID456")
  dedup <- deduplicate_tagged_columns(df, list(name = "Name", dtxsid = "DTXSID"))
  expect_identical(dedup$unique_names, "Example")
  expect_false(any(dedup$dedup_key_map$tag_type == "DTXSID"))
  mapped <- map_results_to_rows(df, dedup$dedup_key_map, empty_source_lookup_result())
  expect_identical(mapped$dtxsid, df$dtxsid)
  expect_identical(mapped$dtxsid_source, df$dtxsid_source)
  expect_identical(find_dtxsid_cols(mapped), "dtxsid_lookup_name")
  classified <- classify_consensus(mapped, find_dtxsid_cols(mapped))
  expect_true(is.na(classified$consensus_dtxsid))
  restored <- jsonlite::fromJSON(jsonlite::toJSON(mapped, dataframe = "columns"))
  expect_identical(find_dtxsid_cols(restored), "dtxsid_lookup_name")
  none <- map_results_to_rows(df, deduplicate_tagged_columns(df, list(dtxsid = "DTXSID"))$dedup_key_map,
    empty_source_lookup_result())
  expect_length(find_dtxsid_cols(none), 0L)
})

test_that("validated source IDs remain evidence and preserve conflicting and flagged rows", {
  df <- tibble::tibble(name = "Example", source = "DTXSID123", dtxsid = "DTXSID999",
    lookup_evidence_columns = "dtxsid", row_flag = "BAD", consensus_dtxsid = "DTXSID999")
  attached <- attach_source_identifier_evidence(df, list(source = "DTXSID"), function(...) {
    tibble::tibble(dtxsid = "DTXSID123", preferredName = "Other", casrn = "67-64-1")
  })
  expect_identical(attached$data$source_id_source_validation_status, "validated")
  expect_identical(attached$data$source_id_source_identity_status, "identity_conflict")
  expect_identical(attached$data$consensus_dtxsid, df$consensus_dtxsid)
  expect_identical(attached$data$row_flag, "BAD")
})

test_that("metadata ignore is replayed and persisted in workbook config", {
  script <- generate_concert_script("input.csv", "output.xlsx", list(name = "Name", source = "DTXSID"),
    1L, ignored_identifier_cols = "dtxsid_metadata")
  expect_match(script, "ignored_identifier_cols = \\\"dtxsid_metadata\\\"")
  raw <- tibble::tibble(name = "Example", source = "DTXSID123", dtxsid_metadata = "DTXSID456")
  rs <- init_resolution_state(tibble::tibble(name = "Example", source = "DTXSID123",
    dtxsid_metadata = "DTXSID456", lookup_evidence_columns = "dtxsid_name", dtxsid_name = NA_character_,
    consensus_status = "error", consensus_dtxsid = NA_character_, consensus_source = NA_character_))
  rs <- attach_source_identifier_evidence(rs, list(source = "DTXSID"), function(...) {
    tibble::tibble(dtxsid = "DTXSID123", preferredName = "Example")
  })$data
  sheets <- build_export_sheets(raw, rs, recalc_consensus_summary(rs), empty_cleaning_audit(),
    list(), list(name = "Name", source = "DTXSID"), list(header_row = 1L), list(name = "fixture.csv"),
    ignored_identifier_cols = "dtxsid_metadata")
  path <- tempfile(fileext = ".xlsx")
  withr::defer(unlink(path))
  writexl::write_xlsx(sheets, path)
  parsed <- parse_concert_export(path)
  hydrated <- hydrate_session_state(parsed)$state
  expect_identical(hydrated$ignored_identifier_cols, "dtxsid_metadata")
  expect_identical(hydrated$column_tags$source, "DTXSID")
  expect_identical(find_dtxsid_cols(hydrated$resolution_state), "dtxsid_name")
  expect_identical(hydrated$resolution_state$dtxsid_metadata, "DTXSID456")
  expect_identical(hydrated$resolution_state$source_id_source_validation_status, "validated")
})

test_that("source-only pipeline validates candidates without consensus promotion", {
  df <- tibble::tibble(source = c("DTXSID123", "junk"), dtxsid_metadata = "DTXSID999",
    lookup_evidence_columns = "dtxsid_metadata", row_flag = c("BAD", "FOLLOW-UP"))
  result <- run_curation_pipeline(df, list(source = "DTXSID"),
    ignored_identifier_cols = "dtxsid_metadata", source_lookup_fn = function(ids) {
      expect_identical(ids, "DTXSID123")
      tibble::tibble(dtxsid = ids, preferredName = "Example", casrn = "67-64-1")
    })
  expect_identical(result$results$consensus_dtxsid, rep(NA_character_, 2L))
  expect_length(find_dtxsid_cols(result$results), 0L)
  expect_identical(result$results$dtxsid_metadata, df$dtxsid_metadata)
  expect_identical(result$results$row_flag, df$row_flag)
  expect_identical(result$source_identifier_evidence$validation_status, c("validated", "invalid_format"))
  expect_equal(nrow(result$identifier_diagnostics), 0L)
  expect_warning(unused <- run_curation_pipeline(df, list(),
    source_lookup_fn = function(...) stop("unconfigured data must not query")), "Unused source identifier")
  expect_equal(nrow(unused$source_identifier_evidence), 0L)
  expect_length(find_dtxsid_cols(unused$results), 0L)
})
