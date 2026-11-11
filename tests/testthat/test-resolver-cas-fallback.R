test_that("resolver retries unresolved source CAS aliases and preserves row attribution", {
  df <- tibble::tibble(
    original_row_id = c(19L, 7L),
    name = c("(S)-Emtricitabine-3'-sulfoxide", "Hydroxydarunavir"),
    cas = c("1160303-44-5", "1809154-88-8"),
    consensus_status = "error",
    consensus_dtxsid = NA_character_
  )
  expected <- c("DTXSID90747694", "DTXSID20857750")
  queried <- NULL
  lookup <- function(ids, tidy) {
    queried <<- ids
    c(
      lapply(df$name, function(q) list(query = q, result = "NOT_RESOLVED")),
      lapply(seq_len(nrow(df)), function(i) {
        list(
          query = df$cas[i],
          result = "FOUND",
          resolvedBy = "CAS",
          chemical = list(sid = expected[i], name = df$name[i])
        )
      })
    )
  }
  out <- add_resolver_candidates(df, "name", cas_cols = "cas", lookup_fn = lookup, public_fn = identity)
  expect_setequal(queried, c(df$name, df$cas))
  expect_identical(out$resolver_dtxsid_candidate, expected)
  expect_identical(out$resolver_lookup_status, c("public", "public"))
  expect_identical(out$consensus_dtxsid, df$consensus_dtxsid)
  expect_identical(out$consensus_status, df$consensus_status)
  expect_identical(out$original_row_id, df$original_row_id)
  for (i in seq_len(nrow(df))) {
    details <- jsonlite::fromJSON(out$resolver_query_details[i])
    cas <- details[details$role == "source_cas", ]
    expect_identical(cas$query, df$cas[i])
    expect_identical(cas$source_column, "cas")
    expect_identical(cas$original_row_id, as.character(df$original_row_id[i]))
    expect_identical(unlist(cas$candidates, use.names = FALSE), expected[i])
  }
})

test_that("resolver CAS queries require whole valid identifiers on unresolved rows", {
  df <- tibble::tibble(
    name = NA_character_,
    cas = c(" 1160303-44-5 ", "1809154-88-8", "67-56-2", "NOCAS_1", "67-56-1; 64-17-5", "C(1160303-44-5)", NA),
    arbitrary_metadata = "64-17-5",
    consensus_status = c("error", "single", rep("error", 5)),
    consensus_dtxsid = c(NA, "DTXSID1", rep(NA_character_, 5))
  )
  queried <- NULL
  out <- add_resolver_candidates(
    df,
    character(),
    cas_cols = "cas",
    lookup_fn = function(ids, tidy) {
      queried <<- ids
      list(list(
        query = "1160303-44-5",
        result = "FOUND",
        resolvedBy = "CAS",
        chemical = list(sid = "DTXSID90747694", name = "Sulfoxide")
      ))
    },
    public_fn = identity
  )
  expect_identical(queried, "1160303-44-5")
  expect_identical(out$resolver_dtxsid_candidate, c("DTXSID90747694", rep(NA_character_, 6)))
  expect_identical(out$consensus_dtxsid, df$consensus_dtxsid)
})

test_that("resolver retains conflicting name and CAS candidates without choosing one", {
  df <- tibble::tibble(
    name = "Source name",
    cas = "67-56-1",
    consensus_status = "error",
    consensus_dtxsid = NA_character_
  )
  out <- add_resolver_candidates(
    df,
    "name",
    cas_cols = "cas",
    lookup_fn = function(ids, tidy) {
      list(
        list(
          query = "Source name",
          result = "FOUND",
          resolvedBy = "Name",
          chemical = list(sid = "DTXSID1", name = "A")
        ),
        list(query = "67-56-1", result = "DUPLICATE", resolvedBy = "CAS", chemical = list(sid = "DTXSID2", name = "B"))
      )
    },
    public_fn = identity
  )
  expect_identical(out$resolver_dtxsid_candidate, "DTXSID1; DTXSID2")
  expect_true(is.na(out$consensus_dtxsid))
  expect_identical(out$consensus_status, "error")
})

