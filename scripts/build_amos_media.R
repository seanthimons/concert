# source('scripts/build_amos_media.R'); build_amos_media_cache()
# Supply archive to import the pinned release; subsequent rebuilds work offline.
build_amos_media_cache <- function(root = getwd(), archive = NULL) {
  source(file.path(root, 'R', 'media_harmonizer.R'), local = TRUE)
  source(file.path(root, 'R', 'media_artifacts.R'), local = TRUE)
  source_dir <- file.path(root, 'inst', 'extdata', 'reference_sources')
  if (!is.null(archive)) {
    verify_media_file(archive, '56da987c0fb72e08915df5b7ecf1d099fdb03c5828fa1cc85debcceefe61daca')
    files <- c('concert_media_map.csv', 'matrix_terms.csv', 'matrix_edges.csv',
      'table-manifest.json', 'release-manifest.json', 'SHA256SUMS', 'README.md',
      'DATA_LICENSE.md', 'AMOS-ATTRIBUTION.md', 'ECOTOX-ATTRIBUTION.md', 'ECOTOX-REVIEW.md')
    dest <- file.path(source_dir, 'envharmonizer-0.1.1')
    dir.create(dest, recursive = TRUE, showWarnings = FALSE)
    extracted <- tempfile('media-import-')
    dir.create(extracted)
    utils::untar(archive, files = paste0('envharmonizer-tables-0.1.1/', files), exdir = extracted)
    stopifnot(all(file.copy(file.path(extracted, 'envharmonizer-tables-0.1.1', files), dest, overwrite = TRUE)))
  }
  tables <- load_published_media_tables(source_dir)
  runtime_map <- build_media_runtime_map(tables)
  saveRDS(runtime_map, file.path(root, 'inst', 'extdata', 'reference_cache', 'amos_media.rds'), compress = FALSE, version = 3)
  invisible(runtime_map)
}

refresh_amos_cache <- function(force = TRUE, max_age_days = Inf) build_amos_media_cache()
