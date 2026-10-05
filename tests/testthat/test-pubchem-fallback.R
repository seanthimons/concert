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
