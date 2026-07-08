# Shared non-Shiny harmonization runtime used by app and headless replay.

default_harmonize_step_mask <- function() {
  list(units = TRUE, duration = TRUE, dates = TRUE, media = TRUE)
}

normalize_harmonize_step_mask <- function(mask = NULL) {
  default_mask <- default_harmonize_step_mask()
  if (is.null(mask)) {
    return(default_mask)
  }

  stats::setNames(
    lapply(names(default_mask), function(name) isTRUE(mask[[name]])),
    names(default_mask)
  )
}

resolve_harmonization_reference <- function(value, reference_lists, name, loader, cache_dir = NULL) {
  if (!is.null(value)) {
    return(value)
  }
  if (!is.null(reference_lists) && !is.null(reference_lists[[name]])) {
    return(reference_lists[[name]])
  }

  loader(resolve_reference_cache_dir(cache_dir))
}

resolve_harmonization_references <- function(
  unit_map = NULL,
  corrections = NULL,
  media_map = NULL,
  reference_lists = NULL,
  cache_dir = NULL
) {
  list(
    unit_map = resolve_harmonization_reference(
      unit_map,
      reference_lists,
      "unit_map",
      load_unit_map,
      cache_dir
    ),
    corrections = resolve_harmonization_reference(
      corrections,
      reference_lists,
      "corrections",
      load_corrections,
      cache_dir
    ),
    media_map = resolve_harmonization_reference(
      media_map,
      reference_lists,
      "media_map",
      load_media_map,
      cache_dir
    )
  )
}

as_harmonization_tag_values <- function(tag_map) {
  if (is.null(tag_map) || length(tag_map) == 0L) {
    return(character())
  }

  tag_values <- unlist(as.list(tag_map), recursive = FALSE, use.names = TRUE)
  tag_names <- names(tag_values)
  tag_values <- as.character(tag_values)
  names(tag_values) <- tag_names
  tag_values
}

missing_harmonization_columns <- function(input_data, tag_values) {
  harmonization_roles <- c(
    "Result",
    "Numeric",
    "ReportingLimit",
    "Uncertainty",
    "UncertaintyCoverage",
    "Qualifier",
    "Unit",
    "Duration",
    "DurationUnit",
    "StudyDate",
    "Media"
  )
  tagged <- names(tag_values)[tag_values %in% harmonization_roles]
  tagged <- tagged[!is.na(tagged) & nzchar(tagged)]
  setdiff(tagged, names(input_data))
}

expand_row_context_value <- function(value, n) {
  if (is.null(value)) {
    return(NULL)
  }
  if (length(value) == 1L) {
    return(rep(value, n))
  }
  value
}

