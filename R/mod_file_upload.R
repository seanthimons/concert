# File Upload Module
# Handles file upload, detection mode settings, and column selection

#' File Upload Module - UI
#'
#' @param id Module namespace ID
#'
#' @return tagList of sidebar UI elements
#' @export
mod_file_upload_ui <- function(id) {
  ns <- NS(id)

  tagList(
    # File Upload Section
    card(
      card_header(
        class = "bg-primary text-white",
        "Upload Data"
      ),
      card_body(
        fileInput(
          ns("file_upload"),
          "Choose CSV or XLSX File",
          accept = c(".csv", ".xlsx", ".xls"),
          buttonLabel = "Browse...",
          placeholder = "No file selected"
        ),
        uiOutput(ns("file_info"))
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
          ns("preview_rows"),
          "Rows to Preview:",
          min = 5,
          max = 100,
          value = 10,
          step = 5
        ),

        radioButtons(
          ns("detection_mode"),
          "Header Detection:",
          choices = c(
            "Automatic" = "auto",
            "Manual" = "manual"
          ),
          selected = "auto"
        ),

        conditionalPanel(
          condition = "input.detection_mode == 'manual'",
          ns = ns,
          numericInput(
            ns("manual_header_row"),
            "Header Row Number:",
            value = 1,
            min = 1,
            max = 100,
            step = 1
          )
        ),

        actionButton(
          ns("reset_btn"),
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
          condition = paste0("output['", ns("has_data"), "']"),

          checkboxGroupInput(
            ns("selected_columns"),
            "Select Columns to Display:",
            choices = NULL,
            selected = NULL
          ),

          div(
            class = "d-flex gap-1 mb-2",
            actionButton(ns("select_all_cols"), "Select All", class = "btn-sm btn-outline-primary flex-fill"),
            actionButton(ns("deselect_all_cols"), "Deselect All", class = "btn-sm btn-outline-secondary flex-fill")
          )
        )
      )
    )
  )
}

