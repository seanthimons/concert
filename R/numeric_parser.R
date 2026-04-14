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

#' Parse messy numeric result strings into a structured tibble
#'
#' Handles whitespace, commas, scientific notation (x10^, Fortran exponents, standard e),
#' qualifier extraction (<, >, <=, >=, ~, =), unicode qualifiers (>=, <=),
#' narrative detection (BDL, ND, trace, etc.), and unparseable values.
#'
#' @param values Character vector of raw result strings
#' @return A tibble with columns: orig_row_id, orig_result, numeric_value, qualifier,
#'   range_bin, parse_flag. One row per input value (range splitting handled in Plan 02).
#'
#' @examples
#' parse_numeric_results(c("< 5.0", "2.5x10^3", "BDL", "4.56+02", "\u2265100"))
#'
#' @importFrom tibble tibble
#' @importFrom dplyr mutate
#' @export
parse_numeric_results <- function(values) {
  # Step 1 (PARS-05): capture orig_result before any transformation
  orig_result <- values

  # Step 2: assign orig_row_id
  orig_row_id <- seq_along(values)

  # Step 3: normalize
  normalized <- normalize_numeric_string(values)

  # Step 4: extract qualifiers
  qe <- extract_qualifier(normalized)
  qualifier <- qe$qualifier
  remainder <- qe$remainder

  # Step 5: detect narratives
  is_narrative <- detect_narrative(remainder)

  # Step 6: attempt as.numeric on non-narrative values
  numeric_value <- rep(NA_real_, length(values))
  parse_flag <- rep("", length(values))

  for (i in seq_along(values)) {
    if (is_narrative[i]) {
      # narrative: NA with flag
      numeric_value[i] <- NA_real_
      parse_flag[i] <- "narrative"
    } else {
      # Suppress warnings from as.numeric
      val <- suppressWarnings(as.numeric(remainder[i]))
      if (!is.na(val)) {
        numeric_value[i] <- val
        parse_flag[i] <- ""
      } else {
        numeric_value[i] <- NA_real_
        parse_flag[i] <- "unparseable"
      }
    }
  }

  # Step 7 (D-13): warn if any unparseable
  n_unparseable <- sum(parse_flag == "unparseable")
  if (n_unparseable > 0) {
    warning(paste0(n_unparseable, " values could not be parsed"))
  }

  # Step 8: build output tibble (exact column order per D-09)
  tibble::tibble(
    orig_row_id = orig_row_id,
    orig_result = orig_result,
    numeric_value = numeric_value,
    qualifier = qualifier,
    range_bin = "as_is",
    parse_flag = parse_flag
  )
}
