find_app_file <- function() {
  candidates <- c(
    file.path(getwd(), "inst", "app", "app.R"),
    testthat::test_path("../../inst/app/app.R")
  )

  for (candidate in candidates) {
    if (file.exists(candidate)) {
      return(candidate)
    }
  }

  NULL
}

test_that("app title reports package version", {
  app_path <- find_app_file()
  skip_if(is.null(app_path), "inst/app/app.R not found")

  app_source <- paste(readLines(app_path, warn = FALSE), collapse = "\n")

  expect_match(app_source, 'app_version <- as.character\\(utils::packageVersion\\("concert"\\)\\)')
  expect_match(app_source, 'title = paste\\("CONCERT", app_version\\)')
  expect_no_match(app_source, 'title = "CONCERT Data Upload & Preview"')
})
