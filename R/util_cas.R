#' Checks if a string is a syntactically and algorithmically valid CASRN
#'
#' A valid CAS Registry Number (CASRN) is a string in the format "dd...d-dd-d",
#' containing 5 to 10 digits in total. The final digit is a check-digit
#' calculated using a specific algorithm. This function validates both the
#' format and the check-digit calculation.
#'
#' @param x A character vector of potential CASRN strings.
#'
#' @return A logical vector of the same length as `x`. Returns `TRUE` for
#'   each valid CASRN, `FALSE` for invalid ones, and `NA` for `NA` inputs.
#'
#' @export
#' @importFrom stringr str_detect str_remove_all str_split_i
#'
#' @examples
#' is_cas("50-00-0")  # Valid
#' is_cas("50-00-1")  # Invalid check digit
#' is_cas("7732-18-5") # Valid
#' is_cas("100-42-5")  # Valid
#' is_cas("not-a-casrn")
#' is_cas(c("50-00-0", "50-00-1", NA, "7732-18-5"))
is_cas <- function(x) {
  x <- as.character(x)
  out <- !is.na(x) & grepl("^\\d{2,7}-\\d{2}-\\d$", x)
  ok <- which(out)
  if (length(ok) > 0) {
    digits <- gsub("-", "", x[ok], fixed = TRUE)
    n <- nchar(digits)
    # Left-pad the body to 9 digits so the check-digit weights are always 9:1
    body <- substr(digits, 1, n - 1)
    body <- paste0(strrep("0", 9 - nchar(body)), body)
    d <- matrix(as.integer(unlist(strsplit(body, ""), use.names = FALSE)), ncol = 9, byrow = TRUE)
    out[ok] <- as.vector(d %*% 9:1) %% 10 == as.integer(substr(digits, n, n))
  }
  out[is.na(x)] <- NA
  out
}

#' Coerces and validates a string to a standard CASRN format
#'
#' This function attempts to convert a string into a valid Chemical Abstracts
#' Service Registry Number (CASRN). It handles common data quality issues such
#' as extra non-digit characters, missing hyphens, and leading zeros.
#' The function extracts all digits, trims any leading zeros, formats the
#' result into the standard "xx-yy-z" structure, and then validates it using
#' the `is_cas()` check-digit algorithm.
#'
#' @param x A character vector of potential CASRN strings.
#'
#' @return A character vector of the same length as `x`. Returns the correctly
#'   formatted, canonical CASRN string if valid, otherwise returns `NA_character_`.
#'
#' @export
#' @importFrom stringr str_remove_all str_sub
#'
#' @seealso [is_cas()] for the underlying validation logic.
#'
#' @examples
#' # Handles standard and padded formats
#' as_cas("50-00-0")
#' as_cas("0050-00-0") # Padded with leading zeros
#' as_cas("000575-38-2") # Another padded example
#'
#' # Handles extra characters and missing hyphens
#' as_cas("CAS: 7732-18-5")
#' as_cas("50000")
#'
#' # Returns NA for invalid CASRNs
#' as_cas("50-00-1") # Invalid check digit
#' as_cas("not-a-casrn")
as_cas <- function(x) {
  x <- as.character(x)
  # Source identifiers such as NOCAS_1355346 are not CAS numbers, even if
  # their digits happen to satisfy the CAS checksum after reformatting.
  nocas <- grepl("^\\s*NO[_[:space:]-]*CAS(?:[_[:space:]-]|$)", x, ignore.case = TRUE, perl = TRUE)

  # Keep only digits, trim leading zeros; a CASRN has 5 to 10 digits
  digits <- sub("^0+", "", gsub("[^0-9]", "", x))
  n <- nchar(digits)
  ok <- !is.na(x) & !nocas & n >= 5 & n <= 10

  cand <- paste(substr(digits, 1, n - 3), substr(digits, n - 2, n - 1), substr(digits, n, n), sep = "-")
  ok[ok] <- is_cas(cand[ok])
  out <- rep(NA_character_, length(x))
  out[ok] <- cand[ok]
  out
}

