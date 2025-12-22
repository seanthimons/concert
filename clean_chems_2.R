# --- START OF FILE clean_chems.R ---

# This script is an R/Tidyverse conversion of the Python script 'clean_chems.py'.
# It cleans a dataset of chemical names and CAS-RNs by applying a series of
# cleaning, validation, and standardization rules.

# -----------------------------------------------------------------------------
# 1. SETUP: LOAD LIBRARIES
# -----------------------------------------------------------------------------
# Ensure the required packages are installed, e.g., install.packages("tidyverse")
library(tidyverse)
library(readr)
library(stringr)
library(dplyr)
library(tidyr)
library(lubridate)
library(here) # For robust file path management
library(writexl)
library(stringi) # For stri_reverse

# -----------------------------------------------------------------------------
# 2. HELPER FUNCTIONS
# -----------------------------------------------------------------------------

#' Extract CAS-RNs from a string
#'
#' Takes a text string and extracts all occurrences of a CAS-RN.
#' The regex ensures that leading zeros are not matched.
#'
#' @param x A character string to be searched for CAS-RNs.
#' @return A character vector of all CAS-RNs found, or NA if none are found
#'   or the input is not a string.
casrn_split <- function(x) {
  if (!is.character(x) || length(x) != 1) {
    return(NA_character_)
  }
  
  # Regex for CAS-RN: starts with a non-zero digit, followed by 1-6 digits,
  # a hyphen, two digits, a hyphen, and a final digit.
  matches <- str_extract_all(x, "[1-9][0-9]{1,6}-[0-9]{2}-[0-9]")[[1]]
  
  if (length(matches) < 1) {
    return(NA_character_)
  } else {
    return(matches)
  }
}


#' Identify if a string is likely a chemical formula
#'
#' This is a heuristic to check if a string resembles a molecular formula. It
#' checks for patterns of elements and numbers. It has a special case to
#' correctly identify 'NaCl' as a formula.
#'
#' @param x A character string to check.
#' @return A logical value: TRUE if the string appears to be a formula,
#'   FALSE otherwise. Returns FALSE for non-string inputs.
find_formula <- function(x) {
  if (!is.character(x) || length(x) != 1 || is.na(x)) {
    return(FALSE)
  }
  
  # This regex is a direct translation from the Python original.
  # It looks for (Element)(Number) or (Bracketed Group)(Number).
  regex <- "([A-Z][a-z]?)(\\d*(?:(?:[\\.|,])\\d+(?:%)?)?)|(?:[\\(|\\[])([^()]*(?:(?:[\\(|\\[]).*(?:[\\)|]]))?[^()]*)(?:[\\)|]])(\\d*(?:(?:[\\.|,]?)\\d+(?:%)?))"
  
  matches <- str_match_all(x, regex)[[1]]
  
  if (nrow(matches) < 1) {
    s <- ""
  } else {
    # Reconstruct the matched formula string
    s <- apply(matches, 1, function(row) paste(row[2:5], collapse = "")) %>%
      paste(collapse = "")
  }
  
  # Check if the reconstructed string contains any digits
  has_digits <- str_detect(s, "\\d")
  
  if (!has_digits) {
    # Special case for simple ionic compounds like NaCl
    if (s != "NaCl") {
      s <- ""
    }
  }
  
  # The string is a formula if the entire original string was matched.
  return(s == x)
}


#' Validate a CAS-RN using its checksum digit
#'
#' Checks if the last digit of a CAS-RN is a valid checksum.
#'
#' @param x A character string representing a CAS-RN.
#' @return A logical value: TRUE if the checksum is valid, FALSE otherwise.
checksum <- function(x) {
  if (!is.character(x) || length(x) != 1 || is.na(x)) {
    return(FALSE)
  }
  
  # Remove hyphens and the check digit itself, then reverse the string.
  cas <- str_sub(x, end = -2) %>%
    str_remove_all("-") %>%
    stringi::stri_reverse()
  
  # Split into individual digits
  digits <- str_split(cas, "")[[1]] %>% as.numeric()
  
  # Calculate the checksum
  q <- sum((1:length(digits)) * digits)
  
  # The checksum is valid if the remainder of q/10 equals the last digit of the CAS-RN.
  check_digit <- as.numeric(str_sub(x, -1))
  
  return((q %% 10) == check_digit)
}


