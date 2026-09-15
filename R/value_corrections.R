#' Apply dataset-specific value corrections before cleaning
#'
#' Rewrites cell values in named columns using a small pattern/replacement
#' table. This is the escape hatch for dataset quirks the reference lists
#' cannot express: a "Total " prefix on every analyte, a known-bad CAS, a
#' unit typo. Runs before the cleaning pipeline so every downstream step sees
#' the corrected value.
#'
#' @param df Data frame after frontmatter extraction and `janitor::clean_names()`.
#' @param value_corrections Data frame with columns `column`, `pattern`,
#'   `replacement`, and optional `match_mode` (one of `"regex"` (default),
#'   `"literal_exact"`, or `"literal_word"`). Rows are applied in order.
#' @return List with `cleaned_data` and `audit_trail` (step `value_correction`).
#' @export
apply_value_corrections <- function(df, value_corrections = NULL) {
  if (is.null(value_corrections) || nrow(value_corrections) == 0) {
    return(list(cleaned_data = df, audit_trail = empty_cleaning_audit()))
  }

  spec <- tibble::as_tibble(value_corrections)
  required <- c("column", "pattern", "replacement")
  missing_cols <- setdiff(required, names(spec))
  if (length(missing_cols) > 0) {
    stop(
      sprintf("value_corrections is missing columns: %s", paste(missing_cols, collapse = ", ")),
      call. = FALSE
    )
  }
  if (!"match_mode" %in% names(spec)) {
    spec$match_mode <- "regex"
  }
  spec$match_mode <- tolower(trimws(as.character(spec$match_mode)))
  spec$match_mode[is.na(spec$match_mode) | !nzchar(spec$match_mode)] <- "regex"
  bad_modes <- setdiff(unique(spec$match_mode), c("regex", "literal_exact", "literal_word"))
  if (length(bad_modes) > 0) {
    stop(
      sprintf(
        "value_corrections match_mode must be regex, literal_exact, or literal_word (got: %s)",
        paste(bad_modes, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  unknown_cols <- setdiff(unique(spec$column), names(df))
  if (length(unknown_cols) > 0) {
    stop(
      sprintf("value_corrections refers to columns not in the data: %s", paste(unknown_cols, collapse = ", ")),
      call. = FALSE
    )
  }

  df_result <- df
  for (i in seq_len(nrow(spec))) {
    col <- as.character(spec$column[i])
    pattern <- as.character(spec$pattern[i])
    replacement <- as.character(spec$replacement[i])
    values <- as.character(df_result[[col]])
    new_values <- switch(
      spec$match_mode[i],
      regex = gsub(pattern, replacement, values, perl = TRUE),
      literal_exact = ifelse(!is.na(values) & values == pattern, replacement, values),
      literal_word = gsub(
        paste0("(?<![[:alnum:]])", escape_regex(pattern), "(?![[:alnum:]])"),
        replacement,
        values,
        perl = TRUE
      )
    )
    df_result[[col]] <- new_values
  }

  audit <- build_audit_trail(df, df_result, "value_correction", function(field) {
    paste0("Applied value_corrections to ", field)
  })
  list(cleaned_data = df_result, audit_trail = audit)
}
