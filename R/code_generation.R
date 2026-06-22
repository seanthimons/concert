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
    "row_flag_reason",
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

replay_tag_workflow_groups <- function() {
  list(
    chemical_tags = c("Name", "CASRN", "Other"),
    measurement_tags = c("Result", "Numeric", "Unit", "Qualifier", "Duration", "DurationUnit"),
    study_tags = c("StudyDate", "Media"),
    metadata_tags = c("Species", "ExposureRoute")
  )
}

replay_workflow_order <- function() {
  c("review", "measurement_tags", "study_tags", "metadata_tags", "chemical_tags")
}

tag_column_workflows <- function(tag_map = NULL) {
  if (is.null(tag_map) || length(tag_map) == 0) {
    return(character())
  }

  tag_values <- unlist(as.list(tag_map), recursive = FALSE, use.names = TRUE)
  if (length(tag_values) == 0 || is.null(names(tag_values))) {
    return(character())
  }

  tag_names <- names(tag_values)
  tag_values <- as.character(tag_values)
  names(tag_values) <- tag_names
  workflows <- character()
  groups <- replay_tag_workflow_groups()

  for (workflow in names(groups)) {
    matched <- names(tag_values)[tag_values %in% groups[[workflow]]]
    if (length(matched) > 0) {
      workflows[matched] <- workflow
    }
  }

  workflows
}

