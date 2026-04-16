# Harmonize Module
# Button-triggered numeric parsing + unit harmonization pipeline with QC dashboard.
#
# Pipeline stages (per PARS-06, UITG-04, UITG-05):
#   1. apply_corrections()          -- vectorized gsub() on Result column
#   2. parse_numeric_results()      -- handles sci-notation, ranges, qualifiers
#   3. harmonize_units()            -- vectorized unit conversion via unit_map
#   4. store results in data_store  -- list(parsed, harmonized, input_data)
#
# Data contract for data_store$harmonize_results (consumed by Phase 35):
#   list(
#     parsed     = <tibble from parse_numeric_results()>,
#     harmonized = <tibble from harmonize_units()>,
#     input_data = <data.frame passed into the pipeline>
#   )
#
# Plan 02 will populate the editors_panel output with chip-based editors for the
# unit table, corrections table, and unmatched-unit batch review panel.

#' Harmonize Module - UI
#'
#' @param id Module namespace ID
#'
#' @return UI elements for harmonize tab
#' @export
mod_harmonize_ui <- function(id) {
  ns <- NS(id)

  tagList(
    # Chip editor CSS (verbatim from mod_clean_data.R lines 15-22)
    tags$style(HTML(sprintf("
      .ref-chip { cursor: pointer; margin: 2px; display: inline-block; }
      .ref-chip:hover { opacity: 0.8; }
      .ref-chip-remove { cursor: pointer; margin-left: 4px; font-weight: bold; }
      .ref-chip-remove:hover { color: red; }
      .ref-chip-container { max-height: 200px; overflow-y: auto; padding: 8px; border: 1px solid #dee2e6; border-radius: 4px; background: #f8f9fa; }
      .ref-term-input { margin-top: 6px; }
    "))),

    # Chip editor JS -- delegated events scoped to this module's namespace via data-ns
    # Two handlers: chip_click (body click -> edit modal) and chip_remove (x button)
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
    ", ns(""), ns("chip_click"), ns(""), ns("chip_remove")))),

    # Main content when numeric tags exist
    conditionalPanel(
      condition = paste0("output['", ns("has_numeric_tags"), "']"),

      shinyjs::disabled(
        actionButton(
          ns("run_harmonization"),
          "Run Harmonization",
          class = "btn-success btn-lg mt-3",
          icon = icon("play")
        )
      ),

      # QC value boxes render after pipeline completes
      uiOutput(ns("qc_dashboard")),

      # --- Editor accordions added in Plan 02 ---
      uiOutput(ns("editors_panel"))
    ),

    # Empty state when no numeric tags
    conditionalPanel(
      condition = paste0("!output['", ns("has_numeric_tags"), "']"),
      div(
        class = "text-center text-muted py-5",
        bsicons::bs_icon("sliders", size = "3em"),
        h4("No numeric columns tagged"),
        p("Tag your Result and Unit columns first, then run harmonization.")
      )
    )
  )
}

#' Harmonize Module - Server
#'
#' @param id Module namespace ID
#' @param data_store Shared reactive data store
#'
#' @return NULL (module used for side effects on data_store)
#' @export
mod_harmonize_server <- function(id, data_store) {
  moduleServer(id, function(input, output, session) {

    # --- Internal helpers -----------------------------------------------------

    # Apply one-off corrections (PARS-06). Each pattern is treated as regex;
    # failures on a single row skip with a warning rather than crashing.
    apply_corrections <- function(values, corrections_tbl) {
      if (is.null(corrections_tbl) || nrow(corrections_tbl) == 0) {
        return(values)
      }
      result <- values
      for (i in seq_len(nrow(corrections_tbl))) {
        tryCatch(
          result <- gsub(corrections_tbl$pattern[i], corrections_tbl$replacement[i], result),
          error = function(e) {
            warning(sprintf(
              "Correction pattern '%s' failed: %s",
              corrections_tbl$pattern[i], e$message
            ))
          }
        )
      }
      result
    }

    # Add a pass-through (identity) mapping for an unmatched unit. Used by the
    # unmatched unit batch action in Plan 02; included here so the helper lives
    # with the rest of the module logic.
    add_passthrough_mapping <- function(unit_string, unit_map) {
      new_row <- tibble::tibble(
        from_unit = unit_string,
        to_unit = unit_string,
        multiplier = 1,
        category = "dimensionless",
        confidence = "LOW",
        source = "user_passthrough"
      )
      dplyr::bind_rows(unit_map, new_row)
    }

    # --- Empty-state gate -----------------------------------------------------

    output$has_numeric_tags <- reactive({
      !is.null(data_store$numeric_tags) && length(data_store$numeric_tags) > 0
    })
    outputOptions(output, "has_numeric_tags", suspendWhenHidden = FALSE)

    # --- Button enable/disable based on numeric_tags --------------------------

    observe({
      has_tags <- !is.null(data_store$numeric_tags) && length(data_store$numeric_tags) > 0
      if (has_tags) {
        shinyjs::enable("run_harmonization")
      } else {
        shinyjs::disable("run_harmonization")
      }
    })

    # --- Working-copy initialization (one-shot) -------------------------------
    # unit_map_working and corrections_working are session-local editable copies.
    # Initialized from data_store$reference_lists on first observation when they
    # are still NULL (avoids clobbering later edits).

    unit_map_ready <- reactiveVal(FALSE)
    observe({
      if (is.null(data_store$unit_map_working) &&
          !is.null(data_store$reference_lists$unit_map)) {
        data_store$unit_map_working <- data_store$reference_lists$unit_map
        if (!unit_map_ready()) unit_map_ready(TRUE)
      }
    })

    corrections_ready <- reactiveVal(FALSE)
    observe({
      if (is.null(data_store$corrections_working) &&
          !is.null(data_store$reference_lists$corrections)) {
        data_store$corrections_working <- data_store$reference_lists$corrections
        if (!corrections_ready()) corrections_ready(TRUE)
      }
    })

    # --- Pipeline execution ---------------------------------------------------

    observeEvent(input$run_harmonization, {
      req(data_store$clean, data_store$numeric_tags)

      # Guard: require at least one Result-tagged column (Pitfall 5)
      numeric_tags_vec <- unlist(data_store$numeric_tags, use.names = TRUE)
      result_cols <- names(numeric_tags_vec)[numeric_tags_vec == "Result"]

      if (length(result_cols) == 0) {
        showNotification(
          "No Result column tagged. Tag a Result column before running harmonization.",
          type = "warning",
          duration = 5
        )
        return()
      }

      unit_cols <- names(numeric_tags_vec)[numeric_tags_vec == "Unit"]

      shinyjs::disable("run_harmonization")

      tryCatch(
        {
          withProgress(message = "Running harmonization...", value = 0, {
            # Use cleaned_data (post-cleaning) when present, otherwise raw clean
            input_df <- if (!is.null(data_store$cleaned_data)) {
              data_store$cleaned_data
            } else {
              data_store$clean
            }

            # Extract Result column (first Result-tagged column if multiple)
            result_values <- as.character(input_df[[result_cols[1]]])

            # Stage 1: Apply one-off corrections (PARS-06)
            incProgress(0.15, detail = "Applying corrections...")
            corrected_values <- apply_corrections(
              result_values,
              data_store$corrections_working
            )

            # Stage 2: Parse numeric results
            incProgress(0.30, detail = "Parsing numeric results...")
            parse_tibble <- parse_numeric_results(corrected_values)

            # Stage 3: Harmonize units (if a Unit column is tagged)
            incProgress(0.30, detail = "Harmonizing units...")
            if (length(unit_cols) > 0) {
              unit_values <- as.character(input_df[[unit_cols[1]]])
              # Ranges expand rows -- re-broadcast unit via orig_row_id
              if (nrow(parse_tibble) > length(unit_values)) {
                unit_values_expanded <- unit_values[parse_tibble$orig_row_id]
              } else {
                unit_values_expanded <- unit_values
              }
              harmonize_tibble <- harmonize_units(
                values = parse_tibble$numeric_value,
                units = unit_values_expanded,
                unit_map = data_store$unit_map_working
              )
            } else {
              # No Unit column -- placeholder harmonize output with NA units
              harmonize_tibble <- tibble::tibble(
                orig_row_id = parse_tibble$orig_row_id,
                orig_unit = rep(NA_character_, nrow(parse_tibble)),
                harmonized_value = parse_tibble$numeric_value,
                harmonized_unit = rep(NA_character_, nrow(parse_tibble)),
                conversion_factor = rep(1, nrow(parse_tibble)),
                unit_flag = rep("", nrow(parse_tibble))
              )
            }

            # Stage 4: Store results
            incProgress(0.25, detail = "Finalizing...")
            data_store$harmonize_results <- list(
              parsed = parse_tibble,
              harmonized = harmonize_tibble,
              input_data = input_df
            )
            # Audit trail: joined tibble for export
            data_store$harmonize_audit <- dplyr::bind_cols(
              parse_tibble,
              harmonize_tibble[, c(
                "orig_unit", "harmonized_value", "harmonized_unit",
                "conversion_factor", "unit_flag"
              )]
            )
          })
        },
        error = function(e) {
          showNotification(
            paste(
              "Harmonization failed:", e$message,
              "Check column tags and try again."
            ),
            type = "error",
            duration = NULL
          )
        },
        finally = {
          shinyjs::enable("run_harmonization")
        }
      )
    })

    # --- QC dashboard (UITG-05, D-17..D-20) -----------------------------------

    output$qc_dashboard <- renderUI({
      req(data_store$harmonize_results)
      hr <- data_store$harmonize_results

      n_parsed <- nrow(hr$parsed)
      n_harmonized <- sum(hr$harmonized$unit_flag != "unmatched", na.rm = TRUE)
      n_dtxsid <- if ("consensus_dtxsid" %in% names(hr$input_data)) {
        sum(!is.na(hr$input_data$consensus_dtxsid))
      } else {
        0L
      }
      n_na_numeric <- sum(is.na(hr$parsed$numeric_value))

      bslib::layout_columns(
        col_widths = c(3, 3, 3, 3),
        bslib::value_box(
          title = "Rows Parsed",
          value = n_parsed,
          showcase = bsicons::bs_icon("123"),
          theme = "primary"
        ),
        bslib::value_box(
          title = "Rows Harmonized",
          value = n_harmonized,
          showcase = bsicons::bs_icon("check-circle"),
          theme = "success"
        ),
        bslib::value_box(
          title = "With DTXSID",
          value = n_dtxsid,
          showcase = bsicons::bs_icon("database"),
          theme = "info"
        ),
        bslib::value_box(
          title = "NA Results",
          value = n_na_numeric,
          showcase = bsicons::bs_icon("exclamation-triangle"),
          theme = "warning"
        )
      )
    })

    # --- Editors panel (Plan 02) ----------------------------------------------
    # Three accordion panels: unit table editor, corrections editor, unmatched
    # units batch-review panel. All start collapsed; titles include item counts.

    output$editors_panel <- renderUI({
      # Only show after unit_map_working is initialized
      req(unit_map_ready())

      bslib::accordion(
        id = session$ns("editors"),
        open = FALSE,
        multiple = TRUE,
        bslib::accordion_panel(
          title = uiOutput(session$ns("unit_editor_title")),
          icon = bsicons::bs_icon("rulers"),
          uiOutput(session$ns("unit_chip_editor")),
          actionButton(
            session$ns("add_unit_mapping"),
            "Add Unit Mapping",
            class = "btn-outline-primary btn-sm mt-2",
            icon = icon("plus")
          )
        ),
        bslib::accordion_panel(
          title = uiOutput(session$ns("corrections_editor_title")),
          icon = bsicons::bs_icon("pencil-square"),
          uiOutput(session$ns("corrections_chip_editor")),
          actionButton(
            session$ns("add_correction"),
            "Add Correction",
            class = "btn-outline-primary btn-sm mt-2",
            icon = icon("plus")
          )
        ),
        bslib::accordion_panel(
          title = uiOutput(session$ns("unmatched_title")),
          icon = bsicons::bs_icon("question-circle"),
          uiOutput(session$ns("unmatched_panel"))
        )
      )
    })

    # --- Accordion panel titles with item counts ------------------------------

    output$unit_editor_title <- renderUI({
      n <- if (!is.null(data_store$unit_map_working)) {
        nrow(data_store$unit_map_working)
      } else {
        0
      }
      sprintf("Unit Table Editor (%d mappings)", n)
    })

    output$corrections_editor_title <- renderUI({
      n <- if (!is.null(data_store$corrections_working)) {
        nrow(data_store$corrections_working)
      } else {
        0
      }
      sprintf("Corrections Editor (%d corrections)", n)
    })

    output$unmatched_title <- renderUI({
      if (is.null(data_store$harmonize_results)) {
        return("Unmatched Units")
      }
      harmonized <- data_store$harmonize_results$harmonized
      n_unique <- length(unique(
        harmonized$orig_unit[harmonized$unit_flag == "unmatched"]
      ))
      sprintf("Unmatched Units (%d)", n_unique)
    })

    # --- Unit table chip editor (DATA-04) -------------------------------------
    # Chips display "from_unit -> to_unit (xN)" per D-07. Badge class colors:
    #   bg-success (ECOTOX), bg-info (SSWQS), bg-primary (user),
    #   bg-secondary (user_passthrough). Only user-added rows get x-remove.

    render_unit_chip_editor <- function(unit_map_tbl) {
      ns <- session$ns
      chips <- lapply(seq_len(nrow(unit_map_tbl)), function(i) {
        row <- unit_map_tbl[i, ]

        badge_class <- switch(
          as.character(row$source),
          ECOTOX = "badge bg-success ref-chip",
          SSWQS = "badge bg-info ref-chip",
          user = "badge bg-primary ref-chip",
          user_passthrough = "badge bg-secondary ref-chip",
          "badge bg-light text-dark ref-chip"
        )

        # Chip label: "from_unit -> to_unit (xmultiplier)" per D-07
        chip_label <- sprintf("%s \u2192 %s", row$from_unit, row$to_unit)
        if (!is.na(row$multiplier) && row$multiplier != 1) {
          chip_label <- sprintf("%s (\u00d7%s)", chip_label, row$multiplier)
        }

        # X button only for user-added rows (app defaults not removable)
        remove_btn <- if (row$source %in% c("user", "user_passthrough")) {
          tags$span(
            class = "ref-chip-remove",
            `data-ns` = ns(""),
            `data-type` = "unit_map",
            `data-term` = row$from_unit,
            HTML("&times;")
          )
        }

        tags$span(
          class = badge_class,
          tags$span(
            class = "ref-chip-body",
            `data-ns` = ns(""),
            `data-type` = "unit_map",
            `data-term` = row$from_unit,
            chip_label
          ),
          remove_btn
        )
      })

      div(class = "ref-chip-container", chips)
    }

    output$unit_chip_editor <- renderUI({
      req(data_store$unit_map_working)
      render_unit_chip_editor(data_store$unit_map_working)
    })

    # --- Chip click observer -- opens edit modal (D-08, D-10) -----------------

    observeEvent(input$chip_click, {
      msg <- input$chip_click
      req(msg$type, msg$term)

      if (msg$type == "unit_map") {
        tbl <- data_store$unit_map_working
        row <- tbl[tbl$from_unit == msg$term, ][1, ]

        showModal(modalDialog(
          title = "Edit Unit Mapping",
          textInput(session$ns("modal_from_unit"), "From Unit", value = row$from_unit),
          textInput(session$ns("modal_to_unit"), "To Unit", value = row$to_unit),
          numericInput(session$ns("modal_multiplier"), "Multiplier", value = row$multiplier),
          selectInput(
            session$ns("modal_category"),
            "Category",
            choices = c(
              "mass_concentration",
              "mass_per_mass",
              "volume_concentration",
              "molar",
              "radioactivity",
              "biological",
              "dimensionless",
              "other"
            ),
            selected = row$category
          ),
          selectInput(
            session$ns("modal_confidence"),
            "Confidence",
            choices = c("HIGH", "MEDIUM", "LOW"),
            selected = row$confidence
          ),
          textInput(session$ns("modal_source"), "Source", value = row$source),
          # Store original from_unit for row lookup on save
          tags$input(
            type = "hidden",
            id = session$ns("modal_orig_from"),
            value = row$from_unit
          ),
          footer = tagList(
            modalButton("Discard"),
            actionButton(
              session$ns("save_unit_mapping"),
              "Save Mapping",
              class = "btn-primary"
            )
          ),
          easyClose = FALSE
        ))
      } else if (msg$type == "corrections") {
        tbl <- data_store$corrections_working
        row <- tbl[tbl$pattern == msg$term, ][1, ]

        showModal(modalDialog(
          title = "Edit Correction",
          textInput(
            session$ns("modal_corr_pattern"),
            "Pattern (regex)",
            value = row$pattern
          ),
          textInput(
            session$ns("modal_corr_replacement"),
            "Replacement",
            value = row$replacement
          ),
          tags$input(
            type = "hidden",
            id = session$ns("modal_corr_orig_pattern"),
            value = row$pattern
          ),
          footer = tagList(
            modalButton("Discard"),
            actionButton(
              session$ns("save_correction"),
              "Save Correction",
              class = "btn-primary"
            )
          ),
          easyClose = FALSE
        ))
      }
    })

    # --- Chip remove observer -- removes user-added rows only -----------------

    observeEvent(input$chip_remove, {
      msg <- input$chip_remove
      req(msg$type, msg$term)

      if (msg$type == "unit_map") {
        tbl <- data_store$unit_map_working
        idx <- which(
          tbl$from_unit == msg$term &
            tbl$source %in% c("user", "user_passthrough")
        )
        if (length(idx) > 0) {
          data_store$unit_map_working <- tbl[-idx[1], ]
        }
      } else if (msg$type == "corrections") {
        tbl <- data_store$corrections_working
        idx <- which(tbl$pattern == msg$term)
        if (length(idx) > 0) {
          data_store$corrections_working <- tbl[-idx[1], ]
        }
      }
    })

    # --- "Add Unit Mapping" button observer -- opens blank modal (D-09) ------

    observeEvent(input$add_unit_mapping, {
      showModal(modalDialog(
        title = "Add Unit Mapping",
        textInput(
          session$ns("modal_from_unit"),
          "From Unit",
          placeholder = "e.g., ug/L"
        ),
        textInput(
          session$ns("modal_to_unit"),
          "To Unit",
          placeholder = "e.g., mg/L"
        ),
        numericInput(session$ns("modal_multiplier"), "Multiplier", value = NA),
        selectInput(
          session$ns("modal_category"),
          "Category",
          choices = c(
            "mass_concentration",
            "mass_per_mass",
            "volume_concentration",
            "molar",
            "radioactivity",
            "biological",
            "dimensionless",
            "other"
          )
        ),
        selectInput(
          session$ns("modal_confidence"),
          "Confidence",
          choices = c("HIGH", "MEDIUM", "LOW")
        ),
        textInput(session$ns("modal_source"), "Source", value = "user"),
        tags$input(
          type = "hidden",
          id = session$ns("modal_orig_from"),
          value = ""
        ),
        footer = tagList(
          modalButton("Discard"),
          actionButton(
            session$ns("save_unit_mapping"),
            "Save Mapping",
            class = "btn-primary"
          )
        ),
        easyClose = FALSE
      ))
    })

    # --- save_unit_mapping observer -- append or update unit_map_working ------

    observeEvent(input$save_unit_mapping, {
      req(input$modal_from_unit, input$modal_to_unit)

      from_val <- trimws(input$modal_from_unit)
      to_val <- trimws(input$modal_to_unit)

      if (from_val == "" || to_val == "") {
        showNotification(
          "From Unit and To Unit are required.",
          type = "warning",
          duration = 3
        )
        return()
      }

      new_row <- tibble::tibble(
        from_unit = from_val,
        to_unit = to_val,
        multiplier = if (is.na(input$modal_multiplier)) 1 else input$modal_multiplier,
        category = input$modal_category,
        confidence = input$modal_confidence,
        source = input$modal_source
      )

      tbl <- data_store$unit_map_working
      orig_from <- input$modal_orig_from

      if (!is.null(orig_from) && orig_from != "") {
        # Edit mode: replace existing row
        idx <- which(tbl$from_unit == orig_from)
        if (length(idx) > 0) {
          tbl <- tbl[-idx[1], ]
        }
      }

      data_store$unit_map_working <- dplyr::bind_rows(tbl, new_row)
      removeModal()
    })

    # --- Cascade reset observers (D-26, D-27, D-28) ---------------------------
    # When the working copy of unit_map or corrections changes, invalidate
    # harmonize results and downstream toxval_output.

    prev_unit_map <- reactiveVal(NULL)
    observeEvent(data_store$unit_map_working,
      {
        if (!is.null(prev_unit_map()) &&
            !identical(prev_unit_map(), data_store$unit_map_working)) {
          data_store$harmonize_results <- NULL
          data_store$harmonize_audit <- NULL
          data_store$toxval_output <- NULL
        }
        prev_unit_map(data_store$unit_map_working)
      },
      ignoreNULL = FALSE
    )

    prev_corrections <- reactiveVal(NULL)
    observeEvent(data_store$corrections_working,
      {
        if (!is.null(prev_corrections()) &&
            !identical(prev_corrections(), data_store$corrections_working)) {
          data_store$harmonize_results <- NULL
          data_store$harmonize_audit <- NULL
          data_store$toxval_output <- NULL
        }
        prev_corrections(data_store$corrections_working)
      },
      ignoreNULL = FALSE
    )
  })
}
