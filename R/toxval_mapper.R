# toxval_mapper.R
# ToxVal schema mapping functionality
#
# Transforms ChemReg curated + harmonized data into ToxVal-compatible 56-column format
# with typed NAs, source_hash, and *_original audit columns.

#' Map curated data to ToxVal schema
#'
#' Transforms ChemReg's curated and harmonized data into the 56-column
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
  n_rows <- nrow(curated_data)
  if (n_rows == 0) {
    return(get_empty_schema())
  }

  # Default source name
  source_name <- source_name %||% "user_upload"

  # Extract orig_result values if present (for toxval_numeric_original)
  if ("orig_result" %in% names(curated_data)) {
    # Parse numeric from orig_result strings (strip qualifiers)
    orig_numeric <- suppressWarnings(as.numeric(gsub("[<>=~]", "", curated_data$orig_result)))
  } else {
    orig_numeric <- harmonized_data$harmonized_value
  }

  # Build the result tibble with all 56 columns in exact ToxVal order
  result <- tibble::tibble(
    # Core identifiers (1-3)
    dtxsid = safe_extract_char(curated_data, "dtxsid", n_rows),
    casrn = safe_extract_char(curated_data, "casrn", n_rows),
    name = safe_extract_char(curated_data, "name", n_rows),

    # Source information (4-5)
    source = rep(source_name, n_rows),
    sub_source = rep(NA_character_, n_rows),

    # Toxval type information (6-8)
    toxval_type = safe_extract_char(curated_data, "toxval_type", n_rows),
    toxval_subtype = rep(NA_character_, n_rows),
    toxval_type_supercategory = rep(NA_character_, n_rows),

    # Toxicity values (9-11)
    qualifier = safe_extract_char(curated_data, "qualifier", n_rows),
    toxval_numeric = harmonized_data$harmonized_value,
    toxval_units = harmonized_data$harmonized_unit,

    # Risk and study (12-16)
    risk_assessment_class = rep(NA_character_, n_rows),
    study_type = safe_extract_char(curated_data, "study_type", n_rows),
    study_duration_class = rep(NA_character_, n_rows),
    study_duration_value = safe_extract_num(curated_data, "study_duration_value", n_rows),
    study_duration_units = safe_extract_char(curated_data, "study_duration_units", n_rows),

    # Species (17-20)
    species_common = safe_extract_char(curated_data, "species_common", n_rows),
    strain = safe_extract_char(curated_data, "strain", n_rows),
    latin_name = rep(NA_character_, n_rows),
    species_supercategory = rep(NA_character_, n_rows),

    # Biology (21-23)
    sex = safe_extract_char(curated_data, "sex", n_rows),
    generation = safe_extract_char(curated_data, "generation", n_rows),
    lifestage = safe_extract_char(curated_data, "lifestage", n_rows),

    # Exposure (24-27)
    exposure_route = safe_extract_char(curated_data, "exposure_route", n_rows),
    exposure_method = safe_extract_char(curated_data, "exposure_method", n_rows),
    exposure_form = safe_extract_char(curated_data, "exposure_form", n_rows),
    media = safe_extract_char(curated_data, "media", n_rows),

    # Effects (28-29)
    toxicological_effect = safe_extract_char(curated_data, "toxicological_effect", n_rows),
    toxicological_effect_category = rep(NA_character_, n_rows),

    # Study metadata (30-32)
    experimental_record = rep(NA_character_, n_rows),
    study_group = rep(NA_character_, n_rows),
    year = safe_extract_num(curated_data, "year", n_rows),

    # QC (33-34)
    qc_category = rep("user_curated", n_rows),
    qc_status = rep("pass", n_rows),

    # Hash and URLs (35-37) - source_hash populated later
    source_hash = rep(NA_character_, n_rows),
    source_url = rep(NA_character_, n_rows),
    subsource_url = rep(NA_character_, n_rows),

    # Audit columns: *_original (38-56)
    toxval_type_original = safe_extract_char(curated_data, "toxval_type", n_rows),
    toxval_subtype_original = rep(NA_character_, n_rows),
    toxval_numeric_original = orig_numeric,
    toxval_units_original = harmonized_data$orig_unit,
    study_type_original = safe_extract_char(curated_data, "study_type", n_rows),
    study_duration_class_original = rep(NA_character_, n_rows),
    study_duration_value_original = safe_extract_num(curated_data, "study_duration_value", n_rows),
    study_duration_units_original = safe_extract_char(curated_data, "study_duration_units", n_rows),
    species_original = safe_extract_char(curated_data, "species_common", n_rows),
    strain_original = safe_extract_char(curated_data, "strain", n_rows),
    sex_original = safe_extract_char(curated_data, "sex", n_rows),
    generation_original = safe_extract_char(curated_data, "generation", n_rows),
    lifestage_original = safe_extract_char(curated_data, "lifestage", n_rows),
    exposure_route_original = safe_extract_char(curated_data, "exposure_route", n_rows),
    exposure_method_original = safe_extract_char(curated_data, "exposure_method", n_rows),
    exposure_form_original = safe_extract_char(curated_data, "exposure_form", n_rows),
    media_original = safe_extract_char(curated_data, "media", n_rows),
    toxicological_effect_original = safe_extract_char(curated_data, "toxicological_effect", n_rows),
    original_year = safe_extract_num(curated_data, "year", n_rows)
  )

  # Generate source_hash for each row
  result$source_hash <- generate_source_hash(result)

  # Verify no bare NAs (logical type)
  assert_typed_nas(result)

  result
}

#' Get empty schema template
#'
#' Returns a zero-row tibble with all 56 ToxVal columns properly typed.
#' Used for zero-row input handling.
#'
#' @return Zero-row tibble with 56 typed columns
#' @keywords internal
get_empty_schema <- function() {
  cache_dir <- system.file("extdata/reference_cache", package = "chemreg")
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
