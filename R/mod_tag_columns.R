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
    tags$style(HTML(paste0(
      "#",
      ns("column_tagging_ui"),
      " .tag-columns-table td { vertical-align: middle; }",
      "#",
      ns("column_tagging_ui"),
      " .tag-columns-table td .shiny-input-container { margin-bottom: 0; }",
      "#",
      ns("column_tagging_ui"),
      " .tag-column-name { padding-left: 0.75rem; }",
      "#",
      ns("column_tagging_ui"),
      " .tag-column-selected > td { background-color: #e7f5ff !important; }"
    ))),
    tags$script(HTML(paste0(
      "$(document).on('shiny:inputchanged', function(event) {",
      "  var id = event.name;",
      "  var row = $('#",
      ns("column_tagging_ui"),
      " .tag-column-row').filter(function() {",
      "    return $(this).data('input-id') === id;",
      "  });",
      "  if (!row.length) return;",
      "  if (event.value && event.value !== '') {",
      "    row.addClass('tag-column-selected');",
      "  } else {",
      "    row.removeClass('tag-column-selected');",
      "  }",
      "});"
    ))),

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

      # Header with tag action buttons top-right
      div(
        class = "d-flex justify-content-between align-items-center gap-2 flex-wrap mb-3",
        h4("Tag Columns"),
        div(
          class = "d-flex gap-2 flex-wrap",
          actionButton(
            ns("suggest_tags"),
            "Suggest Tags",
            class = "btn-outline-primary",
            icon = icon("magic")
          ),
          actionButton(
            ns("clear_tags"),
            "Clear Tags",
            class = "btn-outline-secondary",
            icon = icon("eraser")
          ),
          actionButton(
            ns("apply_tags"),
            "Apply Tags",
            class = "btn-primary",
            icon = icon("tag")
          )
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
#' @param on_tags_cleared Callback function to execute after tags cleared
#'
#' @return Reactive list with tags_applied indicator
#' @export
mod_tag_columns_server <- function(id, data_store, on_tags_applied = NULL, on_tags_cleared = NULL) {
  moduleServer(id, function(input, output, session) {
    tag_input_id <- function(col) {
      paste0("tag_", make.names(col))
    }

    collect_applied_tags <- function() {
      c(
        data_store$column_tags,
        data_store$numeric_tags,
        data_store$metadata_tags,
        data_store$study_type_tags
      )
    }

    update_tag_inputs <- function(cols, values) {
      for (col in cols) {
        updateSelectInput(
          session,
          tag_input_id(col),
          selected = values[[col]] %||% ""
        )
      }
    }

    # Dynamic UI for column tagging — table-based layout
    output$column_tagging_ui <- renderUI({
      req(data_store$selected_columns)

      selected_cols <- data_store$selected_columns

      if (length(selected_cols) == 0) {
        return(div(class = "alert alert-warning", "No columns selected. Please select columns in the sidebar."))
      }

      # Pre-fill precedence: an already-applied or config-imported tag wins over
      # a heuristic suggestion, which wins over blank. Applied tags are split
      # across four partitions (column_tags holds chemical only), so merge them.
      applied_tags <- collect_applied_tags()
      suggested_tags <- data_store$suggested_column_tags

      # Table-based layout: one row per column
      tags$table(
        class = "table table-sm table-striped table-hover tag-columns-table",
        tags$thead(
          tags$tr(
            tags$th("Type", style = "width: 220px;"),
            tags$th("Column Name", class = "text-start")
          )
        ),
        tags$tbody(
          lapply(selected_cols, function(col) {
            applied_tag <- applied_tags[[col]]
            # Only surface a suggestion when the user has not already chosen one.
            is_suggested <- is.null(applied_tag) && !is.null(suggested_tags[[col]]) && nzchar(suggested_tags[[col]])
            selected_tag <- applied_tag %||% suggested_tags[[col]] %||% ""

            tags$tr(
              class = "tag-column-row",
              `data-input-id` = session$ns(tag_input_id(col)),
              tags$td(
                style = "width:220px;",
                selectInput(
                  inputId = session$ns(tag_input_id(col)),
                  label = NULL,
                  choices = list(
                    "Select type..." = c("Select type..." = ""),
                    "Chemical" = c("Chemical Name" = "Name", "CASRN" = "CASRN", "Other" = "Other"),
                    "Numeric" = c(
                      "Result Value" = "Result",
                      "Numeric Measurement" = "Numeric",
                      "Unit" = "Unit",
                      "Qualifier" = "Qualifier",
                      "Reporting Limit" = "ReportingLimit",
                      "Uncertainty" = "Uncertainty",
                      "Uncertainty Coverage" = "UncertaintyCoverage"
                    ),
                    "Study / Contextual" = c(
                      "Duration" = "Duration",
                      "Duration Unit" = "DurationUnit",
                      "Species" = "Species",
                      "Exposure Route" = "ExposureRoute",
                      "Study Date" = "StudyDate",
                      "Media" = "Media"
                    )
                  ),
                  selected = selected_tag,
                  selectize = FALSE,
                  width = "100%"
                )
              ),
              tags$td(
                class = "tag-column-name text-start align-middle",
                tags$strong(col),
                if (is_suggested) {
                  tags$span(class = "badge bg-light text-muted ms-2 fw-normal", "suggested")
                }
              )
            )
          })
        )
      )
    })

    # Suggest tags button
    observeEvent(input$suggest_tags, {
      selected_cols <- data_store$selected_columns
      if (is.null(selected_cols) || length(selected_cols) == 0) {
        showNotification(
          "Select at least one column before suggesting tags.",
          type = "warning",
          duration = 5
        )
        return()
      }

      suggested_tags <- suggest_column_tags(selected_cols)
      data_store$suggested_column_tags <- suggested_tags

      applied_tags <- collect_applied_tags()
      unassigned_suggestions <- list()
      for (col in selected_cols) {
        suggestion <- suggested_tags[[col]]
        applied_tag <- applied_tags[[col]]
        if (
          !is.null(suggestion) && nzchar(suggestion) &&
            (is.null(applied_tag) || !nzchar(applied_tag))
        ) {
          unassigned_suggestions[[col]] <- suggestion
        }
      }

      update_tag_inputs(names(unassigned_suggestions), unassigned_suggestions)

      if (length(unassigned_suggestions) == 0) {
        showNotification(
          "No new tag suggestions found for selected columns.",
          type = "message",
          duration = 3
        )
      } else {
        showNotification(
          paste("Suggested tags for", length(unassigned_suggestions), "column(s)."),
          type = "message",
          duration = 3
        )
      }
    })

    # Clear tags button
    observeEvent(input$clear_tags, {
      cols_to_clear <- data_store$selected_columns
      if (is.null(cols_to_clear) || length(cols_to_clear) == 0) {
        cols_to_clear <- if (!is.null(data_store$clean)) names(data_store$clean) else character(0)
      }

      data_store$column_tags <- NULL
      data_store$numeric_tags <- NULL
      data_store$metadata_tags <- NULL
      data_store$study_type_tags <- NULL
      data_store$suggested_column_tags <- NULL
      data_store$dedup_preview <- NULL

      update_tag_inputs(cols_to_clear, list())

      showNotification(
        "Cleared assigned tags.",
        type = "message",
        duration = 3
      )

      if (!is.null(on_tags_cleared)) {
        on_tags_cleared()
      }
    })

    # Apply tags button
    observeEvent(input$apply_tags, {
      req(data_store$selected_columns)

      # Collect non-empty tag selections from UI inputs.
      # NOTE: named "col_tag_map" (not "tags") to avoid shadowing the htmltools
      # tags namespace used in the modal construction below.
      col_tag_map <- list()
      for (col in data_store$selected_columns) {
        tag_value <- input[[tag_input_id(col)]]

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
      if (!is.null(warning_msg)) {
        showNotification(warning_msg, type = "warning", duration = 6)
      }

      # Check for required chemical tags (Name AND CASRN)
      has_req <- has_required_chemical_tags(classified$chemical_tags)
      if (!has_req) {
        tag_values <- unlist(classified$chemical_tags, use.names = FALSE)
        missing <- c()
        if (!"Name" %in% tag_values) {
          missing <- c(missing, "Chemical Name")
        }
        if (!"CASRN" %in% tag_values) {
          missing <- c(missing, "CASRN")
        }
        showNotification(
          paste("Clean Data requires both Name and CASRN columns. Missing:", paste(missing, collapse = ", ")),
          type = "warning",
          duration = 6
        )
      }

      # Store partitioned tags per D-04
      # column_tags contains ONLY chemical tags for backwards compatibility
      data_store$column_tags <- classified$chemical_tags
      data_store$numeric_tags <- classified$numeric_tags
      data_store$metadata_tags <- classified$metadata_tags
      data_store$study_type_tags <- classified$study_type_tags

      # Generate dedup preview immediately (uses chemical tags only)
      # Skip for large datasets (>10k rows) - deduplicate_tagged_columns is O(n²)
      if (nrow(data_store$clean) <= 10000) {
        tryCatch(
          {
            data_store$dedup_preview <- get_dedup_preview(data_store$clean, classified$chemical_tags)
          },
          error = function(e) {
            message("Dedup preview generation failed: ", e$message)
            data_store$dedup_preview <- NULL
          }
        )
      } else {
        data_store$dedup_preview <- NULL
      }

      showNotification(
        paste("Tagged", length(col_tag_map), "column(s) successfully!"),
        type = "message",
        duration = 3
      )

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
