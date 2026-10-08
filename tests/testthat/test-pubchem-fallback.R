test_that("PubChem fallback keeps all candidates separate from consensus", {
  df <- tibble::tibble(
    original_row_id = c(1L, 2L, 3L, 4L),
    raw_name = c("Clean salt", "Clean salt", "Resolved", "No hit"),
    consensus_status = c("error", "error", "single", "error"),
    consensus_dtxsid = c(NA_character_, NA_character_, "DTXSID1", NA_character_)
  )
  original <- tibble::tibble(raw_name = c("Salt form", "Salt form", "Resolved", "No hit"))
  calls <- character()
  search <- function(name, type) {
    calls <<- c(calls, name)
    if (name == "Salt form") return(tibble::tibble(cid = c(10L, 11L)))
    tibble::tibble(cid = integer())
  }
  synonyms <- function(cid, tidy) {
    tibble::tibble(cid = c(10L, 10L, 11L),
                   synonym = c("DTXSID123", "DTXSID456", "unrelated"))
  }

  out <- add_pubchem_candidates(df, "raw_name", original, search, synonyms)

  expect_equal(calls, c("Salt form", "No hit"))
  expect_equal(out$pubchem_query[1:2], rep("Salt form", 2))
  expect_equal(out$pubchem_cid_candidates[1:2], rep("10; 11", 2))
  expect_equal(out$pubchem_dtxsid_candidates[1:2], rep("10:DTXSID123; 10:DTXSID456", 2))
  expect_equal(out$pubchem_lookup_status, c("hit", "hit", NA, "no_hit"))
  expect_identical(out$consensus_dtxsid, df$consensus_dtxsid)
})

test_that("PubChem candidates require complete valid CID and DTXSID pairs", {
  df <- tibble::tibble(
    raw_name = c("Example", "Example", "Resolved"),
    consensus_status = c("error", "unresolvable", "single"),
    consensus_dtxsid = c(NA_character_, NA_character_, "DTXSID1")
  )
  responses <- list(
    unrelated = tibble::tibble(cid = 1L, synonym = "Other synonym"),
    empty = tibble::tibble(cid = integer(), synonym = character()),
    missing_synonym = tibble::tibble(cid = 1L, synonym = NA_character_),
    missing_cid_column = tibble::tibble(synonym = "DTXSID123"),
    missing_synonym_column = tibble::tibble(cid = 1L),
    unaligned = list(cid = c(1L, 2L), synonym = "DTXSID123"),
    invalid_cids = tibble::tibble(
      cid = c(NA, "", "junk", "0", "-1", "1.5", "01", " 1", "1 "),
      synonym = "DTXSID123"
    ),
    invalid_synonyms = tibble::tibble(
      cid = 1L, synonym = c(NA, "", "DTXSID", "dtxsid123", "DTXSID123x", " DTXSID123")
    )
  )
  for (response in responses) {
    calls <- character()
    out <- add_pubchem_candidates(
      df, "raw_name",
      search_fn = function(name, type) {
        calls <<- c(calls, name)
        tibble::tibble(cid = 1L)
      },
      synonyms_fn = function(cid, tidy) response
    )
    expect_identical(calls, "Example")
    expect_identical(out$pubchem_query, c("Example", "Example", NA_character_))
    expect_identical(out$pubchem_cid_candidates, c("1", "1", NA_character_))
    expect_identical(out$pubchem_dtxsid_candidates, rep(NA_character_, 3))
    expect_identical(out$pubchem_lookup_status, c("hit", "hit", NA_character_))
    expect_identical(out$consensus_dtxsid, df$consensus_dtxsid)
    expect_identical(out$consensus_status, df$consensus_status)
  }

  valid <- add_pubchem_candidates(
    df, "raw_name", search_fn = function(...) tibble::tibble(cid = c(1L, 2L)),
    synonyms_fn = function(...) tibble::tibble(
      cid = c("1", NA, "2", "1", "junk", "1", "2"),
      synonym = c("DTXSID123", "DTXSID123", "DTXSID123", "DTXSID123",
                  "DTXSID456", "DTXSID456", "unrelated")
    )
  )
  expect_identical(valid$pubchem_dtxsid_candidates,
                   c(rep("1:DTXSID123; 2:DTXSID123; 1:DTXSID456", 2), NA_character_))
  expect_identical(valid$pubchem_cid_candidates, c("1; 2", "1; 2", NA_character_))
  expect_identical(valid$pubchem_lookup_status, c("hit", "hit", NA_character_))
  expect_identical(valid$consensus_dtxsid, df$consensus_dtxsid)
  expect_identical(valid$consensus_status, df$consensus_status)
})

