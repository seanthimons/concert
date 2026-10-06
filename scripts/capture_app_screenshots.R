# Run from the repository root with source('scripts/capture_app_screenshots.R').
# Drives the installed app through the Michigan slice of the SSWQS UAT file and
# saves the screenshots used by vignettes/articles/app-walkthrough.Rmd.
# Needs shinytest2, a Chrome (chromote::chrome_versions_add() works), network
# access, and the CompTox API key in `ctx_api_key`. Reinstall concert first so
# the screenshots match the current UI.
capture_app_screenshots <- function(out_dir = "vignettes/articles/figures") {
  stopifnot(nzchar(Sys.getenv("ctx_api_key")))
  Sys.setenv(NOT_CRAN = "true")
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

  sswqs <- readxl::read_excel("data/uat/sswqs.xlsx", col_types = "text")
  input <- file.path(tempdir(), "sswqs_michigan.xlsx")
  writexl::write_xlsx(
    sswqs[sswqs$short_code == "MI", c(
      "name", "cas", "local_analyte", "orig_result", "unit",
      "local", "application", "effective_date"
    )],
    input
  )

  app <- shinytest2::AppDriver$new(
    system.file("app", package = "concert"),
    name = "walkthrough", width = 1400, height = 900,
    load_timeout = 60000, timeout = 60000
  )
  on.exit(app$stop(), add = TRUE)

  # Raw CDP capture: app$get_screenshot() resizes the viewport, which makes
  # bslib reopen the sidebar the app just collapsed.
  chrome <- app$get_chromote_session()
  shot <- function(file, scroll_to = NULL) {
    if (!is.null(scroll_to)) {
      app$run_js(sprintf("document.querySelector('%s').scrollIntoView()", scroll_to))
    }
    Sys.sleep(1)
    png <- chrome$Page$captureScreenshot(format = "png")$data
    writeBin(jsonlite::base64_dec(png), file.path(out_dir, file))
  }
  tab <- function(value) {
    app$run_js(sprintf("document.querySelector('a[data-value=\"%s\"]').click()", value))
    app$wait_for_idle(2000)
  }

  app$upload_file(`upload-file_upload` = input)
  app$wait_for_idle(5000)
  shot("01-upload.png")
  tab("detection_info")
  shot("02-detection.png")

  tab("tag_columns")
  app$click("tags-suggest_tags")
  app$wait_for_idle(3000)
  shot("03-tags.png")
  app$click("tags-apply_tags")
  app$wait_for_idle(3000)

  tab("clean_data")
  app$click("cleaning-run_pipeline")
  app$wait_for_idle(5000)
  shot("04-preflight.png")
  app$click("cleaning-run_checked")
  app$wait_for_idle(5000)
  shot("05-cleaned.png")

  tab("run_curation_tab")
  app$click("curation-run_curation")
  app$wait_for_idle(10000, timeout = 900000)
  shot("06-curation.png")

  tab("review_results")
  shot("07-review.png")
  app$set_inputs(`results-visible_cols` = c(
    "local_analyte", "cas", "consensus_status", "consensus_dtxsid",
    "consensus_name", "consensus_source", "qc_tier", "match_type", "cleaning_flag"
  ))
  app$wait_for_idle(3000)
  shot("08-review-table.png", scroll_to = "#results-curation_table")

  tab("harmonize_tab")
  shot("09-harmonize.png")

  invisible(list.files(out_dir, full.names = TRUE))
}
