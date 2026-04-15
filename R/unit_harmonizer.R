# unit_harmonizer.R
# Unit harmonization engine: normalization, case-safe lookup, conversion arithmetic.
#
# Public API: harmonize_units()
# Internal helpers: normalize_unit_string(), is_molarity_unit(), get_molarity_scale(), etc.

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

# ---- Internal helpers for synonym loading ----

#' Load unit synonyms internally via system.file
#'
#' @return Tibble with synonym mappings or NULL if not found
#' @keywords internal
get_unit_synonyms <- function() {
  path <- system.file("extdata/unit_synonyms.rds", package = "chemreg")
  if (nzchar(path) && file.exists(path)) {
    readRDS(path)
  } else {
    NULL
  }
}

#' Apply synonym normalization to unit strings
#'
#' @param unit_strings Character vector of normalized unit strings
#' @param synonyms Tibble from get_unit_synonyms() or NULL
#' @return Character vector with synonyms applied
#' @keywords internal
apply_synonyms <- function(unit_strings, synonyms) {
  if (is.null(synonyms) || nrow(synonyms) == 0) return(unit_strings)

  result <- unit_strings
  for (i in seq_len(nrow(synonyms))) {
    pattern <- synonyms$input_pattern[i]
    replacement <- synonyms$normalized_unit[i]
    if (isTRUE(synonyms$is_regex[i])) {
      result <- gsub(pattern, replacement, result, ignore.case = TRUE)
    } else {
      # Exact match (case-insensitive)
      result <- ifelse(tolower(result) == tolower(pattern), replacement, result)
    }
  }
  result
}

# ---- Internal helpers for molarity conversion ----

#' Check if a unit is a molarity unit
#'
#' @param unit Character vector of unit strings (normalized)
#' @return Logical vector
#' @keywords internal
is_molarity_unit <- function(unit) {
  tolower(unit) %in% c("m", "mm", "um", "nm", "pm", "mol/l", "mmol/l", "umol/l", "nmol/l", "pmol/l")
}

#' Get molarity scale factor for conversion to mg/L
#'
#' Formula: mg/L = molarity * molecular_weight * scale_factor
#'
#' @param unit Character - the molarity unit
#' @return Numeric scale factor
#' @keywords internal
get_molarity_scale <- function(unit) {
  scales <- c(
    "m" = 1000, "mol/l" = 1000,        # M * MW * 1000 = mg/L
    "mm" = 1, "mmol/l" = 1,            # mM * MW = mg/L
    "um" = 0.001, "umol/l" = 0.001,    # uM * MW * 0.001 = mg/L
    "nm" = 1e-6, "nmol/l" = 1e-6,
    "pm" = 1e-9, "pmol/l" = 1e-9
 )
  scales[tolower(unit)]
}

#' Fetch molecular weight via ComptoxR API
#'
#' @param dtxsids Character vector of unique DTXSIDs
#' @return Named numeric vector (names = dtxsid, values = MW)
#' @keywords internal
fetch_molecular_weight <- function(dtxsids) {
  if (!requireNamespace("ComptoxR", quietly = TRUE)) {
    result <- rep(NA_real_, length(dtxsids))
    names(result) <- dtxsids
    return(result)
  }

  tryCatch({
    raw <- suppressMessages(ComptoxR::ct_chemical_detail_search_bulk(dtxsids))
    if (is.null(raw) || nrow(raw) == 0) {
      result <- rep(NA_real_, length(dtxsids))
      names(result) <- dtxsids
      return(result)
    }
    # Find MW column - may be "mol_weight" or "molecular_weight"
    mw_col <- intersect(c("mol_weight", "molecular_weight", "average_mass"), names(raw))
    if (length(mw_col) == 0) {
      result <- rep(NA_real_, length(dtxsids))
      names(result) <- dtxsids
      return(result)
    }
    mw_values <- raw[[mw_col[1]]][match(dtxsids, raw$dtxsid)]
    names(mw_values) <- dtxsids
    mw_values
  }, error = function(e) {
    result <- rep(NA_real_, length(dtxsids))
    names(result) <- dtxsids
    result
  })
}

# ---- Internal helpers for media-based routing ----

