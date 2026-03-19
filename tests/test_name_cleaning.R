# Test file for name cleaning functions
# Tests for NAME-01 through NAME-04: parenthetical stripping, formula extraction,
# synonym splitting, quality adjective removal, salt references, and unspecified suffixes

library(testthat)
library(here)
library(tibble)
library(dplyr)

# Source the cleaning pipeline module
source(here::here("R", "cleaning_pipeline.R"))

# ==============================================================================
# NAME-01: strip_terminal_enclosures - parenthetical and bracket stripping
# ==============================================================================

test_that("strip_terminal_enclosures removes terminal parentheticals", {
  df <- tibble::tibble(
    chemical_name = c("Acetone (ACS reagent)", "Sodium chloride (NaCl)", "Water")
  )
  tag_map <- list(chemical_name = "Name")

  result <- strip_terminal_enclosures(df, names(tag_map)[tag_map == "Name"])
  cleaned <- result$cleaned_data

  expect_equal(cleaned$chemical_name[1], "Acetone")
  expect_equal(cleaned$chemical_name[2], "Sodium chloride")
  expect_equal(cleaned$chemical_name[3], "Water")
})

test_that("strip_terminal_enclosures removes terminal brackets", {
  df <- tibble::tibble(
    chemical_name = c("Sodium chloride [food grade]", "Water [purified]")
  )
  tag_map <- list(chemical_name = "Name")

  result <- strip_terminal_enclosures(df, names(tag_map)[tag_map == "Name"])
  cleaned <- result$cleaned_data

  expect_equal(cleaned$chemical_name[1], "Sodium chloride")
  expect_equal(cleaned$chemical_name[2], "Water")
})

test_that("strip_terminal_enclosures preserves parentheticals containing 'yl'", {
  df <- tibble::tibble(
    chemical_name = c("dimethyl (methyl)", "ethanol (ethyl alcohol)")
  )
  tag_map <- list(chemical_name = "Name")

  result <- strip_terminal_enclosures(df, names(tag_map)[tag_map == "Name"])
  cleaned <- result$cleaned_data

  expect_equal(cleaned$chemical_name[1], "dimethyl (methyl)")
  expect_equal(cleaned$chemical_name[2], "ethanol (ethyl alcohol)")
})

test_that("strip_terminal_enclosures removes 'yl' parentheticals with exception words", {
  df <- tibble::tibble(
    chemical_name = c("compound (high density)", "polymer (probably crosslinked)")
  )
  tag_map <- list(chemical_name = "Name")

  result <- strip_terminal_enclosures(df, names(tag_map)[tag_map == "Name"])
  cleaned <- result$cleaned_data

  expect_equal(cleaned$chemical_name[1], "compound")
  expect_equal(cleaned$chemical_name[2], "polymer")
})

test_that("strip_terminal_enclosures preserves non-terminal parentheticals", {
  df <- tibble::tibble(
    chemical_name = c("mid (paren) text", "compound (a) with (b) end")
  )
  tag_map <- list(chemical_name = "Name")

  result <- strip_terminal_enclosures(df, names(tag_map)[tag_map == "Name"])
  cleaned <- result$cleaned_data

  expect_equal(cleaned$chemical_name[1], "mid (paren) text")
  expect_equal(cleaned$chemical_name[2], "compound (a) with (b) end")
})

test_that("strip_terminal_enclosures handles NA gracefully", {
  df <- tibble::tibble(
    chemical_name = c("Acetone", NA_character_, "Water")
  )
  tag_map <- list(chemical_name = "Name")

  result <- strip_terminal_enclosures(df, names(tag_map)[tag_map == "Name"])
  cleaned <- result$cleaned_data

  expect_equal(cleaned$chemical_name[1], "Acetone")
  expect_true(is.na(cleaned$chemical_name[2]))
  expect_equal(cleaned$chemical_name[3], "Water")
})

test_that("strip_terminal_enclosures handles text with no parentheticals", {
  df <- tibble::tibble(
    chemical_name = c("no parens at all", "another clean name")
  )
  tag_map <- list(chemical_name = "Name")

  result <- strip_terminal_enclosures(df, names(tag_map)[tag_map == "Name"])
  cleaned <- result$cleaned_data

  expect_equal(cleaned$chemical_name[1], "no parens at all")
  expect_equal(cleaned$chemical_name[2], "another clean name")
})

