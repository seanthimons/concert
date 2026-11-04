# Synonym-list input (#139): ";"-separated extra names are lookup evidence for
# their own row and never create rows.

syn_lookup <- function(...) {
  tibble::tibble(
    searchValue = names(c(...)),
    dtxsid = unname(c(...)),
    preferredName = NA_character_,
    searchName = NA_character_,
    rank = 1L,
    source_tier = "exact"
  )
}

test_that("split_synonym_list splits on ; outside enclosures, regardless of length", {
  parts <- split_synonym_list(c(
    "EDB; Ethylene bromide; Ethylene dibromide",
    "Benzene, 1,2-dichloro-; o-DCB",
    "Cyclo(a; b); other",
    "unbalanced (a; b",
    "same; same; ",
    NA,
    ""
  ))
  expect_equal(parts[[1]], c("EDB", "Ethylene bromide", "Ethylene dibromide"))
  expect_equal(parts[[2]], c("Benzene, 1,2-dichloro-", "o-DCB"))
  expect_equal(parts[[3]], c("Cyclo(a; b)", "other"))
  expect_equal(parts[[4]], "unbalanced (a; b")
  expect_equal(parts[[5]], "same")
  expect_equal(lengths(parts[6:7]), c(0L, 0L))
})

test_that("split_synonyms still gates CAS-less plausibility after the shared-splitter refactor", {
  df <- data.frame(n = c("xylene; dimethylbenzene; xylol", "branched; chain"), original_row_id = 1:2)
  out <- split_synonyms(df, "n", list(n = "Name"))$cleaned_data
  expect_equal(sum(out$original_row_id == 1L), 3L)
  expect_equal(sum(out$original_row_id == 2L), 1L)
})

test_that("format_synonyms joins lists and protects the delimiter", {
  expect_equal(format_synonyms(c("EDB", "Ethylene dibromide")), "EDB; Ethylene dibromide")
  expect_equal(
    format_synonyms(list(c("o-DCB", " ortho-Dichlorobenzene ", "o-DCB"), NA, character(0))),
    c("o-DCB; ortho-Dichlorobenzene", NA, NA)
  )
  expect_warning(out <- format_synonyms(list(c("a; b", "c"))), "comma")
  expect_equal(out, "a, b; c")
  expect_equal(format_synonyms(list("Cyclo(a; b)")), "Cyclo(a; b)")
  expect_warning(format_synonyms(list(c("foo (bar", "baz"))), "unbalanced")
})

test_that("Synonym is a chemical tag", {
  expect_equal(names(classify_tags(list(a = "Synonym", b = "Result"))$chemical_tags), "a")
})

test_that("cleaning leaves Synonym cells alone, including embedded CAS, and adds no CASRN column", {
  df <- data.frame(
    raw_name = "1,2-Dibromoethane",
    raw_casrn = "106-93-4",
    raw_synonyms = "EDB; 71-43-2; Ethylene bromide",
    stringsAsFactors = FALSE
  )
  out <- run_cleaning_pipeline(df, tag_map = list(raw_name = "Name", raw_casrn = "CASRN", raw_synonyms = "Synonym"))
  expect_equal(nrow(out$cleaned_data), 1L)
  expect_equal(out$cleaned_data$raw_synonyms, "EDB; 71-43-2; Ethylene bromide")
  expect_false(any(grepl("^cas_extract_raw_synonyms", names(out$cleaned_data))))
  expect_length(out$new_tags[grepl("raw_synonyms", names(out$new_tags))], 0L)
})

test_that("dedup searches each synonym part and keeps one row per part in the key map", {
  df <- data.frame(
    nm = c("A", "B", "C"),
    syn = c("EDB; Ethylene bromide", NA, "EDB"),
    stringsAsFactors = FALSE
  )
  res <- deduplicate_tagged_columns(df, list(nm = "Name", syn = "Synonym"))
  expect_setequal(res$unique_names, c("A", "B", "C", "EDB", "Ethylene bromide"))
  syn_keys <- res$dedup_key_map[res$dedup_key_map$column_name == "syn", ]
  expect_equal(syn_keys$row_idx, c(1L, 1L, 2L, 3L))
  expect_equal(syn_keys$dedup_key, c("EDB", "Ethylene bromide", NA, "EDB"))

  skipped <- deduplicate_tagged_columns(df, list(nm = "Name", syn = "Synonym"), skip_rows = 1L)
  expect_setequal(skipped$unique_names, c("B", "C", "EDB"))
})

