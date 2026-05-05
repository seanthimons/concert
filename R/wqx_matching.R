# wqx_matching.R
# Three-tier WQX Characteristic Name matcher
#
# Tier 1: exact canonical lookup (O(1) named vector)
# Tier 2: alias lookup resolving to canonical_name (O(1) named vector)
# Tier 3: Jaro-Winkler fuzzy fallback against canonical names only

#' Match chemical names against WQX Characteristic Name dictionary
#'
#' Runs a three-tier lookup: (1) exact canonical, (2) alias crosswalk,
#' (3) Jaro-Winkler fuzzy against canonical names only. Returns a tibble
#' with one row per input name.
#'
#' @param names Character vector of analyte names to match
#' @param dictionary Tibble from load_wqx_dictionary() with columns: name, canonical_name, type
#' @param threshold Numeric similarity threshold for fuzzy acceptance (default 0.85).
#'   Internally converted to JW distance cutoff: distance <= (1 - threshold).
#' @param verbose Logical. If TRUE, emits per-name cli output (default FALSE).
#' @return Tibble with columns: input_name, wqx_name, match_tier, match_distance, alias_type
#' @export
match_wqx <- function(names, dictionary, threshold = 0.85, verbose = FALSE) {
  # --- Empty-input guard ---
  if (length(names) == 0) {
    return(tibble::tibble(
      input_name = character(0),
      wqx_name = character(0),
      match_tier = character(0),
      match_distance = numeric(0),
      alias_type = character(0)
    ))
  }

  n <- length(names)

  # --- Pre-allocate result vectors ---
  input_name <- names
  wqx_name <- rep(NA_character_, n)
  match_tier <- rep("none", n)
  match_distance <- rep(NA_real_, n)
  alias_type <- rep(NA_character_, n)

  # --- Identify valid inputs (non-NA, non-empty after trimming) ---
  valid_idx <- which(!is.na(names) & trimws(names) != "")

  # --- Normalize once: lowercase + trim + ampersand swap ---
  names_clean <- tolower(trimws(names))
  names_clean <- gsub("\\s*&\\s*", " and ", names_clean)

  # --- Build hash tables from dictionary ---
  # Tier 1: canonical rows only
  canonical_rows <- dictionary[dictionary$type == "canonical", ]

  # Tier 2: alias rows (synonym, standardize, retired)
  alias_rows <- dictionary[dictionary$type %in% c("synonym", "standardize", "retired"), ]

  # Normalize keys: lowercase + trim + & -> and
  normalize_key <- function(x) gsub("\\s*&\\s*", " and ", tolower(trimws(x)))

  # Deduplicate alias keys: prioritize standardize > synonym > retired,
  # then keep first row per normalized name
  alias_type_priority <- c("standardize" = 1L, "synonym" = 2L, "retired" = 3L)
  alias_rows <- alias_rows[order(alias_type_priority[alias_rows$type]), ]
  alias_rows <- dplyr::distinct(
    dplyr::mutate(alias_rows, .lower_name = normalize_key(alias_rows$name)),
    .lower_name,
    .keep_all = TRUE
  )

  # O(1) named-vector maps
  tier1_map <- stats::setNames(canonical_rows$name, normalize_key(canonical_rows$name))
  tier2_map <- stats::setNames(alias_rows$canonical_name, alias_rows$.lower_name)
  tier2_type_map <- stats::setNames(alias_rows$type, alias_rows$.lower_name)

  # --- Tier 1: Exact canonical match ---
  tier1_hits <- tier1_map[names_clean[valid_idx]]
  tier1_resolved <- valid_idx[!is.na(tier1_hits)]
  unresolved_idx <- valid_idx[is.na(tier1_hits)]

  if (length(tier1_resolved) > 0) {
    wqx_name[tier1_resolved] <- tier1_hits[!is.na(tier1_hits)]
    match_tier[tier1_resolved] <- "exact"
    match_distance[tier1_resolved] <- NA_real_
    alias_type[tier1_resolved] <- NA_character_
  }

  # --- Tier 2: Alias lookup ---
  tier2_hits <- tier2_map[names_clean[unresolved_idx]]
  tier2_types <- tier2_type_map[names_clean[unresolved_idx]]
  tier2_resolved <- unresolved_idx[!is.na(tier2_hits)]
  still_unresolved_idx <- unresolved_idx[is.na(tier2_hits)]

  if (length(tier2_resolved) > 0) {
    resolved_hits <- tier2_hits[!is.na(tier2_hits)]
    resolved_types <- tier2_types[!is.na(tier2_hits)]
    wqx_name[tier2_resolved] <- resolved_hits
    match_tier[tier2_resolved] <- "alias"
    match_distance[tier2_resolved] <- NA_real_
    alias_type[tier2_resolved] <- resolved_types
  }

  # --- Tier 3: Fuzzy Jaro-Winkler match (canonical names only) ---
  # Only runs on unresolved remainder after tiers 1 and 2.
  # NOTE: At scale (1000+ unresolved × 23K canonical), this matrix is ~180MB RAM.
  # For Phase 45 (production wiring), consider chunked batching. See RESEARCH.md Pitfall 4.
  nearest_candidate <- rep(NA_character_, n)

  if (length(still_unresolved_idx) > 0) {
    canonical_name_vec <- canonical_rows$name

    # JW distance: 0 = identical, 1 = maximally different
    # cutoff = 1 - threshold (e.g., threshold 0.85 → cutoff 0.15)
    dist_matrix <- stringdist::stringdistmatrix(
      names_clean[still_unresolved_idx],
      tolower(canonical_name_vec),
      method = "jw"
    )

    best_dist <- apply(dist_matrix, 1, min)
    best_idx <- apply(dist_matrix, 1, which.min)
    best_match <- canonical_name_vec[best_idx]

    # JW distance: 0=identical, cutoff = 1 - threshold
    accepted <- best_dist <= (1 - threshold)

    # Vectorized assignment: all unresolved positions get distance and nearest candidate
    match_distance[still_unresolved_idx] <- best_dist
    nearest_candidate[still_unresolved_idx] <- best_match

    # Accepted fuzzy matches: assign wqx_name and tier in one batch operation
    fuzzy_pos <- still_unresolved_idx[accepted]
    if (length(fuzzy_pos) > 0) {
      wqx_name[fuzzy_pos] <- best_match[accepted]
      match_tier[fuzzy_pos] <- "fuzzy"
    }
    # Rejected positions: match_tier stays "none", wqx_name stays NA
  }

  # --- Verbose per-name logging ---
  # Emit one cli message per valid input; extract subsets by tier for batch processing.
  if (verbose && length(valid_idx) > 0) {
    exact_idx <- valid_idx[match_tier[valid_idx] == "exact"]
    alias_idx <- valid_idx[match_tier[valid_idx] == "alias"]
    fuzzy_idx <- valid_idx[match_tier[valid_idx] == "fuzzy"]
    none_idx <- valid_idx[match_tier[valid_idx] == "none"]

    # cli glue interpolation operates on vectors: each element becomes one message line
    if (length(exact_idx) > 0) {
      mapply(
        function(inp, wqx) cli::cli_alert_success("'{inp}' -> '{wqx}' [exact]"),
        input_name[exact_idx],
        wqx_name[exact_idx]
      )
    }
    if (length(alias_idx) > 0) {
      mapply(
        function(inp, wqx, atype) cli::cli_alert_success("'{inp}' -> '{wqx}' [alias/{atype}]"),
        input_name[alias_idx],
        wqx_name[alias_idx],
        alias_type[alias_idx]
      )
    }
    if (length(fuzzy_idx) > 0) {
      mapply(
        function(inp, wqx, dist) {
          cli::cli_alert_success("'{inp}' -> '{wqx}' [fuzzy, dist={sprintf('%.3f', dist)}]")
        },
        input_name[fuzzy_idx],
        wqx_name[fuzzy_idx],
        match_distance[fuzzy_idx]
      )
    }
    if (length(none_idx) > 0) {
      mapply(
        function(inp, cand, dist) {
          if (!is.na(dist)) {
            cli::cli_alert_warning("'{inp}' -> unresolved (nearest: '{cand}', dist={sprintf('%.3f', dist)})")
          } else {
            cli::cli_alert_warning("'{inp}' -> unresolved (no candidates)")
          }
        },
        input_name[none_idx],
        nearest_candidate[none_idx],
        match_distance[none_idx]
      )
    }
  }

  # --- Summary logging (always emitted) ---
  n_exact <- sum(match_tier == "exact", na.rm = TRUE)
  n_alias <- sum(match_tier == "alias", na.rm = TRUE)
  n_fuzzy <- sum(match_tier == "fuzzy", na.rm = TRUE)
  n_none <- sum(match_tier == "none", na.rm = TRUE)
  cli::cli_inform(c(
    "v" = "WQX match complete: {n_exact} exact, {n_alias} alias, {n_fuzzy} fuzzy, {n_none} unresolved"
  ))

  # --- Return tibble ---
  tibble::tibble(
    input_name = names,
    wqx_name = wqx_name,
    match_tier = match_tier,
    match_distance = match_distance,
    alias_type = alias_type
  )
}