#' Get target unit for ppb/ppm based on media context
#'
#' @param unit Character - the unit string (should be ppb or ppm)
#' @param media Character - "aqueous", "air", "solid", or NULL
#' @return Character - target unit or NULL if not applicable
#' @keywords internal
get_media_target <- function(unit, media) {
  unit_lower <- tolower(unit)
  if (!(unit_lower %in% c("ppb", "ppm"))) {
    return(NULL)
  }

  # D-09: Default to aqueous when media context unknown
  if (is.null(media) || is.na(media) || media == "") {
    media <- "aqueous"
  }

  switch(media,
    "aqueous" = "mg/L",
    "air" = "mg/m3",
    "solid" = "mg/kg",
    "mg/L"  # default fallback
  )
}

#' Get conversion factor for ppb/ppm to target unit
#'
#' @param unit Character - ppb or ppm
#' @return Numeric conversion factor
#' @keywords internal
get_ppx_conversion_factor <- function(unit) {
  unit_lower <- tolower(unit)
  if (unit_lower == "ppb") {
    0.001  # ppb = ug/L = 0.001 mg/L (for aqueous; same ratio for others)
  } else if (unit_lower == "ppm") {
    1      # ppm = mg/L (for aqueous; same ratio for others)
  } else {
    1
  }
}

