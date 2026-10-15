# method_harmonizer.R
# Analytical-method identity lookup against the pinned envharmonizer tables.
# Port of envharmonizer::harmonize_methodology() (MIT); see #102.

normalize_method_key <- function(x) {
  out <- trimws(tolower(as.character(x)))
  out <- gsub(paste0("[_", intToUtf8(c(0x2013, 0x2014)), "]+"), "-", out)
  out <- gsub("\\s+", " ", out)
  out[is.na(x) | !nzchar(out)] <- NA_character_
  out
}

#' Load the pinned analytical-method tables
#'
#' Memoised for the session, like [get_media_table()].
#' @keywords internal
get_method_tables <- function() {
  if (is.null(method_table_cache$tables)) {
    tables <- load_envharmonizer_tables(list(analytical_terms = "term_id", analytical_synonyms = NULL))
    synonyms <- as.data.frame(tables$analytical_synonyms)
    terms <- as.data.frame(tables$analytical_terms)
    method_table_cache$tables <- list(
      terms = terms,
      synonyms = synonyms,
      index = split(seq_len(nrow(synonyms)), synonyms$normalized_label),
      term_keys = normalize_method_key(terms$preferred_label)
    )
  }
  method_table_cache$tables
}

method_table_cache <- new.env(parent = emptyenv())

# Vectorised over distinct values; returns component rows tagged with `vid`, the
# index into `values`. Every value yields at least one row.
method_lookup_rows <- function(values, tables) {
  terms <- tables$terms
  syn <- tables$synonyms
  keys <- normalize_method_key(values)
  hits <- tables$index[ifelse(is.na(keys), "", keys)]
  vid <- rep(seq_along(values), lengths(hits))
  pos <- unlist(hits, use.names = FALSE)
  keep <- is.na(syn$active[pos]) | syn$active[pos]
  vid <- vid[keep]
  pos <- pos[keep]
  # Reviewed AMOS decisions outrank ontology synonyms for the same label.
  curated <- syn$source[pos] %in% "amosharmonizer"
  has_curated <- vid %in% vid[curated]
  vid <- vid[curated | !has_curated]
  pos <- pos[curated | !has_curated]
  rows <- data.frame(
    vid = vid, term_id = syn$term_id[pos], analytical_role = syn$analytical_role[pos],
    component_order = as.integer(syn$component_order[pos]), match_type = syn$synonym_type[pos],
    assertion_mode = syn$assertion_mode[pos], confidence_tier = syn$confidence_tier[pos]
  )
  # Fall back to exact preferred labels when no synonym row survives.
  fallback <- setdiff(which(!is.na(keys)), vid)
  term_hits <- split(seq_len(nrow(terms)), factor(tables$term_keys, levels = unique(keys[fallback])))
  term_pos <- unlist(term_hits, use.names = FALSE)
  if (length(term_pos)) {
    rows <- rbind(rows, data.frame(
      vid = match(rep(names(term_hits), lengths(term_hits)), keys),
      term_id = terms$term_id[term_pos], analytical_role = terms$analytical_role[term_pos],
      component_order = 1L, match_type = "preferred_label", assertion_mode = "auto",
      confidence_tier = "high"
    ))
  }
  rows <- rows[!duplicated(rows[c("vid", "term_id", "analytical_role")]), , drop = FALSE]
  term_match <- match(rows$term_id, terms$term_id)
  missing_role <- is.na(rows$analytical_role) | !nzchar(rows$analytical_role)
  rows$analytical_role[missing_role] <- terms$analytical_role[term_match][missing_role]
  rows$preferred_label <- terms$preferred_label[term_match]
  rows$status <- rep("matched", nrow(rows))
  unresolved <- setdiff(seq_along(values), rows$vid)
  if (length(unresolved)) {
    rows <- rbind(rows, data.frame(
      vid = unresolved, term_id = NA_character_, analytical_role = NA_character_,
      component_order = NA_integer_, match_type = NA_character_, assertion_mode = NA_character_,
      confidence_tier = "unresolved", preferred_label = NA_character_, status = "queued"
    ))
  }
  rows <- rows[order(rows$vid, rows$component_order, na.last = TRUE), , drop = FALSE]
  rows[c("vid", "component_order", "term_id", "preferred_label", "analytical_role",
    "match_type", "assertion_mode", "confidence_tier", "status")]
}

#' Harmonize analytical-method strings
#'
#' Exact lookup of normalized labels against the pinned envharmonizer v0.1.1
#' analytical tables. One input can yield several ordered components (overall
#' method, separation, detection), so the result is long: one or more rows per
#' input row, never zero. Unmatched values get one row with
#' `confidence_tier = "unresolved"` and `status = "queued"`.
#'
#' @param raw_method Character vector of method strings.
#' @param orig_row_id Row ids aligned with `raw_method`.
#' @return Tibble with orig_row_id, raw_method, component_order, term_id,
#'   preferred_label, analytical_role, match_type, assertion_mode,
#'   confidence_tier, status and artifact_version.
#' @export
harmonize_methodology <- function(raw_method, orig_row_id = seq_along(raw_method)) {
  if (length(raw_method) != length(orig_row_id)) {
    stop("raw_method and orig_row_id must have equal lengths.", call. = FALSE)
  }
  raw_method <- as.character(raw_method)
  tables <- get_method_tables()
  if (length(raw_method) == 0L) {
    return(harmonize_methodology(NA_character_)[0, ])
  }
  # Look up each distinct value once, then expand back to input rows.
  values <- unique(raw_method)
  combined <- method_lookup_rows(values, tables)
  counts <- tabulate(combined$vid, nbins = length(values))
  starts <- cumsum(c(0L, counts))[seq_along(values)]
  value_idx <- match(raw_method, values)
  input_idx <- rep(seq_along(raw_method), counts[value_idx])
  positions <- starts[value_idx[input_idx]] + sequence(counts[value_idx])
  combined$vid <- NULL
  result <- tibble::as_tibble(combined[positions, , drop = FALSE])
  tibble::add_column(result,
    orig_row_id = as.integer(orig_row_id)[input_idx],
    raw_method = raw_method[input_idx],
    .before = 1L
  ) |>
    dplyr::mutate(artifact_version = media_artifact_version())
}
