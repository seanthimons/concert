# Config Import Functions for CONCERT Export Re-import
#
# This module provides functions to detect, parse, and hydrate CONCERT exports.

#' Parse CONCERT Export
#'
#' Detects if an Excel file is a valid CONCERT export and extracts all
#' available export sheets. Older exports without Session State still parse for
#' reference-list and column-tag import.
#'
#' @param file_path Path to Excel file
#'
#' @return List with parsed sheet data frames and has_full_session_state, or
#'         NULL if not a valid CONCERT export
#' @export
parse_concert_export <- function(file_path) {
  tryCatch(
    {
      sheets <- readxl::excel_sheets(file_path)
      if (!"Pipeline Config" %in% sheets) {
        return(NULL)
      }

      config_df <- readxl::read_excel(file_path, sheet = "Pipeline Config")
      if (!"key" %in% names(config_df) || !"value" %in% names(config_df)) {
        return(NULL)
      }

      concert_marker <- config_df %>%
        dplyr::filter(key == "concert_export") %>%
        dplyr::pull(value)

      marker_value <- tolower(trimws(as.character(concert_marker[1] %||% "")))
      if (!identical(marker_value, "true")) {
        return(NULL)
      }

      reference_lists_df <- read_export_sheet(
        file_path,
        sheets,
        "Reference Lists",
        tibble::tibble(type = character(), term = character(), source = character(), active = logical())
      )

      column_tags_df <- read_export_sheet(
        file_path,
        sheets,
        "Column Tags",
        tibble::tibble(Column = character(), Type = character())
      )

      list(
        reference_lists = reference_lists_df,
        column_tags = column_tags_df,
        config = config_df,
        raw_data = read_export_sheet(file_path, sheets, "Raw Data", NULL),
        cleaned_data = read_export_sheet(file_path, sheets, "Cleaned Data", NULL),
        curated_data = read_export_sheet(file_path, sheets, "Curated Data", NULL),
        summary = read_export_sheet(file_path, sheets, "Summary", NULL),
        cleaning_audit = read_export_sheet(file_path, sheets, "Cleaning Audit", NULL),
        session_state = read_export_sheet(file_path, sheets, "Session State", NULL),
        toxval_output = read_export_sheet(file_path, sheets, "ToxVal Output", NULL),
        harmonization_audit = read_export_sheet(file_path, sheets, "Harmonization Audit", NULL),
        has_full_session_state = all(c("Raw Data", "Curated Data", "Session State") %in% sheets),
        sheet_names = sheets
      )
    },
    error = function(e) {
      warning("Failed to parse CONCERT export: ", conditionMessage(e))
      return(NULL)
    }
  )
}