#' Check for Unicode (non-ASCII) characters in a string
#'
#' @param x A character string.
#' @return A logical value: TRUE if there is at least one Unicode character,
#'   FALSE otherwise.
has_unicode <- function(x) {
  if (!is.character(x) || length(x) != 1 || is.na(x)) {
    return(FALSE)
  }
  # Regex to find any character that is not in the ASCII range.
  return(str_detect(x, "[^\\x00-\\x7F]"))
}


#' Provide a list of custom stop words
#'
#' These words indicate that a "chemical name" is likely generic, proprietary,
#' or otherwise not a specific chemical entity.
#'
#' @return A character vector of stop words.
stops <- function() {
  stop_words <- c(
    'proprietary', 'ingredient', 'hazard', 'blend', 'inert', 'stain',
    'other', 'withheld', 'cas |cas-|casrn', 'secret', "herbal",
    'confidential', 'bacteri', 'treatment', 'contracept', 'emission',
    "agent", "eye", "resin", "citron", 'bio', 'smoke', 'fiber', 'adult',
    'boy', 'girl', 'infant', 'child', 'other organosilane', 'material'
  )
  return(stop_words)
}


#' Append a comment to an existing comment string
#'
#' Safely appends a new comment to a potentially existing comment string,
#' handling NA values gracefully.
#'
#' @param x The original comment string (can be NA).
#' @param s The new information to append (can be NA).
#' @param comment A string providing context for the new information.
#' @param sep A character to separate the comments.
#' @return A character string with the appended comment, or NA.
append_col <- function(x, s, comment, sep = "|") {
  if (is.na(s) || s == "") {
    return(x)
  }
  
  new_comment <- glue::glue("{comment}: {str_trim(s)}")
  
  if (!is.na(x) && x != "") {
    y <- paste(str_trim(x), str_trim(new_comment), sep = sep)
  } else {
    y <- new_comment
  }
  
  return(y)
}


#' Remove terminal parenthetical phrases
#'
#' Removes a parenthetical phrase at the end of a string if it is unlikely
#' to contain part of a chemical name (e.g., it doesn't contain "yl").
#'
#' @param x A character string.
#' @return A named list with `phrase` (the modified string) and `removed`
#'   (the text that was removed, or NA).
term_parenth <- function(x) {
  if (!is.character(x) || length(x) != 1 || is.na(x)) {
    return(list(phrase = x, removed = NA_character_))
  }
  
  # Regex to find text inside the last pair of parentheses.
  match_data <- str_match(x, ".*\\(([^()]*)\\)$")
  
  if (is.na(match_data[1, 1])) { # No match
    return(list(phrase = x, removed = NA_character_))
  }
  
  s <- match_data[1, 2] # The content inside the parentheses
  
  # Heuristic: if the text contains "yl", it might be part of a chemical name.
  # Keep it, unless it also contains a word from the 'keepers' list.
  if (str_detect(s, "yl")) {
    keepers <- c('density', 'probably', 'average', 'combination')
    if (!any(str_detect(s, keepers))) {
      return(list(phrase = x, removed = NA_character_)) # Keep it
    }
  }
  
  # Remove the parenthetical phrase.
  phrase <- str_remove(x, "\\s*\\([^()]*\\)$") %>% str_trim()
  return(list(phrase = phrase, removed = s))
}


#' Remove terminal bracketed phrases
#'
#' Similar to `term_parenth`, but for square brackets.
#'
#' @param x A character string.
#' @return A named list with `phrase` (the modified string) and `removed`
#'   (the text that was removed, or NA).
term_bracket <- function(x) {
  if (!is.character(x) || length(x) != 1 || is.na(x)) {
    return(list(phrase = x, removed = NA_character_))
  }
  
  # Regex to find text inside the last pair of square brackets.
  match_data <- str_match(x, ".*\\[([^\\[\\]]*)\\]$")
  
  if (is.na(match_data[1, 1])) { # No match
    return(list(phrase = x, removed = NA_character_))
  }
  
  s <- match_data[1, 2]
  
  if (str_detect(s, "yl")) {
    keepers <- c('density', 'probably', 'average', 'combination')
    if (!any(str_detect(s, keepers))) {
      return(list(phrase = x, removed = NA_character_)) # Keep it
    }
  }
  
  phrase <- str_remove(x, "\\s*\\[[^\\[\\]]*\\]$") %>% str_trim()
  return(list(phrase = phrase, removed = s))
}


