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
  expect_identical(removals$new_value, expected[c(5, 6, 9, 10)])
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