#' Hydrate Session State
#'
#' Converts a parsed CONCERT export into values ready to assign into the Shiny
#' data_store. This function is pure and does not depend on Shiny.
#'
#' @param parsed Parsed export returned by parse_concert_export()
#' @param existing_reference_lists Current application reference lists, merged
#'   with imported reference-list rows.
#'
#' @return List with state and warnings
#' @export
hydrate_session_state <- function(parsed, existing_reference_lists = NULL) {
  if (is.null(parsed)) {
    stop("hydrate_session_state requires a parsed CONCERT export.", call. = FALSE)
  }

  warnings <- character(0)
  raw_data <- normalize_optional_sheet(parsed$raw_data)
  cleaned_data <- normalize_optional_sheet(parsed$cleaned_data)
  cleaning_audit <- parsed$cleaning_audit %||% tibble::tibble()
  toxval_output <- normalize_toxval_output(parsed$toxval_output)
  harmonization_audit <- normalize_optional_sheet(parsed$harmonization_audit)

  all_tags <- tags_from_column_tag_sheet(parsed$column_tags)
  classified_tags <- classify_tags(all_tags)

  reference_lists <- merge_reference_lists(
    existing_reference_lists,
    parsed$reference_lists
  )

  restored <- restore_resolution_state(
    parsed$curated_data,
    parsed$session_state
  )
  resolution_state <- restored$resolution_state
  warnings <- c(warnings, restored$warnings)

  dtxsid_cols <- if (!is.null(resolution_state)) {
    find_dtxsid_cols(resolution_state)
  } else {
    character(0)
  }

  consensus_summary <- parse_session_consensus_summary(parsed$session_state)
  if (length(consensus_summary) == 0 && !is.null(resolution_state)) {
    consensus_summary <- recalc_consensus_summary(resolution_state)
  }

  if (!is.null(raw_data) && !is.null(resolution_state) && nrow(raw_data) != nrow(resolution_state)) {
    warnings <- c(
      warnings,
      sprintf(
        "Raw Data row count (%d) does not match Curated Data row count (%d). Restored state may be stale.",
        nrow(raw_data),
        nrow(resolution_state)
      )
    )
  }

  detection <- hydrate_detection(parsed$config)
  file_info <- hydrate_file_info(parsed$config)
  dedup_preview <- hydrate_dedup_preview(raw_data, classified_tags$chemical_tags)
  harmonize_results <- hydrate_harmonize_results(harmonization_audit, resolution_state)

  state <- list(
    raw = raw_data,
    clean = raw_data,
    detection = detection,
    file_info = file_info,
    selected_columns = if (!is.null(raw_data)) names(raw_data) else NULL,
    column_tags = classified_tags$chemical_tags,
    numeric_tags = classified_tags$numeric_tags,
    metadata_tags = classified_tags$metadata_tags,
    study_type_tags = classified_tags$study_type_tags,
    prev_chemical_tags = classified_tags$chemical_tags,
    prev_numeric_tags = classified_tags$numeric_tags,
    cleaning_audit = cleaning_audit,
    cleaned_data = cleaned_data,
    reference_lists = reference_lists,
    curation_results = resolution_state,
    curation_report = NULL,
    curation_status = if (!is.null(resolution_state)) "completed" else NULL,
    dedup_preview = dedup_preview,
    consensus_data = resolution_state,
    consensus_summary = consensus_summary,
    resolution_state = resolution_state,
    script_baseline_state = resolution_state,
    dtxsid_cols = dtxsid_cols,
    priority_order = dtxsid_cols,
    review_visible_cols = NULL,
    error_filter_active = FALSE,
    unassigned_untagged_filter_active = FALSE,
    display_row_map = NULL,
    selected_error_rows = NULL,
    selected_visible_rows = NULL,
    manual_queue = list(),
    qc_results = if (!is.null(resolution_state)) perform_unicode_qc(resolution_state) else NULL,
    harmonize_results = harmonize_results,
    harmonize_audit = harmonization_audit,
    toxval_output = toxval_output,
    harmonize_results_stale = FALSE,
    changed_units = character(0)
  )

  list(state = state, warnings = warnings)
}

read_export_sheet <- function(file_path, sheets, sheet_name, default) {
  if (!sheet_name %in% sheets) {
    return(default)
  }
  readxl::read_excel(file_path, sheet = sheet_name)
}

normalize_optional_sheet <- function(df) {
  if (is.null(df)) {
    return(NULL)
  }
  df
}

normalize_toxval_output <- function(df) {
  if (is.null(df)) {
    return(NULL)
  }

  if (identical(names(df), "note") && nrow(df) > 0) {
    note <- as.character(df$note[1])
    if (!is.na(note) && grepl("Harmonization not run", note, fixed = TRUE)) {
      return(NULL)
    }
  }

  df
}

config_value <- function(config, key, default = NULL) {
  if (is.null(config) || !all(c("key", "value") %in% names(config))) {
    return(default)
  }

  values <- config %>%
    dplyr::filter(key == !!key) %>%
    dplyr::pull(value)

  if (length(values) == 0 || is.na(values[1])) {
    return(default)
  }

  as.character(values[1])
}

parse_number <- function(value, default = NA_real_) {
  parsed <- suppressWarnings(as.numeric(value))
  if (length(parsed) == 0 || is.na(parsed[1])) {
    return(default)
  }
  parsed[1]
}

parse_integer <- function(value, default = NA_integer_) {
  parsed <- suppressWarnings(as.integer(as.numeric(value)))
  if (length(parsed) == 0 || is.na(parsed[1])) {
    return(default)
  }
  parsed[1]
}

