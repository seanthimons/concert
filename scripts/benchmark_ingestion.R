# Run from the repository root with source('scripts/benchmark_ingestion.R').
# benchmark_ingestion() times upload -> header detection -> CAS normalization on
# synthetic files with a metadata preamble. Budgets in
# tests/testthat/test-ingestion-performance.R are set from these numbers.
ingestion_benchmark_data <- function(n, cols = 10L) {
  cas <- c("67-64-1", "71-43-2", "0103-02-06", "108-88-3", "7732-18-5")
  df <- data.frame(name = sprintf("Chem %d", seq_len(n)), casrn = rep(cas, length.out = n))
  for (i in seq_len(cols - 2L)) df[[paste0("v", i)]] <- round(stats::runif(n), 3)
  df
}

write_ingestion_csv <- function(df, path = tempfile(fileext = ".csv")) {
  writeLines(c("Report X", "Generated 2026", ""), path)
  suppressWarnings(utils::write.table(df, path, sep = ",", row.names = FALSE, append = TRUE))
  path
}

benchmark_ingestion <- function(sizes = c(1e3, 1e4, 1e5)) {
  pkgload::load_all(".", quiet = TRUE)
  secs <- function(e) system.time(e)[["elapsed"]]
  do.call(rbind, lapply(sizes, function(n) {
    df <- ingestion_benchmark_data(n)
    csv <- write_ingestion_csv(df)
    xlsx <- tempfile(fileext = ".xlsx")
    writexl::write_xlsx(df, xlsx)
    tag_map <- list(casrn = "CASRN")
    data.frame(
      rows = n,
      read_csv = secs(raw <- suppressWarnings(read_csv_robust(csv))),
      read_xlsx = secs(read_excel_robust(xlsx)),
      detect = secs(det <- detect_data_start(raw)),
      extract = secs(clean <- extract_clean_data(raw, det)),
      precheck_cas = secs(precheck_normalize_cas(clean, tag_map)),
      normalize_cas = secs(normalize_cas_fields(clean, tag_map))
    )
  }))
}
