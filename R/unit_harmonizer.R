# unit_harmonizer.R
# Unit harmonization engine: normalization, case-safe lookup, conversion arithmetic.
#
# Public API: harmonize_units()
# Internal helper: normalize_unit_string()

#' Normalize a unit string for lookup
#'
#' Applies normalization chain to prepare unit strings for lookup:
#'   (a) Trim leading/trailing whitespace
#'   (b) Replace micro symbols: U+00B5 (micro sign) and U+03BC (Greek mu) -> "u"
#'   (c) Collapse spaces around "/": "mg / L" -> "mg/L"
#'
#' @param x Character vector of unit strings
#' @return Character vector of normalized unit strings
#' @keywords internal
normalize_unit_string <- function(x) {
  # (a) Trim whitespace

x <- trimws(x)

  # (b) Replace micro symbols with ASCII 'u'
  # U+00B5 = micro sign, U+03BC = Greek lowercase mu
  x <- gsub("\u00B5", "u", x, fixed = TRUE)
  x <- gsub("\u03BC", "u", x, fixed = TRUE)

  # (c) Collapse spaces around "/"
  x <- gsub("\\s*/\\s*", "/", x)

  x
}

#' Harmonize unit values using a conversion table
#'
#' Takes numeric values and their unit strings, performs lookup against a unit
#' conversion table, and returns harmonized values with audit trail.
#'
#' Lookup strategy:
#' 1. Normalize the input unit string (trim, micro symbols, spaces)
#' 2. Try case-sensitive exact match against unit_map$from_unit
#' 3. If no match, try case-insensitive fallback (with unit_flag = "case_fallback")
#' 4. If still no match, pass through unchanged (with unit_flag = "unmatched")
#'
#' @param values Numeric vector of parsed numeric values
#' @param units Character vector of unit strings (same length as values)
#' @param unit_map Tibble from load_unit_map() with columns: from_unit, to_unit, multiplier
#'
#' @return A tibble with columns:
#'   - orig_row_id: Integer linking back to input position
#'   - orig_unit: Original unit string before normalization
#'   - harmonized_value: Value after conversion (value * multiplier)
#'   - harmonized_unit: Target unit from table (or original if unmatched)
#'   - conversion_factor: Multiplier applied (1 for pass-through)
#'   - unit_flag: Status - "" (exact match), "case_fallback", or "unmatched"
#'
#' @examples
#' unit_map <- tibble::tibble(
#'   from_unit = c("mg/L", "ug/L"),
#'   to_unit = c("mg/L", "mg/L"),
#'   multiplier = c(1, 0.001)
#' )
#' harmonize_units(c(5, 10), c("ug/L", "mg/L"), unit_map)
#'
#' @importFrom tibble tibble
#' @export
harmonize_units <- function(values, units, unit_map) {
  # Step 1: Capture orig_unit before any transformation
  orig_unit <- units

  # Step 2: Assign orig_row_id
  n <- length(values)
  orig_row_id <- seq_len(n)

  # Step 3: Normalize unit strings
  normalized <- normalize_unit_string(units)

  # Prepare output vectors
  harmonized_value <- numeric(n)
  harmonized_unit <- character(n)
  conversion_factor <- numeric(n)
  unit_flag <- character(n)

  # Pre-compute lowercase versions for case-insensitive fallback
  map_from_lower <- tolower(unit_map$from_unit)

  # Step 4: Lookup for each row
  for (i in seq_len(n)) {
    norm_unit <- normalized[i]

    # (a) Case-sensitive exact match
    idx <- match(norm_unit, unit_map$from_unit)

    if (!is.na(idx)) {
      # Exact match found
      harmonized_unit[i] <- unit_map$to_unit[idx]
      conversion_factor[i] <- unit_map$multiplier[idx]
      unit_flag[i] <- ""
    } else {
      # (b) Case-insensitive fallback
      idx_ci <- match(tolower(norm_unit), map_from_lower)

      if (!is.na(idx_ci)) {
        # Case-insensitive match found
        harmonized_unit[i] <- unit_map$to_unit[idx_ci]
        conversion_factor[i] <- unit_map$multiplier[idx_ci]
        unit_flag[i] <- "case_fallback"
      } else {
        # (c) No match - pass through
        harmonized_unit[i] <- orig_unit[i]
        conversion_factor[i] <- 1
        unit_flag[i] <- "unmatched"
      }
    }
  }

  # Step 5: Compute harmonized_value = values * conversion_factor
  harmonized_value <- values * conversion_factor

  # Step 6: Build output tibble with columns in exact order (per D-07)
  tibble::tibble(
    orig_row_id = as.integer(orig_row_id),
    orig_unit = orig_unit,
    harmonized_value = harmonized_value,
    harmonized_unit = harmonized_unit,
    conversion_factor = conversion_factor,
    unit_flag = unit_flag
  )
}
