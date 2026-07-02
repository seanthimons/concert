# toxval_mapper.R
# ToxVal schema mapping functionality
#
# Transforms CONCERT curated + harmonized data into ToxVal-compatible 56-column format
# with typed NAs, source_hash, and *_original audit columns.

#' Map curated data to ToxVal schema
#'
#' Transforms CONCERT's curated and harmonized data into the 56-column
#' ToxVal-compatible format with typed NAs and *_original audit columns.
#'
#' @param curated_data Tibble from curation pipeline containing at minimum:
#'   - dtxsid: DSSTox substance identifier
#'   - casrn: CAS Registry Number
#'   - name: Chemical name
#'   Optional columns: qualifier, orig_result, toxval_type, species_common, etc.
#' @param harmonized_data Tibble from harmonize_units() containing:
#'   - orig_row_id: Row identifier linking back to curated_data
#'   - orig_unit: Original unit string before normalization
#'   - harmonized_value: Numeric value after conversion
#'   - harmonized_unit: Target canonical unit
#'   - conversion_factor: Multiplier applied
#'   - unit_flag: Conversion quality flag
#' @param source_name Optional dataset identifier. Defaults to "user_upload".
#'
#' @return Tibble with 56 ToxVal columns including:
#'   - Mapped values from curated_data and harmonized_data
#'   - Typed NA values for unmapped columns (NA_character_, NA_real_)
#'   - source_hash: SHA256 digest of row content
#'   - *_original audit columns preserving pre-harmonization values
#'
#' @examples
#' \dontrun{
#' curated <- tibble::tibble(
#'   dtxsid = "DTXSID7020182",
#'   casrn = "71-43-2",
#'   name = "Benzene"
#' )
#' harmonized <- tibble::tibble(
#'   orig_row_id = 1L,
#'   orig_unit = "ug/L",
#'   harmonized_value = 0.5,
#'   harmonized_unit = "mg/L",
#'   conversion_factor = 0.001,
#'   unit_flag = ""
#' )
#' result <- map_to_toxval_schema(curated, harmonized)
#' }
#'
#' @importFrom tibble tibble
#' @importFrom digest digest
#' @export
map_to_toxval_schema <- function(curated_data, harmonized_data, source_name = NULL) {
  # Handle zero-row input
  n_rows <- nrow(harmonized_data)
  if (n_rows == 0) {
    return(get_empty_schema())
  }

  # Default source name
  source_name <- source_name %||% "user_upload"

  if (!"orig_row_id" %in% names(harmonized_data)) {
    harmonized_data$orig_row_id <- seq_len(nrow(harmonized_data))
  }

  row_idx <- harmonized_data$orig_row_id
  if (any(is.na(row_idx)) || any(row_idx < 1) || any(row_idx > nrow(curated_data))) {
    stop("map_to_toxval_schema: harmonized_data$orig_row_id contains invalid row indexes.")
  }

  row_data <- curated_data[row_idx, , drop = FALSE]

  pick_char <- function(primary, fallback = NULL) {
    if (primary %in% names(row_data)) {
      value <- as.character(row_data[[primary]])
      if (!is.null(fallback)) {
        fallback <- fallback[!is.na(fallback)]
        for (fallback_col in fallback) {
          if (fallback_col %in% names(row_data)) {
            fallback_value <- as.character(row_data[[fallback_col]])
            value[is.na(value) | value == ""] <- fallback_value[is.na(value) | value == ""]
          }
        }
      }
      value
    } else if (!is.null(fallback) && any(fallback %in% names(row_data))) {
      fallback <- fallback[!is.na(fallback)]
      fallback_col <- fallback[fallback %in% names(row_data)][1]
      as.character(row_data[[fallback_col]])
    } else {
      rep(NA_character_, n_rows)
    }
  }

  pick_num <- function(primary, fallback = NULL) {
    if (primary %in% names(row_data)) {
      as.numeric(row_data[[primary]])
    } else if (!is.null(fallback) && fallback %in% names(row_data)) {
      as.numeric(row_data[[fallback]])
    } else {
      rep(NA_real_, n_rows)
    }
  }

  # Extract orig_result values if present (for toxval_numeric_original)
  if ("numeric_value_original" %in% names(harmonized_data)) {
    orig_numeric <- suppressWarnings(as.numeric(harmonized_data$numeric_value_original))
  } else if ("orig_result" %in% names(row_data)) {
    # Parse numeric from orig_result strings (strip qualifiers)
    orig_numeric <- suppressWarnings(as.numeric(gsub("[<>=~]", "", row_data$orig_result)))
  } else {
    orig_numeric <- harmonized_data$harmonized_value
  }

  # Build the result tibble with all 56 columns in exact ToxVal order
  result <- tibble::tibble(
    # Core identifiers (1-3)
    dtxsid = pick_char("consensus_dtxsid", "dtxsid"),
    casrn = pick_char("casrn", c("cas", names(row_data)[tag_values(row_data, c("CASRN", "CAS"))])),
    name = pick_char("name", c("analyte", "chemical", "chemical_name", names(row_data)[tag_values(row_data, c("Name"))])),

    # Source information (4-5)
    source = if ("source" %in% names(row_data)) pick_char("source") else rep(source_name, n_rows),
    sub_source = pick_char("sub_source"),

    # Toxval type information (6-8)
    toxval_type = pick_char("toxval_type"),
    toxval_subtype = pick_char("toxval_subtype"),
    toxval_type_supercategory = pick_char("toxval_type_supercategory"),

    # Toxicity values (9-11)
    qualifier = pick_char("qualifier"),
    toxval_numeric = harmonized_data$harmonized_value,
    toxval_units = harmonized_data$harmonized_unit,

    # Risk and study (12-16)
    risk_assessment_class = pick_char("risk_assessment_class"),
    study_type = pick_char("study_type"),
    study_duration_class = pick_char("study_duration_class"),
    study_duration_value = pick_num("study_duration_value"),
    study_duration_units = pick_char("study_duration_units"),

    # Species (17-20)
    species_common = pick_char("species_common"),
    strain = pick_char("strain"),
    latin_name = pick_char("latin_name"),
    species_supercategory = pick_char("species_supercategory"),

    # Biology (21-23)
    sex = pick_char("sex"),
    generation = pick_char("generation"),
    lifestage = pick_char("lifestage"),

    # Exposure (24-27)
    exposure_route = pick_char("exposure_route"),
    exposure_method = pick_char("exposure_method"),
    exposure_form = pick_char("exposure_form"),
    media = pick_char("media"),

    # Effects (28-29)
    toxicological_effect = pick_char("toxicological_effect"),
    toxicological_effect_category = pick_char("toxicological_effect_category"),

    # Study metadata (30-32)
    experimental_record = pick_char("experimental_record"),
    study_group = pick_char("study_group"),
    year = pick_num("year"),

    # QC (33-34)
    qc_category = if ("qc_category" %in% names(row_data)) pick_char("qc_category") else rep("user_curated", n_rows),
    qc_status = if ("qc_status" %in% names(row_data)) pick_char("qc_status") else rep("pass", n_rows),

    # Hash and URLs (35-37) - source_hash populated later
    source_hash = rep(NA_character_, n_rows),
    source_url = pick_char("source_url"),
    subsource_url = pick_char("subsource_url"),

    # Audit columns: *_original (38-56)
    toxval_type_original = pick_char("toxval_type_original", "toxval_type"),
    toxval_subtype_original = pick_char("toxval_subtype_original", "toxval_subtype"),
    toxval_numeric_original = orig_numeric,
    toxval_units_original = harmonized_data$orig_unit,
    study_type_original = pick_char("study_type_original", "study_type"),
    study_duration_class_original = pick_char("study_duration_class_original", "study_duration_class"),
    study_duration_value_original = pick_num("study_duration_value_original", "study_duration_value"),
    study_duration_units_original = pick_char("study_duration_units_original", "study_duration_units"),
    species_original = pick_char("species_original", "species_common"),
    strain_original = pick_char("strain_original", "strain"),
    sex_original = pick_char("sex_original", "sex"),
    generation_original = pick_char("generation_original", "generation"),
    lifestage_original = pick_char("lifestage_original", "lifestage"),
    exposure_route_original = pick_char("exposure_route_original", "exposure_route"),
    exposure_method_original = pick_char("exposure_method_original", "exposure_method"),
    exposure_form_original = pick_char("exposure_form_original", "exposure_form"),
    media_original = pick_char("media_original", "media"),
    toxicological_effect_original = pick_char("toxicological_effect_original", "toxicological_effect"),
    original_year = pick_num("original_year", "year")
  )

  # Generate source_hash for each row
  result$source_hash <- generate_source_hash(result)

  # Verify no bare NAs (logical type)
  assert_typed_nas(result)

  result
}

