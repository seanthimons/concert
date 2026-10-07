# From the package root:
# source("inst/examples/identity-review-demo.R")
# run_identity_review_demo()
run_identity_review_demo <- function(port = 63320L, launch.browser = interactive()) {
  devtools::load_all(quiet = TRUE)
  fixture <- concert:::init_resolution_state(tibble::tibble(
    original_row_id = 1:4,
    name = c("Mock registered mixture", "Mock registered mixture", "Mock unavailable source", "Mock follow-up source"),
    cas = c("1-23-4", "1-23-4", "2-34-5", "3-45-6"),
    source_file = c("inventory A", "inventory B", "inventory C", "inventory D"),
    source_dtxsid = c("DTXSID123", "DTXSID123", "DTXSID456", "DTXSID123"),
    source_id_source_dtxsid_source_candidate_id = c("DTXSID123", "DTXSID123", "DTXSID456", "DTXSID123"),
    source_id_source_dtxsid_validation_status = c("validated", "validated", "unavailable", "validated"),
    source_id_source_dtxsid_identity_status = "scope_review",
    source_id_source_dtxsid_authority = "Synthetic fixture",
    consensus_dtxsid = c("DTXSID123", "DTXSID123", "DTXSID456", "DTXSID123"),
    consensus_status = "single", consensus_source = "cas", dtxsid_cas = "DTXSID123",
    multi_analyte_resolution = "keep_combined", identity_conflict = "scope",
    row_flag = c(NA_character_, NA_character_, NA_character_, "FOLLOW-UP"),
    row_flag_reason = c(NA_character_, NA_character_, NA_character_, "Keep this follow-up flag")))
  testthat::local_mocked_bindings(
    validate_manual_dtxsids = function(ids, ...) tibble::tibble(searchValue = ids, dtxsid = ids,
      preferredName = "Synthetic fixture", is_valid = ids %in% c("DTXSID123", "DTXSID456", "DTXSID789")),
    run_curation_pipeline = function(...) stop("Discovery is disabled in this synthetic review demo."),
    find_related_parent_candidates = function(...) tibble::tibble(),
    .package = "concert")
  ui <- bslib::page_fluid(theme = bslib::bs_theme(version = 5), shinyjs::useShinyjs(),
    shiny::tags$h3("Source correspondence review — synthetic test fixtures"),
    shiny::tags$p("Registry checks are mocked. No fixture is a validated chemical assignment. Use Expert Override to open a row."),
    shiny::tags$p("Two mixture rows share a chemical name: choose one source row. The unavailable source cannot promote its source ID. FOLLOW-UP stays flagged after correspondence review."),
    concert::mod_review_results_ui("review"))
  server <- function(input, output, session) {
    store <- shiny::reactiveValues(curation_status = "completed", resolution_state = fixture, script_baseline_state = fixture,
      clean = fixture[c("name", "cas", "source_file", "source_dtxsid")],
      column_tags = list(name = "Name", cas = "CASRN", source_dtxsid = "DTXSID"),
      consensus_summary = concert:::recalc_consensus_summary(fixture), dtxsid_cols = "dtxsid_cas",
      file_info = list(name = "synthetic-review.csv", size = 1), reference_lists = list())
    concert::mod_review_results_server("review", store)
  }
  shiny::runApp(shiny::shinyApp(ui, server), port = port, launch.browser = launch.browser)
}
