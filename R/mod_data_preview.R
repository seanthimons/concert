# Data Preview Module
# Displays summary cards and filterable data table

#' Data Preview Module - UI
#'
#' @param id Module namespace ID
#'
#' @return UI elements for data preview tab
#' @export
mod_data_preview_ui <- function(id) {
  ns <- NS(id)

  tagList(
    # Summary cards
    uiOutput(ns("summary_cards")),

    # Data table (full width, no card wrapper)
    div(
      class = "mt-3",
      div(
        class = "d-flex gap-2 mb-2",
        downloadButton(ns("download_csv"), "Download CSV", class = "btn-sm btn-outline-secondary"),
        downloadButton(ns("download_excel"), "Download Excel", class = "btn-sm btn-outline-secondary")
      ),
      reactable::reactableOutput(ns("data_table"))
    )
  )
}

#' Data Preview Module - Server
#'
#' @param id Module namespace ID
#' @param data_store Reactive values store from main app
#' @param preview_rows Reactive integer for number of rows to preview
#'
#' @return NULL (module has no return values)
#' @export
mod_data_preview_server <- function(id, data_store, preview_rows) {
  moduleServer(id, function(input, output, session) {

    # Filtered data based on column selection
    filtered_data <- reactive({
      req(data_store$clean)
      selected <- data_store$selected_columns

      if (is.null(selected) || length(selected) == 0) {
        return(data_store$clean) # Show all if none selected
      }

      data_store$clean %>% dplyr::select(all_of(selected))
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
    output$data_table <- reactable::renderReactable({
      req(data_store$clean)
      req(preview_rows)

      preview_data <- head(filtered_data(), preview_rows())

      # Validate data before rendering
      if (nrow(preview_data) == 0 || ncol(preview_data) == 0) {
        return(reactable::reactable(
          data.frame(Message = "No data available after cleaning"),
          compact = TRUE
        ))
      }

      # Build column defs with NA styling
      col_defs <- lapply(names(preview_data), function(col_name) {
        reactable::colDef(
          style = function(value) {
            if (is.na(value)) {
              list(backgroundColor = "#f9f9f9")
            } else {
              NULL
            }
          }
        )
      })
      names(col_defs) <- names(preview_data)

      reactable::reactable(
        preview_data,
        columns = col_defs,
        defaultPageSize = min(25, nrow(preview_data)),
        filterable = TRUE,
        resizable = TRUE,
        wrap = FALSE,
        striped = TRUE,
        bordered = TRUE,
        compact = TRUE,
        highlight = TRUE
      )
    })

    # Download handlers
    output$download_csv <- downloadHandler(
      filename = function() {
        file_base <- if (!is.null(data_store$file_info)) {
          tools::file_path_sans_ext(data_store$file_info$name)
        } else {
          "preview_data"
        }
        paste0(file_base, "_preview.csv")
      },
      content = function(file) {
        readr::write_csv(filtered_data(), file)
      }
    )

    output$download_excel <- downloadHandler(
      filename = function() {
        file_base <- if (!is.null(data_store$file_info)) {
          tools::file_path_sans_ext(data_store$file_info$name)
        } else {
          "preview_data"
        }
        paste0(file_base, "_preview.xlsx")
      },
      content = function(file) {
        writexl::write_xlsx(filtered_data(), path = file)
      }
    )
  })
}