#' Load and clean functional use categories (FCs)
#'
#' Reads a list of FCs from a CSV, cleans them, and prepares them for matching.
#' This assumes the file "ChemExpo_FC_2023-05-24.csv" is in the working directory.
#'
#' @return A data frame with cleaned functional categories.
function_categories <- function() {
  # If file doesn't exist, return an empty tibble to avoid errors
  if (!file.exists("ChemExpo_FC_2023-05-24.csv")) {
    warning("ChemExpo_FC_2023-05-24.csv not found. FC cleaning will be skipped.")
    return(tibble(function_category = character(), fc_clean = character()))
  }

  df <- read_csv("ChemExpo_FC_2023-05-24.csv", col_types = cols(.default = "c")) %>%
    select(1) %>%
    rename_with(~ str_to_lower(str_replace_all(.x, " ", "_"))) %>%
    mutate(
      fc_clean_split = str_split(str_to_lower(function_category), "\\("),
      fc_extra = map_chr(fc_clean_split, ~ tail(.x, 1)) %>% str_remove_all("\\)"),
      fc_clean = map_chr(fc_clean_split, ~ head(.x, 1))
    ) %>%
    mutate(
      fc_extra = if_else(fc_clean == fc_extra | fc_extra == "epa", NA_character_, fc_extra)
    ) %>%
    unite(fc_clean, fc_clean, fc_extra, sep = "|", na.rm = TRUE, remove = TRUE) %>%
    mutate(fc_clean = str_trim(str_replace(fc_clean, "\\|$", ""))) %>% 
    select(function_category, fc_clean)
  
  return(df)
}


#' Create a single regex string for all functional categories
#'
#' Combines predefined FCs with a list loaded from a file into a single,
#' pipe-separated string for use in regex matching.
#'
#' @return A single character string for regex matching.
fc_string <- function() {
  extra_fcs <- c(
    'colorant', 'detergent', 'additive', 'flavor', "anti-", "protectant",
    'thermoplastic', "dispersion", "plast", 'enzyme', 'thick', 'inhib'
  )
  
  oecd_fcs_df <- function_categories()
  
  if (nrow(oecd_fcs_df) > 0) {
    oecd_fcs <- unique(oecd_fcs_df$fc_clean)
    all_fcs <- c(oecd_fcs, extra_fcs)
  } else {
    all_fcs <- extra_fcs
  }
  
  return(paste(all_fcs, collapse = "|"))
}


#' Create a regex string for food-related terms
#'
#' @return A single character string for regex matching.
foods <- function() {
  food_terms <- c('yeast culture', 'food starch', 'sweet whey', 'salted fish', 'beverage')
  return(paste(food_terms, collapse = "|"))
}


#' Find the newest file in a directory matching a pattern
#'
#' @param globber A string with a wildcard pattern (glob) to search for.
#' @param path The directory path to search in. Defaults to the current directory.
#' @return The full path of the newest file found.
newest_file <- function(globber, path = here::here()) {
  files <- list.files(path = path, pattern = globber, full.names = TRUE)
  if (length(files) == 0) {
    stop(glue::glue("No files found matching pattern: {globber} in {path}"))
  }
  file_info <- file.info(files)
  return(files[which.max(file_info$mtime)])
}


#' Create a date-stamped filename
#'
#' @param stem The base name of the file.
#' @param suffix The file extension.
#' @param sep Separator between stem and date.
#' @param format The date format string.
#' @return A character string for the new filename.
date_file <- function(stem, suffix, sep = "-", format = '%b-%d-%Y') {
  hoy <- format(today(), format)
  suffix <- str_remove(suffix, "^\\.")
  return(glue::glue("{stem}{sep}{hoy}.{suffix}"))
}


