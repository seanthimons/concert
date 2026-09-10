# Pinned tables; retain the published graph without turning it into a tree.
media_artifact_version <- function() "envharmonizer-v0.1.1"

verify_media_file <- function(path, hash) {
  if (!file.exists(path) || !identical(digest::digest(file = path, algo = "sha256"), hash)) {
    stop(sprintf("Media artifact hash mismatch: %s. Restore the pinned v0.1.1 artifacts.", basename(path)), call. = FALSE)
  }
}

load_published_media_tables <- function(source_dir = resolve_media_source_dir()) {
  path <- file.path(source_dir, "envharmonizer-0.1.1")
  verify_media_file(file.path(path, "table-manifest.json"),
    "1e9f4bffe5f691e456af4e685e4ef6a87f3fe33af937d238786153cfca0f3c5f")
  manifest <- jsonlite::read_json(file.path(path, "table-manifest.json"))
  stopifnot(identical(manifest$package_version, "0.1.1"),
    identical(manifest$csv_na, "__ENVHARMONIZER_MISSING__"))
  keys <- list(concert_media_map = "term", matrix_terms = "term_id",
    matrix_edges = c("child_id", "parent_id", "relation"))
  tables <- lapply(names(keys), function(name) {
    spec <- manifest$tables[[name]]
    file <- file.path(path, paste0(name, ".csv"))
    verify_media_file(file, spec$csv_sha256)
    types <- unlist(spec$columns)
    if (!all(types %in% c("c", "l", "i", "d"))) stop("Unsupported media manifest types.", call. = FALSE)
    tbl <- readr::read_csv(file, na = manifest$csv_na, trim_ws = FALSE,
      col_types = paste(types, collapse = ""), show_col_types = FALSE)
    if (nrow(readr::problems(tbl)) || nrow(tbl) != spec$rows ||
        !identical(names(tbl), names(types)) || anyDuplicated(tbl[keys[[name]]]) ||
        anyNA(tbl[keys[[name]]])) stop(paste("Malformed media artifact:", name), call. = FALSE)
    tibble::as_tibble(as.data.frame(tbl))
  })
  names(tables) <- names(keys)
  map <- tables$concert_media_map
  if (!all(map$term_id %in% tables$matrix_terms$term_id) ||
      !all(na.omit(map$media_category) %in% valid_media_routing_categories()) ||
      !identical(map$media_category, map$concert_unit_route)) {
    stop("Malformed media identity or routing annotations.", call. = FALSE)
  }
  tables
}
