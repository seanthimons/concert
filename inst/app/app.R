# CONCERT Shiny Data Upload & Preview Application
# Upload CSV/XLSX files with intelligent frontmatter detection

# Load Shiny UI packages (required for DSL-style UI code)
# Other packages come from concert namespace via Imports
library(shiny)
library(bslib)
library(bsicons)
library(reactable)
library(reactable.extras)
library(shinyjs)

# Load reference lists (cached locally for fast startup)
# Uses system.file() for installed package access
reference_lists <- concert::load_all_reference_lists(
  system.file("extdata", "reference_cache", package = "concert")
)

# Application configuration
options(
  shiny.maxRequestSize = 50 * 1024^2 # 50MB upload limit
)


# UI Definition
ui <- page_sidebar(
  # Enable shinyjs
  shinyjs::useShinyjs(),

  # Tab pulse animation CSS
  tags$head(tags$style(
    "
    @keyframes tab-pulse {
      0% { background-color: transparent; }
      50% { background-color: rgba(0, 123, 255, 0.15); }
      100% { background-color: transparent; }
    }
    .tab-pulse > .nav-link {
      animation: tab-pulse 0.5s ease-in-out 2;
    }
  "
  )),

  # Theme
  theme = bs_theme(
    version = 5,
    bootswatch = "flatly",
    primary = "#007bff"
  ),

  # Title
  title = "CONCERT Data Upload & Preview",

  # Sidebar — delegated to upload module
  sidebar = sidebar(
    id = "main_sidebar",
    width = 300,
    concert::mod_file_upload_ui("upload"),
    hr(),
    h6("Import Configuration", class = "text-muted"),
    fileInput(
      "config_import",
      label = NULL,
      accept = ".xlsx",
      buttonLabel = "Browse...",
      placeholder = "CONCERT export (.xlsx)"
    ),
    helpText("Optional: restore reference lists from a previous CONCERT export", class = "small")
  ),

  # Main Content — module UIs in tabs
  navset_underline(
    id = "main_tabs",
    nav_panel(
      "Data Preview",
      value = "data_preview",
      icon = bsicons::bs_icon("table"),
      concert::mod_data_preview_ui("preview")
    ),
    nav_panel(
      "Detection Info",
      value = "detection_info",
      icon = bsicons::bs_icon("search"),
      concert::mod_detection_info_ui("detection")
    ),
    nav_panel("Raw Data", value = "raw_data", icon = bsicons::bs_icon("file-text"), concert::mod_raw_data_ui("raw")),
    nav_panel(
      "Tag Columns",
      value = "tag_columns",
      icon = bsicons::bs_icon("tags"),
      concert::mod_tag_columns_ui("tags")
    ),
    nav_panel(
      "Clean Data",
      value = "clean_data",
      icon = bsicons::bs_icon("magic"),
      concert::mod_clean_data_ui("cleaning")
    ),
    nav_panel(
      "Run Curation",
      value = "run_curation_tab",
      icon = bsicons::bs_icon("play-circle"),
      concert::mod_run_curation_ui("curation")
    ),
    nav_panel(
      "Harmonize",
      value = "harmonize_tab",
      icon = bsicons::bs_icon("sliders"),
      concert::mod_harmonize_ui("harmonize")
    ),
    nav_panel(
      "Review Results",
      value = "review_results",
      icon = bsicons::bs_icon("clipboard-check"),
      concert::mod_review_results_ui("results")
    )
  )
)

