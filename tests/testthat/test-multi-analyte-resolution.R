multi_analyte_fixture <- function(values) {
  flagged <- !is.na(values) & (
    grepl("(?<!\\()\\s\\+\\s(?!\\))", values, perl = TRUE) |
      grepl("(?i)\\s+and\\s+", values, perl = TRUE)
  )

  tibble::tibble(
    original_row_id = seq_along(values),
    analyte = values,
    cleaning_flag = ifelse(flagged, "WARNING: potential multi-analyte", NA_character_)
  )
}

test_that("suggest_multi_analyte_parts splits explicit separators and carries isotope element", {
  expect_equal(suggest_multi_analyte_parts("nitrate + nitrite"), c("nitrate", "nitrite"))
  expect_equal(suggest_multi_analyte_parts("Thorium-230 and 232"), c("Thorium-230", "Thorium-232"))
  expect_equal(suggest_multi_analyte_parts("(+)-catechin"), "(+)-catechin")
  expect_equal(suggest_multi_analyte_parts(NA_character_), character(0))
  expect_equal(suggest_multi_analyte_parts(""), character(0))
})

test_that("resolve_multi_analyte_row split creates rows with lineage and audit trail", {
  df <- multi_analyte_fixture(c("lead and arsenic", "acetone"))

  result <- resolve_multi_analyte_row(df, "analyte", row_index = 1L, action = "split")
  cleaned <- result$cleaned_data

  expect_equal(nrow(cleaned), 3)
  expect_equal(cleaned$analyte[1:2], c("lead", "arsenic"))
  expect_equal(cleaned$original_row_id[1:2], c(1L, 1L))
  expect_equal(cleaned$multi_analyte_resolution[1:2], c("split", "split"))
  expect_equal(cleaned$multi_analyte_part_index[1:2], c(1L, 2L))
  expect_equal(cleaned$multi_analyte_part_count[1:2], c(2L, 2L))
  expect_false(any(is_multi_analyte_review_row(cleaned)))

  expect_equal(result$audit_trail$step, rep("multi_analyte_resolution", 2))
  expect_equal(result$audit_trail$new_value, c("lead", "arsenic"))
})

test_that("resolve_multi_analyte_row keep combined clears repeat review warning", {
  df <- multi_analyte_fixture("nitrate + nitrite")

  result <- resolve_multi_analyte_row(df, "analyte", row_index = 1L, action = "keep")
  cleaned <- result$cleaned_data

  expect_equal(cleaned$analyte, "nitrate + nitrite")
  expect_equal(cleaned$multi_analyte_resolution, "keep_combined")
  expect_false(is_multi_analyte_review_row(cleaned))
  expect_match(cleaned$cleaning_flag, "REVIEWED: multi-analyte kept combined", fixed = TRUE)
  expect_equal(result$audit_trail$reason, "Kept as combined analyte")

  rechecked <- flag_multi_analyte(cleaned, "analyte")$cleaned_data
  expect_false(is_multi_analyte_review_row(rechecked))
  expect_no_match(rechecked$cleaning_flag, "WARNING: potential multi-analyte", fixed = TRUE)
})

test_that("resolve_multi_analyte_row rename updates the analyte and clears warning", {
  df <- multi_analyte_fixture("Thorium-230 and 232")

  result <- resolve_multi_analyte_row(
    df,
    "analyte",
    row_index = 1L,
    action = "rename",
    values = "Thorium-230/232 combined"
  )
  cleaned <- result$cleaned_data

  expect_equal(cleaned$analyte, "Thorium-230/232 combined")
  expect_equal(cleaned$multi_analyte_resolution, "rename")
  expect_false(is_multi_analyte_review_row(cleaned))
  expect_equal(result$audit_trail$new_value, "Thorium-230/232 combined")
})

test_that("resolve_multi_analyte_row split tolerates duplicate values after expansion", {
  df <- multi_analyte_fixture(c("Thorium-230 and 232", "Thorium-232"))
  df$cleaning_flag[2] <- NA_character_

  result <- resolve_multi_analyte_row(df, "analyte", row_index = 1L, action = "split")
  cleaned <- result$cleaned_data

  expect_equal(cleaned$analyte, c("Thorium-230", "Thorium-232", "Thorium-232"))
  expect_equal(sum(cleaned$analyte == "Thorium-232"), 2L)
})

test_that("resolve_multi_analyte_row validates empty and NA names", {
  df <- multi_analyte_fixture(c(NA_character_, ""))

  expect_error(
    resolve_multi_analyte_row(df, "analyte", row_index = 1L, action = "split"),
    "at least two"
  )
  expect_error(
    resolve_multi_analyte_row(df, "analyte", row_index = 2L, action = "rename", values = ""),
    "exactly one"
  )
})

test_that("apply_multi_analyte_resolutions applies specs in descending row order", {
  df <- multi_analyte_fixture(c("lead and arsenic", "nitrate + nitrite"))
  spec <- tibble::tibble(
    row_index = c(1L, 2L),
    action = c("split", "keep"),
    values = I(list(c("lead", "arsenic"), NULL))
  )

  result <- apply_multi_analyte_resolutions(df, "analyte", spec)

  expect_equal(result$cleaned_data$analyte, c("lead", "arsenic", "nitrate + nitrite"))
  expect_equal(result$cleaned_data$multi_analyte_resolution, c("split", "split", "keep_combined"))
  expect_equal(nrow(result$audit_trail), 3L)
  expect_false(any(is_multi_analyte_review_row(result$cleaned_data)))
})

test_that("curate_headless applies multi-analyte resolutions before curation", {
  skip_if_not_installed("withr")
  skip_if_not_installed("readr")

  input_path <- tempfile(fileext = ".csv")
  readr::write_csv(tibble::tibble(analyte = "lead and arsenic"), input_path)
  withr::defer(unlink(input_path))

  seen_clean_data <- NULL

  local_mocked_bindings(
    run_cleaning_pipeline = function(clean_data, tag_map, reference_lists = NULL, ...) {
      list(
        cleaned_data = multi_analyte_fixture("lead and arsenic"),
        audit_trail = empty_cleaning_audit(),
        new_tags = list()
      )
    },
    run_curation_pipeline = function(clean_data, column_tags, ...) {
      seen_clean_data <<- clean_data
      results <- init_resolution_state(tibble::tibble(
        analyte = clean_data$analyte,
        consensus_status = rep("error", nrow(clean_data)),
        consensus_dtxsid = rep(NA_character_, nrow(clean_data)),
        consensus_source = rep(NA_character_, nrow(clean_data))
      ))
      list(
        results = results,
        consensus_summary = recalc_consensus_summary(results),
        search_summary = list(n_exact = 0, n_cas_valid = 0, n_wqx = 0, n_starts_with = 0, n_miss = nrow(clean_data)),
        dedup_summary = list(n_names = nrow(clean_data), n_cas = 0)
      )
    }
  )

  result <- curate_headless(
    input_path = input_path,
    output_path = NULL,
    tag_map = list(analyte = "Name"),
    multi_analyte_resolutions = tibble::tibble(
      row_index = 1L,
      action = "split",
      values = I(list(c("lead", "arsenic")))
    ),
    write_files = FALSE,
    verbose = FALSE
  )

  expect_equal(seen_clean_data$analyte, c("lead", "arsenic"))
  expect_equal(result$data$analyte, c("lead", "arsenic"))
  expect_true("multi_analyte_resolution" %in% result$audit_trail$step)
})
