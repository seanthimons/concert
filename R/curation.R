# Curation Module for Chemical Inventory Data
# Uses ComptoxR package to validate and lookup chemical identifiers

#' Validate CAS Numbers
#'
#' @param cas_vector Character vector of CAS numbers to validate
#' @return Tibble with original, validated CAS, and validation status
#' @export
validate_cas_numbers <- function(cas_vector) {
  # Use ComptoxR::is_cas() and as_cas()
  tibble::tibble(
    original_cas = cas_vector,
    validated_cas = ComptoxR::as_cas(cas_vector),
    is_valid = ComptoxR::is_cas(validated_cas)
  )
}

#' Lookup Chemical Names
#'
#' @param name_vector Character vector of chemical names
#' @param search_method "exact", "starts", or "contains"
#' @return Tibble with original name, matched DTXSID, preferred name, CAS, match confidence
#' @export
lookup_chemical_names <- function(name_vector, search_method = "exact") {
  # Remove NA and empty values
  clean_names <- name_vector[!is.na(name_vector) & name_vector != ""]

  if (length(clean_names) == 0) {
    return(tibble::tibble(
      raw_search = character(0),
      dtxsid = character(0),
      preferredName = character(0),
      casrn = character(0),
      match_status = character(0),
      match_confidence = numeric(0)
    ))
  }

  # Use ComptoxR::ct_search()
  # Handle batch processing for large datasets
  results <- ComptoxR::ct_search(
    query = unique(clean_names),
    request_method = "POST",  # Batch processing
    search_method = search_method
  )

  # Process results into standardized format
  if (nrow(results) == 0) {
    # No matches found
    return(tibble::tibble(
      raw_search = clean_names,
      dtxsid = NA_character_,
      preferredName = NA_character_,
      casrn = NA_character_,
      match_status = "no_match",
      match_confidence = 0.0
    ))
  }

  # Add match status and confidence
  results <- results %>%
    dplyr::mutate(
      match_status = dplyr::case_when(
        is.na(dtxsid) ~ "no_match",
        search_method == "exact" ~ "exact_match",
        TRUE ~ "fuzzy_match"
      ),
      match_confidence = dplyr::case_when(
        match_status == "exact_match" ~ 1.0,
        match_status == "fuzzy_match" ~ 0.8,
        TRUE ~ 0.0
      )
    )

  # For names that weren't found at all, add them as no_match
  missing_names <- setdiff(clean_names, results$raw_search)
  if (length(missing_names) > 0) {
    missing_df <- tibble::tibble(
      raw_search = missing_names,
      dtxsid = NA_character_,
      preferredName = NA_character_,
      casrn = NA_character_,
      match_status = "no_match",
      match_confidence = 0.0
    )
    results <- dplyr::bind_rows(results, missing_df)
  }

  return(results)
}

#' Curate Chemical Inventory Data
#'
#' @param clean_data The cleaned data frame (data_store$clean)
#' @param column_tags Named list of column tags (col_name -> "Name"|"CASRN"|"Other")
#' @return List with curated_data and curation_report
#' @export
curate_chemical_data <- function(clean_data, column_tags) {
  # Identify name and CASRN columns
  name_cols <- names(column_tags)[column_tags == "Name"]
  cas_cols <- names(column_tags)[column_tags == "CASRN"]

  results_list <- list()

  # Process CAS columns
  for (col in cas_cols) {
    results_list[[col]] <- clean_data %>%
      dplyr::select(dplyr::all_of(col)) %>%
      dplyr::mutate(row_id = dplyr::row_number()) %>%
      dplyr::rename(original_value = !!rlang::sym(col)) %>%
      dplyr::mutate(
        column_type = "CASRN",
        original_column = col
      )

    # Validate CAS numbers
    cas_validation <- validate_cas_numbers(results_list[[col]]$original_value)

    results_list[[col]] <- results_list[[col]] %>%
      dplyr::bind_cols(
        cas_validation %>% dplyr::select(validated_cas, is_valid)
      )
  }

  # Process Name columns
  for (col in name_cols) {
    name_values <- clean_data[[col]]

    # Lookup chemical names
    lookup_results <- lookup_chemical_names(name_values, search_method = "exact")

    results_list[[col]] <- clean_data %>%
      dplyr::select(dplyr::all_of(col)) %>%
      dplyr::mutate(row_id = dplyr::row_number()) %>%
      dplyr::rename(original_value = !!rlang::sym(col)) %>%
      dplyr::mutate(
        column_type = "Name",
        original_column = col
      ) %>%
      dplyr::left_join(
        lookup_results,
        by = c("original_value" = "raw_search")
      )
  }

  # Combine all results
  curated_data <- dplyr::bind_rows(results_list)

  # Generate report
  report <- list(
    total_rows = nrow(clean_data),
    cas_columns = length(cas_cols),
    name_columns = length(name_cols),
    cas_validated = sum(curated_data$column_type == "CASRN" & curated_data$is_valid == TRUE, na.rm = TRUE),
    cas_invalid = sum(curated_data$column_type == "CASRN" & curated_data$is_valid == FALSE, na.rm = TRUE),
    names_exact_match = sum(curated_data$column_type == "Name" & curated_data$match_status == "exact_match", na.rm = TRUE),
    names_fuzzy_match = sum(curated_data$column_type == "Name" & curated_data$match_status == "fuzzy_match", na.rm = TRUE),
    names_no_match = sum(curated_data$column_type == "Name" & curated_data$match_status == "no_match", na.rm = TRUE)
  )

  list(
    curated_data = curated_data,
    report = report
  )
}
