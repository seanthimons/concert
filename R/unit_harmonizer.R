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
  x <- gsub("\\bmug\\b", "ug", x, ignore.case = TRUE)

  # (c) Collapse spaces around "/"
  x <- gsub("\\s*/\\s*", "/", x)

  x
}

# ---- Internal helpers for synonym loading ----

default_unit_synonyms <- function() {
  tibble::tibble(
    input_pattern = c(
      "mg/kg-bw/day",
      "mg/kg-day",
      "ug/kg-bw/day",
      "ug/kg-day",
      "hrs",
      "days",
      "m"
    ),
    normalized_unit = c(
      "mg/kg/d",
      "mg/kg/d",
      "ug/kg/d",
      "ug/kg/d",
      "hr",
      "day",
      "min"
    ),
    is_regex = rep(FALSE, 7L),
    notes = c(
      "body weight qualifier",
      "dose denominator separator",
      "body weight qualifier",
      "dose denominator separator",
      "duration plural",
      "duration plural",
      "ambiguous duration shorthand"
    )
  )
}

#' Load unit synonyms internally via system.file
#'
#' @return Tibble with synonym mappings or NULL if not found
#' @keywords internal
get_unit_synonyms <- function() {
  candidates <- c(
    system.file("extdata/unit_synonyms.rds", package = "concert"),
    file.path("inst", "extdata", "unit_synonyms.rds"),
    file.path(getwd(), "inst", "extdata", "unit_synonyms.rds"),
    file.path("..", "..", "inst", "extdata", "unit_synonyms.rds"),
    file.path(getwd(), "..", "..", "inst", "extdata", "unit_synonyms.rds"),
    file.path("inst", "extdata", "reference_cache", "unit_synonyms.rds"),
    file.path(getwd(), "inst", "extdata", "reference_cache", "unit_synonyms.rds"),
    file.path("..", "..", "inst", "extdata", "reference_cache", "unit_synonyms.rds"),
    file.path(getwd(), "..", "..", "inst", "extdata", "reference_cache", "unit_synonyms.rds")
  )
  candidates <- unique(candidates[nzchar(candidates)])
  path <- candidates[file.exists(candidates)][1]
  loaded <- if (!is.na(path) && nzchar(path)) {
    readRDS(path)
  } else {
    NULL
  }
  fallback <- default_unit_synonyms()
  if (is.null(loaded) || nrow(loaded) == 0) {
    return(fallback)
  }
  synonyms <- dplyr::bind_rows(loaded, fallback)
  synonym_key <- paste(tolower(synonyms$input_pattern), synonyms$is_regex, sep = "\r")
  synonyms[!duplicated(synonym_key), , drop = FALSE]
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
#' Molarity symbols are case-sensitive so lowercase length symbols cannot be
#' reinterpreted as scientific concentration units.
#'
#' @param unit Character vector of unit strings (normalized, pre-synonym)
#' @return Logical vector
#' @keywords internal
is_molarity_unit <- function(unit) {
  unit %in% c(
    "M",
    "mM",
    "uM",
    "nM",
    "pM",
    "mol/L",
    "mmol/L",
    "umol/L",
    "nmol/L",
    "pmol/L"
  )
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
    "M" = 1000,
    "mol/L" = 1000, # M * MW * 1000 = mg/L
    "mM" = 1,
    "mmol/L" = 1, # mM * MW = mg/L
    "uM" = 0.001,
    "umol/L" = 0.001, # uM * MW * 0.001 = mg/L
    "nM" = 1e-6,
    "nmol/L" = 1e-6,
    "pM" = 1e-9,
    "pmol/L" = 1e-9
  )
  scales[unit]
}

molarity_casefold_keys <- function() {
  tolower(c(
    "M",
    "mM",
    "uM",
    "nM",
    "pM",
    "mol/L",
    "mmol/L",
    "umol/L",
    "nmol/L",
    "pmol/L"
  ))
}

