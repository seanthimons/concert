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
