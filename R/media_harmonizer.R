# media_harmonizer.R
# Environmental media harmonization engine: string normalization, exact/parent-walk
# lookup against curated ENVO subset, canonical resolution with category routing.
#
# Public API: harmonize_media()
# Internal: get_media_table(), walk_parent()

#' Load the curated ENVO media vocabulary table
#'
#' Reads amos_media.rds from the package reference cache.  Returns NULL if the
#' file cannot be found so that callers can degrade gracefully.
#'
#' @return Tibble with columns term, canonical_term, envo_id, parent,
#'   media_category, source, fetch_timestamp; or NULL.
#' @keywords internal
get_media_table <- function() {
  path <- system.file("extdata/reference_cache/amos_media.rds", package = "chemreg")
  if (nzchar(path) && file.exists(path)) {
    readRDS(path)
  } else {
    NULL
  }
}

#' Walk the parent hierarchy for a normalized media string
#'
#' Given a normalized (trimws + tolower) input string that did not produce an
#' exact match, attempts to find the best ancestor by checking whether any
#' table term is a sub-string of the input or vice-versa.  When a candidate is
#' found, walks up the \code{parent} column until an entry with a non-NA
#' \code{media_category} is reached.
#'
#' Returns the integer row index of the resolved entry, or \code{NA_integer_}.
#'
#' @param norm_term Single normalized character string.
#' @param media_tbl Tibble returned by \code{get_media_table()}.
#' @return Integer row index or NA_integer_.
#' @keywords internal
walk_parent <- function(norm_term, media_tbl) {
  if (is.na(norm_term) || !nzchar(norm_term)) {
    return(NA_integer_)
  }

  # Pre-built term vector (lowercase, already normalized in the table)
  tbl_terms <- media_tbl$term

  # Candidate: norm_term is a sub-string of a table entry (e.g. "water" in
  # "freshwater"), OR a table entry is a sub-string of norm_term (e.g.
  # "sediment" in "freshwater sediment").
  # grepl(pattern, x) -- vectorize over x for the first case (one pattern,
  # many strings), and over pattern via vapply for the second case so that we
  # never pass a length>1 vector as the pattern argument.
  norm_in_tbl <- grepl(norm_term, tbl_terms, fixed = TRUE)
  tbl_in_norm <- vapply(tbl_terms, grepl, logical(1L), x = norm_term, fixed = TRUE)
  is_candidate <- norm_in_tbl | tbl_in_norm

  candidate_idx <- which(is_candidate)
  if (length(candidate_idx) == 0L) {
    return(NA_integer_)
  }

  # Among candidates, prefer longer term strings (more specific match).
  # Pre-compute lengths once.
  cand_lens <- nchar(tbl_terms[candidate_idx])
  best_cand <- candidate_idx[which.max(cand_lens)]

  # Walk up the parent hierarchy until we reach an entry with media_category
  visited <- integer(0)
  current <- best_cand

  repeat {
    if (current %in% visited) {
      break
    } # cycle guard
    visited <- c(visited, current)

    if (!is.na(media_tbl$media_category[current])) {
      return(current)
    }

    # Move to parent
    parent_term <- media_tbl$parent[current]
    if (is.na(parent_term)) {
      break
    }

    parent_idx <- match(parent_term, tbl_terms)
    if (is.na(parent_idx)) {
      break
    }

    current <- parent_idx
  }

  NA_integer_
}

