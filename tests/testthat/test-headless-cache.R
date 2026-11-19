# curate_headless(cache_dir = ) reuses the post-search state (#148).

cache_fixture <- function() {
  dir <- withr::local_tempdir(.local_envir = parent.frame())
  input_path <- file.path(dir, "inventory.csv")
  readr::write_csv(
    tibble::tibble(
      chemical_name = c("Acetone", "Chromium", "Lead"),
      cas_number = c("67-64-1", NA, "7439-92-1"),
      result = c("1", "2", "3"),
      unit = c("mg/L", "mg/L", "mg/L")
    ),
    input_path
  )
  list(dir = dir, input_path = input_path, cache_dir = file.path(dir, "cache"))
}

cache_pipeline_result <- function(cleaned_data, ...) {
  cleaned_data$dtxsid_chemical_name <- c("DTXSID8021482", "DTXSID1020322", "DTXSID6024161")
  cleaned_data$preferredName_chemical_name <- c("Acetone", "Chromium", "Lead")
  cleaned_data$source_tier_chemical_name <- "exact"
  cleaned_data$dtxsid_cas_number <- c("DTXSID8021482", "DTXSID9999999", NA)
  cleaned_data$preferredName_cas_number <- c("Acetone", "Chromium(VI)", NA)
  cleaned_data$source_tier_cas_number <- "cas"
  cleaned_data$consensus_status <- c("agree", "disagree", "single")
  cleaned_data$consensus_dtxsid <- c("DTXSID8021482", NA, "DTXSID6024161")
  cleaned_data$consensus_source <- c("chemical_name", NA, "chemical_name")
  cleaned_data$consensus_name <- NA_character_
  cleaned_data$qc_tier <- 1L
  list(
    results = init_resolution_state(cleaned_data),
    consensus_summary = list(n_agree = 1, n_disagree = 1, n_agree_caveat = 0, n_single = 1, n_error = 0)
  )
}

# Stands in for the CompTox detail fetch: one row per uncached DTXSID.
cache_enrich <- function(dtxsids, existing_cache = NULL, ...) {
  new <- setdiff(unique(dtxsids), existing_cache$dtxsid)
  fresh <- tibble::tibble(
    dtxsid = new,
    casrn = paste0("CAS-", new),
    molecular_formula = "X",
    molecular_weight = 1
  )
  list(cache = dplyr::bind_rows(existing_cache, fresh), failed_dtxsids = character(0))
}

cache_postprocess <- function(resolution_state, column_tags, dtxsid_cols = NULL, enrichment_cache = NULL) {
  ids <- collect_candidate_dtxsids(resolution_state, dtxsid_cols)
  empty_postprocess_result(resolution_state, cache_enrich(ids, enrichment_cache)$cache, character(0))
}

cache_validate <- function(dtxsids, ...) {
  tibble::tibble(searchValue = dtxsids, dtxsid = dtxsids, preferredName = "Picked", rank = 1L, is_valid = TRUE)
}

read_workbook <- function(path) {
  names <- readxl::excel_sheets(path)
  sheets <- stats::setNames(lapply(names, function(s) readxl::read_excel(path, sheet = s)), names)
  config <- sheets[["Pipeline Config"]]
  sheets[["Pipeline Config"]] <- config[config$key != "export_timestamp", ]
  sheets
}

test_that("a review-only rerun reuses the search and matches a from-scratch run", {
  fx <- cache_fixture()
  calls <- 0L
  local_mocked_bindings(
    run_curation_pipeline = function(cleaned_data, ...) {
      calls <<- calls + 1L
      cache_pipeline_result(cleaned_data)
    },
    postprocess_curation_candidates = cache_postprocess,
    enrich_candidates = cache_enrich,
    validate_manual_dtxsids = cache_validate
  )
  run <- function(out, ...) {
    curate_headless(
      input_path = fx$input_path,
      output_path = file.path(fx$dir, out),
      tag_map = list(chemical_name = "Name", cas_number = "CASRN", result = "Result", unit = "Unit"),
      header_row = 1L,
      ...
    )
  }
  # DTXSID1020807 is a pick that no search returned.
  picks <- tibble::tibble(name = "Chromium", casrn = NA, dtxsid = "DTXSID1020807")
  flags <- tibble::tibble(name = "Lead", flag = "FOLLOW-UP", reason = "check")

  expect_message(run("first.xlsx", cache_dir = fx$cache_dir, postprocess_candidates = TRUE), "searching afresh")
  expect_equal(calls, 1L)
  expect_message(
    rerun <- run("rerun.xlsx", cache_dir = fx$cache_dir, postprocess_candidates = TRUE, review_picks = picks,
      row_flags = flags),
    "Reusing cached curation search"
  )
  expect_equal(calls, 1L)

  scratch <- suppressMessages(run("scratch.xlsx", postprocess_candidates = TRUE, review_picks = picks, row_flags = flags))
  expect_equal(calls, 2L)
  expect_equal(rerun, scratch)
  rerun_book <- read_workbook(file.path(fx$dir, "rerun.xlsx"))
  expect_equal(rerun_book, read_workbook(file.path(fx$dir, "scratch.xlsx")))
  curated <- rerun_book[["Curated Data"]]
  expect_equal(curated$consensus_dtxsid[curated$chemical_name == "Chromium"], "DTXSID1020807")
  expect_equal(curated$consensus_casrn[curated$chemical_name == "Chromium"], "CAS-DTXSID1020807")

  # A cache filled with postprocessing must not leak into a run without it.
  plain <- suppressMessages(run("plain.xlsx", cache_dir = fx$cache_dir, postprocess_candidates = FALSE))
  expect_equal(calls, 2L)
  expect_true(all(is.na(read_workbook(file.path(fx$dir, "plain.xlsx"))[["Curated Data"]]$consensus_casrn)))
})

