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
  expect_true(is.na(detection$site_label))
  expect_equal(detection$latitude, "decimal_latitude")
  expect_equal(detection$longitude, "decimal_longitude")
  expect_equal(detection$grouping, "watershed_name")
  expect_equal(detection$grouping_type, "watershed")
})

test_that("detect_site_columns finds source label columns", {
  df <- tibble::tibble(
    sample_id = c("S1", "S2"),
    site_label = c("Raw Influent", "Plant Inlet"),
    station_id = c("INF", "INF")
  )

  detection <- detect_site_columns(df)

  expect_true(detection$has_site_context)
  expect_equal(detection$site_label, "site_label")
  expect_equal(detection$site_id, "station_id")
})

test_that("extract_site_candidates preserves distinct raw labels in first-seen order", {
  df <- tibble::tibble(
    site_label = c("Raw Influent", "", NA, "raw influent", "Plant Inlet", "Raw Infl.", "Raw Infl."),
    site_id = c("INF", "", NA, "INF", "INF", "INF", "INF"),
    latitude = c("45.1", "", NA, "45.2", "45.3", "45.4", "45.5"),
    longitude = c("-93.1", "", NA, "-93.2", "-93.3", "-93.4", "-93.5"),
    watershed = c("Mississippi", "", NA, "Mississippi", "Mississippi", "Mississippi", "Mississippi")
  )

  result <- extract_site_candidates(df)

  expect_equal(result$source_site_label, c("Raw Influent", "Plant Inlet", "Raw Infl."))
  expect_equal(result$site_identifier, c("INF", "INF", "INF"))
  expect_true(all(is.na(result$site_order)))
  expect_equal(result$site_suborder, rep(1L, 3))
  expect_equal(result$source_row, c(1L, 5L, 6L))
  expect_equal(result$latitude, c(45.1, 45.3, 45.4))
  expect_equal(result$longitude, c(-93.1, -93.3, -93.4))
  expect_equal(result$source_site_id, c("INF", "INF", "INF"))
  expect_equal(result$source_latitude, c("45.1", "45.3", "45.4"))
  expect_equal(result$grouping_type, c("watershed", "watershed", "watershed"))
  expect_equal(result$site_label_column, rep("site_label", 3))
})

test_that("extract_site_candidates supports coordinate-only site rows and duplicate coordinates", {
  df <- tibble::tibble(
    latitude = c(45, 45, 46, NA),
    longitude = c(-93, -93, -94, NA)
  )

  result <- extract_site_candidates(df)

  expect_equal(result$site_identifier, c("coord:45,-93", "coord:46,-94"))
  expect_equal(result$source_site_label, c("coord:45,-93", "coord:46,-94"))
  expect_true(all(is.na(result$site_order)))
  expect_equal(result$source_row, c(1L, 3L))
  expect_equal(result$latitude, c(45, 46))
  expect_equal(result$longitude, c(-93, -94))
})

test_that("source labels fall back to site name, site ID, then coordinates", {
  name_detection <- list(
    site_label = NA_character_,
    site_name = "site_name",
    site_id = NA_character_,
    latitude = NA_character_,
    longitude = NA_character_,
    grouping = NA_character_,
    grouping_type = NA_character_,
    has_site_context = TRUE
  )
  id_detection <- name_detection
  id_detection$site_name <- NA_character_
  id_detection$site_id <- "site_id"
  coord_detection <- id_detection
  coord_detection$site_id <- NA_character_
  coord_detection$latitude <- "latitude"
  coord_detection$longitude <- "longitude"

  expect_equal(
    extract_site_candidates(tibble::tibble(site_name = c("Alpha", "Beta")), name_detection)$source_site_label,
    c("Alpha", "Beta")
  )
  expect_equal(
    extract_site_candidates(tibble::tibble(site_id = c("A", "B")), id_detection)$source_site_label,
    c("A", "B")
  )
  expect_equal(
    extract_site_candidates(
      tibble::tibble(latitude = c(45, 46), longitude = c(-93, -94)),
      coord_detection
    )$source_site_label,
    c("coord:45,-93", "coord:46,-94")
  )
})

