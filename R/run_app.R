#' Launch the CONCERT Shiny Application
#'
#' Launches the CONCERT Shiny app for chemical inventory upload, cleaning,
#' and curation. The app provides a full workflow from file upload through
#' CompTox API curation with audit trail export.
#'
#' @param ... Additional arguments passed to \code{\link[shiny]{runApp}},
#'   such as \code{port}, \code{host}, or \code{launch.browser}.
#'
#' @return Invisible \code{NULL}. The function is called for its side effect
#'   of launching the Shiny application.
#'
#' @examples
#' \dontrun{
#' # Launch with default settings
#' run_app()
#'
#' # Launch on specific port without browser
#' run_app(port = 3838, launch.browser = FALSE)
#' }
#'
#' @export
run_app <- function(...) {
  app_dir <- system.file("app", package = "concert")

  if (app_dir == "") {
    stop(
      "Could not find app directory. Is concert installed?",
      call. = FALSE
    )
  }

  shiny::runApp(app_dir, ...)

  invisible(NULL)
}
