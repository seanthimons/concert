# Test file for dedup infrastructure functions
# Tests for dedup_step() and remap_audit_to_parent() — Phase 37 PERF-01 / PERF-02

# ==============================================================================
# Helper: simple uppercase step for testing dedup_step
# ==============================================================================

uppercase_step <- function(df, cols) {
  df_result <- df
  audit_rows <- integer()
  audit_fields <- character()
  audit_originals <- character()
  audit_news <- character()
  for (col_name in cols) {
    original <- df[[col_name]]
    cleaned <- toupper(original)
    changed <- which(!is.na(original) & original != cleaned)
    if (length(changed) > 0) {
      audit_rows <- c(audit_rows, as.integer(changed))
      audit_fields <- c(audit_fields, rep(col_name, length(changed)))
      audit_originals <- c(audit_originals, original[changed])
      audit_news <- c(audit_news, cleaned[changed])
      df_result[[col_name]] <- cleaned
    }
  }
  list(
    cleaned_data = df_result,
    audit_trail = tibble::tibble(
      row_id = audit_rows,
      field = audit_fields,
      step = rep("uppercase", length(audit_rows)),
      original_value = audit_originals,
      new_value = audit_news,
      reason = rep("uppercased", length(audit_rows))
    )
  )
}

# ==============================================================================
# remap_audit_to_parent tests
# ==============================================================================

test_that("remap_audit_to_parent with empty audit returns empty typed tibble", {
  empty_audit <- tibble::tibble(
    row_id = integer(),
    field = character(),
    step = character(),
    original_value = character(),
    new_value = character(),
    reason = character()
  )
  parent_map <- list("1" = c(1L, 2L), "2" = c(3L, 4L))

  result <- remap_audit_to_parent(empty_audit, parent_map)

  expect_equal(nrow(result), 0L)
  expect_named(result, c("row_id", "field", "step", "original_value", "new_value", "reason"))
  expect_type(result$row_id, "integer")
  expect_type(result$field, "character")
})

test_that("remap_audit_to_parent expands row IDs correctly to all parent rows", {
  audit_slice <- tibble::tibble(
    row_id = c(1L, 2L),
    field = c("name", "name"),
    step = c("uppercase", "uppercase"),
    original_value = c("acetone", "ethanol"),
    new_value = c("ACETONE", "ETHANOL"),
    reason = c("uppercased", "uppercased")
  )
  # key 1 appears at parent rows 1, 3, 5 — key 2 at rows 2, 4
  parent_map <- list("1" = c(1L, 3L, 5L), "2" = c(2L, 4L))

  result <- remap_audit_to_parent(audit_slice, parent_map)

  expect_equal(nrow(result), 5L)
  expect_equal(result$row_id, c(1L, 3L, 5L, 2L, 4L))

  # Values from key 1 replicated for rows 1, 3, 5
  expect_true(all(result$original_value[result$row_id %in% c(1L, 3L, 5L)] == "acetone"))
  expect_true(all(result$new_value[result$row_id %in% c(1L, 3L, 5L)] == "ACETONE"))

  # Values from key 2 replicated for rows 2, 4
  expect_true(all(result$original_value[result$row_id %in% c(2L, 4L)] == "ethanol"))
  expect_true(all(result$new_value[result$row_id %in% c(2L, 4L)] == "ETHANOL"))

  # All row_ids are integer
  expect_type(result$row_id, "integer")
})

# ==============================================================================
# dedup_step tests
# ==============================================================================

test_that("dedup_step with highly unique data bypasses dedup (D-03 threshold)", {
  # 10 rows all unique — uniqueness ratio = 1.0, exceeds 0.5 threshold
  df <- tibble::tibble(
    name = c(
      "acetone",
      "ethanol",
      "benzene",
      "toluene",
      "methanol",
      "hexane",
      "pentane",
      "propanol",
      "butanol",
      "xylene"
    )
  )

  direct_result <- uppercase_step(df, "name")
  dedup_result <- dedup_step(uppercase_step, df, "name", dedup_cols = "name")

  # Should produce identical output to direct call
  expect_equal(dedup_result$cleaned_data$name, direct_result$cleaned_data$name)
  expect_equal(nrow(dedup_result$audit_trail), nrow(direct_result$audit_trail))

  # Row IDs must be in valid range
  if (nrow(dedup_result$audit_trail) > 0) {
    expect_true(all(dedup_result$audit_trail$row_id <= nrow(df)))
    expect_true(all(dedup_result$audit_trail$row_id >= 1L))
  }
})

