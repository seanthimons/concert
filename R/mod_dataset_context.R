# Dataset Context Module
# Curates site/location metadata before chemical cleaning and curation.

#' Dataset Context Module - UI
#'
#' @param id Module namespace ID
#'
#' @return UI elements for dataset context curation.
#' @export
mod_dataset_context_ui <- function(id) {
  ns <- NS(id)

  tagList(
    tags$style(HTML(paste0(
      "#", ns("dataset_context_ui"), " .dataset-context-actions { gap: 0.5rem; }",
      "#", ns("dataset_context_ui"), " .dataset-context-table .dataTables_wrapper { width: 100%; }"
    ))),
    div(
      id = ns("dataset_context_ui"),
      conditionalPanel(
        condition = paste0("!output['", ns("has_data"), "']"),
        div(
          class = "text-center text-muted py-5",
          bsicons::bs_icon("geo-alt", size = "3em"),
          h4("No data loaded"),
          p("Upload a file to review dataset context.")
        )
      ),
      conditionalPanel(
        condition = paste0("output['", ns("has_data"), "']"),
        uiOutput(ns("dataset_context_nudge")),
        uiOutput(ns("site_manifest_summary")),
        div(
          class = "dataset-context-table",
          DT::DTOutput(ns("site_manifest_table"))
        ),
        div(
          class = "dataset-context-actions d-flex flex-wrap mt-3",
          actionButton(
            ns("apply_site_manifest"),
            "Apply",
            icon = icon("check"),
            class = "btn-primary"
          ),
          actionButton(
            ns("reset_site_manifest"),
            "Reset",
            icon = icon("rotate-left"),
            class = "btn-outline-secondary"
          ),
          actionButton(
            ns("clear_site_manifest"),
            "Clear",
            icon = icon("trash"),
            class = "btn-outline-danger"
          )
        )
      )
    )
  )
}

site_context_datatable <- function(manifest) {
  manifest <- normalize_site_manifest(manifest)
  disabled <- which(!names(manifest) %in% site_context_editable_columns()) - 1L
  DT::datatable(
    manifest,
    rownames = FALSE,
    editable = list(target = "cell", disable = list(columns = disabled)),
    filter = "top",
    options = list(
      pageLength = 10,
      scrollX = TRUE,
      dom = "tip"
    ),
    class = "compact stripe hover"
  )
}

#' Dataset Context Module - Server
#'
#' @param id Module namespace ID
#' @param data_store Reactive values store from main app.
#'
#' @return Reactive list with site context state.
#' @export
mod_dataset_context_server <- function(id, data_store) {
  moduleServer(id, function(input, output, session) {
    site_manifest_working <- reactiveVal(empty_site_manifest())

    output$has_data <- reactive({
      !is.null(data_store$clean)
    })
    outputOptions(output, "has_data", suspendWhenHidden = FALSE)

    output$has_site_context <- reactive({
      detection <- data_store$site_context_detection
      !is.null(detection) && isTRUE(detection$has_site_context)
    })
    outputOptions(output, "has_site_context", suspendWhenHidden = FALSE)

    observeEvent(
      data_store$clean,
      {
        if (is.null(data_store$clean)) {
          data_store$site_context_detection <- NULL
          data_store$site_context_candidates <- empty_site_manifest()
          site_manifest_working(empty_site_manifest())
          return()
        }

        detection <- detect_site_columns(data_store$clean)
        candidates <- extract_site_candidates(data_store$clean, detection)
        data_store$site_context_detection <- detection
        data_store$site_context_candidates <- candidates

        if (!is.null(data_store$site_manifest) && nrow(normalize_site_manifest(data_store$site_manifest)) > 0L) {
          site_manifest_working(normalize_site_manifest(data_store$site_manifest))
        } else {
          site_manifest_working(candidates)
        }
      },
      ignoreNULL = FALSE
    )

    output$dataset_context_nudge <- renderUI({
      detection <- data_store$site_context_detection
      candidates <- data_store$site_context_candidates

      if (is.null(detection) || !isTRUE(detection$has_site_context) || is.null(candidates) || nrow(candidates) == 0L) {
        return(NULL)
      }

      summary <- site_context_detection_summary(detection)
      div(
        class = "alert alert-info d-flex align-items-start gap-2",
        bsicons::bs_icon("geo-alt"),
        div(
          tags$strong("Dataset Context"),
          tags$div(sprintf("%d distinct site row(s) detected.", nrow(candidates))),
          if (length(summary) > 0L) {
            tags$small(class = "text-muted", paste(summary, collapse = "; "))
          }
        )
      )
    })

    output$site_manifest_summary <- renderUI({
      manifest <- build_site_manifest(site_manifest_working())
      if (nrow(manifest) == 0L) {
        return(div(class = "alert alert-secondary", "No site/location context is currently selected."))
      }

      grouped <- sum(!is.na(manifest$grouping_label) & nzchar(manifest$grouping_label))
      located <- sum(!is.na(manifest$latitude) & !is.na(manifest$longitude))
      div(
        class = "d-flex flex-wrap gap-2 mb-2",
        tags$span(class = "badge bg-primary", sprintf("%d sites", nrow(manifest))),
        tags$span(class = "badge bg-secondary", sprintf("%d with coordinates", located)),
        tags$span(class = "badge bg-secondary", sprintf("%d grouped", grouped))
      )
    })

    output$site_manifest_table <- DT::renderDT({
      site_context_datatable(site_manifest_working())
    })

    observeEvent(input$site_manifest_table_cell_edit, {
      info <- input$site_manifest_table_cell_edit
      manifest <- normalize_site_manifest(site_manifest_working())
      if (nrow(manifest) == 0L) {
        return()
      }

      row <- suppressWarnings(as.integer(info$row))
      col <- suppressWarnings(as.integer(info$col))
      if (is.na(row) || row < 1L || row > nrow(manifest)) {
        return()
      }

      if (is.na(col) || col < 1L || col > ncol(manifest)) {
        col <- col + 1L
      }
      if (is.na(col) || col < 1L || col > ncol(manifest)) {
        return()
      }

      col_name <- names(manifest)[col]
      if (!col_name %in% site_context_editable_columns()) {
        return()
      }

      manifest[[col_name]][row] <- info$value
      site_manifest_working(normalize_site_manifest(manifest))
    })

    observeEvent(input$apply_site_manifest, {
      manifest <- build_site_manifest(site_manifest_working())
      data_store$site_manifest <- manifest
      data_store$site_context_status <- if (nrow(manifest) > 0L) "curated" else "empty"

      showNotification(
        sprintf("Dataset context applied: %d site row(s).", nrow(manifest)),
        type = "message",
        duration = 4
      )
    })

    observeEvent(input$reset_site_manifest, {
      candidates <- data_store$site_context_candidates
      if (is.null(candidates)) {
        candidates <- empty_site_manifest()
      }
      site_manifest_working(candidates)
      showNotification("Dataset context reset to detected values.", type = "message", duration = 3)
    })

    observeEvent(input$clear_site_manifest, {
      site_manifest_working(empty_site_manifest())
      data_store$site_manifest <- empty_site_manifest()
      data_store$site_context_status <- "empty"
      showNotification("Dataset context cleared.", type = "message", duration = 3)
    })

    list(
      has_site_context = reactive({
        detection <- data_store$site_context_detection
        !is.null(detection) && isTRUE(detection$has_site_context)
      }),
      site_manifest = reactive({
        build_site_manifest(site_manifest_working())
      })
    )
  })
}
