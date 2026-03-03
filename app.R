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

# Load helper functions
source(here::here("R", "file_handlers.R"))
source(here::here("R", "data_detection.R"))
source(here::here("R", "consensus.R"))
source(here::here("R", "curation.R"))

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

  # Resolution dropdown JavaScript
  tags$script(HTML("
    $(document).on('change', '.resolve-select', function() {
      var row = $(this).data('row');
      var column = $(this).val();
      if (column && column !== '') {
        Shiny.setInputValue('resolve_row_choice', {row: row, column: column}, {priority: 'event'});
      }
    });
  ")),

  # Theme
  theme = bs_theme(
    version = 5,
    bootswatch = "flatly",
    primary = "#007bff"
  ),

  # Title
  title = "Chem-Janitor Data Upload & Preview",

  # Sidebar
  sidebar = sidebar(
    id = "main_sidebar",
    width = 300,

    # File Upload Section
    card(
      card_header(
        class = "bg-primary text-white",
        "Upload Data"
      ),
      card_body(
        fileInput(
          "file_upload",
          "Choose CSV or XLSX File",
          accept = c(".csv", ".xlsx", ".xls"),
          buttonLabel = "Browse...",
          placeholder = "No file selected"
        ),
        uiOutput("file_info")
      )
    ),

    # Preview Settings Section
    card(
      card_header(
        class = "bg-info text-white",
        "Preview Settings"
      ),
      card_body(
        sliderInput(
          "preview_rows",
          "Rows to Preview:",
          min = 5,
          max = 100,
          value = 10,
          step = 5
        ),

        radioButtons(
          "detection_mode",
          "Header Detection:",
          choices = c(
            "Automatic" = "auto",
            "Manual" = "manual"
          ),
          selected = "auto"
        ),

        conditionalPanel(
          condition = "input.detection_mode == 'manual'",
          numericInput(
            "manual_header_row",
            "Header Row Number:",
            value = 1,
            min = 1,
            max = 100,
            step = 1
          )
        ),

        actionButton(
          "reset_btn",
          "Reset",
          class = "btn-secondary btn-sm w-100 mt-2"
        )
      )
    ),

    # Column Selection Section
    card(
      card_header(
        class = "bg-primary text-white",
        "Column Selection"
      ),
      card_body(
        conditionalPanel(
          condition = "output.has_data",

          checkboxGroupInput(
            "selected_columns",
            "Select Columns to Display:",
            choices = NULL,
            selected = NULL
          ),

          div(
            class = "d-flex gap-1 mb-2",
            actionButton("select_all_cols", "Select All", class = "btn-sm btn-outline-primary flex-fill"),
            actionButton("deselect_all_cols", "Deselect All", class = "btn-sm btn-outline-secondary flex-fill")
          )
        )
      )
    )
  ),

  # Main Content — Full-width tabs (no card wrapper)
  navset_underline(
    id = "main_tabs",

    # Data Preview Tab
    nav_panel(
      "Data Preview",
      value = "data_preview",
      icon = bsicons::bs_icon("table"),

      # Summary cards
      uiOutput("summary_cards"),

      # Data table (full width, no card wrapper)
      div(
        class = "mt-3",
        DTOutput("data_table")
      )
    ),

    # Detection Info Tab (hidden on startup, shown after upload)
    nav_panel(
      "Detection Info",
      value = "detection_info",
      icon = bsicons::bs_icon("search"),

      uiOutput("detection_details")
    ),

    # Raw Data Tab (hidden on startup, shown after upload)
    nav_panel(
      "Raw Data",
      value = "raw_data",
      icon = bsicons::bs_icon("file-text"),

      h4("Raw File Contents (First 20 Rows)"),
      div(
        class = "mt-3",
        DTOutput("raw_table")
      )
    ),

    # Tag Columns Tab (hidden on startup, shown after upload+detection)
    nav_panel(
      "Tag Columns",
      value = "tag_columns",
      icon = bsicons::bs_icon("tags"),

      # Empty state when no data uploaded
      conditionalPanel(
        condition = "!output.has_data",
        div(
          class = "text-center text-muted py-5",
          bsicons::bs_icon("upload", size = "3em"),
          h4("Upload a file to start tagging columns"),
          p("Upload a CSV or XLSX file using the sidebar.")
        )
      ),

      # Tagging interface when data exists
      conditionalPanel(
        condition = "output.has_data",

        # Header with Apply Tags button top-right
        div(
          class = "d-flex justify-content-between align-items-center mb-3",
          h4("Tag Columns"),
          actionButton(
            "apply_tags",
            "Apply Tags",
            class = "btn-primary",
            icon = icon("tag")
          )
        ),
        p("Categorize selected columns for chemical curation."),
        uiOutput("column_tagging_ui")
      )
    ),

    # Run Curation Tab (hidden on startup, shown after tags applied)
    nav_panel(
      "Run Curation",
      value = "run_curation_tab",
      icon = bsicons::bs_icon("play-circle"),

      # Content when tags are applied
      conditionalPanel(
        condition = "output.tags_applied",

        div(
          class = "alert alert-info",
          uiOutput("curation_summary")
        ),

        shinyjs::disabled(
          actionButton(
            "run_curation",
            "Start Curation",
            class = "btn-success btn-lg mt-3",
            icon = icon("play")
          )
        ),

        uiOutput("curation_progress")
      ),

      # Empty state when tags not applied
      conditionalPanel(
        condition = "!output.tags_applied",
        div(
          class = "text-center text-muted py-5",
          bsicons::bs_icon("tags", size = "3em"),
          h4("No columns tagged yet"),
          p("Go to the Tag Columns tab and assign column types first.")
        )
      )
    ),

    # Review Results Tab (hidden on startup, shown after curation complete)
    nav_panel(
      "Review Results",
      value = "review_results",
      icon = bsicons::bs_icon("clipboard-check"),

      # Content when curation completed
      conditionalPanel(
        condition = "output.curation_completed",

        # Statistics value boxes at top
        uiOutput("curation_stats"),

        # En masse priority controls
        div(
          class = "card mb-3",
          div(class = "card-header", "Column Priority (En Masse Resolution)"),
          div(
            class = "card-body",
            uiOutput("priority_controls"),
            actionButton("apply_priority", "Apply Priority", class = "btn-warning btn-sm mt-2")
          )
        ),

        # Header with Download button top-right and action buttons
        div(
          class = "d-flex justify-content-between align-items-center mb-3 mt-3",
          h4("Curated Results"),
          div(
            class = "d-flex gap-2",
            actionButton(
              "filter_errors",
              "Show Errors",
              icon = icon("filter"),
              class = "btn-sm btn-outline-secondary"
            ),
            shinyjs::hidden(
              actionButton(
                "retag_selected",
                "Re-tag Selected",
                icon = icon("tags"),
                class = "btn-sm btn-warning"
              )
            ),
            shinyjs::hidden(
              actionButton(
                "validate_all",
                "Validate All",
                icon = icon("check"),
                class = "btn-sm btn-success"
              )
            ),
            downloadButton(
              "download_curated",
              "Download Excel",
              class = "btn-primary"
            )
          )
        ),

        DTOutput("curation_table")
      ),

      # Empty state when curation not completed
      conditionalPanel(
        condition = "!output.curation_completed",
        div(
          class = "text-center text-muted py-5",
          bsicons::bs_icon("hourglass-split", size = "3em"),
          h4("No results yet"),
          p("Run curation first to see results here.")
        )
      )
    )
  )
)


# Server Logic
server <- function(input, output, session) {
  # Reactive values store
  data_store <- reactiveValues(
    raw = NULL,
    clean = NULL,
    detection = NULL,
    file_info = NULL,
    # Column selection and tagging
    selected_columns = NULL,
    column_tags = NULL,
    # Curation results
    curation_results = NULL,
    curation_report = NULL,
    curation_status = NULL,
    # New pipeline fields
    dedup_preview = NULL,
    consensus_data = NULL,
    consensus_summary = NULL,
    resolution_state = NULL,
    dtxsid_cols = NULL,
    priority_order = NULL,
    # Error recovery fields
    error_filter_active = FALSE,
    display_row_map = NULL,
    selected_error_rows = NULL,
    manual_queue = list()  # row_idx (string) -> dtxsid (string)
  )

  # --- Gated Navigation: Hide tabs on startup ---
  session$onFlushed(function() {
    nav_hide("main_tabs", target = "detection_info")
    nav_hide("main_tabs", target = "raw_data")
    nav_hide("main_tabs", target = "tag_columns")
    nav_hide("main_tabs", target = "run_curation_tab")
    nav_hide("main_tabs", target = "review_results")
  }, once = TRUE)

  # --- Gated Navigation Helpers ---

  # Show a tab with a brief pulse animation to draw attention
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

  # Full downstream reset: clear state, hide tabs, return to Data Preview
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

  # --- Gated Navigation: Show tabs when prerequisites met ---

  # After successful upload+detection: show Detection Info, Raw Data, Tag Columns
  observe({
    req(data_store$clean)
    show_tab_with_pulse("detection_info")
    show_tab_with_pulse("raw_data")
    show_tab_with_pulse("tag_columns")
  })

  # Sidebar visibility based on active tab ----
  # Hide sidebar on curation tabs, show on upload/detection tabs
  observeEvent(input$main_tabs, {
    curation_tabs <- c("tag_columns", "run_curation_tab", "review_results")
    is_curation <- input$main_tabs %in% curation_tabs
    toggle_sidebar("main_sidebar", open = !is_curation)
  })

  # Enable/disable Start Curation button based on prerequisites ----
  observe({
    has_tags <- !is.null(data_store$column_tags) && length(data_store$column_tags) > 0
    has_api_key <- Sys.getenv("ctx_api_key") != ""

    if (has_tags && has_api_key) {
      shinyjs::enable("run_curation")
    } else {
      shinyjs::disable("run_curation")
    }
  })

  # --- File Upload Processing (extracted for re-use by modal confirm) ---

  process_uploaded_file <- function(file_info) {
    # Validate file
    validation <- validate_file(file_info)

    if (!validation$success) {
      showNotification(
        validation$message,
        type = "error",
        duration = 10
      )
      return(NULL)
    }

    # Show processing notification
    notification_id <- showNotification(
      "Processing file...",
      type = "message",
      duration = NULL
    )

    tryCatch(
      {
        # Read file
        file_ext <- tools::file_ext(file_info$name)
        raw_df <- safely_read_file(file_info$datapath, file_ext)

        # Validate raw data
        if (is.null(raw_df) || nrow(raw_df) == 0 || ncol(raw_df) == 0) {
          stop("File appears to be empty or unreadable")
        }

        # Debug: Log raw data dimensions
        message("Raw data dimensions: ", nrow(raw_df), " rows x ", ncol(raw_df), " cols")

        # Detect frontmatter
        detection <- detect_data_start(
          raw_df,
          mode = input$detection_mode,
          manual_row = if (input$detection_mode == "manual") input$manual_header_row else NULL
        )

        # Debug: Log detection results
        message(
          "Detection: method=",
          detection$method,
          ", confidence=",
          detection$confidence,
          ", header_row=",
          detection$header_row,
          ", data_start=",
          detection$data_start_row
        )

        # Extract clean data
        clean_df <- extract_clean_data(raw_df, detection)

        # Debug: Log after extraction
        message("After extraction: ", nrow(clean_df), " rows x ", ncol(clean_df), " cols")

        # Handle merged cells
        clean_df <- handle_merged_cells(clean_df)

        # Apply janitor cleaning
        clean_df <- clean_df %>%
          janitor::clean_names() %>%
          janitor::remove_empty(which = c("rows", "cols"))

        # Validate cleaned data
        if (nrow(clean_df) == 0) {
          showNotification(
            paste0(
              "Warning: No data rows found after cleaning. ",
              "Try adjusting detection settings or using Manual mode."
            ),
            type = "warning",
            duration = 10
          )
        }

        if (ncol(clean_df) == 0) {
          stop("No columns found after cleaning. File may not contain valid tabular data.")
        }

        # Store results
        data_store$raw <- raw_df
        data_store$clean <- clean_df
        data_store$detection <- detection
        data_store$file_info <- file_info

        # Calculate smart preview rows
        suggested_rows <- calculate_smart_preview_rows(clean_df)
        updateSliderInput(session, "preview_rows", value = suggested_rows)

        # Remove processing notification
        removeNotification(notification_id)

        # Show success notification
        showNotification(
          paste0(
            "File uploaded successfully! ",
            "Detected ",
            nrow(clean_df),
            " rows and ",
            ncol(clean_df),
            " columns."
          ),
          type = "message",
          duration = 5
        )
      },
      error = function(e) {
        # Remove processing notification
        removeNotification(notification_id)

        # Provide more detailed error information
        error_details <- conditionMessage(e)

        # Show error notification with more context
        showNotification(
          div(
            tags$strong("Error processing file:"),
            tags$br(),
            error_details,
            tags$br(),
            tags$br(),
            tags$em("Check the R console for detailed debug messages.")
          ),
          type = "error",
          duration = NULL # Keep error visible until dismissed
        )

        # Log full error to console for debugging
        message("\n=== FILE UPLOAD ERROR ===")
        message("File: ", file_info$name)
        message("Error: ", error_details)
        message("Stack trace:")
        print(e)
        message("=========================\n")

        # Reset data store
        data_store$raw <- NULL
        data_store$clean <- NULL
        data_store$detection <- NULL
        data_store$file_info <- NULL
      }
    )
  }

  # File upload handler — with confirmation modal for re-uploads
  observeEvent(input$file_upload, {
    req(input$file_upload)

    if (!is.null(data_store$clean)) {
      # Re-upload: data already exists — show confirmation modal
      showModal(modalDialog(
        title = "Replace Current Data?",
        p("Your column tags and curation results will be cleared."),
        p("This action cannot be undone."),
        footer = tagList(
          actionButton("cancel_reupload", "Cancel", class = "btn-secondary"),
          actionButton("confirm_reupload", "Replace Data", class = "btn-danger")
        ),
        easyClose = FALSE
      ))
    } else {
      # First upload — process directly
      process_uploaded_file(input$file_upload)
    }
  })

  # Re-upload modal: Cancel — dismiss modal, reset file input to previous state
  observeEvent(input$cancel_reupload, {
    removeModal()
    shinyjs::reset("file_upload")
  })

  # Re-upload modal: Confirm — reset all downstream state, process new file
  observeEvent(input$confirm_reupload, {
    removeModal()
    # Full reset of downstream state and tabs
    reset_all_downstream()
    # Clear core data (reset_all_downstream doesn't clear raw/clean/detection)
    data_store$raw <- NULL
    data_store$clean <- NULL
    data_store$detection <- NULL
    data_store$file_info <- NULL
    # Process the new file
    process_uploaded_file(input$file_upload)
  })

  # Update detection when mode or manual row changes
  observeEvent(c(input$detection_mode, input$manual_header_row), {
    req(data_store$raw)

    tryCatch(
      {
        # Re-run detection
        detection <- detect_data_start(
          data_store$raw,
          mode = input$detection_mode,
          manual_row = if (input$detection_mode == "manual") input$manual_header_row else NULL
        )

        # Re-extract clean data
        clean_df <- extract_clean_data(data_store$raw, detection)
        clean_df <- handle_merged_cells(clean_df)
        clean_df <- clean_df %>%
          janitor::clean_names() %>%
          janitor::remove_empty(which = c("rows", "cols"))

        # Validate cleaned data
        if (nrow(clean_df) == 0) {
          showNotification(
            paste0(
              "Warning: No data rows found with current settings. ",
              "Try a different header row or detection mode."
            ),
            type = "warning",
            duration = 8
          )
        }

        if (ncol(clean_df) == 0) {
          showNotification(
            "Warning: No columns found after cleaning.",
            type = "warning",
            duration = 8
          )
          return()
        }

        # Update stored data
        data_store$clean <- clean_df
        data_store$detection <- detection
      },
      error = function(e) {
        showNotification(
          paste("Error updating detection:", e$message),
          type = "warning",
          duration = 5
        )
      }
    )
  })

  # Output: File info
  output$file_info <- renderUI({
    req(data_store$file_info)

    tagList(
      tags$hr(),
      tags$div(
        class = "small text-muted",
        tags$div(
          bsicons::bs_icon("file-earmark"),
          tags$strong("File:"),
          tags$br(),
          tags$span(class = "text-break", data_store$file_info$name)
        ),
        tags$div(
          class = "mt-2",
          bsicons::bs_icon("hdd"),
          tags$strong("Size:"),
          format_file_size(data_store$file_info$size)
        )
      )
    )
  })

  # Output: Summary cards
  output$summary_cards <- renderUI({
    req(data_store$clean)
    df <- data_store$clean

    # Calculate statistics
    total_rows <- nrow(df)
    total_cols <- ncol(df)
    selected_cols <- ncol(filtered_data())
    missing_pct <- round(sum(is.na(df)) / (total_rows * total_cols) * 100, 1)
    detection_conf <- round(data_store$detection$confidence * 100, 0)

    layout_columns(
      col_widths = c(3, 3, 3, 3),
      value_box(
        title = "Total Rows",
        value = format(total_rows, big.mark = ","),
        showcase = bsicons::bs_icon("table"),
        theme = "primary"
      ),
      value_box(
        title = "Columns (Selected/Total)",
        value = paste0(selected_cols, " / ", total_cols),
        showcase = bsicons::bs_icon("grid-3x3"),
        theme = "info"
      ),
      value_box(
        title = "Missing Values",
        value = paste0(missing_pct, "%"),
        showcase = bsicons::bs_icon("question-circle"),
        theme = if (missing_pct > 10) "warning" else "success"
      ),
      value_box(
        title = "Detection Confidence",
        value = paste0(detection_conf, "%"),
        showcase = bsicons::bs_icon("bullseye"),
        theme = if (detection_conf >= 70) {
          "success"
        } else if (detection_conf >= 50) {
          "warning"
        } else {
          "danger"
        }
      )
    )
  })

  # Output: Data table
  output$data_table <- renderDT({
    req(data_store$clean)

    preview_data <- head(filtered_data(), input$preview_rows)

    # Validate data before rendering
    if (nrow(preview_data) == 0 || ncol(preview_data) == 0) {
      # Return empty table with message
      return(datatable(
        data.frame(Message = "No data available after cleaning"),
        options = list(dom = 't'),
        rownames = FALSE
      ))
    }

    datatable(
      preview_data,
      options = list(
        pageLength = min(25, nrow(preview_data)),
        scrollX = TRUE,
        scrollY = "500px",
        fixedHeader = TRUE,
        dom = 'Bfrtip',
        buttons = c('copy', 'csv', 'excel'),
        columnDefs = list(
          list(className = 'dt-center', targets = '_all')
        )
      ),
      extensions = c('Buttons', 'FixedHeader'),
      class = 'cell-border stripe hover',
      rownames = FALSE,
      filter = if (nrow(preview_data) > 0) 'top' else 'none'
    ) %>%
      formatStyle(
        columns = names(preview_data),
        backgroundColor = styleEqual(c(NA_character_), c('#f9f9f9'))
      )
  })

  # Output: Detection details
  output$detection_details <- renderUI({
    req(data_store$detection)
    det <- data_store$detection

    # Create method badge
    method_badge <- if (det$method == "manual") {
      tags$span(class = "badge bg-primary", "Manual")
    } else if (det$confidence >= 0.7) {
      tags$span(class = "badge bg-success", toupper(det$method))
    } else if (det$confidence >= 0.5) {
      tags$span(class = "badge bg-warning", toupper(det$method))
    } else {
      tags$span(class = "badge bg-danger", toupper(det$method))
    }

    # Create confidence progress bar
    confidence_pct <- round(det$confidence * 100, 0)
    confidence_color <- if (confidence_pct >= 70) {
      "success"
    } else if (confidence_pct >= 50) {
      "warning"
    } else {
      "danger"
    }

    tagList(
      # Main detection card
      card(
        card_header("Detection Summary"),
        card_body(
          layout_columns(
            col_widths = c(6, 6),

            # Left column
            tags$div(
              tags$dl(
                tags$dt("Method Used:"),
                tags$dd(method_badge),

                tags$dt(class = "mt-3", "Confidence Score:"),
                tags$dd(
                  paste0(confidence_pct, "%"),
                  tags$div(
                    class = "progress mt-1",
                    style = "height: 20px;",
                    tags$div(
                      class = paste0("progress-bar bg-", confidence_color),
                      role = "progressbar",
                      style = paste0("width: ", confidence_pct, "%"),
                      `aria-valuenow` = confidence_pct,
                      `aria-valuemin` = "0",
                      `aria-valuemax` = "100"
                    )
                  )
                )
              )
            ),

            # Right column
            tags$div(
              tags$dl(
                tags$dt("Header Row:"),
                tags$dd(
                  tags$span(class = "badge bg-info", det$header_row)
                ),

                tags$dt(class = "mt-3", "Data Start Row:"),
                tags$dd(
                  tags$span(class = "badge bg-info", det$data_start_row)
                ),

                tags$dt(class = "mt-3", "Metadata Rows:"),
                tags$dd(
                  if (length(det$metadata_rows) > 0) {
                    tags$span(class = "badge bg-secondary", length(det$metadata_rows))
                  } else {
                    tags$span(class = "text-muted", "None")
                  }
                )
              )
            )
          )
        )
      ),

      # Metadata preview card (if metadata exists)
      if (length(det$metadata_rows) > 0 && !is.null(data_store$raw)) {
        card(
          card_header("Detected Metadata (Ignored Rows)"),
          card_body(
            renderTable(
              {
                metadata_df <- data_store$raw[det$metadata_rows, , drop = FALSE]
                metadata_df
              },
              rownames = TRUE,
              colnames = FALSE
            )
          )
        )
      },

      # All methods comparison (if multiple methods were tried)
      if (!is.null(det$all_results) && length(det$all_results) > 1) {
        card(
          card_header("Detection Methods Comparison"),
          card_body(
            renderTable(
              {
                comparison_df <- purrr::map_dfr(det$all_results, function(result) {
                  tibble::tibble(
                    Method = toupper(result$method),
                    `Header Row` = result$header_row,
                    `Data Start` = result$data_start_row,
                    Confidence = paste0(round(result$confidence * 100, 0), "%")
                  )
                })
                comparison_df
              }
            )
          )
        )
      }
    )
  })

  # Output: Raw table
  output$raw_table <- renderDT({
    req(data_store$raw)

    raw_preview <- head(data_store$raw, 20)

    datatable(
      raw_preview,
      options = list(
        pageLength = 20,
        scrollX = TRUE,
        scrollY = "500px",
        dom = 't'
      ),
      class = 'cell-border stripe compact',
      rownames = TRUE
    )
  })

  # Reset button handler
  observeEvent(input$reset_btn, {
    # Clear data store
    data_store$raw <- NULL
    data_store$clean <- NULL
    data_store$detection <- NULL
    data_store$file_info <- NULL

    # Hide all downstream tabs and clear downstream state
    reset_all_downstream()

    # Reset file input (using JavaScript)
    shinyjs::reset("file_upload")

    # Reset settings to defaults
    updateSliderInput(session, "preview_rows", value = 10)
    updateRadioButtons(session, "detection_mode", selected = "auto")

    showNotification(
      "Reset successful. Ready for new file.",
      type = "message",
      duration = 3
    )
  })

  # Column Selection Logic ----

  # Update checkbox choices when data loads
  observe({
    req(data_store$clean)
    choices <- names(data_store$clean)

    updateCheckboxGroupInput(
      session,
      "selected_columns",
      choices = choices,
      selected = choices # All selected by default
    )

    # Store in reactive store
    data_store$selected_columns <- choices
  })

  # Update selected columns when user changes selection
  observeEvent(input$selected_columns, {
    data_store$selected_columns <- input$selected_columns
  })

  # Select all button
  observeEvent(input$select_all_cols, {
    req(data_store$clean)
    updateCheckboxGroupInput(session, "selected_columns", selected = names(data_store$clean))
  })

  # Deselect all button
  observeEvent(input$deselect_all_cols, {
    updateCheckboxGroupInput(session, "selected_columns", selected = character(0))
  })

  # Filtered data based on column selection
  filtered_data <- reactive({
    req(data_store$clean)
    selected <- data_store$selected_columns

    if (is.null(selected) || length(selected) == 0) {
      return(data_store$clean) # Show all if none selected
    }

    data_store$clean %>% select(all_of(selected))
  })

  # has_data output for conditionalPanel
  output$has_data <- reactive({
    !is.null(data_store$clean)
  })
  outputOptions(output, "has_data", suspendWhenHidden = FALSE)

  # Column Tagging Logic ----

  # Dynamic UI for column tagging — table-based layout
  output$column_tagging_ui <- renderUI({
    req(data_store$selected_columns)

    selected_cols <- data_store$selected_columns

    if (length(selected_cols) == 0) {
      return(div(class = "alert alert-warning", "No columns selected. Please select columns in the sidebar."))
    }

    # Table-based layout: one row per column
    tags$table(
      class = "table table-striped table-hover",
      tags$thead(
        tags$tr(
          tags$th("Column Name"),
          tags$th("Type", style = "width: 200px;")
        )
      ),
      tags$tbody(
        lapply(selected_cols, function(col) {
          tags$tr(
            tags$td(tags$strong(col)),
            tags$td(
              selectInput(
                inputId = paste0("tag_", make.names(col)),
                label = NULL,
                choices = c(
                  "Select type..." = "",
                  "Chemical Name" = "Name",
                  "CASRN" = "CASRN",
                  "Other" = "Other"
                ),
                selected = "",
                selectize = FALSE,
                width = "100%"
              )
            )
          )
        })
      )
    )
  })

  # Apply tags button
  observeEvent(input$apply_tags, {
    req(data_store$selected_columns)

    tags <- list()
    for (col in data_store$selected_columns) {
      tag_input_id <- paste0("tag_", make.names(col))
      tag_value <- input[[tag_input_id]]

      if (!is.null(tag_value) && tag_value != "") {
        tags[[col]] <- tag_value
      }
    }

    if (length(tags) == 0) {
      showNotification(
        "Please select at least one column type before applying tags.",
        type = "warning",
        duration = 5
      )
      return()
    }

    data_store$column_tags <- tags

    # Generate dedup preview immediately
    tryCatch(
      {
        data_store$dedup_preview <- get_dedup_preview(data_store$clean, tags)
      },
      error = function(e) {
        message("Dedup preview generation failed: ", e$message)
        data_store$dedup_preview <- NULL
      }
    )

    # Cascade: hide downstream tabs and clear curation state (re-apply invalidates curation)
    nav_hide("main_tabs", target = "review_results")
    data_store$curation_results <- NULL
    data_store$curation_report <- NULL
    data_store$curation_status <- NULL
    data_store$consensus_data <- NULL
    data_store$consensus_summary <- NULL
    data_store$resolution_state <- NULL
    data_store$dtxsid_cols <- NULL
    data_store$priority_order <- NULL

    # Show Run Curation tab with pulse
    show_tab_with_pulse("run_curation_tab")

    showNotification(
      paste("Tagged", length(tags), "column(s) successfully!"),
      type = "message",
      duration = 3
    )
  })

  # Tags applied indicator
  output$tags_applied <- reactive({
    !is.null(data_store$column_tags) && length(data_store$column_tags) > 0
  })
  outputOptions(output, "tags_applied", suspendWhenHidden = FALSE)

  # Curation summary
  output$curation_summary <- renderUI({
    req(data_store$column_tags)

    col_tags <- data_store$column_tags
    name_count <- sum(col_tags == "Name")
    cas_count <- sum(col_tags == "CASRN")
    other_count <- sum(col_tags == "Other")

    # API key check
    has_api_key <- Sys.getenv("ctx_api_key") != ""
    api_status <- if (has_api_key) {
      tags$span(class = "badge bg-success", "API Key Configured")
    } else {
      tags$span(class = "badge bg-danger", "API Key Missing")
    }

    tagList(
      p(strong("Tagged Columns:")),
      tags$ul(
        tags$li(paste(name_count, "Chemical Name column(s)")),
        tags$li(paste(cas_count, "CASRN column(s)")),
        if (other_count > 0) tags$li(paste(other_count, "Other column(s)"))
      ),

      # Dedup preview
      if (!is.null(data_store$dedup_preview)) {
        tagList(
          p(strong("Deduplication Preview:")),
          tags$ul(
            tags$li(paste(data_store$dedup_preview$n_names, "unique chemical names to look up")),
            tags$li(paste(data_store$dedup_preview$n_cas, "unique CAS numbers to validate"))
          )
        )
      },

      # API key status
      p(strong("API Status:"), " ", api_status)
    )
  })

  # Curation Execution Logic ----

  # Run curation button
  observeEvent(input$run_curation, {
    req(data_store$clean, data_store$column_tags)

    # Check for ComptoxR API key
    if (Sys.getenv("ctx_api_key") == "") {
      showNotification(
        "ComptoxR API key not set. Please set 'ctx_api_key' environment variable and restart R session.",
        type = "error",
        duration = NULL
      )
      return()
    }

    # Check if there are Name or CASRN columns tagged
    has_name <- any(data_store$column_tags == "Name")
    has_cas <- any(data_store$column_tags == "CASRN")

    if (!has_name && !has_cas) {
      showNotification(
        "Please tag at least one column as 'Chemical Name' or 'CASRN' before running curation.",
        type = "warning",
        duration = 5
      )
      return()
    }

    # Disable the button during execution
    shinyjs::disable("run_curation")
    data_store$curation_status <- "in_progress"

    # Run curation with progress tracking via withProgress
    tryCatch(
      {
        withProgress(message = "Running curation pipeline...", value = 0, {
          # Progress callback to update both withProgress and status field
          progress_callback <- function(stage, msg) {
            data_store$curation_status <- msg
            incProgress(0.2, detail = msg)
          }

          # Run the new pipeline
          pipeline_result <- run_curation_pipeline(
            clean_data = data_store$clean,
            column_tags = data_store$column_tags,
            progress_callback = progress_callback,
            dedup_only = FALSE
          )

          # Store results
          data_store$consensus_data <- pipeline_result$results
          data_store$consensus_summary <- pipeline_result$consensus_summary
          data_store$resolution_state <- pipeline_result$results
          data_store$dtxsid_cols <- find_dtxsid_cols(pipeline_result$results)
          data_store$priority_order <- data_store$dtxsid_cols

          # Store in curation_results for backward compatibility with Review tab
          data_store$curation_results <- pipeline_result$results

          # Generate backward-compatible report from new summaries
          data_store$curation_report <- list(
            total_rows = nrow(pipeline_result$results),
            cas_columns = sum(data_store$column_tags == "CASRN"),
            name_columns = sum(data_store$column_tags == "Name"),
            cas_validated = pipeline_result$search_summary$n_cas_valid,
            cas_invalid = pipeline_result$dedup_summary$n_cas - pipeline_result$search_summary$n_cas_valid,
            names_exact_match = pipeline_result$search_summary$n_exact,
            names_fuzzy_match = pipeline_result$search_summary$n_starts_with,
            names_no_match = pipeline_result$search_summary$n_miss
          )

          data_store$curation_status <- "completed"

          # Show tier breakdown notification
          notification_msg <- sprintf(
            "Search complete: %d exact, %d CAS, %d starts-with, %d no match",
            pipeline_result$search_summary$n_exact,
            pipeline_result$search_summary$n_cas_valid,
            pipeline_result$search_summary$n_starts_with,
            pipeline_result$search_summary$n_miss
          )

          showNotification(
            notification_msg,
            type = "message",
            duration = 8
          )

          # Show Review Results tab and auto-navigate to it
          nav_show("main_tabs", target = "review_results")
          nav_select("main_tabs", "review_results")
        })
      },
      error = function(e) {
        showNotification(
          paste("Curation failed:", e$message),
          type = "error",
          duration = NULL
        )
        data_store$curation_status <- "failed"
      },
      finally = {
        # Re-enable button
        shinyjs::enable("run_curation")
      }
    )
  })

  # Curation completed indicator
  output$curation_completed <- reactive({
    !is.null(data_store$curation_status) && data_store$curation_status == "completed"
  })
  outputOptions(output, "curation_completed", suspendWhenHidden = FALSE)

  # Curation progress display
  output$curation_progress <- renderUI({
    status <- data_store$curation_status

    if (is.null(status) || status == "") {
      return(NULL)
    }

    if (status == "in_progress") {
      tagList(
        div(
          class = "mt-3 text-muted small",
          tags$span(class = "spinner-border spinner-border-sm me-2", role = "status"),
          tags$span(status)
        )
      )
    } else if (status == "completed") {
      div(
        class = "mt-3 alert alert-success small",
        bsicons::bs_icon("check-circle"),
        " Pipeline completed successfully!"
      )
    } else if (status == "failed") {
      div(
        class = "mt-3 alert alert-danger small",
        bsicons::bs_icon("exclamation-triangle"),
        " Pipeline failed. Check notifications for details."
      )
    } else {
      # Show progress message
      div(
        class = "mt-3 text-muted small",
        tags$span(class = "spinner-border spinner-border-sm me-2", role = "status"),
        tags$span(status)
      )
    }
  })

  # Curation statistics
  output$curation_stats <- renderUI({
    req(data_store$consensus_summary, data_store$resolution_state)

    summary <- data_store$consensus_summary

    # Calculate match rate from resolution_state
    total_rows <- nrow(data_store$resolution_state)
    matched_rows <- sum(!is.na(data_store$resolution_state$consensus_dtxsid))
    match_rate <- round((matched_rows / total_rows) * 100, 1)

    # Needs Review = agree_caveat + single
    needs_review <- summary$n_agree_caveat + summary$n_single

    layout_columns(
      col_widths = c(3, 3, 3, 3),
      value_box(
        title = "Agree",
        value = summary$n_agree,
        showcase = bsicons::bs_icon("check-circle-fill"),
        theme = "success"
      ),
      value_box(
        title = "Disagree",
        value = summary$n_disagree,
        showcase = bsicons::bs_icon("x-circle-fill"),
        theme = "danger"
      ),
      value_box(
        title = "Needs Review",
        value = needs_review,
        showcase = bsicons::bs_icon("exclamation-triangle-fill"),
        theme = "warning"
      ),
      value_box(
        title = "Match Rate",
        value = paste0(match_rate, "%"),
        showcase = bsicons::bs_icon("percent"),
        theme = "info"
      )
    )
  })

  # Curation results table
  output$curation_table <- renderDT(server = FALSE, {
    req(data_store$resolution_state, data_store$dtxsid_cols)

    df <- data_store$resolution_state
    dtxsid_cols <- data_store$dtxsid_cols

    # Ensure consensus_status is a factor with ordered levels (enables dropdown filter)
    df$consensus_status <- factor(
      df$consensus_status,
      levels = c("agree", "agree_caveat", "single", "disagree", "error", "manual", "unresolvable")
    )

    # Derive Match Type from source_tier columns
    # Per user decision: show tier only, not which tagged column produced the match
    tier_label_map <- c(
      "exact" = "Exact Match",
      "cas" = "CAS Lookup",
      "starts_with" = "Starts-With",
      "miss" = "No Match",
      "cas_no_match" = "No Match",
      "cas_invalid" = "No Match"
    )

    df$match_type <- sapply(seq_len(nrow(df)), function(i) {
      # Strategy: find the source_tier of the column that provided consensus_dtxsid
      tier_cols <- grep("^source_tier_", names(df), value = TRUE)

      if (length(tier_cols) == 0) return("Unknown")

      # If consensus_dtxsid exists, find which column provided it
      if (!is.na(df$consensus_dtxsid[i])) {
        # Check each source_tier column for a successful match
        for (tc in tier_cols) {
          tier_val <- df[[tc]][i]
          if (!is.na(tier_val) && tier_val %in% c("exact", "cas", "starts_with")) {
            label <- tier_label_map[tier_val]
            if (!is.na(label)) return(label)
          }
        }
      }

      # No consensus_dtxsid: check if all tiers are miss/error
      all_tiers <- sapply(tier_cols, function(tc) df[[tc]][i])
      all_tiers <- all_tiers[!is.na(all_tiers)]

      if (length(all_tiers) == 0) return("No Match")

      # Pick first non-miss tier if any
      for (tv in all_tiers) {
        if (tv %in% c("exact", "cas", "starts_with")) {
          return(tier_label_map[tv])
        }
      }

      return("No Match")
    })

    # Convert match_type to factor for dropdown filter
    df$match_type <- factor(df$match_type, levels = c("Exact Match", "CAS Lookup", "Starts-With", "No Match"))

    # Position match_type after consensus columns but before Resolution
    df <- dplyr::relocate(df, match_type, .after = consensus_status)

    # Build Resolution column with enhanced context
    df$Resolution <- sapply(seq_len(nrow(df)), function(i) {
      status <- as.character(df$consensus_status[i])

      if (status %in% c("agree", "agree_caveat", "single")) {
        # Static display with checkmark for rows that have a DTXSID
        dtxsid <- df$consensus_dtxsid[i]
        if (!is.na(dtxsid)) {
          # Find preferredName from any available column
          pref_cols <- grep("^preferredName_", names(df), value = TRUE)
          pref_name <- NA_character_
          for (pc in pref_cols) {
            if (!is.na(df[[pc]][i])) { pref_name <- df[[pc]][i]; break }
          }
          if (!is.na(pref_name)) {
            paste0("\u2705 ", htmltools::htmlEscape(dtxsid), " \u2014 ", htmltools::htmlEscape(pref_name))
          } else {
            paste0("\u2705 ", htmltools::htmlEscape(dtxsid))
          }
        } else {
          ""
        }
      } else if (status == "disagree") {
        if (isTRUE(df$.pinned[i])) {
          # Pinned: show pin icon with resolved value and name
          dtxsid <- df$consensus_dtxsid[i]
          if (!is.na(dtxsid)) {
            pref_cols <- grep("^preferredName_", names(df), value = TRUE)
            pref_name <- NA_character_
            for (pc in pref_cols) {
              if (!is.na(df[[pc]][i])) { pref_name <- df[[pc]][i]; break }
            }
            if (!is.na(pref_name)) {
              paste0("\U0001F4CC ", htmltools::htmlEscape(dtxsid), " \u2014 ", htmltools::htmlEscape(pref_name))
            } else {
              paste0("\U0001F4CC ", htmltools::htmlEscape(dtxsid))
            }
          } else {
            paste0("\U0001F4CC (None selected)")
          }
        } else {
          # Unpinned disagree: dropdown with enhanced options
          options <- get_resolution_options(df, i, dtxsid_cols)
          if (length(options) > 0) {
            # Options already sorted by rank from get_resolution_options
            options_html <- paste0(
              sapply(names(options), function(col) {
                opt <- options[[col]]
                label <- if (!is.na(opt$preferredName)) {
                  paste0(htmltools::htmlEscape(opt$dtxsid), " \u2014 ", htmltools::htmlEscape(opt$preferredName))
                } else {
                  htmltools::htmlEscape(opt$dtxsid)
                }
                paste0('<option value="', htmltools::htmlEscape(col), '">', label, '</option>')
              }),
              collapse = ""
            )
            paste0(
              '<select class="resolve-select form-select form-select-sm" data-row="', i, '">',
              '<option value="">Select...</option>',
              options_html,
              '<option value="__none__">None (skip this row)</option>',
              '</select>'
            )
          } else {
            ""
          }
        }
      } else if (status == "manual") {
        # Manual entry: show checkmark + DTXSID + preferredName + manual badge
        dtxsid <- df$consensus_dtxsid[i]
        pref_name <- if ("manual_preferredName" %in% names(df)) df$manual_preferredName[i] else NA_character_
        # Fall back to auto preferredName columns if manual not available
        if (is.na(pref_name)) {
          pref_cols <- grep("^preferredName_", names(df), value = TRUE)
          for (pc in pref_cols) {
            if (!is.na(df[[pc]][i])) { pref_name <- df[[pc]][i]; break }
          }
        }
        manual_badge <- '<span class="badge bg-info ms-1" style="font-size:0.7em;">manual</span>'
        if (!is.na(dtxsid) && !is.na(pref_name)) {
          paste0("\u2705 ", htmltools::htmlEscape(dtxsid), " \u2014 ", htmltools::htmlEscape(pref_name), " ", manual_badge)
        } else if (!is.na(dtxsid)) {
          paste0("\u2705 ", htmltools::htmlEscape(dtxsid), " ", manual_badge)
        } else {
          ""
        }
      } else if (status == "unresolvable") {
        # Unresolvable: show warning icon
        "\u26A0\uFE0F Auto-curation failed"
      } else if (status == "error") {
        ""
      } else {
        # other status
        ""
      }
    })

    # Apply error filter if active
    display_indices <- seq_len(nrow(df))
    if (isTRUE(data_store$error_filter_active)) {
      display_indices <- which(df$consensus_status %in% c("error", "unresolvable"))
      df_display <- df[display_indices, , drop = FALSE]
    } else {
      df_display <- df
    }
    # Store mapping for row selection (filtered row -> original row)
    data_store$display_row_map <- display_indices

    # --- Three-tier column visibility ---

    # Tier 1: Always hidden (permanently, excluded from colvis menu)
    always_hidden <- c(
      dtxsid_cols,
      grep("^preferredName_", names(df), value = TRUE),
      grep("^searchName_", names(df), value = TRUE),
      grep("^rank_", names(df), value = TRUE),
      grep("^source_tier_", names(df), value = TRUE),
      ".pinned",
      ".manual_entry",
      "manual_preferredName"
    )
    always_hidden_idx <- which(names(df) %in% always_hidden) - 1

    # Tier 2: Hidden by default, toggleable via colvis (untagged original columns)
    tagged_col_names <- names(data_store$column_tags)
    all_original_cols <- names(data_store$clean)
    untagged_cols <- setdiff(
      all_original_cols[all_original_cols %in% names(df)],
      tagged_col_names
    )
    untagged_idx <- which(names(df) %in% untagged_cols) - 1

    # Combined: both tiers hidden initially
    all_hidden_idx <- unique(c(always_hidden_idx, untagged_idx))

    # Column indices for badge rendering (0-indexed)
    match_type_idx <- which(names(df) == "match_type") - 1
    consensus_idx <- which(names(df) == "consensus_status") - 1
    consensus_dtxsid_idx <- which(names(df) == "consensus_dtxsid") - 1

    # Prepare display dataframe (after filtering)
    display_df <- df_display

    # Determine row selection mode based on filter state
    selection_mode <- if (isTRUE(data_store$error_filter_active)) "multiple" else "none"

    # Create DT table with colvis, badges, and column visibility
    dt <- datatable(
      display_df,
      selection = selection_mode,
      editable = list(
        target = "cell",
        disable = list(
          columns = setdiff(seq_len(ncol(display_df)) - 1, consensus_dtxsid_idx)
        )
      ),
      options = list(
        pageLength = 25,
        scrollX = TRUE,
        dom = 'Bfrtip',
        buttons = list(
          'copy', 'csv',
          list(
            extend = 'colvis',
            text = 'Toggle Columns',
            columns = as.list(untagged_idx)
          )
        ),
        columnDefs = list(
          list(visible = FALSE, targets = as.list(all_hidden_idx)),
          # Match type badge rendering via JS callback
          list(
            targets = match_type_idx,
            render = JS(
              "function(data, type, row, meta) {",
              "  if (type !== 'display') return data;",
              "  var colors = {",
              "    'Exact Match': '#28a745',",
              "    'CAS Lookup': '#007bff',",
              "    'Starts-With': '#ffc107',",
              "    'No Match': '#dc3545'",
              "  };",
              "  var textColors = { 'Starts-With': '#212529' };",
              "  var bg = colors[data] || '#6c757d';",
              "  var fg = textColors[data] || '#fff';",
              "  return '<span style=\"background:' + bg + ';color:' + fg +",
              "    ';padding:2px 8px;border-radius:4px;font-weight:600;font-size:0.85em;display:inline-block;\">' +",
              "    data + '</span>';",
              "}"
            )
          ),
          # Consensus status badge rendering via JS callback
          list(
            targets = consensus_idx,
            render = JS(
              "function(data, type, row, meta) {",
              "  if (type !== 'display') return data;",
              "  var colors = {",
              "    'agree': '#28a745',",
              "    'agree_caveat': '#17a2b8',",
              "    'single': '#6c757d',",
              "    'disagree': '#fd7e14',",
              "    'error': '#343a40',",
              "    'manual': '#6f42c1',",
              "    'unresolvable': '#721c24'",
              "  };",
              "  var bg = colors[data] || '#6c757d';",
              "  return '<span style=\"background:' + bg + ';color:#fff;padding:2px 8px;border-radius:4px;font-weight:600;font-size:0.85em;display:inline-block;\">' +",
              "    data + '</span>';",
              "}"
            )
          )
        )
      ),
      extensions = 'Buttons',
      class = 'cell-border stripe hover compact',
      rownames = FALSE,
      filter = "top",
      escape = FALSE  # Allow HTML in Resolution column
    )

    # Add color-coded row backgrounds (error rows get light pink)
    dt <- dt %>% formatStyle(
      'consensus_status',
      target = 'row',
      backgroundColor = styleEqual(
        c("agree", "agree_caveat", "disagree", "single", "error", "manual", "unresolvable"),
        c(
          "rgba(40, 167, 69, 0.08)",
          "rgba(40, 167, 69, 0.05)",
          "rgba(220, 53, 69, 0.08)",
          "rgba(108, 117, 125, 0.05)",
          "rgba(220, 53, 69, 0.12)",
          "rgba(111, 66, 193, 0.08)",
          "rgba(114, 28, 36, 0.12)"
        )
      )
    )

    dt
  })

  # Priority Controls UI ----

  output$priority_controls <- renderUI({
    req(data_store$priority_order)

    priority <- data_store$priority_order

    # Generate UI for each column in priority order
    controls <- lapply(seq_along(priority), function(i) {
      col_name <- priority[i]
      display_name <- sub("^dtxsid_", "", col_name)

      div(
        class = "d-flex align-items-center mb-2",
        tags$span(
          class = "badge bg-secondary me-2",
          style = "width: 30px;",
          i
        ),
        tags$span(
          class = "flex-grow-1",
          display_name
        ),
        actionButton(
          paste0("priority_up_", i),
          "",
          icon = icon("arrow-up"),
          class = "btn-sm btn-outline-secondary me-1",
          disabled = if (i == 1) TRUE else NULL
        ),
        actionButton(
          paste0("priority_down_", i),
          "",
          icon = icon("arrow-down"),
          class = "btn-sm btn-outline-secondary",
          disabled = if (i == length(priority)) TRUE else NULL
        )
      )
    })

    do.call(tagList, controls)
  })

  # Handle priority up/down buttons dynamically
  observe({
    req(data_store$priority_order)
    priority <- data_store$priority_order

    lapply(seq_along(priority), function(i) {
      # Up button
      observeEvent(input[[paste0("priority_up_", i)]], {
        if (i > 1) {
          new_priority <- data_store$priority_order
          # Swap with previous
          temp <- new_priority[i - 1]
          new_priority[i - 1] <- new_priority[i]
          new_priority[i] <- temp
          data_store$priority_order <- new_priority
        }
      }, ignoreInit = TRUE)

      # Down button
      observeEvent(input[[paste0("priority_down_", i)]], {
        if (i < length(data_store$priority_order)) {
          new_priority <- data_store$priority_order
          # Swap with next
          temp <- new_priority[i + 1]
          new_priority[i + 1] <- new_priority[i]
          new_priority[i] <- temp
          data_store$priority_order <- new_priority
        }
      }, ignoreInit = TRUE)
    })
  })

  # Resolution Controls ----

  # Handle inline cell editing for manual DTXSID entry
  observeEvent(input$curation_table_cell_edit, {
    info <- input$curation_table_cell_edit
    display_row <- info$row  # 1-based index in displayed table
    new_value <- trimws(as.character(info$value))

    # Map displayed row to original row index when filter is active
    row_map <- isolate(data_store$display_row_map)
    if (!is.null(row_map) && display_row <= length(row_map)) {
      row_idx <- row_map[display_row]
    } else {
      row_idx <- display_row
    }

    # Only allow edits on error/unresolvable rows
    current_status <- as.character(isolate(data_store$resolution_state)$consensus_status[row_idx])
    if (!current_status %in% c("error", "unresolvable")) {
      showNotification("Only error/unresolvable rows can be manually edited", type = "warning")
      return()
    }

    # Basic DTXSID format validation
    if (!grepl("^DTXSID\\d+$", new_value, ignore.case = TRUE)) {
      showNotification(
        paste0("Invalid format: ", new_value, ". Expected: DTXSIDxxxxxxx"),
        type = "warning", duration = 5
      )
      return()
    }

    # Queue for bulk validation only — don't update resolution_state here.
    # The cell value is already visually updated by DT's inline editor.
    # resolution_state gets updated when "Validate All" is clicked.
    data_store$manual_queue[[as.character(row_idx)]] <- new_value

    showNotification(paste0("Row ", row_idx, " queued for validation"), type = "message", duration = 2)
  })

  # Toggle Validate All button visibility based on queue length
  observe({
    has_queued <- length(data_store$manual_queue) > 0
    if (has_queued) {
      shinyjs::show("validate_all")
    } else {
      shinyjs::hide("validate_all")
    }
  })

  # Handle per-row resolution dropdown
  observeEvent(input$resolve_row_choice, {
    req(data_store$resolution_state, data_store$dtxsid_cols)

    choice <- input$resolve_row_choice
    row_idx <- choice$row
    chosen_column <- choice$column

    tryCatch({
      if (chosen_column == "__none__") {
        # "None" selected: pin the row without setting a DTXSID
        updated_df <- data_store$resolution_state
        updated_df <- init_resolution_state(updated_df)
        updated_df$.pinned[row_idx] <- TRUE
        # Leave consensus_dtxsid as-is (NA)
        data_store$resolution_state <- updated_df

        showNotification(
          paste0("Row ", row_idx, " marked as skipped (None)"),
          type = "message"
        )
      } else {
        # Normal resolution: call resolve_row function
        updated_df <- resolve_row(
          data_store$resolution_state,
          row_idx,
          chosen_column,
          data_store$dtxsid_cols
        )

        # Update state
        data_store$resolution_state <- updated_df

        showNotification(
          paste0("Row ", row_idx, " resolved using ", sub("^dtxsid_", "", chosen_column)),
          type = "message"
        )
      }

      # Recalculate consensus summary
      updated_df <- data_store$resolution_state
      data_store$consensus_summary <- list(
        n_agree = sum(updated_df$consensus_status == "agree", na.rm = TRUE),
        n_disagree = sum(updated_df$consensus_status == "disagree" & !isTRUE(updated_df$.pinned), na.rm = TRUE),
        n_agree_caveat = sum(updated_df$consensus_status == "agree_caveat", na.rm = TRUE),
        n_single = sum(updated_df$consensus_status == "single", na.rm = TRUE),
        n_error = sum(updated_df$consensus_status == "error", na.rm = TRUE)
      )
    }, error = function(e) {
      showNotification(
        paste0("Error resolving row: ", e$message),
        type = "error"
      )
    })
  })

  # Handle Validate All button for manual DTXSID entries
  observeEvent(input$validate_all, {
    queue <- data_store$manual_queue
    if (length(queue) == 0) {
      showNotification("No manual entries to validate", type = "warning", duration = 3)
      return()
    }

    row_indices <- as.integer(names(queue))
    all_dtxsids <- unlist(queue)
    unique_dtxsids <- unique(all_dtxsids)

    # Disable button during validation
    shinyjs::disable("validate_all")
    on.exit(shinyjs::enable("validate_all"))

    withProgress(message = "Validating manual DTXSIDs...", value = 0, {
      incProgress(0.1, detail = sprintf("Validating %d entries...", length(unique_dtxsids)))

      validation_results <- validate_manual_dtxsids(unique_dtxsids)

      incProgress(0.6, detail = "Updating results...")

      updated_df <- data_store$resolution_state
      n_valid <- 0
      n_invalid <- 0
      invalid_details <- c()

      for (i in seq_along(row_indices)) {
        row_idx <- row_indices[i]
        entered_dtxsid <- queue[[as.character(row_idx)]]

        val_row <- validation_results[validation_results$searchValue == entered_dtxsid, ]

        if (nrow(val_row) > 0 && isTRUE(val_row$is_valid[1])) {
          # Valid: update consensus
          updated_df$consensus_dtxsid[row_idx] <- val_row$dtxsid[1]
          updated_df$consensus_status[row_idx] <- "manual"
          updated_df$consensus_source[row_idx] <- "manual_entry"
          updated_df$.manual_entry[row_idx] <- TRUE

          # Store preferredName in manual_preferredName column
          if (!"manual_preferredName" %in% names(updated_df)) {
            updated_df$manual_preferredName <- NA_character_
          }
          updated_df$manual_preferredName[row_idx] <- val_row$preferredName[1]

          n_valid <- n_valid + 1
        } else {
          # Invalid: keep error status, track for feedback
          invalid_details <- c(invalid_details,
            sprintf("Row %d: %s", row_idx, entered_dtxsid))
          n_invalid <- n_invalid + 1
        }
      }

      data_store$resolution_state <- updated_df

      # Clear queue
      data_store$manual_queue <- list()

      incProgress(0.3, detail = "Done")
    })

    # Summary notification
    msg <- sprintf("Validation complete: %d validated, %d failed", n_valid, n_invalid)
    showNotification(msg,
      type = if (n_invalid > 0) "warning" else "message",
      duration = 8
    )

    # Detail notification for failures
    if (n_invalid > 0) {
      showNotification(
        paste("Failed entries:", paste(invalid_details, collapse = "; ")),
        type = "error",
        duration = NULL  # Stays until dismissed
      )
    }

    # Update consensus summary to reflect manual resolutions
    updated_df <- data_store$resolution_state
    data_store$consensus_summary <- list(
      n_agree = sum(updated_df$consensus_status == "agree", na.rm = TRUE),
      n_disagree = sum(updated_df$consensus_status == "disagree" & !isTRUE(updated_df$.pinned), na.rm = TRUE),
      n_agree_caveat = sum(updated_df$consensus_status == "agree_caveat", na.rm = TRUE),
      n_single = sum(updated_df$consensus_status == "single", na.rm = TRUE),
      n_error = sum(updated_df$consensus_status == "error", na.rm = TRUE),
      n_manual = sum(updated_df$consensus_status == "manual", na.rm = TRUE),
      n_unresolvable = sum(updated_df$consensus_status == "unresolvable", na.rm = TRUE)
    )
  })

  # Handle en masse priority application
  observeEvent(input$apply_priority, {
    req(data_store$resolution_state, data_store$priority_order, data_store$dtxsid_cols)

    tryCatch({
      # Count disagree rows before
      before_count <- sum(
        data_store$resolution_state$consensus_status == "disagree" &
        !isTRUE(data_store$resolution_state$.pinned),
        na.rm = TRUE
      )

      # Apply priority chain
      updated_df <- apply_priority_chain(
        data_store$resolution_state,
        data_store$priority_order,
        data_store$dtxsid_cols
      )

      # Update state
      data_store$resolution_state <- updated_df

      # Count disagree rows after
      after_count <- sum(
        updated_df$consensus_status == "disagree" &
        !isTRUE(updated_df$.pinned),
        na.rm = TRUE
      )

      resolved_count <- before_count - after_count

      # Recalculate consensus summary
      data_store$consensus_summary <- list(
        n_agree = sum(updated_df$consensus_status == "agree", na.rm = TRUE),
        n_disagree = after_count,
        n_agree_caveat = sum(updated_df$consensus_status == "agree_caveat", na.rm = TRUE),
        n_single = sum(updated_df$consensus_status == "single", na.rm = TRUE),
        n_error = sum(updated_df$consensus_status == "error", na.rm = TRUE)
      )

      showNotification(
        paste0("Applied priority chain: ", resolved_count, " rows resolved"),
        type = "message"
      )
    }, error = function(e) {
      showNotification(
        paste0("Error applying priority: ", e$message),
        type = "error"
      )
    })
  })

  # Export Functionality ----

  # Download curated data
  output$download_curated <- downloadHandler(
    filename = function() {
      # Generate filename with timestamp
      file_base <- if (!is.null(data_store$file_info)) {
        tools::file_path_sans_ext(data_store$file_info$name)
      } else {
        "curated_data"
      }
      paste0(file_base, "_curated_", format(Sys.Date(), "%Y%m%d"), ".xlsx")
    },
    content = function(file) {
      req(data_store$resolution_state, data_store$consensus_summary)

      # Sheet 1: Curated Data with full audit trail
      # Add needs_review flag (TRUE for error/No Match rows only), remove .pinned
      export_data <- data_store$resolution_state %>%
        dplyr::mutate(
          needs_review = (consensus_status %in% c("error", "unresolvable"))
        ) %>%
        dplyr::select(-tidyselect::any_of(c(".pinned", ".manual_entry"))) %>%
        dplyr::relocate(needs_review, .after = tidyselect::last_col())

      # Sheet 2: Summary
      summary_df <- tibble::tibble(
        Metric = c(
          "Total Rows",
          "Consensus - Agree",
          "Consensus - Disagree",
          "Consensus - Agree (Caveat)",
          "Consensus - Single Source",
          "Consensus - Manual",
          "Consensus - Error",
          "Consensus - Unresolvable",
          "Match Rate (%)"
        ),
        Value = c(
          nrow(data_store$resolution_state),
          data_store$consensus_summary$n_agree,
          data_store$consensus_summary$n_disagree,
          data_store$consensus_summary$n_agree_caveat,
          data_store$consensus_summary$n_single,
          data_store$consensus_summary$n_manual %||% 0,
          data_store$consensus_summary$n_error,
          data_store$consensus_summary$n_unresolvable %||% 0,
          round((sum(!is.na(data_store$resolution_state$consensus_dtxsid)) / nrow(data_store$resolution_state)) * 100, 1)
        )
      )

      # Sheet 3: Column Tags
      tags_df <- tibble::tibble(
        Column = names(data_store$column_tags),
        Type = unlist(data_store$column_tags)
      )

      # Write to Excel with multiple sheets
      writexl::write_xlsx(
        list(
          "Curated Data" = export_data,
          "Summary" = summary_df,
          "Column Tags" = tags_df
        ),
        path = file
      )
    }
  )

  # --- Error Recovery Observers ---

  # Filter toggle observer
  observeEvent(input$filter_errors, {
    data_store$error_filter_active <- !data_store$error_filter_active

    # Update button label
    updateActionButton(
      session, "filter_errors",
      label = if (data_store$error_filter_active) "Show All" else "Show Errors"
    )
  })

  # Track selected rows and show/hide retag button
  observe({
    selected <- input$curation_table_rows_selected
    if (!is.null(selected) && length(selected) > 0 && isTRUE(data_store$error_filter_active)) {
      # Map filtered indices back to original indices
      data_store$selected_error_rows <- data_store$display_row_map[selected]
      shinyjs::show("retag_selected")
    } else {
      data_store$selected_error_rows <- NULL
      shinyjs::hide("retag_selected")
    }
  })

  # Show re-tag modal
  observeEvent(input$retag_selected, {
    req(data_store$selected_error_rows, data_store$clean, data_store$column_tags)

    n_selected <- length(data_store$selected_error_rows)
    original_cols <- names(data_store$clean)

    # Build modal content with column tag selectors
    modal_content <- tagList(
      p(sprintf("Re-assign column tags for %d selected row(s).", n_selected)),
      p("Change tags below and click 'Apply & Re-curate' to run the full pipeline on selected rows."),
      hr(),
      lapply(original_cols, function(col) {
        current_tag <- data_store$column_tags[[col]] %||% ""
        div(
          class = "mb-3",
          selectInput(
            inputId = paste0("retag_col_", col),
            label = col,
            choices = c("(none)" = "", "Name" = "Name", "CASRN" = "CASRN", "Other" = "Other"),
            selected = current_tag,
            width = "100%"
          )
        )
      })
    )

    showModal(modalDialog(
      title = sprintf("Re-tag %d Selected Rows", n_selected),
      modal_content,
      footer = tagList(
        tags$button(
          "Apply & Re-curate",
          class = "btn btn-primary",
          onclick = "Shiny.setInputValue('apply_retag_trigger', Math.random())"
        ),
        modalButton("Cancel")
      ),
      size = "l",
      easyClose = FALSE
    ))
  })

  # Apply re-tag and re-curate handler
  observeEvent(input$apply_retag_trigger, {
    selected_rows <- data_store$selected_error_rows

    if (is.null(selected_rows) || length(selected_rows) == 0) {
      showNotification("No rows selected. Please select error rows first.", type = "warning")
      removeModal()
      return()
    }

    # Collect new tags from modal inputs BEFORE closing modal
    original_cols <- names(data_store$clean)
    new_tags <- list()
    for (col in original_cols) {
      tag_val <- input[[paste0("retag_col_", col)]]
      if (!is.null(tag_val) && tag_val != "") {
        new_tags[[col]] <- tag_val
      }
    }

    # Now safe to close modal
    removeModal()

    if (length(new_tags) == 0) {
      showNotification("No columns tagged. Please select at least one tag.", type = "warning")
      return()
    }

    # Check if tags changed from original
    tags_changed <- !identical(sort(names(new_tags)), sort(names(data_store$column_tags))) ||
                    !identical(new_tags[sort(names(new_tags))], data_store$column_tags[sort(names(data_store$column_tags))])

    # Extract subset of clean data for selected rows
    subset_data <- data_store$clean[selected_rows, , drop = FALSE]

    # Run full curation pipeline on subset (button is in modal which is already closed)

    withProgress(message = "Re-curating selected rows...", value = 0, {
      retry_result <- tryCatch({
        run_curation_pipeline(
          clean_data = subset_data,
          column_tags = new_tags,
          progress_callback = function(stage, msg) {
            incProgress(0.2, detail = msg)
          }
        )
      }, error = function(e) {
        showNotification(paste("Re-curation failed:", e$message), type = "error", duration = NULL)
        NULL
      })

      if (!is.null(retry_result)) {
        incProgress(0.3, detail = "Merging results...")

        # Merge retry results back into main state
        updated_state <- merge_retry_results(
          original_state = data_store$resolution_state,
          retry_results = retry_result$results,
          selected_row_indices = selected_rows,
          tags_changed = tags_changed
        )

        data_store$resolution_state <- updated_state

        # Update dtxsid_cols if new tag columns were added
        if (tags_changed) {
          data_store$dtxsid_cols <- grep("^dtxsid_", names(updated_state), value = TRUE)
        }

        # Count results
        n_resolved <- sum(updated_state$consensus_status[selected_rows] %in%
          c("agree", "agree_caveat", "single", "manual"), na.rm = TRUE)
        n_still_error <- sum(updated_state$consensus_status[selected_rows] == "unresolvable", na.rm = TRUE)

        showNotification(
          sprintf("Re-curation complete: %d resolved, %d unresolvable", n_resolved, n_still_error),
          type = if (n_still_error > 0) "warning" else "message",
          duration = 8
        )
      }
    })

    # Reset filter and selection state
    data_store$error_filter_active <- FALSE
    data_store$selected_error_rows <- NULL
    updateActionButton(session, "filter_errors", label = "Show Errors")

    # Update consensus summary
    updated_df <- data_store$resolution_state
    data_store$consensus_summary <- list(
      n_agree = sum(updated_df$consensus_status == "agree", na.rm = TRUE),
      n_disagree = sum(updated_df$consensus_status == "disagree", na.rm = TRUE),
      n_agree_caveat = sum(updated_df$consensus_status == "agree_caveat", na.rm = TRUE),
      n_single = sum(updated_df$consensus_status == "single", na.rm = TRUE),
      n_error = sum(updated_df$consensus_status == "error", na.rm = TRUE),
      n_manual = sum(updated_df$consensus_status == "manual", na.rm = TRUE),
      n_unresolvable = sum(updated_df$consensus_status == "unresolvable", na.rm = TRUE)
    )
  })
}

# Run application
shinyApp(ui = ui, server = server)