# ==============================================================================
# NAME-02: Formula extraction preserved
# ==============================================================================

test_that("strip_terminal_enclosures preserves stripped content in formula_extract column", {
  df <- tibble::tibble(
    chemical_name = c("Sodium chloride (NaCl)", "Acetone (ACS reagent)", "Water")
  )
  tag_map <- list(chemical_name = "Name")

  result <- strip_terminal_enclosures(df, names(tag_map)[tag_map == "Name"])
  cleaned <- result$cleaned_data

  expect_true("formula_extract_chemical_name" %in% names(cleaned))
  expect_equal(cleaned$formula_extract_chemical_name[1], "NaCl")
  expect_equal(cleaned$formula_extract_chemical_name[2], "ACS reagent")
  expect_true(is.na(cleaned$formula_extract_chemical_name[3]))
})

test_that("strip_terminal_enclosures returns audit trail for stripping", {
  df <- tibble::tibble(
    chemical_name = c("Acetone (ACS reagent)", "Water")
  )
  tag_map <- list(chemical_name = "Name")

  result <- strip_terminal_enclosures(df, names(tag_map)[tag_map == "Name"])
  audit <- result$audit_trail

  expect_s3_class(audit, "tbl_df")
  expect_named(audit, c("row_id", "field", "step", "original_value", "new_value", "reason"))
  expect_gt(nrow(audit), 0)
})

# ==============================================================================
# NAME-03: split_synonyms - IUPAC-aware comma/semicolon splitting
# ==============================================================================

test_that("split_synonyms splits comma-separated synonyms", {
  df <- tibble::tibble(
    original_row_id = 1L,
    chemical_name = "xylene, dimethylbenzene, xylol"
  )
  tag_map <- list(chemical_name = "Name")

  result <- split_synonyms(df, names(tag_map)[tag_map == "Name"], tag_map)
  cleaned <- result$cleaned_data

  expect_equal(nrow(cleaned), 3)
  expect_equal(cleaned$chemical_name[1], "xylene")
  expect_equal(cleaned$chemical_name[2], "dimethylbenzene")
  expect_equal(cleaned$chemical_name[3], "xylol")
})

test_that("split_synonyms splits semicolon-separated synonyms", {
  df <- tibble::tibble(
    original_row_id = 1L,
    chemical_name = "acetone; dimethyl ketone"
  )
  tag_map <- list(chemical_name = "Name")

  result <- split_synonyms(df, names(tag_map)[tag_map == "Name"], tag_map)
  cleaned <- result$cleaned_data

  expect_equal(nrow(cleaned), 2)
  expect_equal(cleaned$chemical_name[1], "acetone")
  expect_equal(cleaned$chemical_name[2], "dimethyl ketone")
})

test_that("split_synonyms protects IUPAC digit-comma-digit patterns", {
  df <- tibble::tibble(
    original_row_id = c(1L, 2L, 3L),
    chemical_name = c("butane, 2,2-dimethyl", "1,4-Dioxane", "2,4-dichlorophenol")
  )
  tag_map <- list(chemical_name = "Name")

  result <- split_synonyms(df, names(tag_map)[tag_map == "Name"], tag_map)
  cleaned <- result$cleaned_data

  # Row 1 is IUPAC inverted name - should NOT split
  expect_equal(nrow(cleaned), 3)  # 3 rows stay 3 rows
  expect_equal(cleaned$chemical_name[1], "butane, 2,2-dimethyl")
  expect_equal(cleaned$chemical_name[2], "1,4-Dioxane")
  expect_equal(cleaned$chemical_name[3], "2,4-dichlorophenol")
})

test_that("split_synonyms tracks original_row_id for synonym rows", {
  df <- tibble::tibble(
    original_row_id = 1L,
    chemical_name = "xylene, dimethylbenzene"
  )
  tag_map <- list(chemical_name = "Name")

  result <- split_synonyms(df, names(tag_map)[tag_map == "Name"], tag_map)
  cleaned <- result$cleaned_data

  expect_equal(nrow(cleaned), 2)
  expect_equal(cleaned$original_row_id[1], 1)
  expect_equal(cleaned$original_row_id[2], 1)
})

