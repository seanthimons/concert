# cleaning_reference.R
# Reference list loaders with local disk caching
#
# Functions for loading stop words, block patterns, and functional categories.
# Uses local RDS cache to avoid repeated API calls or slow initialization.
# ComptoxR is used for functional categories when available.

#' Generic cache-or-fetch function
#'
#' Checks if cache file exists. If yes, reads from disk. If no, calls fetch_fn,
#' creates directory structure, saves result to disk, and returns result.
#'
#' @param cache_path Full path to cache file (e.g., "data/reference_cache/stop_words.rds")
#' @param fetch_fn Function that fetches/generates the data when cache missing
#' @param name Human-readable name for logging
#' @return Data returned by fetch_fn (or read from cache)
#'
#' @examples
#' load_or_fetch_reference("cache/data.rds", function() c("a", "b"), "test_data")
#' @export
load_or_fetch_reference <- function(cache_path, fetch_fn, name) {
  if (file.exists(cache_path)) {
    message(sprintf("Loading %s from cache: %s", name, cache_path))
    return(readRDS(cache_path))
  }

  message(sprintf("Fetching %s (cache not found)...", name))
  result <- fetch_fn()

  # Create directory if it doesn't exist
  fs::dir_create(dirname(cache_path), recurse = TRUE)

  # Save to cache
  saveRDS(result, cache_path, compress = FALSE)
  message(sprintf("Cached %s to: %s", name, cache_path))

  return(result)
}

#' Resolve the default bundled reference cache directory
#'
#' Prefer installed package data. When running the Shiny app from a source
#' checkout, system.file() may be empty, so fall back to inst/extdata/reference_cache
#' before allowing data/reference_cache to be created with minimal fallback data.
#'
#' @param cache_dir Optional explicit cache directory
#' @return Character path to a reference cache directory
#' @keywords internal
resolve_reference_cache_dir <- function(cache_dir = NULL) {
  if (!is.null(cache_dir) && nzchar(cache_dir)) {
    return(cache_dir)
  }

  installed_cache <- system.file("extdata", "reference_cache", package = "concert")
  candidates <- c(
    installed_cache,
    file.path("inst", "extdata", "reference_cache"),
    file.path(getwd(), "inst", "extdata", "reference_cache"),
    file.path("..", "..", "inst", "extdata", "reference_cache"),
    file.path(getwd(), "..", "..", "inst", "extdata", "reference_cache"),
    file.path("data", "reference_cache")
  )
  candidates <- unique(candidates[nzchar(candidates)])

  existing <- candidates[dir.exists(candidates)]
  if (length(existing) > 0) {
    return(existing[1])
  }

  file.path("data", "reference_cache")
}

#' Load stop words list
#'
#' Returns a tibble of chemistry-specific stop words with provenance tracking.
#' These are domain knowledge defaults, not ComptoxR-seeded.
#'
#' Stop words are terms that indicate placeholder/test entries:
#' - test, sample, unknown, blank, standard, control, reference
#' - placeholder, tbd, tba
#' - na, n/a, none, not available, not applicable
#'
#' NOTE: Cache format changed in Phase 13 - delete existing cache files if needed.
#'
#' @param cache_dir Directory for cache files (e.g., "data/reference_cache")
#' @return Tibble with columns: term, source, active
#' @export
load_stop_words <- function(cache_dir) {
  cache_path <- file.path(cache_dir, "stop_words.rds")

  fetch_fn <- function() {
    tibble::tibble(
      term = c(
        "test",
        "sample",
        "unknown",
        "blank",
        "standard",
        "control",
        "reference",
        "placeholder",
        "tbd",
        "tba",
        "na",
        "n/a",
        "none",
        "not available",
        "not applicable"
      ),
      source = "app_default",
      active = TRUE
    )
  }

  load_or_fetch_reference(cache_path, fetch_fn, "stop words")
}

#' Load block patterns list
#'
#' Returns a tibble of regex patterns for substances that should
#' be blocked from curation with provenance tracking.
#' These match empty/redacted/proprietary entries.
#'
#' Patterns:
#' - Empty strings, dashes, dots
#' - Proprietary/confidential/trade secret indicators
#' - "Not disclosed" phrases
#'
#' NOTE: Cache format changed in Phase 13 - delete existing cache files if needed.
#'
#' @param cache_dir Directory for cache files (e.g., "data/reference_cache")
#' @return Tibble with columns: term, source, active
#' @export
load_block_patterns <- function(cache_dir) {
  cache_path <- file.path(cache_dir, "block_patterns.rds")

  fetch_fn <- function() {
    tibble::tibble(
      term = c(
        "^\\s*$", # Empty or whitespace-only
        "^-+$", # Only dashes
        "^[.]+$", # Only dots
        "^proprietary", # Proprietary (case-insensitive via grep flags)
        "^confidential", # Confidential
        "^trade\\s*secret", # Trade secret
        "^not\\s+disclosed" # Not disclosed
      ),
      source = "app_default",
      active = TRUE
    )
  }

  load_or_fetch_reference(cache_path, fetch_fn, "block patterns")
}

