# Chem-Janitor Shiny Data Upload & Preview Application
# Upload CSV/XLSX files with intelligent frontmatter detection

# Load packages
{
  library(shiny)
  library(bslib)
  library(bsicons)
  library(DT)
  library(shinyjs)
  library(here)
  library(janitor)
  library(rio)
  library(readxl)
  library(writexl)
  library(readr)
  library(dplyr)
  library(tidyr)
  library(tibble)
  library(purrr)
  library(stringr)
  library(tidyselect)
  library(rlang)
  library(ComptoxR)
}

# Custom operators
`%ni%` <- Negate(`%in%`)
`%||%` <- function(a, b) {
  if (!is.null(a)) a else b
}

# Auto-source all R files recursively
for (f in list.files("R", recursive = TRUE, pattern = "\\.R$", full.names = TRUE)) {
  source(f)
}

# Application configuration
options(
  shiny.maxRequestSize = 50 * 1024^2 # 50MB upload limit
)


# UI Definition
ui <- page_sidebar(
  # Enable shinyjs
  shinyjs::useShinyjs(),

  # Tab pulse animation CSS
  tags$head(tags$style("
    @keyframes tab-pulse {
      0% { background-color: transparent; }
      50% { background-color: rgba(0, 123, 255, 0.15); }
      100% { background-color: transparent; }
    }
    .tab-pulse > .nav-link {
      animation: tab-pulse 0.5s ease-in-out 2;
    }
  ")),

  # Theme
  theme = bs_theme(
    version = 5,
    bootswatch = "flatly",
    primary = "#007bff"
  ),

  # Title
  title = "Chem-Janitor Data Upload & Preview",

  # Sidebar — delegated to upload module
  sidebar = sidebar(
    id = "main_sidebar",
    width = 300,
    mod_file_upload_ui("upload")
  ),

  # Main Content — module UIs in tabs
  navset_underline(
    id = "main_tabs",
    nav_panel("Data Preview", value = "data_preview",
      icon = bsicons::bs_icon("table"),
      mod_data_preview_ui("preview")
    ),
    nav_panel("Detection Info", value = "detection_info",
      icon = bsicons::bs_icon("search"),
      mod_detection_info_ui("detection")
    ),
    nav_panel("Raw Data", value = "raw_data",
      icon = bsicons::bs_icon("file-text"),
      mod_raw_data_ui("raw")
    ),
    nav_panel("Tag Columns", value = "tag_columns",
      icon = bsicons::bs_icon("tags"),
      mod_tag_columns_ui("tags")
    ),
    nav_panel("Run Curation", value = "run_curation_tab",
      icon = bsicons::bs_icon("play-circle"),
      mod_run_curation_ui("curation")
    ),
    nav_panel("Review Results", value = "review_results",
      icon = bsicons::bs_icon("clipboard-check"),
      mod_review_results_ui("results")
    )
  )
)

# Server Logic
server <- function(input, output, session) {
  # Create shared data store
  data_store <- reactiveValues(
    raw = NULL, clean = NULL, detection = NULL, file_info = NULL,
    selected_columns = NULL, column_tags = NULL,
    curation_results = NULL, curation_report = NULL, curation_status = NULL,
    dedup_preview = NULL, consensus_data = NULL, consensus_summary = NULL,
    resolution_state = NULL, dtxsid_cols = NULL, priority_order = NULL,
    error_filter_active = FALSE, display_row_map = NULL,
    selected_error_rows = NULL, manual_queue = list()
  )

  # --- Gated Navigation ---
  session$onFlushed(function() {
    nav_hide("main_tabs", target = "detection_info")
    nav_hide("main_tabs", target = "raw_data")
    nav_hide("main_tabs", target = "tag_columns")
    nav_hide("main_tabs", target = "run_curation_tab")
    nav_hide("main_tabs", target = "review_results")
  }, once = TRUE)

  show_tab_with_pulse <- function(tab_value) {
    nav_show("main_tabs", target = tab_value)
    shinyjs::runjs(sprintf("
      var tab = document.querySelector('[data-value=\"%s\"]');
      if (tab) {
        var li = tab.closest('li');
        if (li) {
          li.classList.add('tab-pulse');
          setTimeout(function() { li.classList.remove('tab-pulse'); }, 1200);
        }
      }
    ", tab_value))
  }

  reset_all_downstream <- function() {
    data_store$column_tags <- NULL
    data_store$curation_results <- NULL
    data_store$curation_report <- NULL
    data_store$curation_status <- NULL
    data_store$dedup_preview <- NULL
    data_store$consensus_data <- NULL
    data_store$consensus_summary <- NULL
    data_store$resolution_state <- NULL
    data_store$dtxsid_cols <- NULL
    data_store$priority_order <- NULL
    nav_hide("main_tabs", target = "detection_info")
    nav_hide("main_tabs", target = "raw_data")
    nav_hide("main_tabs", target = "tag_columns")
    nav_hide("main_tabs", target = "run_curation_tab")
    nav_hide("main_tabs", target = "review_results")
    nav_select("main_tabs", "data_preview")
  }

  # Show tabs when data is available
  observe({
    req(data_store$clean)
    show_tab_with_pulse("detection_info")
    show_tab_with_pulse("raw_data")
    show_tab_with_pulse("tag_columns")
  })

  # Sidebar visibility based on active tab
  observeEvent(input$main_tabs, {
    curation_tabs <- c("tag_columns", "run_curation_tab", "review_results")
    is_curation <- input$main_tabs %in% curation_tabs
    toggle_sidebar("main_sidebar", open = !is_curation)
  })

  # --- Initialize Modules ---
  upload_result <- mod_file_upload_server("upload", data_store, reset_all_downstream)

  preview_rows <- upload_result$preview_rows
  mod_data_preview_server("preview", data_store, preview_rows)
  mod_detection_info_server("detection", data_store)
  mod_raw_data_server("raw", data_store)

  mod_tag_columns_server("tags", data_store,
    on_tags_applied = function() {
      show_tab_with_pulse("run_curation_tab")
      nav_hide("main_tabs", target = "review_results")
    }
  )

  mod_run_curation_server("curation", data_store,
    on_curation_complete = function() {
      show_tab_with_pulse("review_results")
    }
  )

  mod_review_results_server("results", data_store)
}

# Run application
shinyApp(ui = ui, server = server)
