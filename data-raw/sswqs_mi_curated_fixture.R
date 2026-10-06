# sswqs_mi_curated_fixture.R
# Regenerates tests/testthat/data/sswqs_mi_curated.csv: the 84 Michigan rows
# of data/uat/sswqs.xlsx with their real curation output (consensus columns).
# The issue #79 regression test uses it to stand in for curation offline.
#
# Needs network access (CompTox lookups). Audit the diff before committing.

devtools::load_all(quiet = TRUE)

sswqs <- readxl::read_excel("data/uat/sswqs.xlsx")
mi <- sswqs[sswqs$short_code == "MI", c("analyte", "cas", "orig_result", "unit")]
mi[] <- lapply(mi, as.character)

curated <- run_curation_pipeline(
  clean_data = mi,
  column_tags = list(analyte = "Name", cas = "CASRN"),
  original_data = mi
)$results

readr::write_csv(
  curated[c(names(mi), "consensus_status", "consensus_dtxsid", "consensus_name")],
  "tests/testthat/data/sswqs_mi_curated.csv",
  na = ""
)
