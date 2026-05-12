# benchmark_pipeline.R
# Standalone benchmark -- measures dedup architecture speedup
# No Shiny dependency -- runs in any R session with bench installed
#
# Prerequisites:
#   1. Place detections.csv in data/benchmark/
#   2. Install bench: pak::pak("bench")
#   3. Source this file: source("scripts/benchmark_pipeline.R")
#
# Output:
#   - data/benchmark/results.csv (raw timing data, gitignored)
#   - docs/benchmark_results.md (summary with speedup table, committed)

# ============================================================================
# 0. CONFIGURATION
# ============================================================================

library(dplyr)
library(bench)
library(readr)

CONCERT_ROOT <- here::here()

source(file.path(CONCERT_ROOT, "R", "cleaning_pipeline.R"))
source(file.path(CONCERT_ROOT, "R", "cleaning_reference.R"))
source(file.path(CONCERT_ROOT, "R", "unit_harmonizer.R"))

stopifnot(
  "bench package is required -- run: pak::pak('bench')" = requireNamespace("bench", quietly = TRUE),
  "dplyr package is required" = requireNamespace("dplyr", quietly = TRUE),
  "readr package is required" = requireNamespace("readr", quietly = TRUE),
  "readxl package is required for XLSX input -- run: pak::pak('readxl')" = requireNamespace("readxl", quietly = TRUE)
)

# ============================================================================
# 1. INPUT DATA
# ============================================================================

bench_dir <- file.path(CONCERT_ROOT, "data", "benchmark")
dir.create(bench_dir, showWarnings = FALSE, recursive = TRUE)

bench_file <- file.path(bench_dir, "detections.csv")
stopifnot(
  "data/benchmark/detections.csv not found" = file.exists(bench_file)
)

message("=== LOADING BENCHMARK DATA ===")
benchmark_df <- readr::read_csv(bench_file, show_col_types = FALSE)
message(sprintf(
  "  Loaded: %s (%d rows x %d cols)",
  basename(bench_file),
  nrow(benchmark_df),
  ncol(benchmark_df)
))

stopifnot(
  "Benchmark dataset must have >= 100000 rows for full grid" = nrow(benchmark_df) >= 100000L
)

# ============================================================================
# 2. TAG MAP AND REFERENCE LISTS
# ============================================================================

# Build tag_map -- benchmark needs realistic tags for dedup to exercise name-chain.
# Hardcoded tag map for detections.csv
tag_map <- c(
  analyte = "Name",
  cas = "CASRN",
  units = "Unit",
  concentration = "Result"
)
message(sprintf(
  "  Tag map: %d columns tagged (%s)",
  length(tag_map),
  paste(names(tag_map), "=", tag_map, collapse = ", ")
))

# Load reference lists (includes unit_map at ref_lists$unit_map)
ref_lists <- tryCatch(
  load_all_reference_lists(
    cache_dir = file.path(CONCERT_ROOT, "inst", "extdata")
  ),
  error = function(e) {
    message("  Warning: reference lists not available, using NULL -- ", conditionMessage(e))
    NULL
  }
)
message("  Reference lists loaded")

# ============================================================================
# 3. PRE-GENERATE SUBSETS
# ============================================================================

# Per D-02: set.seed(42) + dplyr::slice_sample() for reproducible subsets.
# Pre-generated OUTSIDE any bench call to avoid measuring sampling cost.
message("=== GENERATING SUBSETS ===")
set.seed(42)
df_1k <- dplyr::slice_sample(benchmark_df, n = 1000L)
df_10k <- dplyr::slice_sample(benchmark_df, n = 10000L)
df_100k <- dplyr::slice_sample(benchmark_df, n = 100000L)
message(sprintf(
  "  Subsets: 1K (%d rows), 10K (%d rows), 100K (%d rows)",
  nrow(df_1k),
  nrow(df_10k),
  nrow(df_100k)
))

# ============================================================================
# 4. COMPUTE UNIQUENESS RATES
# ============================================================================

