test_that("media snapshots require matching schema, artifact and baseline", {
  map <- concert:::load_media_map(tempdir())
  user <- concert:::normalize_media_map_for_display(tibble::tibble(
    term = "unknown", canonical = "drinking water", source = "user", active = TRUE))
  map <- concert:::infer_media_categories(dplyr::bind_rows(user, map))
  snapshot <- concert:::build_media_map_snapshot(map)
  expect_equal(nrow(snapshot$overrides), 1L)
  restored <- concert:::reconstruct_media_map_snapshot(snapshot)
  expect_equal(harmonize_media("unknown", media_map = restored), harmonize_media("unknown", media_map = map))
  literal <- concert:::keyed_map_snapshot_script_literal(snapshot)
  expect_identical(eval(parse(text = literal)), snapshot[c("default_hash", "snapshot_version", "artifact_version", "artifact_sha256", "overrides")])
  for (field in c("snapshot_version", "artifact_version", "artifact_sha256", "default_hash")) {
    bad <- snapshot
    bad[[field]] <- "wrong"
    expect_error(concert:::reconstruct_media_map_snapshot(bad), paste0("Incompatible media replay: ", field))
    bad[[field]] <- NULL
    expect_error(concert:::reconstruct_media_map_snapshot(bad), "Incompatible media replay")
  }
  # Local sidecars must never be treated as the immutable default baseline.
  dir <- withr::local_tempdir()
  saveRDS(user, file.path(dir, "user_media_map.rds"))
  expect_identical(concert:::build_media_map_snapshot(map, dir), snapshot)
  expect_identical(withr::with_locale(c(LC_COLLATE = "C"), concert:::build_media_map_snapshot(map)), snapshot)
  expect_error(concert:::reconstruct_media_map_snapshot("legacy"), "malformed snapshot")
})

test_that("media snapshots omit only exactly reconstructible vocabulary fields", {
  defaults <- concert:::normalize_media_map_for_display(concert:::get_media_table())
  aliases <- tibble::tibble(
    term = c("custom soil", "custom water"),
    canonical = c("soil", "drinking water"),
    source = "user", confidence = "user", active = c(TRUE, FALSE)
  )
  map <- concert:::infer_media_categories(dplyr::bind_rows(
    concert:::normalize_media_map_for_display(aliases), defaults))
  snapshot <- concert:::build_media_map_snapshot(map)
  expect_identical(snapshot$snapshot_version, "2")
  expect_setequal(names(snapshot$overrides), c("term", "canonical", "source", "confidence", "active"))
  restored <- concert:::reconstruct_media_map_snapshot(snapshot)
  expect_equal(restored[seq_len(2), names(map)], map[seq_len(2), ])
  expect_equal(harmonize_media(aliases$term, media_map = restored), harmonize_media(aliases$term, media_map = map))

  full <- snapshot
  full$snapshot_version <- "1"
  full$overrides <- map[seq_len(2), ]
  legacy <- concert:::reconstruct_media_map_snapshot(full)
  expect_equal(legacy[seq_len(2), names(map)], map[seq_len(2), ])
  expect_lt(nchar(concert:::keyed_map_snapshot_script_literal(snapshot)),
    nchar(concert:::keyed_map_snapshot_script_literal(full)) / 2)

  # Keep explicit exceptions, missing values, and fields unknown to the package.
  map$definition[1] <- "Local description"
  map$term_id[2] <- NA_character_
  map$media_category[1] <- "air"
  map$local_note <- NA_character_
  map$local_note[1] <- "retain this"
  custom <- concert:::build_media_map_snapshot(map)
  restored <- concert:::reconstruct_media_map_snapshot(custom)
  expect_equal(restored[seq_len(2), names(map)], map[seq_len(2), ])
  expect_identical(custom$overrides$definition[1], "Local description")
  expect_true(is.na(custom$overrides$term_id[2]))
  expect_identical(custom$overrides$media_category[1], "air")

  # Custom targets without vocabulary context remain explicit too.
  map$canonical[1] <- map$canonical_term[1] <- "local medium"
  custom <- concert:::build_media_map_snapshot(map)
  restored <- concert:::reconstruct_media_map_snapshot(custom)
  expect_equal(restored[seq_len(2), names(map)], map[seq_len(2), ])
})