#' Load functional use categories
#'
#' Returns a tibble of functional use categories from ComptoxR with provenance tracking.
#' Falls back gracefully if ComptoxR is unavailable or API fails.
#'
#' NOTE: Cache format changed in Phase 13 - delete existing cache files if needed.
#'
#' @param cache_dir Directory for cache files (e.g., "data/reference_cache")
#' @return Tibble with columns: term, source, active
#' @export
load_functional_categories <- function(cache_dir) {
  cache_path <- file.path(cache_dir, "functional_categories.rds")

  fetch_fn <- function() {
    tryCatch(
      {
        if (requireNamespace("ComptoxR", quietly = TRUE)) {
          raw <- ComptoxR::ct_exposure_functional_use_category()
          if (is.data.frame(raw) && nrow(raw) > 0 && "category" %in% names(raw)) {
            # Strip source tags like (EPA), extract clarifying synonyms
            categories <- raw$category
            # Remove (EPA) source tags entirely
            categories <- stringr::str_remove(categories, "\\s*\\(EPA\\)$")
            # Remove classification disclaimers like ", not other" and "not otherwise specified"
            categories <- stringr::str_remove(categories, ",?\\s*not other(wise specified)?$")
            # Extract clarifying parentheticals as aliases
            has_parens <- stringr::str_detect(categories, "\\(.+\\)")
            alias_text <- stringr::str_match(categories, "\\((.+)\\)")[, 2]
            # Strip parentheticals from primary terms
            primary <- stringr::str_trim(stringr::str_remove(categories, "\\s*\\(.+\\)"))

            primary_tbl <- tibble::tibble(term = primary, source = "ComptoxR", active = TRUE)

            # Split comma-separated aliases into individual terms
            # Only from trailing parentheticals (skip mid-string parens like "Solids separation (precipitating) agent")
            trailing_parens <- stringr::str_detect(categories, "\\(.+\\)\\s*$")
            alias_entries <- which(trailing_parens & has_parens & !is.na(alias_text))
            alias_rows <- purrr::map_dfr(alias_entries, function(i) {
              aliases <- stringr::str_split(alias_text[i], ",\\s*")[[1]]
              tibble::tibble(
                term = stringr::str_trim(aliases),
                source = paste0("ComptoxR (alias of: ", primary[i], ")"),
                active = TRUE
              )
            })

            dplyr::bind_rows(primary_tbl, alias_rows)
          } else {
            message("ComptoxR returned unexpected format for functional use categories")
            tibble::tibble(term = character(), source = character(), active = logical())
          }
        } else {
          message("ComptoxR package not available, using empty functional categories")
          tibble::tibble(term = character(), source = character(), active = logical())
        }
      },
      error = function(e) {
        message(sprintf("ComptoxR functional use fetch failed (%s), using empty list", e$message))
        tibble::tibble(term = character(), source = character(), active = logical())
      }
    )
  }

  load_or_fetch_reference(cache_path, fetch_fn, "functional categories")
}

#' Load strip terms list
#'
#' Returns a tibble of terms to strip from chemical names with provenance tracking.
#' Default terms are seeded from the hardcoded strip functions (quality adjectives,
#' salt references, terminal unspecified). Users can add custom terms via the UI.
#'
#' @param cache_dir Directory for cache files (e.g., "data/reference_cache")
#' @return Tibble with columns: term, source, active
#' @export
load_strip_terms <- function(cache_dir) {
  cache_path <- file.path(cache_dir, "strip_terms.rds")

  fetch_fn <- function() {
    tibble::tibble(
      term = c(
        "pure",
        "purified",
        "technical",
        "grade",
        "chemical",
        "and its salts",
        "and its \\w+ salts",
        "unspecified"
      ),
      source = "app_default",
      active = TRUE
    )
  }

  load_or_fetch_reference(cache_path, fetch_fn, "strip terms")
}

