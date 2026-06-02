# Script replay code generation and review override helpers.

review_override_columns <- function() {
  c(
    "consensus_status",
    "consensus_dtxsid",
    "consensus_source",
    "qc_tier",
    ".pinned",
    ".manual_entry",
    ".resolution_method",
    ".resolution_reason",
    ".suggested_column",
    "manual_preferredName",
    "row_flag",
    "wqx_override_name"
  )
}

combine_tag_maps <- function(...) {
  parts <- list(...)
  parts <- parts[!vapply(parts, is.null, logical(1))]
  parts <- lapply(parts, function(x) {
    if (length(x) == 0) {
      return(list())
    }
    as.list(x)
  })
  combined <- unlist(parts, recursive = FALSE, use.names = TRUE)
  combined[!duplicated(names(combined), fromLast = TRUE)]
}

script_literal <- function(value) {
  paste(utils::capture.output(dput(value)), collapse = "\n")
}

scalar_values_equal <- function(a, b) {
  if (identical(a, b)) {
    return(TRUE)
  }

  if (length(a) != 1 || length(b) != 1) {
    return(FALSE)
  }

  a_na <- tryCatch(is.na(a), error = function(e) FALSE)
  b_na <- tryCatch(is.na(b), error = function(e) FALSE)

  isTRUE(a_na) && isTRUE(b_na)
}

cell_value <- function(df, row_idx, col) {
  if (!col %in% names(df)) {
    return(NA)
  }
  df[[col]][row_idx]
}

#' Build compact review overrides
#'
#' Captures row-level Review Results edits by comparing the automated baseline
#' state against the final user-curated state.
#'
#' @param baseline_state Resolution state immediately after automated curation
#'   and postprocessing.
#' @param final_state Resolution state after Review Results edits.
#'
#' @return NULL when no overrides are needed, otherwise a list of row/value
#'   override entries suitable for `apply_review_overrides()`.
#' @export
build_review_overrides <- function(baseline_state, final_state) {
  if (is.null(baseline_state) || is.null(final_state)) {
    return(NULL)
  }

  if (nrow(baseline_state) != nrow(final_state)) {
    stop("baseline_state and final_state must have the same number of rows.", call. = FALSE)
  }

  cols <- intersect(review_override_columns(), names(final_state))
  overrides <- list()

  for (row_idx in seq_len(nrow(final_state))) {
    values <- list()

    for (col in cols) {
      before <- cell_value(baseline_state, row_idx, col)
      after <- cell_value(final_state, row_idx, col)

      if (!scalar_values_equal(before, after)) {
        values[[col]] <- after
      }
    }

    if (length(values) > 0) {
      overrides[[length(overrides) + 1L]] <- list(
        row = row_idx,
        values = values
      )
    }
  }

  if (length(overrides) == 0) {
    return(NULL)
  }

  overrides
}

empty_column_for_value <- function(value, n) {
  if (is.logical(value)) {
    return(rep(NA, n))
  }
  if (is.integer(value)) {
    return(rep(NA_integer_, n))
  }
  if (is.numeric(value)) {
    return(rep(NA_real_, n))
  }
  rep(NA_character_, n)
}

#' Apply review overrides to a replayed resolution state
#'
#' @param resolution_state Automated resolution state from a replayed curation
#'   run.
#' @param review_overrides Overrides from `build_review_overrides()`, or NULL.
#'
#' @return Updated resolution state.
#' @export
apply_review_overrides <- function(resolution_state, review_overrides = NULL) {
  if (is.null(review_overrides) || length(review_overrides) == 0) {
    return(resolution_state)
  }

  updated <- init_resolution_state(resolution_state)

  for (override in review_overrides) {
    row_idx <- as.integer(override$row)
    if (length(row_idx) != 1 || is.na(row_idx) || row_idx < 1L || row_idx > nrow(updated)) {
      stop("review_overrides contains an invalid row index.", call. = FALSE)
    }

    values <- override$values
    if (is.null(values) || length(values) == 0) {
      next
    }

    for (col in names(values)) {
      value <- values[[col]]
      if (!col %in% names(updated)) {
        updated[[col]] <- empty_column_for_value(value, nrow(updated))
      }
      updated[[col]][row_idx] <- value
    }
  }

  updated
}

