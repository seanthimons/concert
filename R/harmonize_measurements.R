# Shared numeric measurement harmonization helpers.
#
# These helpers keep primary Result harmonization and auxiliary Numeric
# measurement harmonization on the same parse/unit-conversion path.

apply_measurement_corrections <- function(values, corrections_tbl) {
  if (is.null(corrections_tbl) || nrow(corrections_tbl) == 0) {
    return(values)
  }

  result <- values
  for (i in seq_len(nrow(corrections_tbl))) {
    tryCatch(
      result <- gsub(corrections_tbl$pattern[i], corrections_tbl$replacement[i], result),
      error = function(e) {
        warning(sprintf(
          "Correction pattern '%s' failed: %s",
          corrections_tbl$pattern[i],
          e$message
        ))
      }
    )
  }

  result
}

expand_measurement_context <- function(values, orig_row_id, input_n, output_n) {
  if (is.null(values) || length(values) == 0) {
    return(NULL)
  }
  if (length(values) == 1L || length(values) == output_n) {
    return(values)
  }
  if (length(values) == input_n) {
    return(values[orig_row_id])
  }

  values
}

build_identity_harmonize_tibble <- function(n_rows) {
  tibble::tibble(
    orig_row_id = seq_len(n_rows),
    orig_unit = rep(NA_character_, n_rows),
    harmonized_value = rep(NA_real_, n_rows),
    harmonized_unit = rep(NA_character_, n_rows),
    conversion_factor = rep(1, n_rows),
    unit_flag = rep("", n_rows)
  )
}

build_measurement_audit_from_results <- function(parsed, harmonized) {
  dplyr::bind_cols(
    parsed,
    harmonized[, c(
      "orig_unit",
      "harmonized_value",
      "harmonized_unit",
      "conversion_factor",
      "unit_flag"
    )]
  )
}

empty_numeric_parse_issues <- function() {
  tibble::tibble(
    measurement_column = character(),
    measurement_role = character(),
    original_value = character(),
    row_count = integer()
  )
}

empty_numeric_correction_queue <- function() {
  tibble::tibble(
    measurement_column = character(),
    original_value = character(),
    pattern = character(),
    replacement = character()
  )
}

normalize_numeric_correction_queue <- function(queue) {
  if (is.null(queue) || length(queue) == 0L) {
    return(empty_numeric_correction_queue())
  }

  queue <- tibble::as_tibble(queue)
  required <- names(empty_numeric_correction_queue())
  for (col in setdiff(required, names(queue))) {
    queue[[col]] <- character(nrow(queue))
  }

  queue <- queue[, required, drop = FALSE]
  for (col in required) {
    queue[[col]] <- as.character(queue[[col]])
  }
  queue
}

extract_unparseable_numeric_issues <- function(harmonize_audit = NULL, harmonize_results = NULL) {
  source_tbl <- harmonize_audit
  if ((is.null(source_tbl) || nrow(source_tbl) == 0L) &&
    !is.null(harmonize_results) && !is.null(harmonize_results$parsed)) {
    source_tbl <- harmonize_results$parsed
  }

  if (is.null(source_tbl) || nrow(source_tbl) == 0L || !"parse_flag" %in% names(source_tbl)) {
    return(empty_numeric_parse_issues())
  }

  source_tbl <- tibble::as_tibble(source_tbl)
  unparseable <- source_tbl[!is.na(source_tbl$parse_flag) & source_tbl$parse_flag == "unparseable", , drop = FALSE]
  if (nrow(unparseable) == 0L) {
    return(empty_numeric_parse_issues())
  }

  value_col <- if ("original_value" %in% names(unparseable)) {
    "original_value"
  } else if ("orig_result" %in% names(unparseable)) {
    "orig_result"
  } else {
    NULL
  }
  if (is.null(value_col)) {
    return(empty_numeric_parse_issues())
  }

  issue_rows <- tibble::tibble(
    measurement_column = if ("measurement_column" %in% names(unparseable)) {
      as.character(unparseable$measurement_column)
    } else {
      rep(NA_character_, nrow(unparseable))
    },
    measurement_role = if ("measurement_role" %in% names(unparseable)) {
      as.character(unparseable$measurement_role)
    } else {
      rep(NA_character_, nrow(unparseable))
    },
    original_value = as.character(unparseable[[value_col]]),
    .row_id = if ("orig_row_id" %in% names(unparseable)) {
      as.character(unparseable$orig_row_id)
    } else {
      as.character(seq_len(nrow(unparseable)))
    }
  )

  group_key <- paste(
    ifelse(is.na(issue_rows$measurement_column), "<NA>", issue_rows$measurement_column),
    ifelse(is.na(issue_rows$measurement_role), "<NA>", issue_rows$measurement_role),
    ifelse(is.na(issue_rows$original_value), "<NA>", issue_rows$original_value),
    sep = "\r"
  )

  grouped <- split(seq_len(nrow(issue_rows)), group_key)
  issues <- lapply(grouped, function(idx) {
    first <- issue_rows[idx[1], ]
    tibble::tibble(
      measurement_column = first$measurement_column,
      measurement_role = first$measurement_role,
      original_value = first$original_value,
      row_count = length(unique(issue_rows$.row_id[idx]))
    )
  })

  out <- dplyr::bind_rows(issues)
  out[order(-out$row_count, out$measurement_column, out$measurement_role, out$original_value), , drop = FALSE]
}

