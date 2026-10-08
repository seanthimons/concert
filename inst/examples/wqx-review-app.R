# Actual application with synthetic WQX evidence and process-local services.
# Source from the package root; the wrapper also supports exported replay code.
wqx_review_fixture_dictionary <- function() {
  tibble::tibble(name = c("Arsenic", "Dissolved oxygen", "DO", "Tetracycline"),
    canonical_name = c("Arsenic", "Dissolved oxygen", "Dissolved oxygen", "Tetracycline"),
    type = c("canonical", "canonical", "synonym", "canonical"),
    cas_number = c("7440-38-2", NA_character_, NA_character_, "60-54-8"),
    group_name = NA_character_, description = "Synthetic review fixture")
}

with_wqx_review_fixture_services <- function(code) {
  withr::local_envvar(ctx_api_key = "synthetic-service-key")
  testthat::local_mocked_bindings(
    search_exact = function(names, ...) tibble::tibble(searchValue = names, dtxsid = NA_character_,
      preferredName = NA_character_, searchName = NA_character_, rank = NA_integer_),
    load_wqx_dictionary = function(...) wqx_review_fixture_dictionary(),
    validate_and_lookup_cas = function(ids, ..., preserve_candidates = FALSE) {
      candidate <- unname(c("7440-38-2" = "DTXSID999000001", "60-54-8" = "DTXSID999000003")[ids])
      tibble::tibble(original_cas = ids, validated_cas = ids, dtxsid = candidate,
        preferredName = ifelse(is.na(candidate), NA_character_, "Synthetic dictionary-CAS candidate"),
        rank = ifelse(is.na(candidate), NA_integer_, 1L), is_valid = !is.na(candidate),
        lookup_status = ifelse(is.na(candidate), "not_found", "candidate"))
    },
    validate_manual_dtxsids = function(ids, ...) tibble::tibble(dtxsid = ids,
      is_valid = ids %in% c("DTXSID999000001", "DTXSID999000003")),
    postprocess_curation_candidates = function(resolution_state, ...) {
      concert:::empty_postprocess_result(resolution_state, NULL, character())
    },
    find_related_parent_candidates = function(...) tibble::tibble(),
    .package = "concert")
  testthat::local_mocked_bindings(
    chemi_resolver_lookup_bulk = function(ids, ...) lapply(ids, function(query) list(query = query, result = "NOT_RESOLVED")),
    pubchem_search = function(name, ...) tibble::tibble(cid = integer()),
    pubchem_synonyms = function(...) tibble::tibble(cid = integer(), synonym = character()),
    .package = "ComptoxR")
  force(code)
}

run_wqx_review_app <- function(port = 63326L, launch.browser = interactive()) {
  devtools::load_all(quiet = TRUE)
  message("Synthetic WQX/registry services active; no chemical assignments are validated.")
  with_wqx_review_fixture_services(concert::run_app(port = port, launch.browser = launch.browser))
}
