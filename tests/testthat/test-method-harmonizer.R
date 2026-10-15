test_that("harmonize_methodology splits labels into ordered components", {
  out <- harmonize_methodology(c("GC-ECD", " gc_ecd ", "not a method", NA))

  expect_equal(out$orig_row_id, c(1L, 1L, 2L, 2L, 3L, 4L))
  expect_equal(out$term_id[1:4], rep(c("CHMO:0001002", "CHMO:0001717"), 2))
  expect_equal(out$analytical_role[1:2], c("separation", "detection"))
  expect_equal(out$status, c(rep("matched", 4), "queued", "queued"))
  expect_equal(out$confidence_tier[5:6], c("unresolved", "unresolved"))
  expect_equal(unique(out$artifact_version), media_artifact_version())
})

test_that("reviewed AMOS decisions outrank ontology synonyms", {
  # "ecd" has CHMO synonyms for two terms; the AMOS row picks one.
  out <- harmonize_methodology("ECD")
  expect_equal(out$term_id, "CHMO:0001717")
})

test_that("harmonize_methodology handles empty input and bad lengths", {
  out <- harmonize_methodology(character())
  expect_equal(nrow(out), 0L)
  expect_length(out, 11L)
  expect_error(harmonize_methodology("GC", 1:2), "equal lengths")
})

test_that("runtime returns method_results for AnalyticalMethod tags", {
  rt <- run_harmonization_runtime(
    tibble::tibble(m = c("GC-FID", "nope")),
    c(m = "AnalyticalMethod"),
    unit_map = NULL
  )
  expect_equal(unique(rt$method_results$orig_row_id), 1:2)
  expect_equal(rt$data$m, c("GC-FID", "nope"))
})

test_that("harmonize_methodology stays within its time budget", {
  syn <- get_method_tables()$synonyms$label
  x <- sample(c(syn, paste("unknown", 1:1000)), 1e5, replace = TRUE)
  elapsed <- system.time(harmonize_methodology(x))[["elapsed"]]
  expect_lt(elapsed, 5)
})