test_that("PubChem failures retain lookup status and available CID evidence", {
  df <- tibble::tibble(raw_name = "Example", consensus_status = "error", consensus_dtxsid = NA_character_)
  search_error <- add_pubchem_candidates(df, "raw_name", search_fn = function(...) stop("offline"))
  expect_identical(search_error$pubchem_lookup_status, "error")
  expect_identical(search_error$pubchem_dtxsid_candidates, NA_character_)
  expect_identical(search_error$pubchem_cid_candidates, NA_character_)

  no_hit <- add_pubchem_candidates(df, "raw_name", search_fn = function(...) tibble::tibble(cid = integer()))
  expect_identical(no_hit$pubchem_lookup_status, "no_hit")
  expect_identical(no_hit$pubchem_dtxsid_candidates, NA_character_)
  expect_identical(no_hit$pubchem_cid_candidates, NA_character_)

  synonym_error <- add_pubchem_candidates(
    df, "raw_name", search_fn = function(...) tibble::tibble(cid = 1L),
    synonyms_fn = function(...) stop("offline")
  )
  expect_identical(synonym_error$pubchem_lookup_status, "synonyms_error")
  expect_identical(synonym_error$pubchem_dtxsid_candidates, NA_character_)
  expect_identical(synonym_error$pubchem_cid_candidates, "1")
})

test_that("salt parent suggestions follow exact lookup and preserve identity", {
  df <- tibble::tibble(
    raw_name = c("Halofuginone lactate", "Tiamulin hydrogen fumarate",
                 "Laidlomycin propionate potassium", "Acetyl fentanyl-13C6 hydrochloride",
                 "ZINC SULFATE MONOHYDRATE", "dexamethasone phenylpropionate",
                 "Sodium chloride", "Acepromazine maleate", "Bupivacaine chloride"),
    consensus_status = c(rep("error", 6), "single", "error", "error"),
    consensus_dtxsid = c(rep(NA_character_, 6), "DTXSID3021271", NA_character_, NA_character_)
  )
  calls <- character()
  lookup <- function(name) {
    calls <<- c(calls, name)
    if (name == "Halofuginone") {
      return(tibble::tibble(searchValue = c(name, name, "Other"),
                            dtxsid = c("DTXSID1", "DTXSID2", "DTXSID3")))
    }
    tibble::tibble(searchValue = character(), dtxsid = character())
  }

  out <- add_salt_parent_candidates(df, "raw_name", search_fn = lookup)

  expect_equal(out$parent_name_candidate[1:4],
               c("Halofuginone", "Tiamulin", "Laidlomycin propionate",
                 "Acetyl fentanyl-13C6"))
  expect_equal(out$parent_dtxsid_candidates[1], "DTXSID1; DTXSID2")
  expect_true(all(is.na(out$parent_name_candidate[5:7])))
  expect_equal(out$parent_name_candidate[8], "Acepromazine")
  expect_equal(out$parent_name_candidate[9], "Bupivacaine")
  expect_identical(out$consensus_dtxsid, df$consensus_dtxsid)
  expect_setequal(calls, out$parent_name_candidate[c(1:4, 8:9)])
})

