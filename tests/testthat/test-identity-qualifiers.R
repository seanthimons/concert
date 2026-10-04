test_that("13C6 identity enclosures survive cleaning without extraction or audit changes", {
  input <- tibble::tibble(
    name = c(
      "Dibenz(ah)anthracene (13C6)",
      "Dibenz(ah)anthracene [13C6]",
      "Acetone (ACS reagent)",
      "Compound (X13C6)",
      "Compound [13C6note]",
      NA_character_
    )
  )

  result <- strip_terminal_enclosures(input, "name")

  expect_identical(
    result$cleaned_data$name,
    c(
      input$name[1:2],
      "Acetone",
      "Compound",
      "Compound",
      NA_character_
    )
  )
  expect_identical(
    result$cleaned_data$formula_extract_name,
    c(
      NA_character_,
      NA_character_,
      "ACS reagent",
      "X13C6",
      "13C6note",
      NA_character_
    )
  )
  expect_identical(result$audit_trail$row_id, 3:5)
  expect_identical(result$audit_trail$original_value, input$name[3:5])
  expect_identical(result$audit_trail$new_value, c("Acetone", "Compound", "Compound"))
})

test_that("supported isotope tokens preserve both enclosure styles and original spelling", {
  labels <- c(
    "D8",
    "d12",
    "15N2",
    "18O2",
    "2H5",
    "ring-13C6",
    "U-13C",
    "D 8",
    "13 C6",
    "Ring-13C6",
    "u-13C",
    "13C3, 15N3",
    "34S",
    "37Cl"
  )
  names <- c(paste0("Compound (", labels, ")"), paste0("Compound [", labels, "]"))
  result <- strip_terminal_enclosures(tibble::tibble(name = names), "name")

  expect_identical(result$cleaned_data$name, names)
  expect_true(all(is.na(result$cleaned_data$formula_extract_name)))
  expect_equal(nrow(result$audit_trail), 0L)
})

test_that("embedded lookalikes and incorrect element case do not protect annotations", {
  contents <- c(
    "X15N2",
    "15N2note",
    "XPCB 153",
    "PCB 153note",
    "TMX-1note",
    "XParlar 21",
    "B8-1413note",
    "23+",
    "+23",
    "13c6",
    "37CL",
    "D",
    "ACS reagent",
    "NaCl",
    "food grade"
  )
  names <- c(paste0("Compound (", contents, ")"), paste0("Compound [", contents, "]"))
  result <- strip_terminal_enclosures(tibble::tibble(name = names), "name")

  expect_identical(result$cleaned_data$name, rep("Compound", length(names)))
  expect_identical(result$cleaned_data$formula_extract_name, rep(contents, 2))
  expect_equal(nrow(result$audit_trail), length(names))
})

test_that("bounded identity tokens survive mixed annotations and the full cleaning pipeline", {
  names <- c(
    "Compound (13C6, ACS reagent)",
    "Compound [ACS reagent, 15N2]",
    "Compound (13C6 internal standard)",
    "Compound [13C3/15N3]",
    "Compound (D8) (ACS reagent)",
    "Compound [18O2] (ACS reagent)",
    "Heptachlorobornane (Parlar 21)",
    "Heptachlorobornane [TMX-1]",
    "Compound (13C6) (density annotation)",
    "Compound (food grade)"
  )
  input <- tibble::tibble(name = names)
  direct <- strip_terminal_enclosures(input, "name")
  full <- run_cleaning_pipeline(input, list(name = "Name"))
  expected <- c(names[1:4], "Compound (D8)", "Compound [18O2]", names[7:8], "Compound (13C6)", "Compound")

  expect_identical(direct$cleaned_data$name, expected)
  expect_identical(full$cleaned_data$name, expected)
  expect_identical(
    full$cleaned_data$formula_extract_name,
    c(
      rep(NA_character_, 4),
      "ACS reagent",
      "ACS reagent",
      rep(NA_character_, 2),
      "density annotation",
      "food grade"
    )
  )
  removals <- full$audit_trail[full$audit_trail$step == "strip_terminal_enclosures", ]
  expect_equal(removals$row_id, c(5L, 6L, 9L, 10L))
  expect_identical(removals$original_value, names[c(5, 6, 9, 10)])
  expect_identical(removals$new_value, expected[c(5, 6, 9, 10)])
  expect_true(all(removals$field == "name"))
})

