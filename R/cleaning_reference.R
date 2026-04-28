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
load_unit_map <- function(cache_dir) {
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

  load_or_fetch_reference(cache_path, fetch_fn, "unit conversion map")
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
    dplyr::bind_rows(user_map, amos_fallback)
  } else {
    amos_map
  }
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
load_all_reference_lists <- function(cache_dir) {
  list(
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
}