test_that("map_results_to_rows aggregates synonym parts without adding rows", {
  df <- data.frame(
    nm = c("a", "b", "c", "d", "e"),
    syn = c("p1; p2", "p1; p3", "p4; p5", "p6; p7", "p8"),
    stringsAsFactors = FALSE
  )
  keys <- deduplicate_tagged_columns(df, list(nm = "Name", syn = "Synonym"))$dedup_key_map
  lookup <- dplyr::bind_rows(
    syn_lookup(p1 = "DTXSID1", p2 = "DTXSID1", p3 = "DTXSID1", p4 = "DTXSID4", p5 = "DTXSID5"),
    tibble::tibble(
      searchValue = "p6",
      dtxsid = NA_character_,
      preferredName = NA_character_,
      searchName = NA_character_,
      rank = NA_integer_,
      source_tier = "exact_tied",
      tied_dtxsids = "DTXSID4; DTXSID6"
    ),
    tibble::tibble(
      searchValue = "p7",
      dtxsid = "DTXSID4",
      preferredName = NA_character_,
      searchName = NA_character_,
      rank = 2L,
      source_tier = "exact"
    ),
    tibble::tibble(
      searchValue = "p8",
      dtxsid = NA_character_,
      preferredName = "Fuzzy name",
      searchName = NA_character_,
      rank = NA_integer_,
      source_tier = "wqx_fuzzy"
    )
  )
  mapped <- suppressMessages(map_results_to_rows(df, keys, lookup))

  expect_equal(nrow(mapped), 5L)
  expect_equal(mapped$dtxsid_syn[1:2], c("DTXSID1", "DTXSID1"))
  # Parts that resolve to different DTXSIDs become a tie for consensus to settle.
  expect_true(is.na(mapped$dtxsid_syn[3]))
  expect_equal(mapped$tied_dtxsids_syn[3], "DTXSID4; DTXSID5")
  # A definite part wins over a tie that includes it.
  expect_equal(mapped$dtxsid_syn[4], "DTXSID4")
  # A fuzzy WQX hit is not synonym evidence.
  expect_true(is.na(mapped$preferredName_syn[5]))
  expect_false(is_wqx_tier(mapped$source_tier_syn[5]))
})

test_that("a tied synonym agrees with a Name hit it contains and conflicts otherwise", {
  df <- data.frame(nm = c("a", "b"), syn = c("p4; p5", "p4; p5"), stringsAsFactors = FALSE)
  keys <- deduplicate_tagged_columns(df, list(nm = "Name", syn = "Synonym"))$dedup_key_map
  lookup <- dplyr::bind_rows(
    syn_lookup(p4 = "DTXSID4", p5 = "DTXSID5", a = "DTXSID5", b = "DTXSID9")
  )
  mapped <- suppressMessages(map_results_to_rows(df, keys, lookup))
  cls <- classify_consensus(mapped, find_dtxsid_cols(mapped))
  expect_equal(cls$consensus_status[2], "disagree")
  expect_false(cls$consensus_status[1] %in% c("disagree", "error"))
  expect_equal(cls$consensus_dtxsid[1], "DTXSID5")
})

test_that("a synonym lookup for a CAS row is evidence for that row (#139 item 2)", {
  df <- data.frame(
    nm = "1,2-Dibromoethane",
    cas = "106-93-4",
    syn = "EDB; Ethylene bromide",
    stringsAsFactors = FALSE
  )
  tags <- list(nm = "Name", cas = "CASRN", syn = "Synonym")
  keys <- deduplicate_tagged_columns(df, tags)$dedup_key_map
  lookup <- syn_lookup(`1,2-Dibromoethane` = "DTXSID1", `EDB` = "DTXSID1")
  mapped <- suppressMessages(map_results_to_rows(df, keys, lookup))
  expect_equal(nrow(mapped), 1L)
  expect_equal(mapped$dtxsid_syn, "DTXSID1")
})