test_that("split_synonyms sets CAS columns to NA for synonym rows", {
  df <- tibble::tibble(
    original_row_id = 1L,
    cas_number = "67-64-1",
    chemical_name = "acetone, dimethyl ketone"
  )
  tag_map <- list(cas_number = "CASRN", chemical_name = "Name")

  result <- split_synonyms(df, names(tag_map)[tag_map == "Name"], tag_map)
  cleaned <- result$cleaned_data

  expect_equal(nrow(cleaned), 2)
  expect_equal(cleaned$cas_number[1], "67-64-1")  # Primary row keeps CAS
  expect_true(is.na(cleaned$cas_number[2]))       # Synonym row gets NA
})

test_that("split_synonyms adds synonym_count and synonym_index columns", {
  df <- tibble::tibble(
    original_row_id = 1L,
    chemical_name = "xylene, dimethylbenzene, xylol"
  )
  tag_map <- list(chemical_name = "Name")

  result <- split_synonyms(df, names(tag_map)[tag_map == "Name"], tag_map)
  cleaned <- result$cleaned_data

  expect_true("synonym_count" %in% names(cleaned))
  expect_true("synonym_index" %in% names(cleaned))
  expect_equal(cleaned$synonym_count[1], 3)
  expect_equal(cleaned$synonym_index[1], 1)
  expect_equal(cleaned$synonym_index[2], 2)
  expect_equal(cleaned$synonym_index[3], 3)
})

test_that("split_synonyms removes empty strings after split", {
  df <- tibble::tibble(
    original_row_id = 1L,
    chemical_name = "acetone, , water"
  )
  tag_map <- list(chemical_name = "Name")

  result <- split_synonyms(df, names(tag_map)[tag_map == "Name"], tag_map)
  cleaned <- result$cleaned_data

  expect_equal(nrow(cleaned), 2)  # Empty string removed
  expect_equal(cleaned$chemical_name[1], "acetone")
  expect_equal(cleaned$chemical_name[2], "water")
})

test_that("split_synonyms handles single names without splitting", {
  df <- tibble::tibble(
    original_row_id = 1L,
    chemical_name = "acetone"
  )
  tag_map <- list(chemical_name = "Name")

  result <- split_synonyms(df, names(tag_map)[tag_map == "Name"], tag_map)
  cleaned <- result$cleaned_data

  expect_equal(nrow(cleaned), 1)
  expect_equal(cleaned$chemical_name[1], "acetone")
})

test_that("split_synonyms returns audit trail with split information", {
  df <- tibble::tibble(
    original_row_id = 1L,
    chemical_name = "xylene, dimethylbenzene"
  )
  tag_map <- list(chemical_name = "Name")

  result <- split_synonyms(df, names(tag_map)[tag_map == "Name"], tag_map)
  audit <- result$audit_trail

  expect_s3_class(audit, "tbl_df")
  expect_gt(nrow(audit), 0)
})

test_that("split_synonyms protects letter-comma-letter IUPAC patterns", {
  df <- tibble::tibble(
    original_row_id = c(1L, 2L, 3L),
    chemical_name = c("N,N-Dimethylformamide", "O,O-Diethyl phosphorothioate", "S,S-Dimethyl dithiocarbonate")
  )
  tag_map <- list(chemical_name = "Name")

  result <- split_synonyms(df, names(tag_map)[tag_map == "Name"], tag_map)
  cleaned <- result$cleaned_data

  # All should remain unsplit (1 row each)
  expect_equal(nrow(cleaned), 3)
  expect_equal(cleaned$chemical_name[1], "N,N-Dimethylformamide")
  expect_equal(cleaned$chemical_name[2], "O,O-Diethyl phosphorothioate")
  expect_equal(cleaned$chemical_name[3], "S,S-Dimethyl dithiocarbonate")

  # All should have synonym_count = 1 (not split)
  expect_equal(cleaned$synonym_count[1], 1)
  expect_equal(cleaned$synonym_count[2], 1)
  expect_equal(cleaned$synonym_count[3], 1)
})