test_that("full cleaning keeps distinct identities and accurate audits with dedup enabled or disabled", {
  names <- c(
    "Benzene (D6)",
    "Benzene (D8)",
    "Heptachlorobornane (Parlar 21)",
    "Heptachlorobornane [TMX-1]",
    "Benzene (D6) [ACS reagent]",
    "Benzene [D8] (ACS reagent)",
    "Heptachlorobornane (Parlar 21) [food grade]",
    "Heptachlorobornane (Parlar 21) [food grade]"
  )
  expected <- c(names[1:4], "Benzene (D6)", "Benzene [D8]", rep(names[3], 2))

  for (use_dedup in c(TRUE, FALSE)) {
    result <- run_cleaning_pipeline(
      tibble::tibble(name = names),
      list(name = "Name"),
      use_dedup = use_dedup
    )

    expect_identical(result$cleaned_data$name, expected)
    expect_equal(dplyr::n_distinct(result$cleaned_data$name[1:4]), 4L)
    expect_identical(result$cleaned_data$original_row_id, seq_along(names))
    expect_identical(
      result$cleaned_data$formula_extract_name,
      c(
        rep(NA_character_, 4),
        rep("ACS reagent", 2),
        rep("food grade", 2)
      )
    )
    removals <- result$audit_trail[result$audit_trail$step == "strip_terminal_enclosures", ]
    expect_identical(sort(removals$row_id), 5:8)
    expect_identical(removals$original_value, names[removals$row_id])
    expect_identical(removals$new_value, expected[removals$row_id])
    expect_true(all(removals$field == "name"))
  }
})

test_that("congener and charge tokens protect mixed enclosures in both styles", {
  labels <- c(
    "Parlar 21",
    "Parlar #56A",
    "P26",
    "p-42a",
    "TMX-1",
    "Hp-Sed",
    "B8-1413",
    "T2, Tox8",
    "PCB 153",
    "BZ #118",
    "CB 77",
    "PBDE 47",
    "BDE-47",
    "PBB 153",
    "IUPAC 77",
    "3+",
    "2-",
    "+3"
  )
  contents <- c(labels, paste0(labels, ", ACS reagent"), paste0("annotation; ", labels))
  names <- c(paste0("Compound (", contents, ")"), paste0("Compound [", contents, "]"))
  result <- strip_terminal_enclosures(tibble::tibble(name = names), "name")

  expect_identical(result$cleaned_data$name, names)
  expect_true(all(is.na(result$cleaned_data$formula_extract_name)))
  expect_equal(nrow(result$audit_trail), 0L)
})

test_that("positional locants are protected separately from genuine charges", {
  names <- c(
    "dinitrobenzene(1,3-)", "dithiane (1,4-)",
    "trinitrotoluene (2,4,6-)", "trichlorobenzene ( 1,3,5-)",
    "trichlorophenoxy proprionic acid, 2 (2,4,5-)",
    "Compound (1, 3-)", "Compound (2, 4, 6-, ACS reagent)",
    "Compound (ACS reagent, 3+)", "Compound (2-)", "Compound (+3)"
  )
  names <- c(names, chartr("()", "[]", names))
  direct <- strip_terminal_enclosures(tibble::tibble(name = names), "name")
  expect_identical(direct$cleaned_data$name, names)
  expect_true(all(is.na(direct$cleaned_data$formula_extract_name)))
  expect_equal(nrow(direct$audit_trail), 0L)

  for (use_dedup in c(TRUE, FALSE)) {
    input <- c(names, names[1], "dithiane (1,4-) [ACS reagent]")
    result <- run_cleaning_pipeline(tibble::tibble(name = input), list(name = "Name"), use_dedup = use_dedup)
    expected <- c(stringr::str_squish(names), names[1], "dithiane (1,4-)")
    expect_identical(result$cleaned_data$name, expected)
    expect_identical(result$cleaned_data$original_row_id, seq_along(input))
    expect_identical(result$cleaned_data$formula_extract_name, c(rep(NA_character_, length(input) - 1L), "ACS reagent"))
    removals <- dplyr::filter(result$audit_trail, step == "strip_terminal_enclosures")
    expect_identical(removals$row_id, length(input))
    expect_identical(removals$new_value, "dithiane (1,4-)")
  }
  expect_false(stringr::str_detect("1,3-", CHARGE_PATTERN))
  expect_false(is_identity_qualifier("X1,3,5-"))
})

test_that("embedded congener suffixes strip without breaking attached isotopes", {
  names <- c("Trp-P-1 (Tryptophan-P-1)", "Trp-P-2 (Tryptophan-P-2)")
  names <- c(names, chartr("()", "[]", names))
  controls <- c("P-1", "P-2", "Parlar 21", "TMX-1, ACS reagent", "name-13C6", "name-d8", "Ring-13C6")
  controls <- c(paste0("Compound (", controls, ")"), paste0("Compound [", controls, "]"))
  input <- tibble::tibble(name = c(names, controls))
  expected <- c(rep(c("Trp-P-1", "Trp-P-2"), 2), controls)
  results <- list(strip_terminal_enclosures(input, "name"))
  for (use_dedup in c(TRUE, FALSE)) {
    results <- c(results, list(run_cleaning_pipeline(input, list(name = "Name"), use_dedup = use_dedup)))
  }
  for (result in results) {
    expect_identical(result$cleaned_data$name, expected)
    expect_identical(result$cleaned_data$formula_extract_name, c(rep(c("Tryptophan-P-1", "Tryptophan-P-2"), 2), rep(NA_character_, length(controls))))
    removals <- dplyr::filter(result$audit_trail, step == "strip_terminal_enclosures")
    expect_identical(sort(removals$row_id), 1:4)
    expect_identical(removals$original_value, input$name[removals$row_id])
    expect_identical(removals$new_value, expected[removals$row_id])
  }
})

