# Swallowed lookup failures are recorded and summarised (#150).

test_that("each swallowed lookup failure is recorded", {
  .search_failures$rows <- list()
  boom <- function(...) stop("API down")
  local_mocked_bindings(
    ct_chemical_search_equal_bulk = boom,
    ct_chemical_search_start_with = boom,
    .package = "ComptoxR"
  )
  clear_starts_with_cache()

  find_name_ties(c("a", "b"), get_fn = boom)
  suppressMessages({
    validate_and_lookup_cas(c("67-64-1", "50-00-0"))
    validate_and_lookup_cas("67-64-1", failure_label = "cas_from_names")
    search_starts_with(c("abc", "xyz"))
    # WQX evidence marks its own status, so it is not counted twice.
    validate_and_lookup_cas("67-64-1", preserve_candidates = TRUE)
  })

  failures <- collected_search_failures()
  expect_equal(failures$lookup, c("cas", "cas_from_names", "name_ties", "starts_with"))
  expect_equal(failures$n_queries, c(2L, 1L, 2L, 2L))
  expect_equal(failures$message[1], "API down")
})

test_that("the summary counts joined status columns by row", {
  rs <- tibble::tibble(
    dtxsid_name = c("DTXSID1", NA, NA),
    pubchem_lookup_status = c("hit; error", "no_hit", NA),
    resolver_lookup_status = c(NA, "unverified; error", "public")
  )
  rs[[source_field_column("dtxsid_name", "wqx_cas_lookup_status")]] <- c(NA, "unavailable", "not_found")
  summary <- search_failure_summary(list(
    results = rs,
    search_failures = tibble::tibble(lookup = "cas", n_queries = 9L, message = "x"),
    source_identifier_evidence = tibble::tibble(validation_status = c("unavailable", "valid"))
  ))
  expect_equal(summary$lookup, c("cas", "wqx_cas", "pubchem", "resolver", "source_identifier"))
  expect_equal(summary$n, c(9, 1, 1, 1, 1))
  expect_equal(summary$unit, c("queries", rep("rows", 4)))
  expect_match(search_failure_message(summary, "Retry."), "cas 9 queries, wqx_cas 1 rows.* failed\\. Retry\\.$")
  expect_null(search_failure_message(search_failure_summary(list(results = rs[0, ])), "Retry."))
})