user_reference_list_names <- function() {
  c("stop_words", "block_patterns", "strip_terms")
}

empty_reference_list_tbl <- function() {
  tibble::tibble(term = character(), source = character(), active = logical())
}

empty_user_reference_lists <- function() {
  stats::setNames(
    rep(list(empty_reference_list_tbl()), length(user_reference_list_names())),
    user_reference_list_names()
  )
}

normalize_reference_list_type <- function(type) {
  type_map <- c(
    stop_word = "stop_words",
    stop_words = "stop_words",
    block_pattern = "block_patterns",
    block_patterns = "block_patterns",
    strip_term = "strip_terms",
    strip_terms = "strip_terms"
  )

  normalized <- unname(type_map[[type]])
  if (is.null(normalized)) {
    stop(
      sprintf(
        "Unknown reference list type '%s'. Expected one of: %s",
        type,
        paste(names(type_map), collapse = ", ")
      ),
      call. = FALSE
    )
  }

  normalized
}

normalize_reference_list_tbl <- function(tbl) {
  if (is.null(tbl)) {
    return(empty_reference_list_tbl())
  }

  required_cols <- c("term", "source", "active")
  if (!is.data.frame(tbl) || !all(required_cols %in% names(tbl))) {
    stop("Reference list entries must be data frames with term, source, and active columns.", call. = FALSE)
  }

  tibble::as_tibble(tbl) %>%
    dplyr::transmute(
      term = trimws(as.character(term)),
      source = as.character(source),
      active = as.logical(active)
    ) %>%
    dplyr::filter(!is.na(term), nzchar(term))
}

merge_reference_list_rows <- function(default_tbl, user_tbl) {
  dplyr::bind_rows(
    normalize_reference_list_tbl(user_tbl),
    normalize_reference_list_tbl(default_tbl)
  ) %>%
    dplyr::distinct(term, .keep_all = TRUE)
}

load_default_user_reference_list <- function(type, cache_dir) {
  switch(
    normalize_reference_list_type(type),
    stop_words = load_stop_words(cache_dir),
    block_patterns = load_block_patterns(cache_dir),
    strip_terms = load_strip_terms(cache_dir)
  )
}

#' Load user reference list overrides
#'
#' Loads the sidecar RDS containing user-editable reference list rows. Missing or
#' malformed sidecars return an empty typed list so packaged defaults still load.
#'
#' @param cache_dir Directory for reference cache files. Defaults to the bundled
#'   package/source reference cache.
#' @return List with stop_words, block_patterns, and strip_terms tibbles.
#' @export
load_user_reference_lists <- function(cache_dir = NULL) {
  cache_dir <- resolve_reference_cache_dir(cache_dir)
  cache_path <- file.path(cache_dir, "user_reference_lists.rds")
  empty_lists <- empty_user_reference_lists()

  if (!file.exists(cache_path)) {
    return(empty_lists)
  }

  raw <- tryCatch(
    readRDS(cache_path),
    error = function(e) {
      warning(
        sprintf("Failed to load user reference lists from %s: %s", cache_path, conditionMessage(e)),
        call. = FALSE
      )
      NULL
    }
  )

  if (is.null(raw)) {
    return(empty_lists)
  }

  if (!is.list(raw) || is.data.frame(raw)) {
    warning("User reference lists sidecar is malformed; using empty user lists.", call. = FALSE)
    return(empty_lists)
  }

  tryCatch(
    {
      for (type in user_reference_list_names()) {
        empty_lists[[type]] <- normalize_reference_list_tbl(raw[[type]])
      }
      empty_lists
    },
    error = function(e) {
      warning(
        sprintf("User reference lists sidecar is malformed; using empty user lists: %s", conditionMessage(e)),
        call. = FALSE
      )
      empty_user_reference_lists()
    }
  )
}

#' Save user reference list overrides
#'
#' Persists only rows whose source is not `app_default`, leaving packaged
#' defaults untouched. Rows are saved to `user_reference_lists.rds`.
#'
#' @param reference_lists List containing stop_words, block_patterns, and/or
#'   strip_terms tibbles.
#' @param cache_dir Directory for reference cache files. Defaults to the bundled
#'   package/source reference cache.
#' @return Invisibly returns the saved sidecar list.
#' @export
save_user_reference_lists <- function(reference_lists, cache_dir = NULL) {
  cache_dir <- resolve_reference_cache_dir(cache_dir)
  sidecar <- empty_user_reference_lists()

  for (type in user_reference_list_names()) {
    sidecar[[type]] <- normalize_reference_list_tbl(reference_lists[[type]]) %>%
      dplyr::filter(source != "app_default") %>%
      dplyr::distinct(term, .keep_all = TRUE)
  }

  fs::dir_create(cache_dir, recurse = TRUE)
  saveRDS(sidecar, file.path(cache_dir, "user_reference_lists.rds"), compress = FALSE)

  invisible(sidecar)
}