test_that("alias map keeps raw labels while manifest collapses canonical sites", {
  site_context <- tibble::tibble(
    source_site_label = c("Raw Influent", "Raw Infl.", "Plant Inlet", ""),
    site_order = c(1L, 1L, 1L, 2L),
    site_suborder = c(1L, 1L, 1L, 1L),
    site_identifier = c("INF", "INF", "INF", ""),
    site_name = c("Influent", "Influent", "Influent", ""),
    site_label = c("Influent", "Influent", "Influent", ""),
    source_row = c(1L, 2L, 3L, 4L)
  )

  alias_map <- build_site_alias_map(site_context)
  manifest <- build_site_manifest(alias_map)

  expect_equal(alias_map$source_site_label, c("Raw Influent", "Raw Infl.", "Plant Inlet"))
  expect_equal(alias_map$site_identifier, c("INF", "INF", "INF"))
  expect_equal(manifest$site_identifier, "INF")
  expect_equal(manifest$source_site_label, "Raw Influent")
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
    site_alias_map = NULL,
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
    site_alias_map = NULL,
    site_manifest = NULL,
    site_context_status = NULL
  )

  suppressWarnings(shiny::testServer(mod_dataset_context_server, args = list(data_store = site_store), {
    session$flushReact()
    nudge <- paste(as.character(output$dataset_context_nudge), collapse = "")
    expect_match(nudge, "Dataset Context", fixed = TRUE)
    expect_match(nudge, "2 distinct raw site label", fixed = TRUE)

    session$setInputs(apply_site_manifest = 1)
    session$flushReact()

    expect_equal(site_store$site_context_status, "curated")
    expect_equal(site_store$site_alias_map$source_site_label, c("A", "B"))
    expect_equal(site_store$site_manifest$site_identifier, c("A", "B"))
    expect_true(all(is.na(site_store$site_manifest$site_order)))
  }))
})

test_that("Dataset Context table hides audit columns until requested", {
  manifest <- extract_site_candidates(tibble::tibble(
    site_id = c("A", "B"),
    latitude = c(45.1, 46.2),
    longitude = c(-93.1, -94.2)
  ))

  default_table <- site_context_table_data(manifest)
  audit_table <- site_context_table_data(manifest, show_audit_columns = TRUE)

  expect_equal(names(default_table), c("source_site_label", site_context_editable_columns()))
  expect_true("source_site_label" %in% names(default_table))
  expect_false("source_row" %in% names(default_table))
  expect_false("site_id_column" %in% names(default_table))
  expect_equal(names(audit_table), site_context_manifest_columns())
  expect_true("source_site_label" %in% names(audit_table))
  expect_true("source_row" %in% names(audit_table))
  expect_true("site_id_column" %in% names(audit_table))
})

test_that("Dataset Context datatable uses read-only source labels and 25-row pages", {
  manifest <- extract_site_candidates(tibble::tibble(
    site_id = c("A", "B"),
    latitude = c(45.1, 46.2),
    longitude = c(-93.1, -94.2)
  ))

  widget <- site_context_datatable(manifest)

  expect_equal(widget$x$options$pageLength, 25)
  expect_equal(widget$x$options$lengthMenu[[1]], c(10, 25, 50, 100, -1))
  expect_equal(widget$x$options$lengthMenu[[2]], c("10", "25", "50", "100", "All"))
  expect_true(0 %in% widget$x$editable$disable$columns)
  expect_equal(widget$x$selection$mode, "multiple")
})

test_that("Dataset Context can fill selected aliases from the first selected row", {
  manifest <- tibble::tibble(
    source_site_label = c("Raw Influent", "Raw Infl.", "Plant Inlet"),
    site_order = c(1L, 2L, 3L),
    site_suborder = c(1L, 1L, 1L),
    site_identifier = c("INF", "RAW", "INLET"),
    site_name = c("Influent", "Raw", "Inlet"),
    site_label = c("Influent", "Raw", "Inlet"),
    latitude = c(45.1, 46.2, 47.3),
    longitude = c(-93.1, -94.2, -95.3),
    grouping_type = c("watershed", "group", "group"),
    grouping_label = c("Upper", "Raw group", "Inlet group"),
    source_row = c(1L, 2L, 3L)
  )

  result <- site_context_fill_selected_aliases(manifest, c(1L, 2L, 3L))

  expect_equal(result$source_site_label, c("Raw Influent", "Raw Infl.", "Plant Inlet"))
  expect_equal(result$site_identifier, rep("INF", 3))
  expect_equal(result$site_name, rep("Influent", 3))
  expect_equal(result$site_label, rep("Influent", 3))
  expect_equal(result$latitude, rep(45.1, 3))
  expect_equal(result$longitude, rep(-93.1, 3))
})

