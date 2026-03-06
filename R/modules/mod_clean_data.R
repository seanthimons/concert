# Clean Data Module
# Data cleaning execution with progress tracking and audit trail display

#' Clean Data Module - UI
#'
#' @param id Module namespace ID
#'
#' @return UI elements for clean data tab
mod_clean_data_ui <- function(id) {
  ns <- NS(id)

  tagList(
    # Content when data is loaded
    conditionalPanel(
      condition = paste0("output['", ns("has_data"), "']"),

      actionButton(
        ns("run_cleaning"),
        "Run Cleaning",
        class = "btn-success btn-lg",
        icon = icon("magic")
      ),

      uiOutput(ns("cleaning_summary")),

      DT::dataTableOutput(ns("cleaned_table")),

      uiOutput(ns("audit_section")),

      uiOutput(ns("multi_cas_section"))
    ),

    # Empty state when no data loaded
    conditionalPanel(
      condition = paste0("!output['", ns("has_data"), "']"),
      div(
        class = "text-center text-muted py-5",
        bsicons::bs_icon("eraser", size = "3em"),
        h4("No columns tagged"),
        p("Tag your columns first, then run cleaning.")
      )
    )
  )
}

#' Clean Data Module - Server
#'
#' @param id Module namespace ID
#' @param data_store Reactive values store from main app
#' @param on_cleaning_complete Callback function to execute after cleaning completes (for navigation)
#'
#' @return Reactive list with cleaning indicators
mod_clean_data_server <- function(id, data_store, on_cleaning_complete = NULL) {
  moduleServer(id, function(input, output, session) {

    # Has data indicator for conditionalPanel
    output$has_data <- reactive({
      !is.null(data_store$column_tags) && length(data_store$column_tags) > 0
    })
    outputOptions(output, "has_data", suspendWhenHidden = FALSE)

    # Run cleaning button
    observeEvent(input$run_cleaning, {
      req(data_store$clean)

      # Disable button during execution
      shinyjs::disable("run_cleaning")

      # Run cleaning with progress tracking and error handling
      tryCatch(
        {
          withProgress(message = "Cleaning data...", value = 0, {
            df <- data_store$clean
            tag_map <- data_store$column_tags
            all_audits <- list()

            incProgress(0.05, detail = "Adding row lineage...")
            df <- inject_row_lineage(df)

            incProgress(0.10, detail = "Converting unicode to ASCII...")
            df_before <- df
            df <- dplyr::mutate(df, dplyr::across(where(is.character), clean_unicode_field))
            all_audits[[length(all_audits) + 1]] <- build_audit_trail(df_before, df, "unicode_to_ascii", function(f) paste0("Unicode to ASCII in ", f))

            incProgress(0.10, detail = "Trimming whitespace...")
            df_before <- df
            df <- dplyr::mutate(df, dplyr::across(where(is.character), clean_text_field))
            all_audits[[length(all_audits) + 1]] <- build_audit_trail(df_before, df, "trim_whitespace_punctuation", function(f) paste0("Trim in ", f))

            new_tags <- list()
            if (!is.null(tag_map) && length(tag_map) > 0) {
              incProgress(0.15, detail = "Normalizing CAS-RNs...")
              cas_result <- normalize_cas_fields(df, tag_map)
              df <- cas_result$cleaned_data
              all_audits[[length(all_audits) + 1]] <- cas_result$audit_trail

              incProgress(0.15, detail = "Rescuing CAS from names...")
              rescue_result <- rescue_cas_from_text(df, tag_map)
              df <- rescue_result$cleaned_data
              all_audits[[length(all_audits) + 1]] <- rescue_result$audit_trail
              new_tags <- rescue_result$new_tags

              incProgress(0.10, detail = "Detecting multi-CAS rows...")
              updated_tag_map <- c(tag_map, new_tags)
              df <- detect_multi_cas(df, updated_tag_map)

              # Name cleaning steps (if Name columns present)
              name_cols <- names(tag_map)[tag_map == "Name"]

              if (length(name_cols) > 0) {
                incProgress(0.10, detail = "Stripping parentheticals...")
                enclosure_result <- strip_terminal_enclosures(df, name_cols)
                df <- enclosure_result$cleaned_data
                all_audits[[length(all_audits) + 1]] <- enclosure_result$audit_trail
                if (length(enclosure_result$new_tags) > 0) {
                  new_tags <- c(new_tags, enclosure_result$new_tags)
                  updated_tag_map <- c(updated_tag_map, enclosure_result$new_tags)
                }

                incProgress(0.05, detail = "Removing quality adjectives...")
                quality_result <- strip_quality_adjectives(df, name_cols)
                df <- quality_result$cleaned_data
                all_audits[[length(all_audits) + 1]] <- quality_result$audit_trail

                incProgress(0.05, detail = "Removing salt references...")
                salt_result <- strip_salt_references(df, name_cols)
                df <- salt_result$cleaned_data
                all_audits[[length(all_audits) + 1]] <- salt_result$audit_trail

                incProgress(0.05, detail = "Removing unspecified suffixes...")
                unspec_result <- strip_terminal_unspecified(df, name_cols)
                df <- unspec_result$cleaned_data
                all_audits[[length(all_audits) + 1]] <- unspec_result$audit_trail

                # Cleanup before second enclosure stripping
                df <- df %>%
                  dplyr::mutate(dplyr::across(dplyr::all_of(name_cols), ~ {
                    .x %>%
                      stringr::str_squish() %>%
                      stringr::str_remove("\\(\\s*\\)\\s*$") %>%
                      stringr::str_trim() %>%
                      stringr::str_remove("[,;-]+$") %>%
                      stringr::str_trim()
                  }))

                # Second pass enclosure stripping
                enclosure_result2 <- strip_terminal_enclosures(df, name_cols)
                df <- enclosure_result2$cleaned_data
                all_audits[[length(all_audits) + 1]] <- enclosure_result2$audit_trail

                incProgress(0.10, detail = "Splitting synonyms...")
                synonym_result <- split_synonyms(df, name_cols, updated_tag_map)
                df <- synonym_result$cleaned_data
                all_audits[[length(all_audits) + 1]] <- synonym_result$audit_trail

                # Final cleanup
                df <- df %>%
                  dplyr::mutate(dplyr::across(dplyr::all_of(name_cols), ~ {
                    .x %>%
                      stringr::str_squish() %>%
                      stringr::str_remove_all("\\(\\s*\\)") %>%
                      stringr::str_trim()
                  }))

                # Remove rows where all name columns are empty or NA
                name_check <- df[, name_cols, drop = FALSE]
                all_empty <- apply(name_check, 1, function(row) {
                  all(is.na(row) | row == "")
                })
                df <- df[!all_empty, ]
              }
            }

            incProgress(0.05, detail = "Finalizing...")
            audit_combined <- dplyr::bind_rows(all_audits)
            data_store$cleaned_data <- df
            data_store$cleaning_audit <- audit_combined
            if (length(new_tags) > 0) {
              data_store$column_tags <- c(data_store$column_tags, new_tags)
            }

            # Show success notification
            n_changes <- nrow(audit_combined)
            showNotification(
              sprintf("Cleaning complete: %d transformations applied", n_changes),
              type = "message",
              duration = 5
            )

            # Call navigation callback if provided
            if (!is.null(on_cleaning_complete)) {
              on_cleaning_complete()
            }
          })
        },
        error = function(e) {
          showNotification(
            paste("Cleaning failed:", e$message),
            type = "error",
            duration = NULL
          )
        },
        finally = {
          # Re-enable button
          shinyjs::enable("run_cleaning")
        }
      )
    })

    # Cleaning summary display
    output$cleaning_summary <- renderUI({
      req(data_store$cleaning_audit, data_store$cleaned_data)

      audit <- data_store$cleaning_audit
      cleaned_data <- data_store$cleaned_data
      n_total <- nrow(audit)

      if (n_total == 0) {
        return(div(
          class = "mb-3 mt-3",
          bslib::value_box(
            title = "All Clean",
            value = "No transformations needed",
            showcase = bsicons::bs_icon("check-circle"),
            theme = "success"
          )
        ))
      }

      # Count by step
      n_unicode <- sum(audit$step == "unicode_to_ascii")
      n_trim <- sum(audit$step == "trim_whitespace_punctuation")
      n_normalize <- sum(audit$step == "normalize_cas")
      n_rescue <- sum(audit$step == "rescue_cas")

      # Count CAS invalid (normalize_cas entries where new_value is NA or "[NA]")
      n_invalid <- sum(audit$step == "normalize_cas" & (audit$new_value == "[NA]" | is.na(audit$new_value)))

      # Count multi-CAS flags
      n_multi_cas <- if ("multi_cas" %in% names(cleaned_data)) sum(cleaned_data$multi_cas, na.rm = TRUE) else 0

      # Count name cleaning steps
      n_parentheticals <- sum(audit$step == "strip_terminal_enclosures")
      n_synonyms <- sum(audit$step == "split_synonyms")
      n_adjectives <- sum(audit$step %in% c("strip_quality_adjectives", "strip_salt_references", "strip_terminal_unspecified"))

      # Check if name cleaning occurred
      has_name_cleaning <- n_parentheticals > 0 || n_synonyms > 0 || n_adjectives > 0

      # Build rows
      row1 <- bslib::layout_columns(
        col_widths = c(4, 4, 4),
        bslib::value_box(
          title = "CAS Rescued",
          value = n_rescue,
          showcase = bsicons::bs_icon("search"),
          theme = "primary"
        ),
        bslib::value_box(
          title = "CAS Normalized",
          value = n_normalize,
          showcase = bsicons::bs_icon("check-circle"),
          theme = "success"
        ),
        bslib::value_box(
          title = "CAS Invalid",
          value = n_invalid,
          showcase = bsicons::bs_icon("x-circle"),
          theme = "danger"
        )
      )

      row2 <- bslib::layout_columns(
        col_widths = c(4, 4, 4),
        bslib::value_box(
          title = "Multi-CAS Flagged",
          value = n_multi_cas,
          showcase = bsicons::bs_icon("flag"),
          theme = "warning"
        ),
        bslib::value_box(
          title = "Unicode Cleaned",
          value = n_unicode,
          showcase = bsicons::bs_icon("globe"),
          theme = "info"
        ),
        bslib::value_box(
          title = "Fields Trimmed",
          value = n_trim,
          showcase = bsicons::bs_icon("scissors"),
          theme = "info"
        )
      )

      # Name cleaning row (only if applicable)
      row3 <- if (has_name_cleaning) {
        bslib::layout_columns(
          col_widths = c(4, 4, 4),
          bslib::value_box(
            title = "Parentheticals Stripped",
            value = n_parentheticals,
            showcase = bsicons::bs_icon("scissors"),
            theme = "info"
          ),
          bslib::value_box(
            title = "Synonyms Split",
            value = n_synonyms,
            showcase = bsicons::bs_icon("list"),
            theme = "primary"
          ),
          bslib::value_box(
            title = "Adjectives Removed",
            value = n_adjectives,
            showcase = bsicons::bs_icon("eraser"),
            theme = "info"
          )
        )
      } else {
        NULL
      }

      div(
        class = "mb-3 mt-3",
        row1,
        row2,
        row3
      )
    })

    # Audit trail section
    output$audit_section <- renderUI({
      req(data_store$cleaning_audit)

      audit <- data_store$cleaning_audit
      n_changes <- nrow(audit)

      if (n_changes == 0) {
        return(NULL)
      }

      bslib::accordion(
        id = session$ns("audit_accordion"),
        open = FALSE,
        bslib::accordion_panel(
          title = sprintf("Cleaning Audit Trail -- %d Changes", n_changes),
          icon = bsicons::bs_icon("file-text"),
          DT::dataTableOutput(session$ns("audit_table"))
        )
      )
    })

    # Audit table
    output$audit_table <- DT::renderDataTable({
      req(data_store$cleaning_audit)

      DT::datatable(
        data_store$cleaning_audit,
        options = list(
          pageLength = 25,
          scrollX = TRUE,
          order = list(list(0, "asc"))
        ),
        filter = "top",
        rownames = FALSE
      )
    })

    # Cleaned data table
    output$cleaned_table <- DT::renderDataTable({
      req(data_store$cleaned_data)

      # Hide internal columns from display
      hidden_cols <- which(names(data_store$cleaned_data) %in% c("original_row_id", "multi_cas", "multi_cas_count")) - 1

      DT::datatable(
        data_store$cleaned_data,
        options = list(
          pageLength = 25,
          scrollX = TRUE,
          columnDefs = list(list(visible = FALSE, targets = hidden_cols))
        ),
        rownames = FALSE
      )
    })

    # Multi-CAS flagged rows section
    output$multi_cas_section <- renderUI({
      req(data_store$cleaned_data)

      cleaned_data <- data_store$cleaned_data

      # Check if multi_cas column exists and has any TRUE values
      if (!("multi_cas" %in% names(cleaned_data))) {
        return(NULL)
      }

      multi_cas_rows <- cleaned_data[cleaned_data$multi_cas == TRUE, ]

      if (nrow(multi_cas_rows) == 0) {
        return(NULL)
      }

      # Show multi-CAS section
      div(
        class = "card mt-4",
        div(
          class = "card-header bg-warning text-dark",
          h5(class = "mb-0", "Multi-CAS Flagged Rows")
        ),
        div(
          class = "card-body",
          p("These rows contain multiple CAS-RNs. Review them and split if they represent separate chemicals."),
          DT::dataTableOutput(ns("multi_cas_table")),
          actionButton(
            ns("split_row"),
            "Split Selected Row",
            class = "btn-warning mt-2",
            icon = icon("scissors")
          )
        )
      )
    })

    # Multi-CAS table
    output$multi_cas_table <- DT::renderDataTable({
      req(data_store$cleaned_data)

      cleaned_data <- data_store$cleaned_data
      multi_cas_rows <- cleaned_data[cleaned_data$multi_cas == TRUE, ]

      DT::datatable(
        multi_cas_rows,
        selection = "single",
        options = list(
          pageLength = 10,
          scrollX = TRUE
        ),
        rownames = FALSE
      )
    })

    # Split row button handler
    observeEvent(input$split_row, {
      req(data_store$cleaned_data)

      # Get selected row from DT
      selected <- input$multi_cas_table_rows_selected

      if (is.null(selected) || length(selected) == 0) {
        showNotification(
          "Please select a row to split",
          type = "warning",
          duration = 3
        )
        return()
      }

      # Get multi-CAS rows
      cleaned_data <- data_store$cleaned_data
      multi_cas_rows <- cleaned_data[cleaned_data$multi_cas == TRUE, ]
      row_to_split <- multi_cas_rows[selected, ]

      # Get all CASRN columns
      tag_map <- data_store$column_tags
      cas_cols <- names(tag_map)[tag_map == "CASRN"]

      # Extract non-NA CAS values
      cas_values <- unlist(row_to_split[cas_cols])
      cas_values <- cas_values[!is.na(cas_values)]

      if (length(cas_values) <= 1) {
        showNotification(
          "This row does not have multiple CAS-RNs to split",
          type = "warning",
          duration = 3
        )
        return()
      }

      # Show confirmation modal
      showModal(modalDialog(
        title = "Confirm Row Split",
        sprintf("This will split the selected row into %d separate rows, one for each CAS-RN:", length(cas_values)),
        tags$ul(
          lapply(cas_values, function(cas) tags$li(cas))
        ),
        footer = tagList(
          modalButton("Cancel"),
          actionButton(ns("confirm_split"), "Confirm Split", class = "btn-warning")
        )
      ))
    })

    # Confirm split handler
    observeEvent(input$confirm_split, {
      req(data_store$cleaned_data)

      # Get selected row
      selected <- input$multi_cas_table_rows_selected
      cleaned_data <- data_store$cleaned_data
      multi_cas_rows <- cleaned_data[cleaned_data$multi_cas == TRUE, ]
      row_to_split <- multi_cas_rows[selected, ]

      # Get all CASRN columns
      tag_map <- data_store$column_tags
      cas_cols <- names(tag_map)[tag_map == "CASRN"]

      # Extract non-NA CAS values
      cas_values <- unlist(row_to_split[cas_cols])
      cas_values <- cas_values[!is.na(cas_values)]

      # Create new rows (one per CAS)
      new_rows <- lapply(seq_along(cas_values), function(i) {
        new_row <- row_to_split
        # Set primary CAS column to this CAS value
        new_row[[cas_cols[1]]] <- cas_values[i]
        # Set all other CAS columns to NA
        if (length(cas_cols) > 1) {
          for (j in 2:length(cas_cols)) {
            new_row[[cas_cols[j]]] <- NA_character_
          }
        }
        # Update multi_cas flags
        new_row$multi_cas <- FALSE
        new_row$multi_cas_count <- 1L
        return(new_row)
      })

      # Combine new rows
      new_rows_df <- dplyr::bind_rows(new_rows)

      # Remove original row from cleaned_data
      original_row_id <- row_to_split$original_row_id
      cleaned_data_updated <- cleaned_data[cleaned_data$original_row_id != original_row_id, ]

      # Append new rows
      cleaned_data_updated <- dplyr::bind_rows(cleaned_data_updated, new_rows_df)

      # Update data_store
      data_store$cleaned_data <- cleaned_data_updated

      # Add audit entry
      audit_entry <- tibble::tibble(
        row_id = as.integer(original_row_id),
        field = "multi_cas_split",
        step = "manual_split",
        original_value = paste(cas_values, collapse = "; "),
        new_value = sprintf("Split into %d rows", length(cas_values)),
        reason = "User-initiated multi-CAS row split"
      )

      data_store$cleaning_audit <- dplyr::bind_rows(data_store$cleaning_audit, audit_entry)

      # Close modal
      removeModal()

      # Show success notification
      showNotification(
        sprintf("Row split into %d separate entries", length(cas_values)),
        type = "message",
        duration = 5
      )
    })

    # Return reactive list
    return(list(
      cleaning_completed = reactive({
        !is.null(data_store$cleaned_data)
      })
    ))
  })
}
