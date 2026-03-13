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
    # Chip editor CSS
    tags$style(HTML(sprintf("
      .ref-chip { cursor: pointer; margin: 2px; display: inline-block; }
      .ref-chip:hover { opacity: 0.8; }
      .ref-chip-remove { cursor: pointer; margin-left: 4px; font-weight: bold; }
      .ref-chip-remove:hover { color: red; }
      .ref-chip-container { max-height: 200px; overflow-y: auto; padding: 6px; border: 1px solid #dee2e6; border-radius: 4px; background: #f8f9fa; }
      .ref-term-input { margin-top: 6px; }
    "))),
    # Chip editor JS — delegated events
    tags$script(HTML(sprintf("
      $(document).on('click', '.ref-chip-body[data-ns=\"%s\"]', function() {
        var $chip = $(this);
        Shiny.setInputValue('%s', {
          type: $chip.data('type'),
          term: $chip.data('term'),
          ts: Date.now()
        });
      });
      $(document).on('click', '.ref-chip-remove[data-ns=\"%s\"]', function(e) {
        e.stopPropagation();
        var $btn = $(this);
        Shiny.setInputValue('%s', {
          type: $btn.data('type'),
          term: $btn.data('term'),
          ts: Date.now()
        });
      });
      $(document).on('keypress', '.ref-term-input[data-ns=\"%s\"]', function(e) {
        if (e.which === 13) {
          e.preventDefault();
          var $input = $(this);
          var val = $input.val().trim();
          if (val !== '') {
            Shiny.setInputValue('%s', {
              type: $input.data('type'),
              term: val,
              ts: Date.now()
            });
            $input.val('');
          }
        }
      });
    ", ns(""), ns("chip_toggle"), ns(""), ns("chip_remove"), ns(""), ns("chip_add")))),

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

      reactable::reactableOutput(ns("cleaned_table")),

      uiOutput(ns("audit_section")),

      # Reference list editors
      fileInput(
        ns("csv_upload"),
        "Upload Reference List CSV",
        accept = ".csv"
      ),

      uiOutput(ns("reference_editors_section")),

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

    # Initialize reference lists if not yet loaded
    observe({
      if (is.null(data_store$reference_lists)) {
        data_store$reference_lists <- load_all_reference_lists("data/reference_cache")
      } else if (is.null(data_store$reference_lists$strip_terms)) {
        # Backfill strip_terms for sessions initialized before this list existed
        data_store$reference_lists$strip_terms <- load_strip_terms("data/reference_cache")
      }
    })

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

            incProgress(0.04, detail = "Adding row lineage...")
            df <- inject_row_lineage(df)

            incProgress(0.08, detail = "Converting unicode to ASCII...")
            df_before <- df
            df <- dplyr::mutate(df, dplyr::across(where(is.character), ComptoxR::clean_unicode))
            all_audits[[length(all_audits) + 1]] <- build_audit_trail(df_before, df, "unicode_to_ascii", function(f) paste0("Unicode to ASCII in ", f))

            incProgress(0.08, detail = "Trimming whitespace...")
            df_before <- df
            df <- dplyr::mutate(df, dplyr::across(where(is.character), clean_text_field))
            all_audits[[length(all_audits) + 1]] <- build_audit_trail(df_before, df, "trim_whitespace_punctuation", function(f) paste0("Trim in ", f))

            new_tags <- list()
            if (!is.null(tag_map) && length(tag_map) > 0) {
              incProgress(0.12, detail = "Normalizing CAS-RNs...")
              cas_result <- normalize_cas_fields(df, tag_map)
              df <- cas_result$cleaned_data
              all_audits[[length(all_audits) + 1]] <- cas_result$audit_trail

              incProgress(0.12, detail = "Rescuing CAS from names...")
              rescue_result <- rescue_cas_from_text(df, tag_map)
              df <- rescue_result$cleaned_data
              all_audits[[length(all_audits) + 1]] <- rescue_result$audit_trail
              new_tags <- rescue_result$new_tags

              incProgress(0.08, detail = "Detecting multi-CAS rows...")
              updated_tag_map <- c(tag_map, new_tags)
              df <- detect_multi_cas(df, updated_tag_map)

              # Name cleaning steps (if Name columns present)
              name_cols <- names(tag_map)[tag_map == "Name"]

              if (length(name_cols) > 0) {
                incProgress(0.08, detail = "Stripping parentheticals...")
                enclosure_result <- strip_terminal_enclosures(df, name_cols)
                df <- enclosure_result$cleaned_data
                all_audits[[length(all_audits) + 1]] <- enclosure_result$audit_trail
                if (length(enclosure_result$new_tags) > 0) {
                  new_tags <- c(new_tags, enclosure_result$new_tags)
                  updated_tag_map <- c(updated_tag_map, enclosure_result$new_tags)
                }

                incProgress(0.04, detail = "Removing quality adjectives...")
                quality_result <- strip_quality_adjectives(df, name_cols)
                df <- quality_result$cleaned_data
                all_audits[[length(all_audits) + 1]] <- quality_result$audit_trail

                incProgress(0.04, detail = "Removing salt references...")
                salt_result <- strip_salt_references(df, name_cols)
                df <- salt_result$cleaned_data
                all_audits[[length(all_audits) + 1]] <- salt_result$audit_trail

                incProgress(0.04, detail = "Removing unspecified suffixes...")
                unspec_result <- strip_terminal_unspecified(df, name_cols)
                df <- unspec_result$cleaned_data
                all_audits[[length(all_audits) + 1]] <- unspec_result$audit_trail

                incProgress(0.04, detail = "Stripping user-defined terms...")
                if (!is.null(data_store$reference_lists$strip_terms)) {
                  strip_terms_result <- strip_reference_terms(df, name_cols, data_store$reference_lists$strip_terms)
                  df <- strip_terms_result$cleaned_data
                  all_audits[[length(all_audits) + 1]] <- strip_terms_result$audit_trail
                }

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

                incProgress(0.08, detail = "Splitting synonyms...")
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

                # Phase 13: Bare formula detection (after all name cleaning)
                incProgress(0.05, detail = "Detecting bare formulas...")
                formula_result <- detect_bare_formulas(df, name_cols)
                df <- formula_result$cleaned_data
                all_audits[[length(all_audits) + 1]] <- formula_result$audit_trail

                # Phase 13: Reference list flagging
                if (!is.null(data_store$reference_lists)) {
                  incProgress(0.05, detail = "Flagging reference list matches...")

                  # Flag functional categories (warning)
                  func_cats <- data_store$reference_lists$functional_categories
                  if (nrow(func_cats) > 0) {
                    func_result <- flag_reference_matches(df, name_cols, func_cats, "warning", "functional category")
                    df <- func_result$cleaned_data
                    all_audits[[length(all_audits) + 1]] <- func_result$audit_trail
                  }

                  # Flag stop words (warning)
                  stop_words <- data_store$reference_lists$stop_words
                  if (nrow(stop_words) > 0) {
                    stop_result <- flag_reference_matches(df, name_cols, stop_words, "warning", "stop word")
                    df <- stop_result$cleaned_data
                    all_audits[[length(all_audits) + 1]] <- stop_result$audit_trail
                  }

                  # Flag block patterns (blocking)
                  block_pats <- data_store$reference_lists$block_patterns
                  if (nrow(block_pats) > 0) {
                    block_result <- flag_reference_matches(df, name_cols, block_pats, "blocking", "block pattern")
                    df <- block_result$cleaned_data
                    all_audits[[length(all_audits) + 1]] <- block_result$audit_trail
                  }
                }
              }
            }

            incProgress(0.04, detail = "Finalizing...")
            audit_combined <- dplyr::bind_rows(all_audits)
            data_store$cleaned_data <- df
            data_store$cleaning_audit <- audit_combined
            if (length(new_tags) > 0) {
              data_store$column_tags <- c(data_store$column_tags, new_tags)
            }

            # Cascade reset: invalidate downstream state
            data_store$curation_results <- NULL
            data_store$resolved_data <- NULL

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

      # Flag statistics row (always visible)
      n_formulas_blocked <- sum(audit$step == "detect_bare_formula")
      n_categories_flagged <- sum(audit$step == "flag_warning" & grepl("functional category", audit$reason, ignore.case = TRUE))
      n_stop_words_matched <- sum(audit$step == "flag_warning" & grepl("stop word", audit$reason, ignore.case = TRUE))

      row4 <- bslib::layout_columns(
        col_widths = c(4, 4, 4),
        bslib::value_box(
          title = "Formulas Blocked",
          value = n_formulas_blocked,
          showcase = bsicons::bs_icon("calculator"),
          theme = "danger"
        ),
        bslib::value_box(
          title = "Categories Flagged",
          value = n_categories_flagged,
          showcase = bsicons::bs_icon("tag"),
          theme = "warning"
        ),
        bslib::value_box(
          title = "Stop Words Matched",
          value = n_stop_words_matched,
          showcase = bsicons::bs_icon("hand-thumbs-down"),
          theme = "warning"
        )
      )

      div(
        class = "mb-3 mt-3",
        row1,
        row2,
        row3,
        row4
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
          reactable::reactableOutput(session$ns("audit_table"))
        )
      )
    })

    # Audit table
    output$audit_table <- reactable::renderReactable({
      req(data_store$cleaning_audit)

      reactable::reactable(
        data_store$cleaning_audit,
        defaultPageSize = 25,
        filterable = TRUE,
        resizable = TRUE,
        wrap = FALSE,
        striped = TRUE,
        compact = TRUE,
        defaultSorted = list(row_id = "asc")
      )
    })

    # Helper: render chip editor for a reference list tibble
    render_chip_editor <- function(ref_tibble, type) {
      ns <- session$ns
      chips <- lapply(seq_len(nrow(ref_tibble)), function(i) {
        row <- ref_tibble[i, ]
        is_active <- isTRUE(row$active)
        is_default <- identical(row$source, "app_default")

        # Badge class based on source and active status
        if (is_active) {
          badge_class <- switch(row$source,
            app_default = "badge bg-success ref-chip",
            user = "badge bg-primary ref-chip",
            imported = "badge bg-info ref-chip",
            "badge bg-secondary ref-chip"
          )
        } else {
          badge_class <- "badge text-bg-light text-muted text-decoration-line-through ref-chip"
        }

        # X button only for non-default terms
        remove_btn <- if (!is_default) {
          tags$span(
            class = "ref-chip-remove",
            `data-ns` = ns(""),
            `data-type` = type,
            `data-term` = row$term,
            HTML("&times;")
          )
        }

        tags$span(
          class = badge_class,
          tags$span(
            class = "ref-chip-body",
            `data-ns` = ns(""),
            `data-type` = type,
            `data-term` = row$term,
            row$term
          ),
          remove_btn
        )
      })

      tagList(
        div(class = "ref-chip-container", chips),
        tags$input(
          type = "text",
          class = "form-control form-control-sm ref-term-input",
          `data-ns` = ns(""),
          `data-type` = type,
          placeholder = "Type a term and press Enter..."
        )
      )
    }

    # Reference list editors section — static accordion wrapper (renders once)
    # Track whether reference lists have been initialized (one-shot flag)
    ref_lists_ready <- reactiveVal(FALSE)
    observe({
      req(data_store$reference_lists)
      if (!ref_lists_ready()) ref_lists_ready(TRUE)
    })

    output$reference_editors_section <- renderUI({
      req(ref_lists_ready())

      bslib::accordion(
        id = session$ns("reference_editors"),
        open = FALSE,
        multiple = TRUE,
        bslib::accordion_panel(
          title = "Functional Categories",
          icon = bsicons::bs_icon("tag"),
          uiOutput(session$ns("chip_func_cats"))
        ),
        bslib::accordion_panel(
          title = "Stop Words",
          icon = bsicons::bs_icon("hand-thumbs-down"),
          uiOutput(session$ns("chip_stop_words"))
        ),
        bslib::accordion_panel(
          title = "Block Patterns",
          icon = bsicons::bs_icon("calculator"),
          uiOutput(session$ns("chip_block_patterns"))
        ),
        bslib::accordion_panel(
          title = "Strip Terms",
          icon = bsicons::bs_icon("eraser"),
          uiOutput(session$ns("chip_strip_terms"))
        )
      )
    })

    # Per-list chip renderers (isolated so toggling one doesn't re-render others)
    output$chip_func_cats <- renderUI({
      req(data_store$reference_lists)
      tbl <- data_store$reference_lists$functional_categories
      n_active <- sum(tbl$active, na.rm = TRUE)
      tagList(
        tags$small(class = "text-muted mb-1 d-block", sprintf("%d active / %d total", n_active, nrow(tbl))),
        render_chip_editor(tbl, "functional_categories")
      )
    })

    output$chip_stop_words <- renderUI({
      req(data_store$reference_lists)
      tbl <- data_store$reference_lists$stop_words
      n_active <- sum(tbl$active, na.rm = TRUE)
      tagList(
        tags$small(class = "text-muted mb-1 d-block", sprintf("%d active / %d total", n_active, nrow(tbl))),
        render_chip_editor(tbl, "stop_words")
      )
    })

    output$chip_block_patterns <- renderUI({
      req(data_store$reference_lists)
      tbl <- data_store$reference_lists$block_patterns
      n_active <- sum(tbl$active, na.rm = TRUE)
      tagList(
        tags$small(class = "text-muted mb-1 d-block", sprintf("%d active / %d total", n_active, nrow(tbl))),
        render_chip_editor(tbl, "block_patterns")
      )
    })

    output$chip_strip_terms <- renderUI({
      req(data_store$reference_lists)
      tbl <- data_store$reference_lists$strip_terms
      n_active <- sum(tbl$active, na.rm = TRUE)
      tagList(
        tags$small(class = "text-muted mb-1 d-block", sprintf("%d active / %d total", n_active, nrow(tbl))),
        render_chip_editor(tbl, "strip_terms")
      )
    })

    # Chip toggle — flip active status
    observeEvent(input$chip_toggle, {
      msg <- input$chip_toggle
      req(msg$type, msg$term)

      tbl <- data_store$reference_lists[[msg$type]]
      idx <- which(tbl$term == msg$term)
      if (length(idx) > 0) {
        tbl$active[idx[1]] <- !isTRUE(tbl$active[idx[1]])
        data_store$reference_lists[[msg$type]] <- tbl
      }
    })

    # Chip remove — delete non-default terms
    observeEvent(input$chip_remove, {
      msg <- input$chip_remove
      req(msg$type, msg$term)

      tbl <- data_store$reference_lists[[msg$type]]
      idx <- which(tbl$term == msg$term & tbl$source != "app_default")
      if (length(idx) > 0) {
        tbl <- tbl[-idx[1], ]
        data_store$reference_lists[[msg$type]] <- tbl
      }
    })

    # Chip add — append new user term
    observeEvent(input$chip_add, {
      msg <- input$chip_add
      req(msg$type, msg$term)

      tbl <- data_store$reference_lists[[msg$type]]

      # Duplicate check (case-insensitive)
      if (tolower(msg$term) %in% tolower(tbl$term)) {
        showNotification(
          sprintf("'%s' already exists in this list", msg$term),
          type = "warning",
          duration = 3
        )
        return()
      }

      new_row <- tibble::tibble(term = msg$term, source = "user", active = TRUE)
      data_store$reference_lists[[msg$type]] <- dplyr::bind_rows(tbl, new_row)
    })

    # CSV upload handler
    observeEvent(input$csv_upload, {
      req(input$csv_upload)

      tryCatch(
        {
          # Read CSV
          uploaded_data <- readr::read_csv(input$csv_upload$datapath, show_col_types = FALSE)

          # Validate required columns
          if (!("type" %in% names(uploaded_data))) {
            showModal(modalDialog(
              title = "Invalid CSV",
              "The CSV must have a 'type' column.",
              "Allowed values: functional_category, stop_word, block_pattern",
              easyClose = TRUE,
              footer = modalButton("OK")
            ))
            return()
          }

          if (!("term" %in% names(uploaded_data))) {
            showModal(modalDialog(
              title = "Invalid CSV",
              "The CSV must have a 'term' column containing the reference list entries.",
              easyClose = TRUE,
              footer = modalButton("OK")
            ))
            return()
          }

          # Validate type values
          allowed_types <- c("functional_category", "stop_word", "block_pattern", "strip_term")
          unknown_types <- setdiff(unique(uploaded_data$type), allowed_types)

          if (length(unknown_types) > 0) {
            showModal(modalDialog(
              title = "Invalid Type Values",
              sprintf("Unknown type values found: %s", paste(unknown_types, collapse = ", ")),
              sprintf("Allowed types: %s", paste(allowed_types, collapse = ", ")),
              easyClose = TRUE,
              footer = modalButton("OK")
            ))
            return()
          }

          # Route entries to correct lists
          n_added <- 0

          for (i in seq_len(nrow(uploaded_data))) {
            type_val <- uploaded_data$type[i]
            term_val <- uploaded_data$term[i]

            if (is.na(term_val) || term_val == "") {
              next
            }

            new_row <- tibble::tibble(
              term = term_val,
              source = "user",
              active = TRUE
            )

            if (type_val == "functional_category") {
              data_store$reference_lists$functional_categories <- dplyr::bind_rows(
                data_store$reference_lists$functional_categories,
                new_row
              )
              n_added <- n_added + 1
            } else if (type_val == "stop_word") {
              data_store$reference_lists$stop_words <- dplyr::bind_rows(
                data_store$reference_lists$stop_words,
                new_row
              )
              n_added <- n_added + 1
            } else if (type_val == "block_pattern") {
              data_store$reference_lists$block_patterns <- dplyr::bind_rows(
                data_store$reference_lists$block_patterns,
                new_row
              )
              n_added <- n_added + 1
            } else if (type_val == "strip_term") {
              data_store$reference_lists$strip_terms <- dplyr::bind_rows(
                data_store$reference_lists$strip_terms,
                new_row
              )
              n_added <- n_added + 1
            }
          }

          showNotification(
            sprintf("Successfully added %d entries to reference lists", n_added),
            type = "message",
            duration = 5
          )
        },
        error = function(e) {
          showNotification(
            paste("CSV upload failed:", e$message),
            type = "error",
            duration = NULL
          )
        }
      )
    })

    # Cleaned data table
    output$cleaned_table <- reactable::renderReactable({
      req(data_store$cleaned_data)

      df <- data_store$cleaned_data

      # Hidden columns
      hidden_col_names <- intersect(c("original_row_id", "multi_cas", "multi_cas_count"), names(df))

      # Build column definitions
      col_defs <- list()

      # Hide internal columns
      for (col_name in hidden_col_names) {
        col_defs[[col_name]] <- reactable::colDef(show = FALSE)
      }

      # Row style function for cleaning_flag conditional formatting
      row_style_fn <- if ("cleaning_flag" %in% names(df)) {
        function(index) {
          flag <- df$cleaning_flag[index]
          if (!is.na(flag) && is.character(flag)) {
            if (startsWith(flag, "BLOCK:")) {
              return(list(backgroundColor = "#ffcccc"))
            } else if (startsWith(flag, "WARN:")) {
              return(list(backgroundColor = "#fff3cd"))
            }
          }
          NULL
        }
      } else {
        NULL
      }

      reactable::reactable(
        df,
        columns = col_defs,
        defaultPageSize = 25,
        resizable = TRUE,
        wrap = FALSE,
        striped = TRUE,
        compact = TRUE,
        rowStyle = row_style_fn
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
          reactable::reactableOutput(ns("multi_cas_table")),
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
    output$multi_cas_table <- reactable::renderReactable({
      req(data_store$cleaned_data)

      cleaned_data <- data_store$cleaned_data
      multi_cas_rows <- cleaned_data[cleaned_data$multi_cas == TRUE, ]

      reactable::reactable(
        multi_cas_rows,
        selection = "single",
        onClick = "select",
        defaultPageSize = 10,
        resizable = TRUE,
        wrap = FALSE,
        striped = TRUE,
        compact = TRUE
      )
    })

    # Split row button handler
    observeEvent(input$split_row, {
      req(data_store$cleaned_data)

      # Get selected row from reactable
      selected <- reactable::getReactableState("multi_cas_table", "selected")

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
      selected <- reactable::getReactableState("multi_cas_table", "selected")
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
