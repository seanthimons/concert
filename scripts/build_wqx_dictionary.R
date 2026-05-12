# build_wqx_dictionary.R
# One-time build of wqx_dictionary.rds from local EPA CSV files.
# Run from package root: source("scripts/build_wqx_dictionary.R")
#
# Prerequisites:
#   1. Characteristic.csv in repo root
#   2. "Characteristic Alias.csv" in repo root
#
# Output:
#   - inst/extdata/reference_cache/wqx_dictionary.rds
#
# This replicates the cleaning logic in .build_wqx_dictionary() (R/cleaning_reference.R)
# but reads from local files instead of downloading from EPA.

CONCERT_ROOT <- here::here()

# --- Read and clean Characteristic.csv (canonical names) ---
char_path <- file.path(CONCERT_ROOT, "Characteristic.csv")
stopifnot(file.exists(char_path))

char_tbl <- readr::read_csv(char_path, show_col_types = FALSE) |>
  dplyr::select(
    name = Name,
    cas_number = `CAS Number`,
    group_name = `Group Name`,
    description = Description
  ) |>
  dplyr::mutate(
    name = trimws(name),
    canonical_name = name,
    type = "canonical"
  )

message(sprintf("Canonical rows: %d", nrow(char_tbl)))

# --- Read and clean Characteristic Alias.csv (alias mappings) ---
alias_path <- file.path(CONCERT_ROOT, "Characteristic Alias.csv")
stopifnot(file.exists(alias_path))

kept_alias_types <- c(
  "WQX SYNONYM REGISTRY (validation)",
  "STANDARDIZE NAME (Normalized)",
  "RETIRED NAME"
)
type_map <- c(
  "WQX SYNONYM REGISTRY (validation)" = "synonym",
  "STANDARDIZE NAME (Normalized)" = "standardize",
  "RETIRED NAME" = "retired"
)

alias_tbl <- readr::read_csv(alias_path, show_col_types = FALSE) |>
  dplyr::filter(`Alias Type Name` %in% kept_alias_types) |>
  dplyr::select(
    name = `Alias Name`,
    canonical_name = `Characteristic Name`,
    description = Description,
    alias_type = `Alias Type Name`
  ) |>
  dplyr::mutate(
    name = trimws(name),
    canonical_name = trimws(canonical_name),
    type = dplyr::recode(alias_type, !!!type_map),
    cas_number = NA_character_,
    group_name = NA_character_
  ) |>
  dplyr::select(-alias_type)

message(sprintf("Alias rows (3 types): %d", nrow(alias_tbl)))

# --- Combine and save ---
result <- dplyr::bind_rows(char_tbl, alias_tbl) |>
  dplyr::select(name, canonical_name, type, cas_number, group_name, description)
message(sprintf("Combined tibble: %d rows x %d columns", nrow(result), ncol(result)))

# Sanity checks
stopifnot(
  all(c("name", "canonical_name", "type", "cas_number", "group_name", "description") %in% names(result)),
  all(result$type %in% c("canonical", "synonym", "standardize", "retired")),
  !anyNA(result$name[result$type == "canonical"]),
  nrow(result) >= 120000
)

cache_path <- file.path(CONCERT_ROOT, "inst", "extdata", "reference_cache", "wqx_dictionary.rds")
fs::dir_create(dirname(cache_path), recurse = TRUE)
saveRDS(result, cache_path, compress = FALSE)
message(sprintf("Built wqx_dictionary.rds: %d rows written to %s", nrow(result), cache_path))