#' Harmonize unit values using a conversion table
#'
#' Takes numeric values and their unit strings, performs lookup against a unit
#' conversion table, and returns harmonized values with audit trail.
#'
#' Lookup strategy:
#' 1. Load synonyms internally via system.file() and apply normalization
#' 2. Apply normalize_unit_string() (trim, micro symbols, spaces)
#' 3. Check for molarity units - if detected and MW available, convert to mg/L
#' 4. Check for ppb/ppm - route based on media context
#' 5. Try case-sensitive exact match against unit_map$from_unit
#' 6. If no match, try case-insensitive fallback (with unit_flag = "case_fallback")
#' 7. If still no match, pass through unchanged (with unit_flag = "unmatched")
#'
#' @param values Numeric vector of parsed numeric values
#' @param units Character vector of unit strings (same length as values)
#' @param unit_map Tibble from load_unit_map() with columns: from_unit, to_unit, multiplier
#' @param media Optional character vector - media context for ppb/ppm routing.
#'   Values: "aqueous", "air", "solid", or NULL (defaults to aqueous per D-09)
#' @param dtxsid Optional character vector - DTXSIDs for MW lookup when molarity detected
#' @param molecular_weight Optional numeric vector - MW override (skips API call)
#'
#' @return A tibble with columns:
#'   - orig_row_id: Integer linking back to input position
#'   - orig_unit: Original unit string before normalization
#'   - harmonized_value: Value after conversion (value * multiplier)
#'   - harmonized_unit: Target unit from table (or original if unmatched)
#'   - conversion_factor: Multiplier applied (1 for pass-through)
#'   - unit_flag: Status - "" (exact match), "case_fallback", "unmatched",
#'                "needs_mw" (molarity without MW), "media_inferred" (ppb/ppm default media)
#'
#' @examples
#' unit_map <- tibble::tibble(
#'   from_unit = c("mg/L", "ug/L"),
#'   to_unit = c("mg/L", "mg/L"),
#'   multiplier = c(1, 0.001)
#' )
#' # Basic usage (backward compatible)
#' harmonize_units(c(5, 10), c("ug/L", "mg/L"), unit_map)
#'
#' # With molarity conversion
#' harmonize_units(c(1), c("mM"), unit_map, molecular_weight = c(100))
#'
#' # With media context for ppb/ppm
#' harmonize_units(c(10), c("ppb"), unit_map, media = c("aqueous"))
#'
#' @importFrom tibble tibble
#' @export
harmonize_units <- function(values, units, unit_map,
                            media = NULL,
                            dtxsid = NULL,
                            molecular_weight = NULL) {
  # Step 0: Capture orig_unit before any transformation
  orig_unit <- units

  # Step 1: Assign orig_row_id
  n <- length(values)
  orig_row_id <- seq_len(n)

  # Step 2: Load synonyms internally and apply
  synonyms <- get_unit_synonyms()

  # Step 3: Normalize unit strings (trim, micro symbols, spaces)
  normalized <- normalize_unit_string(units)

  # Step 4: Apply synonym normalization
  normalized <- apply_synonyms(normalized, synonyms)

  # Prepare output vectors
  harmonized_value <- numeric(n)
  harmonized_unit <- character(n)
  conversion_factor <- numeric(n)
  unit_flag <- character(n)

  # Pre-compute lowercase versions for case-insensitive fallback
  map_from_lower <- tolower(unit_map$from_unit)

  # Handle media parameter - expand to vector if scalar/NULL
  if (is.null(media)) {
    media_vec <- rep(NA_character_, n)
  } else if (length(media) == 1) {
    media_vec <- rep(media, n)
  } else {
    media_vec <- media
  }

  # Handle dtxsid parameter - expand to vector if scalar/NULL
  if (is.null(dtxsid)) {
    dtxsid_vec <- rep(NA_character_, n)
  } else if (length(dtxsid) == 1) {
    dtxsid_vec <- rep(dtxsid, n)
  } else {
    dtxsid_vec <- dtxsid
  }

  # Handle molecular_weight parameter - expand to vector if scalar/NULL
  if (is.null(molecular_weight)) {
    mw_vec <- rep(NA_real_, n)
  } else if (length(molecular_weight) == 1) {
    mw_vec <- rep(molecular_weight, n)
  } else {
    mw_vec <- molecular_weight
  }

  # Pre-fetch MW for rows that need it (molarity + dtxsid but no mw_override)
  molarity_mask <- is_molarity_unit(normalized)
  needs_api_lookup <- molarity_mask & !is.na(dtxsid_vec) & is.na(mw_vec)

  if (any(needs_api_lookup)) {
    unique_dtxsids <- unique(dtxsid_vec[needs_api_lookup])
    unique_dtxsids <- unique_dtxsids[!is.na(unique_dtxsids)]
    if (length(unique_dtxsids) > 0) {
      fetched_mw <- fetch_molecular_weight(unique_dtxsids)
      # Populate mw_vec for rows that needed API lookup
      for (i in which(needs_api_lookup)) {
        if (!is.na(dtxsid_vec[i]) && dtxsid_vec[i] %in% names(fetched_mw)) {
          mw_vec[i] <- fetched_mw[dtxsid_vec[i]]
        }
      }
    }
  }

  # Step 5: Lookup for each row
  for (i in seq_len(n)) {
    norm_unit <- normalized[i]

    # Check for molarity unit
    if (is_molarity_unit(norm_unit)) {
      mw <- mw_vec[i]
      if (!is.na(mw) && mw > 0) {
        # Convert molarity to mg/L
        scale <- get_molarity_scale(norm_unit)
        harmonized_value[i] <- values[i] * mw * scale
        harmonized_unit[i] <- "mg/L"
        conversion_factor[i] <- mw * scale
        unit_flag[i] <- ""
        next
      } else {
        # Molarity but no MW - flag and pass through
        harmonized_value[i] <- values[i]
        harmonized_unit[i] <- orig_unit[i]
        conversion_factor[i] <- 1
        unit_flag[i] <- "needs_mw"
        next
      }
    }

    # Check for ppb/ppm - media-dependent routing
    ppx_target <- get_media_target(norm_unit, media_vec[i])
    if (!is.null(ppx_target)) {
      ppx_factor <- get_ppx_conversion_factor(norm_unit)
      harmonized_value[i] <- values[i] * ppx_factor
      harmonized_unit[i] <- ppx_target
      conversion_factor[i] <- ppx_factor
      # Flag as media_inferred if media was NULL/NA (defaulted to aqueous)
      if (is.na(media_vec[i]) || media_vec[i] == "") {
        unit_flag[i] <- "media_inferred"
      } else {
        unit_flag[i] <- ""
      }
      next
    }

    # Standard table lookup
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

  # Step 6: Compute harmonized_value for standard lookups (molarity/ppx already set)
  # Only apply for rows not already processed by molarity or ppx logic
  standard_rows <- !(molarity_mask | sapply(seq_len(n), function(i) !is.null(get_media_target(normalized[i], media_vec[i]))))
  harmonized_value[standard_rows] <- values[standard_rows] * conversion_factor[standard_rows]

  # Step 7: Build output tibble with columns in exact order (per D-07)
  tibble::tibble(
    orig_row_id = as.integer(orig_row_id),
    orig_unit = orig_unit,
    harmonized_value = harmonized_value,
    harmonized_unit = harmonized_unit,
    conversion_factor = conversion_factor,
    unit_flag = unit_flag
  )
}
