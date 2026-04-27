#' Run the full curation pipeline headlessly (without Shiny UI)
#'
#' Runs the complete ChemReg curation pipeline — file read, frontmatter
#' detection, cleaning, CompTox API search, consensus classification, and
#' 8-sheet XLSX export — from a single R script call with no Shiny session
#' required. When harmonize=TRUE, additionally runs the numeric parsing, unit
#' harmonization, and ToxVal schema mapping pipeline, and writes parquet/CSV
#' output alongside the XLSX.
#'
#' @param input_path Character. Path to the input file (CSV, XLSX, or XLS).
#' @param output_path Character. Path for the output XLSX file. Parent
#'   directories are created automatically if they do not exist.
#' @param tag_map Named list mapping cleaned column names to tag roles. Keys
#'   must match column names *after* `janitor::clean_names()` normalization.
#'   Values are one of `"Name"`, `"CASRN"`, `"Other"`, `"Result"`, `"Unit"`,
#'   `"Qualifier"`, etc. Example:
#'   `list(chemical_name = "Name", cas_number = "CASRN", result = "Result",
#'         unit = "Unit")`.
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
#' @param harmonize Logical. If TRUE, runs numeric parsing, unit harmonization,
#'   and ToxVal schema mapping after curation. Default FALSE for backward compat.
#' @param format Character. Output format for ToxVal data when harmonize=TRUE.
#'   One of "parquet", "csv", or "both". Default "parquet". Ignored when
#'   harmonize=FALSE.
#' @param unit_map Tibble with unit conversion mappings, or NULL (default) to
#'   load from package cache via load_unit_map().
#' @param corrections Tibble with pattern/replacement columns for one-off
#'   corrections, or NULL (default) to load from package cache.
#' @param media Character. Media context for ppb/ppm routing: "aqueous", "air",
#'   or "solid". NULL (default) uses aqueous assumption.
#'
#' @return Invisibly returns a list:
#'   \describe{
#'     \item{When \code{harmonize=FALSE}:}{
#'       \itemize{
#'         \item \code{$data} -- resolution_state tibble
#'         \item \code{$audit_trail} -- cleaning audit tibble
#'       }
#'     }
#'     \item{When \code{harmonize=TRUE}:}{
#'       \itemize{
#'         \item \code{$data} -- 56-column ToxVal tibble (per D-05)
#'         \item \code{$audit_trail} -- cleaning audit tibble
#'         \item \code{$harmonize_audit} -- harmonization audit tibble (per D-06)
#'       }
#'     }
#'   }
#'
#' @export
#' @importFrom tools file_ext
#' @importFrom arrow write_parquet
curate_headless <- function(
  input_path,
  output_path,
  tag_map,
  skip_flags = NULL,
  header_row = NULL,
  reference_lists = NULL,
  verbose = TRUE,
  harmonize = FALSE,
  format = "parquet",
  unit_map = NULL,
  corrections = NULL,
  media = NULL
) {
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
    # Step 1b: Validate format parameter
    # ------------------------------------------------------------------
    if (!format %in% c("parquet", "csv", "both")) {
      stop(sprintf(
        "curate_headless: invalid format '%s'. Use 'parquet', 'csv', or 'both'.",
        format
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
    # Step 8b: Run harmonization pipeline (when harmonize = TRUE)
    # ------------------------------------------------------------------
    toxval_tibble <- NULL
    harmonize_audit_tibble <- NULL

    if (harmonize) {
      message("[headless] Running harmonization pipeline...")

      # Load unit_map from cache if not provided
      cache_dir_ref <- NULL
      if (is.null(unit_map)) {
        cache_dir_ref <- system.file("extdata", "reference_cache", package = "chemreg")
        unit_map <- load_unit_map(cache_dir_ref)
      }
      # Load corrections from cache if not provided
      if (is.null(corrections)) {
        if (is.null(cache_dir_ref)) {
          cache_dir_ref <- system.file("extdata", "reference_cache", package = "chemreg")
        }
        corrections <- load_corrections(cache_dir_ref)
      }

      # Identify tagged columns for harmonization (per D-04)
      result_cols <- names(tag_map)[tag_map == "Result"]
      unit_cols <- names(tag_map)[tag_map == "Unit"]

      has_study <- any(tag_map == "StudyDate")

      if (length(result_cols) == 0 && !has_study) {
        stop("curate_headless: harmonize=TRUE requires at least one column tagged as 'Result' or 'StudyDate' in tag_map.")
      }

      # Use resolution_state as input (same as mod_harmonize.R pattern)
      input_df <- resolution_state

      if (length(result_cols) > 0) {
        result_values <- as.character(input_df[[result_cols[1]]])

        # Stage 1: Apply one-off corrections
        message("[headless] Stage 1: Applying corrections...")
        apply_corrections_headless <- function(values, corrections_tbl) {
          if (is.null(corrections_tbl) || nrow(corrections_tbl) == 0) {
            return(values)
          }
          result <- values
          for (i in seq_len(nrow(corrections_tbl))) {
            tryCatch(
              result <- gsub(corrections_tbl$pattern[i], corrections_tbl$replacement[i], result),
              error = function(e) NULL
            )
          }
          result
        }
        corrected_values <- apply_corrections_headless(result_values, corrections)

      # Stage 2: Parse numeric results
      message("[headless] Stage 2: Parsing numeric results...")
      parse_tibble <- parse_numeric_results(corrected_values)

      # Stage 3: Harmonize units
      message("[headless] Stage 3: Harmonizing units...")
      if (length(unit_cols) > 0) {
        unit_values <- as.character(input_df[[unit_cols[1]]])
        # Ranges expand rows -- re-broadcast unit via orig_row_id (mod_harmonize.R pattern)
        if (nrow(parse_tibble) > length(unit_values)) {
          unit_values_expanded <- unit_values[parse_tibble$orig_row_id]
        } else {
          unit_values_expanded <- unit_values
        }
        harmonize_tibble <- harmonize_units(
          values = parse_tibble$numeric_value,
          units = unit_values_expanded,
          unit_map = unit_map,
          media = media
        )
      } else {
        # No Unit column -- placeholder harmonize output with NA units
        harmonize_tibble <- tibble::tibble(
          orig_row_id = parse_tibble$orig_row_id,
          orig_unit = rep(NA_character_, nrow(parse_tibble)),
          harmonized_value = parse_tibble$numeric_value,
          harmonized_unit = rep(NA_character_, nrow(parse_tibble)),
          conversion_factor = rep(1, nrow(parse_tibble)),
          unit_flag = rep("", nrow(parse_tibble))
        )
      }

        # Build harmonize audit (same as mod_harmonize.R pattern)
        harmonize_audit_tibble <- dplyr::bind_cols(
          parse_tibble,
          harmonize_tibble[, c(
            "orig_unit",
            "harmonized_value",
            "harmonized_unit",
            "conversion_factor",
            "unit_flag"
          )]
        )
      } else {
        # StudyDate-only path: identity harmonize tibble
        message("[headless] No Result column — skipping numeric stages.")
        n <- nrow(input_df)
        harmonize_tibble <- tibble::tibble(
          orig_row_id = seq_len(n),
          orig_unit = rep(NA_character_, n),
          harmonized_value = rep(NA_real_, n),
          harmonized_unit = rep(NA_character_, n),
          conversion_factor = rep(1, n),
          unit_flag = rep("", n)
        )
        harmonize_audit_tibble <- NULL
      }

      # Stage 3.5: Duration harmonization (D-13, DUR-03)
      message("[headless] Stage 3.5: Harmonizing durations...")
      duration_cols <- names(tag_map)[tag_map == "Duration"]
      duration_unit_cols <- names(tag_map)[tag_map == "DurationUnit"]

      if (length(duration_cols) > 0 && length(duration_unit_cols) > 0) {
        dur_tibble <- harmonize_units(
          values = as.numeric(input_df[[duration_cols[1]]]),
          units = as.character(input_df[[duration_unit_cols[1]]]),
          unit_map = unit_map,
          category = "duration"
        )
        # Join by position: dur_tibble$orig_row_id is 1:nrow(input_df)
        input_df$study_duration_value <- dur_tibble$harmonized_value[
          match(seq_len(nrow(input_df)), dur_tibble$orig_row_id)
        ]
        input_df$study_duration_units <- dur_tibble$harmonized_unit[
          match(seq_len(nrow(input_df)), dur_tibble$orig_row_id)
        ]
      }

      # Stage 3c: Date parsing (DATE-05, DATE-06)
      message("[headless] Stage 3c: Parsing dates...")
      date_cols <- names(tag_map)[tag_map == "StudyDate"]

      if (length(date_cols) > 0) {
        date_tibble <- parse_dates(
          raw_dates = as.character(input_df[[date_cols[1]]]),
          orig_row_id = seq_len(nrow(input_df))
        )
        # Join by position via match() -- same pattern as duration (lines 288-293)
        input_df$year <- date_tibble$date_year[
          match(seq_len(nrow(input_df)), date_tibble$orig_row_id)
        ]
      }

      # Stage 4: Map to ToxVal schema
      message("[headless] Stage 4: Mapping to ToxVal schema...")
      toxval_tibble <- map_to_toxval_schema(
        curated_data = input_df,
        harmonized_data = harmonize_tibble,
        source_name = tools::file_path_sans_ext(basename(input_path))
      )
      message(sprintf("[headless] ToxVal schema: %d rows x %d columns", nrow(toxval_tibble), ncol(toxval_tibble)))
    }

    # ------------------------------------------------------------------
    # Step 9: Build export sheets and write XLSX
    # ------------------------------------------------------------------
    file_info <- list(
      name = basename(input_path),
      size = file.info(input_path)$size
    )

    sheets <- build_export_sheets(
      raw = raw_df,
      resolution_state = resolution_state,
      consensus_summary = pipeline_result$consensus_summary,
      cleaning_audit = cleaning_result$audit_trail,
      reference_lists = reference_lists,
      column_tags = merged_tags,
      detection = detection,
      file_info = file_info,
      toxval_output = toxval_tibble
    )

    fs::dir_create(dirname(output_path), recurse = TRUE)
    writexl::write_xlsx(sheets, output_path)

    message(sprintf("[headless] Output written to: %s", output_path))

    # ------------------------------------------------------------------
    # Step 9b: Write parquet/CSV (when harmonize = TRUE, per D-07)
    # ------------------------------------------------------------------
    if (harmonize) {
      toxval_base <- sub("\\.xlsx$", "", output_path, ignore.case = TRUE)

      if (format %in% c("parquet", "both")) {
        parquet_path <- paste0(toxval_base, "_toxval.parquet")
        arrow::write_parquet(toxval_tibble, parquet_path)
        message(sprintf("[headless] Parquet written: %s", basename(parquet_path)))
      }
      if (format %in% c("csv", "both")) {
        csv_path <- paste0(toxval_base, "_toxval.csv")
        readr::write_csv(toxval_tibble, csv_path)
        message(sprintf("[headless] CSV written: %s", basename(csv_path)))
      }
    }

    # ------------------------------------------------------------------
    # Step 10: Return invisibly (per D-05, D-06)
    # ------------------------------------------------------------------
    if (harmonize) {
      invisible(list(
        data = toxval_tibble,
        audit_trail = cleaning_result$audit_trail,
        harmonize_audit = harmonize_audit_tibble
      ))
    } else {
      invisible(list(data = resolution_state, audit_trail = cleaning_result$audit_trail))
    }
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
