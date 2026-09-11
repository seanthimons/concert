# source('scripts/validate_published_media.R'); validate_published_media()
validate_published_media <- function() {
  # The Windows session may inherit a Unix-only C.UTF-8 locale.
  if (.Platform$OS.type == "windows") {
    withr::local_locale(c(LC_COLLATE = "English_United States.utf8", LC_CTYPE = "English_United States.utf8"))
  }
  devtools::test(
    filter = "media|harmonize-module|code-generation|export-import|toxval|unit-harmonizer|wqx|consensus|headless-write-files",
    stop_on_failure = TRUE
  )
}