hydrate_detection <- function(config) {
  header_row <- parse_integer(config_value(config, "header_row", "1"), default = 1L)
  confidence <- parse_number(config_value(config, "detection_confidence", NA_character_))

  list(
    header_row = header_row,
    data_start_row = header_row + 1L,
    metadata_rows = if (header_row > 1L) seq_len(header_row - 1L) else integer(0),
    method = config_value(config, "detection_method", "restored"),
    confidence = confidence,
    all_results = list()
  )
}

hydrate_file_info <- function(config) {
  list(
    name = config_value(config, "file_name", "concert_export.xlsx"),
    size = parse_number(config_value(config, "file_size_bytes", "0"), default = 0)
  )
}

tags_from_column_tag_sheet <- function(column_tags_df) {
  if (
    is.null(column_tags_df) ||
      nrow(column_tags_df) == 0 ||
      !all(c("Column", "Type") %in% names(column_tags_df))
  ) {
    return(list())
  }

  tag_df <- column_tags_df %>%
    dplyr::filter(!is.na(Column), !is.na(Type), Column != "", Type != "")

  tag_values <- as.list(as.character(tag_df$Type))
  stats::setNames(tag_values, as.character(tag_df$Column))
}

restore_resolution_state <- function(curated_data, session_state) {
  warnings <- character(0)
  if (is.null(curated_data)) {
    return(list(resolution_state = NULL, warnings = warnings))
  }

  resolution_state <- tibble::as_tibble(curated_data)
  row_state <- session_state_rows(session_state)

  if (nrow(row_state) > 0) {
    row_state <- row_state[order(row_state$row_index), , drop = FALSE]
    if (nrow(row_state) != nrow(resolution_state)) {
      warnings <- c(
        warnings,
        sprintf(
          "Session State row count (%d) does not match Curated Data row count (%d). Restored overlapping rows.",
          nrow(row_state),
          nrow(resolution_state)
        )
      )
    }

    n_restore <- min(nrow(row_state), nrow(resolution_state))
    state_cols <- setdiff(
      names(row_state),
      c("record_type", "row_index", "key", "value")
    )

    for (col in state_cols) {
      if (!col %in% names(resolution_state)) {
        resolution_state[[col]] <- default_state_column(col, nrow(resolution_state))
      }

      values <- row_state[[col]][seq_len(n_restore)]
      if (col %in% c(".pinned", ".manual_entry")) {
        values <- coerce_logical(values)
      } else {
        values <- as.character(values)
        values[is.na(values) | values == "NA"] <- NA_character_
      }

      resolution_state[[col]][seq_len(n_restore)] <- values
    }
  }

  list(
    resolution_state = init_resolution_state(resolution_state),
    warnings = warnings
  )
}

session_state_rows <- function(session_state) {
  if (
    is.null(session_state) ||
      nrow(session_state) == 0 ||
      !"record_type" %in% names(session_state)
  ) {
    return(tibble::tibble())
  }

  rows <- session_state %>%
    dplyr::filter(record_type == "row_state")

  if (!"row_index" %in% names(rows)) {
    rows$row_index <- seq_len(nrow(rows))
  }

  rows$row_index <- parse_integer_vector(rows$row_index)
  rows
}

parse_integer_vector <- function(value) {
  parsed <- suppressWarnings(as.integer(as.numeric(value)))
  parsed[is.na(parsed)] <- seq_along(parsed)[is.na(parsed)]
  parsed
}

default_state_column <- function(col, n) {
  if (col %in% c(".pinned", ".manual_entry")) {
    return(rep(FALSE, n))
  }

  rep(NA_character_, n)
}

coerce_logical <- function(value) {
  if (is.logical(value)) {
    result <- value
  } else {
    normalized <- tolower(trimws(as.character(value)))
    result <- normalized %in% c("true", "t", "1", "yes")
    result[is.na(value) | normalized %in% c("", "na", "nan")] <- FALSE
  }

  result[is.na(result)] <- FALSE
  result
}

parse_session_consensus_summary <- function(session_state) {
  if (
    is.null(session_state) ||
      nrow(session_state) == 0 ||
      !all(c("record_type", "key", "value") %in% names(session_state))
  ) {
    return(list())
  }

  rows <- session_state %>%
    dplyr::filter(record_type == "consensus_summary", !is.na(key), key != "")

  if (nrow(rows) == 0) {
    return(list())
  }

  values <- lapply(rows$value, parse_summary_scalar)
  stats::setNames(values, as.character(rows$key))
}