test_that("structure parents flag salts, mixtures and stereo loss without touching consensus", {
  ids <- paste0("DTXSID", 1:6) # salt, single, mixture, inorganic, stereo salt, no structure
  df <- tibble::tibble(consensus_dtxsid = c(ids, NA, ids[1]))
  smiles <- stats::setNames(c("[Na+].[O-]C(=O)c1ccccc1", "CCO", "CCO.CC(C)=O", "[Na+].[Cl-]",
                              "C[C@H](N)O.Cl", NA), ids)
  lookups <- list()
  lookup <- function(x) {
    lookups[[length(lookups) + 1]] <<- x
    tibble::tibble(dtxsid = x, smiles = unname(smiles[x]), name = paste("name", x), casrn = paste("cas", x))
  }
  calls <- character()
  stdize <- function(smi, wf) {
    calls <<- c(calls, paste(wf, smi))
    switch(smi,
      "[Na+].[O-]C(=O)c1ccccc1" = list(list(sid = "DTXSID9PARENT", name = "Benzoic acid", casrn = "65-85-0", smiles = "OC(=O)c1ccccc1")),
      "CCO.CC(C)=O" = list(list(sid = "DTXSID9A", name = "Ethanol", casrn = "64-17-5", smiles = "CCO"),
                           list(sid = "DTXSID9B", name = "Acetone", smiles = "CC(C)=O")),
      "[Na+].[Cl-]" = list(),
      "C[C@H](N)O.Cl" = list(list(sid = "DTXSID9FLAT", name = "Flat", casrn = "NOCAS_1", smiles = "CC(N)O"))
    )
  }

  out <- add_structure_parents(df, NULL, lookup_fn = lookup, stdize_fn = stdize)

  expect_identical(out$data$consensus_dtxsid, df$consensus_dtxsid)
  expect_equal(out$data$parent_status_qsar_ready,
               c("parent", "self", "mixture", "no_parent", "stereo_lost", "no_structure", NA, "parent"))
  expect_equal(out$data$parent_dtxsid_qsar_ready,
               c("DTXSID9PARENT", ids[2], "DTXSID9A; DTXSID9B", NA, "DTXSID9FLAT", NA, NA, "DTXSID9PARENT"))
  expect_equal(out$data$parent_name_qsar_ready,
               c("Benzoic acid", "name DTXSID2", "Ethanol; Acetone", NA, "Flat", NA, NA, "Benzoic acid"))
  expect_equal(out$data$parent_casrn_qsar_ready,
               c("65-85-0", "cas DTXSID2", "64-17-5; ?", NA, "NOCAS_1", NA, NA, "65-85-0"))
  expect_identical(out$data$parent_status_ms_ready, out$data$parent_status_qsar_ready)
  # Single components skip the standardizer; each salt is standardized once per workflow.
  expect_length(calls, 8)

  again <- add_structure_parents(df, out$cache, lookup_fn = lookup, stdize_fn = stdize)
  expect_length(lookups, 1)
  expect_identical(again$data, out$data)

  qsar_only <- add_structure_parents(df, NULL, "qsar-ready", lookup_fn = lookup, stdize_fn = stdize)
  expect_false(any(grepl("ms_ready", names(qsar_only$data))))
})

test_that("structure parent lookup errors are reported and retried", {
  df <- tibble::tibble(consensus_dtxsid = "DTXSID1")
  failing <- add_structure_parents(df, NULL, "qsar-ready",
                                   lookup_fn = function(x) stop("offline"), stdize_fn = function(...) NULL)
  expect_equal(failing$data$parent_status_qsar_ready, "error")
  ok <- add_structure_parents(df, failing$cache, "qsar-ready",
                              lookup_fn = function(x) tibble::tibble(dtxsid = x, smiles = "CCO", name = "Ethanol", casrn = "64-17-5"),
                              stdize_fn = function(...) NULL)
  expect_equal(ok$data$parent_status_qsar_ready, "self")
  expect_equal(ok$data$parent_name_qsar_ready, "Ethanol")
  expect_equal(nrow(ok$cache), 1)
})