test_that("synonym_delimiter_diagnostics flags comma-delimited lists, not locants or semicolon lists", {
  df <- data.frame(
    syn = c("EDB, Ethylene bromide", "o-DCB, ortho-Dichlorobenzene", "Antimony"),
    fine = c("a; b", "c", "d"),
    locants = c("1,2-Dichlorobenzene", "3,4,5-Trichlorocatechol", "1,1-Dichloroethane"),
    raw_synonyms = c("EDB, Ethylene bromide", "x, y", "z"),
    stringsAsFactors = FALSE
  )
  diag <- synonym_delimiter_diagnostics(
    df,
    list(syn = "Synonym", fine = "Synonym", locants = "Synonym", raw_synonyms = "Other")
  )
  expect_setequal(diag$column, c("syn", "raw_synonyms"))
  expect_match(diag$message[diag$column == "syn"], "separated by ';'")
  expect_match(diag$message[diag$column == "raw_synonyms"], "Tag this column Synonym")
  expect_warning(warn_synonym_delimiter(diag), "comma-delimited")
  expect_equal(nrow(synonym_delimiter_diagnostics(df["fine"], list(fine = "Synonym"))), 0L)
})

test_that("pick_synonym_hit ignores loose evidence and conflicting vocabulary hits", {
  hit <- function(tier, dtxsid = NA_character_, pref = NA_character_, rank = 1L) {
    tibble::tibble(dtxsid = dtxsid, preferredName = pref, rank = rank, source_tier = tier)
  }
  expect_true(is.na(pick_synonym_hit(hit("wqx_fuzzy", pref = "X"))$pos))
  vocab <- dplyr::bind_rows(hit("wqx_exact", pref = "Benzene"), hit("wqx_alias", pref = "Toluene"))
  expect_true(is.na(pick_synonym_hit(vocab)$pos))
  expect_equal(
    pick_synonym_hit(dplyr::bind_rows(hit("wqx_exact", pref = "Benzene"), hit("wqx_alias", pref = "benzene")))$pos,
    1L
  )
  # Starts-with only counts when nothing firmer hit, and only when unambiguous.
  expect_equal(pick_synonym_hit(hit("starts_with", "D1"))$pos, 1L)
  expect_true(is.na(pick_synonym_hit(dplyr::bind_rows(hit("starts_with", "D1"), hit("starts_with", "D2")))$pos))
  expect_equal(pick_synonym_hit(dplyr::bind_rows(hit("starts_with", "D2"), hit("exact", "D1")))$pos, 2L)
  expect_equal(pick_synonym_hit(hit("miss"))$tier, "miss")
  expect_true(is.na(pick_synonym_hit(hit("exact")[0, ])$tier))
})

test_that("is_synonym_bundle flags names that still hold several parts", {
  expect_equal(
    is_synonym_bundle(c("EDB; Ethylene bromide", "Benzene, 1,2-dichloro-", "Cyclo(a; b)", "(a; b", NA)),
    c(TRUE, FALSE, FALSE, FALSE, FALSE)
  )
})

test_that("synonym aggregation handles many rows and an empty frame", {
  n <- 2000L
  df <- data.frame(
    nm = paste0("n", seq_len(n)),
    syn = rep(c("s1; s2", "s2; s3"), length.out = n),
    stringsAsFactors = FALSE
  )
  keys <- deduplicate_tagged_columns(df, list(syn = "Synonym"))$dedup_key_map
  lookup <- syn_lookup(s1 = "D1", s2 = "D1", s3 = "D2")
  mapped <- suppressMessages(map_results_to_rows(df, keys, lookup))
  # Odd rows: s1, s2 agree. Even rows: s2 -> D1 and s3 -> D2 tie.
  expect_equal(mapped$dtxsid[seq(1, n, 2)], rep("D1", n / 2))
  expect_true(all(is.na(mapped$dtxsid[seq(2, n, 2)])))
  expect_equal(unique(mapped$tied_dtxsids[seq(2, n, 2)]), "D1; D2")

  empty <- deduplicate_tagged_columns(df[0, ], list(syn = "Synonym"))
  expect_equal(nrow(empty$dedup_key_map), 0L)
  expect_true("dedup_key" %in% names(empty$dedup_key_map))
})