#' Update a user reference list override
#'
#' Adds, removes, or toggles one user-editable reference term in the sidecar and
#' returns the merged list for that type.
#'
#' @param type One of stop_words/stop_word, block_patterns/block_pattern, or
#'   strip_terms/strip_term.
#' @param term Term or pattern to update.
#' @param active Active value to use when adding or replacing a term.
#' @param action One of add, remove, or toggle.
#' @param cache_dir Directory for reference cache files. Defaults to the bundled
#'   package/source reference cache.
#' @return Tibble containing packaged defaults merged with user overrides.
#' @export
update_user_reference_list <- function(
  type,
  term,
  active = TRUE,
  action = c("add", "remove", "toggle"),
  cache_dir = NULL
) {
  action <- match.arg(action)
  type <- normalize_reference_list_type(type)
  cache_dir <- resolve_reference_cache_dir(cache_dir)
  term <- trimws(as.character(term))

  if (length(term) != 1 || is.na(term) || !nzchar(term)) {
    stop("term must be a non-empty scalar string.", call. = FALSE)
  }

  defaults <- load_default_user_reference_list(type, cache_dir)
  user_lists <- load_user_reference_lists(cache_dir)
  user_tbl <- user_lists[[type]]
  current_tbl <- merge_reference_list_rows(defaults, user_tbl)
  current_idx <- which(tolower(current_tbl$term) == tolower(term))
  user_idx <- which(tolower(user_tbl$term) == tolower(term))

  if (action == "remove") {
    if (length(user_idx) > 0) {
      user_tbl <- user_tbl[-user_idx[1], , drop = FALSE]
    }
  } else {
    new_active <- if (action == "toggle") {
      if (length(current_idx) > 0) !isTRUE(current_tbl$active[current_idx[1]]) else isTRUE(active)
    } else {
      isTRUE(active)
    }

    new_row <- tibble::tibble(term = term, source = "user", active = new_active)
    if (length(user_idx) > 0) {
      user_tbl[user_idx[1], ] <- new_row
    } else {
      user_tbl <- dplyr::bind_rows(user_tbl, new_row)
    }
  }

  user_lists[[type]] <- user_tbl
  save_user_reference_lists(user_lists, cache_dir)
  merge_reference_list_rows(defaults, user_tbl)
}

#' Load one-off corrections table
#'
#' Returns a tibble of (pattern, replacement) pairs for correcting source-specific
#' malformed Result values before numeric parsing. Applied as vectorized gsub()
#' before parse_numeric_results(). Patterns are treated as regex.
#'
#' @param cache_dir Directory for cache files (e.g., "inst/extdata/reference_cache")
#' @return Tibble with columns: pattern (character), replacement (character)
#' @export
load_corrections <- function(cache_dir) {
  cache_path <- file.path(cache_dir, "corrections.rds")

  fetch_fn <- function() {
    tibble::tibble(
      pattern = character(),
      replacement = character()
    )
  }

  load_or_fetch_reference(cache_path, fetch_fn, "one-off corrections")
}

