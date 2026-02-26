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
      title = "Data Preview",
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

    # Detection Info Tab (hidden until upload)
    nav_panel_hidden(
      value = "detection_info",
      title = "Detection Info",
      icon = bsicons::bs_icon("search"),

      uiOutput("detection_details")
    ),

    # Raw Data Tab (hidden until upload)
    nav_panel_hidden(
      value = "raw_data",
      title = "Raw Data",
      icon = bsicons::bs_icon("file-text"),

      h4("Raw File Contents (First 20 Rows)"),
      div(
        class = "mt-3",
        DTOutput("raw_table")
      )
    ),

    # Tag Columns Tab (hidden until upload+detection)
    nav_panel_hidden(
      value = "tag_columns",
      title = "Tag Columns",
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

    # Run Curation Tab (hidden until tags applied)
    nav_panel_hidden(
      value = "run_curation_tab",
      title = "Run Curation",
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

    # Review Results Tab (hidden until curation complete)
    nav_panel_hidden(
      value = "review_results",
      title = "Review Results",
      icon = bsicons::bs_icon("clipboard-check"),

      # Content when curation completed
      conditionalPanel(
        condition = "output.curation_completed",

        # Statistics value boxes at top
        uiOutput("curation_stats"),

        # Header with Download button top-right
        div(
          class = "d-flex justify-content-between align-items-center mb-3 mt-3",
          h4("Curated Results"),
          downloadButton(
            "download_curated",
            "Download Excel",
            class = "btn-primary"
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
    curation_status = NULL
  )

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

  # File upload handler
  observeEvent(input$file_upload, {
    req(input$file_upload)

    # Validate file
    validation <- validate_file(input$file_upload)

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
        file_ext <- tools::file_ext(input$file_upload$name)
        raw_df <- safely_read_file(input$file_upload$datapath, file_ext)

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
        data_store$file_info <- input$file_upload

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
        message("File: ", input$file_upload$name)
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

    # Cascade: hide downstream tabs and clear curation state (re-apply invalidates curation)
    nav_hide("main_tabs", target = "review_results")
    data_store$curation_results <- NULL
    data_store$curation_report <- NULL
    data_store$curation_status <- NULL

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

    tagList(
      p(strong("Tagged Columns:")),
      tags$ul(
        tags$li(paste(name_count, "Chemical Name column(s)")),
        tags$li(paste(cas_count, "CASRN column(s)")),
        if (other_count > 0) tags$li(paste(other_count, "Other column(s)"))
      )
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

    data_store$curation_status <- "in_progress"

    # Show progress notification
    notification_id <- showNotification(
      "Curating chemical data... This may take a few moments.",
      type = "message",
      duration = NULL
    )

    # Run curation (with error handling)
    curation_result <- purrr::safely(curate_chemical_data)(
      clean_data = data_store$clean,
      column_tags = data_store$column_tags
    )

    removeNotification(notification_id)

    if (!is.null(curation_result$error)) {
      showNotification(
        paste("Curation failed:", curation_result$error$message),
        type = "error",
        duration = NULL
      )
      data_store$curation_status <- "failed"
    } else {
      data_store$curation_results <- curation_result$result$curated_data
      data_store$curation_report <- curation_result$result$report
      data_store$curation_status <- "completed"

      showNotification(
        "Curation completed successfully!",
        type = "message",
        duration = 5
      )

      # Show Review Results tab and auto-navigate to it
      nav_show("main_tabs", target = "review_results")
      nav_select("main_tabs", "review_results")
    }
  })

  # Curation completed indicator
  output$curation_completed <- reactive({
    !is.null(data_store$curation_status) && data_store$curation_status == "completed"
  })
  outputOptions(output, "curation_completed", suspendWhenHidden = FALSE)

  # Curation statistics
  output$curation_stats <- renderUI({
    req(data_store$curation_report)

    report <- data_store$curation_report

    layout_columns(
      col_widths = c(6, 6),
      value_box(
        title = "CAS Numbers Validated",
        value = paste0(report$cas_validated, " / ", report$cas_validated + report$cas_invalid),
        showcase = bsicons::bs_icon("check-circle"),
        theme = "success"
      ),
      value_box(
        title = "Chemical Names Matched",
        value = paste0(
          report$names_exact_match + report$names_fuzzy_match,
          " / ",
          report$names_exact_match + report$names_fuzzy_match + report$names_no_match
        ),
        showcase = bsicons::bs_icon("search"),
        theme = "info"
      )
    )
  })

  # Curation results table
  output$curation_table <- renderDT({
    req(data_store$curation_results)

    datatable(
      data_store$curation_results,
      options = list(
        pageLength = 25,
        scrollX = TRUE,
        dom = 'Bfrtip',
        buttons = c('copy', 'csv', 'excel')
      ),
      extensions = 'Buttons',
      class = 'cell-border stripe hover compact',
      rownames = FALSE,
      filter = "top"
    )
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
      req(data_store$clean, data_store$curation_results)

      # Prepare export: Original data with row_id
      original_with_id <- data_store$clean %>%
        dplyr::mutate(row_id = dplyr::row_number())

      # Pivot curation results wider for joining
      curated_wide <- data_store$curation_results %>%
        dplyr::select(
          row_id,
          original_column,
          validated_cas,
          tidyselect::any_of(c("dtxsid", "preferredName", "casrn", "match_status", "is_valid"))
        ) %>%
        tidyr::pivot_wider(
          names_from = original_column,
          values_from = tidyselect::any_of(c(
            "validated_cas",
            "dtxsid",
            "preferredName",
            "casrn",
            "match_status",
            "is_valid"
          )),
          names_sep = "_curated_"
        )

      # Join original and curated
      export_data <- original_with_id %>%
        dplyr::left_join(curated_wide, by = "row_id")

      # Prepare curation report as tibble
      report_df <- tibble::tibble(
        Metric = c(
          "Total Rows",
          "CAS Columns Processed",
          "Name Columns Processed",
          "CAS Numbers Validated",
          "CAS Numbers Invalid",
          "Chemical Names - Exact Match",
          "Chemical Names - Fuzzy Match",
          "Chemical Names - No Match"
        ),
        Value = c(
          data_store$curation_report$total_rows,
          data_store$curation_report$cas_columns,
          data_store$curation_report$name_columns,
          data_store$curation_report$cas_validated,
          data_store$curation_report$cas_invalid,
          data_store$curation_report$names_exact_match,
          data_store$curation_report$names_fuzzy_match,
          data_store$curation_report$names_no_match
        )
      )

      # Prepare column tags as tibble
      tags_df <- tibble::tibble(
        Column = names(data_store$column_tags),
        Type = unlist(data_store$column_tags)
      )

      # Write to Excel with multiple sheets
      writexl::write_xlsx(
        list(
          "Curated Data" = export_data,
          "Curation Report" = report_df,
          "Column Tags" = tags_df
        ),
        path = file
      )
    }
  )
}

# Run application
shinyApp(ui = ui, server = server)
