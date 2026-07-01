#' Detects chemical mixtures by name based on ratio patterns
#'
#' This function searches a vector of chemical names for patterns indicating a
#' ratio, such as "(1:1)" or "(2:1)". It is useful for identifying potential
#' mixtures that might not be flagged by other means. The search is robust to
#' extra whitespace. It complements [flag_multi_analyte()], which detects
#' `+`/`and` separators rather than numeric ratios.
#'
#' @param name_vector A character vector of chemical names to search.
#'
#' @return A logical vector of the same length as `name_vector`. Returns `TRUE`
#'   if a ratio pattern is found, `FALSE` if not, and `NA` for `NA` inputs.
#'
#' @export
#' @importFrom stringr str_detect
#'
#' @examples
#'  \dontrun{
#' test_names <- c(
#'   "Ethanol, water (1:1)",
#'   "Sodium chloride",
#'   "Styrene-butadiene copolymer (3:1)",
#'   "A name with extra spaces ( 2 : 1 )",
#'   "A name with decimals (1.5:1)",
#'   "1,2-Dichlorobenzene", # Should be FALSE
#'  "Mixture (3:1 w/w)",
#'   NA
#' )
#' extract_mixture(test_names)
#' test_names %>% enframe(., name = 'idx', value = 'name') %>% mutate(bool_mix = extract_mixture(name))
#' # Expected output: TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, NA
#' }
extract_mixture <- function(name_vector) {
  stopifnot(is.character(name_vector))

  # Core ratio like "2:1", "1.5/1", "3-2"
  ratio_core <- "\\d+(?:\\.\\d+)?\\s*[:/\\-]\\s*\\d+(?:\\.\\d+)?"
  # Optional units after ratio
  units_opt <- "(?:\\s*(?:w/w|v/v|wt%|vol%))?"

  # Allow ratios with or without surrounding () or []
  pattern <- paste0("(?:\\(|\\[)?\\s*", ratio_core, units_opt, "\\s*(?:\\)|\\])?")

  stringr::str_detect(name_vector, pattern)
}