#' Load isotope lookup table
#'
#' Builds a pre-processed lookup table from ComptoxR::pt$isotope for use by
#' expand_isotope_shortcodes(). Cached to RDS to avoid rebuilding on every run.
#'
#' The lookup contains shortcode->canonical mappings (e.g. "u234" -> "Uranium-234"),
#' element name->canonical mappings for spelled-out normalization, and alternate
#' element name spellings (American vs IUPAC).
#'
#' @param cache_dir Directory for cache files (e.g., "data/reference_cache")
#' @return List with components: lookup (tibble), elem_alt_names (named character vector)
#' @export
load_isotope_lookup <- function(cache_dir) {
  cache_path <- file.path(cache_dir, "isotope_lookup.rds")

  fetch_fn <- function() {
    if (!requireNamespace("ComptoxR", quietly = TRUE)) {
      warning("ComptoxR not available - isotope lookup will be empty")
      return(list(
        lookup = tibble::tibble(
          symbol = character(),
          mass = character(),
          element_name = character(),
          shortcode = character(),
          canonical = character(),
          dtxsid = character()
        ),
        elem_alt_names = character()
      ))
    }

    isotopes <- ComptoxR::pt$isotope

    lookup <- tibble::tibble(
      symbol = isotopes$element,
      mass = isotopes$Z,
      element_name = isotopes$Name,
      shortcode = tolower(paste0(isotopes$element, isotopes$Z)),
      canonical = paste0(isotopes$Name, "-", isotopes$Z),
      dtxsid = if ("DTXSID" %in% names(isotopes)) isotopes$DTXSID else NA_character_
    )

    # Remove duplicates (keep first occurrence per shortcode)
    lookup <- lookup[!duplicated(lookup$shortcode), ]

    # Sort by symbol length descending for greedy matching (Pb before P)
    lookup <- lookup[order(-nchar(lookup$symbol)), ]

    # Alternate element name spellings (American vs IUPAC)
    elem_alt_names <- c(
      "cesium" = "Caesium",
      "aluminum" = "Aluminium",
      "sulfur" = "Sulphur"
    )

    list(lookup = lookup, elem_alt_names = elem_alt_names)
  }

  load_or_fetch_reference(cache_path, fetch_fn, "isotope lookup")
}

#' Add deterministic radiological activity-concentration conversions
#'
#' Environmental radioisotope results are commonly reported as activity per volume,
#' but live datasets also use bare activity units such as `pCi` as shorthand. Keep
#' those dimensions separate: concentration units harmonize to `pCi/L`; bare
#' activity units harmonize to `pCi` without assuming a volume basis.
#'
#' Existing ECOTOX-derived cache rows mix canonical targets (`Bq/l` vs `pCi/L`) and
#' omit several common curie-scale variants. This helper installs stable targets
#' for environmental radiological detections.
#'
#' @param unit_map Tibble with unit conversion columns
#' @return Tibble with radiological rows overriding conflicting source rows
#' @keywords internal
augment_radiological_unit_map <- function(unit_map) {
  make_rows <- function(from_unit, to_unit, multiplier, category) {
    tibble::tibble(
      from_unit = from_unit,
      to_unit = rep(to_unit, length(from_unit)),
      multiplier = multiplier,
      category = rep(category, length(from_unit)),
      confidence = rep("HIGH", length(from_unit)),
      source = rep("concert_radiological", length(from_unit))
    )
  }

  activity_concentration_rows <- make_rows(
    from_unit = c(
      "pCi/L", "pCi/l", "pCi per L", "pCi per liter", "pCi per litre",
      "picocurie/L", "picocuries/L", "picocurie/liter", "picocuries/liter",
      "picocurie per liter", "picocuries per liter",
      "picocurie per litre", "picocuries per litre",
      "nCi/L", "uCi/L", "µCi/L", "mCi/L", "Ci/L",
      "Bq/L", "Bq/l", "Bq per L", "Bq per liter", "Bq per litre",
      "mBq/L", "mBq per L", "mBq per liter", "mBq per litre",
      "uBq/L", "uBq per L", "uBq per liter", "uBq per litre",
      "µBq/L", "µBq per L", "µBq per liter", "µBq per litre",
      "kBq/L", "kBq per L", "kBq per liter", "kBq per litre"
    ),
    to_unit = "pCi/L",
    multiplier = c(
      rep(1, 13),
      1e3, 1e6, 1e6, 1e9, 1e12,
      rep(27.027027027027, 5),
      rep(0.027027027027027, 4),
      rep(0.000027027027027, 4),
      rep(0.000027027027027, 4),
      rep(27027.027027027, 4)
    ),
    category = "radioactivity_concentration"
  )

  activity_rows <- make_rows(
    from_unit = c(
      "pCi", "picocurie", "picocuries",
      "nCi", "uCi", "µCi", "mCi", "Ci",
      "Bq", "mBq", "uBq", "µBq", "kBq"
    ),
    to_unit = "pCi",
    multiplier = c(
      1, 1, 1,
      1e3, 1e6, 1e6, 1e9, 1e12,
      27.027027027027, 0.027027027027027,
      0.000027027027027, 0.000027027027027, 27027.027027027
    ),
    category = "radioactivity"
  )

  radiological_rows <- dplyr::bind_rows(activity_concentration_rows, activity_rows)

  if (is.null(unit_map) || nrow(unit_map) == 0) {
    return(radiological_rows)
  }

  unit_map <- unit_map[!tolower(unit_map$from_unit) %in% tolower(radiological_rows$from_unit), , drop = FALSE]
  dplyr::bind_rows(radiological_rows, unit_map)
}