test_that("isotope-labelled records point to the unlabelled parent only where the workflow strips labels", {
  df <- tibble::tibble(consensus_dtxsid = "DTXSID801539501")
  lookup <- function(x) tibble::tibble(dtxsid = x, smiles = "[2H]C([2H])(Cl)C", name = "Label-d2", casrn = "NOCAS_1")
  stdize <- function(smi, wf) {
    if (wf == "qsar-ready") list(list(sid = "DTXSID4024270", name = "Parent", casrn = "1-1-1", smiles = "CCCl"))
    else list(list(sid = "DTXSID801539501", name = "Label-d2", casrn = "NOCAS_1", smiles = smi))
  }

  out <- add_structure_parents(df, NULL, lookup_fn = lookup, stdize_fn = stdize)$data

  expect_equal(out$parent_status_qsar_ready, "isotope_parent")
  expect_equal(out$parent_dtxsid_qsar_ready, "DTXSID4024270")
  expect_equal(out$parent_status_ms_ready, "self")
  expect_equal(out$consensus_dtxsid, "DTXSID801539501")
})

test_that("Markush structures are not sent to the standardizer", {
  rec <- list(smiles = "C*.CC1=CC=CC=C1 |m:1:4.5.6|", name = "Xylenes", casrn = "1330-20-7")
  out <- structure_parent("DTXSID2021446", rec, "qsar-ready", function(...) stop("called"))
  expect_equal(out$parent_status, "markush")
})

test_that("resolver fallback flags hits missing from the public CTX API", {
  df <- tibble::tibble(
    raw_name = c("Prochloraz-d4", "Atrazine", "Resolved", "Nothing", "Atrazine"),
    consensus_status = c("error", "error", "single", "error", "unresolvable"),
    consensus_dtxsid = c(NA, NA, "DTXSID1", NA, NA)
  )
  hit <- function(q, sid, name, result = "FOUND", by = "Name")
    list(result = result, query = q, resolvedBy = by, chemical = list(sid = sid, name = name))
  queried <- NULL
  lookup <- function(ids, tidy) {
    queried <<- ids
    list(hit("Prochloraz-d4", "DTXSID801539501", "Prochloraz-d4"),
         hit("Atrazine", "DTXSID9020112", "Atrazine"),
         list(result = "NOT_RESOLVED", query = "Nothing"))
  }
  public <- function(ids) intersect(ids, "DTXSID9020112")

  out <- add_resolver_candidates(df, "raw_name", lookup_fn = lookup, public_fn = public)

  expect_equal(queried, c("Prochloraz-d4", "Atrazine", "Nothing"))
  expect_equal(out$resolver_dtxsid_candidate,
               c("DTXSID801539501", "DTXSID9020112", NA, NA, "DTXSID9020112"))
  expect_equal(out$resolver_lookup_status,
               c("not_public", "public", NA, "no_hit", "public"))
  expect_identical(out$consensus_dtxsid, df$consensus_dtxsid)

  multi <- function(ids, tidy) list(
    hit("PFOA", "DTXSID8031865", "Perfluorooctanoic acid"),
    hit("PFOA", "DTXSID40892486", "Perfluorooctanoate", result = "DUPLICATE"),
    hit("BPA", "DTXSID7020182", "Bisphenol A", result = "DUPLICATE"),
    hit("PP", "DTXSID1", "Diphosphane", by = "InChIKey"))
  df2 <- tibble::tibble(raw_name = c("PFOA", "BPA", "PP"), consensus_status = "error",
                        consensus_dtxsid = NA_character_)
  out2 <- add_resolver_candidates(df2, "raw_name", lookup_fn = multi,
                                  public_fn = function(ids) setdiff(ids, "DTXSID40892486"))
  expect_equal(out2$resolver_dtxsid_candidate, c("DTXSID8031865; DTXSID40892486", "DTXSID7020182", NA))
  expect_equal(out2$resolver_lookup_status, c("some_public", "public", "no_hit"))

  down <- add_resolver_candidates(df, "raw_name", lookup_fn = lookup,
                                  public_fn = function(ids) stop("503"))
  expect_equal(down$resolver_lookup_status[1:2], c("unverified", "unverified"))
  err <- add_resolver_candidates(df, "raw_name", lookup_fn = function(...) stop("down"))
  expect_equal(err$resolver_lookup_status, c("error", "error", NA, "error", "error"))
})