#' Create a list of names to block
#'
#' These are manually identified names that are too generic or ambiguous.
#'
#' @return A unique character vector of names to block.
block_list <- function() {
  block <- c(
    'alcohol', 'Bly', 'Polyester', 'Alkanes', 'alkanes', 'red 4, 33', 'rose',
    'Organic electrolyte principally involves ester carbonate', 'PP', 'Amine soap',
    'Free Amines', 'Acrylic Polymer', 'Acrylic Polymers', 'Urethane Polymer',
    'Caustic Salt', '', 'Aflatoxins', 'Aminoglycosides', 'Anabolic steroids',
    'Analgesic mixtures containing Phenacetin', 'Aristolochic acids',
    'Barbiturates', 'Benzodiazepines', 'Conjugated estrogens',
    'Dibenzanthracenes', 'Estrogens, steroidal',
    'Estrogen-progestogen (combined) used as menopausal therapy',
    'Etoposide in combination with cisplatin and bleomycin',
    'Cyanide salts that readily dissociate in solution (expressed as cyanide)f'
  )
  return(unique(block))
}


#' Known Unicode characters and their ASCII replacements
#'
#' @return A named character vector for substitutions.
known_encodings <- function() {
  unis <- c(
    "\u2032" = "'",
    "\u03c9" = ".omega.",
    "\xae" = " (registered trademark)",
    "\u2013" = "--",
    "\xb0" = " degrees ",
    "\u2019" = "'",
    "\u2026" = "...",
    "\u03b1" = ".alpha."
  )
  return(unis)
}

# -----------------------------------------------------------------------------
# 3. DATA PROCESSING PIPELINE FUNCTIONS
# -----------------------------------------------------------------------------

#' Fix known unicode encodings
#'
#' Replaces specific Unicode characters with their ASCII equivalents and
#' logs the change in the comment column.
#'
#' @param df The input data frame.
#' @param col The column containing the chemical name.
#' @param comment The column for comments.
#' @return The modified data frame.
fix_encodings <- function(df, col = "chemical_name", comment = "name_comment") {
  unis <- known_encodings()
  df_out <- df
  
  for (i in seq_along(unis)) {
    char_to_find <- names(unis)[i]
    replacement <- unis[i]
    
    idx <- str_detect(df_out[[col]], fixed(char_to_find)) & !is.na(df_out[[col]])
    
    if (any(idx)) {
      df_out[[col]][idx] <- str_replace_all(df_out[[col]][idx], fixed(char_to_find), replacement)
      
      comment_text <- glue::glue("swapped {char_to_find} with {replacement}")
      df_out[[comment]][idx] <- map2_chr(
        df_out[[comment]][idx],
        comment_text,
        ~append_col(.x, .y, comment = "Unicode detected")
      )
    }
  }
  return(df_out)
}


#' Remove names that are just chemical formulas
#'
#' @param df The input data frame.
#' @return The modified data frame.
correct_formula <- function(df, col = 'chemical_name', comment = 'name_comment') {
  df %>%
    mutate(
      is_formula = map_lgl(.data[[col]], find_formula),
      across(
        all_of(comment),
        ~ if_else(is_formula,
                  append_col(.x, .data[[col]], "Name only formula"),
                  .x)
      ),
      across(
        all_of(col),
        ~ if_else(is_formula, NA_character_, .x)
      )
    ) %>%
    select(-is_formula)
}


#' Drop terminal parenthesis or brackets
#'
#' @param df The input data frame.
#' @return The modified data frame.
drop_terminal_phrases <- function(df, col = 'chemical_name', comment = 'name_comment') {
  df %>%
    # Process parentheses
    mutate(
      parenth_data = map(.data[[col]], term_parenth),
      parenth_removed = map_chr(parenth_data, "removed"),
      "{col}" := map_chr(parenth_data, "phrase")
    ) %>%
    mutate(
      "{comment}" := map2_chr(
        .data[[comment]], parenth_removed,
        ~append_col(.x, .y, "Extraneous parenthesis")
      )
    ) %>%
    # Process brackets
    mutate(
      bracket_data = map(.data[[col]], term_bracket),
      bracket_removed = map_chr(bracket_data, "removed"),
      "{col}" := map_chr(bracket_data, "phrase")
    ) %>%
    mutate(
      "{comment}" := map2_chr(
        .data[[comment]], bracket_removed,
        ~append_col(.x, .y, "Extraneous brackets")
      )
    ) %>%
    select(-parenth_data, -parenth_removed, -bracket_data, -bracket_removed) %>%
    mutate(across(all_of(col), str_trim))
}


