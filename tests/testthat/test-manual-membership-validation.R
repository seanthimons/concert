test_that("manual membership never selects a tied or mismatched authoritative response", {
  ids <- c("DTXSID1", "DTXSID2", "DTXSID3", "DTXSID4", "bogus")
  out <- validate_manual_dtxsids(ids, lookup_fn = function(ids) {
    tibble::tibble(searchValue = c("DTXSID1", "DTXSID2", "DTXSID2", "DTXSID3"),
      dtxsid = c("DTXSID1", "DTXSID2", "DTXSID9", "DTXSID9"), rank = c(1L, 1L, 2L, 1L))
  })
  expect_identical(out$is_valid, c(TRUE, FALSE, FALSE, FALSE, FALSE))
  expect_identical(out$validation_status,
    c("validated", "ambiguous", "returned_id_mismatch", "not_found", "invalid_format"))
  expect_true(all(is.na(out$dtxsid[-1])))
})

test_that("transport failure and unknown schema differ from definitive no result", {
  failed <- validate_manual_dtxsids("DTXSID1", lookup_fn = function(...) stop("fixture timeout"))
  absent <- validate_manual_dtxsids("DTXSID1", lookup_fn = function(...) tibble::tibble())
  unknown <- validate_manual_dtxsids("DTXSID1", lookup_fn = function(...) data.frame(value = "DTXSID1"))
  expect_equal(failed$validation_status, "unavailable")
  expect_equal(absent$validation_status, "not_found")
  expect_equal(unknown$validation_status, "unavailable")
  expect_false(any(c(failed$is_valid, absent$is_valid, unknown$is_valid)))
})

test_that("explicit validation batches deduplicate requests without hidden services", {
  requests <- list()
  out <- validate_manual_dtxsids(c("DTXSID1", "DTXSID1", "DTXSID2", NA), batch_size = 1L, delay_sec = 0,
    lookup_fn = function(ids) {
      requests[[length(requests) + 1L]] <<- ids
      tibble::tibble(searchValue = ids, dtxsid = ids, preferredName = "fixture")
    })
  expect_equal(length(requests), 2)
  expect_true(all(out$is_valid))
  expect_equal(nrow(validate_manual_dtxsids(character())), 0)
})