#' File Upload Module - Server
#'
#' @param id Module namespace ID
#' @param data_store Reactive values store from main app
#' @param reset_all_downstream Optional callback function to reset downstream state (app navigation)
#' @param on_session_restored Optional callback after a CONCERT export session is
#'   hydrated
#'
#' @return Reactive list with file processing outputs
#' @export
mod_file_upload_server <- function(
  id,
  data_store,
  reset_all_downstream = NULL,
  on_session_restored = NULL
) {
  moduleServer(id, function(input, output, session) {
    pending_concert_export <- reactiveVal(NULL)

    # --- Internal Functions ---

    detect_full_concert_export <- function(file_info) {
      file_ext <- tolower(tools::file_ext(file_info$name))
      if (!file_ext %in% c("xlsx", "xls")) {
        return(NULL)
      }

      parsed <- parse_concert_export(file_info$datapath)
      if (!is.null(parsed) && isTRUE(parsed$has_full_session_state)) {
        return(parsed)
      }

      NULL
    }

    show_concert_export_modal <- function() {
      showModal(modalDialog(
        title = "CONCERT Export Detected",
        p("This workbook contains a saved CONCERT session."),
        p("Resume restores the exported review state and opens Review Results. Treat as Raw Data processes the Raw Data sheet as a fresh upload."),
        if (!is.null(data_store$clean)) {
          p(class = "text-muted small", "Your current session will be replaced.")
        },
        footer = tagList(
          modalButton("Cancel"),
          actionButton(session$ns("treat_export_as_raw"), "Treat as Raw Data", class = "btn-outline-secondary"),
          actionButton(session$ns("resume_export_session"), "Resume Session", class = "btn-primary")
        ),
        easyClose = TRUE
      ))
    }

    assign_hydrated_state <- function(state) {
      for (name in names(state)) {
        data_store[[name]] <- state[[name]]
      }
    }

    restore_concert_export_session <- function(file_info, parsed) {
      notification_id <- showNotification(
        "Restoring CONCERT session...",
        type = "message",
        duration = NULL
      )

      tryCatch(
        {
          hydrated <- hydrate_session_state(parsed, data_store$reference_lists)

          if (!is.null(reset_all_downstream)) {
            reset_all_downstream()
          }

          assign_hydrated_state(hydrated$state)

          if (!is.null(data_store$clean)) {
            suggested_rows <- calculate_smart_preview_rows(data_store$clean)
            updateSliderInput(session, "preview_rows", value = suggested_rows)
          }

          removeNotification(notification_id)

          for (warning_msg in hydrated$warnings) {
            showNotification(warning_msg, type = "warning", duration = 10)
          }

          showNotification(
            "CONCERT session restored successfully.",
            type = "message",
            duration = 5
          )

          if (!is.null(on_session_restored)) {
            on_session_restored(hydrated$warnings)
          }
        },
        error = function(e) {
          removeNotification(notification_id)
          showNotification(
            paste("Failed to restore CONCERT session:", conditionMessage(e)),
            type = "error",
            duration = NULL
          )
        }
      )
    }

    # Process uploaded file (extracted for re-use by modal confirm)
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

          # Store results (upload module owns these fields)
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

    # --- File Upload Handlers ---

    # File upload handler — with confirmation modal for re-uploads
    observeEvent(input$file_upload, {
      req(input$file_upload)

      parsed_export <- detect_full_concert_export(input$file_upload)
      if (!is.null(parsed_export)) {
        pending_concert_export(list(
          file_info = input$file_upload,
          parsed = parsed_export
        ))
        show_concert_export_modal()
        return()
      }

      if (!is.null(data_store$clean)) {
        # Re-upload: data already exists — show confirmation modal
        showModal(modalDialog(
          title = "Replace Current Data?",
          p("Your column tags and curation results will be cleared."),
          p("This action cannot be undone."),
          footer = tagList(
            actionButton(session$ns("cancel_reupload"), "Cancel", class = "btn-secondary"),
            actionButton(session$ns("confirm_reupload"), "Replace Data", class = "btn-danger")
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

    observeEvent(input$resume_export_session, {
      export_data <- pending_concert_export()
      req(export_data)

      removeModal()
      pending_concert_export(NULL)
      restore_concert_export_session(export_data$file_info, export_data$parsed)
    })

    observeEvent(input$treat_export_as_raw, {
      export_data <- pending_concert_export()
      req(export_data)

      removeModal()
      pending_concert_export(NULL)

      if (!is.null(reset_all_downstream)) {
        reset_all_downstream()
      }
      data_store$raw <- NULL
      data_store$clean <- NULL
      data_store$detection <- NULL
      data_store$file_info <- NULL

      process_uploaded_file(export_data$file_info)
    })

    # Re-upload modal: Confirm — reset all downstream state, process new file
    observeEvent(input$confirm_reupload, {
      removeModal()
      # Call reset callback if provided
      if (!is.null(reset_all_downstream)) {
        reset_all_downstream()
      }
      # Clear core data
      data_store$raw <- NULL
      data_store$clean <- NULL
      data_store$detection <- NULL
      data_store$file_info <- NULL
      # Process the new file
      process_uploaded_file(input$file_upload)
    })

    # --- Detection Mode Observers ---

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

    # --- Outputs ---

    # File info display
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

    # has_data output for conditionalPanel
    output$has_data <- reactive({
      !is.null(data_store$clean)
    })
    outputOptions(output, "has_data", suspendWhenHidden = FALSE)

    # --- Reset Handler ---

    # Reset button handler
    observeEvent(input$reset_btn, {
      # Call reset callback if provided
      if (!is.null(reset_all_downstream)) {
        reset_all_downstream()
      }
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

    # --- Column Selection Logic ---

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

    # --- Return Values ---

    # Return reactive list for app.R to observe
    return(list(
      preview_rows = reactive({ input$preview_rows })
    ))
  })
}