test_that("split_synonyms still splits normal comma-separated names after IUPAC fix", {
  df <- tibble::tibble(
    original_row_id = 1L,
    chemical_name = "xylene, dimethylbenzene"
  )
  tag_map <- list(chemical_name = "Name")

  result <- split_synonyms(df, names(tag_map)[tag_map == "Name"], tag_map)
  cleaned <- result$cleaned_data

  # Should split into 2 rows
  expect_equal(nrow(cleaned), 2)
  expect_equal(cleaned$chemical_name[1], "xylene")
  expect_equal(cleaned$chemical_name[2], "dimethylbenzene")
})

test_that("split_synonyms protects multi-locant IUPAC patterns (3+ locants)", {
  df <- tibble::tibble(
    original_row_id = c(1L, 2L, 3L, 4L, 5L),
    chemical_name = c(
      "2,4,6-trichlorophenol",
      "1,2,3,4,5,6-hexachlorocyclohexane",
      "butane, 2,4,6-trimethyl",
      "acetone, 2,4-dinitrophenylhydrazone",
      "xylene, toluene"
    )
  )
  tag_map <- list(chemical_name = "Name")

  result <- split_synonyms(df, names(tag_map)[tag_map == "Name"], tag_map)
  cleaned <- result$cleaned_data

  # Row 1: multi-locant — must NOT split
  row1 <- cleaned[cleaned$original_row_id == 1L, ]
  expect_equal(nrow(row1), 1)
  expect_equal(row1$chemical_name, "2,4,6-trichlorophenol")

  # Row 2: 6-locant chain — must NOT split
  row2 <- cleaned[cleaned$original_row_id == 2L, ]
  expect_equal(nrow(row2), 1)
  expect_equal(row2$chemical_name, "1,2,3,4,5,6-hexachlorocyclohexane")

  # Row 3: inverted name + multi-locant — must NOT split
  row3 <- cleaned[cleaned$original_row_id == 3L, ]
  expect_equal(nrow(row3), 1)
  expect_equal(row3$chemical_name, "butane, 2,4,6-trimethyl")

  # Row 4: inverted name + locant — Step 2 inverted-name protection prevents split
  # "acetone, 2,4-dinitrophenylhydrazone" has ", digit" pattern — treated as inverted name
  row4 <- cleaned[cleaned$original_row_id == 4L, ]
  expect_equal(nrow(row4), 1)
  expect_equal(row4$chemical_name, "acetone, 2,4-dinitrophenylhydrazone")

  # Row 5: plain synonyms — SHOULD split into 2
  row5 <- cleaned[cleaned$original_row_id == 5L, ]
  expect_equal(nrow(row5), 2)
  expect_equal(row5$chemical_name[1], "xylene")
  expect_equal(row5$chemical_name[2], "toluene")
})

# ==============================================================================
# NAME-04: strip_quality_adjectives
# ==============================================================================

test_that("strip_quality_adjectives removes quality words", {
  df <- tibble::tibble(
    chemical_name = c("technical grade ethanol", "purified water", "pure acetone")
  )
  tag_map <- list(chemical_name = "Name")

  result <- strip_quality_adjectives(df, names(tag_map)[tag_map == "Name"])
  cleaned <- result$cleaned_data

  expect_equal(cleaned$chemical_name[1], "ethanol")
  expect_equal(cleaned$chemical_name[2], "water")
  expect_equal(cleaned$chemical_name[3], "acetone")
})

test_that("strip_quality_adjectives handles partial matches", {
  df <- tibble::tibble(
    chemical_name = c("purification reagent", "tech grade solvent")
  )
  tag_map <- list(chemical_name = "Name")

  result <- strip_quality_adjectives(df, names(tag_map)[tag_map == "Name"])
  cleaned <- result$cleaned_data

  expect_equal(cleaned$chemical_name[1], "reagent")
  expect_equal(cleaned$chemical_name[2], "solvent")
})

test_that("strip_quality_adjectives preserves percentage qualifiers", {
  df <- tibble::tibble(
    chemical_name = c("Acetone, 99.5% pure", "Ethanol 95%")
  )
  tag_map <- list(chemical_name = "Name")

  result <- strip_quality_adjectives(df, names(tag_map)[tag_map == "Name"])
  cleaned <- result$cleaned_data

  expect_equal(cleaned$chemical_name[1], "Acetone, 99.5%")
  expect_equal(cleaned$chemical_name[2], "Ethanol 95%")
})

