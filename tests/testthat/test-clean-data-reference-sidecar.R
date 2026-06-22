test_that("clean data chip operations persist sidecar-backed reference lists", {
  withr::with_tempdir({
    cache_dir <- file.path(getwd(), "reference_cache")
    dir.create(cache_dir)

    local_mocked_bindings(
      resolve_reference_cache_dir = function(cache_dir_arg = NULL) cache_dir,
      .package = "concert"
    )

    reference_lists <- list(
      functional_categories = tibble::tibble(term = character(), source = character(), active = logical()),
      stop_words = load_stop_words(cache_dir),
      block_patterns = load_block_patterns(cache_dir),
      strip_terms = load_strip_terms(cache_dir)
    )
    data_store <- shiny::reactiveValues(
      reference_lists = reference_lists,
      column_tags = NULL,
      clean = NULL,
      cleaned_data = NULL,
      cleaning_audit = NULL
    )

    shiny::testServer(mod_clean_data_server, args = list(
      data_store = data_store,
      on_cleaning_complete = NULL
    ), {
      session$flushReact()

      session$setInputs(chip_add = list(type = "stop_words", term = "persisted", ts = 1))
      session$flushReact()
      sidecar <- readRDS(file.path(cache_dir, "user_reference_lists.rds"))
      expect_true("persisted" %in% sidecar$stop_words$term)
      expect_true(sidecar$stop_words$active[sidecar$stop_words$term == "persisted"])
      expect_equal(sidecar$stop_words$match_mode[sidecar$stop_words$term == "persisted"], "literal_word")

      session$setInputs(chip_toggle = list(type = "stop_words", term = "test", ts = 2))
      session$flushReact()
      sidecar <- readRDS(file.path(cache_dir, "user_reference_lists.rds"))
      test_row <- sidecar$stop_words[sidecar$stop_words$term == "test", ]
      expect_equal(test_row$source, "user")
      expect_false(test_row$active)

      session$setInputs(chip_remove = list(type = "stop_words", term = "persisted", ts = 3))
      session$flushReact()
      sidecar <- readRDS(file.path(cache_dir, "user_reference_lists.rds"))
      expect_false("persisted" %in% sidecar$stop_words$term)
      expect_true("test" %in% sidecar$stop_words$term)
    })
  })
})

test_that("reference list help text describes each editor semantics", {
  expect_match(reference_list_help_text("functional_categories"), "warning flags")
  expect_match(reference_list_help_text("stop_words"), "generic")
  expect_match(reference_list_help_text("block_patterns"), "Regex")
  expect_match(reference_list_help_text("block_patterns"), "anchors")
  expect_match(reference_list_help_text("strip_terms"), "modify|remove")
})

test_that("preflight reference toggle activates inactive terms for the run only", {
  reference_lists <- list(
    functional_categories = empty_reference_list_tbl(),
    stop_words = tibble::tibble(
      term = "ingredient",
      pattern = "ingredient",
      match_mode = "literal_word",
      source = "legacy_review",
      active = FALSE,
      notes = NA_character_
    ),
    block_patterns = empty_reference_list_tbl(),
    strip_terms = empty_reference_list_tbl(),
    isotope_lookup = list(
      lookup = tibble::tibble(
        symbol = character(),
        mass = character(),
        element_name = character(),
        shortcode = character(),
        canonical = character(),
        dtxsid = character()
      ),
      elem_alt_names = character()
    )
  )

  data_store <- shiny::reactiveValues(
    reference_lists = reference_lists,
    column_tags = c(chemical_name = "Name", casrn = "CASRN"),
    clean = tibble::tibble(chemical_name = "ingredient", casrn = "67-64-1"),
    cleaned_data = NULL,
    cleaning_audit = NULL,
    curation_results = NULL,
    resolved_data = NULL,
    review_visible_cols = NULL
  )

  run_mask <- list(
    unicode = FALSE,
    whitespace = FALSE,
    cas = FALSE,
    names = TRUE,
    isotopes = FALSE,
    multi = FALSE,
    chiral = FALSE,
    units = FALSE,
    duration = FALSE,
    dates = FALSE,
    media = FALSE,
    wqx_threshold = 0.85,
    starts_with = FALSE,
    activate_all_references = FALSE
  )

  shiny::testServer(mod_clean_data_server, args = list(
    data_store = data_store,
    on_cleaning_complete = NULL
  ), {
    execute_pipeline(run_mask)
    expect_true(is.na(data_store$cleaned_data$cleaning_flag[1]))
    expect_false(data_store$activate_all_references)

    data_store$clean <- tibble::tibble(chemical_name = "ingredient", casrn = "67-64-1")
    data_store$cleaned_data <- NULL
    data_store$cleaning_audit <- NULL
    run_mask$activate_all_references <- TRUE
    execute_pipeline(run_mask)

    expect_match(data_store$cleaned_data$cleaning_flag[1], "WARN: stop word")
    expect_false(data_store$reference_lists$stop_words$active[1])
    expect_true(data_store$activate_all_references)
  })
})
