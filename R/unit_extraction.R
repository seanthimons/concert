# unit_extraction.R
# Internal extraction functions for building unit conversion tables from ECOTOX/ToxVal/SSWQS.
#
# NOTE: These functions require DBI, duckdb, and arrow packages which are NOT
# in chemreg's Imports (too heavy for one-time build functions). Install manually:
#   pak::pak(c("DBI", "duckdb", "arrow"))
# Then run via: chemreg:::build_unit_conversion_table(...)
#
# These functions are INTERNAL (not exported) - one-time data build step.
# Users consume the pre-built .rds files, not these extraction functions.

#' Extract unit conversions from ECOTOX database
#'
#' Queries the ECOTOX unit_conversion table and transforms entries into
#' a standardized format with UCUM conventions and proper category inference.
#'
#' @param db_path Path to ecotox.duckdb file
#' @return A tibble with columns: from_unit, to_unit, multiplier, category, confidence, source
#'
#' @details
#' ECOTOX stores conversions to SI base units (g/l, mol/l). This function transforms

#' targets to UCUM conventions (mg/L capital L) by adjusting multipliers accordingly.
#'
#' Category inference is based on unit_domain and cur_unit_result:
#' - concentration: aqueous mass/volume, target = mg/L
#' - air_concentration: gaseous mass/volume, target = mg/m3
#' - mass_fraction: solid matrix, target = mg/kg
#' - dose: body weight adjusted rates, target = mg/kg/d
#' - molarity: molar concentrations, confidence = NEEDS_MW, multiplier = NA
#'
#' @keywords internal
extract_ecotox_units <- function(db_path) {
  if (!requireNamespace("DBI", quietly = TRUE) ||
      !requireNamespace("duckdb", quietly = TRUE)) {
    stop("DBI and duckdb packages required. Install with: pak::pak(c('DBI', 'duckdb'))")
  }

  con <- DBI::dbConnect(duckdb::duckdb(), db_path, read_only = TRUE)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  # Query all unit conversions

  result <- DBI::dbGetQuery(con, "
    SELECT
      orig,
      cur_unit_result,
      conversion_factor_unit,
      unit_domain
    FROM unit_conversion
    WHERE orig IS NOT NULL
      AND cur_unit_result IS NOT NULL
      AND conversion_factor_unit IS NOT NULL
  ")

  # Build output tibble
  n <- nrow(result)
  out <- tibble::tibble(
    from_unit = character(n),
    to_unit = character(n),
    multiplier = numeric(n),
    category = character(n),
    confidence = character(n),
    source = rep("ECOTOX", n)
  )

  for (i in seq_len(n)) {
    orig <- result$orig[i]
    cur_target <- result$cur_unit_result[i]
    ecotox_mult <- as.numeric(result$conversion_factor_unit[i])
    domain <- result$unit_domain[i]

    out$from_unit[i] <- orig

    # Determine category and transform target to UCUM
    transform_result <- transform_ecotox_to_ucum(cur_target, ecotox_mult, domain, orig)
    out$to_unit[i] <- transform_result$to_unit
    out$multiplier[i] <- transform_result$multiplier
    out$category[i] <- transform_result$category
    out$confidence[i] <- transform_result$confidence
  }

  # Deduplicate by from_unit (keep first occurrence)
  out <- out[!duplicated(out$from_unit), ]

  out
}


#' Transform ECOTOX SI targets to UCUM conventions
#'
#' Internal helper to convert ECOTOX's SI base unit targets to UCUM-compliant
#' canonical forms with adjusted multipliers.
#'
#' @param cur_target ECOTOX cur_unit_result (e.g., "g/l", "mol/l")
#' @param ecotox_mult Original ECOTOX conversion factor
#' @param domain ECOTOX unit_domain category
#' @param orig Original unit string for molarity detection
#' @return List with to_unit, multiplier, category, confidence
#'
#' @keywords internal
transform_ecotox_to_ucum <- function(cur_target, ecotox_mult, domain, orig) {
  # Default values
  to_unit <- cur_target
  multiplier <- ecotox_mult
  category <- "other"
  confidence <- "HIGH"

  # Check if this is a molarity unit (per D-14)
  is_molarity <- grepl("mol", cur_target, fixed = TRUE) ||
    grepl("^[munp]?M$", orig) ||
    grepl("mol/[lL]", orig, ignore.case = TRUE)

  if (is_molarity) {
    # Molarity entries get NEEDS_MW confidence and NA multiplier
    # Keep target as-is (mol/l -> M conceptually)
    to_unit <- "M"
    multiplier <- NA_real_
    category <- "molarity"
    confidence <- "NEEDS_MW"
    return(list(to_unit = to_unit, multiplier = multiplier,
                category = category, confidence = confidence))
  }

  # Transform based on cur_target
  if (cur_target == "g/l") {
    # Aqueous concentration: g/l -> mg/L (multiply by 1000)
    to_unit <- "mg/L"
    multiplier <- ecotox_mult * 1000
    category <- "concentration"
  } else if (cur_target == "g/m3") {
    # Air concentration: g/m3 -> mg/m3 (multiply by 1000)
    to_unit <- "mg/m3"
    multiplier <- ecotox_mult * 1000
    category <- "air_concentration"
  } else if (cur_target == "g/g") {
    # Mass fraction: g/g -> mg/kg (multiply by 1e6)
    to_unit <- "mg/kg"
    multiplier <- ecotox_mult * 1e6
    category <- "mass_fraction"
  } else if (cur_target == "g/kg" || cur_target == "mol/g") {
    # Matrix concentration
    to_unit <- "mg/kg"
    if (cur_target == "g/kg") {
      multiplier <- ecotox_mult * 1000
    }
    category <- "mass_fraction"
  } else if (grepl("g/h", cur_target, fixed = TRUE) ||
             grepl("/h", cur_target, fixed = TRUE)) {
    # Dose rate (per hour in ECOTOX, convert to per day)
    # g/g/h -> mg/kg/d: multiply by 1e6 * 24
    if (cur_target == "g/g/h") {
      to_unit <- "mg/kg/d"
      multiplier <- ecotox_mult * 1e6 * 24
      category <- "dose"
    } else {
      # Other rate units - keep as-is
      category <- "rate"
    }
  } else if (cur_target == "ppb" || cur_target == "ratio") {
    # Dimensionless ratios
    to_unit <- cur_target
    category <- "dimensionless"
  } else if (grepl("^g$", cur_target)) {
    # Mass
    to_unit <- "g"
    category <- "mass"
  } else if (grepl("^l$", cur_target)) {
    # Volume
    to_unit <- "L"
    category <- "volume"
  } else if (grepl("m2", cur_target, fixed = TRUE)) {
    # Area
    category <- "area"
  } else if (grepl("Bq", cur_target, fixed = TRUE)) {
    # Radioactivity
    category <- "radioactivity"
  } else {
    # Infer category from domain
    if (grepl("Liquid", domain, fixed = TRUE)) {
      category <- "concentration"
    } else if (grepl("Matrix", domain, fixed = TRUE)) {
      category <- "mass_fraction"
    } else if (grepl("Dosing", domain, fixed = TRUE)) {
      category <- "dose"
    } else if (grepl("Ratio|Fraction", domain)) {
      category <- "dimensionless"
    } else if (grepl("Rate", domain, fixed = TRUE)) {
      category <- "rate"
    } else if (grepl("Application", domain, fixed = TRUE)) {
      category <- "application_rate"
    }
  }

  list(
    to_unit = to_unit,
    multiplier = multiplier,
    category = category,
    confidence = confidence
  )
}


#' Extract distinct units from ToxVal database
#'
#' Queries the ToxVal toxval table for distinct unit strings.
#' Returns raw inventory for gap analysis, NOT conversion mappings.
#'
#' @param db_path Path to toxval.duckdb file
#' @return A tibble with column: unit (distinct unit strings)
#'
#' @keywords internal
extract_toxval_units <- function(db_path) {
  if (!requireNamespace("DBI", quietly = TRUE) ||
      !requireNamespace("duckdb", quietly = TRUE)) {
    stop("DBI and duckdb packages required. Install with: pak::pak(c('DBI', 'duckdb'))")
  }

  con <- DBI::dbConnect(duckdb::duckdb(), db_path, read_only = TRUE)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  result <- DBI::dbGetQuery(con, "
    SELECT DISTINCT toxval_units as unit
    FROM toxval
    WHERE toxval_units IS NOT NULL
    ORDER BY toxval_units
  ")

  tibble::as_tibble(result)
}


#' Extract distinct units from SSWQS parquet file
#'
#' Reads the SSWQS benchmark parquet file and extracts distinct unit values.
#' Returns raw inventory for gap analysis, NOT conversion mappings.
#'
#' @param parquet_path Path to sswqs.parquet file
#' @return A tibble with column: unit (distinct unit strings)
#'
#' @keywords internal
extract_sswqs_units <- function(parquet_path) {
  if (!requireNamespace("arrow", quietly = TRUE)) {
    stop("arrow package required. Install with: pak::pak('arrow')")
  }

  df <- arrow::read_parquet(parquet_path)
  units <- unique(df$unit)
  units <- units[!is.na(units)]

  tibble::tibble(unit = sort(units))
}


#' Build comprehensive unit conversion table
#'
#' Extracts units from ECOTOX (primary source), performs coverage analysis
#' against ToxVal and SSWQS, transforms to UCUM conventions, and saves
#' the result as an RDS file.
#'
#' @param ecotox_path Path to ecotox.duckdb file (required)
#' @param toxval_path Path to toxval.duckdb file (optional, for coverage analysis)
#' @param sswqs_path Path to sswqs.parquet file (optional, for coverage analysis)
#' @param output_path Path to write output RDS file
#' @return The unit conversion tibble (invisibly)
#'
#' @details
#' The output table has 6 columns:
#' - from_unit: source unit string
#' - to_unit: target canonical unit (UCUM)
#' - multiplier: conversion factor (NA for molarity units)
#' - category: unit category (concentration, air_concentration, mass_fraction, dose, molarity, etc.)
#' - confidence: HIGH, LOW, or NEEDS_MW
#' - source: provenance (ECOTOX, manual)
#'
#' @keywords internal
build_unit_conversion_table <- function(ecotox_path,
                                        toxval_path = NULL,
                                        sswqs_path = NULL,
                                        output_path) {
  message("Extracting units from ECOTOX...")
  ecotox_units <- extract_ecotox_units(ecotox_path)
  message(sprintf("  - Extracted %d unique conversions from ECOTOX", nrow(ecotox_units)))

  # Coverage analysis against ToxVal
  toxval_coverage <- NULL
  if (!is.null(toxval_path) && file.exists(toxval_path)) {
    message("Analyzing ToxVal coverage...")
    toxval_units <- extract_toxval_units(toxval_path)
    toxval_coverage <- analyze_coverage(ecotox_units$from_unit, toxval_units$unit, "ToxVal")
  }

  # Coverage analysis against SSWQS
  sswqs_coverage <- NULL
  if (!is.null(sswqs_path) && file.exists(sswqs_path)) {
    message("Analyzing SSWQS coverage...")
    sswqs_units <- extract_sswqs_units(sswqs_path)
    sswqs_coverage <- analyze_coverage(ecotox_units$from_unit, sswqs_units$unit, "SSWQS")
  }

  # Log category summary
  message("\nCategory summary:")
  cat_summary <- table(ecotox_units$category)
  for (cat in names(cat_summary)) {
    message(sprintf("  - %s: %d", cat, cat_summary[[cat]]))
  }

  # Verify air_concentration exists (per D-15)
  if (!"air_concentration" %in% ecotox_units$category) {
    message("WARNING: No air_concentration category found. Adding manual entries...")
    # Add manual air concentration entries
    air_entries <- tibble::tibble(
      from_unit = c("mg/m3", "ug/m3", "ng/m3", "g/m3"),
      to_unit = rep("mg/m3", 4),
      multiplier = c(1, 0.001, 1e-6, 1000),
      category = rep("air_concentration", 4),
      confidence = rep("HIGH", 4),
      source = rep("manual", 4)
    )
    # Add only those not already present
    new_air <- air_entries[!air_entries$from_unit %in% ecotox_units$from_unit, ]
    if (nrow(new_air) > 0) {
      ecotox_units <- dplyr::bind_rows(ecotox_units, new_air)
      message(sprintf("  - Added %d manual air_concentration entries", nrow(new_air)))
    }
  }

  # Verify molarity handling (per D-14)
  molarity_check <- ecotox_units[ecotox_units$category == "molarity", ]
  bad_molarity <- molarity_check[!is.na(molarity_check$multiplier), ]
  if (nrow(bad_molarity) > 0) {
    message(sprintf("WARNING: Found %d molarity entries with numeric multiplier (should be NA)", nrow(bad_molarity)))
  }

  # Save output
  message(sprintf("\nSaving %d rows to %s", nrow(ecotox_units), output_path))
  saveRDS(ecotox_units, output_path)

  # Final summary
  message("\n=== BUILD COMPLETE ===")
  message(sprintf("Total conversions: %d", nrow(ecotox_units)))
  message(sprintf("Categories: %d", length(unique(ecotox_units$category))))
  message(sprintf("air_concentration entries: %d", sum(ecotox_units$category == "air_concentration")))
  message(sprintf("molarity entries (NEEDS_MW): %d", sum(ecotox_units$confidence == "NEEDS_MW", na.rm = TRUE)))

  invisible(ecotox_units)
}


#' Analyze coverage of extracted units against target dataset
#'
#' @param extracted_units Character vector of extracted unit strings
#' @param target_units Character vector of target unit strings to check coverage against
#' @param source_name Name of target source for logging
#' @return List with coverage statistics
#'
#' @keywords internal
analyze_coverage <- function(extracted_units, target_units, source_name) {
  # Normalize for comparison
  extracted_lower <- tolower(trimws(extracted_units))
  target_lower <- tolower(trimws(target_units))

  # Find matches
  matched <- target_lower %in% extracted_lower
  n_matched <- sum(matched)
  n_total <- length(target_lower)
  pct_covered <- round(100 * n_matched / n_total, 1)

  message(sprintf("  - %s coverage: %d/%d (%.1f%%)", source_name, n_matched, n_total, pct_covered))

  # Report top uncovered units
  uncovered <- target_units[!matched]
  if (length(uncovered) > 0) {
    message(sprintf("  - Top 10 uncovered %s units:", source_name))
    for (u in head(uncovered, 10)) {
      message(sprintf("      %s", u))
    }
  }

  list(
    source = source_name,
    total = n_total,
    matched = n_matched,
    percent = pct_covered,
    uncovered = uncovered
  )
}