#' Load unit conversion map
#'
#' Returns a tibble of unit conversion factors for harmonizing measurement units.
#' Contains conversions from various units to canonical forms (e.g., ug/L -> mg/L).
#'
#' Structure:
#' - from_unit: Source unit string (case-sensitive)
#' - to_unit: Target canonical unit
#' - multiplier: Conversion factor (from_unit * multiplier = to_unit)
#' - category: Unit category (concentration, mass, dose, etc.)
#' - confidence: Match quality ("HIGH" for exact case, "LOW" for case-insensitive or approximate)
#' - source: Provenance (ECOTOX, SSWQS, user_added)
#'
#' @param cache_dir Directory for cache files (e.g., "inst/extdata")
#' @return Tibble with columns: from_unit, to_unit, multiplier, category, confidence, source
#' @export
load_unit_map <- function(cache_dir = NULL) {
  cache_dir <- resolve_reference_cache_dir(cache_dir)
  cache_path <- file.path(cache_dir, "unit_conversion.rds")

  fetch_fn <- function() {
    # Static data - should already exist in inst/extdata/
    # If missing, return minimal fallback
    warning("unit_conversion.rds not found - returning minimal default")
    tibble::tibble(
      from_unit = c("mg/L", "ug/L", "ppb", "ppm"),
      to_unit = c("mg/L", "mg/L", "mg/L", "mg/L"),
      multiplier = c(1, 0.001, 0.001, 1),
      category = rep("concentration", 4),
      confidence = rep("HIGH", 4),
      source = rep("fallback", 4)
    )
  }

  augment_radiological_unit_map(load_or_fetch_reference(cache_path, fetch_fn, "unit conversion map"))
}

#' Load unit synonym normalization table
#'
#' Returns a tibble for normalizing variant unit spellings to canonical forms
#' before lookup in the main unit conversion table.
#'
#' Note: harmonize_units() loads this table internally via system.file().
#' This exported function is for inspection and debugging purposes.
#'
#' Structure:
#' - input_pattern: String or regex pattern to match
#' - normalized_unit: Canonical form to use for lookup
#' - is_regex: TRUE if pattern is regex, FALSE if exact match
#' - notes: Documentation for the mapping
#'
#' @param cache_dir Directory for cache files (e.g., "inst/extdata")
#' @return Tibble with columns: input_pattern, normalized_unit, is_regex, notes
#' @export
load_unit_synonyms <- function(cache_dir) {
  cache_path <- file.path(cache_dir, "unit_synonyms.rds")

  fetch_fn <- function() {
    warning("unit_synonyms.rds not found - returning minimal default")
    tibble::tibble(
      input_pattern = c("mg/kg bw/day", "ug/kg bw/day"),
      normalized_unit = c("mg/kg/d", "ug/kg/d"),
      is_regex = c(FALSE, FALSE),
      notes = c("body weight qualifier", "body weight qualifier")
    )
  }

  load_or_fetch_reference(cache_path, fetch_fn, "unit synonyms")
}

#' Load ToxVal schema manifest
#'
#' Returns a zero-row tibble defining the 56-column ToxVal schema with proper
#' column types. Use this as a template for creating ToxVal-compatible output.
#'
#' All columns use typed NA values (NA_character_, NA_real_, NA_integer_) to
#' ensure parquet compatibility and proper column type inference.
#'
#' Schema includes:
#' - Identifiers: source_hash, dtxsid, casrn, name, source_name
#' - Toxicity values: toxval_type, toxval_numeric, toxval_units, etc.
#' - Study design: study_type, study_duration_*, generation, lifestage
#' - Species: species_common, species_scientific, strain, sex
#' - Exposure: exposure_route, exposure_method, critical_effect
#' - Source/provenance: source, subsource, year, title, author
#' - Quality: quality, qc_status, priority_id
#' - Audit columns: *_original fields for harmonization tracking
#'
#' @param cache_dir Directory for cache files (e.g., "inst/extdata")
#' @return Zero-row tibble with 56 typed columns
#' @export
load_toxval_schema <- function(cache_dir) {
  cache_path <- file.path(cache_dir, "toxval_schema.rds")

  fetch_fn <- function() {
    # Static data - should already exist in inst/extdata/
    # If missing, return minimal schema with warning
    warning("toxval_schema.rds not found - returning minimal schema")
    tibble::tibble(
      source_hash = NA_character_,
      dtxsid = NA_character_,
      casrn = NA_character_,
      name = NA_character_,
      toxval_type = NA_character_,
      toxval_numeric = NA_real_,
      toxval_units = NA_character_
    )[0, ]
  }

  load_or_fetch_reference(cache_path, fetch_fn, "ToxVal schema")
}