test_that("DSSTox is only downloaded or refreshed when opted in", {
  installs <- 0L
  status <- "missing"
  local_mocked_bindings(
    dss_diag_freshness = function(...) list(status = status, latest_upstream_version = "2025-12-29"),
    dss_install = function(...) installs <<- installs + 1L,
    dss_disconnect = function(...) invisible(),
    .package = "ComptoxR"
  )
  reset <- function() rm(list = ls(.dsstox_checked), envir = .dsstox_checked)
  withr::defer(reset())

  withr::local_options(concert.dsstox_install = NULL)
  reset()
  expect_error(ensure_dsstox(), "concert.dsstox_install")
  status <- "stale"
  reset()
  ensure_dsstox()
  expect_equal(installs, 0L)

  withr::local_options(concert.dsstox_install = TRUE)
  reset()
  ensure_dsstox()
  status <- "missing"
  reset()
  ensure_dsstox()
  expect_equal(installs, 2L)
})

test_that("WQX continuation preserves source and canonical query attribution", {
  df <- tibble::tibble(original_row_id = c(20L, 10L, 30L, 40L),
    raw_name = c("Clean label", "Split part", "Resolved", "Clean label"),
    wqx_name_raw_name = c("Canonical", "Part canonical", "Resolved canonical", "Canonical"),
    consensus_status = c("wqx", "wqx", "single", "wqx"),
    consensus_dtxsid = c(NA_character_, " ", "DTXSID1", ""), multi_analyte_part_count = c(1L, 2L, 1L, 1L))
  original <- tibble::tibble(original_row_id = c(10L, 20L, 30L, 40L),
    raw_name = c("Whole parent", "Original label", "Resolved", "Original label"))
  info <- unresolved_name_queries(df, "raw_name", original)
  expect_identical(info$names, c("Original label", "Split part", "Original label", "Canonical", "Part canonical", "Canonical"))
  expect_identical(info$rows, c(1L, 2L, 4L, 1L, 2L, 4L))
  expect_identical(info$role, c(rep("original", 3L), rep("wqx_canonical", 3L)))
  queried <- character()
  out <- add_pubchem_candidates(df, "raw_name", original,
    search_fn = function(name, ...) {
      queried <<- c(queried, name)
      tibble::tibble(cid = if (name == "Original label") 10L else integer())
    }, synonyms_fn = function(...) tibble::tibble(cid = 10L, synonym = "DTXSID123"))
  expect_identical(queried, c("Original label", "Split part", "Canonical", "Part canonical"))
  expect_identical(out$pubchem_query[c(1L, 4L)], rep("Original label; Canonical", 2L))
  expect_identical(out$pubchem_dtxsid_candidates[c(1L, 4L)], rep("10:DTXSID123", 2L))
  expect_identical(out$pubchem_lookup_status, c("hit", "no_hit", NA_character_, "hit"))
  details <- jsonlite::fromJSON(out$pubchem_query_details[1L])
  expect_identical(details$query, c("Original label", "Canonical"))
  expect_identical(details$role, c("original", "wqx_canonical"))
  expect_identical(details$original_row_id, rep("20", 2L))
  expect_identical(details$source_column, rep("raw_name", 2L))
  expect_identical(out$consensus_status, df$consensus_status)
  expect_identical(out$consensus_dtxsid, df$consensus_dtxsid)
})

test_that("canonical and original PubChem hits aggregate without hiding failures", {
  df <- tibble::tibble(raw_name = "Original", wqx_name = "Canonical", consensus_status = "wqx", consensus_dtxsid = NA_character_)
  out <- add_pubchem_candidates(df, "raw_name", search_fn = function(name, ...) {
    tibble::tibble(cid = if (name == "Original") c(10L, 11L) else c(11L, 12L))
  }, synonyms_fn = function(ids, ...) tibble::tibble(cid = ids, synonym = paste0("DTXSID", ids)))
  expect_identical(out$pubchem_cid_candidates, "10; 11; 12")
  expect_identical(out$pubchem_dtxsid_candidates, "10:DTXSID10; 11:DTXSID11; 12:DTXSID12")
  failed <- add_pubchem_candidates(df, "raw_name", search_fn = function(name, ...) {
    if (name == "Canonical") stop("unavailable")
    tibble::tibble(cid = 10L)
  }, synonyms_fn = function(...) tibble::tibble(cid = 10L, synonym = "DTXSID10"))
  expect_identical(failed$pubchem_dtxsid_candidates, "10:DTXSID10")
  expect_identical(failed$pubchem_lookup_status, "hit; error")
  expect_identical(jsonlite::fromJSON(failed$pubchem_query_details)$status, c("hit", "error"))
})

