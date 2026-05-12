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
  path <- system.file("extdata/unit_synonyms.rds", package = "concert")
  if (nzchar(path) && file.exists(path)) {
    readRDS(path)
  } else {
    NULL
  }
}

#' Apply synonym normalization to unit strings
#'
#' Performance: Split exact-match rules (hash lookup O(1)) from regex rules.
#' Only regex rules require per-rule gsub passes. (Codex optimization)
#'
#' @param unit_strings Character vector of normalized unit strings
#' @param synonyms Tibble from get_unit_synonyms() or NULL
#' @return Character vector with synonyms applied
#' @keywords internal
apply_synonyms <- function(unit_strings, synonyms) {
  if (is.null(synonyms) || nrow(synonyms) == 0) {
    return(unit_strings)
  }

  result <- unit_strings

  # Split rules into exact-match vs regex
  is_regex <- if ("is_regex" %in% names(synonyms)) {
    isTRUE(synonyms$is_regex) | synonyms$is_regex %in% c(TRUE, "TRUE", "true", 1)
  } else {
    rep(FALSE, nrow(synonyms))
  }

  exact_rules <- synonyms[!is_regex, , drop = FALSE]
  regex_rules <- synonyms[is_regex, , drop = FALSE]

  # ---- Exact-match: hash lookup O(n), not O(n*m) ----
  if (nrow(exact_rules) > 0) {
    # Build case-insensitive lookup hash
    lookup_hash <- stats::setNames(
      exact_rules$normalized_unit,
      tolower(exact_rules$input_pattern)
    )
    # Vectorized lookup
    result_lower <- tolower(result)
    matches <- lookup_hash[result_lower]
    matched_mask <- !is.na(matches)
    result[matched_mask] <- matches[matched_mask]
  }

  # ---- Regex rules: still need per-rule gsub, but smaller subset ----
  if (nrow(regex_rules) > 0) {
    for (i in seq_len(nrow(regex_rules))) {
      result <- gsub(
        regex_rules$input_pattern[i],
        regex_rules$normalized_unit[i],
        result,
        ignore.case = TRUE
      )
    }
  }

  result
}

# ---- Internal helpers for molarity conversion ----

