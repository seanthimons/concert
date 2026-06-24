# numeric_parser.R
# Core numeric result parser: normalization chain, qualifier extraction, and single-value parsing.
#
# Public API: parse_numeric_results()
# Internal helpers: normalize_numeric_string(), extract_qualifier(), detect_narrative()

# Known narrative strings (case-insensitive matching)
NARRATIVE_TERMS <- c(
  "bdl", "nd", "non-detect", "nondetect", "trace", "not detected",
  "below detection", "below quantitation", "bql", "lod", "loq"
)

#' Normalize a raw numeric string
#'
#' Applies a chain of normalizations to prepare a raw result string for numeric parsing.
#' Normalization order:
#'   (a) Replace unicode qualifiers: >= -> >=, <= -> <=
#'   (b) Replace x10^ and X10^ with e (scientific notation)
#'   (c) Detect Fortran exponents: digits followed by +/- digits at end of string (no e/E)
#'   (d) Strip commas between digits
#'   (e) Squish whitespace (collapse internal, trim edges)
#'
#' @param x Character vector of raw result strings
#' @return Character vector of normalized strings
normalize_numeric_string <- function(x) {
  # (a) Unicode qualifiers
  x <- gsub("\u2265", ">=", x, fixed = TRUE)
  x <- gsub("\u2264", "<=", x, fixed = TRUE)

  # (b) x10^ notation -> e notation (case-insensitive)
  x <- gsub("[xX]10\\^", "e", x)

  # (c) Fortran exponents: e.g. "4.56+02" or "4.56-02" (no e/E already present)
  # Condition: only apply when no 'e' or 'E' exists in the string already
  x <- ifelse(
    !grepl("[eE]", x) & grepl("(\\d)([+-])(\\d+)$", x),
    gsub("(\\d)([+-])(\\d+)$", "\\1e\\2\\3", x),
    x
  )

  # (d) Strip commas between digits (multi-pass for chains like 1,234,567)
  for (pass in 1:3) {
    x <- gsub("(\\d),(\\d)", "\\1\\2", x)
  }

  # (e) Squish whitespace (collapse runs, trim edges)
  x <- gsub("\\s+", " ", x)
  x <- trimws(x)

  x
}

#' Extract qualifier prefix from normalized string
#'
#' Parses a leading qualifier from a normalized numeric string.
#' Supported qualifiers (in order of priority): <=, >=, <, >, ~, =
#' Per D-07: no qualifier found -> qualifier = ""
#'
#' @param x Character vector (already normalized)
#' @return Named list with two character vectors: `qualifier` and `remainder`
extract_qualifier <- function(x) {
  # Match longest qualifier first (<=, >= before <, >)
  qual <- rep("", length(x))
  remainder <- x

  matches <- regmatches(x, regexec("^\\s*(<=|>=|<|>|~|=)\\s*(.*)", x, perl = TRUE))
  matched <- lengths(matches) >= 3L
  if (any(matched)) {
    qual[matched] <- vapply(matches[matched], `[`, character(1), 2L)
    remainder[matched] <- vapply(matches[matched], `[`, character(1), 3L)
  }

  list(qualifier = qual, remainder = remainder)
}

#' Detect narrative (non-numeric) values
#'
#' Identifies values that represent qualitative descriptions rather than numbers.
#' Flags: known narrative terms (BDL, ND, etc.), empty strings, NA, whitespace-only.
#'
#' @param x Character vector (remainder after qualifier extraction)
#' @return Logical vector, TRUE = narrative
detect_narrative <- function(x) {
  trimmed <- trimws(x)
  is.na(trimmed) | !nzchar(trimmed) | tolower(trimmed) %in% NARRATIVE_TERMS
}

