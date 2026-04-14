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

  for (i in seq_along(x)) {
    val <- x[i]
    if (is.na(val)) next

    m <- regmatches(val, regexpr("^\\s*(<=|>=|<|>|~|=)\\s*(.*)", val, perl = TRUE))
    if (length(m) > 0) {
      # Extract groups
      parts <- regmatches(val, regexec("^\\s*(<=|>=|<|>|~|=)\\s*(.*)", val, perl = TRUE))[[1]]
      if (length(parts) >= 3) {
        qual[i] <- parts[2]
        remainder[i] <- parts[3]
      }
    }
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
  is_narrative <- logical(length(x))

  for (i in seq_along(x)) {
    val <- x[i]
    # NA or empty/whitespace-only
    if (is.na(val) || nchar(trimws(val)) == 0) {
      is_narrative[i] <- TRUE
      next
    }
    # Known narrative terms (case-insensitive)
    if (trimws(tolower(val)) %in% NARRATIVE_TERMS) {
      is_narrative[i] <- TRUE
    }
  }

  is_narrative
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

  for (i in seq_len(n)) {
    val <- remainder[i]
    qual <- qualifier[i]

    # Pre-guard (a): qualified values are never ranges (D-04)
    if (!is.na(qual) && nchar(qual) > 0) {
      next
    }

    if (is.na(val)) next

    # Pre-guard (b): Fortran exponent patterns (e.g., "4.56-02") are NOT ranges.
    # Fortran exponent signature: decimal mantissa (digits.digits) followed by +/- then
    # PURE integer digits at end of string, no existing e/E present.
    # Key distinction from real ranges: the Fortran exponent part is pure digits (no decimal),
    # while a range's second bound may have a decimal (e.g., "0.5-1.0").
    # Pattern: [digits].[digits][+-][pure_digits_only]$
    is_fortran <- !grepl("[eE]", val) &
      grepl("^[+-]?[0-9]+\\.[0-9]+[+-][0-9]+$", val)
    if (is_fortran) next

    m <- regmatches(val, regexec(range_re, val, perl = TRUE))[[1]]
    if (length(m) == 3) {
      lo <- suppressWarnings(as.numeric(m[2]))
      hi <- suppressWarnings(as.numeric(m[3]))
      if (!is.na(lo) && !is.na(hi)) {
        is_range[i] <- TRUE
        low[i] <- lo
        mid[i] <- (lo + hi) / 2
        high[i] <- hi
      }
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
#' @importFrom dplyr bind_rows
#' @export
parse_numeric_results <- function(values) {
  # Step 1 (PARS-05): capture orig_result before any transformation
  orig_result <- values

  # Step 2: assign orig_row_id
  orig_row_id <- seq_along(values)

  # Step 3a: partial normalization (unicode, x10^, commas, whitespace) — BEFORE Fortran exponents
  # This is the form used for range detection: Fortran exponent normalization would convert
  # "5-10" -> "5e-10", destroying the range separator. Ranges must be detected first.
  pre_norm <- values
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
  normalized <- normalize_numeric_string(values)

  # Step 4: extract qualifiers from fully normalized form (for non-range values)
  qe <- extract_qualifier(normalized)
  qualifier <- qe$qualifier
  remainder <- qe$remainder

  # Step 5: detect narratives
  is_narrative <- detect_narrative(remainder)

  # Step 6: build per-row results, expanding ranges to 3 rows
  row_list <- vector("list", length(values))

  n_unparseable <- 0L

  for (i in seq_along(values)) {
    if (is_narrative[i]) {
      # Narrative: NA with flag
      row_list[[i]] <- tibble::tibble(
        orig_row_id = i,
        orig_result = orig_result[i],
        numeric_value = NA_real_,
        qualifier = qualifier[i],
        range_bin = "as_is",
        parse_flag = "narrative"
      )
    } else if (sr$is_range[i]) {
      # Range: expand to 3 rows (D-02, D-03)
      row_list[[i]] <- tibble::tibble(
        orig_row_id = rep(i, 3L),
        orig_result = rep(orig_result[i], 3L),
        numeric_value = c(sr$low[i], sr$mid[i], sr$high[i]),
        qualifier = c(">=", "~", "<="),
        range_bin = c("low", "mid", "high"),
        parse_flag = c("", "", "")
      )
    } else {
      # Single value: attempt as.numeric
      val <- suppressWarnings(as.numeric(remainder[i]))
      if (!is.na(val)) {
        row_list[[i]] <- tibble::tibble(
          orig_row_id = i,
          orig_result = orig_result[i],
          numeric_value = val,
          qualifier = qualifier[i],
          range_bin = "as_is",
          parse_flag = ""
        )
      } else {
        n_unparseable <- n_unparseable + 1L
        row_list[[i]] <- tibble::tibble(
          orig_row_id = i,
          orig_result = orig_result[i],
          numeric_value = NA_real_,
          qualifier = qualifier[i],
          range_bin = "as_is",
          parse_flag = "unparseable"
        )
      }
    }
  }

  # Step 7 (D-13): warn if any unparseable
  if (n_unparseable > 0L) {
    warning(paste0(n_unparseable, " values could not be parsed"))
  }

  # Step 8: assemble final tibble preserving orig_row_id order
  dplyr::bind_rows(row_list)
}
