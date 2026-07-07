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
    measurement_tags = c(
      "Result",
      "Numeric",
      "Unit",
      "Qualifier",
      "ReportingLimit",
      "Uncertainty",
      "UncertaintyCoverage",
      "Duration",
      "DurationUnit"
    ),
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

# Compact tibble literal for embedded site manifests: drops columns that
# normalize_site_manifest() rebuilds identically on replay (all-NA columns,
# site_suborder all 1, source_row matching row position).
site_manifest_script_literal <- function(manifest) {
  n <- nrow(manifest)
  keep <- vapply(
    names(manifest),
    function(col) {
      values <- manifest[[col]]
      if (col == "source_site_label") {
        return(TRUE)
      }
      if (col == "site_suborder") {
        return(!all(is.na(values) | values == 1L))
      }
      if (col == "source_row") {
        return(!identical(as.integer(values), seq_len(n)))
      }
      !all(is.na(values))
    },
    logical(1)
  )
  cols <- names(manifest)[keep]

  col_lines <- vapply(
    cols,
    function(col) {
      values <- manifest[[col]]
      # Constant columns (a consolidated site name repeated per raw label)
      # compress to rep(); short vectors stay as plain c() for readability.
      literal <- if (length(values) >= 4L && !anyNA(values) && length(unique(values)) == 1L) {
        paste0("rep(", script_literal(values[[1]]), ", ", length(values), "L)")
      } else {
        script_literal(values)
      }
      paste0("  ", r_name(col), " = ", literal)
    },
    character(1)
  )
  col_lines[-length(col_lines)] <- paste0(col_lines[-length(col_lines)], ",")

  paste(c("tibble::tibble(", col_lines, ")"), collapse = "\n")
}

# Compact reference-list snapshot literal. Replay reconstruction runs the
# overrides through normalize_reference_list_tbl(), which rebuilds pattern
# (from term), match_mode (type default), and notes (NA) when absent — so
# those columns are emitted only when they differ from what the normalizer
# would derive. `active` is emitted as a term-membership test on the smaller
# of the active/inactive sets.
reference_snapshot_script_literal <- function(snapshot) {
  entries <- vapply(
    names(snapshot),
    function(type) {
      entry <- snapshot[[type]]
      paste0(
        "  ",
        type,
        " = list(\n",
        "    default_hash = ",
        script_literal(entry$default_hash),
        ",\n",
        "    overrides = ",
        reference_overrides_script_literal(entry$overrides, type),
        "\n",
        "  )"
      )
    },
    character(1)
  )
  paste0("list(\n", paste(entries, collapse = ",\n"), "\n)")
}

reference_overrides_script_literal <- function(overrides, type) {
  if (nrow(overrides) == 0) {
    return("tibble::tibble(term = character(), source = character(), active = logical())")
  }

  compact_literal <- function(value) {
    if (length(value) == 1L) {
      script_literal(value)
    } else {
      character_vector_literal(value)
    }
  }

  term <- as.character(overrides$term)
  cols <- list(term = compact_literal(term))

  if (!identical(as.character(overrides$pattern), term)) {
    cols$pattern <- compact_literal(overrides$pattern)
  }
  default_modes <- reference_list_default_match_mode(type, term)
  if (!identical(as.character(overrides$match_mode), default_modes)) {
    cols$match_mode <- compact_literal(overrides$match_mode)
  }

  source <- as.character(overrides$source)
  cols$source <- if (length(unique(source)) == 1L) {
    script_literal(source[[1]])
  } else {
    compact_literal(source)
  }

  cols$active <- active_membership_literal(overrides$active, term)

  if (!all(is.na(overrides$notes))) {
    cols$notes <- compact_literal(overrides$notes)
  }

  col_lines <- paste0("      ", names(cols), " = ", unlist(cols, use.names = FALSE))
  col_lines[-length(col_lines)] <- paste0(col_lines[-length(col_lines)], ",")
  paste(c("tibble::tibble(", col_lines, "    )"), collapse = "\n")
}