# Per BENCH-02: report uniqueness rate of test data per subset size.
compute_uniqueness <- function(df, tag_map) {
  name_cols <- names(tag_map)[tag_map == "Name"]
  if (length(name_cols) == 0) {
    name_cols <- names(df)[vapply(df, is.character, logical(1))][1]
  }
  if (length(name_cols) == 0 || is.na(name_cols[1])) {
    return(NA_real_)
  }
  key_vec <- do.call(paste0, df[, name_cols, drop = FALSE])
  dplyr::n_distinct(key_vec) / nrow(df)
}

uniq_1k <- compute_uniqueness(df_1k, tag_map)
uniq_10k <- compute_uniqueness(df_10k, tag_map)
uniq_100k <- compute_uniqueness(df_100k, tag_map)

message(sprintf(
  "  Uniqueness: 1K=%.1f%%, 10K=%.1f%%, 100K=%.1f%%",
  uniq_1k * 100,
  uniq_10k * 100,
  uniq_100k * 100
))

# ============================================================================
# 5. COLD-START MEASUREMENT
# ============================================================================

# Per BENCH-02: cold-start measured separately with min_iterations=1, max_iterations=1.
# This captures warm-up costs (first compilation, first cache build) distinct from
# steady-state throughput measured in the press() grid.
message("=== COLD-START MEASUREMENT ===")
cold_result <- bench::mark(
  cleaning = run_cleaning_pipeline(df_1k, tag_map, ref_lists, use_dedup = TRUE),
  min_iterations = 1,
  max_iterations = 1,
  memory = TRUE,
  check = FALSE
)
message(sprintf(
  "  Cold-start: %s (mem: %s)",
  format(cold_result$median),
  format(cold_result$mem_alloc)
))

# ============================================================================
# 6. CLEANING PIPELINE BENCHMARK
# ============================================================================

# Per D-05 and BENCH-01: bench::press() across the grid.
# Per D-07: min_iterations = 3 floor.
# Per Pitfall 1: check = FALSE on all bench::mark() calls.
message("=== CLEANING PIPELINE BENCHMARK ===")
cleaning_results <- bench::press(
  n = c(1000L, 10000L, 100000L),
  use_dedup = c(TRUE, FALSE),
  {
    df_sub <- switch(
      as.character(n),
      "1000" = df_1k,
      "10000" = df_10k,
      "100000" = df_100k
    )
    bench::mark(
      run_cleaning_pipeline(df_sub, tag_map, ref_lists, use_dedup = use_dedup),
      min_iterations = 3,
      memory = TRUE,
      check = FALSE
    )
  }
)
message("  Cleaning benchmark complete")

# ============================================================================
# 7. HARMONIZATION PIPELINE BENCHMARK
# ============================================================================

# Per D-05: harmonization benchmarked separately from cleaning.
# Unit map is obtained from ref_lists (populated by load_all_reference_lists).
message("=== HARMONIZATION PIPELINE BENCHMARK ===")
unit_map <- if (!is.null(ref_lists) && !is.null(ref_lists$unit_map)) {
  ref_lists$unit_map
} else {
  tryCatch(
    {
      load_unit_map(file.path(CONCERT_ROOT, "inst", "extdata"))
    },
    error = function(e) {
      message("  Warning: unit_map not available; skipping harmonization benchmark")
      NULL
    }
  )
}

if (!is.null(unit_map)) {
  sample_units <- c("mg/L", "ug/L", "ppb", "ppm", "mg/kg", "ug/kg", "ng/L", "mg/L", "ug/L", "mg/L")

  harmonize_results <- bench::press(
    n = c(1000L, 10000L, 100000L),
    use_dedup = c(TRUE, FALSE),
    {
      set.seed(42)
      test_values <- runif(n, 0.001, 1000)
      test_units <- sample(sample_units, n, replace = TRUE)
      test_media <- sample(c("aqueous", "solid", "air"), n, replace = TRUE)
      bench::mark(
        harmonize_units(test_values, test_units, unit_map, media = test_media, use_dedup = use_dedup),
        min_iterations = 3,
        memory = TRUE,
        check = FALSE
      )
    }
  )
  message("  Harmonization benchmark complete")
} else {
  harmonize_results <- NULL
  message("  Harmonization benchmark skipped (no unit_map available)")
}

# ============================================================================
# 8. SAVE RAW RESULTS
# ============================================================================