test_that("upstream changes and refresh_cache repeat the search", {
  fx <- cache_fixture()
  calls <- 0L
  local_mocked_bindings(run_curation_pipeline = function(cleaned_data, ...) {
    calls <<- calls + 1L
    cache_pipeline_result(cleaned_data)
  })
  tags <- list(chemical_name = "Name", cas_number = "CASRN", result = "Result", unit = "Unit")
  run <- function(tag_map = tags, ...) {
    curate_headless(fx$input_path, NULL, tag_map, header_row = 1L, write_files = FALSE, verbose = FALSE,
      cache_dir = fx$cache_dir, ...)
  }
  run()
  run()
  expect_equal(calls, 1L)

  run(wqx_threshold = 0.9)
  expect_equal(calls, 2L)
  run(tag_map = modifyList(tags, list(cas_number = "Other")))
  expect_equal(calls, 3L)
  run(refresh_cache = TRUE)
  expect_equal(calls, 4L)

  # A non-chemical cell is part of the cached rows, so it invalidates too.
  input <- readr::read_csv(fx$input_path, col_types = "cccc")
  input$result[1] <- "9"
  readr::write_csv(input, fx$input_path)
  out <- run()
  expect_equal(calls, 5L)
  expect_equal(out$data$result[1], "9")
})

test_that("a cached search with failed lookups is reused loudly and empty details are not kept", {
  fx <- cache_fixture()
  calls <- 0L
  local_mocked_bindings(
    run_curation_pipeline = function(cleaned_data, ...) {
      calls <<- calls + 1L
      result <- cache_pipeline_result(cleaned_data)
      result$search_failures <- tibble::tibble(lookup = "cas", n_queries = 2L, message = "API down")
      result
    },
    postprocess_curation_candidates = function(resolution_state, ...) {
      cache <- tibble::tibble(dtxsid = c("DTXSID8021482", "DTXSID6024161"), preferredName = c("Acetone", NA),
        casrn = c("67-64-1", NA), molecular_formula = NA_character_, molecular_weight = NA_real_)
      empty_postprocess_result(resolution_state, cache, character(0))
    }
  )
  run <- function(...) {
    curate_headless(fx$input_path, NULL,
      list(chemical_name = "Name", cas_number = "CASRN", result = "Result", unit = "Unit"),
      header_row = 1L, write_files = FALSE, verbose = FALSE, cache_dir = fx$cache_dir,
      postprocess_candidates = TRUE, ...)
  }
  expect_warning(run(), "^Degraded curation search: cas 2 queries failed\\. Rerun with refresh_cache = TRUE")
  expect_warning(run(), "^Reusing cached search with failed lookups\\. Degraded curation search: cas 2 queries")
  expect_equal(calls, 1L)
  expect_warning(run(refresh_cache = TRUE), "^Degraded")
  expect_equal(calls, 2L)

  saved <- readRDS(list.files(fx$cache_dir, "^enrichment\\.rds$", recursive = TRUE, full.names = TRUE))
  expect_equal(saved$dtxsid, "DTXSID8021482")
})

