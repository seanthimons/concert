# Tag Columns Module
# Column type tagging UI and apply logic

#' Tag Columns Module - UI
#'
#' @param id Module namespace ID
#'
#' @return UI elements for tag columns tab
#' @export
mod_tag_columns_ui <- function(id) {
  ns <- NS(id)

  tagList(
    # Empty state when no data uploaded
    conditionalPanel(
      condition = paste0("!output['", ns("has_data"), "']"),
      div(
        class = "text-center text-muted py-5",
        bsicons::bs_icon("upload", size = "3em"),
        h4("Upload a file to start tagging columns"),
        p("Upload a CSV or XLSX file using the sidebar.")
      )
    ),

    # Tagging interface when data exists
    conditionalPanel(
      condition = paste0("output['", ns("has_data"), "']"),

      # Header with Apply Tags button top-right
      div(
        class = "d-flex justify-content-between align-items-center mb-3",
        h4("Tag Columns"),
        actionButton(
          ns("apply_tags"),
          "Apply Tags",
          class = "btn-primary",
          icon = icon("tag")
        )
      ),
      p("Categorize selected columns for curation and harmonization."),
      uiOutput(ns("column_tagging_ui"))
    )
  )
}

#' Tag Columns Module - Server
#'
#' @param id Module namespace ID
#' @param data_store Reactive values store from main app
#' @param on_tags_applied Callback function to execute after tags applied (for navigation)
#'
#' @return Reactive list with tags_applied indicator
#' @export
mod_tag_columns_server <- function(id, data_store, on_tags_applied = NULL) {
  moduleServer(id, function(input, output, session) {

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
                  inputId = session$ns(paste0("tag_", make.names(col))),
                  label = NULL,
                  choices = list(
                    "Select type..." = c("Select type..." = ""),
                    "Chemical" = c("Chemical Name" = "Name", "CASRN" = "CASRN", "Other" = "Other"),
                    "Numeric" = c("Result Value" = "Result", "Unit" = "Unit", "Qualifier" = "Qualifier"),
                    "Study" = c(
                      "Duration" = "Duration", "Duration Unit" = "DurationUnit",
                      "Species" = "Species", "Exposure Route" = "ExposureRoute"
                    )
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

      # Collect non-empty tag selections from UI inputs.
      # NOTE: named "col_tag_map" (not "tags") to avoid shadowing the htmltools
      # tags namespace used in the modal construction below.
      col_tag_map <- list()
      for (col in data_store$selected_columns) {
        tag_input_id <- paste0("tag_", make.names(col))
        tag_value <- input[[tag_input_id]]

        if (!is.null(tag_value) && tag_value != "") {
          col_tag_map[[col]] <- tag_value
        }
      }

      if (length(col_tag_map) == 0) {
        showNotification(
          "Please select at least one column type before applying tags.",
          type = "warning",
          duration = 5
        )
        return()
      }

      # Classify tags into categories per D-03
      classified <- classify_tags(col_tag_map)

      # Validate Result/Unit pairing per D-12/D-13
      warning_msg <- validate_tag_pairing(col_tag_map)

      # Store partitioned tags per D-04
      # column_tags contains ONLY chemical tags for backwards compatibility
      data_store$column_tags <- classified$chemical_tags
      data_store$numeric_tags <- classified$numeric_tags
      data_store$metadata_tags <- classified$metadata_tags

      # Generate dedup preview immediately (uses chemical tags only)
      tryCatch(
        {
          data_store$dedup_preview <- get_dedup_preview(data_store$clean, classified$chemical_tags)
        },
        error = function(e) {
          message("Dedup preview generation failed: ", e$message)
          data_store$dedup_preview <- NULL
        }
      )

      # Build confirmation modal -------------------------------------------

      # Helper: render one category summary row (returns NULL when list is empty)
      make_category_row <- function(label, tag_list, badge_class) {
        if (length(tag_list) == 0) return(NULL)
        col_names <- names(tag_list)
        tag_values <- unlist(tag_list, use.names = FALSE)
        entry_text <- paste(
          mapply(function(cn, tv) paste0(cn, " \u2192 ", tv), col_names, tag_values),
          collapse = ", "
        )
        tags$li(
          class = "mb-1",
          tags$span(class = paste("badge me-2", badge_class), label),
          entry_text
        )
      }

      n_chem <- length(classified$chemical_tags)
      n_num <- length(classified$numeric_tags)

      # Collect non-NULL category rows
      category_items <- Filter(Negate(is.null), list(
        make_category_row("Chemical", classified$chemical_tags, "bg-primary"),
        make_category_row("Numeric", classified$numeric_tags, "bg-success"),
        make_category_row("Study", classified$metadata_tags, "bg-info")
      ))

      # Collect next-step bullet items
      next_step_items <- list()
      if (n_chem > 0) {
        next_step_items <- c(next_step_items, list(
          tags$li("Clean Data tab is now available for chemical name curation")
        ))
      } else {
        next_step_items <- c(next_step_items, list(
          tags$li(class = "text-muted", "Clean Data requires at least one Chemical tag (Name or CASRN)")
        ))
      }
      if (n_num > 0) {
        next_step_items <- c(next_step_items, list(
          tags$li("Harmonize tab is now available for numeric result harmonization")
        ))
      }

      # Collect top-level modal body elements
      body_items <- list()
      if (!is.null(warning_msg)) {
        body_items <- c(body_items, list(
          div(
            class = "alert alert-warning mb-3",
            bsicons::bs_icon("exclamation-triangle"), " ", warning_msg
          )
        ))
      }
      body_items <- c(body_items, list(
        tags$p(tags$strong(paste(length(col_tag_map), "column(s) tagged:"))),
        do.call(tags$ul, category_items),
        hr(),
        tags$p(tags$strong("Next steps:")),
        do.call(tags$ul, next_step_items)
      ))

      showModal(modalDialog(
        title = tagList(bsicons::bs_icon("check-circle-fill"), " Tags Applied"),
        do.call(tagList, body_items),
        footer = modalButton("Continue"),
        size = "m",
        easyClose = TRUE
      ))

      # Call navigation callback if provided
      if (!is.null(on_tags_applied)) {
        on_tags_applied()
      }
    })

    # has_data output for conditionalPanel
    output$has_data <- reactive({
      !is.null(data_store$clean)
    })
    outputOptions(output, "has_data", suspendWhenHidden = FALSE)

    # Tags applied indicator
    output$tags_applied <- reactive({
      !is.null(data_store$column_tags) && length(data_store$column_tags) > 0
    })
    outputOptions(output, "tags_applied", suspendWhenHidden = FALSE)

    # Return reactive list
    return(list(
      tags_applied = reactive({
        !is.null(data_store$column_tags) && length(data_store$column_tags) > 0
      })
    ))
  })
}
