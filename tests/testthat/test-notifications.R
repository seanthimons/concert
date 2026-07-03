test_that("notify_user logs warning notifications and delegates to Shiny", {
  calls <- list()
  local_mocked_bindings(
    showNotification = function(ui, type = "default", ...) {
      calls[[length(calls) + 1L]] <<- list(ui = ui, type = type, args = list(...))
      "notification-id"
    },
    .package = "shiny"
  )

  expect_message(
    result <- notify_user("Check input columns", type = "warning", duration = 10),
    "\\[concert warning\\].*Check input columns"
  )

  expect_equal(result, "notification-id")
  expect_equal(length(calls), 1)
  expect_equal(calls[[1]]$type, "warning")
  expect_equal(calls[[1]]$args$duration, 10)
})

test_that("notify_user logs error notifications and delegates to Shiny", {
  calls <- list()
  local_mocked_bindings(
    showNotification = function(ui, type = "default", ...) {
      calls[[length(calls) + 1L]] <<- list(ui = ui, type = type, args = list(...))
      "error-id"
    },
    .package = "shiny"
  )

  expect_message(
    result <- notify_user("Pipeline failed", type = "error", duration = NULL),
    "\\[concert error\\].*Pipeline failed"
  )

  expect_equal(result, "error-id")
  expect_equal(length(calls), 1)
  expect_equal(calls[[1]]$type, "error")
  expect_null(calls[[1]]$args$duration)
})

test_that("notify_user keeps message notifications quiet", {
  calls <- list()
  local_mocked_bindings(
    showNotification = function(ui, type = "default", ...) {
      calls[[length(calls) + 1L]] <<- list(ui = ui, type = type, args = list(...))
      "message-id"
    },
    .package = "shiny"
  )

  expect_message(
    result <- notify_user("Upload complete", type = "message", duration = 3),
    NA
  )

  expect_equal(result, "message-id")
  expect_equal(length(calls), 1)
  expect_equal(calls[[1]]$type, "message")
})

test_that("notify_user renders HTML notification content as readable console text", {
  local_mocked_bindings(
    showNotification = function(ui, type = "default", ...) "html-id",
    .package = "shiny"
  )

  html_ui <- shiny::div(
    shiny::tags$strong("Error processing file:"),
    shiny::tags$br(),
    "bad <name>"
  )

  expect_message(
    notify_user(html_ui, type = "error"),
    "\\[concert error\\].*Error processing file: bad <name>"
  )
})

test_that("log_condition includes level, context, message, and condition class", {
  err <- simpleError("boom")

  expect_message(
    result <- log_condition("run curation", err, level = "error"),
    "\\[concert error\\].*context=run curation.*message=boom.*class=simpleError,error,condition"
  )
  expect_identical(result, err)
})

test_that("log_condition handles custom condition classes", {
  err <- structure(
    list(message = "custom failure", call = NULL),
    class = c("concert_custom_error", "error", "condition")
  )

  expect_message(
    log_condition("reference import", err, level = "warning"),
    "\\[concert warning\\].*context=reference import.*message=custom failure.*class=concert_custom_error,error,condition"
  )
})