test_that("PCB reporting basis is preserved without individual-congener evidence", {
  labels <- c("as PCB6", "as PCB6, ACS reagent", "as PCB6, PCB153", "as PCB6, 13C6", "PCB6", "PCB 153", "PBDE 47", "PBB 153")
  names <- c(paste0("PCBtotal (", labels, ")"), paste0("PCBtotal [", labels, "]"))
  input <- tibble::tibble(name = c(names, "PCBtotal (as PCB6) [ACS reagent]", "Compound (as PCB6note)"))
  expected <- c(names, "PCBtotal (as PCB6)", "Compound")
  results <- list(strip_terminal_enclosures(input, "name"))
  for (use_dedup in c(TRUE, FALSE)) {
    results <- c(results, list(run_cleaning_pipeline(input, list(name = "Name"), use_dedup = use_dedup)))
  }
  for (result in results) {
    expect_identical(result$cleaned_data$name, expected)
    expect_identical(result$cleaned_data$formula_extract_name, c(rep(NA_character_, length(names)), "ACS reagent", "as PCB6note"))
    removals <- dplyr::filter(result$audit_trail, step == "strip_terminal_enclosures")
    expect_identical(sort(removals$row_id), length(names) + 1:2)
    expect_identical(removals$new_value, expected[removals$row_id])
  }
  expect_false(is_identity_qualifier("as PCB6, ACS reagent"))
  expect_true(is_identity_qualifier("as PCB6, PCB153"))
})

test_that("semicolon synonyms split only outside balanced enclosures", {
  preserved <- c(
    "Heptachlorobornane [TMX-1; ACS reagent]",
    "Compound (13C6; ACS reagent)", "PCBtotal [as PCB6; ACS reagent]"
  )
  for (use_dedup in c(TRUE, FALSE)) {
    result <- run_cleaning_pipeline(tibble::tibble(name = c(preserved, preserved[1])), list(name = "Name"), use_dedup = use_dedup)
    expect_identical(result$cleaned_data$name, c(preserved, preserved[1]))
    expect_identical(result$cleaned_data$synonym_count, rep(1L, 4))
    expect_identical(result$cleaned_data$original_row_id, 1:4)
    expect_true(all(is.na(result$cleaned_data$formula_extract_name)))
    expect_false(any(result$audit_trail$step %in% c("split_synonyms", "strip_terminal_enclosures")))
  }

  names <- c(
    "Compound [TMX-1; ACS reagent]; alternative name",
    "Compound ([TMX-1; ACS reagent]); alternative name",
    "Compound [TMX-1; ACS reagent", "Compound [TMX-1); alternative name",
    "Compound ]; alternative name", "acetone; ; water", NA_character_
  )
  result <- split_synonyms(tibble::tibble(original_row_id = seq_along(names), name = names), "name", list(name = "Name"))
  for (i in 1:2) {
    rows <- dplyr::filter(result$cleaned_data, original_row_id == i)
    expect_identical(rows$name, c(sub("; alternative name$", "", names[i]), "alternative name"))
    expect_identical(rows$synonym_count, c(2L, 2L))
  }
  for (i in 3:5) {
    expect_identical(dplyr::filter(result$cleaned_data, original_row_id == i)$name, names[i])
  }
  expect_identical(dplyr::filter(result$cleaned_data, original_row_id == 6)$name, c("acetone", "water"))
  expect_identical(dplyr::filter(result$cleaned_data, original_row_id == 7)$name, NA_character_)
  expect_setequal(result$audit_trail$row_id, c(1L, 2L, 6L))

  for (use_dedup in c(TRUE, FALSE)) {
    full <- run_cleaning_pipeline(tibble::tibble(name = names[1]), list(name = "Name"), use_dedup = use_dedup)
    expect_identical(full$cleaned_data$name, c("Compound [TMX-1; ACS reagent]", "alternative name"))
    expect_identical(full$cleaned_data$original_row_id, c(1L, 1L))
    expect_true(all(is.na(full$cleaned_data$formula_extract_name)))
    expect_false(any(grepl("truncated", full$cleaned_data$cleaning_flag)))
    expect_equal(sum(full$audit_trail$step == "split_synonyms"), 2L)
  }
})