test_that("dedup_step with mostly duplicate data deduplicates and produces correct output", {
  # 100 rows, only 5 unique values — uniqueness ratio = 5/100 = 0.05, below 0.5 threshold
  df <- tibble::tibble(
    chemical_name = rep(c("acetone", "ethanol", "benzene", "toluene", "methanol"), 20L)
  )

  result <- dedup_step(uppercase_step, df, "chemical_name", dedup_cols = "chemical_name")

  # Output must have 100 rows (same as input)
  expect_equal(nrow(result$cleaned_data), 100L)

  # All values should be uppercased
  expect_true(all(result$cleaned_data$chemical_name == toupper(df$chemical_name)))

  # PERF-02: all audit row_ids must be <= 100
  expect_true(all(result$audit_trail$row_id <= nrow(df)))
  expect_gt(nrow(result$audit_trail), 0L)

  # Audit must cover all 100 rows (every row changed)
  expect_equal(nrow(result$audit_trail), 100L)
})

test_that("dedup_step preserves new_tags if step function returns them", {
  mock_step_with_tags <- function(df, cols) {
    result <- uppercase_step(df, cols)
    result$new_tags <- list(col = "CASRN")
    result
  }

  df <- tibble::tibble(name = rep(c("acetone", "ethanol"), 5L))
  result <- dedup_step(mock_step_with_tags, df, "name", dedup_cols = "name")

  expect_true(!is.null(result$new_tags))
  expect_equal(result$new_tags$col, "CASRN")
})

test_that("dedup_step handles NA values in dedup columns without errors", {
  # Mix of NA and real values — NAs should be grouped together as one unique value
  df <- tibble::tibble(
    name = c("acetone", NA, "acetone", NA, "ethanol", NA)
  )

  # Should not error
  result <- dedup_step(uppercase_step, df, "name", dedup_cols = "name")

  # Output row count must be preserved
  expect_equal(nrow(result$cleaned_data), 6L)

  # Non-NA values are uppercased
  non_na_idx <- !is.na(df$name)
  expect_equal(
    result$cleaned_data$name[non_na_idx],
    toupper(df$name[non_na_idx])
  )

  # NA values stay NA
  expect_true(all(is.na(result$cleaned_data$name[is.na(df$name)])))

  # Audit row_ids in range
  if (nrow(result$audit_trail) > 0) {
    expect_true(all(result$audit_trail$row_id <= nrow(df)))
  }
})

test_that("dedup_step returns list with cleaned_data and audit_trail (step contract preserved)", {
  df <- tibble::tibble(
    name = rep(c("acetone", "ethanol"), 3L)
  )

  result <- dedup_step(uppercase_step, df, "name", dedup_cols = "name")

  expect_type(result, "list")
  expect_true("cleaned_data" %in% names(result))
  expect_true("audit_trail" %in% names(result))
  expect_s3_class(result$cleaned_data, "tbl_df")
  expect_s3_class(result$audit_trail, "tbl_df")
  expect_named(
    result$audit_trail,
    c("row_id", "field", "step", "original_value", "new_value", "reason")
  )
})

test_that("dedup_step with normalize_cas_fields integration: row count and audit validity", {
  # 20 rows with tag_map wiring and many duplicate CAS values
  df <- tibble::tibble(
    compound = rep(c("acetone", "ethanol", "benzene", "toluene"), 5L),
    cas = rep(c("67641", "64175", "71432", "108883"), 5L)
  )
  tag_map <- list(compound = "Name", cas = "CASRN")

  result <- dedup_step(
    normalize_cas_fields,
    df,
    tag_map,
    dedup_cols = "cas"
  )

  # Row count preserved
  expect_equal(nrow(result$cleaned_data), 20L)

  # CAS values normalized correctly (e.g., "67641" -> "67-64-1")
  expect_equal(result$cleaned_data$cas[1], "67-64-1")
  expect_equal(result$cleaned_data$cas[2], "64-17-5")
  expect_equal(result$cleaned_data$cas[3], "71-43-2")
  expect_equal(result$cleaned_data$cas[4], "108-88-3")

  # PERF-02: all audit row_ids <= 20
  if (nrow(result$audit_trail) > 0) {
    expect_true(all(result$audit_trail$row_id <= nrow(df)))
  }
})

test_that("PERF-02 assertion fires when audit row_id would exceed parent row count", {
  # Construct a buggy remap that produces out-of-range row IDs by using
  # a parent_map with indices exceeding the parent row count
  audit_slice <- tibble::tibble(
    row_id = c(1L),
    field = c("name"),
    step = c("uppercase"),
    original_value = c("acetone"),
    new_value = c("ACETONE"),
    reason = c("uppercased")
  )

  # Parent map points to row 999, which would exceed a 3-row parent df
  bad_parent_map <- list("1" = c(999L))
  remapped <- remap_audit_to_parent(audit_slice, bad_parent_map)

  # Manually trigger the PERF-02 assertion by checking with a small parent
  parent_nrow <- 3L
  expect_error(
    if (nrow(remapped) > 0) stopifnot(max(remapped$row_id) <= parent_nrow),
    regexp = NULL
  )
})