test_that("generated media replay reproduces headless results offline", {
  local_mocked_bindings(run_curation_pipeline = function(cleaned_data, ...) {
    cleaned_data$consensus_status <- "unresolvable"
    cleaned_data$consensus_dtxsid <- NA_character_
    cleaned_data$consensus_source <- NA_character_
    list(results = cleaned_data, consensus_summary = list())
  })
  file <- test_path("data", "media-curation-acceptance.csv")
  map <- concert:::load_media_map(tempdir())
  user <- concert:::normalize_media_map_for_display(tibble::tibble(
    term = "unknown", canonical = "soil", source = "user", active = TRUE))
  map <- concert:::infer_media_categories(dplyr::bind_rows(user, map))
  tags <- list(chemical_name = "Name", casrn = "CASRN", result = "Result", unit = "Unit", media = "Media")
  original <- curate_headless(file, NULL, tags, header_row = 1L, harmonize = TRUE,
    media_map = map, write_files = FALSE, verbose = FALSE)
  output <- file.path(withr::local_tempdir(), "replay.xlsx")
  script <- generate_concert_script(file, output, tags, header_row = 1L,
    harmonize = TRUE, media_map = map)
  replay <- eval(parse(text = script), new.env())
  expect_equal(replay$media_results, original$media_results)
  expect_equal(replay$data$media, original$data$media)
  expect_equal(replay$data$media_original, original$data$media_original)
  expect_equal(nrow(replay$data), 7L)
})

test_that("workbooks restore media audit, compact overrides and rerunnable originals", {
  raw <- tibble::tibble(media = c(" Drinking WATER ", "soil", "air", "acetone", "lake", "runoff", "unknown", "", NA),
    result = rep(1000, 9), unit = "ppb", consensus_status = "unresolvable", consensus_dtxsid = NA_character_,
    consensus_source = NA_character_)
  refs <- concert:::load_all_reference_lists(concert:::resolve_reference_cache_dir())
  user <- concert:::normalize_media_map_for_display(tibble::tibble(
    term = "unknown", canonical = "soil", source = "user", active = TRUE))
  map <- concert:::infer_media_categories(dplyr::bind_rows(user, refs$media_map))
  tags <- list(media = "Media", result = "Result", unit = "Unit")
  first <- concert:::run_harmonization_runtime(raw, tags, refs$unit_map, media_map = map)
  sheets <- build_export_sheets(raw, first$data, list(), NULL, refs, tags, list(), list(),
    toxval_output = first$toxval_output, media_map = map, media_results = first$media_results)
  expect_equal(nrow(sheets[["Media Overrides"]]), 1L)
  file <- tempfile(fileext = ".xlsx")
  withr::defer(unlink(file))
  writexl::write_xlsx(sheets, file)
  parsed <- parse_concert_export(file)
  restored <- hydrate_session_state(parsed, refs)$state
  expect_identical(restored$media_results, first$media_results)
  expect_identical(restored$resolution_state$media_original, raw$media)
  expect_identical(restored$toxval_output$media_original, raw$media)
  replay <- concert:::run_harmonization_runtime(restored$resolution_state, tags, refs$unit_map,
    media_map = restored$media_map_working)
  expect_identical(replay$media_results, first$media_results)
  expect_equal(replay$toxval_output$media, first$toxval_output$media)
  expect_equal(replay$toxval_output$media_original, raw$media)
  expect_equal(nrow(replay$toxval_output), nrow(raw))
  parsed$media_snapshot$value[parsed$media_snapshot$key == "default_hash"] <- "wrong"
  expect_error(hydrate_session_state(parsed, refs), "Incompatible media replay")
  parsed$media_snapshot <- NULL
  expect_error(hydrate_session_state(parsed, refs), "snapshot metadata is missing")
})