#' Fetch molecular weight via ComptoxR API
#'
#' @param dtxsids Character vector of unique DTXSIDs
#' @return List containing named numeric `values` and named logical
#'   `lookup_failed` vectors.
#' @keywords internal
fetch_molecular_weight <- function(dtxsids) {
  empty_result <- function(lookup_failed = TRUE) {
    values <- stats::setNames(rep(NA_real_, length(dtxsids)), dtxsids)
    failures <- stats::setNames(rep(lookup_failed, length(dtxsids)), dtxsids)
    list(values = values, lookup_failed = failures)
  }

  if (!requireNamespace("ComptoxR", quietly = TRUE)) {
    return(empty_result())
  }

  tryCatch(
    {
      raw <- suppressMessages(ComptoxR::ct_chemical_detail_search_bulk(dtxsids))
      if (!is.data.frame(raw) || nrow(raw) == 0) {
        return(empty_result())
      }

      mw_col <- intersect(
        c("molecularWeight", "mol_weight", "molecular_weight", "average_mass"),
        names(raw)
      )
      if (!("dtxsid" %in% names(raw)) || length(mw_col) == 0) {
        return(empty_result())
      }

      response_rows <- match(dtxsids, raw$dtxsid)
      returned <- !is.na(response_rows)
      result <- empty_result()
      result$lookup_failed[returned] <- FALSE
      result$values[returned] <- suppressWarnings(
        as.numeric(raw[[mw_col[1]]][response_rows[returned]])
      )
      result
    },
    error = function(e) empty_result()
  )
}

# ---- Internal helpers for media-based routing ----

#' Get target unit for ppb/ppm based on media context
#'
#' @param unit Character - the unit string (should be ppb or ppm)
#' @param media Character - "aqueous", "air", "solid", or NULL
#' @return Character target, `NA_character_` when air needs gas context, or NULL
#'   when media is unknown/not applicable.
#' @keywords internal
get_media_target <- function(unit, media) {
  unit_lower <- tolower(unit)
  if (!(unit_lower %in% c("ppb", "ppm"))) {
    return(NULL)
  }

  # Media routing is only safe when the upstream media resolver produced an
  # explicit category. Unknown media must not silently become aqueous.
  if (is.null(media) || is.na(media) || media == "") {
    return(NULL)
  }

  switch(
    media,
    "aqueous" = "mg/L",
    "air" = NA_character_,
    "solid" = "mg/kg",
    NULL
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
    0.001 # ppb = ug/L = 0.001 mg/L (for aqueous/solid/air media routing)
  } else if (unit_lower == "ppm") {
    1 # ppm = mg/L (for aqueous/solid/air media routing)
  } else {
    1
  }
}

normalize_unit_map_schema <- function(unit_map) {
  if (is.null(unit_map) || nrow(unit_map) == 0) {
    return(unit_map)
  }

  if (!"offset" %in% names(unit_map)) {
    unit_map$offset <- rep(0, nrow(unit_map))
  }
  unit_map$offset <- as.numeric(unit_map$offset)
  unit_map$offset[is.na(unit_map$offset)] <- 0

  inferred_type <- ifelse(unit_map$offset == 0, "linear", "affine")
  if (!"conversion_type" %in% names(unit_map)) {
    unit_map$conversion_type <- inferred_type
  } else {
    unit_map$conversion_type <- as.character(unit_map$conversion_type)
    missing_type <- is.na(unit_map$conversion_type) | unit_map$conversion_type == ""
    unit_map$conversion_type[missing_type] <- inferred_type[missing_type]
    invalid_type <- !unit_map$conversion_type %in% c("linear", "affine")
    unit_map$conversion_type[invalid_type] <- inferred_type[invalid_type]
  }

  unit_map$conversion_type[unit_map$offset != 0] <- "affine"
  unit_map
}

build_case_fallback_metadata <- function(unit_map) {
  if (is.null(unit_map) || nrow(unit_map) == 0) {
    return(tibble::tibble(
      key = character(0),
      unambiguous = logical(0)
    ))
  }

  keys <- tolower(unit_map$from_unit)
  grouped_rows <- split(seq_len(nrow(unit_map)), keys)
  unambiguous <- vapply(
    grouped_rows,
    function(rows) {
      first <- rows[1]
      same_tuple <- vapply(
        rows,
        function(row) {
          identical(unit_map$to_unit[row], unit_map$to_unit[first]) &&
            identical(unit_map$multiplier[row], unit_map$multiplier[first]) &&
            identical(unit_map$offset[row], unit_map$offset[first])
        },
        logical(1)
      )
      all(same_tuple) && !(keys[first] %in% molarity_casefold_keys())
    },
    logical(1)
  )

  tibble::tibble(
    key = names(grouped_rows),
    unambiguous = unname(unambiguous)
  )
}

