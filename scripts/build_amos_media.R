# build_amos_media.R
# Deterministically generates the runtime media cache from reviewable source
# tables in inst/extdata/reference_sources.
#
# Source of truth:
#   - inst/extdata/reference_sources/media_canonical.csv
#   - inst/extdata/reference_sources/media_aliases.csv
#
# Output:
#   - inst/extdata/reference_cache/amos_media.rds
#
# AMOS remains provenance for selected aliases in media_aliases.csv, but this
# script does not fetch AMOS at runtime or rebuild opaque inferred rows.

CONCERT_ROOT <- here::here()

stopifnot(
  "readr package is required" = requireNamespace("readr", quietly = TRUE),
  "dplyr package is required" = requireNamespace("dplyr", quietly = TRUE),
  "tibble package is required" = requireNamespace("tibble", quietly = TRUE),
  "fs package is required" = requireNamespace("fs", quietly = TRUE)
)

source(file.path(CONCERT_ROOT, "R", "media_harmonizer.R"))

build_amos_media_cache <- function(root = CONCERT_ROOT) {
  source_dir <- file.path(root, "inst", "extdata", "reference_sources")
  cache_path <- file.path(root, "inst", "extdata", "reference_cache", "amos_media.rds")

  source_tables <- load_media_source_tables(source_dir)
  runtime_map <- build_media_runtime_map(source_tables)

  fs::dir_create(dirname(cache_path), recurse = TRUE)
  saveRDS(runtime_map, cache_path, compress = FALSE)

  message(sprintf(
    "Media cache written: %s (%d terms, %d pending)",
    cache_path,
    nrow(runtime_map),
    sum(runtime_map$assertion_mode == "pending", na.rm = TRUE)
  ))

  invisible(runtime_map)
}

runtime_map <- build_amos_media_cache()

former_unresolved <- c(
  "solid",
  "aqueous",
  "marine",
  "atmospheric",
  "lake",
  "runoff",
  "leachate"
)
represented <- runtime_map[runtime_map$term %in% former_unresolved, ]
message("Former unresolved AMOS terms:")
message(paste(sprintf("  - %s: %s", represented$term, represented$assertion_mode), collapse = "\n"))

#' Refresh the generated AMOS media cache
#'
#' Rebuilds inst/extdata/reference_cache/amos_media.rds from the reviewable
#' source tables. Arguments are kept for backward compatibility with older
#' callers that expected refresh_amos_cache(force, max_age_days).
#'
#' @param force Ignored. Present for backward compatibility.
#' @param max_age_days Ignored. Present for backward compatibility.
#' @return Invisibly returns the rebuilt runtime map.
#' @export
refresh_amos_cache <- function(force = TRUE, max_age_days = Inf) {
  build_amos_media_cache()
}
