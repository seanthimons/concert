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

test_that("review snapshots keep only each row's extracted CAS lookup fields", {
  base <- data.frame(
    label = "base",
    lookup_evidence_columns = "dtxsid_name",
    dtxsid_name = NA_character_,
    preferredName_name = NA_character_,
    dtxsid_metadata = "DTXSID42"
  )
  df <- base[rep(1L, 3L), ]
  df$label <- c("base", "one", "two")
  for (i in 2:3) {
    suffix <- paste0("_cas_extract_", df$label[i])
    id <- paste0("dtxsid", suffix)
    df[[id]] <- NA_character_
    df[[paste0("source_tier", suffix)]] <- NA_character_
    df[[paste0("wqx_cas", suffix)]] <- NA_character_
    df$lookup_evidence_columns[i] <- paste("dtxsid_name", id, sep = ";")
  }
  snapshot <- function(x, rows) review_evidence_snapshot(x, row_indices = rows, scope_cols = "label")
  expect_identical(snapshot(df, 1L), snapshot(base, 1L))
  expect_identical(snapshot(df[1L, ], 1L), snapshot(base, 1L))
  grouped <- snapshot(df, 1:3)$lookup
  for (row in grouped) {
    i <- match(row$label, df$label)
    expect_identical(row, snapshot(df, i)$lookup[[1]])
    expect_equal(
      grep("cas_extract", names(row), value = TRUE),
      if (i == 1L) character() else sort(paste0(c("dtxsid", "source_tier", "wqx_cas"), "_cas_extract_", row$label))
    )
    expect_identical(row$dtxsid_metadata, "DTXSID42")
  }
  expect_identical(grouped, snapshot(df, 3:1)$lookup)
  legacy <- df
  legacy$lookup_evidence_columns <- paste(find_dtxsid_cols(df), collapse = ";")
  unregistered <- legacy
  unregistered$lookup_evidence_columns <- NULL
  expect_identical(snapshot(legacy, 1:3), snapshot(unregistered, 1:3))
  df$dtxsid_cas_extract_one[1] <- "DTXSID99"
  expect_identical(snapshot(df, 1L)$lookup[[1]]$dtxsid_cas_extract_one, "DTXSID99")
  scoped <- review_evidence_snapshot(df, row_indices = 1L, scope_cols = "source_tier_cas_extract_two")
  expect_true("source_tier_cas_extract_two" %in% names(scoped$lookup[[1]]))
})