#' Drop chemical names that are just Functional Categories (FCs)
#'
#' @param df The input data frame.
#' @return The modified data frame.
drop_fcs <- function(df, col = 'chemical_name', comment = 'name_comment') {
  fcs_df <- function_categories()
  fc_regex <- fc_string()
  
  df %>%
    mutate(
      is_fc = if (nrow(fcs_df) > 0) str_to_lower(.data[[col]]) %in% fcs_df$fc_clean else FALSE,
      is_fc_like = str_detect(str_to_lower(.data[[col]]), fc_regex) & !str_detect(.data[[col]], "\\d"),
      is_generic = is_fc | is_fc_like,
      across(
        all_of(comment),
        ~ if_else(is_generic,
                  append_col(.x, .data[[col]], "Name is functional use"),
                  .x)
      ),
      across(
        all_of(col),
        ~ if_else(is_generic, NA_character_, .x)
      )
    ) %>%
    select(-is_fc, -is_fc_like, -is_generic)
}


#' Drop chemical names that are food products
#'
#' @param df The input data frame.
#' @return The modified data frame.
drop_foods <- function(df, col = 'chemical_name', comment = 'name_comment') {
  food_regex <- foods()
  df %>%
    mutate(
      is_food = str_detect(str_to_lower(.data[[col]]), food_regex),
      across(
        all_of(comment),
        ~ if_else(is_food,
                  append_col(.x, .data[[col]], "Name is food"),
                  .x)
      ),
      across(
        all_of(col),
        ~ if_else(is_food, NA_character_, .x)
      )
    ) %>%
    select(-is_food)
}


#' Drop names containing stop words or are otherwise ambiguous
#'
#' @param df The input data frame.
#' @return The modified data frame.
drop_stoppers <- function(df, col = 'chemical_name', comment = 'name_comment') {
  stop_words_regex <- paste(stops(), collapse = "|")
  ambiguous_terms <- c("polymer", 'polymers', 'wax', "mixture", "citron", "compound")
  
  df %>%
    mutate(
      is_stopper = str_detect(str_to_lower(.data[[col]]), stop_words_regex) & !str_detect(str_to_lower(.data[[col]]), "yl"),
      is_ambiguous = str_to_lower(.data[[col]]) %in% ambiguous_terms | str_detect(str_to_lower(.data[[col]]), "citron|compound"),
      is_removable = is_stopper | is_ambiguous,
      across(
        all_of(comment),
        ~ if_else(is_removable,
                  append_col(.x, .data[[col]], "Ambiguous name"),
                  .x)
      ),
      across(
        all_of(col),
        ~ if_else(is_removable, NA_character_, .x)
      )
    ) %>%
    select(-is_stopper, -is_ambiguous, -is_removable)
}


#' Move CAS-RNs found in chemical names to the CAS-RN column
#'
#' @param df The input data frame.
#' @return The modified data frame.
casrn_finder <- function(df, cas_col = 'casrn', name_col = 'chemical_name', comment = 'name_comment') {
    df %>%
        mutate(
            cas_in_name = map(!!sym(name_col), casrn_split),
            has_cas_in_name = !is.na(cas_in_name)
        ) %>%
        # Combine existing CASRN with those found in the name
        rowwise() %>%
        mutate(
            "{cas_col}" := {
                all_cas <- c(na.omit(!!sym(cas_col)), na.omit(unlist(cas_in_name)))
                if (length(all_cas) > 0) paste(unique(all_cas), collapse = ", ") else NA_character_
            }
        ) %>%
        ungroup() %>%
        # Add a comment and clean the name
        mutate(
            "{comment}" := if_else(
                has_cas_in_name,
                append_col(!!sym(comment), !!sym(cas_col), "CAS-RN in name; copied to casrn column"),
                !!sym(comment)
            ),
            "{name_col}" := if_else(
                has_cas_in_name,
                str_remove_all(!!sym(name_col), "\\(CAS Reg\\. No\\. [1-9][0-9]{1,6}-[0-9]{2}-[0-9]\\)"),
                !!sym(name_col)
            )
        ) %>%
        select(-cas_in_name, -has_cas_in_name)
}

