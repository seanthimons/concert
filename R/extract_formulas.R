#' Extract molecular formulas from text
#'
#' Finds and returns chemically valid molecular formulas from a character vector,
#' restricted to content inside parentheses or square brackets.
#'
#' Behavior:
#' - Correctly handles parentheses, square brackets, stoichiometric numbers, and
#'   grouped substructures (e.g., "(NH3)2").
#' - Recognizes complexes and hydrates inside brackets when they include spaces,
#'   middle dot (U+00B7), plus/minus, or periods (these are normalized before validation).
#' - Ignores oxidation state Roman numerals in brackets, e.g., "(III)" or "( ii )".
#' - Excludes carbon backbone ranges like "C9-12".
#'
#' @param text_vector A character vector of text to search.
#' @return A list of character vectors. Each element corresponds to one input
#'   string and contains all formulas found inside its bracketed content.
#' @export
#' @importFrom stringr str_extract_all str_detect str_squish str_replace_all str_sub
#'
#' @examples
#' texts <- c(
#'   "Water (H2O) and ethanol (C2H5OH).",
#'   "Complex: [Pt(NH3)2Cl2] catalyst.",
#'   "Hydrate: (CuSO4 . 5H2O)",
#'   "Oxidation state: iron (III) chloride",  # "(III)" is ignored
#'   "Backbone range: C9-12 alcohols"         # "C9-12" is ignored
#' )
#' extract_formulas(texts)
extract_formulas <- function(text_vector) {
  # Periodic table symbols (including lanthanides/actinides + common elements).
  # Longer symbols first so the alternation prefers two-letter matches.
  #fmt:skip
  elements_list <- c(
    "He", "Li", "Be", "Ne", "Na", "Mg", "Al", "Si", "Cl", "Ar", "Ca", "Sc", "Ti", "Cr", "Mn", "Fe", "Co", "Ni", "Cu", "Zn", "Ga", "Ge", "As", "Se",
    "Br", "Kr", "Rb", "Sr", "Zr", "Nb", "Mo", "Tc", "Ru", "Rh", "Pd", "Ag", "Cd", "In", "Sn", "Sb", "Te", "Xe", "Cs", "Ba", "La", "Ce", "Pr", "Nd",
    "Pm", "Sm", "Eu", "Gd", "Tb", "Dy", "Ho", "Er", "Tm", "Yb", "Lu", "Hf", "Ta", "Re", "Os", "Ir", "Pt", "Au", "Hg", "Tl", "Pb", "Bi", "Po", "At",
    "Rn", "Fr", "Ra", "Ac", "Th", "Pa", "Np", "Pu", "Am", "Cm", "Bk", "Cf", "Es", "Fm", "Md", "No", "Lr", "Rf", "Db", "Sg", "Bh", "Hs", "Mt", "Ds",
    "Rg", "Cn", "Nh", "Fl", "Mc", "Lv", "Ts", "Og", "H", "B", "C", "N", "O", "F", "P", "S", "K", "V", "I", "Y", "W", "U"
  )
  elements_pattern <- paste(elements_list, collapse = "|")

  element_chunk <- paste0("(?:", elements_pattern, ")\\d*")
  group_chunk <- paste0(
    "(?:\\((?:",
    element_chunk,
    ")+\\)\\d*|\\[(?:",
    element_chunk,
    ")+\\]\\d*)"
  )
  validator_regex <- paste0("^(?:", element_chunk, "|", group_chunk, ")+(?:[+-]\\d*)?$")

  # Do NOT allow '(' or ')' inside the (...) alternative; allow them inside [...] only.
  candidate_regex <- "(\\([A-Za-z0-9+\\-\\.\\u00b7\\s]*\\)|\\[[A-Za-z0-9()+\\-\\.\\u00b7\\s]*\\])"

  roman_numeral_regex <- "(?i)^\\s*(?:i|v|x|l|c|d|m)+\\s*$"
  carbon_range_regex <- "^\\s*C\\d+\\s*[-\\u2013]\\s*\\d+\\s*$"

  candidates <- stringr::str_extract_all(text_vector, candidate_regex)
  lapply(candidates, function(cand_list) {
    if (length(cand_list) == 0) {
      return(character(0))
    }

    trimmed <- stringr::str_sub(cand_list, 2, -2)
    trimmed <- stringr::str_squish(trimmed)

    keep_roman <- !stringr::str_detect(trimmed, roman_numeral_regex)
    keep_carbon <- !stringr::str_detect(trimmed, carbon_range_regex)

    cleaned <- stringr::str_replace_all(trimmed, "[\\u00b7\\.\\s]+", "")
    is_formula <- stringr::str_detect(cleaned, validator_regex)

    res <- trimmed[keep_roman & keep_carbon & is_formula]
    unique(res) # de-duplicate while preserving order
  })
}