run_harmonization_runtime <- function(
  input_data,
  tag_map,
  unit_map,
  corrections = NULL,
  media_map = NULL,
  media = NULL,
  source_name = NULL,
  step_mask = NULL
) {
  input_df <- tibble::as_tibble(input_data)
  input_df <- input_df[, setdiff(names(input_df), DETECTION_GENERATED_COLUMNS), drop = FALSE]
  tag_values <- as_harmonization_tag_values(tag_map)
  h_mask <- normalize_harmonize_step_mask(step_mask)

  missing_cols <- missing_harmonization_columns(input_df, tag_values)
  if (length(missing_cols) > 0L) {
    stop(
      sprintf(
        "run_harmonization_runtime: tag_map column(s) not found in input_data: %s",
        paste(missing_cols, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  result_cols <- names(tag_values)[tag_values == "Result"]
  numeric_cols <- names(tag_values)[tag_values %in% c("Numeric", "ReportingLimit", "Uncertainty")]
  unit_cols <- names(tag_values)[tag_values == "Unit"]
  duration_cols <- names(tag_values)[tag_values == "Duration"]
  duration_unit_cols <- names(tag_values)[tag_values == "DurationUnit"]
  date_cols <- names(tag_values)[tag_values == "StudyDate"]
  media_cols <- names(tag_values)[tag_values == "Media"]

  has_measurement <- length(result_cols) > 0L || length(numeric_cols) > 0L
  has_duration_measurement <- length(duration_cols) > 0L && length(duration_unit_cols) > 0L
  has_harmonization_input <- has_measurement ||
    has_duration_measurement ||
    length(date_cols) > 0L ||
    length(media_cols) > 0L

  if (!has_harmonization_input) {
    stop(
      paste(
        "run_harmonization_runtime: harmonization requires at least one column",
        "tagged as Result, Numeric, Duration, StudyDate, or Media."
      ),
      call. = FALSE
    )
  }

  updated_data <- input_df
  media_results <- NULL
  duration_results <- NULL
  date_results <- NULL
  detection_results <- NULL
  media_for_harmonize <- NULL

  if (isTRUE(h_mask$media) && length(media_cols) > 0L) {
    media_results <- harmonize_media(
      raw_media = as.character(updated_data[[media_cols[1]]]),
      orig_row_id = seq_len(nrow(updated_data)),
      media_map = media_map
    )
    updated_data$media <- media_results$media_category[
      match(seq_len(nrow(updated_data)), media_results$orig_row_id)
    ]
    media_for_harmonize <- media_results$media_category
  } else if ("media" %in% names(updated_data)) {
    media_for_harmonize <- updated_data$media
  } else if (!is.null(media)) {
    media_for_harmonize <- expand_row_context_value(media, nrow(updated_data))
    updated_data$media <- media_for_harmonize
  }

  if (has_measurement) {
    measurement_result <- harmonize_tagged_numeric_measurements(
      input_df = updated_data,
      tag_values = tag_values,
      unit_map = unit_map,
      corrections = corrections,
      media = media_for_harmonize,
      apply_units = isTRUE(h_mask$units) && length(unit_cols) > 0L
    )
    harmonize_results <- measurement_result$harmonize_results
    harmonize_audit <- measurement_result$audit
    harmonize_tibble <- measurement_result$toxval_harmonized

    detection_result <- classify_harmonized_detection(
      input_df = updated_data,
      tag_values = tag_values,
      measurement_result = measurement_result
    )
    if (!is.null(detection_result)) {
      detection_results <- detection_result$expanded_detection
      updated_data <- append_detection_fields(
        updated_data,
        detection_result$row_detection,
        allow_existing_generated = TRUE
      )
    }
  } else {
    n_rows <- nrow(updated_data)
    harmonize_tibble <- build_identity_harmonize_tibble(n_rows)
    parse_tibble <- tibble::tibble(
      orig_row_id = seq_len(n_rows),
      raw_value = rep(NA_character_, n_rows),
      numeric_value = rep(NA_real_, n_rows),
      value_flag = rep("", n_rows)
    )
    harmonize_results <- list(
      parsed = parse_tibble,
      harmonized = harmonize_tibble,
      input_data = updated_data
    )
    harmonize_audit <- NULL
  }

  if (isTRUE(h_mask$duration) && has_duration_measurement) {
    dur_tibble <- harmonize_units(
      values = as.numeric(updated_data[[duration_cols[1]]]),
      units = as.character(updated_data[[duration_unit_cols[1]]]),
      unit_map = unit_map,
      category = "duration"
    )
    duration_results <- tibble::tibble(
      orig_row_id = dur_tibble$orig_row_id,
      study_duration_value = dur_tibble$harmonized_value,
      study_duration_units = dur_tibble$harmonized_unit,
      duration_unit_flag = dur_tibble$unit_flag
    )
    dur_idx <- match(seq_len(nrow(updated_data)), duration_results$orig_row_id)
    updated_data$study_duration_value <- duration_results$study_duration_value[dur_idx]
    updated_data$study_duration_units <- duration_results$study_duration_units[dur_idx]
  }

  if (isTRUE(h_mask$dates) && length(date_cols) > 0L) {
    date_results <- parse_dates(
      raw_dates = as.character(updated_data[[date_cols[1]]]),
      orig_row_id = seq_len(nrow(updated_data))
    )
    date_idx <- match(seq_len(nrow(updated_data)), date_results$orig_row_id)
    updated_data$year <- date_results$date_year[date_idx]
  }

  toxval_output <- map_to_toxval_schema(
    curated_data = updated_data,
    harmonized_data = harmonize_tibble,
    source_name = source_name
  )

  list(
    harmonize_results = harmonize_results,
    harmonize_audit = harmonize_audit,
    toxval_output = toxval_output,
    media_results = media_results,
    duration_results = duration_results,
    date_results = date_results,
    detection_results = detection_results,
    data = updated_data
  )
}