#' Check if a unit is a molarity unit
#'
#' Case-sensitive for standalone "m"/"M": uppercase "M" is Molar; lowercase "m"
#' is ambiguous (minutes) and handled by the synonym table.  All other molarity
#' units (mm, um, nm, pm and their mol/L forms) are matched case-insensitively.
#'
#' @param unit Character vector of unit strings (normalized, pre-synonym)
#' @return Logical vector
#' @keywords internal
is_molarity_unit <- function(unit) {
  # Case-sensitive check for standalone M (Molar) vs m (minutes/ambiguous).
  # !is.na() guard prevents NA propagation when unit contains NA strings —
  # NA input should be FALSE (not molarity), consistent with %in% behavior.
  standalone_M <- !is.na(unit) & unit == "M"
  # Case-insensitive check for all other molarity units (%in% is already NA-safe)
  other_molarity <- tolower(unit) %in% c("mm", "um", "nm", "pm", "mol/l", "mmol/l", "umol/l", "nmol/l", "pmol/l")
  standalone_M | other_molarity
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
    "m" = 1000,
    "mol/l" = 1000, # M * MW * 1000 = mg/L
    "mm" = 1,
    "mmol/l" = 1, # mM * MW = mg/L
    "um" = 0.001,
    "umol/l" = 0.001, # uM * MW * 0.001 = mg/L
    "nm" = 1e-6,
    "nmol/l" = 1e-6,
    "pm" = 1e-9,
    "pmol/l" = 1e-9
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

  tryCatch(
    {
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
    },
    error = function(e) {
      result <- rep(NA_real_, length(dtxsids))
      names(result) <- dtxsids
      result
    }
  )
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

  switch(
    media,
    "aqueous" = "mg/L",
    "air" = "mg/m3",
    "solid" = "mg/kg",
    "mg/L" # default fallback
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
    0.001 # ppb = ug/L = 0.001 mg/L (for aqueous; same ratio for others)
  } else if (unit_lower == "ppm") {
    1 # ppm = mg/L (for aqueous; same ratio for others)
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
#' Performance: Vectorized implementation (Plan 34-04) - O(n) hash lookups instead
#' of O(n*m) per-row match() calls. Benchmarks: <1 sec for 128k rows vs 8+ sec prior.
#'
#' @param values Numeric vector of parsed numeric values
#' @param units Character vector of unit strings (same length as values)
#' @param unit_map Tibble from load_unit_map() with columns: from_unit, to_unit, multiplier
#' @param media Optional character vector - media context for ppb/ppm routing.
#'   Values: "aqueous", "air", "solid", or NULL (defaults to aqueous per D-09)
#' @param dtxsid Optional character vector - DTXSIDs for MW lookup when molarity detected
#' @param molecular_weight Optional numeric vector - MW override (skips API call)
#' @param use_dedup Logical. When TRUE (default), applies unit-key dedup
#'   optimization (Phase 37 D-07). Set to FALSE for benchmark baseline.
#' @param category Character or NULL. When non-NULL, filters unit_map to rows
#'   matching this category before conversion. Use "duration" for duration
#'   harmonization. Default NULL uses all rows (backward compatible).
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
harmonize_units <- function(
  values,
  units,
  unit_map,
  media = NULL,
  dtxsid = NULL,
  molecular_weight = NULL,
  use_dedup = TRUE,
  category = NULL
) {
  # Category filter (D-12): isolate conversion table to a single category
  if (!is.null(category)) {
    unit_map <- unit_map[unit_map$category == category, , drop = FALSE]
  }

  # Step 0: Handle empty input
  n <- length(values)
  if (n == 0) {
    return(tibble::tibble(
      orig_row_id = integer(0),
      orig_unit = character(0),
      harmonized_value = numeric(0),
      harmonized_unit = character(0),
      conversion_factor = numeric(0),
      unit_flag = character(0)
    ))
  }

  # Step 1: Capture orig_unit before any transformation
  orig_unit <- units

  # Step 2: Assign orig_row_id
  orig_row_id <- seq_len(n)

  # Step 3: Load synonyms internally and apply
  synonyms <- get_unit_synonyms()

  # Normalize unit strings (trim, micro symbols, spaces)
  normalized <- normalize_unit_string(units)

  # ---- Plan 34-04: Vectorized classification masks ----
  # Compute molarity mask BEFORE synonym application.  is_molarity_unit() is now
  # case-sensitive for standalone "M" vs "m" so that uppercase "M" (Molar) is
  # classified as molarity while lowercase "m" (ambiguous: minutes) is left for
  # the synonym table to map to "min".  We also keep a pre-synonym copy of
  # normalized so the molarity conversion path can look up the correct scale factor
  # (e.g. "M" -> 1000, "mM" -> 1) rather than the post-synonym string "min".
  normalized_pre_synonym <- normalized
  molarity_mask <- is_molarity_unit(normalized_pre_synonym)

  # Step 4: Apply synonym normalization (after molarity detection)
  normalized <- apply_synonyms(normalized, synonyms)

  # Initialize output vectors with default pass-through values
  harmonized_value <- values
  harmonized_unit <- orig_unit
  conversion_factor <- rep(1, n)
  unit_flag <- rep("", n)

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

  # Pre-compute remaining classification masks (after synonym application)
  # molarity_mask already computed above (pre-synonym)
  ppx_units <- c("ppb", "ppm", "ppt", "ppq")
  ppx_mask <- tolower(normalized) %in% ppx_units
  standard_mask <- !molarity_mask & !ppx_mask

  # Pre-fetch MW for rows that need it (molarity + dtxsid but no mw_override)
  # Must run before dedup key construction since mw_vec is used in molarity keys (D-07)
  needs_api_lookup <- molarity_mask & !is.na(dtxsid_vec) & is.na(mw_vec)

  if (any(needs_api_lookup)) {
    unique_dtxsids <- unique(dtxsid_vec[needs_api_lookup])
    unique_dtxsids <- unique_dtxsids[!is.na(unique_dtxsids)]
    if (length(unique_dtxsids) > 0) {
      fetched_mw <- fetch_molecular_weight(unique_dtxsids)
      # Vectorized MW assignment via match
      lookup_idx <- match(dtxsid_vec[needs_api_lookup], names(fetched_mw))
      mw_vec[needs_api_lookup] <- fetched_mw[lookup_idx]
    }
  }

  # ---- Phase 37: Unit-key dedup optimization (D-07) ----
  # Compute conversion factor once per distinct unit combination, then broadcast.
  # Key construction: unit string only for standard, paste(unit, media) for ppx,
  # paste(unit, mw) for molarity. Numeric values excluded from key (multiply is O(1)).

  # Phase 38: use_dedup toggle gates dedup key construction (BENCH-01)
  use_dedup_path <- FALSE
  if (use_dedup) {
    # Build dedup keys per classification
    dedup_keys <- character(n)
    dedup_keys[standard_mask] <- normalized[standard_mask]
    dedup_keys[ppx_mask] <- paste0(normalized[ppx_mask], "||", media_vec[ppx_mask])
    dedup_keys[molarity_mask] <- paste0(normalized[molarity_mask], "||", mw_vec[molarity_mask])

    unique_keys <- unique(dedup_keys)
    n_unique <- length(unique_keys)

    # Only apply dedup optimization if worthwhile (more than 2x duplication)
    use_dedup_path <- n_unique < n / 2
  }

  if (use_dedup_path) {
    # Map each unique key to its first occurrence index
    first_idx <- match(unique_keys, dedup_keys)

    # Prepare unique-subset vectors for the three conversion paths
    unique_normalized <- normalized[first_idx]
    unique_normalized_pre_synonym <- normalized_pre_synonym[first_idx]
    unique_media_vec <- media_vec[first_idx]
    unique_mw_vec <- mw_vec[first_idx]
    unique_values_dummy <- rep(1.0, n_unique) # dummy values; factors computed separately

    unique_molarity_mask <- molarity_mask[first_idx]
    unique_ppx_mask <- ppx_mask[first_idx]
    unique_standard_mask <- standard_mask[first_idx]

    # Initialize per-unique result vectors
    u_harmonized_unit <- orig_unit[first_idx]
    u_conversion_factor <- rep(1.0, n_unique)
    u_unit_flag <- rep("", n_unique)

    # ---- Unique-subset: molarity conversion ----
    mol_with_mw_u <- unique_molarity_mask & !is.na(unique_mw_vec) & unique_mw_vec > 0
    if (any(mol_with_mw_u)) {
      mol_scales_u <- vapply(
        unique_normalized_pre_synonym[mol_with_mw_u],
        get_molarity_scale,
        numeric(1)
      )
      u_harmonized_unit[mol_with_mw_u] <- "mg/L"
      u_conversion_factor[mol_with_mw_u] <- unique_mw_vec[mol_with_mw_u] * mol_scales_u
      u_unit_flag[mol_with_mw_u] <- ""
    }

    mol_no_mw_u <- unique_molarity_mask & (is.na(unique_mw_vec) | unique_mw_vec <= 0)
    if (any(mol_no_mw_u)) {
      u_unit_flag[mol_no_mw_u] <- "needs_mw"
    }

    # ---- Unique-subset: ppb/ppm conversion ----
    if (any(unique_ppx_mask)) {
      u_ppx_idx <- which(unique_ppx_mask)
      u_ppx_units <- unique_normalized[u_ppx_idx]
      u_ppx_media <- unique_media_vec[u_ppx_idx]

      u_ppx_factors <- vapply(u_ppx_units, get_ppx_conversion_factor, numeric(1))

      u_ppx_targets <- vapply(
        seq_along(u_ppx_idx),
        function(i) {
          get_media_target(u_ppx_units[i], u_ppx_media[i]) %||% "mg/L"
        },
        character(1)
      )

      u_harmonized_unit[u_ppx_idx] <- u_ppx_targets
      u_conversion_factor[u_ppx_idx] <- u_ppx_factors

      u_ppx_media_na <- is.na(u_ppx_media) | u_ppx_media == ""
      u_unit_flag[u_ppx_idx] <- ""
      u_unit_flag[u_ppx_idx[u_ppx_media_na]] <- "media_inferred"
    }

    # ---- Unique-subset: standard table lookup ----
    if (any(unique_standard_mask)) {
      u_lookup_hash <- stats::setNames(seq_len(nrow(unit_map)), unit_map$from_unit)
      u_lookup_hash_ci <- stats::setNames(
        seq_len(nrow(unit_map)),
        tolower(unit_map$from_unit)
      )

      u_std_units <- unique_normalized[unique_standard_mask]
      u_std_indices <- which(unique_standard_mask)

      u_lookup_idx <- u_lookup_hash[u_std_units]

      u_unmatched_local <- is.na(u_lookup_idx)
      if (any(u_unmatched_local)) {
        u_ci_lookup <- u_lookup_hash_ci[tolower(u_std_units[u_unmatched_local])]
        u_lookup_idx[u_unmatched_local] <- u_ci_lookup
        u_case_fallback_local <- u_unmatched_local & !is.na(u_lookup_idx)
        u_unit_flag[u_std_indices[u_case_fallback_local]] <- "case_fallback"
      }

      u_matched_local <- !is.na(u_lookup_idx)
      u_matched_global <- u_std_indices[u_matched_local]
      u_map_rows <- u_lookup_idx[u_matched_local]

      u_harmonized_unit[u_matched_global] <- unit_map$to_unit[u_map_rows]
      u_conversion_factor[u_matched_global] <- unit_map$multiplier[u_map_rows]

      u_still_unmatched_local <- is.na(u_lookup_idx)
      u_still_unmatched_global <- u_std_indices[u_still_unmatched_local]
      u_unit_flag[u_still_unmatched_global] <- "unmatched"
    }

    # Broadcast unique results back to all rows
    key_to_unique <- match(dedup_keys, unique_keys)
    stopifnot(!anyNA(key_to_unique)) # T-37-12: match is guaranteed (unique_keys derived from dedup_keys)
    harmonized_unit <- u_harmonized_unit[key_to_unique]
    conversion_factor <- u_conversion_factor[key_to_unique]
    unit_flag <- u_unit_flag[key_to_unique]

    # Compute harmonized_value via vectorized multiply (O(n), already optimal)
    harmonized_value <- values * conversion_factor

    # needs_mw rows must preserve original value (no conversion applied)
    harmonized_value[unit_flag == "needs_mw"] <- values[unit_flag == "needs_mw"]
  } else {
    # Not enough duplication -- run existing logic directly

    # ---- Handle molarity rows (vectorized where possible) ----

    # Molarity with valid MW -> convert to mg/L
    mol_with_mw <- molarity_mask & !is.na(mw_vec) & mw_vec > 0
    if (any(mol_with_mw)) {
      mol_scales <- vapply(
        normalized_pre_synonym[mol_with_mw],
        get_molarity_scale,
        numeric(1)
      )
      harmonized_value[mol_with_mw] <- values[mol_with_mw] * mw_vec[mol_with_mw] * mol_scales
      harmonized_unit[mol_with_mw] <- "mg/L"
      conversion_factor[mol_with_mw] <- mw_vec[mol_with_mw] * mol_scales
      unit_flag[mol_with_mw] <- ""
    }

    # Molarity without MW -> pass through with flag
    mol_no_mw <- molarity_mask & (is.na(mw_vec) | mw_vec <= 0)
    if (any(mol_no_mw)) {
      unit_flag[mol_no_mw] <- "needs_mw"
    }

    # ---- Handle ppb/ppm rows (vectorized) ----

    if (any(ppx_mask)) {
      # Pre-compute indices ONCE to avoid O(k²) which() calls (Codex fix)
      ppx_idx <- which(ppx_mask)
      ppx_units <- normalized[ppx_idx]
      ppx_media <- media_vec[ppx_idx]

      # Vectorized ppx conversion factors
      ppx_factors <- vapply(ppx_units, get_ppx_conversion_factor, numeric(1))

      # Vectorized media target lookup (now O(k), not O(k²))
      ppx_targets <- vapply(
        seq_along(ppx_idx),
        function(i) {
          get_media_target(ppx_units[i], ppx_media[i]) %||% "mg/L"
        },
        character(1)
      )

      harmonized_value[ppx_idx] <- values[ppx_idx] * ppx_factors
      harmonized_unit[ppx_idx] <- ppx_targets
      conversion_factor[ppx_idx] <- ppx_factors

      # Flag as media_inferred if media was NULL/NA
      ppx_media_na <- is.na(ppx_media) | ppx_media == ""
      unit_flag[ppx_idx] <- ""
      unit_flag[ppx_idx[ppx_media_na]] <- "media_inferred"
    }

    # ---- Handle standard table lookup (vectorized with hash) ----

    if (any(standard_mask)) {
      # Build hash maps once: from_unit -> row index (O(m), not O(n*m))
      lookup_hash <- stats::setNames(seq_len(nrow(unit_map)), unit_map$from_unit)
      lookup_hash_ci <- stats::setNames(
        seq_len(nrow(unit_map)),
        tolower(unit_map$from_unit)
      )

      # Extract units for standard rows
      std_units <- normalized[standard_mask]
      std_indices <- which(standard_mask)

      # Vectorized case-sensitive lookup (O(n))
      lookup_idx <- lookup_hash[std_units]

      # Case-insensitive fallback for unmatched
      unmatched_local <- is.na(lookup_idx)
      if (any(unmatched_local)) {
        ci_lookup <- lookup_hash_ci[tolower(std_units[unmatched_local])]
        lookup_idx[unmatched_local] <- ci_lookup
        # Mark case fallbacks
        case_fallback_local <- unmatched_local & !is.na(lookup_idx)
        unit_flag[std_indices[case_fallback_local]] <- "case_fallback"
      }

      # Apply matched lookups (vectorized assignment)
      matched_local <- !is.na(lookup_idx)
      matched_global <- std_indices[matched_local]
      map_rows <- lookup_idx[matched_local]

      harmonized_unit[matched_global] <- unit_map$to_unit[map_rows]
      conversion_factor[matched_global] <- unit_map$multiplier[map_rows]
      harmonized_value[matched_global] <- values[matched_global] * conversion_factor[matched_global]

      # Handle truly unmatched (pass through with flag)
      still_unmatched_local <- is.na(lookup_idx)
      still_unmatched_global <- std_indices[still_unmatched_local]
      unit_flag[still_unmatched_global] <- "unmatched"
    }
  } # end dedup if/else

  # Flag ambiguous original units (D-01): "m" could be minutes or months.
  # Only flag rows that went through the standard table path (not molarity or ppb/ppm),
  # so that "M" (molarity) does not get incorrectly overwritten.
  ambiguous_originals <- c("m")
  ambiguous_mask <- trimws(tolower(orig_unit)) %in% ambiguous_originals & !molarity_mask & !ppx_mask
  if (any(ambiguous_mask)) {
    unit_flag[ambiguous_mask] <- "ambiguous_unit"
  }

  # Build output tibble with columns in exact order (per D-07)
  tibble::tibble(
    orig_row_id = as.integer(orig_row_id),
    orig_unit = orig_unit,
    harmonized_value = harmonized_value,
    harmonized_unit = harmonized_unit,
    conversion_factor = conversion_factor,
    unit_flag = unit_flag
  )
}