test_that("Dataset Context cell edits refresh table data without resetting table state", {
  replacement_calls <- list()
  testthat::local_mocked_bindings(
    replaceData = function(proxy, data, ..., resetPaging = TRUE, clearSelection = "all") {
      replacement_calls[[length(replacement_calls) + 1L]] <<- list(
        data = data,
        resetPaging = resetPaging,
        clearSelection = clearSelection,
        dots = list(...)
      )
      invisible(proxy)
    },
    .package = "DT"
  )

  site_store <- shiny::reactiveValues(
    clean = tibble::tibble(
      site_id = c("A", "B", "A"),
      latitude = c(45.1, 46.2, 45.1),
      longitude = c(-93.1, -94.2, -93.1)
    ),
    site_context_detection = NULL,
    site_context_candidates = NULL,
    site_alias_map = NULL,
    site_manifest = NULL,
    site_context_status = NULL
  )

  suppressWarnings(shiny::testServer(mod_dataset_context_server, args = list(data_store = site_store), {
    session$flushReact()
    expect_length(replacement_calls, 0)

    session$setInputs(site_manifest_table_cell_edit = list(row = 1, col = 0, value = "changed"))
    session$flushReact()

    expect_length(replacement_calls, 0)

    session$setInputs(site_manifest_table_cell_edit = list(row = 2, col = 1, value = "7"))
    session$flushReact()

    expect_length(replacement_calls, 1)
    expect_false(replacement_calls[[1]]$resetPaging)
    expect_equal(replacement_calls[[1]]$clearSelection, "none")
    expect_false(replacement_calls[[1]]$dots$rownames)
    expect_equal(replacement_calls[[1]]$data$site_order, c(NA_integer_, 7L))
    expect_equal(replacement_calls[[1]]$data$site_identifier, c("A", "B"))
    expect_equal(names(replacement_calls[[1]]$data), c("source_site_label", site_context_editable_columns()))

    session$setInputs(show_site_audit_columns = TRUE)
    session$setInputs(site_manifest_table_cell_edit = list(row = 1, col = 1, value = "3"))
    session$flushReact()

    expect_length(replacement_calls, 2)
    expect_false(replacement_calls[[2]]$resetPaging)
    expect_equal(replacement_calls[[2]]$clearSelection, "none")
    expect_equal(replacement_calls[[2]]$data$site_order, c(3L, 7L))
    expect_equal(names(replacement_calls[[2]]$data), site_context_manifest_columns())
  }))
})

