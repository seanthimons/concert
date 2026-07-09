# sswqs_parser_fixture.R
# Regenerates tests/testthat/data/sswqs_criterion_values.csv, the SSWQS parser
# regression corpus: every distinct non-numeric criterion_value string from the
# raw EPA SSWQS criteria workbook, with its expected parse outcome.
#
# Run manually after changing parse_numeric_results(); audit the diff of the
# CSV before committing — any outcome flip outside an intended rule change is
# a regression. The raw workbook stays outside the repo.
#
# Source workbook: EPA State-Specific Water Quality Standards criteria search
# tool export (https://www.epa.gov/wqs-tech).

sswqs_xlsx <- "C:/Users/sxthi/Documents/epa-sswqs/data/raw/sswqs_criteria.xlsx"
stopifnot(file.exists(sswqs_xlsx))

devtools::load_all(quiet = TRUE)

sheets <- rio::import_list(sswqs_xlsx)
dat <- janitor::clean_names(sheets[[which.max(sapply(sheets, nrow))]])
res <- as.character(dat$criterion_value)
corpus <- sort(unique(res[is.na(suppressWarnings(as.numeric(res))) & !is.na(res) & res != ""]))
message(length(corpus), " distinct non-numeric criterion_value strings")

parsed <- suppressWarnings(parse_numeric_results(corpus))

# Collapse per input string: ranges emit 3 rows (low/mid/high), singles emit 1
n_rows <- tabulate(parsed$orig_row_id, nbins = length(corpus))
first <- parsed[!duplicated(parsed$orig_row_id), ]
first <- first[order(first$orig_row_id), ]

expected_flag <- ifelse(
  n_rows == 3L,
  "range",
  ifelse(first$parse_flag == "", "value", first$parse_flag)
)
expected_low <- tapply(parsed$numeric_value, parsed$orig_row_id, min)
expected_high <- tapply(parsed$numeric_value, parsed$orig_row_id, max)

fixture <- data.frame(
  raw_value = corpus,
  expected_flag = expected_flag,
  expected_low = as.numeric(expected_low),
  expected_high = as.numeric(expected_high),
  stringsAsFactors = FALSE
)

# Sanity gates: the corpus must resolve the way the salvage rules were designed
stopifnot(
  # no zero-digit string may remain unparseable (all reclassified narrative)
  !any(fixture$expected_flag == "unparseable" & !grepl("[0-9]", fixture$raw_value)),
  # headline salvage targets
  fixture$expected_low[fixture$raw_value == "6 x 10-4"] == 6e-4,
  fixture$expected_low[fixture$raw_value == "7 million"] == 7e6,
  fixture$expected_flag[fixture$raw_value == "See note"] == "narrative",
  fixture$expected_flag[fixture$raw_value == "0.63-3,200"] == "range",
  # slash dual-values must NOT be coerced
  fixture$expected_flag[fixture$raw_value == "19/15"] == "unparseable"
)

out_path <- file.path("tests", "testthat", "data", "sswqs_criterion_values.csv")
write.csv(fixture, out_path, row.names = FALSE, fileEncoding = "UTF-8")
message("Wrote ", out_path, " (", nrow(fixture), " rows)")
print(table(fixture$expected_flag))
