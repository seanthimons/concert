# Pinned tables; retain the published graph without turning it into a tree.
media_artifact_version <- function() "envharmonizer-v0.1.1"

verify_media_file <- function(path, hash) {
  if (!file.exists(path) || !identical(digest::digest(file = path, algo = "sha256"), hash)) {
    stop(sprintf("Media artifact hash mismatch: %s. Restore the pinned v0.1.1 artifacts.", basename(path)), call. = FALSE)
  }
}

envharmonizer_release_url <- function() {
  "https://github.com/seanthimons/envharmonizer-releases/releases/download/v0.1.1/envharmonizer-tables-0.1.1.tar.gz"
}

envharmonizer_release_files <- function() {
  c("concert_media_map.csv", "matrix_terms.csv", "matrix_edges.csv",
    "analytical_terms.csv", "analytical_synonyms.csv",
    "table-manifest.json", "release-manifest.json", "SHA256SUMS", "README.md",
    "DATA_LICENSE.md", "AMOS-ATTRIBUTION.md", "ECOTOX-ATTRIBUTION.md", "ECOTOX-REVIEW.md")
}

envharmonizer_cache_root <- function() {
  getOption("concert.envharmonizer_cache", tools::R_user_dir("concert", "cache"))
}

envharmonizer_cache_valid <- function(path) {
  manifest_path <- file.path(path, "table-manifest.json")
  if (!all(file.exists(file.path(path, envharmonizer_release_files()))) ||
      !identical(digest::digest(file = manifest_path, algo = "sha256"), envharmonizer_manifest_sha256())) {
    return(FALSE)
  }
  tables <- jsonlite::read_json(manifest_path)$tables
  csvs <- grep("\\.csv$", envharmonizer_release_files(), value = TRUE)
  all(vapply(csvs, function(csv) {
    identical(digest::digest(file = file.path(path, csv), algo = "sha256"),
      tables[[sub("\\.csv$", "", csv)]]$csv_sha256)
  }, logical(1)))
}

envharmonizer_manifest_sha256 <- function() "1e9f4bffe5f691e456af4e685e4ef6a87f3fe33af937d238786153cfca0f3c5f"

#' Download the pinned envharmonizer tables if missing or modified
#'
#' The tables are not committed. The cache directory is versioned, so bumping
#' the pin makes the next start fetch the new release.
#'
#' @param root Cache root; the release lands in `envharmonizer-0.1.1/` below it.
#' @return The cache root, invisibly.
#' @keywords internal
ensure_envharmonizer_tables <- function(root = envharmonizer_cache_root()) {
  dest <- file.path(root, "envharmonizer-0.1.1")
  if (envharmonizer_cache_valid(dest)) {
    return(invisible(root))
  }
  archive <- tempfile(fileext = ".tar.gz")
  extracted <- tempfile("envharmonizer-")
  on.exit(unlink(c(archive, extracted), recursive = TRUE), add = TRUE)
  message("Downloading pinned envharmonizer v0.1.1 tables to ", dest)
  tryCatch(
    utils::download.file(envharmonizer_release_url(), archive, mode = "wb", quiet = TRUE),
    error = function(e) {
      stop(sprintf(
        "Could not download envharmonizer tables from %s (%s). Media and method harmonization need network access on first run.",
        envharmonizer_release_url(), conditionMessage(e)
      ), call. = FALSE)
    }
  )
  verify_media_file(archive, "56da987c0fb72e08915df5b7ecf1d099fdb03c5828fa1cc85debcceefe61daca")
  files <- envharmonizer_release_files()
  utils::untar(archive, files = paste0("envharmonizer-tables-0.1.1/", files), exdir = extracted)
  if (!dir.exists(dest) && !dir.create(dest, recursive = TRUE, showWarnings = FALSE)) {
    stop("Cannot create envharmonizer cache directory: ", dest, call. = FALSE)
  }
  stopifnot(all(file.copy(file.path(extracted, "envharmonizer-tables-0.1.1", files), dest, overwrite = TRUE)))
  if (!envharmonizer_cache_valid(dest)) {
    stop("Downloaded envharmonizer tables failed integrity checks.", call. = FALSE)
  }
  invisible(root)
}

# Reads pinned release CSVs with manifest types; `keys` maps table -> unique key
# columns (NULL skips the uniqueness check).
load_envharmonizer_tables <- function(keys, source_dir = ensure_envharmonizer_tables()) {
  path <- file.path(source_dir, "envharmonizer-0.1.1")
  verify_media_file(file.path(path, "table-manifest.json"), envharmonizer_manifest_sha256())
  manifest <- jsonlite::read_json(file.path(path, "table-manifest.json"))
  stopifnot(identical(manifest$package_version, "0.1.1"),
    identical(manifest$csv_na, "__ENVHARMONIZER_MISSING__"))
  tables <- lapply(names(keys), function(name) {
    spec <- manifest$tables[[name]]
    file <- file.path(path, paste0(name, ".csv"))
    verify_media_file(file, spec$csv_sha256)
    types <- unlist(spec$columns)
    if (!all(types %in% c("c", "l", "i", "d"))) stop("Unsupported envharmonizer manifest types.", call. = FALSE)
    tbl <- readr::read_csv(file, na = manifest$csv_na, trim_ws = FALSE,
      col_types = paste(types, collapse = ""), show_col_types = FALSE)
    key <- keys[[name]]
    if (nrow(readr::problems(tbl)) || nrow(tbl) != spec$rows ||
        !identical(names(tbl), names(types)) ||
        (length(key) && (anyDuplicated(tbl[key]) || anyNA(tbl[key])))) {
      stop(paste("Malformed envharmonizer artifact:", name), call. = FALSE)
    }
    tibble::as_tibble(as.data.frame(tbl))
  })
  names(tables) <- names(keys)
  tables
}

load_published_media_tables <- function(source_dir = ensure_envharmonizer_tables()) {
  tables <- load_envharmonizer_tables(list(concert_media_map = "term", matrix_terms = "term_id",
    matrix_edges = c("child_id", "parent_id", "relation")), source_dir)
  map <- tables$concert_media_map
  if (!all(map$term_id %in% tables$matrix_terms$term_id) ||
      !all(na.omit(map$media_category) %in% valid_media_routing_categories()) ||
      !identical(map$media_category, map$concert_unit_route)) {
    stop("Malformed media identity or routing annotations.", call. = FALSE)
  }
  tables
}