#' Split rows with multiple CAS-RNs into separate rows
#'
#' @param df The input data frame.
#' @return The modified data frame, potentially with more rows.
split_casrns <- function(df, col = 'casrn', comment = 'casrn_comment') {
  df %>%
    mutate(
      casrn_list = map(.data[[col]], casrn_split),
      num_cas = map_int(casrn_list, ~if(is.na(.x[1])) 0 else length(.x)),
      "{comment}" := if_else(
        num_cas > 1,
        append_col(.data[[comment]], paste(unlist(casrn_list), collapse = ","), "Multiple CAS-RN on line"),
        .data[[comment]]
      )
    ) %>%
    select(-num_cas) %>%
    rename("{col}" := casrn_list) %>%
    unnest(.data[[col]], keep_empty = TRUE)
}

# -----------------------------------------------------------------------------
# 4. MAIN SCRIPT
# -----------------------------------------------------------------------------
# Set working directory if needed, e.g., setwd("path/to/your/data")

# Find the latest uncurated file
ifile <- newest_file(globber = "uncurated_chemicals.*\\.csv")
message(paste("Processing file:", ifile))

# Load data and prepare initial columns
data_raw <- read_csv(ifile, col_types = cols(.default = "c"))

# The main cleaning pipeline
cleaned_data <- data_raw %>%
  # --- Initial Setup and Canonicalization ---
  mutate(
    chemical_name = as.character(raw_chem_name),
    casrn = as.character(raw_cas),
    casrn_comment = NA_character_,
    name_comment = NA_character_
  ) %>%
  mutate(
    # Clean CASRN strings
    casrn = casrn %>%
      str_trim() %>%
      str_replace_all(fixed("..."), "") %>%
      str_replace_all(fixed(" (registered trademark)"), "") %>%
      str_replace_all(fixed("#"), "") %>%
      str_remove_all("^\\*|\\*$") %>%
      str_squish() %>%
      str_replace_all(" ", ""),
    # Clean Chemical Name strings
    chemical_name = chemical_name %>%
      str_trim() %>%
      str_replace_all(fixed("..."), "") %>%
      str_replace_all(fixed(" (registered trademark)"), "") %>%
      str_replace_all(fixed("#"), "") %>%
      str_remove_all("^\\*|\\*$") %>%
      str_squish()
  ) %>%
  # Replace empty strings/placeholders with NA
  mutate(
    casrn = if_else(casrn %in% c("-", ""), NA_character_, casrn),
    chemical_name = if_else(chemical_name == "", NA_character_, chemical_name)
  ) %>%

  # --- Chemical Name Cleaning Steps ---
  fix_encodings() %>%
  correct_formula() %>%
  drop_terminal_phrases() %>%
  drop_fcs() %>%
  drop_foods() %>%
  drop_stoppers() %>%
  
  # Drop extraneous text
  mutate(
    name_lower = str_to_lower(chemical_name),
    
    # Remove "Part *:" prefixes
    is_part = str_detect(name_lower, "part [a-z]:"),
    name_comment = if_else(is_part, append_col(name_comment, str_extract(chemical_name, ".*:"), "Removed text"), name_comment),
    chemical_name = if_else(is_part, str_replace(chemical_name, ".*:", ""), chemical_name),
    
    # Remove names with "modified"
    is_modified = str_detect(name_lower, "modif"),
    name_comment = if_else(is_modified, append_col(name_comment, chemical_name, "Unknown modification"), name_comment),
    chemical_name = if_else(is_modified, NA_character_, chemical_name),

    # Remove quality adjectives like 'pure', 'grade'
    quality_regex = "(?i)\\b(pure|purif(y|ied)|tech|grade|chemical)\\b",
    has_quality = str_detect(name_lower, quality_regex),
    quality_words = str_extract_all(chemical_name, quality_regex),
    name_comment = if_else(has_quality, map2_chr(name_comment, quality_words, ~append_col(.x, paste(.y, collapse = " "), "Unneeded adjective")), name_comment),
    chemical_name = if_else(has_quality, str_remove_all(chemical_name, quality_regex), chemical_name),

    # Remove terminal percentage
    percent_regex = "\\s*\\d+\\s*%$",
    has_percent = str_detect(chemical_name, percent_regex),
    percent_val = str_extract(chemical_name, percent_regex),
    name_comment = if_else(has_percent, append_col(name_comment, percent_val, "Removed text"), name_comment),
    chemical_name = if_else(has_percent, str_remove(chemical_name, percent_regex), chemical_name)
  ) %>%
  select(-name_lower, -starts_with("is_"), -starts_with("has_"), -ends_with("_regex"), -ends_with("words"), -ends_with("val")) %>%
  
  # Remove terminal ", unspecified"
  mutate(
    unspec_regex = '(?i)[.?\\-",]+\\s+unspecified$',
    has_unspec = str_detect(chemical_name, unspec_regex),
    unspec_val = str_extract(chemical_name, unspec_regex),
    name_comment = if_else(has_unspec, append_col(name_comment, unspec_val, "Unspecified warning"), name_comment),
    chemical_name = if_else(has_unspec, str_remove(chemical_name, unspec_regex), chemical_name)
  ) %>%
  select(-has_unspec, -unspec_val, -unspec_regex) %>%
  
  # Remove ambiguous salt references
  mutate(
    salt_regex = '(?i)\\s*(and its .* salts|and its salts)\\s*',
    has_salt = str_detect(chemical_name, salt_regex),
    salt_val = str_extract(chemical_name, salt_regex),
    name_comment = if_else(has_salt, append_col(name_comment, salt_val, "Ambiguous salt reference"), name_comment),
    chemical_name = if_else(has_salt, str_split(chemical_name, salt_regex) %>% map_chr(1), chemical_name)
  ) %>%
  select(-has_salt, -salt_val, -salt_regex) %>%
  
  # Final name cleanup
  drop_terminal_phrases() %>%
  mutate(
    chemical_name = chemical_name %>% str_squish() %>% str_remove_all("(^[,\\-.*]+)|([,\\-.*]+$)") %>% str_trim(),
    chemical_name = if_else(chemical_name == "", NA_character_, chemical_name)
  ) %>%

  # --- Move CASRNs from Name to CASRN column ---
  casrn_finder() %>%
  
  # --- CASRN Cleaning Steps ---
  # Mark non-CASRN strings for removal
  mutate(
    casrn_regex = "[1-9][0-9]{1,6}-[0-9]{2}-[0-9]",
    is_not_cas = !str_detect(casrn, casrn_regex) & !is.na(casrn),
    casrn_comment = if_else(is_not_cas, append_col(casrn_comment, casrn, "String is not CAS-RN"), casrn_comment),
    casrn = if_else(is_not_cas, NA_character_, casrn)
  ) %>%
  select(-is_not_cas, -casrn_regex) %>%
  
  # Split multiple CASRNs into new rows
  split_casrns() %>%
  
  # Validate CASRN checksum
  mutate(
    checksum_valid = map_lgl(casrn, ~if(is.na(.x)) TRUE else checksum(.x)),
    casrn_comment = if_else(!checksum_valid, append_col(casrn_comment, casrn, "CAS-RN failed checksum"), casrn_comment),
    casrn = if_else(!checksum_valid, NA_character_, casrn)
  ) %>%
  select(-checksum_valid) %>%
  
  # Final CASRN cleanup
  mutate(
    casrn = casrn %>% str_squish() %>% str_remove_all("(^[,\\-.*]+)|([,\\-.*]+$)") %>% str_trim(),
    casrn = if_else(casrn == "", NA_character_, casrn)
  ) %>%

  # --- Final Filtering and Tidying ---
  # Re-squish chemical name after all manipulations
  mutate(chemical_name = str_squish(chemical_name)) %>%
  
  # Drop names from the block list
  mutate(
    on_block_list = chemical_name %in% block_list(),
    name_comment = if_else(on_block_list, append_col(name_comment, chemical_name, "Name is on block list"), name_comment),
    chemical_name = if_else(on_block_list, NA_character_, chemical_name)
  ) %>%
  select(-on_block_list) %>%
  
  # Drop records where both cleaned name and cleaned casrn are null
  filter(!(is.na(chemical_name) & is.na(casrn))) %>%
  
  # Manual flag from original script: remove names containing "cyanidef"
  filter(!str_detect(chemical_name, "cyanidef") | is.na(chemical_name))

# --- Save Output ---
output_file <- date_file("cleaned_chemicals_for_curation", "xlsx")
write_xlsx(cleaned_data, path = output_file)

message(paste("Processing complete. Cleaned data saved to:", output_file))

# --- END OF FILE clean_chems.R ---