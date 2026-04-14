#' Run the full curation pipeline headlessly (without Shiny UI)
#'
#' Runs the complete ChemReg curation pipeline — file read, frontmatter
#' detection, cleaning, CompTox API search, consensus classification, and
#' 7-sheet XLSX export — from a single R script call with no Shiny session
#' required.
#'
#' @param input_path Character. Path to the input file (CSV, XLSX, or XLS).
#' @param output_path Character. Path for the output XLSX file. Parent
#'   directories are created automatically if they do not exist.
#' @param tag_map Named list mapping cleaned column names to tag roles. Keys
#'   must match column names *after* `janitor::clean_names()` normalization.
#'   Values are one of `"Name"`, `"CASRN"`, or `"Other"`. Example:
#'   `list(chemical_name = "Name", cas_number = "CASRN")`.
#' @param skip_flags Character vector of cleaning flag codes whose rows should
#'   skip the CompTox API search. Reserved for future use; isotope_match rows
#'   are already handled internally by `run_curation_pipeline()`.
#' @param header_row Integer or NULL. If NULL (default), frontmatter detection
#'   runs automatically. If an integer, that row number is used as the header
#'   row (manual override).
#' @param reference_lists Named list of reference data. If NULL (default), the
#'   package-bundled reference cache is loaded automatically. If provided, must
#'   contain keys: `stop_words`, `functional_categories`, `block_patterns`,
#'   `strip_terms`, `isotope_lookup`.
#' @param verbose Logical. If TRUE (default), progress messages are printed to
#'   the console. If FALSE, all messages are suppressed.
#'
#' @return Invisibly returns a list with two elements:
#'   \describe{
#'     \item{`$data`}{Tibble — the resolution_state table (curated data with
#'       consensus classifications and per-row resolution).}
#'     \item{`$audit_trail`}{Tibble — the cleaning audit trail documenting every
#'       transformation applied to each cell.}
#'   }
#'
#' @export
#' @importFrom tools file_ext
curate_headless <- function(input_path,
                             output_path,
                             tag_map,
                             skip_flags = NULL,
                             header_row = NULL,
                             reference_lists = NULL,
                             verbose = TRUE) {
  # skip_flags reserved for future use; isotope_match skip is handled internally by run_curation_pipeline()

  pipeline <- function() {

    # ------------------------------------------------------------------
    # Step 1: Validate input (fail fast)
    # ------------------------------------------------------------------
    if (!file.exists(input_path)) {
      stop(sprintf("curate_headless: file not found: %s", input_path))
    }

    file_ext <- tolower(tools::file_ext(input_path))

    if (!file_ext %in% c("csv", "xlsx", "xls")) {
      stop(sprintf(
        "curate_headless: unsupported file type '%s'. Use csv, xlsx, or xls.",
        file_ext
      ))
    }

    # ------------------------------------------------------------------
    # Step 2: Load reference lists
    # ------------------------------------------------------------------
    if (is.null(reference_lists)) {
      cache_dir <- system.file("extdata", "reference_cache", package = "chemreg")
      reference_lists <- load_all_reference_lists(cache_dir)
    } else {
      expected <- c("stop_words", "functional_categories", "block_patterns", "strip_terms", "isotope_lookup")
      missing_keys <- setdiff(expected, names(reference_lists))
      if (length(missing_keys) > 0) {
        stop(sprintf(
          "curate_headless: reference_lists is missing required keys: %s",
          paste(missing_keys, collapse = ", ")
        ))
      }
    }

    # ------------------------------------------------------------------
    # Step 3: Read file
    # ------------------------------------------------------------------
    message(sprintf("[headless] Reading file: %s", basename(input_path)))
    raw_df <- safely_read_file(input_path, file_ext)

    # ------------------------------------------------------------------
    # Step 4: Detect frontmatter
    # ------------------------------------------------------------------
    if (!is.null(header_row)) {
      detection <- detect_data_start(raw_df, mode = "manual", manual_row = header_row)
    } else {
      detection <- detect_data_start(raw_df, mode = "auto")
    }

    message(sprintf(
      "[headless] Detection: method=%s, confidence=%.2f, header_row=%d",
      detection$method,
      detection$confidence,
      detection$header_row
    ))

    # ------------------------------------------------------------------
    # Step 5: Extract and post-process
    # ------------------------------------------------------------------
    clean_data <- extract_clean_data(raw_df, detection)
    clean_data <- handle_merged_cells(clean_data)
    clean_data <- janitor::clean_names(clean_data)
    clean_data <- janitor::remove_empty(clean_data, which = c("rows", "cols"))

    # ------------------------------------------------------------------
    # Step 6: Validate tag_map against cleaned column names
    # ------------------------------------------------------------------
    missing_cols <- setdiff(names(tag_map), names(clean_data))
    if (length(missing_cols) > 0) {
      stop(sprintf(
        "curate_headless: tag_map column names not found after normalization: %s\nActual columns: %s",
        paste(missing_cols, collapse = ", "),
        paste(names(clean_data), collapse = ", ")
      ))
    }

    # ------------------------------------------------------------------
    # Step 7: Run cleaning pipeline
    # ------------------------------------------------------------------
    message("[headless] Running cleaning pipeline...")
    cleaning_result <- run_cleaning_pipeline(clean_data, tag_map, reference_lists)
    merged_tags <- c(tag_map, cleaning_result$new_tags)

    # ------------------------------------------------------------------
    # Step 8: Run curation pipeline (CompTox API search)
    # ------------------------------------------------------------------
    message("[headless] Running curation pipeline (CompTox API search)...")
    pipeline_result <- run_curation_pipeline(cleaning_result$cleaned_data, merged_tags)
    resolution_state <- pipeline_result$results

    # ------------------------------------------------------------------
    # Step 9: Build export sheets and write XLSX
    # ------------------------------------------------------------------
    file_info <- list(
      name = basename(input_path),
      size = file.info(input_path)$size
    )

    sheets <- build_export_sheets(
      raw              = raw_df,
      resolution_state = resolution_state,
      consensus_summary = pipeline_result$consensus_summary,
      cleaning_audit   = cleaning_result$audit_trail,
      reference_lists  = reference_lists,
      column_tags      = merged_tags,
      detection        = detection,
      file_info        = file_info
    )

    fs::dir_create(dirname(output_path), recurse = TRUE)
    writexl::write_xlsx(sheets, output_path)

    message(sprintf("[headless] Output written to: %s", output_path))

    # ------------------------------------------------------------------
    # Step 10: Return invisibly
    # ------------------------------------------------------------------
    invisible(list(data = resolution_state, audit_trail = cleaning_result$audit_trail))
  }

  # Dispatch based on verbose flag
  if (verbose) {
    pipeline()
  } else {
    withCallingHandlers(
      pipeline(),
      message = function(m) invokeRestart("muffleMessage")
    )
  }
}
