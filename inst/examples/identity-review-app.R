# Run the actual application with process-local synthetic registry services:
# source("inst/examples/identity-review-app.R")
# run_identity_review_app()
# Upload inst/examples/identity-review-upload.csv. These are test fixtures,
# not validated chemical assignments. No pilot data is loaded or changed.
run_identity_review_app <- function(port = 63322L, launch.browser = interactive()) {
  devtools::load_all(quiet = TRUE)
  withr::local_envvar(ctx_api_key = "synthetic-service-key")
  testthat::local_mocked_bindings(
    search_exact = function(names, ...) tibble::tibble(
      searchValue = names, dtxsid = "DTXSID789", preferredName = "Synthetic lookup candidate",
      searchName = "EXACT", rank = 1L),
    validate_and_lookup_cas = function(ids, ...) tibble::tibble(
      original_cas = ids, dtxsid = NA_character_, preferredName = NA_character_,
      rank = NA_integer_, is_valid = FALSE),
    source_identifier_lookup = function(ids) tibble::tibble(
      dtxsid = ids[ids == "DTXSID123"], preferredName = "Synthetic registered mixture",
      casrn = NA_character_),
    validate_manual_dtxsids = function(ids, ...) tibble::tibble(
      searchValue = ids, dtxsid = ids, preferredName = "Synthetic registry fixture",
      is_valid = ids %in% c("DTXSID123", "DTXSID789")),
    postprocess_curation_candidates = function(resolution_state, ...) {
      concert:::empty_postprocess_result(resolution_state, NULL, character())
    },
    find_related_parent_candidates = function(...) tibble::tibble(),
    .package = "concert")
  message("Synthetic registry services active; upload identity-review-upload.csv. No assignments are validated.")
  concert::run_app(port = port, launch.browser = launch.browser)
}
