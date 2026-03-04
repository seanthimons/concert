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
      DTOutput(ns("raw_table"))
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
  })
}