resolve_case_fallback <- function(units, unit_map, case_fallback_metadata) {
  keys <- tolower(units)
  candidate <- match(keys, tolower(unit_map$from_unit))
  metadata_idx <- match(keys, case_fallback_metadata$key)
  safe <- !is.na(candidate) &
    !is.na(metadata_idx) &
    case_fallback_metadata$unambiguous[metadata_idx]

  list(
    map_index = ifelse(safe, candidate, NA_integer_),
    ambiguous = !is.na(candidate) & !safe
  )
}

lookup_unit_mapping <- function(unit, unit_map, case_fallback_metadata = NULL) {
  exact_idx <- match(unit, unit_map$from_unit)
  if (!is.na(exact_idx)) {
    return(list(
      to_unit = unit_map$to_unit[exact_idx],
      multiplier = unit_map$multiplier[exact_idx],
      offset = unit_map$offset[exact_idx],
      flag = ""
    ))
  }

  if (is.null(case_fallback_metadata)) {
    case_fallback_metadata <- build_case_fallback_metadata(unit_map)
  }
  fallback <- resolve_case_fallback(unit, unit_map, case_fallback_metadata)
  if (fallback$ambiguous) {
    return(list(to_unit = unit, multiplier = 1, offset = 0, flag = "ambiguous_unit"))
  }
  ci_idx <- fallback$map_index
  if (!is.na(ci_idx)) {
    return(list(
      to_unit = unit_map$to_unit[ci_idx],
      multiplier = unit_map$multiplier[ci_idx],
      offset = unit_map$offset[ci_idx],
      flag = "case_fallback"
    ))
  }

  list(to_unit = unit, multiplier = 1, offset = 0, flag = "unmatched")
}

validate_harmonize_vector_lengths <- function(values, units, media, dtxsid, molecular_weight) {
  expected <- length(values)
  actual_units <- length(units)
  if (actual_units != expected) {
    stop(
      sprintf("`units` must have length %d; got length %d.", expected, actual_units),
      call. = FALSE
    )
  }

  optional <- list(
    media = media,
    dtxsid = dtxsid,
    molecular_weight = molecular_weight
  )
  for (argument in names(optional)) {
    value <- optional[[argument]]
    actual <- length(value)
    if (!is.null(value) && !(actual %in% c(1L, expected))) {
      stop(
        sprintf(
          "`%s` must be NULL, length 1, or length %d; got length %d.",
          argument,
          expected,
          actual
        ),
        call. = FALSE
      )
    }
  }

  invisible(NULL)
}

