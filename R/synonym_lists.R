# Synonym-list input: a column tagged "Synonym" holds extra names for the row's
# own chemical, separated by ";". Parts are looked up as evidence for that row
# and never become analyte rows (#139).

SYNONYM_DELIMITER <- "; "

# Split one cell on semicolons that sit outside parentheses/brackets. Nested
# enclosures count. An unbalanced or mismatched enclosure leaves the cell whole,
# because the semicolons then cannot be trusted as separators.
split_semicolon_cell <- function(name) {
  if (is.na(name)) {
    return(NA_character_)
  }
  chars <- strsplit(name, "", fixed = TRUE)[[1]]
  stack <- character()
  separators <- integer()
  for (i in which(chars %in% c("(", ")", "[", "]", ";"))) {
    char <- chars[i]
    if (char %in% c("(", "[")) {
      stack <- c(stack, char)
    } else if (char %in% c(")", "]")) {
      expected <- if (char == ")") "(" else "["
      if (length(stack) == 0L || utils::tail(stack, 1L) != expected) {
        return(name)
      }
      stack <- utils::head(stack, -1L)
    } else if (length(stack) == 0L) {
      separators <- c(separators, i)
    }
  }
  if (length(stack) > 0L) {
    return(name)
  }
  parts <- stringr::str_trim(substring(name, c(1L, separators + 1L), c(separators - 1L, nchar(name))))
  parts[parts != "" & !is.na(parts)]
}

# A name that still holds several ";"-separated parts after cleaning (a CAS row, or
# a bundle the plausibility gate refused to split) is not one substance.
is_synonym_bundle <- function(x) {
  vapply(as.character(x), function(cell) length(split_semicolon_cell(cell)) > 1L, logical(1), USE.NAMES = FALSE)
}

#' Split synonym-list cells into their parts
#'
#' Splits on `;` outside parentheses and brackets, trims, and drops empty and
#' repeated parts. Unlike [split_synonyms()], there is no plausibility gate (short
#' synonyms such as "EDB" are valid) and a CASRN on the row does not matter: every
#' synonym names the row's own chemical.
#'
#' @param x Character vector of synonym cells.
#' @return List the length of `x`; each element is a character vector of parts
#'   (`character(0)` for NA or empty cells).
#' @keywords internal
split_synonym_list <- function(x) {
  lapply(as.character(x), function(cell) {
    parts <- split_semicolon_cell(cell)
    unique(parts[!is.na(parts)])
  })
}

#' Format synonyms for a Synonym-tagged column
#'
#' Joins synonyms into the `"a; b; c"` form that a `"Synonym"` column expects.
#' Commas never separate synonyms (they occur inside names such as
#' "Benzene, 1,2-dichloro-"), so build the cell with this helper rather than
#' pasting by hand.
#'
#' @param x A list (for example a list column) with one character vector of
#'   synonyms per row, giving one string per element; or an atomic character
#'   vector, which is a single row's synonyms and gives one string.
#' @return Character vector. Empty or all-NA elements give `NA_character_`.
#'   A synonym containing `;` outside brackets cannot be represented, so its
#'   semicolons become commas, with a warning. A synonym with an unbalanced
#'   parenthesis or bracket also warns, because it makes its whole cell unsplittable.
#' @examples
#' format_synonyms(c("EDB", "Ethylene dibromide"))
#' format_synonyms(list(c("o-DCB", "ortho-Dichlorobenzene"), NA))
#' @export
format_synonyms <- function(x) {
  cells <- if (is.list(x)) x else list(x)
  collapsed <- FALSE
  unbalanced <- FALSE
  out <- vapply(
    cells,
    function(items) {
      items <- trimws(as.character(unlist(items, use.names = FALSE)))
      items <- unique(items[!is.na(items) & nzchar(items)])
      if (length(items) == 0L) {
        return(NA_character_)
      }
      clean <- vapply(
        items,
        function(item) {
          if (length(split_semicolon_cell(item)) > 1L) {
            collapsed <<- TRUE
            return(gsub(";", ",", item, fixed = TRUE))
          }
          item
        },
        character(1),
        USE.NAMES = FALSE
      )
      cell <- paste(clean, collapse = SYNONYM_DELIMITER)
      # An unbalanced enclosure in one synonym ("foo (bar") makes the whole cell
      # unsplittable, silently dropping every synonym in it.
      if (!identical(split_semicolon_cell(cell), clean)) {
        unbalanced <<- TRUE
      }
      cell
    },
    character(1)
  )
  if (collapsed) {
    cli::cli_warn("A synonym contained {.val ;}; it was replaced with a comma so it stays one synonym.")
  }
  if (unbalanced) {
    cli::cli_warn("A synonym has an unbalanced parenthesis or bracket, so its cell cannot be split into synonyms.")
  }
  out
}

# Likely wrong delimiter: many comma-joined cells and no semicolon at all. Commas
# between digits are locants ("1,2-"), not list separators.
synonym_delimiter_diagnostics <- function(df, tags, threshold = 0.25) {
  tags <- unlist(tags)
  synonym_like <- names(tags)[
    tags == "Synonym" |
      (tags == "Other" & grepl("synonym", names(tags), ignore.case = TRUE))
  ]
  rows <- lapply(intersect(synonym_like, names(df)), function(col) {
    values <- as.character(df[[col]])
    values <- values[!is.na(values) & nzchar(trimws(values))]
    if (length(values) == 0L || any(grepl(";", values, fixed = TRUE))) {
      return(NULL)
    }
    comma_cells <- sum(grepl(",(?=\\s|[A-Za-z])", values, perl = TRUE))
    if (comma_cells / length(values) < threshold) {
      return(NULL)
    }
    tibble::tibble(
      column = col,
      tag = unname(tags[col]),
      comma_cells = comma_cells,
      nonempty_cells = length(values),
      diagnostic = "synonym_delimiter",
      message = if (identical(unname(tags[col]), "Synonym")) {
        "Synonym cells are separated by ';', not ','. Use format_synonyms() to build them."
      } else {
        "Tag this column Synonym and separate synonyms with ';' (see format_synonyms()); Other columns are looked up whole."
      }
    )
  })
  dplyr::bind_rows(rows)
}

warn_synonym_delimiter <- function(diagnostics) {
  for (i in seq_len(nrow(diagnostics))) {
    cli::cli_warn(c(
      "Column {.field {diagnostics$column[i]}} looks comma-delimited ({diagnostics$comma_cells[i]} of {diagnostics$nonempty_cells[i]} cells, no {.val ;}).",
      "i" = diagnostics$message[i]
    ))
  }
  invisible(diagnostics)
}
