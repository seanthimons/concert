# build_amos_media.R
# AMOS media extraction and coverage pipeline
# Extracts environmental media terms from ComptoxR::chemi_amos_method_pagination(),
# maps against curated ENVO subset, expands parentheticals, deduplicates,
# reports coverage gaps, and writes amos_media.rds runtime cache.
#
# No Shiny dependency -- runs in any R session with ComptoxR configured.
#
# Prerequisites:
#   1. ComptoxR API key configured (ctx_api_key environment variable)
#   2. Curated ENVO subset in inst/extdata/reference_cache/amos_media.rds (Plan 01)
#   3. Source this file: source("scripts/build_amos_media.R")
#
# Output:
#   - inst/extdata/reference_cache/amos_media.rds  (enriched runtime cache)
#   - coverage report to console

# ============================================================================
# 0. CONFIGURATION
# ============================================================================

CONCERT_ROOT <- here::here()

stopifnot(
  "ComptoxR package is required" = requireNamespace("ComptoxR", quietly = TRUE),
  "stringr package is required" = requireNamespace("stringr", quietly = TRUE),
  "dplyr package is required" = requireNamespace("dplyr", quietly = TRUE),
  "tibble package is required" = requireNamespace("tibble", quietly = TRUE)
)

# Load curated ENVO subset built in Plan 01
curated_path <- file.path(CONCERT_ROOT, "inst", "extdata", "reference_cache", "amos_media.rds")
stopifnot("Curated ENVO subset must exist (run Plan 01 first)" = file.exists(curated_path))

curated_media <- readRDS(curated_path)
# Keep only the curated entries as the base -- strip any prior amos_derived rows
# so re-running is idempotent (curated always wins on collision).
curated_only <- dplyr::filter(curated_media, source == "envo_curated")
curated_terms <- tolower(curated_only$term)

message(sprintf("  Loaded %d curated ENVO terms as vocabulary base", length(curated_terms)))

# ============================================================================
# 1. FETCH AMOS METHOD DESCRIPTIONS
# ============================================================================

message("=== FETCHING AMOS METHOD DESCRIPTIONS ===")
amos_raw <- tryCatch(
  # all_pages=FALSE with a large limit returns all ~7400 records in one page.
  # all_pages=TRUE returns 7400 pages with 0 records each (ComptoxR 1.4.0 behaviour).
  ComptoxR::chemi_amos_method_pagination(limit = 10000, offset = 0, all_pages = FALSE),
  error = function(e) stop(sprintf("AMOS fetch failed: %s", conditionMessage(e)))
)

# chemi_amos_method_pagination() returns a nested list:
#   amos_raw[[page_index]]$results[[record_index]]$field
# Flatten all pages into a single list of records using do.call(c) -- avoids
# the intermediate nested list that lapply+unlist would create.
all_records <- do.call(c, lapply(amos_raw, `[[`, "results"))
n_records <- length(all_records)
message(sprintf("  Fetched %d AMOS method records", n_records))

# Extract description and matrix fields in one vapply pass (typed, single loop).
# vapply returns a character matrix [2 x n_records]; rows are description/matrix.
text_matrix <- vapply(
  all_records,
  FUN = function(r) {
    desc <- r[["description"]]
    mat <- r[["matrix"]]
    c(
      if (length(desc) > 0L) as.character(desc[[1L]]) else NA_character_,
      if (length(mat) > 0L) as.character(mat[[1L]]) else NA_character_
    )
  },
  FUN.VALUE = character(2L)
)

# Flatten the 2-row matrix to a plain character vector; drop NAs and empty strings.
descriptions <- as.character(text_matrix)
descriptions <- descriptions[!is.na(descriptions) & nzchar(descriptions)]
message(sprintf("  Valid text fields for extraction: %d", length(descriptions)))

# ============================================================================
# 2. EXTRACT MEDIA TERMS
# ============================================================================

message("=== EXTRACTING MEDIA TERMS ===")

# Build a single alternation pattern covering both curated terms AND broad media
# vocabulary.  One str_extract_all() pass over all descriptions extracts every
# matching token in a single vectorized sweep -- no per-term outer loop.
all_vocab_terms <- unique(c(
  curated_terms,
  "water",
  "soil",
  "air",
  "sediment",
  "sludge",
  "dust",
  "tissue",
  "blood",
  "plasma",
  "serum",
  "biota",
  "effluent",
  "groundwater",
  "surface water",
  "drinking water",
  "wastewater",
  "freshwater",
  "saltwater",
  "seawater",
  "marine",
  "ocean",
  "lake",
  "river",
  "pond",
  "stream",
  "wetland",
  "pore water",
  "interstitial water",
  "leachate",
  "runoff",
  "particulate",
  "atmospheric",
  "ambient",
  "indoor",
  "outdoor",
  "aquatic",
  "terrestrial",
  "aqueous",
  "solid",
  "matrix"
))

