# date_parser.R
# Date string parsing engine: format detection, partial date handling, ambiguity flagging.
#
# Public API: parse_dates()
# Internal: 2-digit year detection via regex pre-scan

#' Parse mixed-format date strings into structured ISO-8601 output
#'
#' Converts a character vector of date strings in mixed formats into a
#' standardised 5-column tibble. Handles ISO, MDY, DMY, SAS (dBY), YYYYMMDD
#' compact, year-only, and month-year formats via lubridate::parse_date_time()
#' with train=FALSE (required for heterogeneous columns).
#'
#' @param raw_dates Character vector of date strings to parse.
#' @param orig_row_id Integer vector of row IDs corresponding to each element
#'   of raw_dates. Defaults to seq_along(raw_dates) for direct column processing.
#' @return A tibble with 5 columns:
#'   \describe{
#'     \item{orig_row_id}{Integer row position for join-by-position merge.}
#'     \item{raw_date}{Original input string, preserved for audit.}
#'     \item{parsed_date}{ISO-8601 "YYYY-MM-DD" string, or NA_character_ if unparseable.}
#'     \item{date_year}{Integer year extracted from parsed_date, or NA_integer_.}
#'     \item{date_flag}{One of: "" (clean), "partial", "inferred_format", "ambiguous", "unparseable".}
#'   }
#' @importFrom tibble tibble
#' @export
parse_dates <- function(raw_dates, orig_row_id = seq_along(raw_dates)) {
  # Pre-compiled orders vector (order matters with train=FALSE - first match wins)
  # Rationale: ymd = ISO priority (D-01); Ymd = YYYYMMDD compact; bY/BY before
  # mdy prevents "Jan 2015" misparse as mdy (PITFALL-02); dBY/BdY = SAS format;
  # mdy = US convention (D-02); dmy = European fallback; Y = year-only (D-03);
  # Ym = numeric month-year "2015-03" (D-04)
  #
  # Time-bearing orders come FIRST: with train=FALSE the match is full-string, so a
  # timestamped value (e.g. "2015-03-15 14:30:00", LIMS/lab exports) fails every
  # date-only order and would parse to NA -> "unparseable", silently dropping a valid
  # date. The HMS/HM/IMp variants capture the date; as.Date() below discards the time.
  # lubridate handles the "T" separator and trailing "Z" (UTC) automatically.
  TIME_ORDERS <- c(
    "ymd HMS",
    "ymd HM",
    "ymd IMp",
    "mdy HMS",
    "mdy HM",
    "mdy IMp",
    "dmy HMS",
    "dmy HM",
    "dmy IMp",
    "BdY HMS",
    "BdY HM",
    "dBY HMS",
    "dBY HM"
  )
  ORDERS <- c(TIME_ORDERS, "ymd", "Ymd", "bY", "BY", "dBY", "BdY", "mdy", "dmy", "Y", "Ym")

  # 2-digit year detection pattern (PITFALL-03: cutoff_2000 does not exist in
  # parse_date_time - use regex pre-scan instead)
  # Trailing (space|T|end) allows a 2-digit-year date that carries a time
  # (e.g. "03/04/15 14:30") to still flag inferred_format; the same boundary
  # keeps 4-digit years like "03/04/2015" from matching (no 2-digit run after
  # the final slash is followed by that boundary).
  TWO_DIGIT_PAT <- "[0-9]{1,2}/[0-9]{1,2}/[0-9]{2}([[:space:]]|T|$)"

  # Empty-input guard: return typed empty tibble (same pattern as unit_harmonizer.R)
  n <- length(raw_dates)
  if (n == 0) {
    return(tibble::tibble(
      orig_row_id = integer(0),
      raw_date = character(0),
      parsed_date = character(0),
      date_year = integer(0),
      date_flag = character(0)
    ))
  }

  # Vectorized parse - train=FALSE is CRITICAL for heterogeneous format columns
  # (PITFALL-01: train=TRUE selects a single dominant format, wrong-parsing others)
  # quiet=TRUE suppresses per-element parse failure messages
  parsed_posix <- lubridate::parse_date_time(
    raw_dates,
    orders = ORDERS,
    train = FALSE,
    quiet = TRUE
  )

  # Format ISO-8601 output; set NA_character_ where parse failed
  parsed_date <- format(as.Date(parsed_posix), "%Y-%m-%d")
  parsed_date[is.na(parsed_posix)] <- NA_character_

  # Extract integer year; NA_integer_ where parse failed
  date_year <- lubridate::year(parsed_posix)
  date_year[is.na(parsed_posix)] <- NA_integer_

  # --- Flag vectors (strictly ordered; PITFALL-04 guard on partial before ambiguous) ---

  is_unparseable <- is.na(parsed_posix)

  # Partial: year-only "2015", numeric month-year "2015-03", named month-year "Mar 2015"
  # PITFALL-04: must be evaluated BEFORE ambiguity check because year-only "2015"
  # parses to 2015-01-01 (day=1, month=1, both <=12) and would false-fire ambiguous.
  is_partial <- !is_unparseable &
    (grepl("^[0-9]{4}$", trimws(raw_dates)) |
      grepl("^[0-9]{4}[-/][0-9]{1,2}$", trimws(raw_dates)) |
      grepl("^[A-Za-z]+ [0-9]{4}$", trimws(raw_dates)))

  # 2-digit year: flag as inferred_format regardless of cutoff result (D-09)
  # 2-digit year cutoff: lubridate default (year < 69 -> 2000+year, >= 69 -> 1900+year).
  # Acceptable for regulatory data spanning 1950-2030. Per D-08, this is the selected threshold.
  is_inferred <- !is_unparseable & grepl(TWO_DIGIT_PAT, raw_dates, perl = TRUE)

  # Ambiguous: parsed day AND month both <= 12 (DATE-03)
  # !is_partial guard prevents year-only / month-year false positives (PITFALL-04)
  is_ambiguous <- (!is_unparseable &
    !is_partial &
    lubridate::day(parsed_posix) <= 12 &
    lubridate::month(parsed_posix) <= 12)

  # Assign flags with strict priority enforcement via dplyr::case_when():
  # "unparseable" > "partial" > "inferred_format" > "ambiguous" > ""
  date_flag <- dplyr::case_when(
    is_unparseable ~ "unparseable",
    is_partial ~ "partial",
    is_inferred ~ "inferred_format",
    is_ambiguous ~ "ambiguous",
    TRUE ~ ""
  )

  tibble::tibble(
    orig_row_id = as.integer(orig_row_id),
    raw_date = as.character(raw_dates),
    parsed_date = parsed_date,
    date_year = as.integer(date_year),
    date_flag = date_flag
  )
}
