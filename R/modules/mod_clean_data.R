# Clean Data Module
# Data cleaning execution with progress tracking and audit trail display

#' Clean Data Module - UI
#'
#' @param id Module namespace ID
#'
#' @return UI elements for clean data tab
mod_clean_data_ui <- function(id) {
  ns <- NS(id)

  tagList(
    # Content when data is loaded
    conditionalPanel(
      condition = paste0("output['", ns("has_data"), "']"),

      actionButton(
        ns("run_cleaning"),
        "Run Cleaning",
        class = "btn-success btn-lg",
        icon = icon("magic")
      ),

      uiOutput(ns("cleaning_summary")),

      DT::dataTableOutput(ns("cleaned_table"))
    ),

    # Empty state when no data loaded
    conditionalPanel(
      condition = paste0("!output['", ns("has_data"), "']"),
      div(
        class = "text-center text-muted py-5",
        bsicons::bs_icon("eraser", size = "3em"),
        h4("No data loaded"),
        p("Upload a file and it will appear here for cleaning.")
      )
    )
  )
}

#' Clean Data Module - Server
#'
#' @param id Module namespace ID
#' @param data_store Reactive values store from main app
#' @param on_cleaning_complete Callback function to execute after cleaning completes (for navigation)
#'
#' @return Reactive list with cleaning indicators
mod_clean_data_server <- function(id, data_store, on_cleaning_complete = NULL) {
  moduleServer(id, function(input, output, session) {

    # Has data indicator for conditionalPanel
    output$has_data <- reactive({
      !is.null(data_store$clean)
    })
    outputOptions(output, "has_data", suspendWhenHidden = FALSE)

    # Run cleaning button
    observeEvent(input$run_cleaning, {
      req(data_store$clean)

      # Disable button during execution
      shinyjs::disable("run_cleaning")

      # Run cleaning with progress tracking and error handling
      tryCatch(
        {
          withProgress(message = "Cleaning data...", value = 0, {
            incProgress(0.3, detail = "Converting unicode to ASCII")
            incProgress(0.6, detail = "Trimming whitespace and punctuation")

            # Run the cleaning pipeline
            result <- run_cleaning_pipeline(data_store$clean)

            incProgress(1.0, detail = "Complete")

            # Store results in data_store
            data_store$cleaned_data <- result$cleaned_data
            data_store$cleaning_audit <- result$audit_trail

            # Show success notification
            n_changes <- nrow(result$audit_trail)
            showNotification(
              sprintf("Cleaning complete: %d transformations applied", n_changes),
              type = "message",
              duration = 5
            )

            # Call navigation callback if provided
            if (!is.null(on_cleaning_complete)) {
              on_cleaning_complete()
            }
          })
        },
        error = function(e) {
          showNotification(
            paste("Cleaning failed:", e$message),
            type = "error",
            duration = NULL
          )
        },
        finally = {
          # Re-enable button
          shinyjs::enable("run_cleaning")
        }
      )
    })

    # Cleaning summary display
    output$cleaning_summary <- renderUI({
      req(data_store$cleaning_audit, data_store$cleaned_data)

      audit <- data_store$cleaning_audit
      n_total <- nrow(audit)

      if (n_total == 0) {
        return(div(
          class = "alert alert-info mb-3 mt-3",
          p("No transformations needed — data is already clean")
        ))
      }

      # Count by step
      n_unicode <- sum(audit$step == "unicode_to_ascii")
      n_trim <- sum(audit$step == "trim_whitespace_punctuation")

      # Count unique rows affected
      n_rows <- length(unique(audit$row_id))

      div(
        class = "alert alert-info mb-3 mt-3",
        p(sprintf(
          "%d rows cleaned, %d unicode chars fixed, %d fields trimmed",
          n_rows,
          n_unicode,
          n_trim
        ))
      )
    })

    # Cleaned data table
    output$cleaned_table <- DT::renderDataTable({
      req(data_store$cleaned_data)

      DT::datatable(
        data_store$cleaned_data,
        options = list(
          pageLength = 25,
          scrollX = TRUE
        ),
        rownames = FALSE
      )
    })

    # Return reactive list
    return(list(
      cleaning_completed = reactive({
        !is.null(data_store$cleaned_data)
      })
    ))
  })
}