#' Harmonize environmental media strings to canonical ENVO terms
#'
#' Maps a character vector of raw environmental media strings against the
#' curated ENVO vocabulary table (\code{amos_media.rds}).  Resolution order:
#' (1) exact match on normalized string; (2) parent-walk for partial/compound
#' matches; (3) \code{media_unmatched} flag for everything else.
#'
#' @param raw_media Character vector of media strings to harmonize.
#' @param orig_row_id Integer vector of row IDs corresponding to each element
#'   of \code{raw_media}.  Defaults to \code{seq_along(raw_media)} for direct
#'   column processing.
#' @return A tibble with 6 columns:
#'   \describe{
#'     \item{orig_row_id}{Integer row position for join-by-position merge.}
#'     \item{raw_media}{Original input string, preserved for audit.}
#'     \item{canonical_media}{Canonical ENVO term, or \code{NA_character_} if
#'       unmatched.}
#'     \item{envo_id}{ENVO identifier for the matched term, or
#'       \code{NA_character_}.}
#'     \item{media_category}{Top-level routing value: \code{"aqueous"},
#'       \code{"air"}, \code{"solid"}, or \code{NA_character_}.}
#'     \item{media_flag}{One of: \code{""} (exact match), \code{"parent_walk"},
#'       \code{"media_unmatched"}.}
#'   }
#' @importFrom tibble tibble
#' @export
harmonize_media <- function(raw_media, orig_row_id = seq_along(raw_media)) {
  # Empty-input guard: return typed 0-row tibble (T-41-02 DoS mitigation)
  n <- length(raw_media)
  if (n == 0L) {
    return(tibble::tibble(
      orig_row_id = integer(0),
      raw_media = character(0),
      canonical_media = character(0),
      envo_id = character(0),
      media_category = character(0),
      media_flag = character(0)
    ))
  }

  # Load vocabulary table; degrade to all-unmatched if unavailable
  media_tbl <- get_media_table()
  if (is.null(media_tbl) || nrow(media_tbl) == 0L) {
    return(tibble::tibble(
      orig_row_id = as.integer(orig_row_id),
      raw_media = as.character(raw_media),
      canonical_media = NA_character_,
      envo_id = NA_character_,
      media_category = NA_character_,
      media_flag = rep("media_unmatched", n)
    ))
  }

  # Normalize input: trim whitespace and lower-case (vectorized)
  normalized <- trimws(tolower(raw_media))

  # Build O(1) hash map: normalized term -> row index
  lookup_hash <- stats::setNames(seq_len(nrow(media_tbl)), media_tbl$term)

  # Exact match (vectorized, NA-safe)
  non_na_mask <- !is.na(normalized)
  match_idx <- rep(NA_integer_, n)
  match_idx[non_na_mask] <- lookup_hash[normalized[non_na_mask]]

  # Pre-allocate output vectors
  canonical_out <- rep(NA_character_, n)
  envo_out <- rep(NA_character_, n)
  category_out <- rep(NA_character_, n)
  media_flag <- rep("media_unmatched", n)

  # Fill exact matches (vectorized where possible)
  exact_mask <- !is.na(match_idx)
  if (any(exact_mask)) {
    idx_vec <- match_idx[exact_mask]
    canonical_out[exact_mask] <- media_tbl$canonical_term[idx_vec]
    envo_out[exact_mask] <- media_tbl$envo_id[idx_vec]
    category_out[exact_mask] <- media_tbl$media_category[idx_vec]
    media_flag[exact_mask] <- ""
  }

  # Parent-walk for remaining unmatched rows (scalar loop -- typically few rows)
  unmatched_positions <- which(!exact_mask)
  for (i in unmatched_positions) {
    resolved <- walk_parent(normalized[i], media_tbl)
    if (!is.na(resolved)) {
      canonical_out[i] <- media_tbl$canonical_term[resolved]
      envo_out[i] <- media_tbl$envo_id[resolved]
      category_out[i] <- media_tbl$media_category[resolved]
      media_flag[i] <- "parent_walk"
    }
    # else: stays "media_unmatched" / NA (already initialized)
  }

  tibble::tibble(
    orig_row_id = as.integer(orig_row_id),
    raw_media = as.character(raw_media),
    canonical_media = canonical_out,
    envo_id = envo_out,
    media_category = category_out,
    media_flag = media_flag
  )
}
