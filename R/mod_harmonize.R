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
    tags$style(HTML(sprintf(
      "
      .ref-chip { cursor: pointer; margin: 2px; display: inline-block; }
      .ref-chip:hover { opacity: 0.8; }
      .ref-chip-remove { cursor: pointer; margin-left: 4px; font-weight: bold; }
      .ref-chip-remove:hover { color: red; }
      .ref-chip-container { max-height: 200px; overflow-y: auto; padding: 8px; border: 1px solid #dee2e6; border-radius: 4px; background: #f8f9fa; }
      .ref-term-input { margin-top: 6px; }
    "
    ))),

    # Chip editor JS -- delegated events scoped to this module's namespace via data-ns
    # Two handlers: chip_click (body click -> edit modal) and chip_remove (x button)
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
    ",
      ns(""),
      ns("chip_click"),
      ns(""),
      ns("chip_remove")
    ))),

    # Hidden button for programmatic triggering of harmonization pipeline
    # (shinyjs::click requires a DOM element; button removed from visible UI in Plan 03)
    tags$div(
      style = "display: none;",
      actionButton(ns("run_harmonization"), "Run Harmonization")
    ),

    # Main content when numeric tags exist
    conditionalPanel(
      condition = paste0("output['", ns("has_numeric_tags"), "']"),

      # QC value boxes render after pipeline completes
      uiOutput(ns("qc_dashboard")),

      # Stale results warning banner (Plan 34-04)
      uiOutput(ns("stale_warning")),

      # --- Editor accordions added in Plan 02 ---
      uiOutput(ns("editors_panel"))
    ),

    # Empty state when no taggable columns
    conditionalPanel(
      condition = paste0("!output['", ns("has_numeric_tags"), "']"),
      div(
        class = "text-center text-muted py-5",
        bsicons::bs_icon("sliders", size = "3em"),
        h4("No columns tagged for harmonization"),
        p("Tag your columns (Result, Unit, Study Date, etc.) first, then run the pipeline from the Clean Data tab.")
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
              corrections_tbl$pattern[i],
              e$message
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
      has_numeric <- !is.null(data_store$numeric_tags) && length(data_store$numeric_tags) > 0
      has_study <- !is.null(data_store$study_type_tags) && length(data_store$study_type_tags) > 0
      has_numeric || has_study
    })
    outputOptions(output, "has_numeric_tags", suspendWhenHidden = FALSE)

    # --- Working-copy initialization (one-shot) -------------------------------
    # unit_map_working and corrections_working are session-local editable copies.
    # Initialized from data_store$reference_lists on first observation when they
    # are still NULL (avoids clobbering later edits).

    unit_map_ready <- reactiveVal(FALSE)
    observe({
      if (
        is.null(data_store$unit_map_working) &&
          !is.null(data_store$reference_lists$unit_map)
      ) {
        data_store$unit_map_working <- data_store$reference_lists$unit_map
        if (!unit_map_ready()) unit_map_ready(TRUE)
      }
    })

    corrections_ready <- reactiveVal(FALSE)
    observe({
      if (
        is.null(data_store$corrections_working) &&
          !is.null(data_store$reference_lists$corrections)
      ) {
        data_store$corrections_working <- data_store$reference_lists$corrections
        if (!corrections_ready()) corrections_ready(TRUE)
      }
    })

    media_map_ready <- reactiveVal(FALSE)
    observe({
      if (
        is.null(data_store$media_map_working) &&
          !is.null(data_store$reference_lists$media_map)
      ) {
        data_store$media_map_working <- data_store$reference_lists$media_map
        if (!media_map_ready()) media_map_ready(TRUE)
      }
    })

    # --- Pipeline execution ---------------------------------------------------

    observeEvent(input$run_harmonization, {
      req(data_store$clean)
      # Read step mask from pre-flight modal (set by mod_clean_data.R run_all/run_checked)
      h_mask <- data_store$harmonize_step_mask
      if (is.null(h_mask)) {
        h_mask <- list(units = TRUE, duration = TRUE, dates = TRUE, media = TRUE)
      }

      # Allow run when either numeric or study-type tags are present
      has_numeric <- !is.null(data_store$numeric_tags) && length(data_store$numeric_tags) > 0
      has_study <- !is.null(data_store$study_type_tags) && length(data_store$study_type_tags) > 0
      if (!has_numeric && !has_study) {
        return()
      }

      # Capture changed_units before clearing (for incremental mode)
      pending_changes <- data_store$changed_units

      # Clear stale flag at start of run (Plan 34-04)
      data_store$harmonize_results_stale <- FALSE
      data_store$changed_units <- character(0)

      numeric_tags_vec <- unlist(data_store$numeric_tags, use.names = TRUE)
      result_cols <- names(numeric_tags_vec)[numeric_tags_vec == "Result"]
      unit_cols <- names(numeric_tags_vec)[numeric_tags_vec == "Unit"]

      # Guard: require Result column when numeric tags are present (Pitfall 5)
      # StudyDate-only runs skip numeric stages and proceed to date stage.
      if (has_numeric && length(result_cols) == 0) {
        showNotification(
          "No Result column tagged. Tag a Result column before running harmonization.",
          type = "warning",
          duration = 5
        )
        return()
      }

      # Determine if incremental mode is possible:
      # - Have existing results
      # - Have changed_units (unit mappings changed, not corrections)
      # - Have a Unit column tagged
      can_incremental <- length(pending_changes) > 0 &&
        !is.null(data_store$harmonize_results) &&
        length(unit_cols) > 0

      shinyjs::disable("run_harmonization")

      tryCatch(
        {
          if (can_incremental) {
            # --- INCREMENTAL MODE: Only re-harmonize affected rows ---
            withProgress(message = "Incremental harmonization...", value = 0, {
              existing <- data_store$harmonize_results
              parse_tibble <- existing$parsed
              old_harmonize <- existing$harmonized

              # Find rows where orig_unit matches changed units OR was unmatched
              # (unmatched rows should be re-checked against new mappings)
              affected_mask <- old_harmonize$orig_unit %in% pending_changes | old_harmonize$unit_flag == "unmatched"

              incProgress(
                0.3,
                detail = sprintf(
                  "Re-processing %d of %d rows...",
                  sum(affected_mask),
                  nrow(old_harmonize)
                )
              )

              if (sum(affected_mask) > 0) {
                # Re-run harmonize_units on affected subset only
                incremental_result <- harmonize_units(
                  values = parse_tibble$numeric_value[affected_mask],
                  units = old_harmonize$orig_unit[affected_mask],
                  unit_map = data_store$unit_map_working
                )

                # Merge back into full results — mutable columns only.
                # harmonize_units() returns orig_row_id = 1:n for its input
                # slice, so writing that back would destroy lineage.
                new_harmonize <- old_harmonize
                mutable_cols <- c("harmonized_value", "harmonized_unit", "conversion_factor", "unit_flag")
                new_harmonize[affected_mask, mutable_cols] <- incremental_result[, mutable_cols]

                # Invariant: orig_row_id must be unchanged after incremental merge
                stopifnot(identical(new_harmonize$orig_row_id, old_harmonize$orig_row_id))

                incProgress(0.6, detail = "Merging results...")

                data_store$harmonize_results <- list(
                  parsed = parse_tibble,
                  harmonized = new_harmonize,
                  input_data = existing$input_data
                )
                data_store$harmonize_audit <- dplyr::bind_cols(
                  parse_tibble,
                  new_harmonize[, c(
                    "orig_unit",
                    "harmonized_value",
                    "harmonized_unit",
                    "conversion_factor",
                    "unit_flag"
                  )]
                )

                # Invalidate toxval_output after incremental re-harmonization.
                # The stale output would not reflect updated unit mappings;
                # the next full-mode run will regenerate it with correct data.
                data_store$toxval_output <- NULL

                showNotification(
                  sprintf(
                    "Incremental: %d rows re-harmonized",
                    sum(affected_mask)
                  ),
                  type = "message",
                  duration = 3
                )
              } else {
                showNotification(
                  "No rows affected by unit changes",
                  type = "message",
                  duration = 3
                )
              }

              incProgress(0.1, detail = "Done")
            })
          } else {
            # --- FULL MODE: Parse + harmonize everything ---
            withProgress(message = "Running harmonization...", value = 0, {
              # Use cleaned_data (post-cleaning) when present, otherwise raw clean
              input_df <- if (!is.null(data_store$cleaned_data)) {
                data_store$cleaned_data
              } else {
                data_store$clean
              }

              # Pre-stage: Media harmonization for ppb/ppm routing (MEDIA-05, D-12)
              incProgress(0.05, detail = "Harmonizing media...")
              media_cols_pre <- if (!is.null(data_store$study_type_tags)) {
                local_stv <- unlist(data_store$study_type_tags)
                names(local_stv)[local_stv == "Media"]
              } else {
                character(0)
              }
              data_store$media_results <- NULL
              media_for_harmonize <- NULL

              if (h_mask$media && length(media_cols_pre) > 0) {
                media_tibble <- tryCatch(
                  harmonize_media(
                    raw_media = as.character(input_df[[media_cols_pre[1]]]),
                    orig_row_id = seq_len(nrow(input_df)),
                    media_map = data_store$media_map_working
                  ),
                  error = function(e) {
                    showNotification(
                      paste0(
                        "Media harmonization failed for column '",
                        media_cols_pre[1],
                        "': ",
                        conditionMessage(e),
                        ". Column skipped."
                      ),
                      type = "error",
                      duration = 10
                    )
                    NULL
                  }
                )
                if (!is.null(media_tibble)) {
                  data_store$media_results <- media_tibble
                  # Per-row media_category for ppb/ppm routing (D-12 tier 1)
                  media_for_harmonize <- media_tibble$media_category

                  n_matched <- sum(media_tibble$media_flag != "media_unmatched", na.rm = TRUE)
                  n_unmatched <- sum(media_tibble$media_flag == "media_unmatched", na.rm = TRUE)
                  showNotification(
                    sprintf("Media harmonized: %d matched, %d unmatched", n_matched, n_unmatched),
                    type = if (n_unmatched > 0) "warning" else "message",
                    duration = 6
                  )
                }
              }

              if (has_numeric) {
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

                # Stage 3: Harmonize units (if a Unit column is tagged and mask allows)
                incProgress(0.15, detail = "Harmonizing units...")
                if (h_mask$units && length(unit_cols) > 0) {
                  unit_values <- as.character(input_df[[unit_cols[1]]])
                  # Ranges expand rows -- re-broadcast unit via orig_row_id
                  if (nrow(parse_tibble) > length(unit_values)) {
                    unit_values_expanded <- unit_values[parse_tibble$orig_row_id]
                  } else {
                    unit_values_expanded <- unit_values
                  }
                  # media_for_harmonize: per-row from Media tag (D-12 tier 1), or NULL (tier 3 aqueous default)
                  harmonize_tibble <- harmonize_units(
                    values = parse_tibble$numeric_value,
                    units = unit_values_expanded,
                    unit_map = data_store$unit_map_working,
                    media = media_for_harmonize
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
                incProgress(0.15, detail = "Finalizing...")
                data_store$harmonize_results <- list(
                  parsed = parse_tibble,
                  harmonized = harmonize_tibble,
                  input_data = input_df
                )
                # Audit trail: joined tibble for export
                data_store$harmonize_audit <- dplyr::bind_cols(
                  parse_tibble,
                  harmonize_tibble[, c(
                    "orig_unit",
                    "harmonized_value",
                    "harmonized_unit",
                    "conversion_factor",
                    "unit_flag"
                  )]
                )
              } else {
                # StudyDate/Media-only: build identity harmonize_tibble (1:1 rows, no parse/harmonize)
                incProgress(0.55, detail = "Preparing date/media pipeline...")
                n_rows <- nrow(input_df)
                harmonize_tibble <- tibble::tibble(
                  orig_row_id = seq_len(n_rows),
                  orig_unit = rep(NA_character_, n_rows),
                  harmonized_value = rep(NA_real_, n_rows),
                  harmonized_unit = rep(NA_character_, n_rows),
                  conversion_factor = rep(1, n_rows),
                  unit_flag = rep("", n_rows)
                )
                parse_tibble <- tibble::tibble(
                  orig_row_id = seq_len(n_rows),
                  raw_value = rep(NA_character_, n_rows),
                  numeric_value = rep(NA_real_, n_rows),
                  value_flag = rep("", n_rows)
                )
                data_store$harmonize_results <- list(
                  parsed = parse_tibble,
                  harmonized = harmonize_tibble,
                  input_data = input_df
                )
              }

              # Stage 4.5: Duration harmonization (D-13, DUR-03)
              incProgress(0.05, detail = "Harmonizing durations...")
              duration_cols <- names(numeric_tags_vec)[numeric_tags_vec == "Duration"]
              duration_unit_cols <- names(numeric_tags_vec)[numeric_tags_vec == "DurationUnit"]
              data_store$duration_results <- NULL

              if (h_mask$duration && length(duration_cols) > 0 && length(duration_unit_cols) > 0) {
                dur_tibble <- harmonize_units(
                  values = as.numeric(input_df[[duration_cols[1]]]),
                  units = as.character(input_df[[duration_unit_cols[1]]]),
                  unit_map = data_store$unit_map_working,
                  category = "duration"
                )
                data_store$duration_results <- tibble::tibble(
                  orig_row_id = dur_tibble$orig_row_id,
                  study_duration_value = dur_tibble$harmonized_value,
                  study_duration_units = dur_tibble$harmonized_unit,
                  duration_unit_flag = dur_tibble$unit_flag
                )
              }

              # Stage 4.6: Date parsing (DATE-01, DATE-05)
              incProgress(0.05, detail = "Parsing dates...")
              study_type_tags_vec <- unlist(data_store$study_type_tags)
              date_cols <- if (!is.null(study_type_tags_vec)) {
                names(study_type_tags_vec)[study_type_tags_vec == "StudyDate"]
              } else {
                character(0)
              }
              data_store$date_results <- NULL

              if (h_mask$dates && length(date_cols) > 0) {
                date_tibble <- tryCatch(
                  parse_dates(
                    raw_dates = as.character(input_df[[date_cols[1]]]),
                    orig_row_id = seq_len(nrow(input_df))
                  ),
                  error = function(e) {
                    showNotification(
                      paste0(
                        "Date parsing failed for column '",
                        date_cols[1],
                        "': ",
                        conditionMessage(e),
                        ". Column skipped."
                      ),
                      type = "error",
                      duration = 10
                    )
                    NULL
                  }
                )

                if (!is.null(date_tibble)) {
                  data_store$date_results <- date_tibble

                  n_parsed <- sum(date_tibble$date_flag != "unparseable", na.rm = TRUE)
                  n_ambiguous <- sum(date_tibble$date_flag == "ambiguous", na.rm = TRUE)

                  if (n_parsed > 0) {
                    showNotification(
                      sprintf(
                        "Date parsing complete. %d dates parsed, %d flagged as ambiguous.",
                        n_parsed,
                        n_ambiguous
                      ),
                      type = "message",
                      duration = 5
                    )
                  } else {
                    showNotification(
                      sprintf(
                        "Date parsing: no valid dates found in column '%s'. All rows unparseable.",
                        date_cols[1]
                      ),
                      type = "warning",
                      duration = 8
                    )
                  }
                }
              }

              # Stage 5: Map to ToxVal schema (SCHM-01, UITG-06)
              incProgress(0.10, detail = "Mapping to ToxVal schema...")
              # Expand curated_data rows to match harmonized rows via orig_row_id.
              # parse_numeric_results() expands range values (1 row -> 3 rows),
              # so harmonize_tibble may have more rows than resolution_state.
              expanded_curated <- data_store$resolution_state[harmonize_tibble$orig_row_id, ]

              # Merge duration columns if present (D-10)
              if (!is.null(data_store$duration_results)) {
                dur_for_merge <- data_store$duration_results[, c(
                  "orig_row_id",
                  "study_duration_value",
                  "study_duration_units"
                )]
                # Duration orig_row_id maps to input_df rows (pre-range-expansion).
                # expanded_curated rows correspond to harmonize_tibble$orig_row_id
                # which may include range-expanded rows. Map duration values through
                # the same orig_row_id that produced expanded_curated.
                dur_values_expanded <- dur_for_merge$study_duration_value[harmonize_tibble$orig_row_id]
                dur_units_expanded <- dur_for_merge$study_duration_units[harmonize_tibble$orig_row_id]
                expanded_curated$study_duration_value <- dur_values_expanded
                expanded_curated$study_duration_units <- dur_units_expanded
              }

              # Merge date_year into expanded_curated for original_year ToxVal mapping (DATE-06, D-16)
              if (!is.null(data_store$date_results)) {
                year_expanded <- data_store$date_results$date_year[harmonize_tibble$orig_row_id]
                expanded_curated$year <- year_expanded
              }

              # Merge media_category into expanded_curated for ToxVal mapping (D-16, MEDIA-05)
              if (!is.null(data_store$media_results)) {
                media_expanded <- data_store$media_results$media_category[harmonize_tibble$orig_row_id]
                expanded_curated$media <- media_expanded
              }

              toxval_tibble <- tryCatch(
                map_to_toxval_schema(
                  curated_data = expanded_curated,
                  harmonized_data = harmonize_tibble,
                  source_name = data_store$file_info$name
                ),
                error = function(e) {
                  showNotification(
                    paste("ToxVal mapping failed:", conditionMessage(e)),
                    type = "warning",
                    duration = 8
                  )
                  NULL
                }
              )
              data_store$toxval_output <- toxval_tibble
            })
          }
        },
        error = function(e) {
          showNotification(
            paste(
              "Harmonization failed:",
              e$message,
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

      # Apply opacity when results are stale (Plan 34-04)
      stale_class <- if (isTRUE(data_store$harmonize_results_stale)) {
        "opacity-50"
      } else {
        ""
      }

      # Date parsing QC boxes (conditional -- only when date results exist)
      date_qc_row <- NULL
      if (!is.null(data_store$date_results)) {
        dr <- data_store$date_results
        n_date_parsed <- sum(dr$date_flag != "unparseable", na.rm = TRUE)
        n_partial <- sum(dr$date_flag == "partial", na.rm = TRUE)
        n_ambiguous <- sum(dr$date_flag == "ambiguous", na.rm = TRUE)
        n_unparseable <- sum(dr$date_flag == "unparseable", na.rm = TRUE)

        date_qc_row <- bslib::layout_columns(
          col_widths = c(3, 3, 3, 3),
          bslib::value_box(
            title = "Dates Parsed",
            value = n_date_parsed,
            showcase = bsicons::bs_icon("check-circle"),
            theme = "success"
          ),
          bslib::value_box(
            title = "Partial Dates",
            value = n_partial,
            showcase = bsicons::bs_icon("calendar"),
            theme = "info"
          ),
          bslib::value_box(
            title = "Ambiguous Dates",
            value = n_ambiguous,
            showcase = bsicons::bs_icon("question-circle"),
            theme = "warning"
          ),
          bslib::value_box(
            title = "Unparseable Dates",
            value = n_unparseable,
            showcase = bsicons::bs_icon("exclamation-triangle"),
            theme = "danger"
          )
        )
      }

      div(
        class = stale_class,
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
        ),
        date_qc_row
      )
    })

    # --- Stale warning banner (Plan 34-04) -------------------------------------
    # Shows when harmonize_results_stale is TRUE with affected row count

    output$stale_warning <- renderUI({
      if (!isTRUE(data_store$harmonize_results_stale)) {
        return(NULL)
      }

      n_changed <- length(data_store$changed_units)

      # Count affected rows if we have the data
      n_affected <- 0
      if (!is.null(data_store$numeric_tags) && !is.null(data_store$cleaned_data)) {
        numeric_tags_vec <- unlist(data_store$numeric_tags, use.names = TRUE)
        unit_cols <- names(numeric_tags_vec)[numeric_tags_vec == "Unit"]
        if (length(unit_cols) > 0) {
          unit_col <- unit_cols[1]
          n_affected <- sum(
            data_store$cleaned_data[[unit_col]] %in% data_store$changed_units,
            na.rm = TRUE
          )
        }
      }

      detail_text <- if (n_changed > 0 && n_affected > 0) {
        sprintf(" %d unit(s) changed, affecting %d rows.", n_changed, n_affected)
      } else if (n_changed > 0) {
        sprintf(" %d unit mapping(s) changed.", n_changed)
      } else {
        " Corrections changed since last run."
      }

      div(
        class = "alert alert-warning d-flex align-items-center mb-3",
        role = "alert",
        bsicons::bs_icon("exclamation-triangle-fill", class = "me-2"),
        tags$div(
          tags$strong("Results may be stale."),
          detail_text,
          actionLink(session$ns("rerun_now"), "Re-run now", class = "alert-link ms-2")
        )
      )
    })

    # Wire rerun_now link to trigger harmonization (Task 4)
    observeEvent(input$rerun_now, {
      shinyjs::click("run_harmonization")
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
          value = "unit_editor",
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
          value = "corrections_editor",
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
          value = "unmatched_units",
          icon = bsicons::bs_icon("question-circle"),
          uiOutput(session$ns("unmatched_panel"))
        ),
        bslib::accordion_panel(
          title = uiOutput(session$ns("media_editor_title")),
          value = "media_editor",
          icon = bsicons::bs_icon("globe"),
          uiOutput(session$ns("media_guidance")),
          DT::DTOutput(session$ns("media_table")),
          div(
            class = "mt-2",
            actionButton(
              session$ns("add_media_mapping"),
              "Add Media Mapping",
              class = "btn-outline-primary btn-sm",
              icon = icon("plus")
            )
          )
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

    output$media_guidance <- renderUI({
      n_unmatched <- 0
      if (!is.null(data_store$media_results)) {
        n_unmatched <- sum(
          data_store$media_results$media_flag == "media_unmatched",
          na.rm = TRUE
        )
      }

      if (n_unmatched > 0) {
        div(
          class = "alert alert-info py-2 mb-2",
          bsicons::bs_icon("info-circle", class = "me-1"),
          sprintf(
            "%d unmatched term(s) highlighted in yellow. Click a row to assign a canonical value, or use ",
            n_unmatched
          ),
          tags$strong("Add Media Mapping"),
          " below to create a new entry."
        )
      }
    })

    output$media_editor_title <- renderUI({
      n <- if (!is.null(data_store$media_map_working)) {
        nrow(data_store$media_map_working)
      } else {
        0
      }
      n_unmatched <- 0
      if (!is.null(data_store$media_results)) {
        n_unmatched <- sum(data_store$media_results$media_flag == "media_unmatched", na.rm = TRUE)
      }
      if (n_unmatched > 0) {
        sprintf("Media Classification (%d mappings, %d unmatched)", n, n_unmatched)
      } else {
        sprintf("Media Classification (%d mappings)", n)
      }
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

    # --- Corrections chip editor (PARS-06 UI, D-10) ---------------------------
    # Pattern -> replacement chips. All corrections are user-added and removable.

    render_corrections_chip_editor <- function(corrections_tbl) {
      ns <- session$ns

      if (nrow(corrections_tbl) == 0) {
        return(p(
          class = "text-muted small",
          "No corrections defined. Add corrections for source-specific malformed values."
        ))
      }

      chips <- lapply(seq_len(nrow(corrections_tbl)), function(i) {
        row <- corrections_tbl[i, ]
        chip_label <- sprintf("%s \u2192 %s", row$pattern, row$replacement)

        tags$span(
          class = "badge bg-primary ref-chip",
          tags$span(
            class = "ref-chip-body",
            `data-ns` = ns(""),
            `data-type` = "corrections",
            `data-term` = row$pattern,
            chip_label
          ),
          tags$span(
            class = "ref-chip-remove",
            `data-ns` = ns(""),
            `data-type` = "corrections",
            `data-term` = row$pattern,
            HTML("&times;")
          )
        )
      })

      div(class = "ref-chip-container", chips)
    }

    output$corrections_chip_editor <- renderUI({
      req(corrections_ready())
      render_corrections_chip_editor(data_store$corrections_working)
    })

    # --- "Add Correction" button observer -> blank modal (D-10) ---------------

    observeEvent(input$add_correction, {
      showModal(modalDialog(
        title = "Add Correction",
        textInput(
          session$ns("modal_corr_pattern"),
          "Pattern (regex)",
          placeholder = "e.g., 1\\.5E 3"
        ),
        textInput(
          session$ns("modal_corr_replacement"),
          "Replacement",
          placeholder = "e.g., 1.5E3"
        ),
        tags$input(
          type = "hidden",
          id = session$ns("modal_corr_orig_pattern"),
          value = ""
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
    })

    # --- save_correction observer -- append or update corrections_working -----

    observeEvent(input$save_correction, {
      req(input$modal_corr_pattern)

      pattern_val <- trimws(input$modal_corr_pattern)
      if (pattern_val == "") {
        showNotification(
          "Pattern is required.",
          type = "warning",
          duration = 3
        )
        return()
      }

      replacement_val <- if (is.null(input$modal_corr_replacement)) {
        ""
      } else {
        input$modal_corr_replacement
      }

      new_row <- tibble::tibble(
        pattern = pattern_val,
        replacement = replacement_val
      )

      tbl <- data_store$corrections_working
      orig_pattern <- input$modal_corr_orig_pattern

      if (!is.null(orig_pattern) && orig_pattern != "") {
        # Edit mode: remove old row
        idx <- which(tbl$pattern == orig_pattern)
        if (length(idx) > 0) {
          tbl <- tbl[-idx[1], ]
        }
      }

      data_store$corrections_working <- dplyr::bind_rows(tbl, new_row)
      removeModal()
    })

    # --- Media classification DT table (MEDIT-01, D-07, D-08, D-12) ----------

    output$media_table <- DT::renderDT(
      {
        req(media_map_ready())
        tbl <- data_store$media_map_working

        if (is.null(tbl) || nrow(tbl) == 0) {
          return(DT::datatable(
            tibble::tibble(
              term = character(),
              canonical = character(),
              source = character(),
              active = character()
            ),
            escape = FALSE,
            selection = "none",
            rownames = FALSE,
            options = list(
              language = list(
                emptyTable = "No media data. Run the pipeline with a Media-tagged column to populate the classification table."
              )
            )
          ))
        }

        # Determine unmatched status: rows where canonical is NA or empty
        is_unmatched <- is.na(tbl$canonical) | !nzchar(as.character(ifelse(is.na(tbl$canonical), "", tbl$canonical)))

        # Build display tibble (4 columns per D-08)
        display_tbl <- tibble::tibble(
          term = tbl$term,
          canonical = dplyr::if_else(is_unmatched, "(unmatched)", tbl$canonical),
          source = dplyr::case_when(
            tbl$source == "user" ~ '<span class="badge bg-primary">user</span>',
            TRUE ~ '<span class="badge bg-secondary">amos</span>'
          ),
          active = dplyr::if_else(tbl$active, "Yes", "No")
        )

        # Sort: unmatched first (D-07), then alphabetical within each group
        sort_order <- order(!is_unmatched, tbl$term)
        display_tbl <- display_tbl[sort_order, ]

        # Track row classes for highlighting
        row_classes <- ifelse(is_unmatched[sort_order], "table-warning", "")

        DT::datatable(
          display_tbl,
          escape = FALSE,
          selection = "none",
          rownames = FALSE,
          options = list(
            pageLength = 25,
            dom = "ftp",
            rowCallback = DT::JS(sprintf(
              "function(row, data, displayNum, index) {
                 var classes = %s;
                 if (classes[index]) $(row).addClass(classes[index]);
               }",
              jsonlite::toJSON(unname(row_classes))
            ))
          ),
          callback = DT::JS(sprintf(
            "table.on('click', 'tr', function() {
               var d = table.row(this).data();
               if (d) Shiny.setInputValue('%s', {term: d[0], ts: Date.now()}, {priority: 'event'});
             });",
            session$ns("open_media_edit_modal")
          ))
        )
      },
      server = FALSE
    )

    # --- Media edit modal observer (D-06) -------------------------------------

    observeEvent(input$open_media_edit_modal, {
      msg <- input$open_media_edit_modal
      req(msg$term)

      tbl <- data_store$media_map_working

      # Clean the "(unmatched)" display value back to the raw term
      search_term <- trimws(tolower(msg$term))
      # If the display value is "(unmatched)", we need to look up by position;
      # since "(unmatched)" is just a display alias, search by the actual term value
      actual_term <- if (search_term == "(unmatched)") search_term else search_term
      row <- tbl[tolower(tbl$term) == actual_term, ]

      # AMOS entries are read-only (D-12)
      if (nrow(row) > 0 && row$source[1] == "amos") {
        showNotification(
          "AMOS entries are read-only. Add a user mapping for this term to override.",
          type = "message",
          duration = 5
        )
        return()
      }

      # Determine modal title: "Add" for unmatched, "Edit" for existing user row
      is_new <- nrow(row) == 0 ||
        is.na(row$canonical[1]) ||
        !nzchar(as.character(ifelse(is.na(row$canonical[1]), "", row$canonical[1])))
      modal_title <- if (is_new) "Add Media Mapping" else "Edit Media Mapping"

      canonical_val <- if (!is_new) row$canonical[1] else ""
      active_val <- if (!is_new) isTRUE(row$active[1]) else TRUE
      orig_term <- if (nrow(row) > 0) row$term[1] else actual_term

      showModal(modalDialog(
        title = modal_title,
        easyClose = FALSE,
        textInput(session$ns("modal_media_term"), "Term", value = orig_term),
        textInput(
          session$ns("modal_media_canonical"),
          "Canonical",
          value = canonical_val,
          placeholder = "e.g., freshwater"
        ),
        checkboxInput(session$ns("modal_media_active"), "Active", value = active_val),
        tags$input(
          type = "hidden",
          id = session$ns("modal_media_orig_term"),
          value = orig_term
        ),
        footer = tagList(
          modalButton("Discard"),
          actionButton(session$ns("save_media_mapping"), "Save Mapping", class = "btn-primary")
        )
      ))
    })

    # --- "Add Media Mapping" button observer -- blank modal -------------------

    observeEvent(
      input$add_media_mapping,
      {
        showModal(modalDialog(
          title = "Add Media Mapping",
          easyClose = FALSE,
          textInput(session$ns("modal_media_term"), "Term", value = ""),
          textInput(
            session$ns("modal_media_canonical"),
            "Canonical",
            value = "",
            placeholder = "e.g., freshwater"
          ),
          checkboxInput(session$ns("modal_media_active"), "Active", value = TRUE),
          tags$input(
            type = "hidden",
            id = session$ns("modal_media_orig_term"),
            value = ""
          ),
          footer = tagList(
            modalButton("Discard"),
            actionButton(session$ns("save_media_mapping"), "Save Mapping", class = "btn-primary")
          )
        ))
      },
      ignoreInit = TRUE
    )

    # --- Save media mapping with AMOS override confirmation (D-13, D-09, D-10) -

    # Reactive value to stage pending save when AMOS override needed
    media_pending_save <- reactiveVal(NULL)

    observeEvent(input$save_media_mapping, {
      req(input$modal_media_term, input$modal_media_canonical)

      new_row <- tibble::tibble(
        term = trimws(tolower(input$modal_media_term)),
        canonical = trimws(input$modal_media_canonical),
        canonical_term = trimws(input$modal_media_canonical),
        envo_id = NA_character_,
        media_category = NA_character_,
        source = "user",
        active = isTRUE(input$modal_media_active)
      )

      tbl <- data_store$media_map_working
      inferred_new_row <- infer_media_categories(dplyr::bind_rows(new_row, tbl))[1, ]
      new_row$envo_id <- inferred_new_row$envo_id
      new_row$media_category <- inferred_new_row$media_category

      # Check for AMOS conflict (D-13)
      amos_conflict <- tbl$term == new_row$term & tbl$source == "amos"
      orig_term <- input$modal_media_orig_term
      is_new_term <- is.null(orig_term) || orig_term == "" || orig_term != new_row$term

      if (is_new_term && any(amos_conflict)) {
        existing_canonical <- tbl$canonical[which(amos_conflict)[1]]
        media_pending_save(new_row)
        showModal(modalDialog(
          title = "Override AMOS Mapping?",
          easyClose = FALSE,
          p(sprintf(
            'This term already has an AMOS mapping (canonical: "%s").',
            existing_canonical
          )),
          p("Your mapping will take priority at runtime. The AMOS entry will remain as fallback."),
          footer = tagList(
            modalButton("Cancel"),
            actionButton(session$ns("confirm_amos_override"), "Override", class = "btn-primary")
          )
        ))
        return()
      }

      # No conflict — proceed with save
      do_save_media_mapping(new_row, orig_term)
    })

    observeEvent(input$confirm_amos_override, {
      pending <- media_pending_save()
      req(pending)
      media_pending_save(NULL)
      do_save_media_mapping(pending, pending$term)
    })

    do_save_media_mapping <- function(new_row, orig_term) {
      tbl <- data_store$media_map_working

      # Remove old user entry if updating (upsert logic)
      if (!is.null(orig_term) && orig_term != "") {
        idx <- which(tbl$term == orig_term & tbl$source == "user")
        if (length(idx) > 0) tbl <- tbl[-idx[1], ]
      }

      data_store$media_map_working <- dplyr::bind_rows(new_row, tbl)

      # Persist user rows only to RDS (D-09)
      user_rows <- data_store$media_map_working[data_store$media_map_working$source == "user", ]
      cache_path <- system.file("extdata/reference_cache", package = "concert")
      if (nzchar(cache_path)) {
        saveRDS(user_rows, file.path(cache_path, "user_media_map.rds"), compress = FALSE)
      }

      removeModal()

      # Re-run notification (D-10)
      showNotification(
        tagList(
          "Media mappings updated. Re-run the pipeline to apply changes?",
          actionLink(session$ns("media_rerun_now"), "Re-run now", class = "alert-link ms-2")
        ),
        type = "message",
        duration = 8
      )
    }

    observeEvent(input$media_rerun_now, {
      shinyjs::click("run_harmonization")
    })

    # --- Unmatched units batch panel (UNIT-06, D-12..D-16) --------------------
    # Three display states:
    #   1. Pre-run: "Run harmonization to see unmatched units."
    #   2. Post-run, all matched: "All units matched successfully." (alert-success)
    #   3. Post-run, unmatched: list with per-unit "Add Mapping" and batch action
    # Per-unit unit-name values escaped in onclick to mitigate T-34-06 JS injection.

    output$unmatched_panel <- renderUI({
      ns <- session$ns

      if (is.null(data_store$harmonize_results)) {
        return(p(
          class = "text-muted small",
          "Run the pipeline to see unmatched units."
        ))
      }

      harmonized <- data_store$harmonize_results$harmonized
      unmatched <- harmonized[harmonized$unit_flag == "unmatched", ]

      if (nrow(unmatched) == 0) {
        return(div(
          class = "alert alert-success",
          bsicons::bs_icon("check-circle"),
          " All units matched successfully."
        ))
      }

      # Summarize by unique unit string with row counts (D-13)
      unmatched_summary <- unmatched |>
        dplyr::count(orig_unit, name = "n") |>
        dplyr::arrange(dplyr::desc(n))

      div(
        class = "mb-3",
        # Batch action: Add All as Pass-through (D-14)
        actionButton(
          ns("add_all_passthrough"),
          "Add All as Pass-through",
          class = "btn-outline-secondary btn-sm"
        ),
        hr(),
        # Per-unit rows with counts and individual Add Mapping buttons (D-13, D-15)
        lapply(seq_len(nrow(unmatched_summary)), function(i) {
          u <- unmatched_summary[i, ]
          safe_id <- make.names(u$orig_unit)
          div(
            class = "d-flex justify-content-between align-items-center mb-2",
            span(sprintf("%s (%d rows)", u$orig_unit, u$n)),
            actionButton(
              ns(paste0("add_map_", safe_id)),
              "Add Mapping",
              class = "btn-primary btn-sm",
              onclick = sprintf(
                "Shiny.setInputValue('%s', {unit: %s, ts: Date.now()});",
                ns("add_unmatched_mapping"),
                jsonlite::toJSON(unname(u$orig_unit), auto_unbox = TRUE)
              )
            )
          )
        })
      )
    })

    # --- "Add All as Pass-through" observer (D-14) ----------------------------

    observeEvent(input$add_all_passthrough, {
      req(data_store$harmonize_results)

      harmonized <- data_store$harmonize_results$harmonized
      unmatched_units <- unique(
        harmonized$orig_unit[harmonized$unit_flag == "unmatched"]
      )

      if (length(unmatched_units) == 0) {
        return()
      }

      tbl <- data_store$unit_map_working
      for (u in unmatched_units) {
        tbl <- add_passthrough_mapping(u, tbl)
      }
      data_store$unit_map_working <- tbl

      showNotification(
        sprintf(
          "Added %d pass-through mappings. Re-run the pipeline to apply.",
          length(unmatched_units)
        ),
        type = "message",
        duration = 5
      )
    })

    # --- Per-unit "Add Mapping" observer (D-15) -------------------------------
    # Opens unit mapping modal pre-filled with msg$unit as from_unit. Reuses the
    # same save_unit_mapping observer as the add/edit flows.

    observeEvent(input$add_unmatched_mapping, {
      msg <- input$add_unmatched_mapping
      req(msg$unit)

      showModal(modalDialog(
        title = "Add Unit Mapping",
        textInput(session$ns("modal_from_unit"), "From Unit", value = msg$unit),
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

    # --- Cascade reset observers (D-26, D-27, D-28) ---------------------------
    # When the working copy of unit_map or corrections changes, invalidate
    # harmonize results and downstream toxval_output.

    # --- Stale results pattern (Plan 34-04) ------------------------------------
    # Instead of clearing results on edit, mark as stale and track changed units.
    # This allows batch edits without forcing full re-runs each time.

    prev_unit_map <- reactiveVal(NULL)
    observeEvent(
      data_store$unit_map_working,
      {
        if (
          !is.null(prev_unit_map()) &&
            !identical(prev_unit_map(), data_store$unit_map_working)
        ) {
          # Mark stale instead of clearing — allows batch edits
          if (!is.null(data_store$harmonize_results)) {
            data_store$harmonize_results_stale <- TRUE
            data_store$toxval_output <- NULL # Force re-generation on next run

            # Track which from_units were added/changed for incremental re-run
            old_units <- prev_unit_map()$from_unit
            new_units <- data_store$unit_map_working$from_unit
            added <- setdiff(new_units, old_units)
            data_store$changed_units <- unique(c(data_store$changed_units, added))
          }
        }
        prev_unit_map(data_store$unit_map_working)
      },
      ignoreNULL = FALSE
    )

    prev_corrections <- reactiveVal(NULL)
    observeEvent(
      data_store$corrections_working,
      {
        if (
          !is.null(prev_corrections()) &&
            !identical(prev_corrections(), data_store$corrections_working)
        ) {
          # Mark stale instead of clearing
          if (!is.null(data_store$harmonize_results)) {
            data_store$harmonize_results_stale <- TRUE
            data_store$toxval_output <- NULL # Force re-generation on next run
          }
        }
        prev_corrections(data_store$corrections_working)
      },
      ignoreNULL = FALSE
    )
  })
}