test_that("strip_quality_adjectives returns audit trail", {
  df <- tibble::tibble(
    chemical_name = c("pure acetone", "water")
  )
  tag_map <- list(chemical_name = "Name")

  result <- strip_quality_adjectives(df, names(tag_map)[tag_map == "Name"])
  audit <- result$audit_trail

  expect_s3_class(audit, "tbl_df")
  expect_gt(nrow(audit), 0)
  expect_true(all(audit$step == "strip_quality_adjectives"))
})

# ==============================================================================
# NAME-04: strip_salt_references
# ==============================================================================

test_that("strip_salt_references removes salt patterns", {
  df <- tibble::tibble(
    chemical_name = c("lead and its salts", "mercury and its inorganic salts")
  )
  tag_map <- list(chemical_name = "Name")

  result <- strip_salt_references(df, names(tag_map)[tag_map == "Name"])
  cleaned <- result$cleaned_data

  expect_equal(cleaned$chemical_name[1], "lead")
  expect_equal(cleaned$chemical_name[2], "mercury")
})

test_that("strip_salt_references handles case insensitivity", {
  df <- tibble::tibble(
    chemical_name = c("Lead And Its Salts", "MERCURY AND ITS SALTS")
  )
  tag_map <- list(chemical_name = "Name")

  result <- strip_salt_references(df, names(tag_map)[tag_map == "Name"])
  cleaned <- result$cleaned_data

  expect_equal(cleaned$chemical_name[1], "Lead")
  expect_equal(cleaned$chemical_name[2], "MERCURY")
})

test_that("strip_salt_references returns audit trail", {
  df <- tibble::tibble(
    chemical_name = c("lead and its salts", "acetone")
  )
  tag_map <- list(chemical_name = "Name")

  result <- strip_salt_references(df, names(tag_map)[tag_map == "Name"])
  audit <- result$audit_trail

  expect_s3_class(audit, "tbl_df")
  expect_gt(nrow(audit), 0)
  expect_true(all(audit$step == "strip_salt_references"))
})

# ==============================================================================
# NAME-04: strip_terminal_unspecified
# ==============================================================================

test_that("strip_terminal_unspecified removes unspecified suffixes", {
  df <- tibble::tibble(
    chemical_name = c("compound, unspecified", "chemical - unspecified", "substance; unspecified")
  )
  tag_map <- list(chemical_name = "Name")

  result <- strip_terminal_unspecified(df, names(tag_map)[tag_map == "Name"])
  cleaned <- result$cleaned_data

  expect_equal(cleaned$chemical_name[1], "compound")
  expect_equal(cleaned$chemical_name[2], "chemical")
  expect_equal(cleaned$chemical_name[3], "substance")
})

test_that("strip_terminal_unspecified handles case insensitivity", {
  df <- tibble::tibble(
    chemical_name = c("compound, UNSPECIFIED", "chemical - Unspecified")
  )
  tag_map <- list(chemical_name = "Name")

  result <- strip_terminal_unspecified(df, names(tag_map)[tag_map == "Name"])
  cleaned <- result$cleaned_data

  expect_equal(cleaned$chemical_name[1], "compound")
  expect_equal(cleaned$chemical_name[2], "chemical")
})

test_that("strip_terminal_unspecified does not remove mid-string 'unspecified'", {
  df <- tibble::tibble(
    chemical_name = c("unspecified compound test", "test unspecified test")
  )
  tag_map <- list(chemical_name = "Name")

  result <- strip_terminal_unspecified(df, names(tag_map)[tag_map == "Name"])
  cleaned <- result$cleaned_data

  # Should only remove terminal, not mid-string
  expect_equal(cleaned$chemical_name[1], "unspecified compound test")
  expect_equal(cleaned$chemical_name[2], "test unspecified test")
})

test_that("strip_terminal_unspecified returns audit trail", {
  df <- tibble::tibble(
    chemical_name = c("compound, unspecified", "acetone")
  )
  tag_map <- list(chemical_name = "Name")

  result <- strip_terminal_unspecified(df, names(tag_map)[tag_map == "Name"])
  audit <- result$audit_trail

  expect_s3_class(audit, "tbl_df")
  expect_gt(nrow(audit), 0)
  expect_true(all(audit$step == "strip_terminal_unspecified"))
})

