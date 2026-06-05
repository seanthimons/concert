# Export Helper Functions for CONCERT Multi-Sheet Excel Export
#
# This module provides functions to build multi-sheet Excel exports from CONCERT
# pipeline state and validate Excel file size limits.

#' Build Export Sheets
#'
#' Converts CONCERT pipeline state into a named list of data frames ready
#' for Excel export via writexl::write_xlsx().
#'
#' @param raw Original uploaded data frame
#' @param resolution_state Curated data with consensus_dtxsid, consensus_status
#' @param consensus_summary List with n_agree, n_disagree, etc.
#' @param cleaning_audit Data frame with audit trail (may be NULL)
#' @param reference_lists List with $functional_categories, $stop_words,
#'   $block_patterns, and $strip_terms
#' @param column_tags Named list of all applied column tags.
#' @param detection List with $method, $confidence
#' @param file_info List with $name, $size
#' @param enrichment_cache Enrichment cache data frame (may be NULL)
#' @param detected_data Data frame after header detection/extraction. When
#'   provided, this is written to Raw Data instead of the headerless ingest
#'   snapshot.
#' @param cleaned_data Data frame produced by the Clean Data workflow (may be
#'   NULL). When provided, a Cleaned Data sheet is included.
#' @param toxval_output Tibble with 56 ToxVal columns from map_to_toxval_schema(),
#'   or NULL (default). When NULL, the ToxVal Output sheet contains a
#'   placeholder note row.
#' @param harmonize_audit Tibble with numeric measurement harmonization audit rows,
#'   or NULL (default). When provided, an additional Harmonization Audit sheet is
#'   appended.
#'
#' @return Named list of data frames with sheet names as keys
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
  detected_data = NULL,
  cleaned_data = NULL,
  toxval_output = NULL,
  harmonize_audit = NULL
) {
  # Sheet 1: Raw Data (detected table with user-facing column names)
  raw_data_sheet <- detected_data %||% raw

  # Sheet 2: Curated Data with public row_flag and computed needs_review flag
  resolution_state <- init_resolution_state(resolution_state)
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
    enrich_lookup <- enrich_lookup[!duplicated(enrich_lookup$dtxsid), ]
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
      tidyselect::any_of(c(".resolution_method", ".resolution_reason", "row_flag")),
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
      consensus_summary_value(consensus_summary, "n_agree"),
      consensus_summary_value(consensus_summary, "n_disagree"),
      consensus_summary_value(consensus_summary, "n_agree_caveat"),
      consensus_summary_value(consensus_summary, "n_single"),
      consensus_summary_value(consensus_summary, "n_manual"),
      consensus_summary_value(consensus_summary, "n_error"),
      consensus_summary_value(consensus_summary, "n_unresolvable"),
      sum(resolution_state$consensus_status == "auto_resolved", na.rm = TRUE),
      sum(resolution_state$consensus_status == "suggested", na.rm = TRUE),
      if (nrow(resolution_state) > 0) {
        round((sum(!is.na(resolution_state$consensus_dtxsid)) / nrow(resolution_state)) * 100, 1)
      } else {
        0
      }
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
  strip_terms <- reference_lists$strip_terms %||%
    tibble::tibble(term = character(), source = character(), active = logical())

  reference_lists_sheet <- dplyr::bind_rows(
    reference_lists$functional_categories %>% dplyr::mutate(type = "functional_category"),
    reference_lists$stop_words %>% dplyr::mutate(type = "stop_word"),
    reference_lists$block_patterns %>% dplyr::mutate(type = "block_pattern"),
    strip_terms %>% dplyr::mutate(type = "strip_term")
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
      "concert_export",
      "app_version",
      "export_timestamp",
      "detection_method",
      "detection_confidence",
      "header_row",
      "file_name",
      "file_size_bytes",
      "pipeline_steps"
    ),
    value = c(
      "true",
      concert_export_version(),
      format(Sys.time(), "%Y-%m-%d %H:%M:%S UTC", tz = "UTC"),
      detection$method %||% "unknown",
      as.character(detection$confidence %||% "N/A"),
      as.character(detection$header_row %||% NA_integer_),
      file_info$name %||% "unknown",
      as.character(file_info$size %||% 0),
      pipeline_steps
    )
  )

  # Sheet 8: Session State (internal review state + serialized summary)
  session_state_sheet <- build_session_state_sheet(resolution_state, consensus_summary)

  # Sheet 9: ToxVal Output (always present per D-09)
  toxval_output_sheet <- if (!is.null(toxval_output) && nrow(toxval_output) > 0) {
    toxval_output
  } else {
    # D-10: placeholder note row when harmonization has not run
    tibble::tibble(
      note = "Harmonization not run -- run harmonization to populate this sheet"
    )
  }

  sheets <- list(
    "Raw Data" = raw_data_sheet
  )

  if (!is.null(cleaned_data)) {
    sheets[["Cleaned Data"]] <- cleaned_data
  }

  sheets <- c(
    sheets,
    list(
      "Curated Data" = curated_data_sheet,
      "Summary" = summary_sheet,
      "Cleaning Audit" = cleaning_audit_sheet,
      "Reference Lists" = reference_lists_sheet,
      "Column Tags" = column_tags_sheet,
      "Pipeline Config" = config_sheet,
      "Session State" = session_state_sheet,
      "ToxVal Output" = toxval_output_sheet
    )
  )

  if (!is.null(harmonize_audit)) {
    sheets[["Harmonization Audit"]] <- harmonize_audit
  }

  sheets
}

