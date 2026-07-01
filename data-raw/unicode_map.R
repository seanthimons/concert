# PURPOSE: Create a comprehensive dictionary of Unicode mappings for chemical names.
# Both uppercase and lowercase Greek letters are mapped to lowercase plain names (e.g., alpha).
# Scientific symbols and other non-ASCII characters are mapped to their ASCII equivalents.
# Note: Dots around names (e.g., .alpha.) were removed to align with upstream search requirements.

# Helper function to generate hex-to-character mappings for a block
# Many Greek variants start at specific offsets in the Mathematical Alphanumeric block (U+1D400)
gen_greek_block <- function(start_hex, names) {
  out <- names
  names(out) <- sapply(0:(length(names) - 1), function(i) {
    intToUtf8(start_hex + i)
  })
  out
}

# Standard Greek names (lowercase order per U+03B1 block)
# Note: This includes 'varsigma' which is a common variant of sigma
standard_low_names <- c(
  "alpha",
  "beta",
  "gamma",
  "delta",
  "epsilon",
  "zeta",
  "eta",
  "theta",
  "iota",
  "kappa",
  "lambda",
  "mu",
  "nu",
  "xi",
  "omicron",
  "pi",
  "rho",
  "varsigma",
  "sigma",
  "tau",
  "upsilon",
  "phi",
  "chi",
  "psi",
  "omega"
)

# Standard Greek names (uppercase order per U+0391 block)
standard_cap_names <- c(
  "alpha",
  "beta",
  "gamma",
  "delta",
  "epsilon",
  "zeta",
  "eta",
  "theta",
  "iota",
  "kappa",
  "lambda",
  "mu",
  "nu",
  "xi",
  "omicron",
  "pi",
  "rho",
  "unused",
  "sigma",
  "tau",
  "upsilon",
  "phi",
  "chi",
  "psi",
  "omega"
)

# 1. Standard Greek Block (U+0370–U+03FF)
standard_low <- gen_greek_block(0x03B1, standard_low_names)
standard_cap <- gen_greek_block(0x0391, standard_cap_names)
# Cleanup: remove the "unused" gap in uppercase block (U+03A2)
standard_cap <- standard_cap[names(standard_cap) != intToUtf8(0x03A2)]

# 2. Mathematical Alphanumeric Greek Blocks (U+1D6A8–U+1D7FF)
# Each sub-block has 25 lowercase and 25 uppercase characters
math_blocks <- list(
  bold_cap = 0x1D6A8,
  bold_low = 0x1D6C2,
  ital_cap = 0x1D6E2,
  ital_low = 0x1D6FC,
  bold_ital_cap = 0x1D71C,
  bold_ital_low = 0x1D736,
  sans_bold_cap = 0x1D756,
  sans_bold_low = 0x1D770,
  sans_bold_ital_cap = 0x1D790,
  sans_bold_ital_low = 0x1D7AA
)

math_maps <- lapply(names(math_blocks), function(bn) {
  nms <- if (grepl("low", bn)) standard_low_names else standard_cap_names
  res <- gen_greek_block(math_blocks[[bn]], nms)
  res[res != "unused"]
})
math_map_combined <- unlist(math_maps)

# 3. Specific Symbol Variants (common in chemical informatics)
symbol_variants <- c(
  "\u03B1" = 'alpha', # Greek Alpha Symbol
  "\u03d0" = "beta", # Greek Beta Symbol
  "\u03d1" = "theta", # Greek Theta Symbol
  "\u03d2" = "upsilon", # Greek Upsilon Symbol
  "\u03d5" = "phi", # Greek Phi Symbol
  "\u03d6" = "pi", # Greek Pi Symbol
  "\u03f0" = "kappa", # Greek Kappa Symbol
  "\u03f1" = "rho", # Greek Rho Symbol
  "\u03f5" = "epsilon" # Greek Lunate Epsilon Symbol
)

greek_map <- c(standard_low, standard_cap, math_map_combined, symbol_variants)
# Ensure varsigma is treated as sigma for searching
greek_map[greek_map == "varsigma"] <- "sigma"