tag_values <- function(df, tags) {
  tag_cols <- grep("_tag$", names(df), value = TRUE)
  if (length(tag_cols) == 0) {
    return(rep(FALSE, length(names(df))))
  }
  matched <- rep(FALSE, length(names(df)))
  names(matched) <- names(df)
  for (tag_col in tag_cols) {
    data_col <- sub("_tag$", "", tag_col)
    if (data_col %in% names(df) && any(df[[tag_col]] %in% tags, na.rm = TRUE)) {
      matched[data_col] <- TRUE
    }
  }
  matched
}

#' Get empty schema template
#'
#' Returns a zero-row tibble with all 56 ToxVal columns properly typed.
#' Used for zero-row input handling.
#'
#' @return Zero-row tibble with 56 typed columns
#' @keywords internal
get_empty_schema <- function() {
  cache_dir <- system.file("extdata/reference_cache", package = "concert")
  load_toxval_schema(cache_dir)
}

#' Safely extract character column from data frame
#'
#' Returns the column if it exists, otherwise returns NA_character_ vector.
#'
#' @param df Data frame to extract from
#' @param col Column name
#' @param n Number of rows expected
#' @return Character vector of length n
#' @keywords internal
safe_extract_char <- function(df, col, n) {
  if (col %in% names(df)) {
    as.character(df[[col]])
  } else {
    rep(NA_character_, n)
  }
}