#' Extracts all valid CASRNs from a character vector
#'
#' This function searches for and extracts all valid Chemical Abstracts Service
#' Registry Numbers (CASRNs) from a character vector. It uses a flexible
#' pattern to find candidate strings (including those without hyphens) and then
#' validates each one using the `as_cas()` coercion and validation function.
#'
#' @param x A character vector of text to be searched.
#'
#' @return A list of character vectors. Each element of the list corresponds
#'   to an element of the input `x` and contains all valid CASRNs found.
#'   An empty `character(0)` vector indicates no valid CASRNs were found for
#'   that input string.
#'
#' @export
#' @importFrom stringr str_extract_all
#'
#' @seealso [as_cas()] and [is_cas()] for the underlying coercion and
#'   validation logic.
#'
#' @examples
#' text <- c(
#'   "The CAS for formaldehyde is 50-00-0, and water is 7732-18-5.",
#'   "An invalid number is 50-00-1, but a padded one is 007732-18-5.",
#'   "No hyphens: 50000.",
#'   "No valid CASRNs in this string.",
#'   NA
#' )
#' extract_cas(text)
#' # [[1]]
#' # [1] "50-00-0"   "7732-18-5"
#' #
#' # [[2]]
#' # [1] "7732-18-5"
#' #
#' # [[3]]
#' # [1] "50-00-0"
#' #
#' # [[4]]
#' # character(0)
#' #
#' # [[5]]
#' # character(0)
extract_cas <- function(x) {
  # Candidates are "words" of 5 to 12 digits and hyphens: well-formatted,
  # unhyphenated and zero-padded CASRNs. as_cas() validates them in one pass.
  candidates_list <- stringr::str_extract_all(x, "\\b[0-9-]{5,12}\\b")
  validated <- as_cas(unlist(candidates_list, use.names = FALSE))
  owner <- rep(seq_along(candidates_list), lengths(candidates_list))
  keep <- !is.na(validated)
  unname(split(validated[keep], factor(owner[keep], levels = seq_along(candidates_list))))
}

#' Detect and repair CASRNs that a spreadsheet converted to dates
#'
#' Excel and Google Sheets silently turn some CASRNs into dates on CSV import
#' (e.g. `103-02-6` -> `0103-02-06`, `10-13-9` -> `10-13-2009`). Roughly 4.6% of
#' DSSTox CASRNs are exposed. No real CASRN has a zero-padded part or a
#' multi-digit check digit, so these shapes are input corruption. Values are
#' repaired only when the reconstruction passes the CAS checksum; otherwise
#' they are flagged with an `NA` repair and the source file must be re-exported
#' with CASRN columns formatted as text.
#'
#' Recognised shapes:
#' - year-month-day with a zero-padded day (Google Sheets display, xlsx date
#'   cells read by [read_excel_robust()]): `0103-02-06`, `1975-09-02`
#' - US month-day-year with a 4-digit 200x year (Google Sheets): `10-13-2009`
#' - slash dates such as `9/2/1975`: flagged only, the field order is
#'   locale-dependent so no repair is attempted
#'
#' @param x Character vector of CASRN-column values.
#' @return Tibble with `flagged` (logical) and `repair` (character, `NA` when
#'   not flagged or not recoverable), one row per element of `x`.
#' @keywords internal
repair_cas_date_coercion <- function(x) {
  x <- trimws(as.character(x))
  repair <- rep(NA_character_, length(x))
  valid <- function(cas) !is.na(cas) & unname(is_cas(cas)) %in% TRUE

  ymd <- !is.na(x) & grepl("^\\d{2,7}-\\d{2}-0[1-9]$", x)
  if (any(ymd)) {
    full <- sub("^0*(\\d+)-(\\d{2})-0(\\d)$", "\\1-\\2-\\3", x[ymd])
    # Two-digit-year CASRNs (75-09-2) come back from xlsx as 1975-09-02
    short <- sub("^(19|20)(\\d{2})-", "\\2-", full)
    repair[ymd] <- ifelse(valid(full), full, ifelse(short != full & valid(short), short, NA_character_))
  }

  mdy <- !is.na(x) & grepl("^1[0-2]-\\d{2}-200\\d$", x)
  if (any(mdy)) {
    cand <- sub("-200(\\d)$", "-\\1", x[mdy])
    repair[mdy] <- ifelse(valid(cand), cand, NA_character_)
  }

  slash <- !is.na(x) & grepl("^\\d{1,2}/\\d{1,2}/\\d{2,5}$", x)

  tibble::tibble(flagged = ymd | mdy | slash, repair = repair)
}