concert_export_version <- function() {
  tryCatch(
    as.character(utils::packageVersion("concert")),
    error = function(e) {
      version <- utils::packageDescription("concert", fields = "Version")
      if (is.na(version)) "unknown" else as.character(version)
    }
  )
}

consensus_summary_value <- function(consensus_summary, key, default = 0) {
  if (is.null(consensus_summary)) {
    return(default)
  }

  value <- consensus_summary[[key]]
  if (is.null(value) || length(value) == 0 || is.na(value[1])) {
    return(default)
  }

  suppressWarnings(as.numeric(value[1]))
}

build_session_state_sheet <- function(resolution_state, consensus_summary) {
  state_cols <- c(
    ".pinned",
    ".manual_entry",
    ".suggested_column",
    ".resolution_method",
    ".resolution_reason",
    "row_flag",
    "manual_preferredName",
    "wqx_override_name"
  )

  row_state <- tibble::tibble(
    record_type = rep("row_state", nrow(resolution_state)),
    row_index = seq_len(nrow(resolution_state)),
    key = rep(NA_character_, nrow(resolution_state)),
    value = rep(NA_character_, nrow(resolution_state))
  )

  for (col in state_cols) {
    if (col %in% names(resolution_state)) {
      row_state[[col]] <- resolution_state[[col]]
    } else if (col %in% c(".pinned", ".manual_entry")) {
      row_state[[col]] <- rep(FALSE, nrow(resolution_state))
    } else {
      row_state[[col]] <- rep(NA_character_, nrow(resolution_state))
    }
  }

  summary_keys <- unique(c(
    "n_agree",
    "n_disagree",
    "n_agree_caveat",
    "n_single",
    "n_manual",
    "n_error",
    "n_unresolvable",
    "n_wqx",
    "n_auto_resolved",
    "n_suggested",
    names(consensus_summary)
  ))

  summary_rows <- tibble::tibble(
    record_type = rep("consensus_summary", length(summary_keys)),
    row_index = rep(NA_integer_, length(summary_keys)),
    key = summary_keys,
    value = as.character(vapply(
      summary_keys,
      function(key) consensus_summary_value(consensus_summary, key),
      numeric(1)
    ))
  )

  for (col in state_cols) {
    if (col %in% c(".pinned", ".manual_entry")) {
      summary_rows[[col]] <- rep(NA, nrow(summary_rows))
    } else {
      summary_rows[[col]] <- rep(NA_character_, nrow(summary_rows))
    }
  }

  dplyr::bind_rows(row_state, summary_rows)
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