#' Safely extract numeric column from data frame
#'
#' Returns the column if it exists, otherwise returns NA_real_ vector.
#'
#' @param df Data frame to extract from
#' @param col Column name
#' @param n Number of rows expected
#' @return Numeric vector of length n
#' @keywords internal
safe_extract_num <- function(df, col, n) {
  if (col %in% names(df)) {
    as.numeric(df[[col]])
  } else {
    rep(NA_real_, n)
  }
}

#' Generate source hash for each row
#'
#' Computes SHA256 digest of all row values (excluding source_hash itself)
#' concatenated with "|" separator.
#'
#' @param result_tibble Tibble to hash (source_hash column will be NA)
#' @return Character vector of SHA256 hashes
#' @keywords internal
generate_source_hash <- function(result_tibble) {
  # Exclude source_hash column from hash computation
  cols_to_hash <- setdiff(names(result_tibble), "source_hash")

  vapply(seq_len(nrow(result_tibble)), function(i) {
    # Concatenate all values for this row
    row_values <- vapply(cols_to_hash, function(col) {
      val <- result_tibble[[col]][i]
      if (is.na(val)) "NA" else as.character(val)
    }, character(1))

    paste_string <- paste(row_values, collapse = "|")
    digest::digest(paste_string, algo = "sha256")
  }, character(1))
}

#' Assert no bare NA values in tibble
#'
#' Verifies all columns have typed NA values (NA_character_, NA_real_, etc.)
#' and no columns are logical type (which would indicate bare NA).
#'
#' @param tbl Tibble to verify
#' @return Invisible NULL (stops with error if assertion fails)
#' @keywords internal
assert_typed_nas <- function(tbl) {
  types <- vapply(tbl, typeof, "")
  logical_cols <- names(types)[types == "logical"]

  if (length(logical_cols) > 0) {
    stop(
      "Found columns with bare NA (logical type): ",
      paste(logical_cols, collapse = ", "),
      ". Use NA_character_ or NA_real_ instead."
    )
  }

  invisible(NULL)
}