escape_exact_regex_value <- function(value) {
  value <- as.character(value)
  gsub("([][{}()+*^$|\\\\?.])", "\\\\\\1", value, perl = TRUE)
}

build_exact_numeric_correction_pattern <- function(value) {
  paste0("^", escape_exact_regex_value(value), "$")
}

upsert_numeric_correction_queue <- function(queue, entries) {
  queue <- normalize_numeric_correction_queue(queue)
  entries <- normalize_numeric_correction_queue(entries)
  if (nrow(entries) == 0L) {
    return(queue)
  }

  combined <- dplyr::bind_rows(queue, entries)
  key <- paste(combined$measurement_column, combined$original_value, sep = "\r")
  combined[!duplicated(key, fromLast = TRUE), , drop = FALSE]
}

validate_numeric_correction_queue <- function(queue) {
  queue <- normalize_numeric_correction_queue(queue)
  if (nrow(queue) == 0L) {
    return(list(valid = queue, invalid = tibble::add_column(queue, reason = character())))
  }

  validation <- lapply(seq_len(nrow(queue)), function(i) {
    replacement <- trimws(queue$replacement[i])
    if (!nzchar(replacement)) {
      return("Replacement is required.")
    }

    parsed <- suppressWarnings(parse_numeric_results(replacement))
    if (any(parsed$parse_flag == "unparseable", na.rm = TRUE)) {
      return("Replacement is still unparseable.")
    }
    if (any(parsed$parse_flag != "", na.rm = TRUE) || all(is.na(parsed$numeric_value))) {
      return("Replacement did not parse to a numeric value.")
    }

    NA_character_
  })
  reasons <- unlist(validation, use.names = FALSE)
  valid_mask <- is.na(reasons)

  valid <- queue[valid_mask, , drop = FALSE]
  invalid <- queue[!valid_mask, , drop = FALSE]
  invalid$reason <- reasons[!valid_mask]

  list(valid = valid, invalid = invalid)
}

append_numeric_corrections <- function(corrections_tbl, queue) {
  queue <- normalize_numeric_correction_queue(queue)
  if (nrow(queue) == 0L) {
    if (is.null(corrections_tbl)) {
      return(tibble::tibble(pattern = character(), replacement = character()))
    }
    return(corrections_tbl)
  }

  new_rows <- queue[, c("pattern", "replacement"), drop = FALSE]
  new_rows <- new_rows[!duplicated(new_rows$pattern, fromLast = TRUE), , drop = FALSE]

  if (is.null(corrections_tbl)) {
    corrections_tbl <- tibble::tibble(pattern = character(), replacement = character())
  }
  corrections_tbl <- tibble::as_tibble(corrections_tbl)
  for (col in c("pattern", "replacement")) {
    if (!col %in% names(corrections_tbl)) {
      corrections_tbl[[col]] <- character(nrow(corrections_tbl))
    }
  }
  corrections_tbl <- corrections_tbl[, c("pattern", "replacement"), drop = FALSE]
  corrections_tbl <- corrections_tbl[!corrections_tbl$pattern %in% new_rows$pattern, , drop = FALSE]

  dplyr::bind_rows(corrections_tbl, new_rows)
}