test_that("the curation pipeline passes CASRN-tagged columns to the resolver", {
  actual_resolver <- add_resolver_candidates
  queried <- NULL
  local_mocked_bindings(
    search_exact = function(query) {
      tibble::tibble(
        searchValue = character(),
        dtxsid = character(),
        preferredName = character(),
        searchName = character(),
        rank = integer()
      )
    },
    validate_and_lookup_cas = function(query, ...) {
      tibble::tibble(
        original_cas = query,
        validated_cas = query,
        is_valid = FALSE,
        dtxsid = NA_character_,
        preferredName = NA_character_,
        rank = NA_integer_
      )
    },
    resolve_curation_reference_cache_dir = function() tempdir(),
    load_wqx_dictionary = function(...) NULL,
    match_wqx = function(query, ...) tibble::tibble(input_name = query, match_tier = "none", match_distance = NA_real_),
    add_resolver_candidates = function(df, name_cols, original_data = NULL, cas_cols = character()) {
      expect_identical(cas_cols, "cas")
      actual_resolver(
        df,
        name_cols,
        original_data,
        cas_cols = cas_cols,
        lookup_fn = function(ids, tidy) {
          queried <<- ids
          list(list(
            query = "1809154-88-8",
            result = "FOUND",
            resolvedBy = "CAS",
            chemical = list(sid = "DTXSID20857750", name = "Hydroxy Darunavir")
          ))
        },
        public_fn = identity
      )
    }
  )
  raw <- tibble::tibble(original_row_id = 31L, name = "Hydroxydarunavir", cas = "1809154-88-8")
  out <- run_curation_pipeline(raw, list(name = "Name", cas = "CASRN"))$results
  expect_setequal(queried, c(raw$name, raw$cas))
  expect_identical(out$resolver_dtxsid_candidate, "DTXSID20857750")
  expect_true(is.na(out$consensus_dtxsid))
})

test_that("resolver handles an empty CAS search pool without making requests", {
  for (status in c("single", "error")) {
    df <- tibble::tibble(
      cas = if (status == "single") "67-56-1" else NA_character_,
      consensus_status = status,
      consensus_dtxsid = if (status == "single") "DTXSID1" else NA_character_
    )
    called <- FALSE
    out <- add_resolver_candidates(df, character(), cas_cols = "cas", lookup_fn = function(...) {
      called <<- TRUE
      stop("must not query")
    })
    expect_false(called)
    expect_true(is.na(out$resolver_query))
    expect_identical(out$consensus_dtxsid, df$consensus_dtxsid)
  }
})

test_that("repeated CAS queries are deduplicated without losing row or column evidence", {
  df <- tibble::tibble(
    original_row_id = c(9L, 3L, 6L),
    cas = "67-56-1",
    alternate_cas = "67-56-1",
    consensus_status = c("error", "unresolvable", "wqx"),
    consensus_dtxsid = c(NA, "", " ")
  )
  queried <- NULL
  out <- add_resolver_candidates(
    df,
    character(),
    cas_cols = c("cas", "alternate_cas"),
    lookup_fn = function(ids, tidy) {
      queried <<- ids
      list(list(
        query = "67-56-1",
        result = "FOUND",
        resolvedBy = "CAS",
        chemical = list(sid = "DTXSID1020323", name = "Methanol")
      ))
    },
    public_fn = identity
  )
  expect_identical(queried, "67-56-1")
  expect_identical(out$resolver_dtxsid_candidate, rep("DTXSID1020323", 3L))
  for (i in seq_len(nrow(df))) {
    details <- jsonlite::fromJSON(out$resolver_query_details[i])
    expect_identical(details$source_column, c("cas", "alternate_cas"))
    expect_identical(details$original_row_id, rep(as.character(df$original_row_id[i]), 2L))
    expect_identical(details$role, rep("source_cas", 2L))
  }
})

test_that("name-only search caches are bypassed and refreshed results are reused", {
  cache_dir <- withr::local_tempdir()
  cleaned <- tibble::tibble(name = "Hydroxydarunavir", cas = "1809154-88-8")
  state <- list(
    cleaning_result = list(cleaned_data = cleaned),
    merged_chemical_tags = list(name = "Name", cas = "CASRN"),
    clean_data = cleaned
  )
  old_key <- digest::digest(list(
    cleaned,
    state$merged_chemical_tags,
    state$ignored_identifier_cols,
    "source-id-v1",
    "synonym-list-v1",
    identity_policy_version(),
    as.character(utils::packageVersion("ComptoxR")),
    NULL,
    0.85,
    FALSE,
    FALSE,
    FALSE
  ))
  saveRDS(list(results = "stale name-only results"), file.path(cache_dir, paste0("curation_", old_key, ".rds")))
  calls <- 0L
  fresh <- tibble::tibble(resolver_dtxsid_candidate = "DTXSID20857750")
  local_mocked_bindings(run_curation_pipeline = function(...) {
    calls <<- calls + 1L
    list(results = fresh)
  })
  first <- stage_curate(state, cache_dir = cache_dir)
  second <- stage_curate(state, cache_dir = cache_dir)
  expect_identical(first$resolution_state, fresh)
  expect_identical(second$resolution_state, fresh)
  expect_identical(calls, 1L)
  expect_length(list.files(cache_dir, pattern = "^curation_"), 2L)
})
