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
  original_values <- as.character(input_df[[measurement_col]])
  corrected_values <- apply_measurement_corrections(original_values, corrections)
  parse_tibble <- parse_numeric_results(corrected_values)

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
  numeric_cols <- names(tag_values)[tag_values == "Numeric"]
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
      measurement_role = "Numeric",
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