#' Load merged media harmonization map (user edits + AMOS fallback)
#'
#' User rows (user_media_map.rds) take precedence for the same term.
#' Falls back to amos_media.rds via get_media_table() for all other terms.
#' Returns a display-schema tibble with columns for the media editor DT
#' plus the additional columns harmonize_media() needs internally
#' (canonical_term, envo_id, media_category) when passed as media_map parameter.
#'
#' On first run, if user_media_map.rds does not exist, the function returns
#' the full AMOS table normalised to the merged schema. If get_media_table()
#' also returns NULL (e.g., amos_media.rds not yet built), the function
#' returns an empty tibble with the correct column types.
#'
#' @param cache_dir Directory for cache files (e.g., "inst/extdata/reference_cache")
#' @return Tibble with columns: term, canonical, canonical_term, envo_id,
#'   media_category, source, active
#' @export
load_media_map <- function(cache_dir) {
  user_path <- file.path(cache_dir, "user_media_map.rds")
  user_map <- if (file.exists(user_path)) readRDS(user_path) else NULL

  amos_raw <- get_media_table()

  amos_map <- if (!is.null(amos_raw) && nrow(amos_raw) > 0) {
    tibble::tibble(
      term = amos_raw$term,
      canonical = amos_raw$canonical_term,
      canonical_term = amos_raw$canonical_term,
      envo_id = amos_raw$envo_id,
      media_category = amos_raw$media_category,
      source = "amos",
      active = TRUE
    )
  } else {
    tibble::tibble(
      term = character(),
      canonical = character(),
      canonical_term = character(),
      envo_id = character(),
      media_category = character(),
      source = character(),
      active = logical()
    )
  }

  if (!is.null(user_map) && nrow(user_map) > 0) {
    # Backfill internal columns if user_map was saved with 4-col display schema
    if (!"canonical_term" %in% names(user_map)) {
      user_map$canonical_term <- user_map$canonical
    }
    if (!"envo_id" %in% names(user_map)) {
      user_map$envo_id <- NA_character_
    }
    if (!"media_category" %in% names(user_map)) {
      user_map$media_category <- NA_character_
    }
    amos_fallback <- amos_map[!amos_map$term %in% user_map$term, ]
    merged <- dplyr::bind_rows(user_map, amos_fallback)
  } else {
    merged <- amos_map
  }

  infer_media_categories(merged)
}

#' Load all reference lists
#'
#' Convenience wrapper that loads stop words, block patterns, and functional
#' categories in one call. Returns a named list.
#'
#' @param cache_dir Directory for cache files (e.g., "data/reference_cache")
#' @return List with keys: stop_words, block_patterns, functional_categories,
#'   strip_terms, corrections, isotope_lookup, unit_map, unit_synonyms,
#'   toxval_schema, media_map
#'
#' @examples
#' refs <- load_all_reference_lists("data/reference_cache")
#' refs$stop_words
#' refs$block_patterns
#' refs$functional_categories
#' refs$strip_terms
#' refs$corrections
#' refs$isotope_lookup
#' refs$unit_map
#' refs$unit_synonyms
#' refs$toxval_schema
#' refs$media_map
#' @export
load_all_reference_lists <- function(cache_dir = NULL) {
  cache_dir <- resolve_reference_cache_dir(cache_dir)

  reference_lists <- list(
    stop_words = load_stop_words(cache_dir),
    block_patterns = load_block_patterns(cache_dir),
    functional_categories = load_functional_categories(cache_dir),
    strip_terms = load_strip_terms(cache_dir),
    corrections = load_corrections(cache_dir),
    isotope_lookup = load_isotope_lookup(cache_dir),
    unit_map = load_unit_map(cache_dir),
    unit_synonyms = load_unit_synonyms(cache_dir),
    toxval_schema = load_toxval_schema(cache_dir),
    media_map = load_media_map(cache_dir) # Phase 42: merged user + AMOS media map
  )

  user_reference_lists <- load_user_reference_lists(cache_dir)
  for (type in user_reference_list_names()) {
    reference_lists[[type]] <- merge_reference_list_rows(
      reference_lists[[type]],
      user_reference_lists[[type]]
    )
  }

  reference_lists
}

