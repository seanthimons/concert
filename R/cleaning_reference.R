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

reference_list_schema_cols <- function() {
  c("term", "pattern", "match_mode", "source", "active", "notes")
}

reference_list_valid_match_modes <- function() {
  c("literal_exact", "literal_word", "regex")
}

reference_list_type_from_label <- function(label) {
  label_map <- c(
    "functional category" = "functional_categories",
    "stop word" = "stop_words",
    "block pattern" = "block_patterns",
    "strip term" = "strip_terms"
  )

  if (!label %in% names(label_map)) {
    return(NULL)
  }
  unname(label_map[[label]])
}

legacy_regex_term <- function(term) {
  tokens <- c("\\w", "\\d", "\\s", "+", "*", "^", "$", "?", "(", ")", "[", "]", "{", "}", "|")
  vapply(
    as.character(term),
    function(value) {
      if (is.na(value) || !nzchar(value)) {
        return(FALSE)
      }
      any(vapply(tokens, grepl, logical(1), x = value, fixed = TRUE))
    },
    logical(1)
  )
}

reference_list_default_match_mode <- function(type = NULL, term = character()) {
  n <- length(term)
  if (n == 0) {
    return(character(0))
  }

  type <- if (is.null(type)) NULL else normalize_reference_list_type(type, allow_functional = TRUE)

  if (identical(type, "block_patterns")) {
    return(rep("regex", n))
  }

  if (identical(type, "strip_terms")) {
    return(ifelse(legacy_regex_term(term), "regex", "literal_word"))
  }

  rep("literal_word", n)
}

normalize_reference_pattern <- function(pattern, term) {
  pattern <- as.character(pattern)
  term <- as.character(term)
  pattern[is.na(pattern) | !nzchar(trimws(pattern))] <- term[is.na(pattern) | !nzchar(trimws(pattern))]
  trimws(pattern)
}

normalize_reference_list_tbl <- function(tbl, type = NULL) {
  if (is.null(tbl)) {
    return(empty_reference_list_tbl())
  }

  required_cols <- c("term", "source", "active")
  if (!is.data.frame(tbl) || !all(required_cols %in% names(tbl))) {
    stop("Reference list entries must be data frames with term, source, and active columns.", call. = FALSE)
  }

  raw <- tibble::as_tibble(tbl)
  term <- trimws(as.character(raw$term))
  keep <- !is.na(term) & nzchar(term)

  if (!any(keep)) {
    return(empty_reference_list_tbl())
  }

  term <- term[keep]
  pattern <- if ("pattern" %in% names(raw)) raw$pattern[keep] else term
  pattern <- normalize_reference_pattern(pattern, term)

  match_mode <- if ("match_mode" %in% names(raw)) {
    tolower(trimws(as.character(raw$match_mode[keep])))
  } else {
    reference_list_default_match_mode(type, term)
  }
  default_modes <- reference_list_default_match_mode(type, term)
  match_mode[is.na(match_mode) | !nzchar(match_mode)] <- default_modes[is.na(match_mode) | !nzchar(match_mode)]

  invalid_modes <- setdiff(unique(match_mode), reference_list_valid_match_modes())
  if (length(invalid_modes) > 0) {
    stop(
      sprintf(
        "Invalid reference list match_mode value(s): %s. Expected one of: %s",
        paste(invalid_modes, collapse = ", "),
        paste(reference_list_valid_match_modes(), collapse = ", ")
      ),
      call. = FALSE
    )
  }

  notes <- if ("notes" %in% names(raw)) as.character(raw$notes[keep]) else rep(NA_character_, length(term))
  notes[is.na(notes) | notes == "NA"] <- NA_character_

  tibble::tibble(
    term = unname(term),
    pattern = unname(pattern),
    match_mode = unname(match_mode),
    source = unname(as.character(raw$source[keep])),
    active = unname(as.logical(raw$active[keep])),
    notes = unname(notes)
  )
}