test_that("site manifest and alias map export and hydrate with source values intact", {
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
  site_alias_map <- tibble::tibble(
    source_site_label = c("Alpha raw", "Beta raw", "Beta short"),
    site_order = c(2L, 1L, 1L),
    site_suborder = c(1L, 1L, 1L),
    site_identifier = c("A", "B", "B"),
    site_name = c("Alpha", "Beta", "Beta"),
    site_label = c("Alpha", "Beta", "Beta"),
    latitude = c(45.1, 46.2, 46.2),
    longitude = c(-93.1, -94.2, -94.2),
    grouping_type = c("watershed", "watershed", "watershed"),
    grouping_label = c("Upper", "Lower", "Lower"),
    source_row = c(1L, 2L, 3L),
    source_site_id = c("A", "B", "B"),
    source_site_name = c("Alpha", "Beta", "Beta")
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
    site_alias_map = site_alias_map
  )

  expect_true("Site Manifest" %in% names(sheets))
  expect_true("Site Alias Map" %in% names(sheets))
  expect_equal(sheets[["Site Manifest"]]$site_identifier, c("B", "A"))
  expect_equal(sheets[["Site Manifest"]]$source_site_id, c("B", "A"))
  expect_equal(sheets[["Site Alias Map"]]$source_site_label, c("Alpha raw", "Beta raw", "Beta short"))
  expect_equal(sheets[["Site Alias Map"]]$site_identifier, c("A", "B", "B"))

  path <- tempfile(fileext = ".xlsx")
  withr::defer(unlink(path))
  writexl::write_xlsx(sheets, path)
  parsed <- parse_concert_export(path)
  hydrated <- hydrate_session_state(parsed, reference_lists)

  expect_equal(hydrated$state$site_context_status, "curated")
  expect_equal(hydrated$state$site_manifest$site_identifier, c("B", "A"))
  expect_equal(hydrated$state$site_manifest$source_site_name, c("Beta", "Alpha"))
  expect_equal(hydrated$state$site_alias_map$source_site_label, c("Alpha raw", "Beta raw", "Beta short"))
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

  expect_match(script, "site_alias_map <- tibble::tibble(", fixed = TRUE)
  expect_match(script, 'site_identifier = c\\("A",[[:space:]]*"B"[[:space:]]*\\)')
  expect_match(script, 'source_site_id = c\\("A",[[:space:]]*"B"[[:space:]]*\\)')
  expect_match(script, "site_manifest <- build_site_manifest(site_alias_map)", fixed = TRUE)
  expect_match(script, "site_manifest = site_manifest", fixed = TRUE)
  expect_match(script, "site_alias_map = site_alias_map", fixed = TRUE)
  expect_silent(parse(text = script))
})

test_that("embedded site alias map literal omits default columns and round-trips", {
  site_manifest <- tibble::tibble(
    source_site_label = c("Influent", "influent ", "INFLUENT-1"),
    site_order = c(1L, 1L, 1L),
    site_name = c("Influent", "Influent", "Influent")
  )

  script <- generate_concert_script(
    input_path = "input.csv",
    output_path = "input_curated.xlsx",
    tag_map = list(chemical = "Name"),
    header_row = 1L,
    site_alias_map = build_site_alias_map(site_manifest)
  )

  expect_match(script, "site_alias_map <- tibble::tibble(", fixed = TRUE)
  expect_no_match(script, "structure(list(", fixed = TRUE)
  expect_no_match(script, "latitude", fixed = TRUE)
  expect_no_match(script, "grouping_type", fixed = TRUE)
  expect_no_match(script, "site_suborder", fixed = TRUE)
  expect_silent(parse(text = script))

  env <- new.env(parent = globalenv())
  for (ex in parse(text = script)) {
    head_sym <- if (is.call(ex)) as.character(ex[[1]])[1] else ""
    if (head_sym %in% c("library", "curate_headless")) {
      next
    }
    eval(ex, envir = env)
  }
  expect_identical(
    build_site_alias_map(env$site_alias_map),
    build_site_alias_map(site_manifest)
  )
  expect_identical(env$site_manifest, build_site_manifest(site_manifest))
})

test_that("constant site alias columns compress to rep() in the embedded literal", {
  site_manifest <- tibble::tibble(
    source_site_label = paste0("Site variant ", 1:6),
    site_order = rep(1L, 6),
    site_name = rep("Influent", 6)
  )

  script <- generate_concert_script(
    input_path = "input.csv",
    output_path = "out.xlsx",
    tag_map = list(chemical = "Name"),
    header_row = 1L,
    site_alias_map = build_site_alias_map(site_manifest)
  )

  expect_match(script, 'site_name = rep("Influent", 6L)', fixed = TRUE)
  expect_match(script, "site_order = rep(1L, 6L)", fixed = TRUE)
  expect_silent(parse(text = script))

  env <- new.env(parent = globalenv())
  for (ex in parse(text = script)) {
    head_sym <- if (is.call(ex)) as.character(ex[[1]])[1] else ""
    if (head_sym %in% c("library", "curate_headless")) next
    eval(ex, envir = env)
  }
  expect_identical(
    build_site_alias_map(env$site_alias_map),
    build_site_alias_map(site_manifest)
  )
})
