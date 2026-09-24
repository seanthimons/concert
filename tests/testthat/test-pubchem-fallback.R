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