#' Validate reference-list patterns
#'
#' @param reference_list Reference-list tibble.
#' @param type Optional normalized reference-list type.
#' @return Tibble with term, severity, and message columns.
#' @export
validate_reference_list_patterns <- function(reference_list, type = NULL) {
  refs <- normalize_reference_list_tbl(reference_list, type)
  if (nrow(refs) == 0) {
    return(tibble::tibble(
      term = character(),
      severity = character(),
      message = character()
    ))
  }

  issues <- list()
  add_issue <- function(term, severity, message) {
    issues[[length(issues) + 1]] <<- tibble::tibble(
      term = term,
      severity = severity,
      message = message
    )
  }

  type <- if (is.null(type)) NULL else normalize_reference_list_type(type, allow_functional = TRUE)

  for (i in seq_len(nrow(refs))) {
    pattern <- refs$pattern[i]
    if (is.na(pattern) || !nzchar(trimws(pattern))) {
      add_issue(refs$term[i], "error", "Pattern is empty.")
      next
    }

    if (identical(refs$match_mode[i], "regex")) {
      valid_regex <- tryCatch(
        {
          suppressWarnings(grepl(pattern, "", perl = TRUE))
          TRUE
        },
        error = function(e) FALSE
      )
      if (!valid_regex) {
        add_issue(refs$term[i], "error", "Regex pattern is invalid.")
        next
      }

      unanchored <- !startsWith(pattern, "^") && !endsWith(pattern, "$")
      simple_literal <- grepl("^[[:alnum:][:space:]/-]+$", pattern)
      if (identical(type, "block_patterns") && unanchored && simple_literal) {
        add_issue(
          refs$term[i],
          "warning",
          "Unanchored literal-like block regex can match inside valid chemical names; use anchors for exact-value blocking."
        )
      } else if (identical(type, "block_patterns") && unanchored && nchar(pattern) < 4) {
        add_issue(
          refs$term[i],
          "warning",
          "Very short unanchored block regex is likely to over-match."
        )
      }
    }
  }

  if (length(issues) == 0) {
    return(tibble::tibble(
      term = character(),
      severity = character(),
      message = character()
    ))
  }

  dplyr::bind_rows(issues)
}

#' Reference-list help text
#'
#' @param type Reference-list type.
#' @return Character scalar describing the reference-list type.
#' @export
reference_list_help_text <- function(type) {
  type <- normalize_reference_list_type(type, allow_functional = TRUE)
  switch(
    type,
    functional_categories = "Terms that indicate product function or use category rather than a specific chemical identity. Matches create warning flags for curator review.",
    stop_words = "Literal words or phrases that suggest the name is generic, ambiguous, placeholder-like, or not a specific analyte. These create warning flags; they do not rewrite the name.",
    block_patterns = "Regex patterns for hard invalid, redacted, or not-searchable values. These create BLOCK flags. Use anchors like ^alcohol$ for exact-value blocking; unanchored regex can match inside valid chemical names.",
    strip_terms = "Words or regex patterns to remove from names when deletion preserves the intended chemical identity, such as pure acetone to acetone. These modify the name field."
  )
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

  normalize_reference_list_tbl(load_or_fetch_reference(cache_path, fetch_fn, "stop words"), "stop_words")
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

  normalize_reference_list_tbl(load_or_fetch_reference(cache_path, fetch_fn, "block patterns"), "block_patterns")
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

  normalize_reference_list_tbl(load_or_fetch_reference(cache_path, fetch_fn, "functional categories"), "functional_categories")
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

  normalize_reference_list_tbl(load_or_fetch_reference(cache_path, fetch_fn, "strip terms"), "strip_terms")
}

user_reference_list_names <- function() {
  c("stop_words", "block_patterns", "strip_terms")
}

cleaning_reference_list_names <- function() {
  c("functional_categories", user_reference_list_names())
}

empty_reference_list_tbl <- function() {
  tibble::tibble(
    term = character(),
    pattern = character(),
    match_mode = character(),
    source = character(),
    active = logical(),
    notes = character()
  )
}

empty_user_reference_lists <- function() {
  stats::setNames(
    rep(list(empty_reference_list_tbl()), length(user_reference_list_names())),
    user_reference_list_names()
  )
}

