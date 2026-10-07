# Run Curation Module
# Curation execution with progress tracking and statistics

# Replay scoped decisions only after comparing the fresh automated evidence.
# The GUI lookup projection is safe to reconstruct only when that evidence is
# unchanged; otherwise it could conceal a changed consensus from the reviewer.
reapply_curation_identity_decisions <- function(df, prior_baseline, baseline, prior_state, decisions) {
  messages <- character()
  for (decision in decisions %||% list()) {
    outcome <- tryCatch({
      if (is.null(prior_baseline)) stop("The earlier automated baseline is missing.", call. = FALSE)
      reviewed_row <- gui_identity_row(prior_state, decision$selector)
      if (!identical(as.character(identity_col(prior_state, "identity_decision_fingerprint")[reviewed_row]),
                     identity_evidence_fingerprint(prior_state, reviewed_row))) {
        stop("The earlier source decision is stale.", call. = FALSE)
      }
      old_row <- gui_identity_row(prior_baseline, decision$selector)
      new_row <- gui_identity_row(baseline, decision$selector)
      if (!identical(identity_evidence_fingerprint(prior_baseline, old_row),
                     identity_evidence_fingerprint(baseline, new_row))) {
        stop("Automated source or identity evidence changed.", call. = FALSE)
      }
      apply_identity_decisions(list(resolution_state = df), list(decision))$resolution_state
    }, error = function(e) e)
    if (inherits(outcome, "error")) {
      messages <- c(messages, paste("Source decision was not re-applied:", conditionMessage(outcome),
                                    "Review the current evidence before accepting this source."))
      # Keep the prior decision visible as stale, without copying source content,
      # lookup results, candidates or validation over the fresh automated result.
      old_row <- tryCatch(gui_identity_row(prior_state, decision$selector), error = function(e) NULL)
      lineage <- decision$selector[intersect(c("original_row_id", "multi_analyte_part_index"), names(decision$selector))]
      matches <- rep(length(lineage) > 0L, nrow(df))
      for (col in names(lineage)) {
        if (!col %in% names(df)) { matches[] <- FALSE; break }
        value <- lineage[[col]]
        matches <- matches & if (is.na(value)) is.na(df[[col]]) else !is.na(df[[col]]) & df[[col]] == value
      }
      if (!is.null(old_row)) {
        for (col in intersect(c("identity_scope", "identity_conflict", "identity_scope_reviewed",
                                "identity_decision_fingerprint", "identity_decision_record"), names(prior_state))) {
          if (!col %in% names(df)) df[[col]] <- if (is.logical(prior_state[[col]])) FALSE else NA_character_
          df[[col]][matches] <- prior_state[[col]][old_row]
        }
        df$identity_scope_reviewed[matches] <- TRUE
        df$identity_decision_fingerprint[matches] <- NA_character_
      }
    } else {
      df <- outcome
    }
  }
  list(resolution_state = df, messages = messages)
}

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
        notify_user(
          "ComptoxR API key not set. Please set 'ctx_api_key' environment variable and restart R session.",
          type = "error",
          duration = NULL
        )
        return()
      }

      # Check if there are Name or CASRN columns tagged
      has_name <- any(data_store$column_tags == "Name")
      has_cas <- any(data_store$column_tags == "CASRN")
      has_source <- any(data_store$column_tags == "DTXSID")

      if (!has_name && !has_cas && !has_source) {
        notify_user(
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

            # Guard against clobbering imported/manual review corrections on a
            # re-run: capture them as content-matched overrides so they can be
            # re-applied to the fresh automated results below.
            prior_baseline <- data_store$script_baseline_state
            prior_state <- data_store$resolution_state
            prior_decisions <- data_store$identity_decisions %||% list()
            prior_flags <- list()
            if (!is.null(prior_state) && !is.null(prior_baseline) &&
                "original_row_id" %in% names(prior_state)) {
              flagged <- which(!is.na(identity_col(prior_state, "row_flag")) |
                                 !is.na(identity_col(prior_state, "row_flag_reason")))
              prior_flags <- vector("list", length(flagged))
              for (index in seq_along(flagged)) {
                row <- flagged[index]
                record <- tryCatch(list(selector = gui_identity_selector(prior_state, row, data_store$column_tags),
                  values = as.list(prior_state[row, intersect(c("row_flag", "row_flag_reason"), names(prior_state)), drop = FALSE])),
                  error = function(e) {
                    notify_user(paste("Source flags could not be captured:", conditionMessage(e)),
                                type = "warning", duration = NULL)
                    NULL
                  })
                prior_flags[index] <- list(record)
              }
              prior_flags <- Filter(Negate(is.null), prior_flags)
            }
            prior_overrides <- tryCatch(
              build_review_overrides(
                prior_baseline,
                {
                  projected <- gui_identity_replay_state(prior_state, prior_decisions)
                  # Flags are source-scoped when lineage is available. Avoid
                  # turning them into conflicting compound-wide corrections.
                  if (length(prior_flags)) for (col in c("row_flag", "row_flag_reason")) {
                    if (col %in% names(projected)) projected[[col]] <- identity_col(prior_baseline, col)
                  }
                  projected
                },
                tag_map = combine_tag_maps(
                  data_store$column_tags,
                  data_store$numeric_tags,
                  data_store$metadata_tags,
                  data_store$study_type_tags
                )
              ),
              error = function(e) {
                notify_user(paste("Existing review corrections could not be captured:", conditionMessage(e),
                                  "Review the new results before exporting replay."), type = "warning", duration = NULL)
                NULL
              }
            )

            pipeline_result <- run_curation_pipeline(
              clean_data = input_data,
              column_tags = data_store$column_tags,
              progress_callback = progress_callback,
              dedup_only = FALSE,
              wqx_threshold = data_store$wqx_threshold %||% 0.85,
              starts_with = isTRUE(data_store$starts_with),
              pubchem = isTRUE(data_store$pubchem),
              desalt = isTRUE(data_store$desalt),
              original_data = data_store$clean,
              ignored_identifier_cols = data_store$ignored_identifier_cols %||% character()
            )

            # Store results
            data_store$consensus_data <- pipeline_result$results
            data_store$source_identifier_evidence <- pipeline_result$source_identifier_evidence
            data_store$identifier_diagnostics <- pipeline_result$identifier_diagnostics
            data_store$consensus_summary <- pipeline_result$consensus_summary
            data_store$resolution_state <- pipeline_result$results
            data_store$dtxsid_cols <- find_dtxsid_cols(pipeline_result$results)
            data_store$priority_order <- data_store$dtxsid_cols
            data_store$review_visible_cols <- NULL

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
            tryCatch(
              {
                all_unique_dtxsids <- collect_candidate_dtxsids(
                  data_store$resolution_state,
                  data_store$dtxsid_cols
                )

                if (length(all_unique_dtxsids) > 0) {
                  showNotification(
                    sprintf("Enriching %d candidates...", length(all_unique_dtxsids)),
                    type = "message",
                    duration = 3,
                    id = "enrich-progress"
                  )
                }

                postprocess_result <- postprocess_curation_candidates(
                  resolution_state = data_store$resolution_state,
                  column_tags = data_store$column_tags,
                  dtxsid_cols = data_store$dtxsid_cols,
                  enrichment_cache = data_store$enrichment_cache
                )

                data_store$resolution_state <- postprocess_result$resolution_state
                data_store$enrichment_cache <- postprocess_result$enrichment_cache
                data_store$enrichment_failed <- postprocess_result$enrichment_failed
                data_store$consensus_summary <- postprocess_result$consensus_summary

                if (postprocess_result$n_dtxsids > 0) {
                  if (postprocess_result$n_failed > 0) {
                    notify_user(
                      sprintf(
                        "Enrichment: %d of %d DTXSIDs enriched (%d failed)",
                        postprocess_result$n_enriched,
                        postprocess_result$n_total,
                        postprocess_result$n_failed
                      ),
                      type = "warning",
                      duration = 8
                    )
                  } else {
                    showNotification(
                      sprintf(
                        "Enrichment complete: %d of %d DTXSIDs enriched",
                        postprocess_result$n_enriched,
                        postprocess_result$n_total
                      ),
                      type = "message",
                      duration = 5
                    )
                  }
                }

                message(sprintf(
                  "[auto-resolve] %d auto-resolved, %d suggested",
                  postprocess_result$n_auto,
                  postprocess_result$n_suggested
                ))
              },
              error = function(e) {
                log_condition("post-curation enrichment", e, level = "warning")
                warning(sprintf("[enrich] Enrichment failed: %s", e$message))
                notify_user(
                  paste("Enrichment failed (curation results still valid):", e$message),
                  type = "warning",
                  duration = 8
                )
              }
            )

            data_store$script_baseline_state <- data_store$resolution_state

            # Re-apply any review corrections captured before the re-run so a
            # deliberate re-curation does not silently discard them. The pure
            # automated result stays as script_baseline_state (above) so replay
            # still diffs corrections against it.
            if (review_overrides_present(prior_overrides)) {
              reapplied <- tryCatch(
                apply_review_overrides(data_store$script_baseline_state, prior_overrides),
                error = function(e) {
                  notify_user(paste("Review corrections could not be re-applied:", conditionMessage(e)),
                              type = "warning", duration = NULL)
                  NULL
                }
              )
              if (!is.null(reapplied)) {
                data_store$resolution_state <- reapplied
                data_store$consensus_data <- reapplied
                data_store$curation_results <- reapplied
                data_store$consensus_summary <- recalc_consensus_summary(reapplied)
                notify_user(
                  "Re-applied existing review corrections to the new curation results.",
                  type = "message",
                  duration = 6
                )
              } else {
                notify_user(
                  paste(
                    "Could not re-apply existing review corrections to the new results;",
                    "they were not carried over. Re-enter them or restore from an export."
                  ),
                  type = "warning",
                  duration = 10
                )
              }
            }

            for (record in prior_flags) {
              row <- tryCatch(gui_identity_row(data_store$resolution_state, record$selector), error = function(e) {
                notify_user(paste("Source flags could not be re-applied:", conditionMessage(e)),
                            type = "warning", duration = NULL)
                NULL
              })
              if (!is.null(row)) for (col in names(record$values)) {
                if (!col %in% names(data_store$resolution_state)) data_store$resolution_state[[col]] <- NA_character_
                data_store$resolution_state[[col]][row] <- record$values[[col]]
              }
            }
            data_store$consensus_data <- data_store$resolution_state
            data_store$curation_results <- data_store$resolution_state

            if (length(prior_decisions)) {
              scoped <- reapply_curation_identity_decisions(data_store$resolution_state, prior_baseline,
                data_store$script_baseline_state, prior_state, prior_decisions)
              data_store$resolution_state <- scoped$resolution_state
              data_store$consensus_data <- scoped$resolution_state
              data_store$curation_results <- scoped$resolution_state
              data_store$consensus_summary <- recalc_consensus_summary(scoped$resolution_state)
              for (message in scoped$messages) notify_user(message, type = "warning", duration = NULL)
            }

            # Show tier breakdown notification
            notification_msg <- sprintf(
              "Search complete: %d exact, %d CAS, %d WQX, %d starts-with, %d no match",
              pipeline_result$search_summary$n_exact,
              pipeline_result$search_summary$n_cas_valid,
              pipeline_result$search_summary$n_wqx,
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
          log_condition("curation pipeline", e)
          notify_user(
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