# 4. Mathematical and scientific symbols
math_symbols <- c(
  "\u00b1" = "+/-",
  "\u2265" = ">=",
  "\u2264" = "<=",
  "\u2260" = "!=",
  "\u2248" = "~",
  "\u221e" = "inf",
  "\u221a" = "sqrt",
  "\u00d7" = "*",
  "\u00b7" = "*",
  "\u2215" = "/",
  "\u00f7" = "/",
  "\u2212" = "-", # Minus sign
  "\u2013" = "-", # En dash
  "\u2014" = "-", # Em dash
  "\u2219" = "*",
  "\u2261" = "==",
  "\u220f" = "II",
  "\u222a" = "U",
  "\u2229" = "^"
)

# 5. Subscripts and Superscripts (map to normal numbers)
script_map <- c(
  "\u00b9" = "1",
  "\u00b2" = "2",
  "\u00b3" = "3",
  "\u2070" = "0",
  "\u2074" = "4",
  "\u2075" = "5",
  "\u2076" = "6",
  "\u2077" = "7",
  "\u2078" = "8",
  "\u2079" = "9",
  "\u2080" = "0",
  "\u2081" = "1",
  "\u2082" = "2",
  "\u2083" = "3",
  "\u2084" = "4",
  "\u2085" = "5",
  "\u2086" = "6",
  "\u2087" = "7",
  "\u2088" = "8",
  "\u2089" = "9",
  "\u207b" = "-",
  "\u207a" = "+"
)

# 6. Units and other symbols (Trademark/Registered removed as metadata noise)
misc_map <- c(
  "\u00b5" = "u", # Micro sign
  "\u03bc" = "u", # Small Greek Mu
  "\u00b0" = "", # Degree sign (usually removed in chemical names)
  "\u2122" = "", # TM
  "\u00ae" = "", # Registered
  "\u00a9" = "", # Copyright
  "\u2026" = "...",
  "\u2032" = "'", # Prime
  "\u00b4" = "'", # Acute accent
  "\u201c" = "\"",
  "\u201d" = "\"", # Smart quotes
  "\u2018" = "'",
  "\u2019" = "'", # Smart single quotes
  "\u00a0" = " ", # Non-breaking space
  "\u33c0" = "KO",
  "\u33c1" = "MO", # Square units
  "\u2192" = "->", # Right arrow
  "\u2191" = "^", # Up arrow
  "\u00a7" = "S", # Section
  "\u00b6" = "P", # Paragraph
  "\u2020" = "|", # Dagger
  "\u2021" = "|" # Double dagger
)

# 7. Latin characters with accents -> ASCII equivalents
latin_map <- c(
  "\u00fc" = "u",
  "\u00f9" = "u",
  "\u00fa" = "u",
  "\u00fb" = "u",
  "\u00e9" = "e",
  "\u00e8" = "e",
  "\u00eb" = "e",
  "\u00ea" = "e",
  "\u00e0" = "a",
  "\u00e1" = "a",
  "\u00e2" = "a",
  "\u00e3" = "a",
  "\u00e4" = "a",
  "\u00e5" = "a",
  "\u00f2" = "o",
  "\u00f3" = "o",
  "\u00f4" = "o",
  "\u00f5" = "o",
  "\u00f6" = "o",
  "\u00f8" = "o",
  "\u00ec" = "i",
  "\u00ed" = "i",
  "\u00ee" = "i",
  "\u00ef" = "i",
  "\u00f1" = "n",
  "\u00e7" = "c",
  "\u00df" = "ss",
  "\u00c6" = "AE",
  "\u00e6" = "ae"
)

# Combine all into one dictionary
unicode_map <- c(greek_map, math_symbols, script_map, misc_map, latin_map)

# Remove duplicates if any (prioritize first occurrence)
unicode_map <- unicode_map[!duplicated(names(unicode_map))]

# Crucial step: use stri_unescape_unicode to ensure the keys are
# actual Unicode characters in the dictionary
names(unicode_map) <- stringi::stri_unescape_unicode(stringi::stri_escape_unicode(names(unicode_map)))

# Save as package data
usethis::use_data(unicode_map, overwrite = TRUE, internal = TRUE)