test_that("appended rows search only their new values and match a fresh run (#151)", {
  fx <- cache_fixture()
  known <- tibble::tibble(
    searchValue = c("Acetone", "67-64-1", "Lead", "7439-92-1", "Benzene", "71-43-2"),
    dtxsid = c("DTXSID8021482", "DTXSID8021482", "DTXSID2024161", "DTXSID2024161", "DTXSID3039242", "DTXSID3039242"),
    preferredName = c("Acetone", "Acetone", "Lead", "Lead", "Benzene", "Benzene"),
    searchName = "Approved Name",
    rank = 9L
  )
  queried <- character()
  local_mocked_bindings(
    ct_chemical_search_equal_bulk = function(query) {
      queried <<- c(queried, query)
      known[known$searchValue %in% query, ]
    },
    .package = "ComptoxR"
  )
  local_mocked_bindings(
    resolve_curation_reference_cache_dir = function() tempdir(),
    load_wqx_dictionary = function(...) NULL,
    match_wqx = function(query, ...) tibble::tibble(input_name = query, match_tier = "none", match_distance = NA_real_),
    add_resolver_candidates = function(df, ...) df
  )
  run <- function(cache_dir) {
    curate_headless(fx$input_path, NULL,
      list(chemical_name = "Name", cas_number = "CASRN", result = "Result", unit = "Unit"),
      header_row = 1L, write_files = FALSE, verbose = FALSE, cache_dir = cache_dir)
  }
  run(fx$cache_dir)
  expect_setequal(queried, c("Acetone", "Chromium", "Lead", "67-64-1", "7439-92-1"))

  readr::write_csv(tibble::tibble(chemical_name = "Benzene", cas_number = "71-43-2", result = "4", unit = "mg/L"),
    fx$input_path, append = TRUE)
  queried <- character()
  incremental <- run(fx$cache_dir)
  expect_setequal(queried, c("Benzene", "71-43-2"))

  fresh <- run(file.path(fx$dir, "fresh"))
  expect_equal(incremental, fresh)
  expect_equal(incremental$data$consensus_dtxsid[incremental$data$chemical_name == "Benzene"], "DTXSID3039242")
})

test_that("values from a dropped batch are retried once, then recorded as failures", {
  withr::defer({
    .lookup_cache$enabled <- FALSE
    .lookup_cache$lookups <- list()
  })
  .lookup_cache$enabled <- TRUE
  .lookup_cache$lookups <- list()
  .search_failures$rows <- list()
  asked <- list()
  failing <- 1:2
  fetch <- function(query) {
    asked[[length(asked) + 1L]] <<- query
    if (length(asked) %in% failing) {
      warning("API request to \"x\" failed for \"b\" with status 503")
    }
    tibble::tibble(searchValue = intersect(query, "a"), dtxsid = "DTXSID1")
  }
  # The first call and its retry both drop a batch: b and c stay unconfirmed.
  expect_message(
    first <- suppressWarnings(cached_lookup("t", c("a", "b", "c"), fetch, "exact_name")),
    "exact_name: 2 queries failed after one retry: API request to .* with status 503"
  )
  expect_equal(first$searchValue, "a")
  expect_equal(asked[[2]], c("b", "c"))
  failures <- collected_search_failures()
  expect_equal(failures$n_queries, 2L)
  expect_match(failures$message, "status 503")
  # The next run drops a batch once; the retry succeeds, so nothing is recorded.
  failing <- 3L
  .search_failures$rows <- list()
  suppressMessages(suppressWarnings(cached_lookup("t", c("a", "b", "c"), fetch)))
  expect_equal(asked[3:4], list(c("b", "c"), c("b", "c")))
  expect_equal(nrow(collected_search_failures()), 0L)
  # b and c are now confirmed misses and are not asked again.
  suppressMessages(cached_lookup("t", c("c", "b", "a"), fetch))
  expect_length(asked, 4L)
  # A retry that errors keeps the first response and records the failure.
  .lookup_cache$enabled <- FALSE
  calls <- 0L
  flaky <- function(query) {
    calls <<- calls + 1L
    if (calls == 2L) {
      stop("down")
    }
    warning("Request for q failed: HTTP 503")
    tibble::tibble(searchValue = "p", dtxsid = "DTXSID2")
  }
  kept <- suppressMessages(suppressWarnings(cached_lookup("u", c("p", "q"), flaky, "name_ties")))
  expect_equal(kept$searchValue, "p")
  expect_equal(collected_search_failures()$n_queries, 1L)
  expect_match(collected_search_failures()$message, "HTTP 503")
  .lookup_cache$enabled <- TRUE

  # ComptoxR returns a columnless tibble when every new value misses or every
  # chunk drops; cached hits survive, and a single-GET drop is not stored.
  none <- function(query) {
    asked[[length(asked) + 1L]] <<- query
    if ("y" %in% query) {
      warning("Request for y failed: HTTP 503")
    }
    tibble::tibble()
  }
  expect_equal(suppressMessages(cached_lookup("t", c("a", "z"), none))$searchValue, "a")
  suppressMessages(cached_lookup("t", c("a", "z"), none))
  expect_length(asked, 5L)
  expect_equal(suppressMessages(suppressWarnings(cached_lookup("t", c("a", "y"), none)))$searchValue, "a")
  suppressMessages(suppressWarnings(cached_lookup("t", c("a", "y"), none)))
  # Each run asks y and retries it once.
  expect_equal(asked[6:9], rep(list("y"), 4L))

  # Time budget: serving a fully cached 25k-value lookup stays cheap.
  values <- sprintf("name %05d", seq_len(25000))
  suppressMessages(cached_lookup("big", values, function(q) tibble::tibble(searchValue = q, rank = 1L)))
  elapsed <- system.time(out <- suppressMessages(cached_lookup("big", rev(values), stop)))[["elapsed"]]
  expect_equal(out$searchValue, rev(values))
  expect_lt(elapsed, 2)
})
