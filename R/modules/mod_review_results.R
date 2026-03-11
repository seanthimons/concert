# Review Results Module
# Resolution table with validation and error recovery

# Module-internal helper: Recalculate consensus summary from resolution state (single source of truth)
recalc_consensus_summary <- function(df) {
  list(
    n_agree = sum(df$consensus_status == "agree", na.rm = TRUE),
    n_disagree = sum(df$consensus_status == "disagree" & !isTRUE(df$.pinned), na.rm = TRUE),
    n_agree_caveat = sum(df$consensus_status == "agree_caveat", na.rm = TRUE),
    n_single = sum(df$consensus_status == "single", na.rm = TRUE),
    n_error = sum(df$consensus_status == "error", na.rm = TRUE),
    n_manual = sum(df$consensus_status == "manual", na.rm = TRUE),
    n_unresolvable = sum(df$consensus_status == "unresolvable", na.rm = TRUE)
  )
}

#' Review Results Module - UI
#'
#' @param id Module namespace ID
#'
#' @return UI elements for review results tab
mod_review_results_ui <- function(id) {
  ns <- NS(id)

  # Resolution dropdown JavaScript (namespace-aware)
  resolution_js <- tags$script(HTML(sprintf("
    $(document).on('change', '.resolve-select', function() {
      var row = $(this).data('row');
      var column = $(this).val();
      if (column && column !== '') {
        Shiny.setInputValue('%s', {row: row, column: column}, {priority: 'event'});
      }
    });
  ", ns("resolve_row_choice"))))

  tagList(
    resolution_js,

    # Content when curation completed
    conditionalPanel(
      condition = paste0("output['", ns("curation_completed"), "']"),

      # Statistics value boxes at top
      uiOutput(ns("curation_stats")),

      # QC statistics (conditional on qc_results being available)
      uiOutput(ns("qc_stats")),

      # En masse priority controls
      div(
        class = "card mb-3",
        div(class = "card-header", "Column Priority (Bulk Resolution)"),
        div(
          class = "card-body",
          uiOutput(ns("priority_controls")),
          actionButton(ns("apply_priority"), "Apply Priority", class = "btn-warning btn-sm mt-2")
        )
      ),

      # QC summary card (conditional on unhandled characters)
      uiOutput(ns("qc_summary_card")),

      # Header with Download button top-right and action buttons
      div(
        class = "d-flex justify-content-between align-items-center mb-3 mt-3",
        h4("Curated Results"),
        div(
          class = "d-flex gap-2",
          actionButton(
            ns("filter_errors"),
            "Show Errors",
            icon = icon("filter"),
            class = "btn-sm btn-outline-secondary"
          ),
          shinyjs::hidden(
            actionButton(
              ns("retag_selected"),
              "Re-tag Selected",
              icon = icon("tags"),
              class = "btn-sm btn-warning"
            )
          ),
          shinyjs::hidden(
            actionButton(
              ns("validate_all"),
              "Validate All",
              icon = icon("check"),
              class = "btn-sm btn-success"
            )
          ),
          actionButton(
            ns("rerun_qc"),
            "Re-run QC",
            icon = icon("arrows-rotate"),
            class = "btn-sm btn-outline-secondary"
          ),
          downloadButton(
            ns("download_curated"),
            "Download Excel",
            class = "btn-primary"
          )
        )
      ),

      DTOutput(ns("curation_table"))
    ),

    # Empty state when curation not completed
    conditionalPanel(
      condition = paste0("!output['", ns("curation_completed"), "']"),
      div(
        class = "text-center text-muted py-5",
        bsicons::bs_icon("hourglass-split", size = "3em"),
        h4("No results yet"),
        p("Run curation first to see results here.")
      )
    )
  )
}

#' Review Results Module - Server
#'
#' @param id Module namespace ID
#' @param data_store Reactive values store from main app
#'
#' @return NULL (module has no return values)
mod_review_results_server <- function(id, data_store) {
  moduleServer(id, function(input, output, session) {

    # Curation statistics
    output$curation_stats <- renderUI({
      req(data_store$consensus_summary, data_store$resolution_state)

      summary <- data_store$consensus_summary

      # Calculate match rate from resolution_state
      total_rows <- nrow(data_store$resolution_state)
      matched_rows <- sum(!is.na(data_store$resolution_state$consensus_dtxsid))
      match_rate <- round((matched_rows / total_rows) * 100, 1)

      resolved <- summary$n_agree + (summary$n_agree_caveat %||% 0) +
        (summary$n_single %||% 0) + (summary$n_manual %||% 0)
      errors <- (summary$n_error %||% 0) + (summary$n_unresolvable %||% 0)

      layout_columns(
        col_widths = c(3, 3, 3, 3),
        value_box(
          title = "Resolved",
          value = resolved,
          showcase = bsicons::bs_icon("check-circle-fill"),
          theme = "success"
        ),
        value_box(
          title = "Disagree",
          value = summary$n_disagree,
          showcase = bsicons::bs_icon("x-circle-fill"),
          theme = "danger"
        ),
        value_box(
          title = "Errors",
          value = errors,
          showcase = bsicons::bs_icon("exclamation-triangle-fill"),
          theme = "warning"
        ),
        value_box(
          title = "Match Rate",
          value = paste0(match_rate, "%"),
          showcase = bsicons::bs_icon("percent"),
          theme = "info"
        )
      )
    })

    # QC statistics value boxes
    output$qc_stats <- renderUI({
      req(data_store$qc_results)

      qc_results <- data_store$qc_results

      # Determine themes based on counts
      rows_theme <- if (qc_results$rows_with_non_ascii == 0) "success" else "warning"
      chars_theme <- if (length(qc_results$unhandled_chars) == 0) "success" else "info"

      layout_columns(
        col_widths = c(6, 6),
        value_box(
          title = "Rows with Non-ASCII",
          value = qc_results$rows_with_non_ascii,
          showcase = bsicons::bs_icon("exclamation-circle"),
          theme = rows_theme
        ),
        value_box(
          title = "Unhandled Characters",
          value = length(qc_results$unhandled_chars),
          showcase = bsicons::bs_icon("question-circle"),
          theme = chars_theme
        )
      )
    })

    # QC summary card (only show if unhandled characters exist)
    output$qc_summary_card <- renderUI({
      req(data_store$qc_results)

      qc_results <- data_store$qc_results

      # Return NULL if no unhandled characters
      if (length(qc_results$unhandled_chars) == 0) {
        return(NULL)
      }

      # Build list of unhandled characters
      char_items <- lapply(names(qc_results$unhandled_chars), function(codepoint) {
        char_info <- qc_results$unhandled_chars[[codepoint]]
        tags$li(
          sprintf("%s (%s) found in %d rows", codepoint, char_info$char, char_info$count)
        )
      })

      div(
        class = "card border-warning mb-3",
        div(
          class = "card-header bg-warning text-dark",
          bsicons::bs_icon("exclamation-triangle"),
          " QC Warning: Unmapped Unicode Characters"
        ),
        div(
          class = "card-body",
          tags$ul(char_items)
        ),
        div(
          class = "card-footer text-muted small",
          "These characters will remain in your exported data."
        )
      )
    })

    # Curation results table
    output$curation_table <- renderDT(server = FALSE, {
      req(data_store$resolution_state, data_store$dtxsid_cols)

      df <- data_store$resolution_state
      dtxsid_cols <- data_store$dtxsid_cols

      # Ensure consensus_status is a factor with ordered levels (enables dropdown filter)
      df$consensus_status <- factor(
        df$consensus_status,
        levels = c("agree", "agree_caveat", "single", "disagree", "error", "manual", "unresolvable")
      )

      # Derive Match Type from source_tier columns
      # Per user decision: show tier only, not which tagged column produced the match
      tier_label_map <- c(
        "exact" = "Exact Match",
        "cas" = "CAS Lookup",
        "starts_with" = "Starts-With",
        "miss" = "No Match",
        "cas_no_match" = "No Match",
        "cas_invalid" = "No Match"
      )

      df$match_type <- sapply(seq_len(nrow(df)), function(i) {
        # Strategy: find the source_tier of the column that provided consensus_dtxsid
        tier_cols <- grep("^source_tier_", names(df), value = TRUE)

        if (length(tier_cols) == 0) return("Unknown")

        # If consensus_dtxsid exists, find which column provided it
        if (!is.na(df$consensus_dtxsid[i])) {
          # Check each source_tier column for a successful match
          for (tc in tier_cols) {
            tier_val <- df[[tc]][i]
            if (!is.na(tier_val) && tier_val %in% c("exact", "cas", "starts_with")) {
              label <- tier_label_map[tier_val]
              if (!is.na(label)) return(label)
            }
          }
        }

        # No consensus_dtxsid: check if all tiers are miss/error
        all_tiers <- sapply(tier_cols, function(tc) df[[tc]][i])
        all_tiers <- all_tiers[!is.na(all_tiers)]

        if (length(all_tiers) == 0) return("No Match")

        # Pick first non-miss tier if any
        for (tv in all_tiers) {
          if (tv %in% c("exact", "cas", "starts_with")) {
            return(tier_label_map[tv])
          }
        }

        return("No Match")
      })

      # Convert match_type to factor for dropdown filter
      df$match_type <- factor(df$match_type, levels = c("Exact Match", "CAS Lookup", "Starts-With", "No Match"))

      # Position match_type after consensus columns but before Resolution
      df <- dplyr::relocate(df, match_type, .after = consensus_status)

      # Add QC flag column if QC results are available
      if (!is.null(data_store$qc_results) && length(data_store$qc_results$row_indices) > 0) {
        df$qc_flag <- NA_character_
        df$qc_flag[data_store$qc_results$row_indices] <- "WARN: non-ASCII"
        # Position qc_flag after match_type
        df <- dplyr::relocate(df, qc_flag, .after = match_type)
      }

      # Build Resolution column with enhanced context
      df$Resolution <- sapply(seq_len(nrow(df)), function(i) {
        status <- as.character(df$consensus_status[i])

        if (status %in% c("agree", "agree_caveat", "single")) {
          # Static display with checkmark for rows that have a DTXSID
          dtxsid <- df$consensus_dtxsid[i]
          if (!is.na(dtxsid)) {
            # Find preferredName from any available column
            pref_cols <- grep("^preferredName_", names(df), value = TRUE)
            pref_name <- NA_character_
            for (pc in pref_cols) {
              if (!is.na(df[[pc]][i])) { pref_name <- df[[pc]][i]; break }
            }
            if (!is.na(pref_name)) {
              paste0("\u2705 ", htmltools::htmlEscape(dtxsid), " \u2014 ", htmltools::htmlEscape(pref_name))
            } else {
              paste0("\u2705 ", htmltools::htmlEscape(dtxsid))
            }
          } else {
            ""
          }
        } else if (status == "disagree") {
          if (isTRUE(df$.pinned[i])) {
            # Pinned: show pin icon with resolved value and name
            dtxsid <- df$consensus_dtxsid[i]
            if (!is.na(dtxsid)) {
              pref_cols <- grep("^preferredName_", names(df), value = TRUE)
              pref_name <- NA_character_
              for (pc in pref_cols) {
                if (!is.na(df[[pc]][i])) { pref_name <- df[[pc]][i]; break }
              }
              if (!is.na(pref_name)) {
                paste0("\U0001F4CC ", htmltools::htmlEscape(dtxsid), " \u2014 ", htmltools::htmlEscape(pref_name))
              } else {
                paste0("\U0001F4CC ", htmltools::htmlEscape(dtxsid))
              }
            } else {
              paste0("\U0001F4CC (None selected)")
            }
          } else {
            # Unpinned disagree: dropdown with enhanced options
            options <- get_resolution_options(df, i, dtxsid_cols, enrichment_cache = data_store$enrichment_cache)
            if (length(options) > 0) {
              # Options already sorted by rank from get_resolution_options
              options_html <- paste0(
                sapply(names(options), function(col) {
                  opt <- options[[col]]
                  label <- if (!is.na(opt$preferredName)) {
                    paste0(htmltools::htmlEscape(opt$dtxsid), " \u2014 ", htmltools::htmlEscape(opt$preferredName))
                  } else {
                    htmltools::htmlEscape(opt$dtxsid)
                  }
                  paste0('<option value="', htmltools::htmlEscape(col), '">', label, '</option>')
                }),
                collapse = ""
              )
              paste0(
                '<select class="resolve-select form-select form-select-sm" data-row="', i, '">',
                '<option value="">Select...</option>',
                options_html,
                '<option value="__none__">None (skip this row)</option>',
                '</select>'
              )
            } else {
              ""
            }
          }
        } else if (status == "manual") {
          # Manual entry: show checkmark + DTXSID + preferredName + manual badge
          dtxsid <- df$consensus_dtxsid[i]
          pref_name <- if ("manual_preferredName" %in% names(df)) df$manual_preferredName[i] else NA_character_
          # Fall back to auto preferredName columns if manual not available
          if (is.na(pref_name)) {
            pref_cols <- grep("^preferredName_", names(df), value = TRUE)
            for (pc in pref_cols) {
              if (!is.na(df[[pc]][i])) { pref_name <- df[[pc]][i]; break }
            }
          }
          manual_badge <- '<span class="badge bg-info ms-1" style="font-size:0.7em;">manual</span>'
          if (!is.na(dtxsid) && !is.na(pref_name)) {
            paste0("\u2705 ", htmltools::htmlEscape(dtxsid), " \u2014 ", htmltools::htmlEscape(pref_name), " ", manual_badge)
          } else if (!is.na(dtxsid)) {
            paste0("\u2705 ", htmltools::htmlEscape(dtxsid), " ", manual_badge)
          } else {
            ""
          }
        } else if (status == "unresolvable") {
          # Unresolvable: show warning icon
          "\u26A0\uFE0F Auto-curation failed"
        } else if (status == "error") {
          ""
        } else {
          # other status
          ""
        }
      })

      # Apply error filter if active
      display_indices <- seq_len(nrow(df))
      if (isTRUE(data_store$error_filter_active)) {
        display_indices <- which(df$consensus_status %in% c("error", "unresolvable"))
        df_display <- df[display_indices, , drop = FALSE]
      } else {
        df_display <- df
      }
      # Store mapping for row selection (filtered row -> original row)
      data_store$display_row_map <- display_indices

      # --- Three-tier column visibility ---

      # Tier 1: Always hidden (permanently, excluded from colvis menu)
      always_hidden <- c(
        dtxsid_cols,
        grep("^preferredName_", names(df), value = TRUE),
        grep("^searchName_", names(df), value = TRUE),
        grep("^rank_", names(df), value = TRUE),
        grep("^source_tier_", names(df), value = TRUE),
        ".pinned",
        ".manual_entry",
        "manual_preferredName"
      )
      always_hidden_idx <- which(names(df) %in% always_hidden) - 1

      # Tier 2: Hidden by default, toggleable via colvis (untagged original columns)
      tagged_col_names <- names(data_store$column_tags)
      all_original_cols <- names(data_store$clean)
      untagged_cols <- setdiff(
        all_original_cols[all_original_cols %in% names(df)],
        tagged_col_names
      )
      untagged_idx <- which(names(df) %in% untagged_cols) - 1

      # Combined: both tiers hidden initially
      all_hidden_idx <- unique(c(always_hidden_idx, untagged_idx))

      # Column indices for badge rendering (0-indexed)
      match_type_idx <- which(names(df) == "match_type") - 1
      consensus_idx <- which(names(df) == "consensus_status") - 1
      consensus_dtxsid_idx <- which(names(df) == "consensus_dtxsid") - 1

      # Prepare display dataframe (after filtering)
      display_df <- df_display

      # Determine row selection mode based on filter state
      selection_mode <- if (isTRUE(data_store$error_filter_active)) "multiple" else "none"

      # Create DT table with colvis, badges, and column visibility
      dt <- datatable(
        display_df,
        selection = selection_mode,
        editable = list(
          target = "cell",
          disable = list(
            columns = setdiff(seq_len(ncol(display_df)) - 1, consensus_dtxsid_idx)
          )
        ),
        options = list(
          pageLength = 25,
          scrollX = TRUE,
          dom = 'Bfrtip',
          buttons = list(
            'copy', 'csv',
            list(
              extend = 'colvis',
              text = 'Toggle Columns',
              columns = as.list(untagged_idx)
            )
          ),
          columnDefs = list(
            list(visible = FALSE, targets = as.list(all_hidden_idx)),
            # Match type badge rendering via JS callback
            list(
              targets = match_type_idx,
              render = JS(
                "function(data, type, row, meta) {",
                "  if (type !== 'display') return data;",
                "  var colors = {",
                "    'Exact Match': '#28a745',",
                "    'CAS Lookup': '#007bff',",
                "    'Starts-With': '#ffc107',",
                "    'No Match': '#dc3545'",
                "  };",
                "  var textColors = { 'Starts-With': '#212529' };",
                "  var bg = colors[data] || '#6c757d';",
                "  var fg = textColors[data] || '#fff';",
                "  return '<span style=\"background:' + bg + ';color:' + fg +",
                "    ';padding:2px 8px;border-radius:4px;font-weight:600;font-size:0.85em;display:inline-block;\">' +",
                "    data + '</span>';",
                "}"
              )
            ),
            # Consensus status badge rendering via JS callback
            list(
              targets = consensus_idx,
              render = JS(
                "function(data, type, row, meta) {",
                "  if (type !== 'display') return data;",
                "  var colors = {",
                "    'agree': '#28a745',",
                "    'agree_caveat': '#17a2b8',",
                "    'single': '#6c757d',",
                "    'disagree': '#fd7e14',",
                "    'error': '#343a40',",
                "    'manual': '#6f42c1',",
                "    'unresolvable': '#721c24'",
                "  };",
                "  var bg = colors[data] || '#6c757d';",
                "  return '<span style=\"background:' + bg + ';color:#fff;padding:2px 8px;border-radius:4px;font-weight:600;font-size:0.85em;display:inline-block;\">' +",
                "    data + '</span>';",
                "}"
              )
            )
          )
        ),
        extensions = 'Buttons',
        class = 'cell-border stripe hover compact',
        rownames = FALSE,
        filter = "top",
        escape = FALSE  # Allow HTML in Resolution column
      )

      # Add color-coded row backgrounds (error rows get light pink)
      dt <- dt %>% formatStyle(
        'consensus_status',
        target = 'row',
        backgroundColor = styleEqual(
          c("agree", "agree_caveat", "disagree", "single", "error", "manual", "unresolvable"),
          c(
            "rgba(40, 167, 69, 0.08)",
            "rgba(40, 167, 69, 0.05)",
            "rgba(220, 53, 69, 0.08)",
            "rgba(108, 117, 125, 0.05)",
            "rgba(220, 53, 69, 0.12)",
            "rgba(111, 66, 193, 0.08)",
            "rgba(114, 28, 36, 0.12)"
          )
        )
      )

      # Add QC flag highlighting (yellow background for rows with non-ASCII)
      if ("qc_flag" %in% names(display_df)) {
        dt <- dt %>% formatStyle(
          'qc_flag',
          target = 'row',
          backgroundColor = styleEqual("WARN: non-ASCII", "#fff3cd")
        )
      }

      dt
    })

    # Priority Controls UI
    output$priority_controls <- renderUI({
      req(data_store$priority_order)

      priority <- data_store$priority_order

      # Generate UI for each column in priority order
      controls <- lapply(seq_along(priority), function(i) {
        col_name <- priority[i]
        display_name <- sub("^dtxsid_", "", col_name)

        div(
          class = "d-flex align-items-center mb-2",
          tags$span(
            class = "badge bg-secondary me-2",
            style = "width: 30px;",
            i
          ),
          tags$span(
            class = "flex-grow-1",
            display_name
          ),
          actionButton(
            session$ns(paste0("priority_up_", i)),
            "",
            icon = icon("arrow-up"),
            class = "btn-sm btn-outline-secondary me-1",
            disabled = if (i == 1) TRUE else NULL
          ),
          actionButton(
            session$ns(paste0("priority_down_", i)),
            "",
            icon = icon("arrow-down"),
            class = "btn-sm btn-outline-secondary",
            disabled = if (i == length(priority)) TRUE else NULL
          )
        )
      })

      do.call(tagList, controls)
    })

    # Handle priority up/down buttons dynamically
    observe({
      req(data_store$priority_order)
      priority <- data_store$priority_order

      lapply(seq_along(priority), function(i) {
        # Up button
        observeEvent(input[[paste0("priority_up_", i)]], {
          if (i > 1) {
            new_priority <- data_store$priority_order
            # Swap with previous
            temp <- new_priority[i - 1]
            new_priority[i - 1] <- new_priority[i]
            new_priority[i] <- temp
            data_store$priority_order <- new_priority
          }
        }, ignoreInit = TRUE)

        # Down button
        observeEvent(input[[paste0("priority_down_", i)]], {
          if (i < length(data_store$priority_order)) {
            new_priority <- data_store$priority_order
            # Swap with next
            temp <- new_priority[i + 1]
            new_priority[i + 1] <- new_priority[i]
            new_priority[i] <- temp
            data_store$priority_order <- new_priority
          }
        }, ignoreInit = TRUE)
      })
    })

    # Handle inline cell editing for manual DTXSID entry
    observeEvent(input$curation_table_cell_edit, {
      info <- input$curation_table_cell_edit
      display_row <- info$row  # 1-based index in displayed table
      new_value <- trimws(as.character(info$value))

      # Map displayed row to original row index when filter is active
      row_map <- isolate(data_store$display_row_map)
      if (!is.null(row_map) && display_row <= length(row_map)) {
        row_idx <- row_map[display_row]
      } else {
        row_idx <- display_row
      }

      # Only allow edits on error/unresolvable rows
      current_status <- as.character(isolate(data_store$resolution_state)$consensus_status[row_idx])
      if (!current_status %in% c("error", "unresolvable")) {
        showNotification("Only error/unresolvable rows can be manually edited", type = "warning")
        return()
      }

      # Basic DTXSID format validation
      if (!grepl("^DTXSID\\d+$", new_value, ignore.case = TRUE)) {
        showNotification(
          paste0("Invalid format: ", new_value, ". Expected: DTXSIDxxxxxxx"),
          type = "warning", duration = 5
        )
        return()
      }

      # Queue for bulk validation only — don't update resolution_state here.
      # The cell value is already visually updated by DT's inline editor.
      # resolution_state gets updated when "Validate All" is clicked.
      data_store$manual_queue[[as.character(row_idx)]] <- new_value

      showNotification(paste0("Row ", row_idx, " queued for validation"), type = "message", duration = 2)
    })

    # Toggle Validate All button visibility based on queue length
    observe({
      has_queued <- length(data_store$manual_queue) > 0
      if (has_queued) {
        shinyjs::show("validate_all")
      } else {
        shinyjs::hide("validate_all")
      }
    })

    # Handle per-row resolution dropdown
    observeEvent(input$resolve_row_choice, {
      req(data_store$resolution_state, data_store$dtxsid_cols)

      choice <- input$resolve_row_choice
      row_idx <- choice$row
      chosen_column <- choice$column

      tryCatch({
        if (chosen_column == "__none__") {
          # "None" selected: pin the row without setting a DTXSID
          updated_df <- data_store$resolution_state
          updated_df <- init_resolution_state(updated_df)
          updated_df$.pinned[row_idx] <- TRUE
          # Leave consensus_dtxsid as-is (NA)
          data_store$resolution_state <- updated_df

          showNotification(
            paste0("Row ", row_idx, " marked as skipped (None)"),
            type = "message"
          )
        } else {
          # Normal resolution: call resolve_row function
          updated_df <- resolve_row(
            data_store$resolution_state,
            row_idx,
            chosen_column,
            data_store$dtxsid_cols
          )

          # Update state
          data_store$resolution_state <- updated_df

          showNotification(
            paste0("Row ", row_idx, " resolved using ", sub("^dtxsid_", "", chosen_column)),
            type = "message"
          )
        }

        # Recalculate consensus summary
        updated_df <- data_store$resolution_state
        data_store$consensus_summary <- recalc_consensus_summary(updated_df)
      }, error = function(e) {
        showNotification(
          paste0("Error resolving row: ", e$message),
          type = "error"
        )
      })
    })

    # Handle Validate All button for manual DTXSID entries
    observeEvent(input$validate_all, {
      queue <- data_store$manual_queue
      if (length(queue) == 0) {
        showNotification("No manual entries to validate", type = "warning", duration = 3)
        return()
      }

      row_indices <- as.integer(names(queue))
      all_dtxsids <- unlist(queue)
      unique_dtxsids <- unique(all_dtxsids)

      # Disable button during validation
      shinyjs::disable("validate_all")
      on.exit(shinyjs::enable("validate_all"))

      withProgress(message = "Validating manual DTXSIDs...", value = 0, {
        incProgress(0.1, detail = sprintf("Validating %d entries...", length(unique_dtxsids)))

        validation_results <- validate_manual_dtxsids(unique_dtxsids)

        incProgress(0.6, detail = "Updating results...")

        updated_df <- data_store$resolution_state
        n_valid <- 0
        n_invalid <- 0
        invalid_details <- c()

        for (i in seq_along(row_indices)) {
          row_idx <- row_indices[i]
          entered_dtxsid <- queue[[as.character(row_idx)]]

          val_row <- validation_results[validation_results$searchValue == entered_dtxsid, ]

          if (nrow(val_row) > 0 && isTRUE(val_row$is_valid[1])) {
            # Valid: update consensus
            updated_df$consensus_dtxsid[row_idx] <- val_row$dtxsid[1]
            updated_df$consensus_status[row_idx] <- "manual"
            updated_df$consensus_source[row_idx] <- "manual_entry"
            updated_df$.manual_entry[row_idx] <- TRUE

            # Store preferredName in manual_preferredName column
            if (!"manual_preferredName" %in% names(updated_df)) {
              updated_df$manual_preferredName <- NA_character_
            }
            updated_df$manual_preferredName[row_idx] <- val_row$preferredName[1]

            n_valid <- n_valid + 1
          } else {
            # Invalid: keep error status, track for feedback
            invalid_details <- c(invalid_details,
              sprintf("Row %d: %s", row_idx, entered_dtxsid))
            n_invalid <- n_invalid + 1
          }
        }

        data_store$resolution_state <- updated_df

        # Clear queue
        data_store$manual_queue <- list()

        incProgress(0.3, detail = "Done")
      })

      # Summary notification
      msg <- sprintf("Validation complete: %d validated, %d failed", n_valid, n_invalid)
      showNotification(msg,
        type = if (n_invalid > 0) "warning" else "message",
        duration = 8
      )

      # Detail notification for failures
      if (n_invalid > 0) {
        showNotification(
          paste("Failed entries:", paste(invalid_details, collapse = "; ")),
          type = "error",
          duration = NULL  # Stays until dismissed
        )
      }

      # Update consensus summary to reflect manual resolutions
      updated_df <- data_store$resolution_state
      data_store$consensus_summary <- recalc_consensus_summary(updated_df)
    })

    # Handle Re-run QC button
    observeEvent(input$rerun_qc, {
      req(data_store$resolution_state)

      withProgress(message = "Running QC checks...", value = 0, {
        incProgress(0.3, detail = "Scanning for non-ASCII characters...")

        # Run QC on current resolution state
        qc_results <- perform_unicode_qc(data_store$resolution_state)
        data_store$qc_results <- qc_results

        incProgress(0.7, detail = "Complete")

        # Show result summary notification
        if (qc_results$rows_with_non_ascii == 0) {
          showNotification(
            "QC complete: No non-ASCII characters found",
            type = "message",
            duration = 3
          )
        } else {
          showNotification(
            sprintf(
              "QC complete: %d rows contain non-ASCII characters (%d unique characters)",
              qc_results$rows_with_non_ascii,
              length(qc_results$unhandled_chars)
            ),
            type = "warning",
            duration = 5
          )
        }
      })
    })

    # Handle en masse priority application
    observeEvent(input$apply_priority, {
      req(data_store$resolution_state, data_store$priority_order, data_store$dtxsid_cols)

      tryCatch({
        # Count disagree rows before
        before_count <- sum(
          data_store$resolution_state$consensus_status == "disagree" &
          !isTRUE(data_store$resolution_state$.pinned),
          na.rm = TRUE
        )

        # Apply priority chain
        updated_df <- apply_priority_chain(
          data_store$resolution_state,
          data_store$priority_order,
          data_store$dtxsid_cols
        )

        # Update state
        data_store$resolution_state <- updated_df

        # Count disagree rows after
        after_count <- sum(
          updated_df$consensus_status == "disagree" &
          !isTRUE(updated_df$.pinned),
          na.rm = TRUE
        )

        resolved_count <- before_count - after_count

        # Recalculate consensus summary
        data_store$consensus_summary <- recalc_consensus_summary(updated_df)

        showNotification(
          paste0("Applied priority chain: ", resolved_count, " rows resolved"),
          type = "message"
        )
      }, error = function(e) {
        showNotification(
          paste0("Error applying priority: ", e$message),
          type = "error"
        )
      })
    })

    # Export Functionality
    output$download_curated <- downloadHandler(
      filename = function() {
        # Generate filename with timestamp
        file_base <- if (!is.null(data_store$file_info)) {
          tools::file_path_sans_ext(data_store$file_info$name)
        } else {
          "curated_data"
        }
        paste0(file_base, "_curated_", format(Sys.Date(), "%Y%m%d"), ".xlsx")
      },
      content = function(file) {
        req(data_store$resolution_state, data_store$consensus_summary)

        # Validate curated data size before export
        tryCatch(
          {
            validate_excel_size(data_store$resolution_state, "Curated Data")
          },
          error = function(e) {
            showNotification(
              paste("Export blocked:", conditionMessage(e)),
              type = "error",
              duration = NULL
            )
            return()
          }
        )

        # Build all 7 export sheets
        sheets <- build_export_sheets(
          raw = data_store$raw,
          resolution_state = data_store$resolution_state,
          consensus_summary = data_store$consensus_summary,
          cleaning_audit = data_store$cleaning_audit,
          reference_lists = data_store$reference_lists,
          column_tags = data_store$column_tags,
          detection = data_store$detection,
          file_info = data_store$file_info,
          enrichment_cache = data_store$enrichment_cache
        )

        # Write to Excel
        writexl::write_xlsx(sheets, path = file)
      }
    )

    # --- Error Recovery Observers ---

    # Filter toggle observer
    observeEvent(input$filter_errors, {
      data_store$error_filter_active <- !data_store$error_filter_active

      # Update button label
      updateActionButton(
        session, "filter_errors",
        label = if (data_store$error_filter_active) "Show All" else "Show Errors"
      )
    })

    # Track selected rows and show/hide retag button
    observe({
      selected <- input$curation_table_rows_selected
      if (!is.null(selected) && length(selected) > 0 && isTRUE(data_store$error_filter_active)) {
        # Map filtered indices back to original indices
        data_store$selected_error_rows <- data_store$display_row_map[selected]
        shinyjs::show("retag_selected")
      } else {
        data_store$selected_error_rows <- NULL
        shinyjs::hide("retag_selected")
      }
    })

    # Show re-tag modal
    observeEvent(input$retag_selected, {
      req(data_store$selected_error_rows, data_store$clean, data_store$column_tags)

      n_selected <- length(data_store$selected_error_rows)
      original_cols <- names(data_store$clean)

      # Build modal content with column tag selectors
      modal_content <- tagList(
        p(sprintf("Re-assign column tags for %d selected row(s).", n_selected)),
        p("Change tags below and click 'Apply & Re-curate' to run the full pipeline on selected rows."),
        hr(),
        lapply(original_cols, function(col) {
          current_tag <- data_store$column_tags[[col]] %||% ""
          div(
            class = "mb-3",
            selectInput(
              inputId = session$ns(paste0("retag_col_", col)),
              label = col,
              choices = c("(none)" = "", "Name" = "Name", "CASRN" = "CASRN", "Other" = "Other"),
              selected = current_tag,
              width = "100%"
            )
          )
        })
      )

      showModal(modalDialog(
        title = sprintf("Re-tag %d Selected Rows", n_selected),
        modal_content,
        footer = tagList(
          tags$button(
            "Apply & Re-curate",
            class = "btn btn-primary",
            onclick = sprintf(
              "var tags = {};
              document.querySelectorAll('select[id^=\"%s\"]').forEach(function(el) {
                tags[el.id.replace('%s', '')] = el.value;
              });
              Shiny.setInputValue('%s', {tags: tags, t: Math.random()});",
              session$ns("retag_col_"),
              session$ns("retag_col_"),
              session$ns("apply_retag_trigger")
            )
          ),
          modalButton("Cancel")
        ),
        size = "l",
        easyClose = FALSE
      ))
    })

    # Apply re-tag and re-curate handler
    observeEvent(input$apply_retag_trigger, {
      selected_rows <- data_store$selected_error_rows

      if (is.null(selected_rows) || length(selected_rows) == 0) {
        showNotification("No rows selected. Please select error rows first.", type = "warning")
        removeModal()
        return()
      }

      # Read tags from JS trigger payload (Shiny modal inputs don't bind reliably)
      trigger_data <- input$apply_retag_trigger
      new_tags <- list()
      if (!is.null(trigger_data$tags)) {
        for (col in names(trigger_data$tags)) {
          tag_val <- trigger_data$tags[[col]]
          if (!is.null(tag_val) && tag_val != "") {
            new_tags[[col]] <- tag_val
          }
        }
      }

      # Now safe to close modal
      removeModal()

      if (length(new_tags) == 0) {
        showNotification("No columns tagged. Please select at least one tag.", type = "warning")
        return()
      }

      # Check if tags changed from original
      tags_changed <- !identical(sort(names(new_tags)), sort(names(data_store$column_tags))) ||
                      !identical(new_tags[sort(names(new_tags))], data_store$column_tags[sort(names(data_store$column_tags))])

      # Extract subset of clean data for selected rows
      subset_data <- data_store$clean[selected_rows, , drop = FALSE]

      # Run full curation pipeline on subset (button is in modal which is already closed)

      withProgress(message = "Re-curating selected rows...", value = 0, {
        retry_result <- tryCatch({
          run_curation_pipeline(
            clean_data = subset_data,
            column_tags = new_tags,
            progress_callback = function(stage, msg) {
              incProgress(0.2, detail = msg)
            }
          )
        }, error = function(e) {
          showNotification(paste("Re-curation failed:", e$message), type = "error", duration = NULL)
          NULL
        })

        if (!is.null(retry_result)) {
          incProgress(0.3, detail = "Merging results...")

          # Merge retry results back into main state
          updated_state <- merge_retry_results(
            original_state = data_store$resolution_state,
            retry_results = retry_result$results,
            selected_row_indices = selected_rows,
            tags_changed = tags_changed
          )

          data_store$resolution_state <- updated_state

          # Update dtxsid_cols if new tag columns were added
          if (tags_changed) {
            data_store$dtxsid_cols <- grep("^dtxsid_", names(updated_state), value = TRUE)
          }

          # Count results
          n_resolved <- sum(updated_state$consensus_status[selected_rows] %in%
            c("agree", "agree_caveat", "single", "manual"), na.rm = TRUE)
          n_still_error <- sum(updated_state$consensus_status[selected_rows] == "unresolvable", na.rm = TRUE)

          showNotification(
            sprintf("Re-curation complete: %d resolved, %d unresolvable", n_resolved, n_still_error),
            type = if (n_still_error > 0) "warning" else "message",
            duration = 8
          )
        }
      })

      # Reset filter and selection state
      data_store$error_filter_active <- FALSE
      data_store$selected_error_rows <- NULL
      updateActionButton(session, "filter_errors", label = "Show Errors")

      # Update consensus summary
      updated_df <- data_store$resolution_state
      data_store$consensus_summary <- recalc_consensus_summary(updated_df)
    })

    # Curation completed indicator
    output$curation_completed <- reactive({
      !is.null(data_store$curation_status) && data_store$curation_status == "completed"
    })
    outputOptions(output, "curation_completed", suspendWhenHidden = FALSE)
  })
}
