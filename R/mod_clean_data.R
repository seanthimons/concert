# Clean Data Module
# Data cleaning execution with progress tracking and audit trail display

#' Clean Data Module - UI
#'
#' @param id Module namespace ID
#'
#' @return UI elements for clean data tab
#' @export
mod_clean_data_ui <- function(id) {
  ns <- NS(id)

  tagList(
    # Chip editor CSS
    tags$style(HTML(sprintf(
      "
      .ref-chip { cursor: pointer; margin: 2px; display: inline-block; }
      .ref-chip:hover { opacity: 0.8; }
      .ref-chip-remove { cursor: pointer; margin-left: 4px; font-weight: bold; }
      .ref-chip-remove:hover { color: red; }
      .ref-chip-container { max-height: 200px; overflow-y: auto; padding: 6px; border: 1px solid #dee2e6; border-radius: 4px; background: #f8f9fa; }
      .ref-term-input { margin-top: 6px; }
    "
    ))),
    # Chip editor JS — delegated events
    tags$script(HTML(sprintf(
      "
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
    ",
      ns(""),
      ns("chip_toggle"),
      ns(""),
      ns("chip_remove"),
      ns(""),
      ns("chip_add")
    ))),

    # Content when data is loaded
    conditionalPanel(
      condition = paste0("output['", ns("has_data"), "']"),

      shinyjs::disabled(
        actionButton(
          ns("run_pipeline"),
          "Run Pipeline",
          class = "btn-success btn-lg mt-3 mb-3",
          icon = icon("play")
        )
      ),

      uiOutput(ns("cleaning_summary")),

      reactable::reactableOutput(ns("cleaned_table")),

      uiOutput(ns("multi_analyte_section")),

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
#' @export
mod_clean_data_server <- function(id, data_store, on_cleaning_complete = NULL) {
  moduleServer(id, function(input, output, session) {
    # Initialize reference lists if not yet loaded
    observe({
      reference_cache_dir <- resolve_reference_cache_dir()
      if (is.null(data_store$reference_lists)) {
        data_store$reference_lists <- load_all_reference_lists(reference_cache_dir)
      } else if (is.null(data_store$reference_lists$strip_terms)) {
        # Backfill strip_terms for sessions initialized before this list existed
        data_store$reference_lists$strip_terms <- load_strip_terms(reference_cache_dir)
      }
    })

    update_persistent_reference_list <- function(type, term, active = TRUE, action = c("add", "remove", "toggle")) {
      data_store$reference_lists[[type]] <- update_user_reference_list(
        type = type,
        term = term,
        active = active,
        action = action,
        cache_dir = resolve_reference_cache_dir()
      )
    }

    # Has data indicator for conditionalPanel
    # Requires both Name AND CASRN columns tagged for cleaning pipeline
    output$has_data <- reactive({
      !is.null(data_store$column_tags) && has_required_chemical_tags(data_store$column_tags)
    })
    outputOptions(output, "has_data", suspendWhenHidden = FALSE)

    # Enable/disable Run Pipeline button based on column tags
    observe({
      has_tags <- !is.null(data_store$column_tags) && has_required_chemical_tags(data_store$column_tags)
      if (has_tags) shinyjs::enable("run_pipeline") else shinyjs::disable("run_pipeline")
    })

    # Pre-flight check state (shared between run_pipeline and open_preflight_anyway)
    preflight_checks <- reactiveVal(NULL)

    # Run Pipeline button -- collect pre-checks and show modal (or zero-change notification)
    observeEvent(input$run_pipeline, {
      req(data_store$clean)

      withProgress(message = "Running pre-flight checks...", value = 0, {
        df <- data_store$clean
        tag_map <- data_store$column_tags
        name_cols <- names(tag_map)[tag_map == "Name"]
        numeric_tags_vec <- if (!is.null(data_store$numeric_tags)) {
          unlist(data_store$numeric_tags, use.names = TRUE)
        } else {
          character(0)
        }
        unit_cols <- names(numeric_tags_vec)[numeric_tags_vec == "Unit"]
        dur_cols <- names(numeric_tags_vec)[numeric_tags_vec == "Duration"]
        dur_unit_cols <- names(numeric_tags_vec)[numeric_tags_vec == "DurationUnit"]

        # Extract study-type tags (NULL-safe)
        if (!is.null(data_store$study_type_tags)) {
          stv <- unlist(data_store$study_type_tags)
          date_cols <- names(stv)[stv == "StudyDate"]
          media_cols <- names(stv)[stv == "Media"]
        } else {
          date_cols <- character(0)
          media_cols <- character(0)
        }

        unit_map_ref <- data_store$unit_map_working %||% data_store$reference_lists$unit_map

        incProgress(0.1, detail = "Checking cleaning steps...")
        checks <- list(
          unicode = precheck_unicode_to_ascii(df),
          whitespace = precheck_trim_whitespace(df),
          cas = precheck_normalize_cas(df, tag_map),
          names = precheck_name_cleaning(df, name_cols),
          isotopes = precheck_isotope_shortcodes(
            df,
            name_cols,
            data_store$reference_lists$isotope_lookup
          ),
          multi = precheck_multi_analyte(df, name_cols),
          chiral = precheck_chiral_restore(df, name_cols)
        )

        incProgress(0.4, detail = "Checking harmonization steps...")
        checks$units <- precheck_harmonize_units(df, unit_cols, unit_map_ref)
        checks$duration <- precheck_harmonize_duration(
          df,
          dur_cols,
          dur_unit_cols,
          unit_map_ref
        )
        checks$dates <- precheck_harmonize_dates(df, date_cols)
        checks$media <- precheck_harmonize_media(
          df,
          media_cols,
          data_store$media_map_working
        )

        incProgress(0.4, detail = "Building pre-flight report...")
        preflight_checks(checks)

        total_changes <- sum(vapply(checks, function(x) x$est_changes, integer(1)))

        if (total_changes == 0L) {
          showNotification(
            tagList(
              "Pre-flight: no steps have changes to apply.",
              actionLink(session$ns("open_preflight_anyway"), "Open pre-flight modal", class = "alert-link ms-2")
            ),
            type = "message",
            duration = 0
          )
          return()
        }

        showModal(modalDialog(
          title = "Pre-flight Check",
          size = "m",
          easyClose = FALSE,
          uiOutput(session$ns("preflight_checklist")),
          footer = tagList(
            modalButton("Cancel"),
            actionButton(session$ns("run_all"), "Run All Steps", class = "btn-outline-secondary"),
            actionButton(session$ns("run_checked"), "Run Checked Steps", class = "btn-primary")
          )
        ))
      })
    })

    # "Open pre-flight modal" link from zero-change notification
    observeEvent(input$open_preflight_anyway, {
      checks <- preflight_checks()
      req(checks)
      showModal(modalDialog(
        title = "Pre-flight Check",
        size = "m",
        easyClose = FALSE,
        uiOutput(session$ns("preflight_checklist")),
        footer = tagList(
          modalButton("Cancel"),
          actionButton(session$ns("run_all"), "Run All Steps", class = "btn-outline-secondary"),
          actionButton(session$ns("run_checked"), "Run Checked Steps", class = "btn-primary")
        )
      ))
    })

    # Checklist renderUI
    output$preflight_checklist <- renderUI({
      checks <- preflight_checks()
      req(checks)

      make_row <- function(key, label, check) {
        badge <- if (check$should_run && check$est_changes > 0) {
          tags$span(class = "badge bg-secondary ms-2", sprintf("~%d changes", check$est_changes))
        } else {
          tags$span(class = "badge bg-light text-muted ms-2", "skip")
        }
        div(
          class = "d-flex align-items-center py-2",
          checkboxInput(
            session$ns(paste0("step_", key)),
            label = NULL,
            value = check$should_run && check$est_changes > 0,
            width = "auto"
          ),
          tags$span(class = "ms-2 flex-grow-1", label),
          badge
        )
      }

      cleaning_rows <- tagList(
        make_row("unicode", "Unicode to ASCII", checks$unicode),
        make_row("whitespace", "Trim Whitespace", checks$whitespace),
        make_row("cas", "Normalize CAS", checks$cas),
        make_row("names", "Name Cleaning", checks$names),
        make_row("isotopes", "Isotope Shortcodes", checks$isotopes),
        make_row("multi", "Multi-Analyte Detection", checks$multi),
        make_row("chiral", "Chiral Restoration", checks$chiral)
      )

      harmonize_rows <- tagList(
        make_row("units", "Unit Harmonization", checks$units),
        make_row("duration", "Duration Conversion", checks$duration),
        make_row("dates", "Date Parsing", checks$dates),
        make_row("media", "Media Classification", checks$media)
      )

      bslib::accordion(
        id = session$ns("preflight_accordion"),
        open = TRUE,
        multiple = TRUE,
        bslib::accordion_panel(title = "Cleaning Steps", value = "cleaning", cleaning_rows),
        bslib::accordion_panel(title = "Harmonization Steps", value = "harmonization", harmonize_rows),
        bslib::accordion_panel(
          title = "Search Settings",
          value = "search_settings",
          div(
            class = "mb-3",
            tags$label(class = "form-label fw-semibold", "WQX Fuzzy Match Threshold"),
            tags$small(
              class = "text-muted d-block mb-2",
              "Minimum similarity score for fuzzy WQX matches (0.50 = permissive, 1.00 = exact only)"
            ),
            bslib::layout_columns(
              col_widths = c(8, 4),
              sliderInput(
                session$ns("wqx_threshold"),
                label = NULL,
                min = 0.50,
                max = 1.00,
                step = 0.01,
                value = 0.85,
                ticks = FALSE
              ),
              numericInput(
                session$ns("wqx_threshold_num"),
                label = NULL,
                value = 0.85,
                min = 0.50,
                max = 1.00,
                step = 0.01
              )
            )
          ),
          div(
            checkboxInput(
              session$ns("starts_with_enabled"),
              label = "Enable CompTox starts-with search",
              value = FALSE
            ),
            tags$small(
              class = "text-muted",
              "Off by default. Enable for datasets where exact + CAS + WQX resolution is insufficient."
            )
          ),
          div(
            checkboxInput(
              session$ns("activate_all_references"),
              label = "Activate all reference terms for this run",
              value = FALSE
            ),
            tags$small(
              class = "text-muted",
              "Uses inactive stop words, block patterns, and strip terms without changing the saved reference lists."
            )
          )
        )
      )
    })

    # Helper: build step mask from checkboxes
    build_mask_from_inputs <- function() {
      list(
        unicode = isTRUE(input$step_unicode),
        whitespace = isTRUE(input$step_whitespace),
        cas = isTRUE(input$step_cas),
        names = isTRUE(input$step_names),
        isotopes = isTRUE(input$step_isotopes),
        multi = isTRUE(input$step_multi),
        chiral = isTRUE(input$step_chiral),
        units = isTRUE(input$step_units),
        duration = isTRUE(input$step_duration),
        dates = isTRUE(input$step_dates),
        media = isTRUE(input$step_media),
        wqx_threshold = input$wqx_threshold,
        starts_with = isTRUE(input$starts_with_enabled),
        activate_all_references = isTRUE(input$activate_all_references)
      )
    }

    observeEvent(
      input$wqx_threshold,
      {
        updateNumericInput(session, "wqx_threshold_num", value = input$wqx_threshold)
      },
      ignoreInit = TRUE
    )

    observeEvent(
      input$wqx_threshold_num,
      {
        val <- input$wqx_threshold_num
        if (!is.null(val) && !is.na(val) && val >= 0.50 && val <= 1.00) {
          updateSliderInput(session, "wqx_threshold", value = val)
        }
      },
      ignoreInit = TRUE
    )

    # Shared pipeline execution function (called by run_all and run_checked)
    execute_pipeline <- function(mask) {
      data_store$wqx_threshold <- mask$wqx_threshold %||% 0.85
      data_store$starts_with <- isTRUE(mask$starts_with)
      data_store$activate_all_references <- isTRUE(mask$activate_all_references)
      reference_lists_for_run <- if (isTRUE(mask$activate_all_references)) {
        activate_all_reference_terms(data_store$reference_lists)
      } else {
        data_store$reference_lists
      }

      removeModal()
      shinyjs::disable("run_pipeline")

      tryCatch(
        {
          withProgress(message = "Running pipeline...", value = 0, {
            df <- data_store$clean
            tag_map <- data_store$column_tags

            incProgress(0.2, detail = "Running selected cleaning steps...")
            cleaning_mask <- mask
            cleaning_mask$truncated <- isTRUE(mask$names)
            cleaning_mask$bare_formula <- isTRUE(mask$names)
            cleaning_mask$reference_flags <- isTRUE(mask$names)

            pipeline_result <- run_cleaning_pipeline_masked(
              df = df,
              tag_map = tag_map,
              reference_lists = reference_lists_for_run,
              mask = cleaning_mask,
              use_dedup = TRUE,
              respect_prechecks = FALSE
            )

            df <- pipeline_result$cleaned_data
            audit_combined <- pipeline_result$audit_trail
            new_tags <- pipeline_result$new_tags

            incProgress(0.8, detail = "Finalizing cleaning...")
            data_store$cleaned_data <- df
            data_store$cleaning_audit <- audit_combined
            if (length(new_tags) > 0) {
              data_store$column_tags <- c(data_store$column_tags, new_tags)
            }

            # Cascade reset: invalidate downstream state
            data_store$curation_results <- NULL
            data_store$resolved_data <- NULL
            data_store$review_visible_cols <- NULL

            n_changes <- nrow(audit_combined)

            # Build completion summary from mask
            cleaning_steps_run <- c(
              if (mask$unicode) "Unicode" else NULL,
              if (mask$whitespace) "Whitespace" else NULL,
              if (mask$cas) "CAS normalization" else NULL,
              if (mask$names) "Name cleaning" else NULL,
              if (mask$isotopes) "Isotope expansion" else NULL,
              if (mask$multi) "Multi-analyte detection" else NULL,
              if (mask$chiral) "Chiral restoration" else NULL
            )
            harmonize_steps_run <- c(
              if (mask$units) "Units" else NULL,
              if (mask$duration) "Duration" else NULL,
              if (mask$dates) "Dates" else NULL,
              if (mask$media) "Media" else NULL
            )

            summary_parts <- character()
            if (length(cleaning_steps_run) > 0) {
              summary_parts <- c(
                summary_parts,
                sprintf(
                  "Cleaning: %d step(s) ran, %d change(s).",
                  length(cleaning_steps_run),
                  n_changes
                )
              )
            }
            if (length(harmonize_steps_run) > 0) {
              summary_parts <- c(
                summary_parts,
                sprintf(
                  "Harmonization: %s dispatched.",
                  paste(harmonize_steps_run, collapse = ", ")
                )
              )
            }
            if (length(summary_parts) == 0) {
              summary_parts <- "No steps were selected to run."
            }

            showNotification(
              tagList(
                tags$strong("Pipeline complete. "),
                paste(summary_parts, collapse = " ")
              ),
              type = "message",
              duration = 8
            )

            # Call navigation callback if provided
            if (!is.null(on_cleaning_complete)) {
              on_cleaning_complete()
            }

            # Trigger harmonization if any harmonization steps are checked
            any_harmonize <- mask$units || mask$duration || mask$dates || mask$media
            if (any_harmonize) {
              data_store$harmonize_step_mask <- list(
                units = mask$units,
                duration = mask$duration,
                dates = mask$dates,
                media = mask$media
              )
              current_nonce <- data_store$harmonize_run_nonce
              if (is.null(current_nonce)) {
                current_nonce <- 0L
              }
              data_store$harmonize_run_nonce <- current_nonce + 1L
            }
          })
        },
        error = function(e) {
          showNotification(
            paste("Pipeline failed:", e$message),
            type = "error",
            duration = NULL
          )
        },
        finally = {
          shinyjs::enable("run_pipeline")
        }
      )
    }

    # Run All Steps observer
    observeEvent(input$run_all, {
      mask <- list(
        unicode = TRUE,
        whitespace = TRUE,
        cas = TRUE,
        names = TRUE,
        isotopes = TRUE,
        multi = TRUE,
        chiral = TRUE,
        units = TRUE,
        duration = TRUE,
        dates = TRUE,
        media = TRUE,
        wqx_threshold = input$wqx_threshold,
        starts_with = isTRUE(input$starts_with_enabled),
        activate_all_references = isTRUE(input$activate_all_references)
      )
      execute_pipeline(mask)
    })

    # Run Checked Steps observer
    observeEvent(input$run_checked, {
      mask <- build_mask_from_inputs()
      execute_pipeline(mask)
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
      n_adjectives <- sum(
        audit$step %in% c("strip_quality_adjectives", "strip_salt_references", "strip_terminal_unspecified")
      )

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
      n_categories_flagged <- sum(
        audit$step == "flag_warning" & grepl("functional category", audit$reason, ignore.case = TRUE)
      )
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
          badge_class <- switch(
            row$source,
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

      reference_title <- function(label, type) {
        tagList(
          label,
          tags$span(
            class = "text-muted ms-1",
            title = reference_list_help_text(type),
            `aria-label` = reference_list_help_text(type),
            bsicons::bs_icon("info-circle")
          )
        )
      }

      bslib::accordion(
        id = session$ns("reference_editors"),
        open = FALSE,
        multiple = TRUE,
        bslib::accordion_panel(
          title = reference_title("Functional Categories", "functional_categories"),
          value = "functional_categories",
          icon = bsicons::bs_icon("tag"),
          uiOutput(session$ns("chip_func_cats"))
        ),
        bslib::accordion_panel(
          title = reference_title("Stop Words", "stop_words"),
          value = "stop_words",
          icon = bsicons::bs_icon("hand-thumbs-down"),
          uiOutput(session$ns("chip_stop_words"))
        ),
        bslib::accordion_panel(
          title = reference_title("Block Patterns", "block_patterns"),
          value = "block_patterns",
          icon = bsicons::bs_icon("calculator"),
          uiOutput(session$ns("chip_block_patterns"))
        ),
        bslib::accordion_panel(
          title = reference_title("Strip Terms", "strip_terms"),
          value = "strip_terms",
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

      if (msg$type %in% user_reference_list_names()) {
        update_persistent_reference_list(msg$type, msg$term, action = "toggle")
        return()
      }

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

      if (msg$type %in% user_reference_list_names()) {
        update_persistent_reference_list(msg$type, msg$term, action = "remove")
        return()
      }

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
      if (msg$type %in% user_reference_list_names()) {
        update_persistent_reference_list(msg$type, msg$term, action = "add")
      } else {
        data_store$reference_lists[[msg$type]] <- dplyr::bind_rows(tbl, new_row)
      }
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
              "Allowed values: functional_category, stop_word, block_pattern, strip_term",
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
            active_val <- if ("active" %in% names(uploaded_data)) {
              active_parsed <- as.logical(uploaded_data$active[i])
              if (is.na(active_parsed)) TRUE else active_parsed
            } else {
              TRUE
            }

            if (is.na(term_val) || term_val == "") {
              next
            }

            new_row <- tibble::tibble(
              term = term_val,
              source = "user",
              active = active_val
            )

            if (type_val == "functional_category") {
              data_store$reference_lists$functional_categories <- dplyr::bind_rows(
                data_store$reference_lists$functional_categories,
                new_row
              )
              n_added <- n_added + 1
            } else if (type_val == "stop_word") {
              update_persistent_reference_list("stop_words", term_val, active = active_val, action = "add")
              n_added <- n_added + 1
            } else if (type_val == "block_pattern") {
              update_persistent_reference_list("block_patterns", term_val, active = active_val, action = "add")
              n_added <- n_added + 1
            } else if (type_val == "strip_term") {
              update_persistent_reference_list("strip_terms", term_val, active = active_val, action = "add")
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
      hidden_col_names <- intersect(
        c(
          "original_row_id",
          "multi_cas",
          "multi_cas_count",
          "multi_analyte_source_value",
          "multi_analyte_part_index",
          "multi_analyte_part_count"
        ),
        names(df)
      )

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

    filter_multi_analyte_rows <- function(cleaned_data) {
      if (is.null(cleaned_data) || nrow(cleaned_data) == 0) {
        return(tibble::tibble())
      }

      rows <- which(is_multi_analyte_review_row(cleaned_data))
      if (length(rows) == 0) {
        return(cleaned_data[0, , drop = FALSE])
      }

      dplyr::mutate(cleaned_data[rows, , drop = FALSE], .row_index = rows, .before = 1)
    }

    output$multi_analyte_section <- renderUI({
      req(data_store$cleaned_data)

      tag_map <- data_store$column_tags %||% list()
      name_cols <- names(tag_map)[tag_map == "Name"]
      if (length(name_cols) == 0) {
        return(NULL)
      }

      multi_analyte_rows <- filter_multi_analyte_rows(data_store$cleaned_data)
      if (nrow(multi_analyte_rows) == 0) {
        return(NULL)
      }

      div(
        class = "card mt-4",
        div(
          class = "card-header bg-warning text-dark",
          h5(class = "mb-0", "Multi-Analyte Review")
        ),
        div(
          class = "card-body",
          reactable::reactableOutput(session$ns("multi_analyte_table")),
          div(
            class = "d-flex gap-2 align-items-end flex-wrap mt-3",
            selectInput(
              session$ns("multi_analyte_action"),
              label = NULL,
              choices = c("Split" = "split", "Keep combined" = "keep", "Rename" = "rename"),
              width = "180px"
            ),
            textAreaInput(
              session$ns("multi_analyte_values"),
              label = NULL,
              value = "",
              rows = 3,
              placeholder = "One split part per line, or one rename value",
              width = "360px"
            ),
            actionButton(
              session$ns("apply_multi_analyte_resolution"),
              "Apply",
              icon = icon("check"),
              class = "btn-warning"
            )
          )
        )
      )
    })

    output$multi_analyte_table <- reactable::renderReactable({
      req(data_store$cleaned_data)

      multi_analyte_rows <- filter_multi_analyte_rows(data_store$cleaned_data)
      col_defs <- list(.row_index = reactable::colDef(show = FALSE))

      reactable::reactable(
        multi_analyte_rows,
        columns = col_defs,
        selection = "single",
        onClick = "select",
        defaultPageSize = 10,
        resizable = TRUE,
        wrap = FALSE,
        striped = TRUE,
        compact = TRUE
      )
    })

    observe({
      req(data_store$cleaned_data)
      selected <- reactable::getReactableState("multi_analyte_table", "selected")
      if (is.null(selected) || length(selected) == 0) {
        return()
      }

      multi_analyte_rows <- filter_multi_analyte_rows(data_store$cleaned_data)
      if (nrow(multi_analyte_rows) == 0 || selected[1] > nrow(multi_analyte_rows)) {
        return()
      }

      target_row <- multi_analyte_rows$.row_index[selected[1]]
      if (identical(data_store$multi_analyte_selected_row, target_row)) {
        return()
      }
      data_store$multi_analyte_selected_row <- target_row

      tag_map <- data_store$column_tags %||% list()
      name_cols <- names(tag_map)[tag_map == "Name"]
      field <- multi_analyte_field_for_row(data_store$cleaned_data, target_row, name_cols)
      suggestions <- suggest_multi_analyte_parts(data_store$cleaned_data[[field]][target_row])
      updateTextAreaInput(session, "multi_analyte_values", value = paste(suggestions, collapse = "\n"))
    })

    observeEvent(input$apply_multi_analyte_resolution, {
      req(data_store$cleaned_data)

      selected <- reactable::getReactableState("multi_analyte_table", "selected")
      if (is.null(selected) || length(selected) == 0) {
        showNotification("Select a multi-analyte row first.", type = "warning")
        return()
      }

      multi_analyte_rows <- filter_multi_analyte_rows(data_store$cleaned_data)
      if (nrow(multi_analyte_rows) == 0 || selected[1] > nrow(multi_analyte_rows)) {
        showNotification("Selected multi-analyte row is no longer available.", type = "warning")
        return()
      }

      tag_map <- data_store$column_tags %||% list()
      name_cols <- names(tag_map)[tag_map == "Name"]
      values <- input$multi_analyte_values
      if (is.null(values) || !nzchar(trimws(values))) {
        values <- NULL
      }

      tryCatch(
        {
          result <- resolve_multi_analyte_row(
            data_store$cleaned_data,
            name_cols = name_cols,
            row_index = multi_analyte_rows$.row_index[selected[1]],
            action = input$multi_analyte_action,
            values = values
          )

          data_store$cleaned_data <- result$cleaned_data
          data_store$cleaning_audit <- dplyr::bind_rows(
            data_store$cleaning_audit %||% empty_cleaning_audit(),
            result$audit_trail
          )
          data_store$curation_results <- NULL
          data_store$consensus_data <- NULL
          data_store$consensus_summary <- NULL
          data_store$resolution_state <- NULL
          data_store$resolved_data <- NULL
          data_store$review_visible_cols <- NULL
          data_store$curation_status <- NULL
          data_store$multi_analyte_selected_row <- NULL

          showNotification("Multi-analyte resolution applied.", type = "message", duration = 4)
        },
        error = function(e) {
          showNotification(paste("Multi-analyte resolution failed:", e$message), type = "error", duration = NULL)
        }
      )
    })

    filter_multi_cas_rows <- function(cleaned_data) {
      if (!("multi_cas" %in% names(cleaned_data))) {
        return(cleaned_data[0, , drop = FALSE])
      }

      cleaned_data[cleaned_data$multi_cas %in% TRUE, , drop = FALSE]
    }

    # Multi-CAS flagged rows section
    output$multi_cas_section <- renderUI({
      req(data_store$cleaned_data)

      cleaned_data <- data_store$cleaned_data

      multi_cas_rows <- filter_multi_cas_rows(cleaned_data)

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
          reactable::reactableOutput(session$ns("multi_cas_table")),
          actionButton(
            session$ns("split_row"),
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
      multi_cas_rows <- filter_multi_cas_rows(cleaned_data)

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
      multi_cas_rows <- filter_multi_cas_rows(cleaned_data)
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
          actionButton(session$ns("confirm_split"), "Confirm Split", class = "btn-warning")
        )
      ))
    })

    # Confirm split handler
    observeEvent(input$confirm_split, {
      req(data_store$cleaned_data)

      # Get selected row
      selected <- reactable::getReactableState("multi_cas_table", "selected")
      cleaned_data <- data_store$cleaned_data
      multi_cas_rows <- filter_multi_cas_rows(cleaned_data)
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