normalize_reference_list_type <- function(type, allow_functional = FALSE) {
  type_map <- c(
    functional_category = "functional_categories",
    functional_categories = "functional_categories",
    stop_word = "stop_words",
    stop_words = "stop_words",
    block_pattern = "block_patterns",
    block_patterns = "block_patterns",
    strip_term = "strip_terms",
    strip_terms = "strip_terms"
  )

  if (!allow_functional) {
    type_map <- type_map[!type_map %in% "functional_categories"]
  }

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

merge_reference_list_rows <- function(default_tbl, user_tbl, type = NULL) {
  dplyr::bind_rows(
    normalize_reference_list_tbl(user_tbl, type),
    normalize_reference_list_tbl(default_tbl, type)
  ) %>%
    dplyr::distinct(term, .keep_all = TRUE)
}

activate_all_reference_terms <- function(reference_lists) {
  if (is.null(reference_lists)) {
    return(reference_lists)
  }

  for (type in cleaning_reference_list_names()) {
    if (
      !is.null(reference_lists[[type]]) &&
        is.data.frame(reference_lists[[type]]) &&
        "active" %in% names(reference_lists[[type]])
    ) {
      reference_lists[[type]]$active <- TRUE
    }
  }

  reference_lists
}

normalize_reference_snapshot_tbl <- function(tbl, type) {
  normalize_reference_list_tbl(tbl, type) %>%
    dplyr::select(dplyr::all_of(reference_list_schema_cols())) %>%
    dplyr::distinct(term, .keep_all = TRUE) %>%
    dplyr::arrange(term)
}

reference_snapshot_hash <- function(tbl, type) {
  digest::digest(
    normalize_reference_snapshot_tbl(tbl, type),
    algo = "sha256"
  )
}

reference_scalar_equal <- function(a, b) {
  if (identical(a, b)) {
    return(TRUE)
  }

  if (length(a) != 1 || length(b) != 1) {
    return(FALSE)
  }

  a_na <- tryCatch(is.na(a), error = function(e) FALSE)
  b_na <- tryCatch(is.na(b), error = function(e) FALSE)

  isTRUE(a_na) && isTRUE(b_na)
}

reference_rows_equal <- function(a, b) {
  cols <- reference_list_schema_cols()
  all(vapply(
    cols,
    function(col) reference_scalar_equal(a[[col]], b[[col]]),
    logical(1)
  ))
}

load_default_cleaning_reference_lists <- function(cache_dir = NULL) {
  cache_dir <- resolve_reference_cache_dir(cache_dir)

  list(
    functional_categories = load_functional_categories(cache_dir),
    stop_words = load_stop_words(cache_dir),
    block_patterns = load_block_patterns(cache_dir),
    strip_terms = load_strip_terms(cache_dir)
  )
}

load_all_default_reference_lists <- function(cache_dir = NULL) {
  cache_dir <- resolve_reference_cache_dir(cache_dir)

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
    media_map = load_media_map(cache_dir)
  )
}

reference_list_snapshot_overrides <- function(reference_list, default_list, type) {
  current <- normalize_reference_snapshot_tbl(reference_list, type)
  defaults <- normalize_reference_snapshot_tbl(default_list, type)

  if (nrow(current) == 0) {
    return(empty_reference_list_tbl())
  }

  default_index <- match(current$term, defaults$term)
  include <- is.na(default_index)

  matched <- which(!is.na(default_index))
  for (idx in matched) {
    default_row <- defaults[default_index[idx], , drop = FALSE]
    include[idx] <- !reference_rows_equal(current[idx, , drop = FALSE], default_row)
  }

  current[include, , drop = FALSE]
}