#' Harmonize unit values using a conversion table
#'
#' Takes numeric values and their unit strings, performs lookup against a unit
#' conversion table, and returns harmonized values with audit trail.
#'
#' Lookup strategy:
#' 1. Validate vector lengths before normalization or external lookup.
#' 2. Preserve missing-like units (`NA`, empty, or whitespace-only) as `absent`.
#' 3. Load synonyms internally and normalize whitespace and micro symbols.
#' 4. Recognize molarity only with exact scientific casing: `M`, `mM`, `uM`,
#'    `nM`, `pM`, and the corresponding correctly cased `mol/L` forms.
#' 5. Route aqueous and solid `ppb`/`ppm` by media. Air values pass through
#'    with `needs_context` because gas conversion also needs MW, temperature,
#'    and pressure.
#' 6. Prefer case-sensitive exact matches against `unit_map$from_unit`.
#' 7. Use case-insensitive fallback only when every complete-map match has the
#'    same target, multiplier, and offset. Ambiguous fallback passes through.
#' 8. Pass unmatched units through unchanged.
#'
#' Performance: Vectorized implementation (Plan 34-04) - O(n) hash lookups instead
#' of O(n*m) per-row match() calls. Benchmarks: <1 sec for 128k rows vs 8+ sec prior.
#'
#' @param values Numeric vector of parsed numeric values.
#' @param units Character vector of unit strings. Must have exactly the same
#'   length as `values`.
#' @param unit_map Tibble from load_unit_map() with columns: from_unit, to_unit, multiplier
#' @param media Optional character vector - media context for ppb/ppm routing.
#'   Must be `NULL`, scalar, or the same length as `values`. Values are
#'   "aqueous", "air", "solid", or `NULL`. Unknown media falls back to the unit
#'   map instead of assuming aqueous. Air `ppb`/`ppm` is not converted.
#' @param dtxsid Optional character vector of DTXSIDs for MW lookup when
#'   molarity is detected. Must be `NULL`, scalar, or the same length as
#'   `values`.
#' @param molecular_weight Optional numeric MW override, which skips API lookup.
#'   Must be `NULL`, scalar, or the same length as `values`.
#' @param use_dedup Logical. When TRUE (default), applies unit-key dedup
#'   optimization (Phase 37 D-07). Set to FALSE for benchmark baseline.
#' @param category Character or NULL. When non-NULL, filters unit_map to rows
#'   matching this category before conversion. Use "duration" for duration
#'   harmonization. Default NULL uses all rows (backward compatible).
#'
#' @return A tibble with columns:
#'   - orig_row_id: Integer linking back to input position
#'   - orig_unit: Original unit string before normalization
#'   - harmonized_value: Value after conversion (value * multiplier + offset)
#'   - harmonized_unit: Target unit from table, original unit for unsafe or
#'     unresolved pass-through, or `NA` for absent units
#'   - conversion_factor: Multiplier applied (1 for pass-through)
#'   - unit_flag: Status. `""` indicates an exact success; `case_fallback`
#'     indicates an unambiguous case-insensitive success; `unmatched`,
#'     `ambiguous_unit`, `absent`, `needs_context`, `needs_mw`, and
#'     `mw_lookup_failed` identify pass-through states requiring no conversion
#'     or further review. A successful MW lookup that returns a missing MW uses
#'     `needs_mw`; package, API, response-schema, and requested-row failures use
#'     `mw_lookup_failed`.
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
  n <- length(values)
  validate_harmonize_vector_lengths(values, units, media, dtxsid, molecular_weight)

  unit_map <- normalize_unit_map_schema(unit_map)
  case_fallback_metadata <- build_case_fallback_metadata(unit_map)

  # Category filter (D-12): isolate conversion table to a single category
  if (!is.null(category)) {
    unit_map <- unit_map[unit_map$category == category, , drop = FALSE]
  }

  # Step 0: Handle empty input
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

  # Step 1: Capture orig_unit and missing-like cells before any transformation.
  orig_unit <- as.character(units)
  absent_mask <- is.na(orig_unit) | !nzchar(trimws(orig_unit))

  # Step 2: Assign orig_row_id
  orig_row_id <- seq_len(n)

  # Step 3: Load synonyms internally and apply
  synonyms <- get_unit_synonyms()

  # Normalize unit strings (trim, micro symbols, spaces)
  normalized <- orig_unit
  normalized[!absent_mask] <- normalize_unit_string(orig_unit[!absent_mask])

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
  conversion_offset <- rep(0, n)
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
  mw_lookup_failed <- rep(FALSE, n)

  # Pre-compute remaining classification masks (after synonym application)
  # molarity_mask already computed above (pre-synonym)
  ppx_units <- c("ppb", "ppm", "ppt", "ppq")
  ppx_mask <- tolower(normalized) %in% ppx_units
  standard_mask <- !absent_mask & !molarity_mask & !ppx_mask

  # Pre-fetch MW for rows that need it (molarity + dtxsid but no mw_override)
  # Must run before dedup key construction since mw_vec is used in molarity keys (D-07)
  needs_api_lookup <- molarity_mask & !is.na(dtxsid_vec) & is.na(mw_vec)

  if (any(needs_api_lookup)) {
    unique_dtxsids <- unique(dtxsid_vec[needs_api_lookup])
    unique_dtxsids <- unique_dtxsids[!is.na(unique_dtxsids)]
    if (length(unique_dtxsids) > 0) {
      fetched_mw <- fetch_molecular_weight(unique_dtxsids)
      # Vectorized MW assignment via match
      lookup_idx <- match(dtxsid_vec[needs_api_lookup], names(fetched_mw$values))
      mw_vec[needs_api_lookup] <- fetched_mw$values[lookup_idx]
      mw_lookup_failed[needs_api_lookup] <- fetched_mw$lookup_failed[lookup_idx]
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
    dedup_keys[molarity_mask] <- paste0(
      normalized[molarity_mask],
      "||",
      mw_vec[molarity_mask],
      "||",
      mw_lookup_failed[molarity_mask]
    )

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
    unique_mw_lookup_failed <- mw_lookup_failed[first_idx]
    unique_values_dummy <- rep(1.0, n_unique) # dummy values; factors computed separately

    unique_molarity_mask <- molarity_mask[first_idx]
    unique_ppx_mask <- ppx_mask[first_idx]
    unique_standard_mask <- standard_mask[first_idx]

    # Initialize per-unique result vectors
    u_harmonized_unit <- orig_unit[first_idx]
    u_conversion_factor <- rep(1.0, n_unique)
    u_conversion_offset <- rep(0.0, n_unique)
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
      u_unit_flag[mol_no_mw_u & unique_mw_lookup_failed] <- "mw_lookup_failed"
    }

    # ---- Unique-subset: ppb/ppm conversion ----
    if (any(unique_ppx_mask)) {
      u_ppx_idx <- which(unique_ppx_mask)
      u_ppx_units <- unique_normalized[u_ppx_idx]
      u_ppx_media <- unique_media_vec[u_ppx_idx]

      u_ppx_targets <- character(length(u_ppx_idx))
      u_ppx_factors <- numeric(length(u_ppx_idx))
      u_ppx_offsets <- numeric(length(u_ppx_idx))
      u_ppx_flags <- character(length(u_ppx_idx))
      for (i in seq_along(u_ppx_idx)) {
        media_target <- get_media_target(u_ppx_units[i], u_ppx_media[i])
        if (!is.null(media_target) && is.na(media_target)) {
          u_ppx_targets[i] <- orig_unit[first_idx[u_ppx_idx[i]]]
          u_ppx_factors[i] <- 1
          u_ppx_offsets[i] <- 0
          u_ppx_flags[i] <- "needs_context"
        } else if (is.null(media_target)) {
          mapped <- lookup_unit_mapping(
            u_ppx_units[i],
            unit_map,
            case_fallback_metadata
          )
          u_ppx_targets[i] <- mapped$to_unit
          u_ppx_factors[i] <- mapped$multiplier
          u_ppx_offsets[i] <- mapped$offset
          u_ppx_flags[i] <- mapped$flag
        } else {
          u_ppx_targets[i] <- media_target
          u_ppx_factors[i] <- get_ppx_conversion_factor(u_ppx_units[i])
          u_ppx_offsets[i] <- 0
          u_ppx_flags[i] <- ""
        }
      }

      u_harmonized_unit[u_ppx_idx] <- u_ppx_targets
      u_conversion_factor[u_ppx_idx] <- u_ppx_factors
      u_conversion_offset[u_ppx_idx] <- u_ppx_offsets
      u_unit_flag[u_ppx_idx] <- u_ppx_flags
    }

    # ---- Unique-subset: standard table lookup ----
    if (any(unique_standard_mask)) {
      u_lookup_hash <- stats::setNames(seq_len(nrow(unit_map)), unit_map$from_unit)

      u_std_units <- unique_normalized[unique_standard_mask]
      u_std_indices <- which(unique_standard_mask)

      u_lookup_idx <- u_lookup_hash[u_std_units]

      u_unmatched_local <- is.na(u_lookup_idx)
      if (any(u_unmatched_local)) {
        u_fallback <- resolve_case_fallback(
          u_std_units[u_unmatched_local],
          unit_map,
          case_fallback_metadata
        )
        u_unmatched_indices <- which(u_unmatched_local)
        u_unit_flag[u_std_indices[u_unmatched_indices[u_fallback$ambiguous]]] <- "ambiguous_unit"
        u_lookup_idx[u_unmatched_local] <- u_fallback$map_index
        u_case_fallback_local <- u_unmatched_local & !is.na(u_lookup_idx)
        u_unit_flag[u_std_indices[u_case_fallback_local]] <- "case_fallback"
      }

      u_matched_local <- !is.na(u_lookup_idx)
      u_matched_global <- u_std_indices[u_matched_local]
      u_map_rows <- u_lookup_idx[u_matched_local]

      u_harmonized_unit[u_matched_global] <- unit_map$to_unit[u_map_rows]
      u_conversion_factor[u_matched_global] <- unit_map$multiplier[u_map_rows]
      u_conversion_offset[u_matched_global] <- unit_map$offset[u_map_rows]

      u_still_unmatched_local <- is.na(u_lookup_idx)
      u_still_unmatched_global <- u_std_indices[u_still_unmatched_local]
      u_unresolved_flag <- u_unit_flag[u_still_unmatched_global]
      u_unit_flag[u_still_unmatched_global[u_unresolved_flag == ""]] <- "unmatched"
    }

    # Broadcast unique results back to all rows
    key_to_unique <- match(dedup_keys, unique_keys)
    stopifnot(!anyNA(key_to_unique)) # T-37-12: match is guaranteed (unique_keys derived from dedup_keys)
    harmonized_unit <- u_harmonized_unit[key_to_unique]
    conversion_factor <- u_conversion_factor[key_to_unique]
    conversion_offset <- u_conversion_offset[key_to_unique]
    unit_flag <- u_unit_flag[key_to_unique]

    # Compute harmonized_value via vectorized affine conversion (O(n)).
    harmonized_value <- values * conversion_factor + conversion_offset

    # Missing or failed MW rows must preserve original value (no conversion applied)
    mw_passthrough <- unit_flag %in% c("needs_mw", "mw_lookup_failed")
    harmonized_value[mw_passthrough] <- values[mw_passthrough]
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
      unit_flag[mol_no_mw & mw_lookup_failed] <- "mw_lookup_failed"
    }

    # ---- Handle ppb/ppm rows (vectorized) ----

    if (any(ppx_mask)) {
      # Pre-compute indices ONCE to avoid O(k^2) which() calls (Codex fix)
      ppx_idx <- which(ppx_mask)
      ppx_units <- normalized[ppx_idx]
      ppx_media <- media_vec[ppx_idx]

      ppx_targets <- character(length(ppx_idx))
      ppx_factors <- numeric(length(ppx_idx))
      ppx_offsets <- numeric(length(ppx_idx))
      ppx_flags <- character(length(ppx_idx))
      for (i in seq_along(ppx_idx)) {
        media_target <- get_media_target(ppx_units[i], ppx_media[i])
        if (!is.null(media_target) && is.na(media_target)) {
          ppx_targets[i] <- orig_unit[ppx_idx[i]]
          ppx_factors[i] <- 1
          ppx_offsets[i] <- 0
          ppx_flags[i] <- "needs_context"
        } else if (is.null(media_target)) {
          mapped <- lookup_unit_mapping(
            ppx_units[i],
            unit_map,
            case_fallback_metadata
          )
          ppx_targets[i] <- mapped$to_unit
          ppx_factors[i] <- mapped$multiplier
          ppx_offsets[i] <- mapped$offset
          ppx_flags[i] <- mapped$flag
        } else {
          ppx_targets[i] <- media_target
          ppx_factors[i] <- get_ppx_conversion_factor(ppx_units[i])
          ppx_offsets[i] <- 0
          ppx_flags[i] <- ""
        }
      }

      harmonized_value[ppx_idx] <- values[ppx_idx] * ppx_factors + ppx_offsets
      harmonized_unit[ppx_idx] <- ppx_targets
      conversion_factor[ppx_idx] <- ppx_factors
      conversion_offset[ppx_idx] <- ppx_offsets
      unit_flag[ppx_idx] <- ppx_flags
    }

    # ---- Handle standard table lookup (vectorized with hash) ----

    if (any(standard_mask)) {
      # Build hash maps once: from_unit -> row index (O(m), not O(n*m))
      lookup_hash <- stats::setNames(seq_len(nrow(unit_map)), unit_map$from_unit)

      # Extract units for standard rows
      std_units <- normalized[standard_mask]
      std_indices <- which(standard_mask)

      # Vectorized case-sensitive lookup (O(n))
      lookup_idx <- lookup_hash[std_units]

      # Case-insensitive fallback for unmatched
      unmatched_local <- is.na(lookup_idx)
      if (any(unmatched_local)) {
        fallback <- resolve_case_fallback(
          std_units[unmatched_local],
          unit_map,
          case_fallback_metadata
        )
        unmatched_indices <- which(unmatched_local)
        unit_flag[std_indices[unmatched_indices[fallback$ambiguous]]] <- "ambiguous_unit"
        lookup_idx[unmatched_local] <- fallback$map_index
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
      conversion_offset[matched_global] <- unit_map$offset[map_rows]
      harmonized_value[matched_global] <-
        values[matched_global] * conversion_factor[matched_global] + conversion_offset[matched_global]

      # Handle truly unmatched (pass through with flag)
      still_unmatched_local <- is.na(lookup_idx)
      still_unmatched_global <- std_indices[still_unmatched_local]
      unresolved_flag <- unit_flag[still_unmatched_global]
      unit_flag[still_unmatched_global[unresolved_flag == ""]] <- "unmatched"
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

  harmonized_value[absent_mask] <- values[absent_mask]
  harmonized_unit[absent_mask] <- NA_character_
  conversion_factor[absent_mask] <- 1
  unit_flag[absent_mask] <- "absent"

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
