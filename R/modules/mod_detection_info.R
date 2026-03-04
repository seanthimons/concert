# Detection Info Module
# Displays detection method details and metadata preview

#' Detection Info Module - UI
#'
#' @param id Module namespace ID
#'
#' @return UI elements for detection info tab
mod_detection_info_ui <- function(id) {
  ns <- NS(id)

  uiOutput(ns("detection_details"))
}

#' Detection Info Module - Server
#'
#' @param id Module namespace ID
#' @param data_store Reactive values store from main app
#'
#' @return NULL (module has no return values)
mod_detection_info_server <- function(id, data_store) {
  moduleServer(id, function(input, output, session) {

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
  })
}