active_membership_literal <- function(active, term) {
  active <- as.logical(active)
  if (anyNA(active)) {
    return(script_literal(active))
  }
  if (all(active)) {
    return("TRUE")
  }
  if (!any(active)) {
    return("FALSE")
  }
  member_literal <- function(members) {
    if (length(members) == 1L) script_literal(members) else character_vector_literal(members)
  }
  if (sum(active) <= sum(!active)) {
    paste0("term %in% ", member_literal(term[active]))
  } else {
    paste0("!(term %in% ", member_literal(term[!active]), ")")
  }
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

# Vectorized per-cell match of a column against one scalar: exact equality,
# with NA matching NA. Columns where `==` errors (lists, mismatched factor
# levels) match nowhere. Vector values are induced bulk signatures matched by
# set membership; %in% matches NA cells to NA members like the scalar branch.
column_match_mask <- function(x, value) {
  if (length(value) > 1L) {
    return(tryCatch(x %in% value, error = function(e) logical(length(x))))
  }
  if (length(value) != 1L) {
    return(logical(length(x)))
  }
  eq <- tryCatch(x == value, error = function(e) logical(length(x)))
  (!is.na(eq) & eq) | (is.na(x) & is.na(value))
}

# Vectorized "cell changed" mask matching scalar_values_equal() semantics,
# including cell_value()'s NA for columns absent from one frame.
changed_cell_mask <- function(baseline_state, final_state, col) {
  n <- nrow(baseline_state)
  a <- if (col %in% names(baseline_state)) baseline_state[[col]] else rep(NA, n)
  b <- if (col %in% names(final_state)) final_state[[col]] else rep(NA, n)
  both_na <- is.na(a) & is.na(b)
  if (!identical(class(a), class(b)) || !identical(typeof(a), typeof(b))) {
    # scalar_values_equal() treats cross-type cells as equal only when both NA
    return(!both_na)
  }
  eq <- tryCatch(a == b, error = function(e) logical(n))
  !((!is.na(eq) & eq) | both_na)
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

    if (is.null(names(override_values)) || !all(nzchar(names(override_values)))) {
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
    column_match_mask(baseline_state[[col]], full_signature[[col]])
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

# A bulk edit that writes one value is often characterized exactly by a single
# column: every changed row holds one of a few values there and no unchanged
# row does. That collapses to one set-membership signature instead of one
# entry per distinct row context.
# ponytail: single-column predicates only; multi-column induction is
# combinatorial and per-row entries remain the correct fallback.
induce_bulk_override_signature <- function(
  baseline_state,
  final_state,
  col,
  changed_mask,
  stable_cols,
  identity_cols
) {
  changed_idx <- which(changed_mask)
  if (length(changed_idx) < 2L || length(stable_cols) == 0L) {
    return(NULL)
  }

  after_values <- lapply(changed_idx, function(row_idx) cell_value(final_state, row_idx, col))
  intended_value <- after_values[[1]]
  if (!all(vapply(after_values, scalar_values_equal, logical(1), b = intended_value))) {
    return(NULL)
  }

  # Identity columns first so predicates read like recognizable chemicals,
  # then prefer the fewest distinct values among exact matches.
  candidates <- unique(c(intersect(identity_cols, stable_cols), stable_cols))
  best_values <- NULL
  best_col <- NULL
  for (candidate in candidates) {
    column_values <- baseline_state[[candidate]]
    changed_values <- unique(column_values[changed_idx])
    if (!is.null(best_values) && length(changed_values) >= length(best_values)) {
      next
    }
    if (identical(column_match_mask(column_values, changed_values), changed_mask)) {
      best_values <- changed_values
      best_col <- candidate
    }
  }
  if (is.null(best_col)) {
    return(NULL)
  }

  signature <- list()
  signature[[best_col]] <- sort(best_values, na.last = TRUE)
  list(value = review_value_scalar(intended_value), signature = signature)
}

# Chemical identity key for compound-scoped review overrides: the tagged
# chemical columns plus the cleaning pipeline's derived identity columns.
# cas_extract_* columns are tagged CASRN by the pipeline, so they arrive via
# chemical_tags; formula_extract_*/formula_blocked_* stay untagged and carry
# identity when the source name column was blanked (e.g. radionuclides).
compound_identity_columns <- function(df, column_workflows) {
  chemical_cols <- workflow_columns(column_workflows, "chemical_tags")
  if (length(chemical_cols) == 0) {
    return(character())
  }

  derived <- c(
    paste0("formula_extract_", chemical_cols),
    paste0("formula_blocked_", chemical_cols)
  )
  candidates <- intersect(names(df), c(chemical_cols, derived))
  candidates[vapply(df[candidates], is_stable_signature_column, logical(1))]
}

compound_override_conflict_error <- function(col, rows, key_cols) {
  stop(
    sprintf(
      paste(
        "Review override for column '%s' is not compound-scoped:",
        "rows %s share the same chemical identity (%s) but hold different final values.",
        "Review Results edits are expected to be uniform per compound."
      ),
      col,
      paste(rows, collapse = ", "),
      paste(key_cols, collapse = ", ")
    ),
    call. = FALSE
  )
}

# Review Results edits are compound-scoped: the review table is deduplicated to
# unique compounds and every edit expands to all rows of that compound. Capture
# them as one curation map keyed on chemical identity instead of searching for
# minimal row signatures. Every changed column gets an entry for every changed
# compound (unchanged cells re-write their final value, a no-op), so all review
# columns share one signature set and the emitter merges them into a single
# rows_update table.
build_compound_curation_entries <- function(baseline_state, final_state, review_cols, key_cols) {
  masks <- lapply(review_cols, function(col) changed_cell_mask(baseline_state, final_state, col))
  names(masks) <- review_cols
  changed_cols <- review_cols[vapply(masks, any, logical(1))]

  empty <- list(
    workflows = character(),
    columns = character(),
    values = list(),
    signatures = list()
  )
  if (length(changed_cols) == 0) {
    return(empty)
  }

  changed_any <- Reduce(`|`, masks[changed_cols])
  keys <- vctrs::vec_group_id(baseline_state[key_cols])
  group_ids <- unique(keys[changed_any])
  group_rows_list <- lapply(group_ids, function(id) which(keys == id))

  # Compound values per changed column, with the uniformity guarantee checked:
  # rows sharing a chemical identity must agree on every final value.
  group_values <- vector("list", length(group_ids))
  for (i in seq_along(group_ids)) {
    group_rows <- group_rows_list[[i]]
    values <- vector("list", length(changed_cols))
    names(values) <- changed_cols
    for (col in changed_cols) {
      after_values <- lapply(group_rows, function(row_idx) cell_value(final_state, row_idx, col))
      intended_value <- after_values[[1]]
      if (!all(vapply(after_values, scalar_values_equal, logical(1), b = intended_value))) {
        compound_override_conflict_error(col, group_rows, key_cols)
      }
      values[[col]] <- review_value_scalar(intended_value)
    }
    group_values[[i]] <- values
  }

  # Drop key columns that are NA for every changed compound when the reduced
  # key still selects exactly the same rows.
  na_key_cols <- key_cols[vapply(
    key_cols,
    function(col) {
      all(vapply(
        group_rows_list,
        function(rows) isTRUE(is.na(baseline_state[[col]][rows[1]])),
        logical(1)
      ))
    },
    logical(1)
  )]
  for (col in na_key_cols) {
    reduced <- setdiff(key_cols, col)
    if (length(reduced) == 0) {
      next
    }
    still_exact <- all(vapply(
      seq_along(group_ids),
      function(i) {
        signature <- row_signature(baseline_state, group_rows_list[[i]][1], reduced)
        identical(which(signature_match_mask(baseline_state, signature)), group_rows_list[[i]])
      },
      logical(1)
    ))
    if (still_exact) {
      key_cols <- reduced
    }
  }

  n_entries <- length(group_ids) * length(changed_cols)
  workflows <- rep("review", n_entries)
  columns <- character(n_entries)
  values <- vector("list", n_entries)
  signatures <- vector("list", n_entries)
  entry <- 0L
  for (col in changed_cols) {
    for (i in seq_along(group_ids)) {
      entry <- entry + 1L
      columns[entry] <- col
      values[[entry]] <- group_values[[i]][[col]]
      signatures[[entry]] <- row_signature(baseline_state, group_rows_list[[i]][1], key_cols)
    }
  }

  list(workflows = workflows, columns = columns, values = values, signatures = signatures)
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
      anyNA(workflows) ||
      !all(workflows %in% valid_workflows)
  ) {
    stop("review_overrides contains an invalid workflow.", call. = FALSE)
  }
  spec$workflow <- workflows

  columns <- as.character(spec$column)
  if (length(columns) != nrow(spec) || anyNA(columns) || !all(nzchar(columns))) {
    stop("review_overrides contains an invalid column name.", call. = FALSE)
  }

  lapply(as.list(spec$value), review_value_scalar)
  lapply(as.list(spec$signature), function(signature) {
    if (!is.list(signature) || is.null(names(signature))) {
      stop("review_overrides contains an invalid row signature.", call. = FALSE)
    }
    # Scalar signatures match one row's contents; longer atomic vectors are
    # induced set-membership signatures for bulk edits.
    lapply(signature, function(value) {
      if (length(value) == 0L || is.list(value)) {
        stop("review_overrides values must be scalar.", call. = FALSE)
      }
      value
    })
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
#' When the tag map identifies chemical columns, Review Results edits are
#' captured as a single compound-scoped curation map keyed on chemical
#' identity (the review table is a deduplicated unique-compound set expanded
#' back out, so per-compound values are uniform by construction). Tagged
#' measurement, study, and metadata edits remain row-scoped and keep
#' content-signature matching.
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

  # Review Results columns are compound-scoped (the review table is a
  # deduplicated unique-compound set expanded back out), so when chemical
  # identity columns are tagged they replace the per-row signature search
  # with one curation map keyed on chemical identity.
  review_targets <- names(target_workflows)[target_workflows == "review"]
  identity_key_cols <- compound_identity_columns(baseline_state, column_workflows)
  if (length(review_targets) > 0 && length(identity_key_cols) > 0) {
    compound <- build_compound_curation_entries(
      baseline_state,
      final_state,
      review_targets,
      identity_key_cols
    )
    workflows <- c(workflows, compound$workflows)
    columns <- c(columns, compound$columns)
    values <- c(values, compound$values)
    branch_signatures <- c(branch_signatures, compound$signatures)
    target_workflows <- target_workflows[!names(target_workflows) %in% review_targets]
  }

  for (col in names(target_workflows)) {
    changed_mask <- changed_cell_mask(baseline_state, final_state, col)
    if (!any(changed_mask)) {
      next
    }

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

    induced <- induce_bulk_override_signature(
      baseline_state,
      final_state,
      col,
      changed_mask,
      stable_cols,
      identity_cols
    )
    if (!is.null(induced)) {
      workflows <- c(workflows, workflow)
      columns <- c(columns, col)
      values[[length(values) + 1L]] <- induced$value
      branch_signatures[[length(branch_signatures) + 1L]] <- induced$signature
      next
    }

    # Exact-value grouping; the old dput-text keys could merge doubles that
    # differ beyond deparse precision, which replay-time matching would split.
    keys <- if (length(stable_cols) == 0L) {
      rep(1L, nrow(baseline_state))
    } else {
      vctrs::vec_group_id(baseline_state[stable_cols])
    }

    # First pass: find changed groups, validate ambiguity, and collect each
    # group's minimal-readable signature.
    group_rows_list <- list()
    group_values <- list()
    group_min_cols <- character()
    for (key in unique(keys[changed_mask])) {
      group_rows <- which(keys == key)

      after_values <- lapply(group_rows, function(row_idx) {
        cell_value(final_state, row_idx, col)
      })

      intended_value <- after_values[[1]]
      same_intended_values <- all(vapply(after_values, scalar_values_equal, logical(1), b = intended_value))
      if (!same_intended_values) {
        ambiguous_review_override_error(col, group_rows, stable_cols)
      }

      full_signature <- row_signature(baseline_state, group_rows[1], stable_cols)
      min_sig <- minimal_stable_row_signature(
        baseline_state,
        full_signature,
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

    mask <- mask & column_match_mask(df[[col]], signature[[col]])
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
      anyNA(row_idx) ||
      any(row_numeric != row_idx, na.rm = TRUE) ||
      any(row_idx < 1L) ||
      any(row_idx > nrow(updated))
  ) {
    stop("review_overrides contains an invalid row index.", call. = FALSE)
  }

  columns <- as.character(overrides$column)
  if (length(columns) != nrow(overrides) || anyNA(columns) || !all(nzchar(columns))) {
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

override_block_comment <- function(workflow, cols, n) {
  sprintf(
    "  # %s \u2014 %s corrections (%d)",
    replay_workflow_label(workflow),
    paste(cols, collapse = ", "),
    n
  )
}

override_values_constant <- function(entries) {
  values <- lapply(seq_len(nrow(entries)), function(i) review_value_scalar(entries$value[[i]]))
  all(vapply(values, scalar_values_equal, logical(1), b = values[[1]]))
}

# Bulk edits that set one value across many rows keyed on a single column
# collapse to a vectorized %in% mask instead of a one-row-per-key table.
# %in% matches NA keys, mirroring column_match_mask()/rows_update semantics.
format_in_assignment_block <- function(workflow, entries_by_col) {
  cols <- names(entries_by_col)
  first <- entries_by_col[[1]]
  key_col <- names(first$signature[[1]])
  key_values <- lapply(seq_len(nrow(first)), function(i) first$signature[[i]][[key_col]])
  combined_keys <- do.call(c, key_values)

  assignment_lines <- vapply(
    cols,
    function(col) {
      value <- review_value_scalar(entries_by_col[[col]]$value[[1]])
      paste0("  state$", r_name(col), "[matched] <- ", script_literal(value))
    },
    character(1)
  )

  c(
    override_block_comment(workflow, cols, length(combined_keys)),
    paste0("  matched <- state$", r_name(key_col), " %in% ", script_literal(combined_keys)),
    assignment_lines,
    ""
  )
}

# Row-wise tribble keeps each correction on one line with its keys and new
# values adjacent, instead of parallel column vectors.
format_tribble_block <- function(workflow, entries_by_col) {
  cols <- names(entries_by_col)
  first <- entries_by_col[[1]]
  key_cols <- names(first$signature[[1]])
  n <- nrow(first)
  tbl_var <- make.names(paste0(cols[1], "_fixes"))

  header <- paste0("~", vapply(c(key_cols, cols), r_name, character(1)))
  cells <- matrix("", nrow = n, ncol = length(header))
  for (i in seq_len(n)) {
    key_cells <- vapply(
      key_cols,
      function(key_col) script_literal(first$signature[[i]][[key_col]]),
      character(1)
    )
    value_cells <- vapply(
      cols,
      function(col) script_literal(review_value_scalar(entries_by_col[[col]]$value[[i]])),
      character(1)
    )
    cells[i, ] <- c(key_cells, value_cells)
  }

  # Attach separators before padding so columns align without space-before-comma.
  tokens <- matrix(paste0(cells, ","), nrow = n)
  tokens[n, ncol(tokens)] <- cells[n, ncol(tokens)]
  header_tokens <- paste0(header, ",")
  widths <- pmax(nchar(header_tokens), apply(matrix(nchar(tokens), nrow = n), 2, max))
  pad <- function(row) {
    vapply(seq_along(row), function(j) formatC(row[j], width = -widths[j]), character(1))
  }
  header_line <- paste0("    ", trimws(paste(pad(header_tokens), collapse = " "), which = "right"))
  body_rows <- vapply(
    seq_len(n),
    function(i) paste0("    ", trimws(paste(pad(tokens[i, ]), collapse = " "), which = "right")),
    character(1)
  )

  by_literal <- if (length(key_cols) == 1L) {
    script_literal(key_cols)
  } else {
    character_vector_literal(key_cols)
  }

  c(
    override_block_comment(workflow, cols, n),
    paste0("  ", tbl_var, " <- tibble::tribble("),
    header_line,
    body_rows,
    "  )",
    sprintf(
      "  state <- dplyr::rows_update(state, %s, by = %s, unmatched = \"ignore\")",
      tbl_var,
      by_literal
    ),
    ""
  )
}

format_override_block <- function(workflow, entries_by_col) {
  first <- entries_by_col[[1]]
  key_cols <- names(first$signature[[1]])
  all_constant <- all(vapply(entries_by_col, override_values_constant, logical(1)))
  set_based <- any(lengths(first$signature[[1]]) > 1L)
  # ponytail: mixed constant/varying columns in one group all stay tabular;
  # split emission if measurement shows those groups dominate script size.
  if (length(key_cols) == 1L && all_constant && (nrow(first) >= 2L || set_based)) {
    format_in_assignment_block(workflow, entries_by_col)
  } else {
    format_tribble_block(workflow, entries_by_col)
  }
}

review_overrides_function_literal <- function(review_overrides) {
  spec <- validate_review_override_spec(review_overrides)
  present_workflows <- unique(as.character(spec$workflow))
  workflows <- replay_workflow_order()[replay_workflow_order() %in% present_workflows]

  body_lines <- character()
  for (workflow in workflows) {
    workflow_spec <- spec[spec$workflow == workflow, , drop = FALSE]
    cols <- unique(as.character(workflow_spec$column))
    entries_by_col <- lapply(cols, function(col) {
      entries <- workflow_spec[workflow_spec$column == col, , drop = FALSE]
      # Deterministic row order within each table for stable diffs across exports.
      entries[order(vapply(entries$signature, signature_key, character(1))), , drop = FALSE]
    })
    names(entries_by_col) <- cols
    # Columns whose ordered signatures are identical share one fixes table and
    # one rows_update call. Columns with differing row sets stay separate:
    # rows_update overwrites matched cells, so merging them would write NAs
    # into rows the user never edited.
    fingerprints <- vapply(
      entries_by_col,
      function(entries) {
        paste(vapply(entries$signature, signature_key, character(1)), collapse = "\n")
      },
      character(1)
    )
    for (fingerprint in unique(fingerprints)) {
      group <- entries_by_col[fingerprints == fingerprint]
      body_lines <- c(body_lines, format_override_block(workflow, group))
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
#' @param site_manifest Optional curated Dataset Context site manifest to embed
#'   in the replay script.
#' @param site_alias_map Optional Dataset Context raw-label alias map to embed
#'   in the replay script.
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
  activate_all_references = FALSE,
  site_manifest = NULL,
  site_alias_map = NULL
) {
  has_review_overrides <- review_overrides_present(review_overrides)
  reference_list_snapshot <- build_reference_list_snapshot(reference_lists)
  site_alias_map_for_replay <- build_site_alias_map(site_context_alias_source(site_alias_map, site_manifest))
  site_manifest_input <- if (nrow(site_alias_map_for_replay) > 0L) site_alias_map_for_replay else site_manifest
  site_manifest_for_replay <- build_site_manifest(site_manifest_input)
  has_site_alias_map <- nrow(site_alias_map_for_replay) > 0L
  has_site_manifest <- nrow(site_manifest_for_replay) > 0L

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
      paste0("reference_list_snapshot <- ", reference_snapshot_script_literal(reference_list_snapshot))
    )
  }

  if (has_site_alias_map) {
    setup_lines <- c(
      setup_lines,
      "",
      paste0("site_alias_map <- ", site_manifest_script_literal(site_alias_map_for_replay)),
      "site_manifest <- build_site_manifest(site_alias_map)"
    )
  } else if (has_site_manifest) {
    setup_lines <- c(
      setup_lines,
      "",
      paste0("site_manifest <- ", site_manifest_script_literal(site_manifest_for_replay))
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
  if (has_site_manifest) {
    call_args$site_manifest <- "site_manifest"
  }
  if (has_site_alias_map) {
    call_args$site_alias_map <- "site_alias_map"
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
