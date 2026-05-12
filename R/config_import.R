# Config Import Functions for CONCERT Export Re-import
#
# This module provides functions to detect and parse CONCERT exports,
# allowing users to restore reference lists and column tags from previous
# export files.

#' Parse CONCERT Export
#'
#' Detects if an Excel file is a valid CONCERT export and extracts
#' configuration data (reference lists and column tags).
#'
#' @param file_path Path to Excel file
#'
#' @return List with reference_lists, column_tags, config data frames,
#'         or NULL if not a valid CONCERT export
#' @export
parse_concert_export <- function(file_path) {
  tryCatch(
    {
      # Stage 1: Check if Pipeline Config sheet exists
      sheets <- readxl::excel_sheets(file_path)
      if (!"Pipeline Config" %in% sheets) {
        return(NULL)
      }

      # Stage 2: Check if concert_export marker is true
      config_df <- readxl::read_excel(file_path, sheet = "Pipeline Config")
      if (!"key" %in% names(config_df) || !"value" %in% names(config_df)) {
        return(NULL)
      }

      concert_marker <- config_df %>%
        dplyr::filter(key == "concert_export") %>%
        dplyr::pull(value)

      if (length(concert_marker) == 0 || concert_marker != "true") {
        return(NULL)
      }

      # Valid CONCERT export — read Reference Lists and Column Tags
      reference_lists_df <- if ("Reference Lists" %in% sheets) {
        readxl::read_excel(file_path, sheet = "Reference Lists")
      } else {
        tibble::tibble(type = character(), term = character(), source = character(), active = logical())
      }

      column_tags_df <- if ("Column Tags" %in% sheets) {
        readxl::read_excel(file_path, sheet = "Column Tags")
      } else {
        tibble::tibble(Column = character(), Type = character())
      }

      list(
        reference_lists = reference_lists_df,
        column_tags = column_tags_df,
        config = config_df
      )
    },
    error = function(e) {
      warning("Failed to parse CONCERT export: ", conditionMessage(e))
      return(NULL)
    }
  )
}

#' Merge Reference Lists
#'
#' Merges imported reference lists with existing lists, giving priority
#' to imported entries on term conflicts (imported wins).
#'
#' @param existing_lists List with $functional_categories, $stop_words, $block_patterns
#' @param imported_ref_df Combined reference list data frame with type column
#'
#' @return Updated list with merged reference lists
#' @export
merge_reference_lists <- function(existing_lists, imported_ref_df) {
  # Helper to merge a single type
  merge_type <- function(existing_tibble, imported_subset) {
    # Force source="imported" for all imported entries (overwrite existing source values)
    imported_subset <- imported_subset %>%
      dplyr::mutate(source = "imported") %>%
      dplyr::select(term, source, active)

    # Put imported first so distinct keeps it on conflicts
    merged <- dplyr::bind_rows(
      imported_subset,
      existing_tibble %>% dplyr::select(term, source, active)
    ) %>%
      dplyr::distinct(term, .keep_all = TRUE)

    merged
  }

  # Process each type
  list(
    functional_categories = merge_type(
      existing_lists$functional_categories,
      imported_ref_df %>% dplyr::filter(type == "functional_category") %>% dplyr::select(-type)
    ),
    stop_words = merge_type(
      existing_lists$stop_words,
      imported_ref_df %>% dplyr::filter(type == "stop_word") %>% dplyr::select(-type)
    ),
    block_patterns = merge_type(
      existing_lists$block_patterns,
      imported_ref_df %>% dplyr::filter(type == "block_pattern") %>% dplyr::select(-type)
    )
  )
}