prepare_replay_reference_lists <- function(reference_lists) {
  if (is.null(reference_lists)) {
    return(NULL)
  }

  keys <- c(
    "stop_words",
    "functional_categories",
    "block_patterns",
    "strip_terms",
    "isotope_lookup"
  )
  reference_lists[intersect(keys, names(reference_lists))]
}

#' Generate a CONCERT replay script
#'
#' @param input_path Character input file path shown at the top of the script.
#' @param output_path Character output XLSX path shown at the top of the script.
#' @param tag_map Named list of chemical, numeric, metadata, and study tags.
#' @param header_row Detected header row to pin for replay.
#' @param reference_lists Optional reference lists to embed.
#' @param unit_map Optional unit map to embed.
#' @param corrections Optional correction table to embed.
#' @param media_map Optional media map to embed.
#' @param review_overrides Optional review overrides to embed.
#' @param wqx_threshold WQX fuzzy match threshold.
#' @param starts_with Logical. Enables CompTox starts-with fallback search.
#' @param harmonize Logical. Re-run harmonization during replay.
#' @param media Optional dataset-wide media fallback.
#' @param format ToxVal output format for harmonized headless runs.
#' @param source_name Optional source name for ToxVal mapping.
#'
#' @return Complete R script as a character scalar.
#' @export
generate_concert_script <- function(
  input_path,
  output_path,
  tag_map,
  header_row,
  reference_lists = NULL,
  unit_map = NULL,
  corrections = NULL,
  media_map = NULL,
  review_overrides = NULL,
  wqx_threshold = 0.85,
  starts_with = FALSE,
  harmonize = FALSE,
  media = NULL,
  format = "parquet",
  source_name = NULL
) {
  reference_lists <- prepare_replay_reference_lists(reference_lists)
  review_overrides_code <- if (is.null(review_overrides) || length(review_overrides) == 0) {
    "NULL"
  } else {
    script_literal(review_overrides)
  }

  lines <- c(
    "# Generated by CONCERT",
    "library(concert)",
    "",
    paste0("input_path <- ", script_literal(as.character(input_path))),
    paste0("output_path <- ", script_literal(as.character(output_path))),
    "",
    paste0("tag_map <- ", script_literal(as.list(tag_map))),
    paste0("reference_lists <- ", script_literal(reference_lists)),
    paste0("unit_map <- ", script_literal(unit_map)),
    paste0("corrections <- ", script_literal(corrections)),
    paste0("media_map <- ", script_literal(media_map)),
    paste0("review_overrides <- ", review_overrides_code),
    "",
    "curate_headless(",
    "  input_path = input_path,",
    "  output_path = output_path,",
    "  tag_map = tag_map,",
    paste0("  header_row = ", script_literal(header_row), ","),
    "  reference_lists = reference_lists,",
    paste0("  wqx_threshold = ", script_literal(wqx_threshold), ","),
    paste0("  starts_with = ", script_literal(isTRUE(starts_with)), ","),
    "  postprocess_candidates = TRUE,",
    "  review_overrides = review_overrides,",
    paste0("  harmonize = ", script_literal(isTRUE(harmonize)), ","),
    paste0("  format = ", script_literal(format), ","),
    "  unit_map = unit_map,",
    "  corrections = corrections,",
    "  media_map = media_map,",
    paste0("  media = ", script_literal(media), ","),
    paste0("  source_name = ", script_literal(source_name), ","),
    "  write_files = TRUE,",
    "  verbose = TRUE",
    ")"
  )

  paste(lines, collapse = "\n")
}