workflow_columns <- function(column_workflows, workflow) {
  names(column_workflows)[column_workflows == workflow]
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

stable_override_signature_columns <- function(df, target_col, workflow, column_workflows = character()) {
  tagged_cols <- names(column_workflows)
  chemical_cols <- workflow_columns(column_workflows, "chemical_tags")
  nonchemical_tagged_cols <- setdiff(tagged_cols, chemical_cols)

  workflow_exclusions <- switch(
    workflow,
    review = nonchemical_tagged_cols,
    chemical_tags = tagged_cols,
    measurement_tags = nonchemical_tagged_cols,
    study_tags = nonchemical_tagged_cols,
    metadata_tags = nonchemical_tagged_cols,
    tagged_cols
  )

  candidates <- setdiff(
    names(df),
    unique(c(review_signature_excluded_columns(), workflow_exclusions, target_col))
  )
  candidates[vapply(df[candidates], is_stable_signature_column, logical(1))]
}

stable_review_signature_columns <- function(df) {
  stable_override_signature_columns(df, target_col = NULL, workflow = "review")
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

minimal_stable_row_signature <- function(baseline_state, full_signature, target_rows, identity_cols = character()) {
  stable_cols <- names(full_signature)
  if (length(stable_cols) <= 1L) {
    return(full_signature)
  }

  target_mask <- rep(FALSE, nrow(baseline_state))
  target_mask[target_rows] <- TRUE

  signature_masks <- lapply(stable_cols, function(col) {
    vapply(
      seq_len(nrow(baseline_state)),
      function(row_idx) {
        scalar_value_matches(baseline_state[[col]][row_idx], full_signature[[col]])
      },
      logical(1)
    )
  })
  names(signature_masks) <- stable_cols

  # Seed the signature with chemical-identity columns so generated predicates read
  # like recognizable rows, then add only the extra columns needed to disambiguate.
  seed <- stable_cols[stable_cols %in% identity_cols]
  optional <- setdiff(stable_cols, seed)

  for (subset_size in seq.int(0L, length(optional))) {
    candidates <- if (subset_size == 0L) {
      list(character())
    } else {
      utils::combn(optional, subset_size, simplify = FALSE)
    }
    for (extra_cols in candidates) {
      candidate_cols <- c(seed, extra_cols)
      if (length(candidate_cols) == 0L) {
        next
      }
      mask <- Reduce(`&`, signature_masks[candidate_cols])
      if (identical(mask, target_mask)) {
        return(full_signature[stable_cols[stable_cols %in% candidate_cols]])
      }
    }
  }

  full_signature
}

new_review_override_spec <- function(columns, values, signatures, signature_columns, workflows = NULL) {
  if (is.null(workflows)) {
    workflows <- rep("review", length(columns))
  }

  spec <- tibble::tibble(
    workflow = workflows,
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

  if (!"workflow" %in% names(spec)) {
    spec$workflow <- rep("review", nrow(spec))
  }

  workflows <- as.character(spec$workflow)
  valid_workflows <- replay_workflow_order()
  if (
    length(workflows) != nrow(spec) ||
      any(is.na(workflows)) ||
      any(!workflows %in% valid_workflows)
  ) {
    stop("review_overrides contains an invalid workflow.", call. = FALSE)
  }
  spec$workflow <- workflows

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
#' @param tag_map Optional named list mapping source columns to tag types. When
#'   supplied, edits to tagged input columns are captured and replayed in
#'   workflow-specific blocks.
#'
#' @return NULL when no overrides are needed, otherwise a content-match
#'   override spec with the edited column, edited scalar value, and a
#'   minimal stable row signature used as the key for each generated
#'   `dplyr::rows_update()` override table.
#' @export
build_review_overrides <- function(baseline_state, final_state, tag_map = NULL) {
  if (is.null(baseline_state) || is.null(final_state)) {
    return(NULL)
  }

  if (nrow(baseline_state) != nrow(final_state)) {
    stop("baseline_state and final_state must have the same number of rows.", call. = FALSE)
  }

  column_workflows <- tag_column_workflows(tag_map)
  review_cols <- intersect(review_override_columns(), names(final_state))
  tagged_cols <- intersect(names(column_workflows), names(final_state))

  target_workflows <- c(
    stats::setNames(rep("review", length(review_cols)), review_cols),
    column_workflows[tagged_cols]
  )
  target_workflows <- target_workflows[!duplicated(names(target_workflows))]

  if (length(target_workflows) == 0) {
    return(NULL)
  }

  workflows <- character()
  columns <- character()
  values <- list()
  branch_signatures <- list()

  for (col in names(target_workflows)) {
    workflow <- unname(target_workflows[[col]])
    stable_cols <- stable_override_signature_columns(
      baseline_state,
      target_col = col,
      workflow = workflow,
      column_workflows = column_workflows
    )
    identity_cols <- if (identical(workflow, "chemical_tags")) {
      character()
    } else {
      intersect(workflow_columns(column_workflows, "chemical_tags"), stable_cols)
    }
    signatures <- lapply(seq_len(nrow(baseline_state)), function(row_idx) {
      row_signature(baseline_state, row_idx, stable_cols)
    })
    keys <- vapply(signatures, signature_key, character(1))

    # First pass: find changed groups, validate ambiguity, and collect each
    # group's minimal-readable signature.
    group_rows_list <- list()
    group_values <- list()
    group_min_cols <- character()
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

      min_sig <- minimal_stable_row_signature(
        baseline_state,
        signatures[[group_rows[1]]],
        group_rows,
        identity_cols
      )
      group_rows_list[[length(group_rows_list) + 1L]] <- group_rows
      group_values[[length(group_values) + 1L]] <- review_value_scalar(intended_value)
      group_min_cols <- union(group_min_cols, names(min_sig))
    }

    if (length(group_values) == 0) {
      next
    }

    # A single rows_update table needs one uniform key set, so key every group on
    # the union of the columns any group needed (ordered by data-frame columns).
    key_cols <- stable_cols[stable_cols %in% group_min_cols]
    for (i in seq_along(group_values)) {
      workflows <- c(workflows, workflow)
      columns <- c(columns, col)
      values[[length(values) + 1L]] <- group_values[[i]]
      branch_signatures[[length(branch_signatures) + 1L]] <- row_signature(
        baseline_state,
        group_rows_list[[i]][1],
        key_cols
      )
    }
  }

  if (length(values) == 0) {
    return(NULL)
  }

  new_review_override_spec(columns, values, branch_signatures, NULL, workflows)
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

  updated <- init_review_override_columns(
    resolution_state,
    intersect(unique(as.character(spec$column)), review_override_columns())
  )

  # Apply in workflow order (chemical-tags last) so edits to chemical-identity
  # columns do not invalidate the stable signatures of earlier workflows. This
  # mirrors the order the generated rows_update tables run in.
  apply_order <- order(match(as.character(spec$workflow), replay_workflow_order()))

  for (i in apply_order) {
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

replay_workflow_label <- function(workflow) {
  switch(
    workflow,
    review = "Review Results",
    measurement_tags = "Measurement tags",
    study_tags = "Study tags",
    metadata_tags = "Metadata tags",
    chemical_tags = "Chemical tags",
    workflow
  )
}

# Combine a list of scalar values into a single typed vector literal. Combining
# with c() preserves the column type (including typed NA) so the generated table
# matches the resolution-state column type that dplyr::rows_update() requires.
column_vector_literal <- function(values) {
  script_literal(do.call(c, values))
}

format_rows_update_block <- function(workflow, col, entries) {
  key_cols <- names(entries$signature[[1]])
  tbl_var <- make.names(paste0(col, "_fixes"))

  col_lines <- character()
  for (key_col in key_cols) {
    key_values <- lapply(seq_len(nrow(entries)), function(i) entries$signature[[i]][[key_col]])
    col_lines <- c(col_lines, paste0("    ", r_name(key_col), " = ", column_vector_literal(key_values)))
  }
  target_values <- lapply(seq_len(nrow(entries)), function(i) review_value_scalar(entries$value[[i]]))
  col_lines <- c(col_lines, paste0("    ", r_name(col), " = ", column_vector_literal(target_values)))
  col_lines[-length(col_lines)] <- paste0(col_lines[-length(col_lines)], ",")

  by_literal <- if (length(key_cols) == 1L) {
    script_literal(key_cols)
  } else {
    character_vector_literal(key_cols)
  }

  c(
    sprintf("  # %s — %s corrections (%d)", replay_workflow_label(workflow), col, nrow(entries)),
    paste0("  ", tbl_var, " <- tibble::tibble("),
    col_lines,
    "  )",
    sprintf(
      "  state <- dplyr::rows_update(state, %s, by = %s, unmatched = \"ignore\")",
      tbl_var,
      by_literal
    ),
    ""
  )
}

review_overrides_function_literal <- function(review_overrides) {
  spec <- validate_review_override_spec(review_overrides)
  present_workflows <- unique(as.character(spec$workflow))
  workflows <- replay_workflow_order()[replay_workflow_order() %in% present_workflows]

  body_lines <- character()
  for (workflow in workflows) {
    workflow_spec <- spec[spec$workflow == workflow, , drop = FALSE]
    for (col in unique(as.character(workflow_spec$column))) {
      entries <- workflow_spec[workflow_spec$column == col, , drop = FALSE]
      # Deterministic row order within each table for stable diffs across exports.
      entries <- entries[order(vapply(entries$signature, signature_key, character(1))), , drop = FALSE]
      body_lines <- c(body_lines, format_rows_update_block(workflow, col, entries))
    }
  }

  columns <- unique(as.character(spec$column))

  paste(
    c(
      "apply_review_overrides <- function(resolution_state) {",
      "  state <- resolution_state",
      "",
      body_lines,
      "  state",
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
#'   `build_review_overrides()` to embed as generated per-column
#'   `dplyr::rows_update()` override tables.
#' @param wqx_threshold WQX fuzzy match threshold.
#' @param starts_with Logical. Enables CompTox starts-with fallback search.
#' @param harmonize Logical. Re-run harmonization during replay.
#' @param media Optional dataset-wide media fallback.
#' @param format ToxVal output format for harmonized headless runs.
#' @param source_name Optional source name for ToxVal mapping.
#' @param reference_lists Optional current cleaning reference lists to snapshot
#'   for portable replay.
#' @param activate_all_references Logical. Replays the preflight setting that
#'   activates all cleaning reference-list rows for the run.
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
  source_name = NULL,
  reference_lists = NULL,
  activate_all_references = FALSE
) {
  has_review_overrides <- review_overrides_present(review_overrides)
  reference_list_snapshot <- build_reference_list_snapshot(reference_lists)

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

  if (!is.null(reference_list_snapshot)) {
    setup_lines <- c(
      setup_lines,
      "",
      paste0("reference_list_snapshot <- ", script_literal(reference_list_snapshot))
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
  if (!is.null(reference_list_snapshot)) {
    call_args$reference_list_snapshot <- "reference_list_snapshot"
  }
  if (isTRUE(activate_all_references)) {
    call_args$activate_all_references <- "TRUE"
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
