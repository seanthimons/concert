test_that("review filters bound preloaded choices and search the full column", {
  values <- sprintf("chemical-%05d", seq_len(8216L))
  config <- build_review_filter_choices(values, "Chemical", limit = 100L)
  expect_equal(nrow(config$choices), 100L)
  expect_equal(config$populated_count, 8216L)
  found <- build_review_filter_choices(values, "Chemical", query = "08216", limit = 100L)
  expect_equal(found$choices$label, "chemical-08216")
  expect_equal(which(review_filter_matches(values, found$choices$token)), 8216L)
  response <- review_filter_response(
    list(values = values, column_name = "Chemical"),
    list(QUERY_STRING = "query=08216")
  )
  expect_equal(response$status, 200L)
  expect_equal(jsonlite::fromJSON(response$body)$label, "chemical-08216")
})

test_that("bulk group expansion handles all selections in one lookup", {
  groups <- list(c(2L, 5L), 8L, c(10L, 11L))
  expect_equal(get_group_rows(c(10L, 2L, 10L), groups), c(10L, 11L, 2L, 5L))
  expect_equal(get_group_rows(c(8L, 3L), groups), c(8L, 3L))
  expect_equal(get_group_rows(integer(), groups), integer())
  expect_equal(get_group_rows(2L, groups), c(2L, 5L))
})

test_that("empty review columns disappear without hiding unresolved editing", {
  df <- data.frame(
    Chemical = c("A", "B"),
    empty = c(NA_character_, "  "),
    number = c(NA_real_, NA_real_),
    zero = c(0, 0),
    flag = c(FALSE, FALSE),
    consensus_status = c("error", "unresolvable"),
    consensus_dtxsid = NA_character_
  )
  expect_setequal(review_empty_columns(df), c("empty", "number"))
  df$consensus_status <- "agree"
  expect_setequal(review_empty_columns(df), c("empty", "number", "consensus_dtxsid"))
  expect_equal(review_empty_columns(df[FALSE, ]), character())
})

test_that("large review module sends one page and does not rebuild for visibility", {
  source(test_path("..", "..", "scripts", "benchmark_review_results.R"), local = TRUE)
  df <- review_benchmark_data()
  store <- review_benchmark_store(df)
  shiny::testServer(mod_review_results_server, args = list(data_store = store), {
    payload <- output$curation_table
    attrs <- jsonlite::fromJSON(payload, simplifyVector = FALSE)$x$tag$attribs
    expect_equal(length(attrs$data$Chemical), 25L)
    expect_equal(attrs$serverRowCount, 8216L)
    expect_lt(nchar(payload, type = "bytes"), 1000000)
    expect_false("Sample3" %in% names(attrs$data))
    expect_false("dtxsid" %in% names(attrs$data))
    expect_equal(nrow(data_store$resolution_state), 8216L)
    expect_true("Sample3" %in% names(data_store$resolution_state))

    session$setInputs(visible_cols = c("Chemical", "consensus_dtxsid"))
    expect_identical(output$curation_table, payload)
    session$setInputs(curation_table_selected_rows = c(8216L, 2L, NA, -1L, 9000L))
    expect_equal(data_store$selected_visible_rows, c(8216L, 2L))
    session$setInputs(curation_table_selected_rows = seq_len(8216L))
    expect_equal(data_store$selected_visible_rows, seq_len(8216L))
    session$setInputs(filter_errors = 1L)
    filtered <- jsonlite::fromJSON(output$curation_table, simplifyVector = FALSE)$x$tag$attribs
    expect_equal(filtered$data$.review_row[[1]], 2L)
    session$setInputs(curation_table_selected_rows = c(1L, 2L))
    expect_equal(data_store$selected_visible_rows, c(2L, 6L))
  })
})

test_that("review server rendering handles an empty filtered result", {
  source(test_path("..", "..", "scripts", "benchmark_review_results.R"), local = TRUE)
  store <- review_benchmark_store(review_benchmark_data(1L))
  shiny::testServer(mod_review_results_server, args = list(data_store = store), {
    expect_equal(jsonlite::fromJSON(output$curation_table)$x$tag$attribs$serverRowCount, 1L)
    session$setInputs(filter_errors = 1L)
    expect_equal(jsonlite::fromJSON(output$curation_table)$x$tag$attribs$serverRowCount, 0L)
    expect_null(data_store$selected_visible_rows)
  })
})
