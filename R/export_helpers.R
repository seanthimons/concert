# Export Helper Functions for ChemReg Multi-Sheet Excel Export
#
# This module provides functions to build 8-sheet Excel exports from ChemReg
# pipeline state and validate Excel file size limits.

#' Build Export Sheets
#'
#' Converts ChemReg pipeline state into a named list of 8 data frames ready
#' for Excel export via writexl::write_xlsx().
#'
#' @param raw Original uploaded data frame
#' @param resolution_state Curated data with consensus_dtxsid, consensus_status
#' @param consensus_summary List with n_agree, n_disagree, etc.
#' @param cleaning_audit Data frame with audit trail (may be NULL)
#' @param reference_lists List with $functional_categories, $stop_words, $block_patterns
#' @param column_tags Named list (column_name = "CASRN"/"Name"/"Other")
#' @param detection List with $method, $confidence
#' @param file_info List with $name, $size
#' @param enrichment_cache Enrichment cache data frame (may be NULL)
#' @param toxval_output Tibble with 56 ToxVal columns from map_to_toxval_schema(),
#'   or NULL (default). When NULL, Sheet 8 contains a placeholder note row.
#'
#' @return Named list of 8 data frames with sheet names as keys
#' @export
build_export_sheets <- function(
  raw,
  resolution_state,
  consensus_summary,
  cleaning_audit,
  reference_lists,
  column_tags,
  detection,
  file_info,
  enrichment_cache = NULL,
  toxval_output = NULL
) {
  # Sheet 1: Raw Data (as-is)
  raw_data_sheet <- raw

  # Sheet 2: Curated Data with needs_review flag
  curated_data_sheet <- resolution_state %>%
    dplyr::mutate(
      needs_review = (consensus_status %in% c("error", "unresolvable"))
    ) %>%
    # Note: similarity_score, .resolution_method, .resolution_reason flow through automatically.
    # .pinned, .manual_entry, .suggested_column are internal state -- excluded from export.
    dplyr::select(-tidyselect::any_of(c(".pinned", ".manual_entry", ".suggested_column")))

  # Add enrichment columns (consensus_casrn, consensus_formula, consensus_mw)
  if (!is.null(enrichment_cache) && nrow(enrichment_cache) > 0) {
    enrich_lookup <- enrichment_cache[, c("dtxsid", "casrn", "molecular_formula", "molecular_weight")]
    names(enrich_lookup) <- c("consensus_dtxsid", "consensus_casrn", "consensus_formula", "consensus_mw")
    curated_data_sheet <- curated_data_sheet %>%
      dplyr::left_join(enrich_lookup, by = "consensus_dtxsid")
  } else {
    curated_data_sheet$consensus_casrn <- NA_character_
    curated_data_sheet$consensus_formula <- NA_character_
    curated_data_sheet$consensus_mw <- NA_real_
  }

  curated_data_sheet <- curated_data_sheet %>%
    dplyr::relocate(
      tidyselect::any_of(c(".resolution_method", ".resolution_reason")),
      .after = tidyselect::any_of("consensus_source")
    )

  curated_data_sheet <- curated_data_sheet %>%
    dplyr::relocate(needs_review, .after = tidyselect::last_col())

  # Sheet 3: Summary statistics
  summary_sheet <- tibble::tibble(
    Metric = c(
      "Total Rows",
      "Consensus - Agree",
      "Consensus - Disagree",
      "Consensus - Agree (Caveat)",
      "Consensus - Single Source",
      "Consensus - Manual",
      "Consensus - Error",
      "Consensus - Unresolvable",
      "Consensus - Auto-Resolved",
      "Consensus - Suggested",
      "Match Rate (%)"
    ),
    Value = c(
      nrow(resolution_state),
      consensus_summary$n_agree,
      consensus_summary$n_disagree,
      consensus_summary$n_agree_caveat,
      consensus_summary$n_single,
      consensus_summary$n_manual %||% 0,
      consensus_summary$n_error,
      consensus_summary$n_unresolvable %||% 0,
      sum(resolution_state$consensus_status == "auto_resolved", na.rm = TRUE),
      sum(resolution_state$consensus_status == "suggested", na.rm = TRUE),
      round((sum(!is.na(resolution_state$consensus_dtxsid)) / nrow(resolution_state)) * 100, 1)
    )
  )

  # Sheet 4: Cleaning Audit (may be NULL)
  cleaning_audit_sheet <- if (!is.null(cleaning_audit)) {
    cleaning_audit
  } else {
    tibble::tibble(
      row_id = integer(),
      field = character(),
      step = character(),
      original_value = character(),
      new_value = character(),
      reason = character()
    )
  }

  # Sheet 5: Reference Lists (combined with type column)
  reference_lists_sheet <- dplyr::bind_rows(
    reference_lists$functional_categories %>% dplyr::mutate(type = "functional_category"),
    reference_lists$stop_words %>% dplyr::mutate(type = "stop_word"),
    reference_lists$block_patterns %>% dplyr::mutate(type = "block_pattern")
  ) %>%
    dplyr::select(type, term, source, active)

  # Sheet 6: Column Tags
  column_tags_sheet <- tibble::tibble(
    Column = names(column_tags),
    Type = unlist(column_tags)
  )

  # Sheet 7: Pipeline Config
  pipeline_steps <- if (!is.null(cleaning_audit) && nrow(cleaning_audit) > 0) {
    paste(unique(cleaning_audit$step), collapse = "; ")
  } else {
    "No cleaning steps recorded"
  }

  config_sheet <- tibble::tibble(
    key = c(
      "chemreg_export",
      "app_version",
      "export_timestamp",
      "detection_method",
      "detection_confidence",
      "file_name",
      "file_size_bytes",
      "pipeline_steps"
    ),
    value = c(
      "true",
      as.character(packageVersion("base")), # Placeholder for ChemReg version
      format(Sys.time(), "%Y-%m-%d %H:%M:%S UTC", tz = "UTC"),
      detection$method %||% "unknown",
      as.character(detection$confidence %||% "N/A"),
      file_info$name %||% "unknown",
      as.character(file_info$size %||% 0),
      pipeline_steps
    )
  )

  # Sheet 8: ToxVal Output (always present per D-09)
  toxval_output_sheet <- if (!is.null(toxval_output) && nrow(toxval_output) > 0) {
    toxval_output
  } else {
    # D-10: placeholder note row when harmonization has not run
    tibble::tibble(
      note = "Harmonization not run -- run harmonization to populate this sheet"
    )
  }

  # Return named list
  list(
    "Raw Data" = raw_data_sheet,
    "Curated Data" = curated_data_sheet,
    "Summary" = summary_sheet,
    "Cleaning Audit" = cleaning_audit_sheet,
    "Reference Lists" = reference_lists_sheet,
    "Column Tags" = column_tags_sheet,
    "Pipeline Config" = config_sheet,
    "ToxVal Output" = toxval_output_sheet
  )
}

#' Validate Excel Size Limits
#'
#' Checks if a data frame exceeds Excel's row or column limits.
#' Throws an informative error if limits are exceeded.
#'
#' @param df Data frame to validate
#' @param sheet_name Name of the sheet (for error messages)
#'
#' @return invisible(TRUE) on success
#' @export
validate_excel_size <- function(df, sheet_name) {
  max_rows <- 1048576
  max_cols <- 16384

  n_rows <- nrow(df)
  n_cols <- ncol(df)

  if (n_rows >= max_rows) {
    stop(
      sprintf(
        "Sheet '%s' exceeds Excel row limit:\n  Rows: %s (limit: %s)",
        sheet_name,
        format(n_rows, big.mark = ","),
        format(max_rows, big.mark = ",")
      ),
      call. = FALSE
    )
  }

  if (n_cols >= max_cols) {
    stop(
      sprintf(
        "Sheet '%s' exceeds Excel column limit:\n  Columns: %s (limit: %s)",
        sheet_name,
        format(n_cols, big.mark = ","),
        format(max_cols, big.mark = ",")
      ),
      call. = FALSE
    )
  }

  invisible(TRUE)
}
