test_that("full app permits chemical curation when paired cleaning is unavailable", {
  navigation <- new.env(parent = emptyenv())
  navigation$visible <- logical()
  local_mocked_bindings(
    nav_show = function(id, target, ..., session) {
      navigation$visible[target] <- TRUE
    },
    nav_hide = function(id, target, ..., session) {
      navigation$visible[target] <- FALSE
    },
    .package = "bslib"
  )
  app <- new.env(parent = globalenv())
  sys.source(test_path("../../inst/app/app.R"), envir = app)

  shiny::testServer(app$server, {
    session$flushReact()
    expect_false(navigation$visible[["run_curation_tab"]])
    data_store$clean <- tibble::tibble(chemical = "Synthetic mixture", cas = "64-17-5", source_id = "DTXSID123")
    data_store$selected_columns <- names(data_store$clean)
    session$flushReact()

    tag_cases <- list(
      list(source_id = "DTXSID"),
      list(chemical = "Name", source_id = "DTXSID"),
      list(chemical = "Name"),
      list(cas = "CASRN")
    )
    for (case in seq_along(tag_cases)) {
      chemical_tags <- tag_cases[[case]]
      session$setInputs(
        `tags-tag_chemical` = chemical_tags$chemical %||% "",
        `tags-tag_cas` = chemical_tags$cas %||% "",
        `tags-tag_source_id` = chemical_tags$source_id %||% "",
        `tags-apply_tags` = case
      )
      session$flushReact()
      expect_true(navigation$visible[["run_curation_tab"]])
      expect_false(navigation$visible[["clean_data"]])
      expect_null(data_store$cleaned_data)
    }

    data_store$column_tags <- list(chemical = "Name", cas = "CASRN")
    session$flushReact()
    expect_true(navigation$visible[["clean_data"]])
    expect_false(navigation$visible[["run_curation_tab"]])
    data_store$cleaned_data <- data_store$clean
    data_store$cleaning_audit <- tibble::tibble(step = "synthetic", new_value = "Synthetic mixture", reason = "test")
    data_store$resolution_state <- dplyr::mutate(data_store$clean, .pinned = FALSE, consensus_status = "error")
    expect_false(is.null(data_store$cleaned_data))
    expect_false(is.null(data_store$resolution_state))

    # Re-tagging must remove old cleaned content and downstream results before
    # the direct curation path can consume the original extracted source rows.
    data_store$column_tags <- list(source_id = "DTXSID")
    session$flushReact()
    expect_null(data_store$cleaned_data)
    expect_null(data_store$cleaning_audit)
    expect_null(data_store$resolution_state)
    expect_true(navigation$visible[["run_curation_tab"]])
    expect_false(navigation$visible[["clean_data"]])

    data_store$column_tags <- list()
    session$flushReact()
    expect_false(navigation$visible[["run_curation_tab"]])
    expect_false(navigation$visible[["clean_data"]])
  })
})