test_that("resolver canonical continuation retains multiple candidates and per-query failures", {
  df <- tibble::tibble(raw_name = c("Original", "Original"), wqx_name_raw_name = "Canonical",
    consensus_status = "wqx", consensus_dtxsid = c(NA_character_, ""))
  queried <- NULL
  hit <- function(query, id) list(query = query, result = "FOUND", resolvedBy = "Name",
    chemical = list(sid = id, name = paste("Candidate", id)))
  out <- add_resolver_candidates(df, "raw_name", lookup_fn = function(query, ...) {
    queried <<- query
    list(hit("Original", "DTXSID10"), hit("Canonical", "DTXSID11"), hit("Canonical", "DTXSID10"))
  }, public_fn = function(ids) "DTXSID10")
  expect_identical(queried, c("Original", "Canonical"))
  expect_identical(out$resolver_query, rep("Original; Canonical", 2L))
  expect_identical(out$resolver_dtxsid_candidate, rep("DTXSID10; DTXSID11", 2L))
  expect_identical(out$resolver_lookup_status, rep("some_public", 2L))
  expect_identical(jsonlite::fromJSON(out$resolver_query_details[1L])$role, c("original", "wqx_canonical"))
  failed <- add_resolver_candidates(df, "raw_name", lookup_fn = function(...) {
    list(hit("Canonical", "DTXSID11"), list(query = "Original", result = "ERROR"))
  }, public_fn = function(ids) ids)
  expect_identical(failed$resolver_dtxsid_candidate, rep("DTXSID11", 2L))
  expect_identical(failed$resolver_lookup_status, rep("public; error", 2L))
  expect_identical(jsonlite::fromJSON(failed$resolver_query_details[1L])$status, c("error", "public"))
  expect_identical(failed$consensus_dtxsid, df$consensus_dtxsid)
  expect_identical(failed$consensus_status, df$consensus_status)
})

test_that("canonical lookup column collisions and salt-parent semantics retain provenance", {
  df <- tibble::tibble(raw_name = "Original hydrochloride", wqx_name_raw_name = "Unrelated raw metadata",
    wqx_name_lookup_raw_name = "Canonical lactate", consensus_status = "wqx", consensus_dtxsid = NA_character_)
  info <- unresolved_name_queries(df, "raw_name")
  expect_identical(info$names, c("Original hydrochloride", "Canonical lactate"))
  calls <- character()
  parent <- add_salt_parent_candidates(df, "raw_name", search_fn = function(name) {
    calls <<- c(calls, name)
    tibble::tibble(searchValue = name, dtxsid = "DTXSID123")
  })
  expect_identical(calls, "Original")
  expect_identical(parent$parent_name_candidate, "Original")
  expect_identical(parent$consensus_dtxsid, df$consensus_dtxsid)
  legacy <- df[c("raw_name", "consensus_status", "consensus_dtxsid")]
  legacy$preferredName_raw_name <- "Canonical"
  legacy$source_tier_raw_name <- "wqx_exact"
  expect_identical(unresolved_name_queries(legacy, "raw_name")$names, c("Original hydrochloride", "Canonical"))
})

test_that("empty collision-safe WQX evidence cannot expose raw metadata as a query", {
  df <- tibble::tibble(name = "Original", wqx_name_name = "Raw unrelated metadata",
    wqx_name_lookup_name = NA_character_, consensus_status = "wqx", consensus_dtxsid = NA_character_)
  expect_identical(unresolved_name_queries(df, "name")$names, "Original")
})
