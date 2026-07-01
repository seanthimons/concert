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
  # The check-digit algorithm needs to be applied to each element.
  # vapply is a safe and efficient way to do this.
  vapply(
    x,
    FUN = function(cas_str) {
      # Immediately return NA for NA inputs
      if (is.na(cas_str)) {
        return(NA)
      }

      # 1. Check the basic format: xx-yy-z with 2-7 digits in the first part.
      # This is a fast way to reject clearly invalid strings.
      format_regex <- "^\\d{2,7}-\\d{2}-\\d$"
      if (!stringr::str_detect(cas_str, format_regex)) {
        return(FALSE)
      }

      # 2. Perform the check-digit calculation.
      # Get the provided check-digit (the last character).
      expected_check_digit <- as.integer(stringr::str_split_i(cas_str, "-", 3))

      # Get the number part (everything before the last digit and hyphen).
      number_part <- stringr::str_remove_all(cas_str, "-\\d$")
      number_part <- stringr::str_remove_all(number_part, "-")

      # Split into individual digits, reverse, and calculate.
      digits <- as.integer(strsplit(number_part, "")[[1]])
      reversed_digits <- rev(digits)

      # The check-digit is the sum of (digit * position) modulo 10
      calculated_check_digit <- sum(reversed_digits * seq_along(reversed_digits)) %% 10

      # Return TRUE only if the calculation matches the provided check-digit.
      return(calculated_check_digit == expected_check_digit)
    },
    FUN.VALUE = logical(1),
    USE.NAMES = FALSE
  )
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
  vapply(
    x,
    FUN = function(cas_str) {
      if (is.na(cas_str)) {
        return(NA_character_)
      }

      # 1. Extract only the digits from the string.
      digits_only <- stringr::str_remove_all(cas_str, "[^0-9]")

      # If no digits were found, it's invalid.
      if (nchar(digits_only) == 0) {
        return(NA_character_)
      }

      # --- NEW STEP: Trim leading zeros ---
      # The as.numeric -> as.character trick is a robust way to do this.
      # It correctly handles "0050" -> "50" and "0" -> "0".
      digits_only <- as.character(as.numeric(digits_only))

      # 2. A CASRN must have between 5 and 10 digits *after trimming*.
      n <- nchar(digits_only)
      if (n < 5 || n > 10) {
        return(NA_character_)
      }

      # 3. Reconstruct the string in the standard format.
      first_part <- stringr::str_sub(digits_only, 1, n - 3)
      middle_part <- stringr::str_sub(digits_only, n - 2, n - 1)
      check_digit <- stringr::str_sub(digits_only, n, n)

      formatted_cas <- paste(first_part, middle_part, check_digit, sep = "-")

      # 4. Use our strict validator function to check the result.
      if (isTRUE(is_cas(formatted_cas))) {
        return(formatted_cas)
      } else {
        return(NA_character_)
      }
    },
    FUN.VALUE = character(1),
    USE.NAMES = FALSE
  )
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
  # --- Pass 1: Find Potential Candidates ---
  # This regex is intentionally flexible. It looks for "words" that consist
  # of 5 to 12 digits and hyphens. This will capture well-formatted CASRNs,
  # those with missing hyphens, and padded ones.
  candidate_regex <- "\\b[0-9-]{5,12}\\b"

  # Extract all candidates into a list of character vectors.
  candidates_list <- stringr::str_extract_all(x, candidate_regex)

  # --- Pass 2: Validate Each Candidate ---
  # Use lapply to iterate over the list. For each vector of candidates,
  # apply as_cas() and keep only the valid results.
  lapply(candidates_list, function(candidates) {
    if (length(candidates) == 0) {
      return(character(0))
    }

    # as_cas() will clean, format, and validate each candidate.
    # It returns a valid CASRN string or NA.
    validated_results <- as_cas(candidates)

    # Remove the NAs to keep only the successfully validated CASRNs.
    validated_results[!is.na(validated_results)]
  })
}
