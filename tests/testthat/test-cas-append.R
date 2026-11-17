test_that("appending extracted CAS evidence preserves previously reviewed rows", {
  lookup <- tibble::tibble(
    searchValue = c("acetone", "67-64-1"),
    dtxsid = "DTXSID8021482",
    preferredName = "Acetone",
    searchName = searchValue,
    rank = 1L,
    source_tier = c("exact", "cas")
  )
  classify <- function(df, tags) {
    normalized <- normalize_cas_fields(df, tags)
    rescued <- rescue_cas_from_text(normalized$cleaned_data, c(tags, normalized$new_tags))
    cleaned <- rescued$cleaned_data
    keys <- deduplicate_tagged_columns(cleaned, c(tags, normalized$new_tags, rescued$new_tags))
    isotope <- tibble::tibble(
      row_idx = 1L,
      dtxsid = "DTXSID8021482",
      preferredName = "Acetone",
      source_tier = "isotope_match"
    )
    mapped <- map_results_to_rows(cleaned, keys$dedup_key_map, lookup, pre_resolved = isotope)
    classify_consensus(mapped, find_dtxsid_cols(mapped))
  }

  df <- tibble::tibble(
    cas = c("lot 9: 67-64-1", "67-64-1", "67-64-1/64-17-5"),
    name = c("old  name", "acetone", "acetone (67-64-1)")
  )
  for (tags in list(list(cas = "CASRN"), list(cas = "CASRN", name = "Name"))) {
    before <- classify(df[1:2, names(tags)], tags)
    after <- classify(df[, names(tags)], tags)
    for (row in 1:2) {
      expect_identical(identity_evidence_fingerprint(after, row), identity_evidence_fingerprint(before, row))
    }
    fields <- c("consensus_status", "qc_tier", "lookup_evidence_columns")
    expect_identical(after[1:2, fields], before[, fields])
    expect_identical(after$qc_tier[3], 2L)
  }
})