# Per D-04: raw results to data/benchmark/results.csv (gitignored).
message("=== SAVING RESULTS ===")

cleaning_tidy <- cleaning_results %>%
  dplyr::mutate(
    pipeline = "cleaning",
    median_secs = as.numeric(median),
    mem_alloc_bytes = as.numeric(mem_alloc)
  ) %>%
  dplyr::select(pipeline, n, use_dedup, median_secs, mem_alloc_bytes, n_itr)

if (!is.null(harmonize_results)) {
  harmonize_tidy <- harmonize_results %>%
    dplyr::mutate(
      pipeline = "harmonization",
      median_secs = as.numeric(median),
      mem_alloc_bytes = as.numeric(mem_alloc)
    ) %>%
    dplyr::select(pipeline, n, use_dedup, median_secs, mem_alloc_bytes, n_itr)
  all_results <- dplyr::bind_rows(cleaning_tidy, harmonize_tidy)
} else {
  all_results <- cleaning_tidy
}

readr::write_csv(all_results, file.path(bench_dir, "results.csv"))
message(sprintf(
  "  Raw results saved to data/benchmark/results.csv (%d rows)",
  nrow(all_results)
))

# ============================================================================
# 9. GENERATE MARKDOWN SUMMARY
# ============================================================================

# Per D-04 and BENCH-03: compute speedup factors and write committed Markdown.
# Speedup = median_no_dedup / median_dedup (>1.0 means dedup is faster).
message("=== GENERATING MARKDOWN SUMMARY ===")

compute_speedup <- function(results_df) {
  results_df %>%
    tidyr::pivot_wider(
      id_cols = c(pipeline, n),
      names_from = use_dedup,
      values_from = median_secs,
      names_prefix = "dedup_"
    ) %>%
    dplyr::mutate(speedup = dedup_FALSE / dedup_TRUE) %>%
    dplyr::select(pipeline, n, speedup)
}

format_results_table <- function(results_df, speedup_df) {
  results_df %>%
    dplyr::left_join(speedup_df, by = c("pipeline", "n")) %>%
    dplyr::mutate(
      median_fmt = sprintf("%.3fs", median_secs),
      mem_fmt = sprintf("%.1fMB", mem_alloc_bytes / 1024^2),
      speedup_fmt = dplyr::if_else(use_dedup, sprintf("%.1fx", speedup), "-")
    )
}

speedup_table <- compute_speedup(all_results)
formatted <- format_results_table(all_results, speedup_table)

cleaning_speedup_100k <- speedup_table %>%
  dplyr::filter(pipeline == "cleaning", n == 100000L)
cleaning_speedup_val <- if (nrow(cleaning_speedup_100k) > 0) cleaning_speedup_100k$speedup[1] else NA_real_

harmonize_speedup_100k <- speedup_table %>%
  dplyr::filter(pipeline == "harmonization", n == 100000L)
harmonize_speedup_val <- if (nrow(harmonize_speedup_100k) > 0) harmonize_speedup_100k$speedup[1] else NA_real_

# Build cleaning table rows
build_md_table <- function(formatted_df, pipeline_name) {
  rows <- formatted_df %>%
    dplyr::filter(pipeline == pipeline_name) %>%
    dplyr::arrange(n, dplyr::desc(use_dedup))
  lines <- c()
  for (i in seq_len(nrow(rows))) {
    r <- rows[i, ]
    dedup_label <- if (r$use_dedup) "Yes" else "No"
    lines <- c(
      lines,
      sprintf(
        "| %s | %s | %s | %s | %d |",
        format(r$n, big.mark = ","),
        dedup_label,
        r$median_fmt,
        r$mem_fmt,
        r$n_itr
      )
    )
  }
  lines
}

cleaning_rows <- build_md_table(formatted, "cleaning")
harmonize_rows <- if (!is.null(harmonize_results)) build_md_table(formatted, "harmonization") else NULL

speedup_rows <- speedup_table %>%
  dplyr::mutate(
    row = sprintf(
      "| %s | %s | %s |",
      pipeline,
      format(n, big.mark = ","),
      ifelse(is.na(speedup), "N/A", sprintf("%.2fx", speedup))
    )
  ) %>%
  dplyr::pull(row)