# Sort longest-first so the alternation engine matches multi-word terms before
# their single-word components (e.g. "surface water" before "water").
all_vocab_terms <- all_vocab_terms[order(nchar(all_vocab_terms), decreasing = TRUE)]

combined_pattern <- stringr::regex(
  paste0("\\b(", paste(stringr::str_escape(all_vocab_terms), collapse = "|"), ")\\b"),
  ignore_case = TRUE
)

# Single vectorized extraction over all descriptions
all_matches <- stringr::str_extract_all(descriptions, combined_pattern)
all_extracted_raw <- tolower(unlist(all_matches, use.names = FALSE))
all_extracted_raw <- all_extracted_raw[!is.na(all_extracted_raw) & nchar(all_extracted_raw) > 0L]
message(sprintf("  Raw extracted terms (with duplicates): %d", length(all_extracted_raw)))

# ============================================================================
# 3. EXPAND PARENTHETICAL COMPOUND TERMS (D-04)
# ============================================================================

message("=== EXPANDING PARENTHETICAL TERMS ===")

#' Vectorized expansion of parenthetical compound media terms
#'
#' Handles patterns like "water (freshwater)" -> three terms (base, qualifier,
#' qualifier+base) and passes non-parenthetical terms through unchanged.
#' Operates on the entire input vector at once via str_match().
#'
#' @param terms Character vector of media terms (may include parentheticals).
#' @return Character vector of all expanded terms (longer than input when
#'   parentheticals are present).
#' @keywords internal
expand_parenthetical_vec <- function(terms) {
  m <- stringr::str_match(terms, "^(.+?)\\s*\\((.+?)\\)$")
  has_paren <- !is.na(m[, 1])

  base_parts <- trimws(m[, 2])
  qual_parts <- trimws(m[, 3])

  # Non-parenthetical terms pass through as-is
  plain <- terms[!has_paren]

  # Parenthetical terms expand to three components each
  bases <- base_parts[has_paren]
  quals <- qual_parts[has_paren]
  combined <- paste(quals, bases)

  c(plain, bases, quals, combined)
}

expanded <- expand_parenthetical_vec(all_extracted_raw)
expanded <- tolower(trimws(expanded))
expanded <- expanded[nchar(expanded) > 0]

# Deduplicate
unique_extracted <- unique(expanded)
message(sprintf("  Unique terms after expansion + dedup: %d", length(unique_extracted)))

# ============================================================================
# 4. MATCH AGAINST CURATED ENVO SUBSET
# ============================================================================

message("=== MATCHING AGAINST CURATED ENVO SUBSET ===")

# Exact match in curated vocabulary
exact_matched <- unique_extracted[unique_extracted %in% curated_terms]
unmatched_raw <- setdiff(unique_extracted, curated_terms)

message(sprintf("  Exact matches: %d / %d", length(exact_matched), length(unique_extracted)))
message(sprintf("  Unmatched (candidate gaps): %d", length(unmatched_raw)))

# Vectorized exact-match lookup: one match() call for all exact_matched terms
exact_row_idx <- match(exact_matched, curated_only$term)
valid_exact <- !is.na(exact_row_idx)

# Build exact-match vectors in one shot (no loop)
em_term_vec <- exact_matched[valid_exact]
em_canonical_vec <- curated_only$canonical_term[exact_row_idx[valid_exact]]
em_envo_vec <- curated_only$envo_id[exact_row_idx[valid_exact]]
em_parent_vec <- curated_only$parent[exact_row_idx[valid_exact]]
em_category_vec <- curated_only$media_category[exact_row_idx[valid_exact]]

# Fuzzy assignment for unmatched terms: substring inheritance.
# combined_pattern (built in Section 2, sorted longest-first) already encodes
# all curated terms as a single alternation.  str_extract() applies it
# vectorized over the entire unmatched_raw vector in one call -- no per-term
# or per-row R loop.  The longest-first sort ensures the most specific curated
# term wins (e.g. "surface water" before "water").
if (length(unmatched_raw) > 0L) {
  # Extract the best-matching curated term from each unmatched string.
  # Returns NA where no curated term appears as a substring.
  best_curated_hit <- tolower(stringr::str_extract(unmatched_raw, combined_pattern))

  has_hit <- !is.na(best_curated_hit)

  # Look up metadata for the matched curated term via vectorized match()
  hit_row_idx <- match(best_curated_hit[has_hit], curated_only$term)

  fz_term_vec <- unmatched_raw[has_hit]
  fz_canonical_vec <- curated_only$canonical_term[hit_row_idx]
  fz_envo_vec <- rep(NA_character_, sum(has_hit))
  fz_parent_vec <- curated_only$canonical_term[hit_row_idx]
  fz_category_vec <- curated_only$media_category[hit_row_idx]

  unmatched_terms <- unmatched_raw[!has_hit]
} else {
  fz_term_vec <- character(0)
  fz_canonical_vec <- character(0)
  fz_envo_vec <- character(0)
  fz_parent_vec <- character(0)
  fz_category_vec <- character(0)
  unmatched_terms <- character(0)
}

