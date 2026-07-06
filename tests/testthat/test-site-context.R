test_that("detect_site_columns finds site, coordinate, and grouping columns", {
  df <- tibble::tibble(
    sample_id = c("S1", "S2"),
    monitoring_location_identifier = c("STA-1", "STA-2"),
    decimal_latitude = c(45.1, 45.2),
    decimal_longitude = c(-93.1, -93.2),
    watershed_name = c("Upper", "Lower")
  )

  detection <- detect_site_columns(df)

  expect_true(detection$has_site_context)
  expect_equal(detection$site_id, "monitoring_location_identifier")
  expect_equal(detection$latitude, "decimal_latitude")
  expect_equal(detection$longitude, "decimal_longitude")
  expect_equal(detection$grouping, "watershed_name")
  expect_equal(detection$grouping_type, "watershed")
})

test_that("extract_site_candidates filters blanks, deduplicates mixed case, and leaves order blank", {
  df <- tibble::tibble(
    site_id = c("Site-A", "", NA, "site-a", "Site-B", "Site-C", "Site-C"),
    site_name = c("Alpha", "", NA, "Alpha duplicate", "Beta", "Gamma", "Gamma duplicate"),
    latitude = c("45.1", "", NA, "45.2", NA, "46.0", "46.1"),
    longitude = c("-93.1", "", NA, "-93.2", NA, "-94.0", "-94.1"),
    watershed = c("Mississippi", "", NA, "Mississippi", "Minnesota", "Red", "Red")
  )

  result <- extract_site_candidates(df)

  expect_equal(result$site_identifier, c("Site-A", "Site-B", "Site-C"))
  expect_true(all(is.na(result$site_order)))
  expect_equal(result$site_suborder, rep(1L, 3))
  expect_equal(result$source_row, c(1L, 5L, 6L))
  expect_equal(result$latitude, c(45.1, NA, 46.0))
  expect_equal(result$longitude, c(-93.1, NA, -94.0))
  expect_equal(result$source_site_id, c("Site-A", "Site-B", "Site-C"))
  expect_equal(result$source_latitude, c("45.1", NA, "46.0"))
  expect_equal(result$grouping_type, c("watershed", "watershed", "watershed"))
})

test_that("extract_site_candidates supports coordinate-only site rows and duplicate coordinates", {
  df <- tibble::tibble(
    latitude = c(45, 45, 46, NA),
    longitude = c(-93, -93, -94, NA)
  )

  result <- extract_site_candidates(df)

  expect_equal(result$site_identifier, c("coord:45,-93", "coord:46,-94"))
  expect_true(all(is.na(result$site_order)))
  expect_equal(result$source_row, c(1L, 3L))
  expect_equal(result$latitude, c(45, 46))
  expect_equal(result$longitude, c(-93, -94))
})

test_that("build_chorus_site_manifest preserves blank orders while using source-row fallback", {
  manifest <- tibble::tibble(
    site_order = c(NA_integer_, NA_integer_, NA_integer_),
    site_suborder = c(1L, 1L, 1L),
    site_identifier = c("C", "A", "B"),
    site_name = c("Gamma", "Alpha", "Beta"),
    site_label = c("Gamma", "Alpha", "Beta"),
    source_row = c(30L, 10L, 20L)
  )

  result <- build_chorus_site_manifest(manifest)

  expect_equal(result$site_identifier, c("A", "B", "C"))
  expect_true(all(is.na(result$site_order)))
  expect_equal(result$source_row, c(10L, 20L, 30L))
})

test_that("build_chorus_site_manifest is ordered, distinct, blank-filtered, and deterministic", {
  manifest <- tibble::tibble(
    site_order = c(2L, 1L, 3L, 4L),
    site_suborder = c(1L, 1L, 1L, 1L),
    site_identifier = c("A", "B", "a", ""),
    site_name = c("Alpha", "Beta", "Alpha duplicate", ""),
    site_label = c("Alpha", "Beta", "Alpha duplicate", ""),
    latitude = c(45.1, 46.2, 45.3, NA),
    longitude = c(-93.1, -94.2, -93.3, NA),
    source_row = c(10L, 5L, 11L, 12L)
  )

  first <- build_chorus_site_manifest(manifest)
  second <- build_chorus_site_manifest(manifest[c(4, 3, 2, 1), ])

  expect_equal(first$site_identifier, c("B", "A"))
  expect_equal(first$site_order, c(1L, 2L))
  expect_equal(first$source_row, c(5L, 10L))
  expect_equal(first, second)
})

