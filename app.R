# ChemReg Shiny Data Upload & Preview Application
# Upload CSV/XLSX files with intelligent frontmatter detection

# Load packages
source(here::here("load_packages.R"))

# Load helper functions
source(here::here("R", "file_handlers.R"))
source(here::here("R", "data_detection.R"))

# Application configuration
options(
  shiny.maxRequestSize = 50 * 1024^2  # 50MB upload limit
)

# UI Definition
ui <- page_sidebar(
  # Enable shinyjs
  shinyjs::useShinyjs(),

  # Theme
  theme = bs_theme(
    version = 5,
    bootswatch = "flatly",
    primary = "#007bff"
  ),

  # Title
  title = "ChemReg Data Upload & Preview",

  # Sidebar
  sidebar = sidebar(
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
    )
  ),

  # Main Content
  navset_card_tab(
    id = "main_tabs",

    # Data Preview Tab
    nav_panel(
      title = "Data Preview",
      icon = bsicons::bs_icon("table"),

      # Summary cards
      layout_columns(
        col_widths = c(3, 3, 3, 3),
        uiOutput("summary_cards")
      ),

      # Data table
      card(
        card_header("Preview Data"),
        card_body(
          min_height = "500px",
          DTOutput("data_table")
        )
      )
    ),

    # Detection Info Tab
    nav_panel(
      title = "Detection Info",
      icon = bsicons::bs_icon("search"),

      uiOutput("detection_details")
    ),

    # Raw Data Tab
    nav_panel(
      title = "Raw Data",
      icon = bsicons::bs_icon("file-text"),

      card(
        card_header("Raw File Contents (First 20 Rows)"),
        card_body(
          DTOutput("raw_table")
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
    file_info = NULL
  )

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

    tryCatch({
      # Read file
      file_ext <- tools::file_ext(input$file_upload$name)
      raw_df <- safely_read_file(input$file_upload$datapath, file_ext)

      # Detect frontmatter
      detection <- detect_data_start(
        raw_df,
        mode = input$detection_mode,
        manual_row = if (input$detection_mode == "manual") input$manual_header_row else NULL
      )

      # Extract clean data
      clean_df <- extract_clean_data(raw_df, detection)

      # Handle merged cells
      clean_df <- handle_merged_cells(clean_df)

      # Apply janitor cleaning
      clean_df <- clean_df %>%
        janitor::clean_names() %>%
        janitor::remove_empty(which = c("rows", "cols"))

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
          "Detected ", nrow(clean_df), " rows and ", ncol(clean_df), " columns."
        ),
        type = "message",
        duration = 5
      )

    }, error = function(e) {
      # Remove processing notification
      removeNotification(notification_id)

      # Show error notification
      showNotification(
        paste("Error reading file:", e$message),
        type = "error",
        duration = 10
      )

      # Reset data store
      data_store$raw <- NULL
      data_store$clean <- NULL
      data_store$detection <- NULL
      data_store$file_info <- NULL
    })
  })

  # Update detection when mode or manual row changes
  observeEvent(c(input$detection_mode, input$manual_header_row), {
    req(data_store$raw)

    tryCatch({
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

      # Update stored data
      data_store$clean <- clean_df
      data_store$detection <- detection

    }, error = function(e) {
      showNotification(
        paste("Error updating detection:", e$message),
        type = "warning",
        duration = 5
      )
    })
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
    missing_pct <- round(sum(is.na(df)) / (total_rows * total_cols) * 100, 1)
    detection_conf <- round(data_store$detection$confidence * 100, 0)

    list(
      value_box(
        title = "Total Rows",
        value = format(total_rows, big.mark = ","),
        showcase = bsicons::bs_icon("table"),
        theme = "primary"
      ),
      value_box(
        title = "Total Columns",
        value = total_cols,
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
        theme = if (detection_conf >= 70) "success" else if (detection_conf >= 50) "warning" else "danger"
      )
    )
  })

  # Output: Data table
  output$data_table <- renderDT({
    req(data_store$clean)

    preview_data <- head(data_store$clean, input$preview_rows)

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
      filter = 'top'
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
}

# Run application
shinyApp(ui = ui, server = server)
