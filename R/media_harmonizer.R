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
find_local_media_table <- function() {
  cwd <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  parts <- strsplit(cwd, "/", fixed = TRUE)[[1]]
  if (length(parts) == 0L) {
    return("")
  }

  for (i in seq(length(parts), 1L)) {
    candidate_root <- paste(parts[seq_len(i)], collapse = "/")
    if (!nzchar(candidate_root)) {
      candidate_root <- "/"
    }
    candidate <- file.path(candidate_root, "inst", "extdata", "reference_cache", "amos_media.rds")
    if (file.exists(candidate)) {
      return(candidate)
    }
  }

  ""
}

get_media_table <- function() {
  package_path <- system.file("extdata/reference_cache/amos_media.rds", package = "concert")
  local_path <- find_local_media_table()
  path <- if (nzchar(package_path) && file.exists(package_path)) {
    package_path
  } else if (file.exists(local_path)) {
    local_path
  } else {
    ""
  }

  if (nzchar(path)) {
    readRDS(path)
  } else {
    NULL
  }
}

media_value_present <- function(x) {
  !is.na(x) & nzchar(trimws(as.character(x)))
}

escape_regex <- function(x) {
  gsub("([][{}()+*^$.|?\\\\])", "\\\\\\1", x)
}

media_term_in_text <- function(term, text) {
  if (is.na(term) || is.na(text) || !nzchar(term) || !nzchar(text)) {
    return(FALSE)
  }

  pattern <- sprintf("(^|[^[:alnum:]])%s($|[^[:alnum:]])", escape_regex(term))
  grepl(pattern, text, perl = TRUE)
}

is_resolved_media_row <- function(media_tbl, idx) {
  valid_idx <- !is.na(idx)
  out <- rep(FALSE, length(idx))
  if (any(valid_idx)) {
    rows <- idx[valid_idx]
    out[valid_idx] <- media_value_present(media_tbl$canonical_term[rows]) &
      media_value_present(media_tbl$media_category[rows])
  }
  out
}

prepare_media_table <- function(media_tbl) {
  if (is.null(media_tbl) || nrow(media_tbl) == 0L) {
    return(media_tbl)
  }

  if (!"canonical_term" %in% names(media_tbl) && "canonical" %in% names(media_tbl)) {
    media_tbl$canonical_term <- media_tbl$canonical
  }
  if (!"envo_id" %in% names(media_tbl)) {
    media_tbl$envo_id <- NA_character_
  }
  if (!"media_category" %in% names(media_tbl)) {
    media_tbl$media_category <- NA_character_
  }
  if (!"parent" %in% names(media_tbl)) {
    media_tbl$parent <- NA_character_
  }
  if (!"active" %in% names(media_tbl)) {
    media_tbl$active <- TRUE
  }

  active_flag <- as.logical(media_tbl$active)
  active_flag[is.na(active_flag)] <- FALSE
  media_tbl <- media_tbl[active_flag, , drop = FALSE]
  media_tbl$term <- trimws(tolower(as.character(media_tbl$term)))
  media_tbl$canonical_term <- trimws(as.character(media_tbl$canonical_term))
  media_tbl$parent <- trimws(tolower(as.character(media_tbl$parent)))
  media_tbl$parent[!media_value_present(media_tbl$parent)] <- NA_character_

  media_tbl
}

infer_media_categories <- function(media_tbl) {
  if (is.null(media_tbl) || nrow(media_tbl) == 0L || !"media_category" %in% names(media_tbl)) {
    return(media_tbl)
  }

  source_idx <- which(
    media_value_present(media_tbl$canonical_term) &
      media_value_present(media_tbl$media_category)
  )
  if (length(source_idx) == 0L) {
    return(media_tbl)
  }

  unique_donor <- function(key, key_vec) {
    candidates <- source_idx[key_vec[source_idx] == key]
    if (length(candidates) == 0L) {
      return(NA_integer_)
    }
    categories <- unique(media_tbl$media_category[candidates])
    categories <- categories[media_value_present(categories)]
    if (length(categories) != 1L) {
      return(NA_integer_)
    }
    candidates[1]
  }

  term_keys <- media_tbl$term
  canonical_keys <- trimws(tolower(media_tbl$canonical_term))

  missing_category <- which(
    media_value_present(media_tbl$canonical_term) &
      !media_value_present(media_tbl$media_category)
  )
  for (i in missing_category) {
    key <- trimws(tolower(media_tbl$canonical_term[i]))
    donor <- unique_donor(key, term_keys)
    if (is.na(donor)) {
      donor <- unique_donor(key, canonical_keys)
    }
    if (!is.na(donor)) {
      media_tbl$media_category[i] <- media_tbl$media_category[donor]
      if (is.na(media_tbl$envo_id[i]) && !is.na(media_tbl$envo_id[donor])) {
        media_tbl$envo_id[i] <- media_tbl$envo_id[donor]
      }
    }
  }

  media_tbl
}

#' Walk the parent hierarchy for a normalized media string
#'
#' Given a normalized (trimws + tolower) input string that did not produce a
#' resolved exact match, attempts to find the best ancestor by checking whether
#' a table term appears as a full token/phrase in the input.  Embedded
#' substrings such as \code{"water"} in \code{"wastewater"} are intentionally
#' ignored.  When a candidate is found, walks up the \code{parent} column until
#' an entry with both a canonical term and media category is reached.
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

  tbl_terms <- media_tbl$term
  is_candidate <- vapply(tbl_terms, media_term_in_text, logical(1L), text = norm_term)

  candidate_idx <- which(is_candidate)
  if (length(candidate_idx) == 0L) {
    return(NA_integer_)
  }

  cand_lens <- nchar(tbl_terms[candidate_idx])
  candidate_idx <- candidate_idx[order(cand_lens, decreasing = TRUE)]

  for (best_cand in candidate_idx) {
    visited <- integer(0)
    current <- best_cand

    repeat {
      if (current %in% visited) {
        break
      }
      visited <- c(visited, current)

      if (is_resolved_media_row(media_tbl, current)) {
        return(current)
      }

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
#' @param media_map Optional tibble with columns term, canonical_term, envo_id,
#'   media_category. When NULL (default), falls back to the bundled AMOS table
#'   via get_media_table(). Pass a merged user+AMOS map from load_media_map()
#'   to enable user-defined mappings (MEDIT-03, D-14). If the tibble uses
#'   \code{canonical} instead of \code{canonical_term} (display schema),
#'   the column is translated internally before lookup.
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
harmonize_media <- function(raw_media, orig_row_id = seq_along(raw_media), media_map = NULL) {
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

  # Use passed-in map or fall back to bundled AMOS table (D-14 priority order)
  media_tbl <- if (!is.null(media_map) && nrow(media_map) > 0) {
    # Validate required column: term must be present
    if (!"term" %in% names(media_map)) {
      get_media_table()
    } else {
      media_map
    }
  } else {
    get_media_table()
  }

  media_tbl <- prepare_media_table(media_tbl)
  media_tbl <- infer_media_categories(media_tbl)

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

  # Fill resolved exact matches (vectorized where possible). Exact rows without
  # a usable routing category stay unmatched so ppb/ppm never default silently.
  exact_mask <- !is.na(match_idx) & is_resolved_media_row(media_tbl, match_idx)
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