test_that("Dataset Context nudge appears only when site/location columns are detected", {
  no_site_store <- shiny::reactiveValues(
    clean = tibble::tibble(sample_id = "S1", result = 1),
    site_context_detection = NULL,
    site_context_candidates = NULL,
    site_manifest = NULL,
    site_context_status = NULL
  )

  suppressWarnings(shiny::testServer(mod_dataset_context_server, args = list(data_store = no_site_store), {
    session$flushReact()
    expect_null(output$dataset_context_nudge)
  }))

  site_store <- shiny::reactiveValues(
    clean = tibble::tibble(
      site_id = c("A", "B", "A"),
      latitude = c(45.1, 46.2, 45.1),
      longitude = c(-93.1, -94.2, -93.1)
    ),
    site_context_detection = NULL,
    site_context_candidates = NULL,
    site_manifest = NULL,
    site_context_status = NULL
  )

  suppressWarnings(shiny::testServer(mod_dataset_context_server, args = list(data_store = site_store), {
    session$flushReact()
    nudge <- paste(as.character(output$dataset_context_nudge), collapse = "")
    expect_match(nudge, "Dataset Context", fixed = TRUE)
    expect_match(nudge, "2 distinct site row", fixed = TRUE)

    session$setInputs(apply_site_manifest = 1)
    session$flushReact()

    expect_equal(site_store$site_context_status, "curated")
    expect_equal(site_store$site_manifest$site_identifier, c("A", "B"))
    expect_true(all(is.na(site_store$site_manifest$site_order)))
  }))
})

test_that("site manifest exports and hydrates with source values intact", {
  reference_lists <- list(
    functional_categories = tibble::tibble(term = character(), source = character(), active = logical()),
    stop_words = tibble::tibble(term = character(), source = character(), active = logical()),
    block_patterns = tibble::tibble(term = character(), source = character(), active = logical()),
    strip_terms = tibble::tibble(term = character(), source = character(), active = logical())
  )
  resolution_state <- init_resolution_state(tibble::tibble(
    chemical = c("Acetone", "Benzene"),
    consensus_status = c("agree", "agree"),
    consensus_dtxsid = c("DTXSID1", "DTXSID2"),
    consensus_source = c("consensus", "consensus")
  ))
  site_manifest <- tibble::tibble(
    site_order = c(2L, 1L),
    site_suborder = c(1L, 1L),
    site_identifier = c("A", "B"),
    site_name = c("Alpha", "Beta"),
    site_label = c("Alpha", "Beta"),
    latitude = c(45.1, 46.2),
    longitude = c(-93.1, -94.2),
    grouping_type = c("watershed", "watershed"),
    grouping_label = c("Upper", "Lower"),
    source_row = c(1L, 2L),
    source_site_id = c("A", "B"),
    source_site_name = c("Alpha", "Beta")
  )

  sheets <- build_export_sheets(
    raw = tibble::tibble(chemical = c("Acetone", "Benzene")),
    resolution_state = resolution_state,
    consensus_summary = recalc_consensus_summary(resolution_state),
    cleaning_audit = tibble::tibble(),
    reference_lists = reference_lists,
    column_tags = list(chemical = "Name"),
    detection = list(method = "manual", confidence = 1, header_row = 1L),
    file_info = list(name = "input.csv", size = 10),
    site_manifest = site_manifest
  )

  expect_true("Site Manifest" %in% names(sheets))
  expect_equal(sheets[["Site Manifest"]]$site_identifier, c("B", "A"))
  expect_equal(sheets[["Site Manifest"]]$source_site_id, c("B", "A"))

  path <- tempfile(fileext = ".xlsx")
  withr::defer(unlink(path))
  writexl::write_xlsx(sheets, path)
  parsed <- parse_concert_export(path)
  hydrated <- hydrate_session_state(parsed, reference_lists)

  expect_equal(hydrated$state$site_context_status, "curated")
  expect_equal(hydrated$state$site_manifest$site_identifier, c("B", "A"))
  expect_equal(hydrated$state$site_manifest$source_site_name, c("Beta", "Alpha"))
})

test_that("generate_concert_script embeds site manifest replay input", {
  site_manifest <- tibble::tibble(
    site_order = c(2L, 1L),
    site_suborder = c(1L, 1L),
    site_identifier = c("A", "B"),
    site_name = c("Alpha", "Beta"),
    site_label = c("Alpha", "Beta"),
    latitude = c(45.1, 46.2),
    longitude = c(-93.1, -94.2),
    source_row = c(1L, 2L),
    source_site_id = c("A", "B")
  )

  script <- generate_concert_script(
    input_path = "input.csv",
    output_path = "input_curated.xlsx",
    tag_map = list(chemical = "Name", casrn = "CASRN"),
    header_row = 1L,
    site_manifest = site_manifest
  )

  expect_match(script, "site_manifest <- structure(list(", fixed = TRUE)
  expect_match(script, 'site_identifier = c\\("B",[[:space:]]*"A"[[:space:]]*\\)')
  expect_match(script, 'source_site_id = c\\("B",[[:space:]]*"A"[[:space:]]*\\)')
  expect_match(script, "site_manifest = site_manifest", fixed = TRUE)
  expect_silent(parse(text = script))
})