harmonize_measurement_column <- function(
  input_df,
  measurement_col,
  measurement_role,
  unit_col = NULL,
  unit_map,
  corrections = NULL,
  media = NULL,
  apply_units = TRUE
) {
  raw_values <- input_df[[measurement_col]]
  original_values <- as.character(raw_values)
  corrected_values <- apply_measurement_corrections(original_values, corrections)
  parse_values <- if (is.numeric(raw_values) && (is.null(corrections) || nrow(corrections) == 0)) {
    raw_values
  } else {
    corrected_values
  }
  parse_tibble <- parse_numeric_results(parse_values)

  parsed <- tibble::add_column(
    parse_tibble,
    measurement_column = measurement_col,
    measurement_role = measurement_role,
    original_value = original_values[parse_tibble$orig_row_id],
    corrected_value = corrected_values[parse_tibble$orig_row_id],
    .before = 1
  )

  if (isTRUE(apply_units) && !is.null(unit_col) && length(unit_col) > 0 && unit_col %in% names(input_df)) {
    unit_values <- as.character(input_df[[unit_col]])
    unit_values_expanded <- unit_values[parse_tibble$orig_row_id]
    media_expanded <- expand_measurement_context(
      media,
      parse_tibble$orig_row_id,
      nrow(input_df),
      nrow(parse_tibble)
    )

    harmonized_raw <- harmonize_units(
      values = parse_tibble$numeric_value,
      units = unit_values_expanded,
      unit_map = unit_map,
      media = media_expanded
    )
    harmonized_raw$orig_row_id <- parse_tibble$orig_row_id
  } else {
    harmonized_raw <- tibble::tibble(
      orig_row_id = parse_tibble$orig_row_id,
      orig_unit = rep(NA_character_, nrow(parse_tibble)),
      harmonized_value = parse_tibble$numeric_value,
      harmonized_unit = rep(NA_character_, nrow(parse_tibble)),
      conversion_factor = rep(1, nrow(parse_tibble)),
      unit_flag = rep("", nrow(parse_tibble))
    )
  }

  harmonized <- tibble::add_column(
    harmonized_raw,
    measurement_column = measurement_col,
    measurement_role = measurement_role,
    .before = 1
  )

  list(
    parsed = parsed,
    harmonized = harmonized,
    audit = build_measurement_audit_from_results(parsed, harmonized)
  )
}

harmonize_tagged_numeric_measurements <- function(
  input_df,
  tag_values,
  unit_map,
  corrections = NULL,
  media = NULL,
  apply_units = TRUE
) {
  if (is.list(tag_values)) {
    tag_values <- unlist(tag_values, use.names = TRUE)
  }

  result_cols <- names(tag_values)[tag_values == "Result"]
  auxiliary_roles <- c("Numeric", "ReportingLimit", "Uncertainty")
  numeric_cols <- names(tag_values)[tag_values %in% auxiliary_roles]
  unit_cols <- names(tag_values)[tag_values == "Unit"]
  unit_col <- if (length(unit_cols) > 0) unit_cols[1] else NULL

  primary <- NULL
  if (length(result_cols) > 0) {
    primary <- harmonize_measurement_column(
      input_df = input_df,
      measurement_col = result_cols[1],
      measurement_role = "Result",
      unit_col = unit_col,
      unit_map = unit_map,
      corrections = corrections,
      media = media,
      apply_units = apply_units
    )
  }

  auxiliary <- lapply(numeric_cols, function(numeric_col) {
    harmonize_measurement_column(
      input_df = input_df,
      measurement_col = numeric_col,
      measurement_role = unname(tag_values[[numeric_col]]),
      unit_col = unit_col,
      unit_map = unit_map,
      corrections = corrections,
      media = media,
      apply_units = apply_units
    )
  })
  names(auxiliary) <- numeric_cols

  all_measurements <- c(if (!is.null(primary)) list(primary) else list(), auxiliary)
  if (length(all_measurements) == 0) {
    return(list(
      primary = NULL,
      auxiliary = auxiliary,
      harmonize_results = NULL,
      audit = NULL,
      toxval_harmonized = build_identity_harmonize_tibble(nrow(input_df))
    ))
  }

  combined_parsed <- dplyr::bind_rows(lapply(all_measurements, `[[`, "parsed"))
  combined_harmonized <- dplyr::bind_rows(lapply(all_measurements, `[[`, "harmonized"))
  combined_audit <- build_measurement_audit_from_results(combined_parsed, combined_harmonized)

  list(
    primary = primary,
    auxiliary = auxiliary,
    harmonize_results = list(
      parsed = combined_parsed,
      harmonized = combined_harmonized,
      input_data = input_df
    ),
    audit = combined_audit,
    toxval_harmonized = if (!is.null(primary)) primary$harmonized else build_identity_harmonize_tibble(nrow(input_df))
  )
}
