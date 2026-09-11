# Run from the repository root with source('scripts/benchmark_review_results.R').
# benchmark_review_results() measures the real module; run_review_benchmark_app()
# serves the same synthetic dataset for browser interaction checks.
review_benchmark_data <- function(n = 8216L, columns = 32L) {
  df <- data.frame(
    Chemical = sprintf("Chemical %05d", seq_len(n)),
    consensus_status = rep(c("agree", "error", "disagree", "wqx"), length.out = n),
    consensus_dtxsid = paste0("DTXSID", 1000000L + seq_len(n)),
    preferredName = sprintf("Chemical %05d", seq_len(n)),
    source_tier = "exact",
    dtxsid = paste0("DTXSID", 1000000L + seq_len(n))
  )
  df$consensus_dtxsid[df$consensus_status != "agree"] <- NA_character_
  for (i in seq_len(columns - ncol(df))) {
    df[[paste0("Sample", i)]] <- if (i %% 3L == 0L) NA_character_ else sprintf("value-%05d", seq_len(n))
  }
  df
}

review_benchmark_store <- function(df) {
  shiny::reactiveValues(
    resolution_state = df,
    clean = df,
    dtxsid_cols = "dtxsid",
    column_tags = c(Chemical = "Name"),
    curation_status = "completed",
    manual_queue = list()
  )
}

benchmark_review_results <- function(n = 8216L, columns = 32L) {
  pkgload::load_all(".", quiet = TRUE)
  df <- review_benchmark_data(n, columns)
  store <- review_benchmark_store(df)
  result <- NULL
  shiny::testServer(concert::mod_review_results_server, args = list(data_store = store), {
    elapsed <- system.time(payload <- output$curation_table)[["elapsed"]]
    payload <- jsonlite::fromJSON(payload, simplifyVector = FALSE)
    attrs <- payload$x$tag$attribs
    initial_rows <- length(attrs$data$Chemical)
    result <<- data.frame(
      rows = n,
      columns = columns,
      seconds = elapsed,
      initial_rows = initial_rows,
      payload_kb = nchar(jsonlite::toJSON(payload), type = "bytes") / 1000
    )
    stopifnot(initial_rows == min(n, 25L), attrs$serverRowCount == n)
  })
  result
}

run_review_benchmark_app <- function(port = 3841L) {
  pkgload::load_all(".", quiet = TRUE)
  ui <- shiny::fluidPage(
    theme = bslib::bs_theme(version = 5),
    shinyjs::useShinyjs(),
    concert::mod_review_results_ui("review")
  )
  server <- function(input, output, session) {
    store <- review_benchmark_store(review_benchmark_data())
    concert::mod_review_results_server("review", store)
  }
  shiny::runApp(shiny::shinyApp(ui, server), port = port, launch.browser = FALSE)
}
