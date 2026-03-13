# Raw Data Module
# Displays first 20 rows of raw uploaded file

#' Raw Data Module - UI
#'
#' @param id Module namespace ID
#'
#' @return UI elements for raw data tab
mod_raw_data_ui <- function(id) {
  ns <- NS(id)

  tagList(
    h4("Raw File Contents (First 20 Rows)"),
    div(
      class = "mt-3",
      reactable::reactableOutput(ns("raw_table"))
    )
  )
}

#' Raw Data Module - Server
#'
#' @param id Module namespace ID
#' @param data_store Reactive values store from main app
#'
#' @return NULL (module has no return values)
mod_raw_data_server <- function(id, data_store) {
  moduleServer(id, function(input, output, session) {

    # Output: Raw table
    output$raw_table <- reactable::renderReactable({
      req(data_store$raw)

      raw_preview <- head(data_store$raw, 20)

      reactable::reactable(
        raw_preview,
        defaultPageSize = 20,
        resizable = TRUE,
        wrap = FALSE,
        striped = TRUE,
        compact = TRUE,
        bordered = TRUE
      )
    })
  })
}