parse_summary_scalar <- function(value) {
  value <- as.character(value)
  numeric_value <- suppressWarnings(as.numeric(value))
  if (!is.na(numeric_value)) {
    return(numeric_value)
  }
  value
}

hydrate_dedup_preview <- function(raw_data, chemical_tags) {
  if (is.null(raw_data) || length(chemical_tags) == 0 || nrow(raw_data) > 10000) {
    return(NULL)
  }

  tryCatch(
    get_dedup_preview(raw_data, chemical_tags),
    error = function(e) NULL
  )
}

hydrate_harmonize_results <- function(harmonization_audit, input_data) {
  if (is.null(harmonization_audit) || nrow(harmonization_audit) == 0) {
    return(NULL)
  }

  audit <- harmonization_audit
  n <- nrow(audit)
  col_or <- function(col, default) {
    if (col %in% names(audit)) audit[[col]] else rep(default, n)
  }

  parsed <- tibble::tibble(
    orig_row_id = col_or("orig_row_id", seq_len(n)),
    raw_value = col_or("orig_result", NA_character_),
    numeric_value = col_or("numeric_value", NA_real_),
    value_flag = col_or("parse_flag", "")
  )

  harmonized <- tibble::tibble(
    orig_row_id = col_or("orig_row_id", seq_len(n)),
    orig_unit = col_or("orig_unit", NA_character_),
    harmonized_value = col_or("harmonized_value", NA_real_),
    harmonized_unit = col_or("harmonized_unit", NA_character_),
    conversion_factor = col_or("conversion_factor", NA_real_),
    unit_flag = col_or("unit_flag", "")
  )

  list(
    parsed = parsed,
    harmonized = harmonized,
    input_data = input_data %||% tibble::tibble()
  )
}

#' Merge Reference Lists
#'
#' Merges imported reference lists with existing lists, giving priority
#' to imported entries on term conflicts (imported wins).
#'
#' @param existing_lists List with $functional_categories, $stop_words,
#'   $block_patterns, and optionally $strip_terms
#' @param imported_ref_df Combined reference list data frame with type column
#'
#' @return Updated list with merged reference lists
#' @export
merge_reference_lists <- function(existing_lists, imported_ref_df) {
  if (
    is.null(imported_ref_df) ||
      nrow(imported_ref_df) == 0 ||
      !"type" %in% names(imported_ref_df)
  ) {
    imported_ref_df <- tibble::tibble(
      type = character(),
      term = character(),
      source = character(),
      active = logical()
    )
  }

  merge_type <- function(existing_tibble, imported_subset) {
    if (is.null(existing_tibble)) {
      existing_tibble <- tibble::tibble(term = character(), source = character(), active = logical())
    }

    imported_subset <- imported_subset %>%
      dplyr::mutate(
        source = "imported",
        active = if ("active" %in% names(imported_subset)) as.logical(active) else TRUE
      ) %>%
      dplyr::select(term, source, active)

    dplyr::bind_rows(
      imported_subset,
      existing_tibble %>% dplyr::select(term, source, active)
    ) %>%
      dplyr::distinct(term, .keep_all = TRUE)
  }

  existing_lists$functional_categories <- merge_type(
    existing_lists$functional_categories,
    imported_ref_df %>% dplyr::filter(type == "functional_category") %>% dplyr::select(-type)
  )
  existing_lists$stop_words <- merge_type(
    existing_lists$stop_words,
    imported_ref_df %>% dplyr::filter(type == "stop_word") %>% dplyr::select(-type)
  )
  existing_lists$block_patterns <- merge_type(
    existing_lists$block_patterns,
    imported_ref_df %>% dplyr::filter(type == "block_pattern") %>% dplyr::select(-type)
  )
  existing_lists$strip_terms <- merge_type(
    existing_lists$strip_terms,
    imported_ref_df %>% dplyr::filter(type == "strip_term") %>% dplyr::select(-type)
  )

  existing_lists
}