build_reference_list_snapshot <- function(reference_lists, cache_dir = NULL) {
  if (is.null(reference_lists)) {
    return(NULL)
  }

  missing_types <- setdiff(cleaning_reference_list_names(), names(reference_lists))
  if (length(missing_types) > 0) {
    stop(
      sprintf(
        "reference_lists is missing required snapshot keys: %s",
        paste(missing_types, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  defaults <- load_default_cleaning_reference_lists(cache_dir)
  snapshot <- lapply(cleaning_reference_list_names(), function(type) {
    list(
      default_hash = reference_snapshot_hash(defaults[[type]], type),
      overrides = reference_list_snapshot_overrides(reference_lists[[type]], defaults[[type]], type)
    )
  })
  names(snapshot) <- cleaning_reference_list_names()
  snapshot
}

reconstruct_reference_list_snapshot <- function(reference_list_snapshot, cache_dir = NULL, reference_lists = NULL) {
  if (is.null(reference_list_snapshot)) {
    return(reference_lists)
  }

  if (is.null(reference_lists)) {
    reference_lists <- load_all_default_reference_lists(cache_dir)
  }

  missing_types <- setdiff(cleaning_reference_list_names(), names(reference_list_snapshot))
  if (length(missing_types) > 0) {
    stop(
      sprintf(
        "reference_list_snapshot is missing required keys: %s",
        paste(missing_types, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  for (type in cleaning_reference_list_names()) {
    entry <- reference_list_snapshot[[type]]
    if (!is.list(entry) || is.null(entry$default_hash) || is.null(entry$overrides)) {
      stop(
        sprintf("reference_list_snapshot entry '%s' is malformed.", type),
        call. = FALSE
      )
    }

    current_hash <- reference_snapshot_hash(reference_lists[[type]], type)
    if (!identical(as.character(entry$default_hash), current_hash)) {
      stop(
        sprintf(
          "reference_list_snapshot default hash mismatch for '%s'. Regenerate the replay script with current package defaults.",
          type
        ),
        call. = FALSE
      )
    }

    reference_lists[[type]] <- merge_reference_list_rows(
      reference_lists[[type]],
      entry$overrides,
      type
    )
  }

  reference_lists
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
        empty_lists[[type]] <- normalize_reference_list_tbl(raw[[type]], type)
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
    sidecar[[type]] <- normalize_reference_list_tbl(reference_lists[[type]], type) %>%
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
#' @param match_mode Optional matching mode. One of `literal_word`,
#'   `literal_exact`, or `regex`.
#' @param pattern Optional pattern to store separately from `term`. Defaults
#'   to `term`.
#' @param notes Optional notes for the reference-list row.
#' @param action One of add, remove, or toggle.
#' @param cache_dir Directory for reference cache files. Defaults to the bundled
#'   package/source reference cache.
#' @return Tibble containing packaged defaults merged with user overrides.
#' @export
update_user_reference_list <- function(
  type,
  term,
  active = TRUE,
  match_mode = NULL,
  pattern = NULL,
  notes = NA_character_,
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
  current_tbl <- merge_reference_list_rows(defaults, user_tbl, type)
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

    new_row <- if (length(current_idx) > 0) {
      current_tbl[current_idx[1], , drop = FALSE]
    } else {
      tibble::tibble(
        term = term,
        pattern = if (is.null(pattern)) term else pattern,
        match_mode = if (is.null(match_mode)) reference_list_default_match_mode(type, term) else match_mode,
        source = "user",
        active = new_active,
        notes = notes
      )
    }
    new_row$source <- "user"
    new_row$active <- new_active
    if (!is.null(match_mode)) {
      new_row$match_mode <- match_mode
    }
    if (!is.null(pattern)) {
      new_row$pattern <- pattern
    }
    if (!is.null(notes)) {
      new_row$notes <- notes
    }
    new_row <- normalize_reference_list_tbl(new_row, type)

    if (isTRUE(new_row$active[1])) {
      validation <- validate_reference_list_patterns(new_row, type)
      errors <- validation$severity == "error"
      if (any(errors)) {
        stop(paste(validation$message[errors], collapse = " "), call. = FALSE)
      }
      warnings <- validation$severity == "warning"
      if (any(warnings)) {
        warning(paste(validation$message[warnings], collapse = " "), call. = FALSE)
      }
    }

    if (length(user_idx) > 0) {
      user_tbl[user_idx[1], ] <- new_row
    } else {
      user_tbl <- dplyr::bind_rows(user_tbl, new_row)
    }
  }

  user_lists[[type]] <- user_tbl
  save_user_reference_lists(user_lists, cache_dir)
  merge_reference_list_rows(defaults, user_tbl, type)
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
      "nCi/L", "uCi/L", "\u00b5Ci/L", "mCi/L", "Ci/L",
      "Bq/L", "Bq/l", "Bq per L", "Bq per liter", "Bq per litre",
      "mBq/L", "mBq per L", "mBq per liter", "mBq per litre",
      "uBq/L", "uBq per L", "uBq per liter", "uBq per litre",
      "\u00b5Bq/L", "\u00b5Bq per L", "\u00b5Bq per liter", "\u00b5Bq per litre",
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
      "nCi", "uCi", "\u00b5Ci", "mCi", "Ci",
      "Bq", "mBq", "uBq", "\u00b5Bq", "kBq"
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

#' Load merged media harmonization map (user edits + bundled defaults)
#'
#' User rows (user_media_map.rds) take precedence for the same term.
#' Falls back to the generated media cache via get_media_table() for all other
#' terms.
#' Returns a display-schema tibble with columns for the media editor DT
#' plus the additional columns harmonize_media() needs internally
#' (canonical_term, envo_id, media_category, assertion_mode, confidence) when
#' passed as media_map parameter.
#'
#' On first run, if user_media_map.rds does not exist, the function returns
#' the generated media table normalised to the merged schema. If get_media_table()
#' also returns NULL (e.g., amos_media.rds not yet built), the function
#' returns an empty tibble with the correct column types.
#'
#' @param cache_dir Directory for cache files (e.g., "inst/extdata/reference_cache")
#' @return Tibble with columns: term, canonical, canonical_term, envo_id,
#'   parent, media_category, source, fetch_timestamp, assertion_mode,
#'   confidence, active
#' @export
load_media_map <- function(cache_dir) {
  user_path <- file.path(cache_dir, "user_media_map.rds")
  user_map <- if (file.exists(user_path)) readRDS(user_path) else NULL

  amos_raw <- get_media_table()

  amos_map <- normalize_media_map_for_display(amos_raw)

  if (!is.null(user_map) && nrow(user_map) > 0) {
    user_map <- normalize_media_map_for_display(user_map)
    user_map$source <- "user"
    user_map$assertion_mode <- "user"
    amos_fallback <- amos_map[!amos_map$term %in% user_map$term, , drop = FALSE]
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
      user_reference_lists[[type]],
      type
    )
  }

  reference_lists
}

# Internal function - builds WQX dictionary from EPA domain value CSVs
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
#' infrastructure - builds the dictionary from EPA data on first call if no
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