# Internal function — builds WQX dictionary from EPA domain value CSVs
# Downloads Characteristic.csv and Characteristic Alias.csv as zips,
# parses them, and returns a combined tibble per D-01/D-05 schema.
.build_wqx_dictionary <- function() {
  char_url <- "https://cdx.epa.gov/wqx/download/DomainValues/Characteristic_CSV.zip"
  alias_url <- "https://cdx.epa.gov/wqx/download/DomainValues/CharacteristicAlias_CSV.zip"

  tmp_dir <- tempfile()
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  # Download both zips
  char_zip <- file.path(tmp_dir, "char.zip")
  alias_zip <- file.path(tmp_dir, "alias.zip")
  utils::download.file(char_url, destfile = char_zip, mode = "wb", quiet = TRUE)
  utils::download.file(alias_url, destfile = alias_zip, mode = "wb", quiet = TRUE)

  # Extract
  utils::unzip(char_zip, exdir = tmp_dir)
  utils::unzip(alias_zip, exdir = tmp_dir)

  # Parse Characteristic.csv -> canonical rows
  char_tbl <- readr::read_csv(
    file.path(tmp_dir, "Characteristic.csv"),
    show_col_types = FALSE
  ) |>
    dplyr::select(
      name = Name,
      cas_number = `CAS Number`,
      group_name = `Group Name`,
      description = Description
    ) |>
    dplyr::mutate(
      name = trimws(name),
      canonical_name = name,
      type = "canonical"
    )

  # Parse Characteristic Alias.csv -> alias rows (3 types only)
  # NOTE: CSV filename has a space: "Characteristic Alias.csv" (not "CharacteristicAlias.csv")
  kept_alias_types <- c(
    "WQX SYNONYM REGISTRY (validation)",
    "STANDARDIZE NAME (Normalized)",
    "RETIRED NAME"
  )
  type_map <- c(
    "WQX SYNONYM REGISTRY (validation)" = "synonym",
    "STANDARDIZE NAME (Normalized)" = "standardize",
    "RETIRED NAME" = "retired"
  )
  alias_tbl <- readr::read_csv(
    file.path(tmp_dir, "Characteristic Alias.csv"),
    show_col_types = FALSE
  ) |>
    dplyr::filter(`Alias Type Name` %in% kept_alias_types) |>
    dplyr::select(
      name = `Alias Name`,
      canonical_name = `Characteristic Name`,
      description = Description,
      alias_type = `Alias Type Name`
    ) |>
    dplyr::mutate(
      name = trimws(name),
      canonical_name = trimws(canonical_name),
      type = dplyr::recode(alias_type, !!!type_map),
      cas_number = NA_character_,
      group_name = NA_character_
    ) |>
    dplyr::select(-alias_type)

  dplyr::bind_rows(char_tbl, alias_tbl) |>
    dplyr::select(name, canonical_name, type, cas_number, group_name, description)
}

#' Load WQX dictionary lookup table
#'
#' Returns a combined tibble of canonical WQX Characteristic Names and alias
#' mappings (synonym, standardize, retired). Uses the generic cache-or-fetch
#' infrastructure — builds the dictionary from EPA data on first call if no
#' cached RDS exists.
#'
#' @param cache_dir Directory containing reference cache RDS files
#' @return Tibble with columns: name, canonical_name, type, cas_number, group_name, description
#' @export
load_wqx_dictionary <- function(cache_dir) {
  cache_path <- file.path(cache_dir, "wqx_dictionary.rds")
  load_or_fetch_reference(cache_path, .build_wqx_dictionary, "WQX dictionary")
}

#' Refresh WQX dictionary cache
#'
#' Re-downloads Characteristic.csv and Characteristic Alias.csv from EPA,
#' rebuilds the combined lookup tibble, and saves to cache. Overwrites any
#' existing cached RDS silently.
#'
#' @param cache_dir Directory for reference cache. Defaults to installed package path.
#' @return Invisibly returns the rebuilt tibble
#' @export
refresh_wqx_cache <- function(cache_dir = NULL) {
  if (is.null(cache_dir)) {
    cache_dir <- resolve_reference_cache_dir()
  }
  cache_path <- file.path(cache_dir, "wqx_dictionary.rds")
  if (file.exists(cache_path)) {
    unlink(cache_path)
  }

  result <- .build_wqx_dictionary()
  fs::dir_create(dirname(cache_path), recurse = TRUE)
  saveRDS(result, cache_path, compress = FALSE)
  message(sprintf("WQX dictionary refreshed: %d rows written to %s", nrow(result), cache_path))
  invisible(result)
}