# Server Logic
server <- function(input, output, session) {
  # Create shared data store
  data_store <- shiny::reactiveValues(
    raw = NULL,
    clean = NULL,
    detection = NULL,
    file_info = NULL,
    selected_columns = NULL,
    column_tags = NULL,
    cleaning_audit = NULL,
    cleaned_data = NULL,
    reference_lists = NULL,
    curation_results = NULL,
    curation_report = NULL,
    curation_status = NULL,
    dedup_preview = NULL,
    consensus_data = NULL,
    consensus_summary = NULL,
    resolution_state = NULL,
    script_baseline_state = NULL,
    dtxsid_cols = NULL,
    priority_order = NULL,
    review_visible_cols = NULL,
    error_filter_active = FALSE,
    unassigned_untagged_filter_active = FALSE,
    display_row_map = NULL,
    selected_error_rows = NULL,
    selected_visible_rows = NULL,
    manual_queue = list(),
    qc_results = NULL,
    enrichment_cache = NULL,
    enrichment_failed = NULL,
    # Phase 33: Extended tag types and harmonization state
    numeric_tags = NULL,
    metadata_tags = NULL,
    harmonize_results = NULL,
    harmonize_audit = NULL,
    toxval_output = NULL,
    prev_chemical_tags = NULL,
    prev_numeric_tags = NULL,
    # Phase 34: Harmonize working copies (session-local, initialized from reference_lists)
    unit_map_working = NULL,
    corrections_working = NULL,
    media_map_working = NULL,
    # Phase 34-04: Stale results pattern for cascade reset UX
    harmonize_results_stale = FALSE,
    changed_units = character(0)
  )

  # Store reference lists in data_store
  data_store$reference_lists <- reference_lists

  # --- Config Import Handlers ---

  # Store parsed config data between modal show and confirm
  imported_config <- shiny::reactiveVal(NULL)

  # Handle config file upload
  shiny::observeEvent(input$config_import, {
    shiny::req(input$config_import)

    # Parse the uploaded file
    parsed <- concert::parse_concert_export(input$config_import$datapath)

    if (is.null(parsed)) {
      shiny::showNotification(
        "Not a valid CONCERT export file. Upload a file exported from CONCERT with Pipeline Config sheet.",
        type = "warning",
        duration = 5
      )
      return()
    }

    # Store parsed data
    imported_config(parsed)

    # Show confirmation modal
    shiny::showModal(shiny::modalDialog(
      title = "CONCERT Export Detected",
      shiny::p("This file contains configuration data from a previous CONCERT session."),
      shiny::p("Select what you want to import:"),
      shiny::checkboxInput("restore_ref_lists", "Restore reference lists", value = TRUE),
      shiny::checkboxInput("restore_col_tags", "Restore column tags", value = TRUE),
      shiny::p(class = "text-muted small", "Note: Imported reference lists will merge with existing lists."),
      footer = shiny::tagList(
        shiny::modalButton("Cancel"),
        shiny::actionButton("confirm_config_import", "Import", class = "btn-primary")
      ),
      size = "m",
      easyClose = TRUE
    ))
  })

  # Handle import confirmation
  shiny::observeEvent(input$confirm_config_import, {
    shiny::req(imported_config())

    # Capture checkbox states before modal closes
    restore_refs <- input$restore_ref_lists
    restore_tags <- input$restore_col_tags

    # Remove modal
    shiny::removeModal()

    # Import reference lists
    if (restore_refs) {
      tryCatch(
        {
          data_store$reference_lists <- concert::merge_reference_lists(
            data_store$reference_lists,
            imported_config()$reference_lists
          )
          shiny::showNotification(
            "Reference lists imported and merged successfully",
            type = "message",
            duration = 3
          )
        },
        error = function(e) {
          shiny::showNotification(
            paste("Failed to import reference lists:", conditionMessage(e)),
            type = "error",
            duration = 5
          )
        }
      )
    }

    # Import column tags
    if (restore_tags) {
      tryCatch(
        {
          # Convert column_tags tibble (Column, Type) to named list
          tags_df <- imported_config()$column_tags
          data_store$column_tags <- stats::setNames(tags_df$Type, tags_df$Column)

          shiny::showNotification(
            "Column tags imported successfully",
            type = "message",
            duration = 3
          )
        },
        error = function(e) {
          shiny::showNotification(
            paste("Failed to import column tags:", conditionMessage(e)),
            type = "error",
            duration = 5
          )
        }
      )
    }

    # Clear imported config
    imported_config(NULL)
  })

  # --- Gated Navigation ---
  session$onFlushed(
    function() {
      bslib::nav_hide("main_tabs", target = "detection_info", session = session)
      bslib::nav_hide("main_tabs", target = "raw_data", session = session)
      bslib::nav_hide("main_tabs", target = "clean_data", session = session)
      bslib::nav_hide("main_tabs", target = "tag_columns", session = session)
      bslib::nav_hide("main_tabs", target = "run_curation_tab", session = session)
      bslib::nav_hide("main_tabs", target = "harmonize_tab", session = session)
      bslib::nav_hide("main_tabs", target = "review_results", session = session)
    },
    once = TRUE
  )

  show_tab_with_pulse <- function(tab_value) {
    bslib::nav_show("main_tabs", target = tab_value, session = session)
    shinyjs::runjs(sprintf(
      "
      var tab = document.querySelector('[data-value=\"%s\"]');
      if (tab) {
        var li = tab.closest('li');
        if (li) {
          li.classList.add('tab-pulse');
          setTimeout(function() { li.classList.remove('tab-pulse'); }, 1200);
        }
      }
    ",
      tab_value
    ))
  }

  reset_all_downstream <- function() {
    data_store$cleaning_audit <- NULL
    data_store$cleaned_data <- NULL
    data_store$column_tags <- NULL
    data_store$curation_results <- NULL
    data_store$curation_report <- NULL
    data_store$curation_status <- NULL
    data_store$dedup_preview <- NULL
    data_store$consensus_data <- NULL
    data_store$consensus_summary <- NULL
    data_store$resolution_state <- NULL
    data_store$script_baseline_state <- NULL
    data_store$qc_results <- NULL
    data_store$dtxsid_cols <- NULL
    data_store$priority_order <- NULL
    data_store$review_visible_cols <- NULL
    data_store$error_filter_active <- FALSE
    data_store$unassigned_untagged_filter_active <- FALSE
    data_store$display_row_map <- NULL
    data_store$selected_error_rows <- NULL
    data_store$selected_visible_rows <- NULL
    # Phase 33: Reset extended tag types and harmonization state
    data_store$numeric_tags <- NULL
    data_store$metadata_tags <- NULL
    data_store$harmonize_results <- NULL
    data_store$harmonize_audit <- NULL
    data_store$toxval_output <- NULL
    data_store$prev_chemical_tags <- NULL
    data_store$prev_numeric_tags <- NULL
    # Phase 34: Reset harmonize working copies
    data_store$unit_map_working <- NULL
    data_store$corrections_working <- NULL
    data_store$media_map_working <- NULL
    bslib::nav_hide("main_tabs", target = "detection_info", session = session)
    bslib::nav_hide("main_tabs", target = "raw_data", session = session)
    bslib::nav_hide("main_tabs", target = "clean_data", session = session)
    bslib::nav_hide("main_tabs", target = "tag_columns", session = session)
    bslib::nav_hide("main_tabs", target = "run_curation_tab", session = session)
    bslib::nav_hide("main_tabs", target = "harmonize_tab", session = session)
    bslib::nav_hide("main_tabs", target = "review_results", session = session)
    bslib::nav_select("main_tabs", "data_preview", session = session)
  }

  # Phase 33: Granular cascade reset functions per D-09
  reset_chemical_downstream <- function() {
    data_store$curation_results <- NULL
    data_store$curation_report <- NULL
    data_store$curation_status <- NULL
    data_store$consensus_data <- NULL
    data_store$consensus_summary <- NULL
    data_store$resolution_state <- NULL
    data_store$script_baseline_state <- NULL
    data_store$qc_results <- NULL
    data_store$toxval_output <- NULL
    data_store$review_visible_cols <- NULL
    data_store$error_filter_active <- FALSE
    data_store$unassigned_untagged_filter_active <- FALSE
    data_store$display_row_map <- NULL
    data_store$selected_error_rows <- NULL
    data_store$selected_visible_rows <- NULL
  }

  reset_numeric_downstream <- function() {
    data_store$harmonize_results <- NULL
    data_store$harmonize_audit <- NULL
    data_store$toxval_output <- NULL
  }

  # Show tabs when data is available
  shiny::observe({
    shiny::req(data_store$clean)
    show_tab_with_pulse("detection_info")
    show_tab_with_pulse("raw_data")
    show_tab_with_pulse("tag_columns")
  })

  # Show Clean Data tab after tagging
  shiny::observe({
    shiny::req(data_store$column_tags)
    show_tab_with_pulse("clean_data")
  })

  # Sidebar visibility based on active tab
  shiny::observeEvent(input$main_tabs, {
    curation_tabs <- c("clean_data", "tag_columns", "run_curation_tab", "review_results", "harmonize_tab")
    is_curation <- input$main_tabs %in% curation_tabs
    bslib::toggle_sidebar("main_sidebar", open = !is_curation, session = session)
  })

  # Phase 33: Independent cascade resets per D-09/D-10/D-11
  shiny::observeEvent(
    data_store$column_tags,
    {
      # Compare with previous state
      if (concert::detect_tag_changes(data_store$prev_chemical_tags, data_store$column_tags)) {
        reset_chemical_downstream()
      }
      data_store$prev_chemical_tags <- data_store$column_tags
    },
    ignoreNULL = FALSE
  )

  shiny::observeEvent(
    data_store$numeric_tags,
    {
      if (concert::detect_tag_changes(data_store$prev_numeric_tags, data_store$numeric_tags)) {
        reset_numeric_downstream()
      }
      data_store$prev_numeric_tags <- data_store$numeric_tags
    },
    ignoreNULL = FALSE
  )

  # Phase 36: Show Harmonize tab when numeric tags AND curation are complete
  shiny::observe({
    shiny::req(data_store$numeric_tags, data_store$resolution_state)
    show_tab_with_pulse("harmonize_tab")
  })

  # --- Initialize Modules ---
  upload_result <- concert::mod_file_upload_server("upload", data_store, reset_all_downstream)

  preview_rows <- upload_result$preview_rows
  concert::mod_data_preview_server("preview", data_store, preview_rows)
  concert::mod_detection_info_server("detection", data_store)
  concert::mod_raw_data_server("raw", data_store)

  concert::mod_clean_data_server("cleaning", data_store, on_cleaning_complete = function() {
    show_tab_with_pulse("run_curation_tab")
  })

  concert::mod_tag_columns_server("tags", data_store, on_tags_applied = function() {
    show_tab_with_pulse("clean_data")
    bslib::nav_hide("main_tabs", target = "run_curation_tab", session = session)
    bslib::nav_hide("main_tabs", target = "review_results", session = session)
  })

  concert::mod_run_curation_server("curation", data_store, on_curation_complete = function() {
    show_tab_with_pulse("review_results")

    # Auto-run post-curation QC
    qc_results <- concert::perform_unicode_qc(data_store$resolution_state)
    data_store$qc_results <- qc_results
    if (qc_results$rows_with_non_ascii > 0) {
      shiny::showNotification(
        sprintf("QC: %d rows contain non-ASCII characters", qc_results$rows_with_non_ascii),
        type = "warning",
        duration = 5
      )
    }
  })

  concert::mod_harmonize_server("harmonize", data_store)

  concert::mod_review_results_server("results", data_store)
}

# Run application
shiny::shinyApp(ui = ui, server = server)
