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

review_signature_excluded_columns <- function() {
  unique(c(
    "row",
    ".row",
    "row_idx",
    ".row_idx",
    "row_index",
    ".row_index",
    "row_id",
    ".row_id",
    "orig_row_id",
    "original_row_id",
    "review_row",
    "display_row",
    "display_index",
    "needs_review",
    review_override_columns()
  ))
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

integer_vector_literal <- function(value) {
  value <- as.integer(value)
  if (length(value) == 0) {
    return("integer()")
  }
  paste0("c(", paste0(value, "L", collapse = ", "), ")")
}

character_vector_literal <- function(value) {
  value <- as.character(value)
  if (length(value) == 0) {
    return("character()")
  }
  parts <- vapply(value, script_literal, character(1))
  paste0("c(", paste(parts, collapse = ", "), ")")
}

r_name <- function(name) {
  reserved <- c(
    "if",
    "else",
    "for",
    "while",
    "repeat",
    "function",
    "in",
    "break",
    "next",
    "return",
    "TRUE",
    "FALSE",
    "NULL",
    "NA",
    "NaN",
    "Inf"
  )

  if (make.names(name) == name && !name %in% reserved) {
    return(name)
  }

  paste0("`", gsub("`", "``", name, fixed = TRUE), "`")
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

scalar_value_matches <- function(a, b) {
  if (scalar_values_equal(a, b)) {
    return(TRUE)
  }

  if (length(a) != 1 || length(b) != 1) {
    return(FALSE)
  }

  equal <- tryCatch(a == b, error = function(e) FALSE)
  isTRUE(equal)
}

cell_value <- function(df, row_idx, col) {
  if (!col %in% names(df)) {
    return(NA)
  }
  df[[col]][row_idx]
}

review_overrides_present <- function(review_overrides) {
  if (is.null(review_overrides)) {
    return(FALSE)
  }
  if (is.function(review_overrides)) {
    return(TRUE)
  }
  if (inherits(review_overrides, "data.frame")) {
    return(nrow(review_overrides) > 0)
  }
  length(review_overrides) > 0
}

legacy_review_overrides_to_table <- function(review_overrides) {
  rows <- integer()
  columns <- character()
  values <- list()

  for (override in review_overrides) {
    row_idx <- as.integer(override$row)
    if (length(row_idx) != 1 || is.na(row_idx)) {
      stop("review_overrides contains an invalid row index.", call. = FALSE)
    }

    override_values <- override$values
    if (is.null(override_values) || length(override_values) == 0) {
      next
    }

    if (is.null(names(override_values)) || any(!nzchar(names(override_values)))) {
      stop("review_overrides contains an invalid column name.", call. = FALSE)
    }

    for (col in names(override_values)) {
      rows <- c(rows, row_idx)
      columns <- c(columns, col)
      values[[length(values) + 1L]] <- override_values[[col]]
    }
  }

  tibble::tibble(row = rows, column = columns, value = values)
}

review_overrides_to_table <- function(review_overrides) {
  if (!review_overrides_present(review_overrides)) {
    return(tibble::tibble(row = integer(), column = character(), value = list()))
  }

  if (is.function(review_overrides)) {
    stop("function review_overrides cannot be converted to a positional table.", call. = FALSE)
  }

  if (is_review_override_spec(review_overrides)) {
    stop(
      "content-matched review_overrides cannot be converted to a positional table.",
      call. = FALSE
    )
  }

  if (inherits(review_overrides, "data.frame")) {
    required_cols <- c("row", "column", "value")
    if (!all(required_cols %in% names(review_overrides))) {
      stop("review_overrides must contain row, column, and value columns.", call. = FALSE)
    }

    return(tibble::tibble(
      row = review_overrides$row,
      column = review_overrides$column,
      value = as.list(review_overrides$value)
    ))
  }

  legacy_review_overrides_to_table(review_overrides)
}

review_values_vector <- function(values) {
  value <- unlist(values, recursive = FALSE, use.names = FALSE)
  if (length(value) != length(values)) {
    stop("review_overrides values must be scalar.", call. = FALSE)
  }
  value
}

review_value_scalar <- function(value) {
  if (length(value) != 1) {
    stop("review_overrides values must be scalar.", call. = FALSE)
  }
  value
}

is_stable_signature_column <- function(value) {
  !inherits(value, "data.frame") && !is.list(value)
}

stable_review_signature_columns <- function(df) {
  candidates <- setdiff(names(df), review_signature_excluded_columns())
  candidates[vapply(df[candidates], is_stable_signature_column, logical(1))]
}

row_signature <- function(df, row_idx, cols) {
  signature <- vector("list", length(cols))
  names(signature) <- cols
  for (col in cols) {
    signature[[col]] <- review_value_scalar(df[[col]][row_idx])
  }
  signature
}

signature_key <- function(signature) {
  script_literal(signature)
}

new_review_override_spec <- function(columns, values, signatures, signature_columns) {
  spec <- tibble::tibble(
    column = columns,
    value = values,
    signature = signatures
  )
  attr(spec, "signature_columns") <- signature_columns
  class(spec) <- c("concert_review_override_spec", class(spec))
  spec
}

is_review_override_spec <- function(value) {
  inherits(value, "concert_review_override_spec") ||
    (inherits(value, "data.frame") &&
      all(c("column", "value", "signature") %in% names(value)))
}

validate_review_override_spec <- function(spec) {
  if (!is_review_override_spec(spec)) {
    stop("review_overrides must come from build_review_overrides().", call. = FALSE)
  }
  if (!all(c("column", "value", "signature") %in% names(spec))) {
    stop("review_overrides is missing column, value, or signature fields.", call. = FALSE)
  }

  columns <- as.character(spec$column)
  if (length(columns) != nrow(spec) || any(is.na(columns)) || any(!nzchar(columns))) {
    stop("review_overrides contains an invalid column name.", call. = FALSE)
  }

  lapply(as.list(spec$value), review_value_scalar)
  lapply(as.list(spec$signature), function(signature) {
    if (!is.list(signature) || is.null(names(signature))) {
      stop("review_overrides contains an invalid row signature.", call. = FALSE)
    }
    lapply(signature, review_value_scalar)
  })

  spec
}

ambiguous_review_override_error <- function(col, rows, stable_cols) {
  detail <- if (length(stable_cols) == 0) {
    "No stable signature columns are available."
  } else {
    sprintf(
      "The stable signature uses: %s.",
      paste(stable_cols, collapse = ", ")
    )
  }

  stop(
    sprintf(
      paste(
        "Review override for column '%s' is ambiguous:",
        "rows %s share the same stable contents but have different intended values.",
        "%s"
      ),
      col,
      paste(rows, collapse = ", "),
      detail
    ),
    call. = FALSE
  )
}

#' Build content-matched review overrides
#'
#' Captures Review Results edits by comparing the automated baseline state
#' against the final user-curated state. Overrides are matched by stable row
#' contents, not by row position, when a replay script is generated.
#'
#' @param baseline_state Resolution state immediately after automated curation
#'   and postprocessing.
#' @param final_state Resolution state after Review Results edits.
#'
#' @return NULL when no overrides are needed, otherwise a content-match
#'   override spec with the edited column, edited scalar value, and a baseline
#'   row signature for each generated `case_when()` branch.
#' @export
build_review_overrides <- function(baseline_state, final_state) {
  if (is.null(baseline_state) || is.null(final_state)) {
    return(NULL)
  }

  if (nrow(baseline_state) != nrow(final_state)) {
    stop("baseline_state and final_state must have the same number of rows.", call. = FALSE)
  }

  cols <- intersect(review_override_columns(), names(final_state))
  if (length(cols) == 0) {
    return(NULL)
  }

  stable_cols <- stable_review_signature_columns(baseline_state)
  signatures <- lapply(seq_len(nrow(baseline_state)), function(row_idx) {
    row_signature(baseline_state, row_idx, stable_cols)
  })
  keys <- vapply(signatures, signature_key, character(1))

  columns <- character()
  values <- list()
  branch_signatures <- list()

  for (col in cols) {
    for (key in unique(keys)) {
      group_rows <- which(keys == key)

      before_values <- lapply(group_rows, function(row_idx) {
        cell_value(baseline_state, row_idx, col)
      })
      after_values <- lapply(group_rows, function(row_idx) {
        cell_value(final_state, row_idx, col)
      })
      changed <- any(!mapply(scalar_values_equal, before_values, after_values))
      if (!changed) {
        next
      }

      intended_value <- after_values[[1]]
      same_intended_values <- all(vapply(after_values, scalar_values_equal, logical(1), b = intended_value))
      if (!same_intended_values) {
        ambiguous_review_override_error(col, group_rows, stable_cols)
      }

      columns <- c(columns, col)
      values[[length(values) + 1L]] <- review_value_scalar(intended_value)
      branch_signatures[[length(branch_signatures) + 1L]] <- signatures[[group_rows[1]]]
    }
  }

  if (length(values) == 0) {
    return(NULL)
  }

  new_review_override_spec(columns, values, branch_signatures, stable_cols)
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

empty_column_for_values <- function(values, n) {
  value <- review_values_vector(values)
  if (length(value) == 0) {
    return(rep(NA_character_, n))
  }
  empty_column_for_value(value[1], n)
}

empty_review_override_column <- function(col, n) {
  if (col %in% c(".pinned", ".manual_entry")) {
    return(rep(FALSE, n))
  }
  if (col == "qc_tier") {
    return(rep(NA_integer_, n))
  }
  rep(NA_character_, n)
}

init_review_override_columns <- function(df, columns = character()) {
  df <- init_resolution_state(df)
  for (col in unique(columns)) {
    if (!col %in% names(df)) {
      df[[col]] <- empty_review_override_column(col, nrow(df))
    }
  }
  df
}

signature_match_mask <- function(df, signature) {
  mask <- rep(TRUE, nrow(df))

  for (col in names(signature)) {
    if (!col %in% names(df)) {
      return(rep(FALSE, nrow(df)))
    }

    value <- signature[[col]]
    col_matches <- vapply(
      seq_len(nrow(df)),
      function(row_idx) {
        scalar_value_matches(df[[col]][row_idx], value)
      },
      logical(1)
    )
    mask <- mask & col_matches
  }

  mask
}

apply_review_override_spec <- function(resolution_state, review_overrides) {
  spec <- validate_review_override_spec(review_overrides)
  if (nrow(spec) == 0) {
    return(resolution_state)
  }

  updated <- init_review_override_columns(resolution_state, unique(as.character(spec$column)))

  for (i in seq_len(nrow(spec))) {
    col <- as.character(spec$column[i])
    value <- review_value_scalar(spec$value[[i]])
    mask <- signature_match_mask(updated, spec$signature[[i]])

    if (!any(mask)) {
      stop(
        sprintf(
          "review_overrides content signature for column '%s' did not match any replayed rows.",
          col
        ),
        call. = FALSE
      )
    }

    if (!col %in% names(updated)) {
      updated[[col]] <- empty_column_for_value(value, nrow(updated))
    }
    updated[[col]][mask] <- value
  }

  updated
}

apply_review_override_function <- function(resolution_state, review_overrides) {
  target_cols <- attr(review_overrides, "review_override_columns", exact = TRUE)
  if (is.null(target_cols)) {
    target_cols <- character()
  }

  updated <- init_review_override_columns(resolution_state, target_cols)
  result <- review_overrides(updated)
  if (!inherits(result, "data.frame") || nrow(result) != nrow(updated)) {
    stop(
      "function review_overrides must return a data frame with the same number of rows.",
      call. = FALSE
    )
  }
  result
}

#' Apply review overrides to a replayed resolution state
#'
#' @param resolution_state Automated resolution state from a replayed curation
#'   run.
#' @param review_overrides A function generated by `generate_concert_script()`,
#'   a content-match spec from `build_review_overrides()`, a legacy positional
#'   override table/list, or NULL.
#'
#' @return Updated resolution state.
#' @export
apply_review_overrides <- function(resolution_state, review_overrides = NULL) {
  if (!review_overrides_present(review_overrides)) {
    return(resolution_state)
  }

  if (is.function(review_overrides)) {
    return(apply_review_override_function(resolution_state, review_overrides))
  }

  if (is_review_override_spec(review_overrides)) {
    return(apply_review_override_spec(resolution_state, review_overrides))
  }

  overrides <- review_overrides_to_table(review_overrides)
  if (nrow(overrides) == 0) {
    return(resolution_state)
  }

  updated <- init_resolution_state(resolution_state)

  row_idx <- suppressWarnings(as.integer(overrides$row))
  row_numeric <- suppressWarnings(as.numeric(overrides$row))
  if (
    length(row_idx) != nrow(overrides) ||
      any(is.na(row_idx)) ||
      any(row_numeric != row_idx, na.rm = TRUE) ||
      any(row_idx < 1L) ||
      any(row_idx > nrow(updated))
  ) {
    stop("review_overrides contains an invalid row index.", call. = FALSE)
  }

  columns <- as.character(overrides$column)
  if (length(columns) != nrow(overrides) || any(is.na(columns)) || any(!nzchar(columns))) {
    stop("review_overrides contains an invalid column name.", call. = FALSE)
  }

  values <- as.list(overrides$value)
  for (col in unique(columns)) {
    col_rows <- which(columns == col)
    col_values <- values[col_rows]
    if (!col %in% names(updated)) {
      updated[[col]] <- empty_column_for_values(col_values, nrow(updated))
    }
    updated[[col]][row_idx[col_rows]] <- review_values_vector(col_values)
  }

  updated
}

format_signature_term <- function(col, value) {
  col_expr <- r_name(col)
  if (isTRUE(tryCatch(is.na(value), error = function(e) FALSE))) {
    return(paste0("is.na(", col_expr, ")"))
  }
  paste0(col_expr, " == ", script_literal(value))
}

format_signature_predicate <- function(signature) {
  if (length(signature) == 0) {
    return("TRUE")
  }

  terms <- mapply(
    format_signature_term,
    names(signature),
    signature,
    SIMPLIFY = TRUE,
    USE.NAMES = FALSE
  )
  paste(terms, collapse = " & ")
}

format_case_when_assignment <- function(col, entries) {
  col_expr <- r_name(col)
  branch_lines <- character()

  for (i in seq_len(nrow(entries))) {
    predicate <- format_signature_predicate(entries$signature[[i]])
    value <- script_literal(review_value_scalar(entries$value[[i]]))
    branch_lines <- c(branch_lines, paste0("      ", predicate, " ~ ", value, ","))
  }

  c(
    paste0("    ", col_expr, " = dplyr::case_when("),
    branch_lines,
    paste0("      TRUE ~ ", col_expr),
    "    )"
  )
}

review_overrides_function_literal <- function(review_overrides) {
  spec <- validate_review_override_spec(review_overrides)
  columns <- unique(as.character(spec$column))

  assignments <- character()
  for (i in seq_along(columns)) {
    col <- columns[i]
    entries <- spec[spec$column == col, , drop = FALSE]
    assignment <- format_case_when_assignment(col, entries)
    if (i < length(columns)) {
      assignment[length(assignment)] <- paste0(assignment[length(assignment)], ",")
    }
    assignments <- c(assignments, assignment)
  }

  paste(
    c(
      "apply_review_overrides <- function(resolution_state) {",
      "  resolution_state |>",
      "    dplyr::mutate(",
      assignments,
      "    )",
      "}",
      paste0(
        "attr(apply_review_overrides, \"review_override_columns\") <- ",
        character_vector_literal(columns)
      )
    ),
    collapse = "\n"
  )
}

format_curate_call_args <- function(args) {
  if (length(args) == 0) {
    return(character(0))
  }

  arg_lines <- paste0("  ", names(args), " = ", unlist(args, use.names = FALSE))
  if (length(arg_lines) > 1) {
    arg_lines[-length(arg_lines)] <- paste0(arg_lines[-length(arg_lines)], ",")
  }
  arg_lines
}

#' Generate a CONCERT replay script
#'
#' @param input_path Character input file path shown at the top of the script.
#' @param output_path Character output XLSX path shown at the top of the script.
#' @param tag_map Named list of chemical, numeric, metadata, and study tags.
#' @param header_row Detected header row to pin for replay.
#' @param review_overrides Optional content-match override spec from
#'   `build_review_overrides()` to embed as generated `case_when()` replay
#'   logic.
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
  review_overrides = NULL,
  wqx_threshold = 0.85,
  starts_with = FALSE,
  harmonize = FALSE,
  media = NULL,
  format = "parquet",
  source_name = NULL
) {
  has_review_overrides <- review_overrides_present(review_overrides)

  setup_lines <- c(
    "# Generated by CONCERT",
    "library(concert)",
    "",
    paste0("input_path <- ", script_literal(as.character(input_path))),
    paste0("output_path <- ", script_literal(as.character(output_path))),
    "",
    paste0("tag_map <- ", script_literal(as.list(tag_map)))
  )

  if (has_review_overrides) {
    if (!is_review_override_spec(review_overrides)) {
      stop(
        "generate_concert_script review_overrides must come from build_review_overrides().",
        call. = FALSE
      )
    }

    setup_lines <- c(
      setup_lines,
      "",
      review_overrides_function_literal(review_overrides)
    )
  }

  call_args <- list(
    input_path = "input_path",
    output_path = "output_path",
    tag_map = "tag_map"
  )

  if (!is.null(header_row)) {
    call_args$header_row <- script_literal(header_row)
  }
  if (!scalar_values_equal(wqx_threshold, 0.85)) {
    call_args$wqx_threshold <- script_literal(wqx_threshold)
  }
  if (isTRUE(starts_with)) {
    call_args$starts_with <- "TRUE"
  }

  call_args$postprocess_candidates <- "TRUE"

  if (has_review_overrides) {
    call_args$review_overrides <- "apply_review_overrides"
  }

  if (isTRUE(harmonize)) {
    call_args$harmonize <- "TRUE"
    call_args$format <- script_literal(format)
    if (!is.null(media)) {
      call_args$media <- script_literal(media)
    }
    if (!is.null(source_name)) {
      call_args$source_name <- script_literal(source_name)
    }
  }

  lines <- c(
    setup_lines,
    "",
    "curate_headless(",
    format_curate_call_args(call_args),
    ")"
  )

  paste(lines, collapse = "\n")
}