#' Detect and split range values
#'
#' Determines whether a normalized remainder string represents a numeric range
#' (e.g., "5-10", "-10--5", "-10-5") rather than a negative number or scientific notation.
#' Returns split low/mid/high values for ranges.
#'
#' Pre-guard order (per D-04):
#'   (a) If qualifier is non-empty, it is NOT a range (qualified values are single rows)
#'   (b) Apply range regex that captures optional leading negative, full decimal/exponent numbers,
#'       then a hyphen separator, then a second full number
#'   (c) Negative sign immediately after 'e'/'E' is part of exponent, not a range separator
#'
#' @param remainder Character vector (post-qualifier-extraction, post-normalization)
#' @param qualifier Character vector (matching length, from extract_qualifier)
#' @return A list with logical `is_range`, numeric `low`, `mid`, `high` (NA for non-ranges)
split_ranges <- function(remainder, qualifier) {
  n <- length(remainder)
  is_range <- logical(n)
  low <- rep(NA_real_, n)
  mid <- rep(NA_real_, n)
  high <- rep(NA_real_, n)

  # Range regex: optional leading negative, digits with optional decimal and optional exponent,
  # then a literal hyphen (not after e/E), then optional negative, digits/decimal/exponent
  # Pattern: ^(-?<number>)\s*-\s*(-?<number>)$
  # A number is: optional minus, digits, optional .digits, optional e/E with optional +/- and digits
  range_re <- "^(-?\\d+\\.?\\d*(?:[eE][+-]?\\d+)?)\\s*-\\s*(-?\\d+\\.?\\d*(?:[eE][+-]?\\d+)?)$"

  eligible <- (is.na(qualifier) | !nzchar(qualifier)) & !is.na(remainder)
  if (!any(eligible)) {
    return(list(is_range = is_range, low = low, mid = mid, high = high))
  }

  candidate_ids <- which(eligible)
  candidate_values <- remainder[candidate_ids]

  # Pre-guard (b): Fortran exponent patterns (e.g., "4.56-02") are NOT ranges.
  is_fortran <- !grepl("[eE]", candidate_values) &
    grepl("^[+-]?[0-9]+\\.[0-9]+[+-][0-9]+$", candidate_values)
  candidate_ids <- candidate_ids[!is_fortran]
  candidate_values <- candidate_values[!is_fortran]
  if (length(candidate_ids) == 0) {
    return(list(is_range = is_range, low = low, mid = mid, high = high))
  }

  matches <- regmatches(candidate_values, regexec(range_re, candidate_values, perl = TRUE))
  matched <- lengths(matches) == 3L
  if (any(matched)) {
    matched_ids <- candidate_ids[matched]
    lo <- suppressWarnings(as.numeric(vapply(matches[matched], `[`, character(1), 2L)))
    hi <- suppressWarnings(as.numeric(vapply(matches[matched], `[`, character(1), 3L)))
    valid <- !is.na(lo) & !is.na(hi)
    if (any(valid)) {
      valid_ids <- matched_ids[valid]
      is_range[valid_ids] <- TRUE
      low[valid_ids] <- lo[valid]
      mid[valid_ids] <- (lo[valid] + hi[valid]) / 2
      high[valid_ids] <- hi[valid]
    }
  }

  list(is_range = is_range, low = low, mid = mid, high = high)
}