# Combine exact-matched and fuzzy-matched vectors (both already character)
amos_term_vec <- c(em_term_vec, fz_term_vec)
amos_canonical_vec <- c(em_canonical_vec, fz_canonical_vec)
amos_envo_vec <- c(em_envo_vec, fz_envo_vec)
amos_parent_vec <- c(em_parent_vec, fz_parent_vec)
amos_category_vec <- c(em_category_vec, fz_category_vec)

n_amos_extracted <- length(unique_extracted)
n_matched <- length(amos_term_vec)
n_unmatched <- length(unmatched_terms)
pct_matched <- if (n_amos_extracted > 0) 100 * n_matched / n_amos_extracted else 0

# ============================================================================
# 5. BUILD ENRICHED CACHE
# ============================================================================

message("=== BUILDING ENRICHED CACHE ===")

fetch_ts <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S")

if (length(amos_term_vec) > 0L) {
  amos_entries <- tibble::tibble(
    term = amos_term_vec,
    canonical_term = amos_canonical_vec,
    envo_id = amos_envo_vec,
    parent = amos_parent_vec,
    media_category = amos_category_vec,
    source = "amos_derived",
    fetch_timestamp = fetch_ts
  )
} else {
  amos_entries <- tibble::tibble(
    term = character(0),
    canonical_term = character(0),
    envo_id = character(0),
    parent = character(0),
    media_category = character(0),
    source = character(0),
    fetch_timestamp = character(0)
  )
}

# Update fetch_timestamp on curated entries to reflect this build run
curated_refreshed <- dplyr::mutate(curated_only, fetch_timestamp = fetch_ts)

# Merge: curated entries first so they win on term collision via distinct()
enriched_media <- dplyr::bind_rows(curated_refreshed, amos_entries) |>
  dplyr::distinct(term, .keep_all = TRUE)

message(sprintf(
  "  Enriched vocab: %d total terms (%d curated + %d AMOS-derived)",
  nrow(enriched_media),
  sum(enriched_media$source == "envo_curated"),
  sum(enriched_media$source == "amos_derived")
))

# ============================================================================
# 6. WRITE CACHE + COVERAGE REPORT (AMOS-02)
# ============================================================================

cache_path <- file.path(CONCERT_ROOT, "inst", "extdata", "reference_cache", "amos_media.rds")
saveRDS(enriched_media, cache_path)
message(sprintf("  Cache written: %s (%d term mappings)", basename(cache_path), nrow(enriched_media)))

message("=== COVERAGE REPORT ===")
message(sprintf("  AMOS terms extracted:    %d", n_amos_extracted))
message(sprintf("  Matched to ENVO subset:  %d (%.1f%%)", n_matched, pct_matched))
message(sprintf("  Unmatched (gaps):        %d", n_unmatched))
if (n_unmatched > 0) {
  message(paste(
    c("  Unmatched terms (first 20):", paste0("    - ", head(unmatched_terms, 20))),
    collapse = "\n"
  ))
}

# ============================================================================
# 7. REFRESH FUNCTION (AMOS-03)
# ============================================================================

#' Refresh the AMOS media vocabulary cache
#'
#' Re-runs the AMOS extraction pipeline if the existing cache is stale (older
#' than \code{max_age_days} days) or if \code{force = TRUE}.  Uses the curated
#' ENVO subset as the vocabulary base and enriches it with terms found in
#' ComptoxR AMOS method descriptions.
#'
#' @param force Logical.  If \code{TRUE}, refreshes regardless of cache age.
#'   Default \code{FALSE}.
#' @param max_age_days Numeric.  Maximum cache age in days before a refresh is
#'   triggered.  Default 30.
#' @return Invisibly returns \code{NULL}.  Side effect: writes
#'   \code{inst/extdata/reference_cache/amos_media.rds}.
#' @export
refresh_amos_cache <- function(force = FALSE, max_age_days = 30) {
  root <- here::here()
  cache <- file.path(root, "inst", "extdata", "reference_cache", "amos_media.rds")

  if (file.exists(cache)) {
    existing <- readRDS(cache)
    ts <- existing$fetch_timestamp[1]

    if (!is.na(ts) && !force) {
      age_days <- as.numeric(difftime(Sys.time(), as.POSIXct(ts), units = "days"))

      if (age_days < max_age_days) {
        message(sprintf(
          "Cache is %.0f days old (< %d). Use force=TRUE to refresh.",
          age_days,
          max_age_days
        ))
        return(invisible(NULL))
      }

      message(sprintf("Cache is %.0f days old (>= %d). Refreshing...", age_days, max_age_days))
    }
  }

  source(file.path(root, "scripts", "build_amos_media.R"))
  invisible(NULL)
}
