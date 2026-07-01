#' @title Clean Unicode symbols in character strings
#'
#' @description A function to replace Unicode symbols (Greek letters, math symbols, etc.)
#' with their ASCII equivalents or pseudo-delimited names.
#'
#' @param x A character vector or a data frame to be processed.
#' @param ... Additional arguments passed to methods.
#'
#' @return The modified character vector or data frame.
#' @export
#'
#' @details
#' Greek letters are replaced with lowercase labels (e.g., 'alpha').
#' Mathematical comparison symbols like '>=' are normalized, and plus/minus symbols are replaced with '+/-'.
#' If a data frame is provided, all character columns are processed.
#'
#' Unhandled Unicode characters will be flagged for the user.
#'
#' @examples
#' \dontrun{
#' clean_unicode("17\u03b2-Estradiol")
#' # Returns: "17beta-Estradiol"
#'
#' clean_unicode("Concentration \u2265 10 \u00b5g/L")
#' # Returns: "Concentration >= 10 ug/L"
#' }
#'
#' @importFrom stringi stri_replace_all_fixed stri_escape_unicode
#' @importFrom cli cli_alert_warning cli_bullets cli_alert_info
#' @importFrom dplyr mutate across where
#' @importFrom stringr str_extract_all
#' @importFrom magrittr %>%
#' @rdname clean_unicode
clean_unicode <- function(x, ...) {
  UseMethod("clean_unicode")
}

#' @export
#' @rdname clean_unicode
clean_unicode.character <- function(x, ...) {
  # The internal unicode_map is loaded from sysdata.rda
  if (!exists("unicode_map")) {
    # Fallback if internal data is not loaded (e.g. during development if not using load_all)
    return(x)
  }

  # Perform replacements in a single pass for each string
  # vectorize_all = FALSE ensures that ALL patterns in unicode_map are applied to each string
  y <- stringi::stri_replace_all_fixed(
    x,
    pattern = names(unicode_map),
    replacement = unicode_map,
    vectorize_all = FALSE
  )

  # Check for any remaining unicode and warn the user
  check_unhandled(y)

  return(y)
}

#' @export
#' @rdname clean_unicode
clean_unicode.default <- function(x, ...) {
  return(x)
}

#' @export
#' @rdname clean_unicode
clean_unicode.data.frame <- function(x, ...) {
  x %>%
    dplyr::mutate(dplyr::across(
      dplyr::where(is.character),
      clean_unicode
    ))
}

#' Internal function to check for unhandled unicode
#' @param x Character vector
#' @keywords internal
check_unhandled <- function(x) {
  # Avoid processing NA
  if (all(is.na(x))) {
    return(NULL)
  }

  # Escape to find \uXXXX patterns
  # We use na.omit to avoid issues with escaped NA strings
  escaped <- stringi::stri_escape_unicode(stats::na.omit(x))

  # Find patterns like \u03b1 or \U00000000
  unhandled <- unique(unlist(stringr::str_extract_all(escaped, "\\\\[uU][0-9a-fA-F]{4,8}")))

  # Filter out some common escaped characters that are NOT symbols if any (usually none in stri_escape_unicode)

  if (length(unhandled) > 0) {
    cli::cli_warn("{length(unhandled)} unhandled Unicode symbol(s) detected:")
    cli::cli_bullets(stats::setNames(unhandled, rep("*", length(unhandled))))
    cli::cli_alert_info("Consider updating data-raw/unicode_map.R to include these.")
  }
}