cold_start_fmt <- format(cold_result$median)
cold_mem_fmt <- format(cold_result$mem_alloc)

run_date <- format(Sys.time(), "%Y-%m-%d %H:%M UTC", tz = "UTC")
r_version <- paste0(R.version$major, ".", R.version$minor)
bench_version <- tryCatch(
  as.character(utils::packageVersion("bench")),
  error = function(e) "unknown"
)

md_lines <- c(
  "# Benchmark Results: CONCERT Pipeline",
  "",
  sprintf("_Generated: %s_", run_date),
  sprintf("_R version: %s | bench version: %s_", r_version, bench_version),
  "",
  "## Dataset",
  "",
  sprintf("- **File:** `%s`", basename(bench_file)),
  sprintf("- **Total rows:** %s", format(nrow(benchmark_df), big.mark = ",")),
  sprintf("- **Columns:** %d", ncol(benchmark_df)),
  "",
  "## Subset Uniqueness Rates",
  "",
  "| Subset | Rows | Uniqueness |",
  "|--------|------|------------|",
  sprintf("| 1K | 1,000 | %.1f%% |", uniq_1k * 100),
  sprintf("| 10K | 10,000 | %.1f%% |", uniq_10k * 100),
  sprintf("| 100K | 100,000 | %.1f%% |", uniq_100k * 100),
  "",
  "## Cold-Start Cost",
  "",
  sprintf(
    "First run (1K rows, use_dedup = TRUE): **%s** | memory: **%s**",
    cold_start_fmt,
    cold_mem_fmt
  ),
  "",
  "_Cold-start includes initial compilation and cache initialization costs._",
  "",
  "## Cleaning Pipeline",
  "",
  "| Rows | Dedup | Median Time | Memory | Iterations |",
  "|------|-------|-------------|--------|------------|",
  cleaning_rows,
  "",
  if (!is.null(harmonize_rows)) {
    c(
      "## Harmonization Pipeline",
      "",
      "| Rows | Dedup | Median Time | Memory | Iterations |",
      "|------|-------|-------------|--------|------------|",
      harmonize_rows,
      ""
    )
  } else {
    c("## Harmonization Pipeline", "", "_Skipped (unit_map not available)_", "")
  },
  "## Speedup Summary",
  "",
  "_Speedup = median(no_dedup) / median(dedup). Values > 1.0x mean dedup is faster._",
  "",
  "| Pipeline | Rows | Speedup |",
  "|----------|------|---------|",
  speedup_rows,
  "",
  if (!is.na(cleaning_speedup_val)) {
    sprintf(
      "_Cleaning pipeline achieves **%.1fx** speedup at 100K rows with dedup enabled._",
      cleaning_speedup_val
    )
  } else {
    "_Cleaning speedup at 100K: not available._"
  },
  "",
  "## Methodology",
  "",
  "- Subsets generated with `set.seed(42)` + `dplyr::slice_sample()` for reproducibility",
  "- Cold-start measured separately (`min_iterations = 1, max_iterations = 1`)",
  "- Warm benchmark uses `bench::press()` with `min_iterations = 3` adaptive defaults",
  "- `use_dedup = TRUE/FALSE` toggle compares same data in same R session (D-03)",
  "- No CompTox API calls -- cleaning and harmonization only (D-06)",
  "- Raw timing data in `data/benchmark/results.csv` (gitignored)",
  ""
)

docs_dir <- file.path(CONCERT_ROOT, "docs")
dir.create(docs_dir, showWarnings = FALSE, recursive = TRUE)
writeLines(md_lines, file.path(docs_dir, "benchmark_results.md"))
message("  Markdown summary written to docs/benchmark_results.md")

# ============================================================================
# 10. DONE
# ============================================================================

message("=== BENCHMARK COMPLETE ===")
if (!is.na(cleaning_speedup_val)) {
  message(sprintf("  Cleaning speedup at 100K: %.1fx", cleaning_speedup_val))
}
if (!is.na(harmonize_speedup_val)) {
  message(sprintf("  Harmonization speedup at 100K: %.1fx", harmonize_speedup_val))
}
message("  Raw data: data/benchmark/results.csv")
message("  Summary:  docs/benchmark_results.md")
