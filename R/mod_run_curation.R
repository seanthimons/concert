# Run Curation Module
# Curation execution with progress tracking and statistics

#' Run Curation Module - UI
#'
#' @param id Module namespace ID
#'
#' @return UI elements for run curation tab
#' @export
mod_run_curation_ui <- function(id) {
  ns <- NS(id)

  tagList(
    # Content when tags are applied
    conditionalPanel(
      condition = paste0("output['", ns("tags_applied"), "']"),

      div(
        class = "alert alert-info",
        uiOutput(ns("curation_summary"))
      ),

      shinyjs::disabled(
        actionButton(
          ns("run_curation"),
          "Start Curation",
          class = "btn-success btn-lg mt-3",
          icon = icon("play")
        )
      ),

      uiOutput(ns("curation_progress"))
    ),

    # Empty state when tags not applied
    conditionalPanel(
      condition = paste0("!output['", ns("tags_applied"), "']"),
      div(
        class = "text-center text-muted py-5",
        bsicons::bs_icon("tags", size = "3em"),
        h4("No columns tagged yet"),
        p("Go to the Tag Columns tab and assign column types first.")
      )
    )
  )
}

#' Run Curation Module - Server
#'
#' @param id Module namespace ID
#' @param data_store Reactive values store from main app
#' @param on_curation_complete Callback function to execute after curation completes (for navigation)
#'
#' @return Reactive list with curation_completed indicator
#' @export
mod_run_curation_server <- function(id, data_store, on_curation_complete = NULL) {
  moduleServer(id, function(input, output, session) {

    # Curation summary
    output$curation_summary <- renderUI({
      req(data_store$column_tags)

      col_tags <- data_store$column_tags
      name_count <- sum(col_tags == "Name")
      cas_count <- sum(col_tags == "CASRN")
      other_count <- sum(col_tags == "Other")

      # API key check
      has_api_key <- Sys.getenv("ctx_api_key") != ""
      api_status <- if (has_api_key) {
        tags$span(class = "badge bg-success", "API Key Configured")
      } else {
        tags$span(class = "badge bg-danger", "API Key Missing")
      }

      tagList(
        p(strong("Tagged Columns:")),
        tags$ul(
          tags$li(paste(name_count, "Chemical Name column(s)")),
          tags$li(paste(cas_count, "CASRN column(s)")),
          if (other_count > 0) tags$li(paste(other_count, "Other column(s)"))
        ),

        # Dedup preview
        if (!is.null(data_store$dedup_preview)) {
          tagList(
            p(strong("Deduplication Preview:")),
            tags$ul(
              tags$li(paste(data_store$dedup_preview$n_names, "unique chemical names to look up")),
              tags$li(paste(data_store$dedup_preview$n_cas, "unique CAS numbers to validate"))
            )
          )
        },

        # API key status
        p(strong("API Status:"), " ", api_status)
      )
    })

    # Enable/disable Start Curation button based on prerequisites
    observe({
      has_tags <- !is.null(data_store$column_tags) && length(data_store$column_tags) > 0
      has_api_key <- Sys.getenv("ctx_api_key") != ""

      if (has_tags && has_api_key) {
        shinyjs::enable("run_curation")
      } else {
        shinyjs::disable("run_curation")
      }
    })

    # Run curation button
    observeEvent(input$run_curation, {
      req(data_store$clean, data_store$column_tags)

      # Check for ComptoxR API key
      if (Sys.getenv("ctx_api_key") == "") {
        showNotification(
          "ComptoxR API key not set. Please set 'ctx_api_key' environment variable and restart R session.",
          type = "error",
          duration = NULL
        )
        return()
      }

      # Check if there are Name or CASRN columns tagged
      has_name <- any(data_store$column_tags == "Name")
      has_cas <- any(data_store$column_tags == "CASRN")

      if (!has_name && !has_cas) {
        showNotification(
          "Please tag at least one column as 'Chemical Name' or 'CASRN' before running curation.",
          type = "warning",
          duration = 5
        )
        return()
      }

      # Disable the button during execution
      shinyjs::disable("run_curation")
      data_store$curation_status <- "in_progress"

      # Run curation with progress tracking via withProgress
      tryCatch(
        {
          withProgress(message = "Running curation pipeline...", value = 0, {
            # Progress callback to update both withProgress and status field
            progress_callback <- function(stage, msg) {
              data_store$curation_status <- msg
              incProgress(0.2, detail = msg)
            }

            # Run the new pipeline
            # Use cleaned_data if available (after cleaning workflow), fallback to clean (raw data)
            input_data <- if (!is.null(data_store$cleaned_data)) {
              data_store$cleaned_data
            } else {
              data_store$clean
            }

            pipeline_result <- run_curation_pipeline(
              clean_data = input_data,
              column_tags = data_store$column_tags,
              progress_callback = progress_callback,
              dedup_only = FALSE
            )

            # Store results
            data_store$consensus_data <- pipeline_result$results
            data_store$consensus_summary <- pipeline_result$consensus_summary
            data_store$resolution_state <- pipeline_result$results
            data_store$dtxsid_cols <- find_dtxsid_cols(pipeline_result$results)
            data_store$priority_order <- data_store$dtxsid_cols

            # Store in curation_results for backward compatibility with Review tab
            data_store$curation_results <- pipeline_result$results

            # Generate backward-compatible report from new summaries
            data_store$curation_report <- list(
              total_rows = nrow(pipeline_result$results),
              cas_columns = sum(data_store$column_tags == "CASRN"),
              name_columns = sum(data_store$column_tags == "Name"),
              cas_validated = pipeline_result$search_summary$n_cas_valid,
              cas_invalid = pipeline_result$dedup_summary$n_cas - pipeline_result$search_summary$n_cas_valid,
              names_exact_match = pipeline_result$search_summary$n_exact,
              names_fuzzy_match = pipeline_result$search_summary$n_starts_with,
              names_no_match = pipeline_result$search_summary$n_miss
            )

            data_store$curation_status <- "completed"

            # --- Enrichment: auto-trigger after curation ---
            tryCatch({
              # Collect ALL unique DTXSIDs for enrichment (disagree + agree/single)
              all_unique_dtxsids <- character(0)

              # From disagree rows: all candidate DTXSIDs across dtxsid_* columns
              dtxsid_cols <- data_store$dtxsid_cols
              disagree_idx <- which(pipeline_result$results$consensus_status == "disagree")
              if (length(disagree_idx) > 0 && length(dtxsid_cols) > 0) {
                for (dc in dtxsid_cols) {
                  vals <- pipeline_result$results[[dc]][disagree_idx]
                  all_unique_dtxsids <- c(all_unique_dtxsids, vals[!is.na(vals)])
                }
              }

              # From agree/single/agree_caveat rows: consensus_dtxsid values
              non_disagree_idx <- which(pipeline_result$results$consensus_status %in%
                c("agree", "agree_caveat", "single"))
              if (length(non_disagree_idx) > 0) {
                consensus_vals <- pipeline_result$results$consensus_dtxsid[non_disagree_idx]
                all_unique_dtxsids <- c(all_unique_dtxsids, consensus_vals[!is.na(consensus_vals)])
              }

              all_unique_dtxsids <- unique(all_unique_dtxsids)

              if (length(all_unique_dtxsids) > 0) {
                showNotification(
                  sprintf("Enriching %d candidates...", length(all_unique_dtxsids)),
                  type = "message", duration = 3, id = "enrich-progress"
                )

                enrich_result <- enrich_candidates(
                  dtxsids = all_unique_dtxsids,
                  existing_cache = data_store$enrichment_cache
                )

                data_store$enrichment_cache <- enrich_result$cache
                data_store$enrichment_failed <- enrich_result$failed_dtxsids

                n_enriched <- sum(!is.na(enrich_result$cache$casrn))
                n_total <- nrow(enrich_result$cache)
                n_failed <- length(enrich_result$failed_dtxsids)

                if (n_failed > 0) {
                  showNotification(
                    sprintf("Enrichment: %d of %d DTXSIDs enriched (%d failed)",
                      n_enriched, n_total, n_failed),
                    type = "warning", duration = 8
                  )
                } else {
                  showNotification(
                    sprintf("Enrichment complete: %d of %d DTXSIDs enriched",
                      n_enriched, n_total),
                    type = "message", duration = 5
                  )
                }
              }
            }, error = function(e) {
              warning(sprintf("[enrich] Enrichment failed: %s", e$message))
              showNotification(
                paste("Enrichment failed (curation results still valid):", e$message),
                type = "warning", duration = 8
              )
            })

            # Show tier breakdown notification
            notification_msg <- sprintf(
              "Search complete: %d exact, %d CAS, %d starts-with, %d no match",
              pipeline_result$search_summary$n_exact,
              pipeline_result$search_summary$n_cas_valid,
              pipeline_result$search_summary$n_starts_with,
              pipeline_result$search_summary$n_miss
            )

            showNotification(
              notification_msg,
              type = "message",
              duration = 8
            )

            # Call navigation callback if provided
            if (!is.null(on_curation_complete)) {
              on_curation_complete()
            }
          })
        },
        error = function(e) {
          showNotification(
            paste("Curation failed:", e$message),
            type = "error",
            duration = NULL
          )
          data_store$curation_status <- "failed"
        },
        finally = {
          # Re-enable button
          shinyjs::enable("run_curation")
        }
      )
    })

    # Curation progress display
    output$curation_progress <- renderUI({
      status <- data_store$curation_status

      if (is.null(status) || status == "") {
        return(NULL)
      }

      if (status == "in_progress") {
        tagList(
          div(
            class = "mt-3 text-muted small",
            tags$span(class = "spinner-border spinner-border-sm me-2", role = "status"),
            tags$span(status)
          )
        )
      } else if (status == "completed") {
        div(
          class = "mt-3 alert alert-success small",
          bsicons::bs_icon("check-circle"),
          " Pipeline completed successfully!"
        )
      } else if (status == "failed") {
        div(
          class = "mt-3 alert alert-danger small",
          bsicons::bs_icon("exclamation-triangle"),
          " Pipeline failed. Check notifications for details."
        )
      } else {
        # Show progress message
        div(
          class = "mt-3 text-muted small",
          tags$span(class = "spinner-border spinner-border-sm me-2", role = "status"),
          tags$span(status)
        )
      }
    })

    # Tags applied indicator (mirrors tag module's state check)
    output$tags_applied <- reactive({
      !is.null(data_store$column_tags) && length(data_store$column_tags) > 0
    })
    outputOptions(output, "tags_applied", suspendWhenHidden = FALSE)

    # Curation completed indicator
    output$curation_completed <- reactive({
      !is.null(data_store$curation_status) && data_store$curation_status == "completed"
    })
    outputOptions(output, "curation_completed", suspendWhenHidden = FALSE)

    # Return reactive list
    return(list(
      curation_completed = reactive({
        !is.null(data_store$curation_status) && data_store$curation_status == "completed"
      })
    ))
  })
}