#' Parse messy numeric result strings into a structured tibble
#'
#' Handles whitespace, commas, scientific notation (x10^, Fortran exponents, standard e),
#' qualifier extraction (<, >, <=, >=, ~, =), unicode qualifiers (>=, <=),
#' narrative detection (BDL, ND, trace, etc.), range splitting (5-10 -> 3 rows),
#' and unparseable values.
#'
#' Range splitting (PARS-03): "5-10" becomes 3 rows per D-02 and D-03:
#'   - low row: qualifier=">=", range_bin="low"
#'   - mid row: qualifier="~", range_bin="mid"
#'   - high row: qualifier="<=", range_bin="high"
#' Negative numbers (-5) and scientific notation (1e-3) are NOT split (numeric pre-guard).
#'
#' Implementation note: range detection runs on a pre-Fortran-normalized form. This is critical
#' because the Fortran exponent normalizer converts "5-10" to "5e-10" (matches digit-minus-digits
#' pattern). Ranges are detected first, then Fortran normalization applies only to non-range values.
#'
#' @param values Character vector of raw result strings
#' @return A tibble with columns: orig_row_id, orig_result, numeric_value, qualifier,
#'   range_bin, parse_flag. Range values produce 3 rows sharing the same orig_row_id.
#'
#' @examples
#' parse_numeric_results(c("< 5.0", "2.5x10^3", "BDL", "4.56+02", "\u2265100"))
#' parse_numeric_results(c("5-10", "-5", "1e-3"))
#'
#' @importFrom tibble tibble
#' @export
parse_numeric_results <- function(values) {
  if (is.numeric(values)) {
    n <- length(values)
    is_missing <- is.na(values)
    parse_flag <- rep("", n)
    parse_flag[is_missing] <- "narrative"
    return(tibble::tibble(
      orig_row_id = seq_len(n),
      orig_result = as.character(values),
      numeric_value = as.numeric(values),
      qualifier = rep("", n),
      range_bin = rep("as_is", n),
      parse_flag = parse_flag
    ))
  }

  # Step 1 (PARS-05): capture orig_result before any transformation
  orig_result <- as.character(values)

  # Step 2: assign orig_row_id
  orig_row_id <- seq_along(values)

  # Step 3a: partial normalization (unicode, x10^, commas, whitespace) — BEFORE Fortran exponents
  # This is the form used for range detection: Fortran exponent normalization would convert
  # "5-10" -> "5e-10", destroying the range separator. Ranges must be detected first.
  pre_norm <- orig_result
  # (a) Unicode qualifiers
  pre_norm <- gsub("\u2265", ">=", pre_norm, fixed = TRUE)
  pre_norm <- gsub("\u2264", "<=", pre_norm, fixed = TRUE)
  # (b) x10^ notation
  pre_norm <- gsub("[xX]10\\^", "e", pre_norm)
  # (d) Strip commas (3-pass)
  for (pass in 1:3) pre_norm <- gsub("(\\d),(\\d)", "\\1\\2", pre_norm)
  # (e) Squish whitespace
  pre_norm <- gsub("\\s+", " ", pre_norm)
  pre_norm <- trimws(pre_norm)

  # Step 3b: extract qualifiers from pre-norm form (for range pre-guard)
  qe_pre <- extract_qualifier(pre_norm)

  # Step 5b: detect ranges on pre-Fortran-normalized form
  sr <- split_ranges(qe_pre$remainder, qe_pre$qualifier)

  # Step 3c: full normalization for non-range values (adds Fortran exponent step)
  normalized <- normalize_numeric_string(orig_result)

  # Step 4: extract qualifiers from fully normalized form (for non-range values)
  qe <- extract_qualifier(normalized)
  qualifier <- qe$qualifier
  remainder <- qe$remainder

  # Step 5: detect narratives
  is_narrative <- detect_narrative(remainder)

  # Step 6: build results in bulk, expanding only range rows.
  single_ids <- which(!sr$is_range)
  range_ids <- which(sr$is_range)

  single_numeric <- suppressWarnings(as.numeric(remainder[single_ids]))
  single_parse_flag <- rep("", length(single_ids))
  single_parse_flag[is_narrative[single_ids]] <- "narrative"
  unparseable <- !is_narrative[single_ids] & is.na(single_numeric)
  single_parse_flag[unparseable] <- "unparseable"
  single_numeric[single_parse_flag != ""] <- NA_real_

  n_unparseable <- sum(unparseable)

  single_order <- single_ids * 10L
  range_order <- integer(0)
  if (length(range_ids) > 0) {
    range_order <- rep(range_ids * 10L, each = 3L) + rep(seq_len(3L), times = length(range_ids))
  }

  out <- tibble::tibble(
    orig_row_id = c(single_ids, rep(range_ids, each = 3L)),
    orig_result = c(orig_result[single_ids], rep(orig_result[range_ids], each = 3L)),
    numeric_value = c(
      single_numeric,
      as.vector(t(cbind(sr$low[range_ids], sr$mid[range_ids], sr$high[range_ids])))
    ),
    qualifier = c(qualifier[single_ids], rep(c(">=", "~", "<="), times = length(range_ids))),
    range_bin = c(rep("as_is", length(single_ids)), rep(c("low", "mid", "high"), times = length(range_ids))),
    parse_flag = c(single_parse_flag, rep("", length(range_ids) * 3L)),
    .row_order = c(single_order, range_order)
  )

  # Step 7 (D-13): warn if any unparseable
  if (n_unparseable > 0L) {
    warning(paste0(n_unparseable, " values could not be parsed"))
  }

  # Step 8: assemble final tibble preserving orig_row_id order
  out <- out[order(out$.row_order), , drop = FALSE]
  out$.row_order <- NULL
  out
}