# ==============================================================================
# Pipeline integration
# ==============================================================================

test_that("run_cleaning_pipeline with Name columns runs name cleaning steps", {
  df <- tibble::tibble(
    cas_number = "67-64-1",
    chemical_name = "Acetone (ACS reagent), pure"
  )
  tag_map <- list(cas_number = "CASRN", chemical_name = "Name")

  result <- run_cleaning_pipeline(df, tag_map)
  cleaned <- result$cleaned_data

  # Should have stripped parenthetical and quality adjective
  expect_equal(cleaned$chemical_name, "Acetone")

  # Should have formula_extract column
  expect_true("formula_extract_chemical_name" %in% names(cleaned))
  expect_equal(cleaned$formula_extract_chemical_name, "ACS reagent")
})

test_that("run_cleaning_pipeline processes name cleaning in correct order", {
  df <- tibble::tibble(
    cas_number = NA_character_,
    chemical_name = "technical grade ethanol (95%), unspecified"
  )
  tag_map <- list(cas_number = "CASRN", chemical_name = "Name")

  result <- run_cleaning_pipeline(df, tag_map)
  cleaned <- result$cleaned_data

  # After all name cleaning steps
  expect_equal(cleaned$chemical_name, "ethanol (95%)")
})

test_that("run_cleaning_pipeline synonym splitting happens last", {
  df <- tibble::tibble(
    original_row_id = 1L,
    cas_number = "67-64-1",
    chemical_name = "acetone (pure), dimethyl ketone"
  )
  tag_map <- list(cas_number = "CASRN", chemical_name = "Name")

  result <- run_cleaning_pipeline(df, tag_map)
  cleaned <- result$cleaned_data

  # Should have 2 rows after split
  expect_equal(nrow(cleaned), 2)

  # Primary name should have cleaned parenthetical and quality first
  expect_equal(cleaned$chemical_name[1], "acetone")
  expect_equal(cleaned$chemical_name[2], "dimethyl ketone")

  # Synonym should have NA CAS
  expect_equal(cleaned$cas_number[1], "67-64-1")
  expect_true(is.na(cleaned$cas_number[2]))
})

test_that("run_cleaning_pipeline skips name cleaning when no Name columns", {
  df <- tibble::tibble(
    cas_number = "67-64-1",
    description = "test (with parens)"
  )
  tag_map <- list(cas_number = "CASRN", description = "Other")

  result <- run_cleaning_pipeline(df, tag_map)
  cleaned <- result$cleaned_data

  # Should NOT strip parentheticals from non-Name column
  expect_equal(cleaned$description, "test (with parens)")

  # Should NOT have formula_extract columns
  expect_false(any(grepl("formula_extract", names(cleaned))))
})

test_that("run_cleaning_pipeline removes rows where all name columns are empty", {
  df <- tibble::tibble(
    cas_number = c("67-64-1", "108-88-3", "64-17-5"),
    chemical_name = c("Acetone", "pure", "Water")  # Row 2 will become empty after stripping
  )
  tag_map <- list(cas_number = "CASRN", chemical_name = "Name")

  result <- run_cleaning_pipeline(df, tag_map)
  cleaned <- result$cleaned_data

  # Row 2 should be removed (name becomes empty after quality stripping)
  expect_lt(nrow(cleaned), 3)
})

test_that("run_cleaning_pipeline includes all name cleaning steps in audit trail", {
  df <- tibble::tibble(
    cas_number = "67-64-1",
    chemical_name = "Acetone (ACS reagent), pure, unspecified"
  )
  tag_map <- list(cas_number = "CASRN", chemical_name = "Name")

  result <- run_cleaning_pipeline(df, tag_map)
  audit <- result$audit_trail

  # Should have entries from name cleaning steps
  steps <- unique(audit$step)
  expect_true("strip_terminal_enclosures" %in% steps)
  expect_true("strip_quality_adjectives" %in% steps)
  expect_true("strip_terminal_unspecified" %in% steps)
})
