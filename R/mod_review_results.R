# Review Results Module
# Resolution table with validation and error recovery

# Module-internal helper: Recalculate consensus summary from resolution state (single source of truth)
recalc_consensus_summary <- function(df) {
  list(
    n_agree = sum(df$consensus_status == "agree", na.rm = TRUE),
    n_disagree = sum(df$consensus_status == "disagree" & !(!is.na(df$.pinned) & df$.pinned), na.rm = TRUE),
    n_agree_caveat = sum(df$consensus_status == "agree_caveat", na.rm = TRUE),
    n_single = sum(df$consensus_status == "single", na.rm = TRUE),
    n_error = sum(df$consensus_status == "error", na.rm = TRUE),
    n_manual = sum(df$consensus_status == "manual", na.rm = TRUE),
    n_unresolvable = sum(df$consensus_status == "unresolvable", na.rm = TRUE),
    n_wqx = sum(df$consensus_status == "wqx", na.rm = TRUE),
    n_auto_resolved = sum(df$consensus_status == "auto_resolved", na.rm = TRUE),
    n_suggested = sum(df$consensus_status == "suggested", na.rm = TRUE)
  )
}

source_to_column <- function(prefix, source) {
  if (is.na(source) || !nzchar(source)) {
    return(NA_character_)
  }
  if (source == "Name") {
    return(prefix)
  }
  paste0(prefix, "_", source)
}

dtxsid_to_column <- function(dtxsid_col, prefix) {
  if (dtxsid_col == "dtxsid") {
    return(prefix)
  }
  sub("^dtxsid_", paste0(prefix, "_"), dtxsid_col)
}

pick_source_aligned_values <- function(df, prefix) {
  n <- nrow(df)
  values <- rep(NA_character_, n)

  source <- if ("consensus_source" %in% names(df)) as.character(df$consensus_source) else rep(NA_character_, n)
  dtxsid <- if ("consensus_dtxsid" %in% names(df)) as.character(df$consensus_dtxsid) else rep(NA_character_, n)
  dtxsid_cols <- find_dtxsid_cols(df)

  for (i in seq_len(n)) {
    src <- source[i]

    if (!is.na(src) && nzchar(src) && !src %in% c("consensus", "manual_entry")) {
      source_col <- source_to_column(prefix, src)
      if (!is.na(source_col) && source_col %in% names(df) && !is.na(df[[source_col]][i])) {
        values[i] <- as.character(df[[source_col]][i])
        next
      }
    }

    if (!is.na(dtxsid[i]) && length(dtxsid_cols) > 0) {
      for (dc in dtxsid_cols) {
        if (!is.na(df[[dc]][i]) && identical(as.character(df[[dc]][i]), dtxsid[i])) {
          candidate_col <- dtxsid_to_column(dc, prefix)
          if (candidate_col %in% names(df) && !is.na(df[[candidate_col]][i])) {
            values[i] <- as.character(df[[candidate_col]][i])
            break
          }
        }
      }
    }

    # Backward-compatible fallback for legacy rows/tests without consensus_source
    # or rows that have no DTXSID-bearing source, e.g. WQX-only evidence.
    if (is.na(values[i])) {
      prefixed_cols <- if (prefix %in% names(df)) prefix else character(0)
      prefixed_cols <- c(prefixed_cols, grep(paste0("^", prefix, "_"), names(df), value = TRUE))
      for (pc in prefixed_cols) {
        if (!is.na(df[[pc]][i])) {
          values[i] <- as.character(df[[pc]][i])
          break
        }
      }
    }
  }

  values
}

# Vectorized match_type derivation (replaces row-by-row sapply)
derive_match_type <- function(df) {
  tier_cols <- c(intersect("source_tier", names(df)), grep("^source_tier_", names(df), value = TRUE))
  if (length(tier_cols) == 0) {
    return(rep("Unknown", nrow(df)))
  }

  tier_label_map <- c(
    "exact" = "Exact Match",
    "cas" = "CAS Lookup",
    "starts_with" = "Starts-With",
    "wqx_exact" = "WQX Exact",
    "wqx_alias" = "WQX Alias",
    "wqx_fuzzy" = "WQX Fuzzy"
  )

  raw_tier <- pick_source_aligned_values(df, "source_tier")
  result <- rep("No Match", nrow(df))
  is_known <- !is.na(raw_tier) & raw_tier %in% names(tier_label_map)
  result[is_known] <- tier_label_map[raw_tier[is_known]]

  result
}

derive_row_flag_html <- function(flag) {
  flag <- as.character(flag)
  flag[is.na(flag)] <- ""

  colors <- c(
    "BAD" = "#DC3545",
    "FOLLOW-UP" = "#FFC107",
    "VERIFIED" = "#198754"
  )
  text_colors <- c(
    "BAD" = "#fff",
    "FOLLOW-UP" = "#212529",
    "VERIFIED" = "#fff"
  )

  unname(vapply(flag, function(value) {
    if (value == "") {
      return("")
    }
    bg <- unname(colors[value]) %||% "#6c757d"
    fg <- unname(text_colors[value]) %||% "#fff"
    paste0(
      '<span class="badge row-flag-chip" style="background:',
      bg,
      ";color:",
      fg,
      ';font-size:0.8em;">',
      htmltools::htmlEscape(value),
      "</span>"
    )
  }, character(1)))
}

# Vectorized Resolution column builder (replaces row-by-row sapply)
derive_resolution_html <- function(df, row_indices) {
  n <- nrow(df)
  result <- character(n)
  status <- as.character(df$consensus_status)
  dtxsid <- df$consensus_dtxsid
  pinned <- if (".pinned" %in% names(df)) df$.pinned else rep(FALSE, n)
  pinned[is.na(pinned)] <- FALSE

  pref_name <- pick_source_aligned_values(df, "preferredName")
  manual_pref <- if ("manual_preferredName" %in% names(df)) df$manual_preferredName else rep(NA_character_, n)

  # Pre-compute search icon once (used by multiple blocks below)
  search_icon <- as.character(shiny::icon("search"))

  # WQX override: prefer user-selected name over pipeline result (per D-08)
  wqx_override <- if ("wqx_override_name" %in% names(df)) df$wqx_override_name else rep(NA_character_, n)

  # agree / agree_caveat / single
  resolved <- status %in% c("agree", "agree_caveat", "single") & !is.na(dtxsid)
  has_pref <- resolved & !is.na(pref_name)
  result[has_pref] <- paste0(
    "\u2705 ",
    htmltools::htmlEscape(dtxsid[has_pref]),
    " \u2014 ",
    htmltools::htmlEscape(pref_name[has_pref])
  )
  result[resolved & !has_pref] <- paste0("\u2705 ", htmltools::htmlEscape(dtxsid[resolved & !has_pref]))

  # manual
  manual_mask <- status == "manual" & !is.na(dtxsid)
  mpref <- manual_pref
  mpref[is.na(mpref)] <- pref_name[is.na(mpref)]
  manual_badge <- '<span class="badge bg-info ms-1" style="font-size:0.7em;">manual</span>'
  has_mp <- manual_mask & !is.na(mpref)
  result[has_mp] <- paste0(
    "\u2705 ",
    htmltools::htmlEscape(dtxsid[has_mp]),
    " \u2014 ",
    htmltools::htmlEscape(mpref[has_mp]),
    " ",
    manual_badge
  )
  result[manual_mask & !has_mp] <- paste0(
    "\u2705 ",
    htmltools::htmlEscape(dtxsid[manual_mask & !has_mp]),
    " ",
    manual_badge
  )

  # disagree + pinned
  dp <- status == "disagree" & pinned
  dp_dtx <- dp & !is.na(dtxsid)
  dp_pref <- dp_dtx & !is.na(pref_name)
  change_link <- function(idx) {
    paste0(
      ' <a href="#" class="change-resolution-link small text-primary" data-row="',
      idx,
      '" style="text-decoration:underline;cursor:pointer;">Change</a>'
    )
  }
  result[dp_pref] <- paste0(
    "\U0001F4CC ",
    htmltools::htmlEscape(dtxsid[dp_pref]),
    " \u2014 ",
    htmltools::htmlEscape(pref_name[dp_pref]),
    change_link(row_indices[dp_pref])
  )
  result[dp_dtx & !dp_pref] <- paste0(
    "\U0001F4CC ",
    htmltools::htmlEscape(dtxsid[dp_dtx & !dp_pref]),
    change_link(row_indices[dp_dtx & !dp_pref])
  )
  result[dp & is.na(dtxsid)] <- paste0(
    "\U0001F4CC (None selected)",
    change_link(row_indices[dp & is.na(dtxsid)])
  )

  # auto_resolved
  auto_mask <- status == "auto_resolved" & !is.na(dtxsid)
  auto_reasons <- if (".resolution_reason" %in% names(df)) df$.resolution_reason else rep(NA_character_, n)
  auto_title <- ifelse(!is.na(auto_reasons), paste0(' title="', htmltools::htmlEscape(auto_reasons), '"'), "")
  auto_badge_vec <- paste0(
    '<span class="badge ms-1" style="background:#0D6EFD;color:#fff;font-size:0.7em;"',
    auto_title,
    ">auto</span>"
  )
  compare_btn_vec <- paste0(
    ' <button class="compare-btn btn btn-sm btn-outline-primary" data-row="',
    row_indices,
    '">',
    search_icon,
    " Compare</button>"
  )
  auto_pref <- auto_mask & !is.na(pref_name)
  result[auto_pref] <- paste0(
    "\u2705 ",
    htmltools::htmlEscape(dtxsid[auto_pref]),
    " \u2014 ",
    htmltools::htmlEscape(pref_name[auto_pref]),
    " ",
    auto_badge_vec[auto_pref],
    compare_btn_vec[auto_pref]
  )
  auto_no_pref <- auto_mask & !auto_pref & !is.na(dtxsid)
  result[auto_no_pref] <- paste0(
    "\u2705 ",
    htmltools::htmlEscape(dtxsid[auto_no_pref]),
    " ",
    auto_badge_vec[auto_no_pref],
    compare_btn_vec[auto_no_pref]
  )

  # suggested (not yet resolved / not pinned)
  suggested_mask <- status == "suggested" & !pinned
  result[suggested_mask] <- paste0(
    '<button class="compare-btn btn btn-sm btn-outline-info" data-row="',
    row_indices[suggested_mask],
    '">',
    search_icon,
    " Review Suggestion</button>"
  )

  # suggested + pinned (accepted suggestion — show resolved display)
  suggested_pinned <- status == "suggested" & pinned & !is.na(dtxsid)
  accepted_badge <- '<span class="badge ms-1" style="background:#0DCAF0;color:#fff;font-size:0.7em;">accepted</span>'
  sp_pref <- suggested_pinned & !is.na(pref_name)
  result[sp_pref] <- paste0(
    "\u2705 ",
    htmltools::htmlEscape(dtxsid[sp_pref]),
    " \u2014 ",
    htmltools::htmlEscape(pref_name[sp_pref]),
    " ",
    accepted_badge,
    compare_btn_vec[sp_pref]
  )
  sp_no_pref <- suggested_pinned & !sp_pref
  result[sp_no_pref] <- paste0(
    "\u2705 ",
    htmltools::htmlEscape(dtxsid[sp_no_pref]),
    " ",
    accepted_badge,
    compare_btn_vec[sp_no_pref]
  )

  # disagree + not pinned
  compare_mask <- status == "disagree" & !pinned
  result[compare_mask] <- paste0(
    '<button class="compare-btn btn btn-sm btn-outline-primary" data-row="',
    row_indices[compare_mask],
    '">',
    search_icon,
    ' Compare</button>'
  )

  # unresolvable
  result[status == "unresolvable"] <- "\u26A0\uFE0F Auto-curation failed"

  # wqx
  wqx_mask <- status == "wqx"
  effective_wqx_name <- ifelse(!is.na(wqx_override), wqx_override, pref_name)
  wqx_has_pref <- wqx_mask & !is.na(effective_wqx_name)
  wqx_badge <- '<span class="badge bg-success ms-1" style="font-size:0.7em;">wqx</span>'
  review_btn <- paste0(
    ' <button class="wqx-review-btn btn btn-sm btn-outline-success" data-row="',
    row_indices,
    '">Review</button>'
  )
  result[wqx_has_pref] <- paste0(
    "\u2705 ",
    htmltools::htmlEscape(effective_wqx_name[wqx_has_pref]),
    " ",
    wqx_badge,
    review_btn[wqx_has_pref]
  )
  result[wqx_mask & !wqx_has_pref] <- paste0(
    "\u2705 WQX matched ",
    wqx_badge,
    review_btn[wqx_mask & !wqx_has_pref]
  )

  result
}

# Build reverse lookup: original_idx -> group index (O(n) build, O(1) lookup)
build_group_reverse_map <- function(dedup_group_map) {
  if (is.null(dedup_group_map)) {
    return(NULL)
  }
  reverse <- integer()
  for (i in seq_along(dedup_group_map)) {
    for (idx in dedup_group_map[[i]]) {
      reverse[idx] <- i
    }
  }
  reverse
}

# Look up all original row indices belonging to the same dedup group as `original_idx`
get_group_rows <- function(original_idx, dedup_group_map) {
  if (is.null(dedup_group_map)) {
    return(original_idx)
  }
  reverse <- build_group_reverse_map(dedup_group_map)
  grp_idx <- reverse[original_idx]
  if (is.na(grp_idx)) {
    return(original_idx)
  }
  dedup_group_map[[grp_idx]]
}

#' Review Results Module - UI
#'
#' @param id Module namespace ID
#'
#' @return UI elements for review results tab
#' @export
mod_review_results_ui <- function(id) {
  ns <- NS(id)

  # Filter persistence JavaScript — saves/restores reactable filters across re-renders
  filter_persist_js <- tags$script(HTML(sprintf(
    "
    (function() {
      var tableId = '%s';
      var savedFilters = [];

      // Before Shiny recalculates the output, save current filters
      $(document).on('shiny:recalculating', function(event) {
        if (event.target && event.target.id === tableId) {
          try {
            var state = Reactable.getState(tableId);
            if (state && state.sorted) { /* table exists */ }
            savedFilters = (state && state.filters) ? state.filters.slice() : [];
          } catch(e) {
            savedFilters = [];
          }
        }
      });

      // After the output is recalculated, restore filters
      $(document).on('shiny:value', function(event) {
        if (event.target && event.target.id === tableId && savedFilters.length > 0) {
          var filtersToRestore = savedFilters.slice();
          savedFilters = [];
          // Small delay to let reactable initialize
          setTimeout(function() {
            filtersToRestore.forEach(function(f) {
              try {
                Reactable.setFilter(tableId, f.id, f.value);
              } catch(e) {}
            });
            // Also restore the <select> dropdown values to match
            filtersToRestore.forEach(function(f) {
              var container = document.getElementById(tableId);
              if (!container) return;
              var selects = container.querySelectorAll('select');
              selects.forEach(function(sel) {
                var onChange = sel.getAttribute('onchange') || '';
                if (onChange.indexOf(\"'\" + f.id + \"'\") !== -1) {
                  sel.value = f.value || '';
                }
              });
            });
          }, 50);
        }
      });
    })();
  ",
    ns("curation_table")
  )))

  # Resolution dropdown JavaScript (namespace-aware)
  resolution_js <- tags$script(HTML(sprintf(
    "
    $(document).on('change', '.resolve-select', function() {
      var row = $(this).data('row');
      var column = $(this).val();
      if (column && column !== '') {
        Shiny.setInputValue('%s', {row: row, column: column}, {priority: 'event'});
      }
    });
  ",
    ns("resolve_row_choice")
  )))

  # Compare button JavaScript (for modal-based resolution)
  compare_js <- tags$script(HTML(sprintf(
    "
    $(document).on('click', '.compare-btn', function() {
      var row = $(this).data('row');
      Shiny.setInputValue('%s', {row: row, t: Math.random()}, {priority: 'event'});
    });

    $(document).on('click', '.change-resolution-link', function() {
      var row = $(this).data('row');
      Shiny.setInputValue('%s', {row: row, t: Math.random()}, {priority: 'event'});
    });

    $(document).on('click', '.modal-select-btn', function() {
      var column = $(this).data('column');
      Shiny.setInputValue('%s', {column: column, t: Math.random()}, {priority: 'event'});
      // Highlight selected card, unhighlight others
      $('.candidate-card').css({'border-color': '#dee2e6', 'background-color': '#fff'});
      $(this).closest('.candidate-card').css({'border-color': '#0d6efd', 'background-color': '#f0f7ff'});
      // Show confirm button
      $('#%s').show();
    });

    $(document).on('click', '.wqx-review-btn', function() {
      var row = $(this).data('row');
      Shiny.setInputValue('%s', {row: row, t: Math.random()}, {priority: 'event'});
    });
  ",
    ns("compare_row_click"),
    ns("compare_row_click"),
    ns("modal_candidate_select"),
    ns("confirm_container"),
    ns("wqx_review_click")
  )))

  # Inline DTXSID editing JavaScript (namespace-aware)
  dtxsid_edit_js <- tags$script(HTML(sprintf(
    "
    $(document).on('blur', '.dtxsid-edit', function() {
      var row = parseInt($(this).data('row'));
      var value = $(this).val().trim();
      Shiny.setInputValue('%s', {row: row, value: value, t: Math.random()}, {priority: 'event'});
    });
    $(document).on('keypress', '.dtxsid-edit', function(e) {
      if (e.which === 13) { $(this).blur(); }
    });
  ",
    ns("dtxsid_manual_edit")
  )))

  # Copy table to clipboard JavaScript
  copy_table_js <- tags$script(HTML(sprintf(
    "
    $(document).on('click', '#%s', function() {
      var table = document.querySelector('.ReactTable');
      if (!table) return;
      var rows = table.querySelectorAll('.rt-tr-group');
      var headers = table.querySelectorAll('.rt-th');
      var text = '';
      // Header row
      var hdr = [];
      headers.forEach(function(h) { if (h.offsetParent !== null) hdr.push(h.textContent.trim()); });
      text += hdr.join('\\t') + '\\n';
      // Data rows
      rows.forEach(function(row) {
        var cells = row.querySelectorAll('.rt-td');
        var vals = [];
        cells.forEach(function(c) { if (c.offsetParent !== null) vals.push(c.textContent.trim()); });
        text += vals.join('\\t') + '\\n';
      });
      navigator.clipboard.writeText(text).then(function() {
        Shiny.setInputValue('%s', {t: Math.random()});
      });
    });
  ",
    ns("copy_table"),
    ns("copy_done")
  )))

  clear_filters_js <- tags$script(HTML(sprintf(
    "
    $(document).on('click', '#%s', function() {
      var tableId = '%s';
      try {
        var state = Reactable.getState(tableId);
        var filters = (state && state.filters) ? state.filters.slice() : [];
        filters.forEach(function(f) {
          Reactable.setFilter(tableId, f.id, undefined);
        });
      } catch(e) {}

      var container = document.getElementById(tableId);
      if (container) {
        container.querySelectorAll('select').forEach(function(sel) {
          sel.value = '';
        });
      }
    });
  ",
    ns("clear_table_filters"),
    ns("curation_table")
  )))

  tagList(
    filter_persist_js,
    resolution_js,
    compare_js,
    dtxsid_edit_js,
    copy_table_js,
    clear_filters_js,
    reactable.extras::reactable_extras_dependency(),

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
          selectInput(
            ns("batch_row_flag"),
            label = NULL,
            choices = c(
              "Flag selected..." = "",
              "BAD" = "BAD",
              "FOLLOW-UP" = "FOLLOW-UP",
              "VERIFIED" = "VERIFIED",
              "Clear flag" = "CLEAR"
            ),
            width = "150px"
          ),
          actionButton(
            ns("apply_batch_row_flag"),
            "Apply Flag",
            icon = icon("tags"),
            class = "btn-sm btn-outline-primary"
          ),
          actionButton(
            ns("clear_table_filters"),
            "Clear Filters",
            icon = icon("filter-circle-xmark"),
            class = "btn-sm btn-outline-secondary"
          ),
          actionButton(
            ns("filter_errors"),
            "Show Errors",
            icon = icon("filter"),
            class = "btn-sm btn-outline-secondary"
          ),
          shinyjs::hidden(
            actionButton(
              ns("accept_all_suggestions"),
              "Accept All Suggestions",
              icon = icon("wand-magic-sparkles"),
              class = "btn-sm btn-primary"
            )
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
          actionButton(
            ns("copy_table"),
            "Copy",
            icon = icon("copy"),
            class = "btn-sm btn-outline-secondary"
          ),
          downloadButton(
            ns("download_csv"),
            "CSV",
            class = "btn-sm btn-outline-secondary"
          ),
          downloadButton(
            ns("download_curated"),
            "Download Excel",
            class = "btn-primary"
          )
        )
      ),

      # Table toolbar: column toggle + page size
      div(
        class = "mb-2 d-flex align-items-start gap-3",
        tags$details(
          tags$summary(
            class = "btn btn-sm btn-outline-secondary",
            icon("columns"),
            " Toggle Columns"
          ),
          div(
            class = "card card-body mt-1 p-2",
            style = "max-height: 200px; overflow-y: auto;",
            uiOutput(ns("col_visibility_checkboxes"))
          )
        ),
        div(
          class = "d-flex align-items-center gap-2",
          tags$label("Rows:", `for` = ns("page_size"), class = "mb-0 small text-muted"),
          selectInput(
            ns("page_size"),
            label = NULL,
            width = "80px",
            choices = c(10, 25, 50, 100),
            selected = 25
          )
        )
      ),

      reactable::reactableOutput(ns("curation_table"))
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
#' @export
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

      resolved <- summary$n_agree +
        (summary$n_agree_caveat %||% 0) +
        (summary$n_single %||% 0) +
        (summary$n_manual %||% 0) +
        (summary$n_wqx %||% 0) +
        (summary$n_auto_resolved %||% 0)
      errors <- (summary$n_error %||% 0) + (summary$n_unresolvable %||% 0)

      layout_columns(
        col_widths = c(2, 2, 2, 2, 2, 2),
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
        ),
        value_box(
          title = "Auto-Resolved",
          value = summary$n_auto_resolved %||% 0,
          showcase = bsicons::bs_icon("magic"),
          theme = "primary"
        ),
        value_box(
          title = "Suggested",
          value = summary$n_suggested %||% 0,
          showcase = bsicons::bs_icon("lightbulb"),
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

    # Column visibility checkboxes (for untagged columns)
    output$col_visibility_checkboxes <- renderUI({
      req(data_store$resolution_state, data_store$column_tags, data_store$clean)

      tagged_col_names <- names(data_store$column_tags)
      all_original_cols <- names(data_store$clean)
      df_names <- names(data_store$resolution_state)

      untagged_cols <- setdiff(
        all_original_cols[all_original_cols %in% df_names],
        tagged_col_names
      )

      if (length(untagged_cols) == 0) {
        return(tags$small(class = "text-muted", "No toggleable columns available"))
      }

      checkboxGroupInput(
        session$ns("visible_cols"),
        label = NULL,
        choices = untagged_cols,
        selected = character(0),
        inline = TRUE
      )
    })

    # Copy done notification
    observeEvent(input$copy_done, {
      showNotification("Table copied to clipboard", type = "message", duration = 2)
    })

    # CSV download handler
    output$download_csv <- downloadHandler(
      filename = function() {
        file_base <- if (!is.null(data_store$file_info)) {
          tools::file_path_sans_ext(data_store$file_info$name)
        } else {
          "curated_data"
        }
        paste0(file_base, "_curated_", format(Sys.Date(), "%Y%m%d"), ".csv")
      },
      content = function(file) {
        req(data_store$resolution_state)
        readr::write_csv(data_store$resolution_state, file)
      }
    )

    # Curation results table (vectorized + deduplicated)
    output$curation_table <- reactable::renderReactable({
      req(data_store$resolution_state, data_store$dtxsid_cols)

      df <- init_resolution_state(data_store$resolution_state)
      data_store$resolution_state <- df
      dtxsid_cols <- data_store$dtxsid_cols
      df$consensus_status <- as.character(df$consensus_status)

      # Vectorized match_type (replaces O(n*m) sapply)
      df$match_type <- derive_match_type(df)
      df <- dplyr::relocate(df, match_type, .after = consensus_status)

      # QC flag column
      if (!is.null(data_store$qc_results) && length(data_store$qc_results$row_indices) > 0) {
        df$qc_flag <- NA_character_
        df$qc_flag[data_store$qc_results$row_indices] <- "WARN: non-ASCII"
        df <- dplyr::relocate(df, qc_flag, .after = match_type)
      }

      # Error filter
      if (isTRUE(data_store$error_filter_active)) {
        filter_mask <- df$consensus_status %in% c("error", "unresolvable")
        df <- df[filter_mask, , drop = FALSE]
        original_indices <- which(filter_mask)
      } else {
        original_indices <- seq_len(nrow(df))
      }

      # --- Deduplication ---
      name_cols <- names(data_store$column_tags)[data_store$column_tags == "Name"]
      cas_cols <- names(data_store$column_tags)[data_store$column_tags == "CASRN"]
      group_cols <- intersect(
        c(name_cols, cas_cols, "consensus_dtxsid", "consensus_status", "match_type"),
        names(df)
      )

      if (length(group_cols) > 0 && nrow(df) > 0) {
        group_key <- do.call(
          paste,
          c(
            lapply(group_cols, function(col) {
              v <- df[[col]]
              ifelse(is.na(v), "\x02NA\x02", as.character(v))
            }),
            sep = "\x1F"
          )
        )

        first_idx <- which(!duplicated(group_key))
        dedup_keys <- group_key[first_idx]
        key_counts <- tabulate(match(group_key, dedup_keys))

        group_split <- split(original_indices, match(group_key, dedup_keys))
        data_store$dedup_group_map <- group_split
        rep_indices <- original_indices[first_idx]
        data_store$display_row_map <- rep_indices

        df_display <- df[first_idx, , drop = FALSE]
        df_display$n_rows <- key_counts
      } else {
        data_store$dedup_group_map <- as.list(original_indices)
        data_store$display_row_map <- original_indices
        rep_indices <- original_indices
        df_display <- df
        df_display$n_rows <- rep(1L, nrow(df))
      }

      # Vectorized Resolution column
      df_display$Resolution <- derive_resolution_html(df_display, rep_indices)

      # --- Column visibility ---
      always_hidden <- c(
        dtxsid_cols,
        grep("^preferredName_", names(df_display), value = TRUE),
        grep("^searchName_", names(df_display), value = TRUE),
        grep("^rank_", names(df_display), value = TRUE),
        grep("^source_tier_", names(df_display), value = TRUE),
        ".pinned",
        ".manual_entry",
        "manual_preferredName"
      )
      always_hidden_set <- unique(always_hidden)

      tagged_col_names <- names(data_store$column_tags)
      all_original_cols <- names(data_store$clean)
      untagged_cols <- setdiff(
        all_original_cols[all_original_cols %in% names(df_display)],
        tagged_col_names
      )
      visible_extra <- input$visible_cols

      col_defs <- list()
      for (col_name in names(df_display)) {
        if (col_name %in% always_hidden_set) {
          col_defs[[col_name]] <- reactable::colDef(show = FALSE)
        } else if (col_name %in% untagged_cols && !(col_name %in% visible_extra)) {
          col_defs[[col_name]] <- reactable::colDef(show = FALSE)
        }
      }

      # Count badge column
      col_defs[["n_rows"]] <- reactable::colDef(
        name = "Rows",
        minWidth = 60,
        cell = function(value, index) {
          if (value == 1L) {
            htmltools::span(as.character(value))
          } else {
            htmltools::span(
              class = "badge bg-secondary",
              style = "font-size:0.85em;",
              paste0("\u00D7", value)
            )
          }
        }
      )

      # WQX confidence column (fuzzy similarity score; NA for exact/alias rows)
      # In multi-tag mode, grep finds wqx_confidence_Chemical AND wqx_confidence_CASRN.
      # Only show columns that have at least one non-NA value (WQX only matches Name-tagged columns).
      wqx_conf_cols <- grep("^wqx_confidence", names(df_display), value = TRUE)
      wqx_conf_visible <- Filter(function(col) !all(is.na(df_display[[col]])), wqx_conf_cols)
      # Hide all-NA wqx_confidence columns (e.g., wqx_confidence_CASRN in multi-tag mode)
      wqx_conf_hidden <- setdiff(wqx_conf_cols, wqx_conf_visible)
      for (whc in wqx_conf_hidden) {
        col_defs[[whc]] <- reactable::colDef(show = FALSE)
      }
      for (wcc in wqx_conf_visible) {
        col_defs[[wcc]] <- reactable::colDef(
          name = "WQX Conf.",
          minWidth = 80,
          align = "right",
          cell = function(value, index) {
            if (is.na(value)) {
              return("")
            }
            formatC(value, digits = 2, format = "f")
          }
        )
      }

      # Similarity score column (per D-05: 2-decimal right-aligned, blank for non-disagree)
      if ("similarity_score" %in% names(df_display)) {
        col_defs[["similarity_score"]] <- reactable::colDef(
          name = "Sim. Score",
          minWidth = 80,
          align = "right",
          cell = function(value, index) {
            if (is.na(value)) {
              return("")
            }
            formatC(value, digits = 2, format = "f")
          }
        )
      }

      # Dropdown filter helper
      table_id <- session$ns("curation_table")
      make_select_filter <- function(choices, col_name) {
        function(values, name) {
          htmltools::tags$select(
            onchange = sprintf(
              "Reactable.setFilter('%s', '%s', event.target.value || undefined)",
              table_id,
              col_name
            ),
            style = "width:100%;font-size:0.85em;padding:2px;",
            htmltools::tags$option(value = "", "All"),
            lapply(choices, function(val) {
              htmltools::tags$option(value = val, val)
            })
          )
        }
      }

      # Badge: match_type
      if ("match_type" %in% names(df_display)) {
        match_levels <- intersect(
          c("Exact Match", "CAS Lookup", "Starts-With", "WQX Exact", "WQX Alias", "WQX Fuzzy", "No Match"),
          unique(as.character(df_display$match_type))
        )
        match_colors <- c(
          "Exact Match" = "#28a745",
          "CAS Lookup" = "#007bff",
          "Starts-With" = "#ffc107",
          "WQX Exact" = "#20c997",
          "WQX Alias" = "#17a2b8",
          "WQX Fuzzy" = "#6f42c1",
          "No Match" = "#dc3545"
        )
        match_text_colors <- c("Starts-With" = "#212529")

        col_defs[["match_type"]] <- reactable::colDef(
          cell = function(value, index) {
            val <- as.character(value)
            bg <- unname(match_colors[val]) %||% "#6c757d"
            fg <- unname(match_text_colors[val]) %||% "#fff"
            htmltools::span(
              style = sprintf(
                "background:%s;color:%s;padding:2px 8px;border-radius:4px;font-weight:600;font-size:0.85em;display:inline-block;",
                bg,
                fg
              ),
              val
            )
          },
          filterMethod = htmlwidgets::JS(
            "function(rows, columnId, filterValue) {
              return rows.filter(function(row) {
                return row.values[columnId] === filterValue;
              });
            }"
          ),
          filterInput = make_select_filter(match_levels, "match_type")
        )
      }

      # Badge: consensus_status
      if ("consensus_status" %in% names(df_display)) {
        status_levels <- intersect(
          c(
            "agree",
            "agree_caveat",
            "single",
            "wqx",
            "disagree",
            "error",
            "manual",
            "unresolvable",
            "auto_resolved",
            "suggested"
          ),
          unique(as.character(df_display$consensus_status))
        )
        status_colors <- c(
          "agree" = "#28a745",
          "agree_caveat" = "#17a2b8",
          "single" = "#6c757d",
          "wqx" = "#20c997",
          "disagree" = "#fd7e14",
          "error" = "#343a40",
          "manual" = "#6f42c1",
          "unresolvable" = "#721c24",
          "auto_resolved" = "#0D6EFD",
          "suggested" = "#0DCAF0"
        )

        col_defs[["consensus_status"]] <- reactable::colDef(
          cell = function(value, index) {
            val <- as.character(value)
            bg <- unname(status_colors[val]) %||% "#6c757d"
            htmltools::span(
              style = sprintf(
                "background:%s;color:#fff;padding:2px 8px;border-radius:4px;font-weight:600;font-size:0.85em;display:inline-block;",
                bg
              ),
              val
            )
          },
          filterMethod = htmlwidgets::JS(
            "function(rows, columnId, filterValue) {
              return rows.filter(function(row) {
                return row.values[columnId] === filterValue;
              });
            }"
          ),
          filterInput = make_select_filter(status_levels, "consensus_status")
        )
      }

      # Badge: row_flag
      if ("row_flag" %in% names(df_display)) {
        flag_levels <- intersect(valid_row_flags(), unique(as.character(stats::na.omit(df_display$row_flag))))
        col_defs[["row_flag"]] <- reactable::colDef(
          name = "Flag",
          html = TRUE,
          minWidth = 100,
          cell = function(value, index) {
            derive_row_flag_html(value)
          },
          filterMethod = htmlwidgets::JS(
            "function(rows, columnId, filterValue) {
              return rows.filter(function(row) {
                return row.values[columnId] === filterValue;
              });
            }"
          ),
          filterInput = make_select_filter(flag_levels, "row_flag")
        )
      }

      # Dropdown filter: qc_flag
      if ("qc_flag" %in% names(df_display)) {
        qc_levels <- na.omit(unique(df_display$qc_flag))
        if (length(qc_levels) > 0) {
          col_defs[["qc_flag"]] <- reactable::colDef(
            filterMethod = htmlwidgets::JS(
              "function(rows, columnId, filterValue) {
                return rows.filter(function(row) {
                  var val = row.values[columnId];
                  if (filterValue === '__na__') return val == null || val === '';
                  return val === filterValue;
                });
              }"
            ),
            filterInput = function(values, name) {
              htmltools::tags$select(
                onchange = sprintf(
                  "Reactable.setFilter('%s', '%s', event.target.value || undefined)",
                  table_id,
                  "qc_flag"
                ),
                style = "width:100%;font-size:0.85em;padding:2px;",
                htmltools::tags$option(value = "", "All"),
                lapply(qc_levels, function(val) {
                  htmltools::tags$option(value = val, val)
                })
              )
            }
          )
        }
      }

      # Resolution: HTML content
      col_defs[["Resolution"]] <- reactable::colDef(html = TRUE, minWidth = 250)

      # consensus_dtxsid: inline editable for error/unresolvable rows
      if ("consensus_dtxsid" %in% names(df_display)) {
        col_defs[["consensus_dtxsid"]] <- reactable::colDef(
          cell = function(value, index) {
            status <- as.character(df_display$consensus_status[index])
            original_idx <- rep_indices[index]
            if (status %in% c("error", "unresolvable")) {
              htmltools::tags$input(
                type = "text",
                class = "form-control form-control-sm dtxsid-edit",
                value = if (!is.na(value)) value else "",
                `data-row` = original_idx,
                placeholder = "DTXSID...",
                style = "width:140px;font-size:0.85em;"
              )
            } else {
              if (!is.na(value)) as.character(value) else ""
            }
          }
        )
      }

      # Row style
      has_qc_flag <- "qc_flag" %in% names(df_display)
      row_bg_colors <- c(
        "agree" = "rgba(40, 167, 69, 0.08)",
        "agree_caveat" = "rgba(40, 167, 69, 0.05)",
        "disagree" = "rgba(220, 53, 69, 0.08)",
        "single" = "rgba(108, 117, 125, 0.05)",
        "wqx" = "rgba(32, 201, 151, 0.08)",
        "error" = "rgba(220, 53, 69, 0.12)",
        "manual" = "rgba(111, 66, 193, 0.08)",
        "unresolvable" = "rgba(114, 28, 36, 0.12)",
        "auto_resolved" = "rgba(13, 110, 253, 0.08)",
        "suggested" = "rgba(13, 202, 240, 0.08)"
      )

      row_style_fn <- function(index) {
        if (has_qc_flag) {
          qc_val <- df_display$qc_flag[index]
          if (!is.na(qc_val) && qc_val == "WARN: non-ASCII") {
            return(list(backgroundColor = "#fff3cd"))
          }
        }
        status <- as.character(df_display$consensus_status[index])
        bg <- unname(row_bg_colors[status])
        if (!is.null(bg) && !is.na(bg)) list(backgroundColor = bg) else NULL
      }

      page_size <- as.integer(input$page_size %||% 25)

      reactable::reactable(
        df_display,
        columns = col_defs,
        filterable = TRUE,
        selection = "multiple",
        onClick = "select",
        rowStyle = row_style_fn,
        defaultPageSize = page_size,
        resizable = TRUE,
        wrap = TRUE,
        compact = TRUE,
        bordered = TRUE,
        highlight = TRUE
      )
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
        observeEvent(
          input[[paste0("priority_up_", i)]],
          {
            if (i > 1) {
              new_priority <- data_store$priority_order
              # Swap with previous
              temp <- new_priority[i - 1]
              new_priority[i - 1] <- new_priority[i]
              new_priority[i] <- temp
              data_store$priority_order <- new_priority
            }
          },
          ignoreInit = TRUE
        )

        # Down button
        observeEvent(
          input[[paste0("priority_down_", i)]],
          {
            if (i < length(data_store$priority_order)) {
              new_priority <- data_store$priority_order
              # Swap with next
              temp <- new_priority[i + 1]
              new_priority[i + 1] <- new_priority[i]
              new_priority[i] <- temp
              data_store$priority_order <- new_priority
            }
          },
          ignoreInit = TRUE
        )
      })
    })

    # Handle inline cell editing for manual DTXSID entry
    observeEvent(input$dtxsid_manual_edit, {
      info <- input$dtxsid_manual_edit
      row_idx <- info$row
      new_value <- trimws(as.character(info$value))

      if (new_value == "") {
        return()
      }

      current_status <- as.character(isolate(data_store$resolution_state)$consensus_status[row_idx])
      if (!current_status %in% c("error", "unresolvable")) {
        showNotification("Only error/unresolvable rows can be manually edited", type = "warning")
        return()
      }

      if (!grepl("^DTXSID\\d+$", new_value, ignore.case = TRUE)) {
        showNotification(
          paste0("Invalid format: ", new_value, ". Expected: DTXSIDxxxxxxx"),
          type = "warning",
          duration = 5
        )
        return()
      }

      group_rows <- get_group_rows(row_idx, isolate(data_store$dedup_group_map))
      for (r in group_rows) {
        data_store$manual_queue[[as.character(r)]] <- new_value
      }

      n_grp <- length(group_rows)
      msg <- if (n_grp > 1) {
        sprintf("%d rows queued for validation", n_grp)
      } else {
        paste0("Row ", row_idx, " queued for validation")
      }
      showNotification(msg, type = "message", duration = 2)
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

    # Show/hide Accept All Suggestions based on suggested row count
    observe({
      req(data_store$resolution_state)
      pinned_vec <- !is.na(data_store$resolution_state$.pinned) & data_store$resolution_state$.pinned
      has_suggested <- any(
        data_store$resolution_state$consensus_status == "suggested" & !pinned_vec,
        na.rm = TRUE
      )
      if (has_suggested) {
        shinyjs::show("accept_all_suggestions")
      } else {
        shinyjs::hide("accept_all_suggestions")
      }
    })

    # Handle per-row resolution dropdown
    observeEvent(input$resolve_row_choice, {
      req(data_store$resolution_state, data_store$dtxsid_cols)

      choice <- input$resolve_row_choice
      row_idx <- choice$row
      chosen_column <- choice$column
      group_rows <- get_group_rows(row_idx, isolate(data_store$dedup_group_map))

      tryCatch(
        {
          if (chosen_column == "__none__") {
            updated_df <- data_store$resolution_state
            updated_df <- init_resolution_state(updated_df)
            updated_df$.pinned[group_rows] <- TRUE
            data_store$resolution_state <- updated_df

            showNotification(
              sprintf("%d row(s) marked as skipped (None)", length(group_rows)),
              type = "message"
            )
          } else {
            updated_df <- data_store$resolution_state
            for (r in group_rows) {
              updated_df <- resolve_row(updated_df, r, chosen_column, data_store$dtxsid_cols)
            }
            data_store$resolution_state <- updated_df

            showNotification(
              sprintf(
                "%d row(s) resolved using %s",
                length(group_rows),
                sub("^dtxsid_", "", chosen_column)
              ),
              type = "message"
            )
          }

          data_store$consensus_summary <- recalc_consensus_summary(data_store$resolution_state)
        },
        error = function(e) {
          showNotification(paste0("Error resolving row: ", e$message), type = "error")
        }
      )
    })

    # Handle Compare button click - open modal with candidate comparison
    observeEvent(input$compare_row_click, {
      req(data_store$resolution_state, data_store$dtxsid_cols)

      row_idx <- input$compare_row_click$row
      row_status <- as.character(data_store$resolution_state$consensus_status[row_idx])

      # Get suggested column for highlight logic (D-08 override flow)
      suggested_col <- if (".suggested_column" %in% names(data_store$resolution_state)) {
        data_store$resolution_state$.suggested_column[row_idx]
      } else {
        NA_character_
      }

      # Get resolution options with enrichment metadata
      options <- get_resolution_options(
        data_store$resolution_state,
        row_idx,
        data_store$dtxsid_cols,
        enrichment_cache = data_store$enrichment_cache
      )

      if (length(options) == 0) {
        showNotification("No candidates available for this row", type = "warning")
        return()
      }

      # Store modal state
      data_store$modal_row_idx <- row_idx
      data_store$modal_selected_column <- NULL

      current_flag <- if ("row_flag" %in% names(data_store$resolution_state)) {
        data_store$resolution_state$row_flag[row_idx]
      } else {
        NA_character_
      }
      current_flag <- if (!is.na(current_flag)) current_flag else ""

      # Build tagged column summary for context
      tagged_summary <- if (!is.null(data_store$column_tags) && length(data_store$column_tags) > 0) {
        tag_values <- sapply(names(data_store$column_tags), function(col) {
          if (col %in% names(data_store$resolution_state)) {
            val <- data_store$resolution_state[[col]][row_idx]
            if (!is.na(val)) paste0(col, " = '", val, "'") else NULL
          } else {
            NULL
          }
        })
        tag_values <- tag_values[!sapply(tag_values, is.null)]
        if (length(tag_values) > 0) {
          div(class = "mb-3 text-muted small", paste(tag_values, collapse = ", "))
        } else {
          NULL
        }
      } else {
        NULL
      }

      # Precompute scoring context outside lapply (O(1) lookup per candidate; per D-06)
      modal_input_name <- NA_character_
      modal_synonym_map <- NULL
      if (!is.null(data_store$column_tags) && !is.null(data_store$enrichment_cache)) {
        name_cols_modal <- names(data_store$column_tags)[data_store$column_tags == "Name"]
        if (length(name_cols_modal) > 0 && name_cols_modal[1] %in% names(data_store$resolution_state)) {
          modal_input_name <- as.character(data_store$resolution_state[[name_cols_modal[1]]][row_idx])
        }
        if ("synonyms" %in% names(data_store$enrichment_cache)) {
          ec <- data_store$enrichment_cache
          modal_synonym_map <- stats::setNames(ec$synonyms, ec$dtxsid)
        }
      }

      # Build candidate cards
      cards <- lapply(names(options), function(col) {
        opt <- options[[col]]

        # Compute per-candidate similarity score using precomputed context (per D-06)
        candidate_sim_score <- NA_real_
        if (!is.na(modal_input_name) && !is.null(modal_synonym_map)) {
          synonyms_str <- modal_synonym_map[opt$dtxsid]
          synonyms_str <- if (length(synonyms_str) == 1 && !is.na(synonyms_str)) synonyms_str else NA_character_
          candidate_sim_score <- score_one_candidate(
            input_name = modal_input_name,
            preferred_name = opt$preferredName,
            synonyms_str = synonyms_str,
            rank = opt$rank
          )
        }

        # Determine highlight style for suggested/auto_resolved candidate (D-14 override flow)
        is_suggested_candidate <- !is.na(suggested_col) && col == suggested_col
        card_border_style <- if (is_suggested_candidate && row_status == "suggested") {
          "border: 2px solid #0D6EFD; border-radius: 8px; transition: border-color 0.2s; background-color: #f0f7ff;"
        } else if (is_suggested_candidate && row_status == "auto_resolved") {
          "border: 2px solid #FFC107; border-radius: 8px; transition: border-color 0.2s; background-color: #fffdf0;"
        } else {
          "border: 2px solid #dee2e6; border-radius: 8px; transition: border-color 0.2s;"
        }

        # Badge for suggested/auto_resolved candidate
        evidence_only_candidate <- isTRUE(opt$evidence_only)
        candidate_badge <- if (evidence_only_candidate) {
          tags$span(class = "badge bg-secondary ms-2", "Evidence only")
        } else if (is_suggested_candidate && row_status == "suggested") {
          tags$span(class = "badge bg-primary ms-2", "Suggested")
        } else if (is_suggested_candidate && row_status == "auto_resolved") {
          tags$span(class = "badge bg-warning text-dark ms-2", "Auto-Selected")
        } else {
          NULL
        }
        candidate_dtxsid_label <- if (evidence_only_candidate || is.na(opt$dtxsid)) {
          "WQX evidence only (no DTXSID)"
        } else {
          opt$dtxsid
        }

        div(
          class = "candidate-card card mb-2",
          style = card_border_style,
          div(
            class = "card-body",
            div(
              class = "d-flex justify-content-between align-items-start",
              div(
                div(
                  class = "d-flex align-items-center",
                  tags$h6(class = "mb-1 fw-bold d-inline", candidate_dtxsid_label),
                  candidate_badge
                ),
                if (!is.na(opt$preferredName)) tags$p(class = "mb-1 text-muted", opt$preferredName) else NULL
              ),
              div(
                class = "d-flex align-items-center gap-2",
                if (!is.na(candidate_sim_score)) {
                  tags$span(
                    class = "badge bg-info",
                    title = "Similarity score (Jaro-Winkler)",
                    sprintf("%.2f", candidate_sim_score)
                  )
                } else {
                  NULL
                },
                if (!evidence_only_candidate) {
                  tags$button(
                    class = "modal-select-btn btn btn-sm btn-outline-success",
                    `data-column` = col,
                    "Select"
                  )
                } else {
                  tags$span(class = "text-muted small", "Review only")
                }
              )
            ),
            tags$hr(class = "my-2"),
            div(
              class = "row small",
              div(class = "col-4", tags$strong("CASRN"), tags$br(), if (!is.na(opt$casrn)) opt$casrn else "N/A"),
              div(
                class = "col-4",
                tags$strong("Formula"),
                tags$br(),
                if (!is.na(opt$molecular_formula)) opt$molecular_formula else "N/A"
              ),
              div(
                class = "col-4",
                tags$strong("Mol. Weight"),
                tags$br(),
                if (!is.na(opt$molecular_weight)) round(opt$molecular_weight, 2) else "N/A"
              )
            ),
            div(
              class = "row small mt-2",
              div(class = "col-4", tags$strong("Source"), tags$br(), opt$source_column),
              div(class = "col-4", tags$strong("Match Type"), tags$br(), opt$source_tier),
              div(class = "col-4", tags$strong("Rank"), tags$br(), if (!is.na(opt$rank)) opt$rank else "N/A")
            )
          )
        )
      })

      # Build scrollable container
      cards_container <- div(style = "max-height: 60vh; overflow-y: auto;", cards)

      flag_controls <- div(
        class = "border rounded p-2 mb-3",
        radioButtons(
          session$ns("modal_row_flag"),
          "Row Flag",
          choices = c("Unset" = "", "BAD" = "BAD", "FOLLOW-UP" = "FOLLOW-UP", "VERIFIED" = "VERIFIED"),
          selected = current_flag,
          inline = TRUE
        )
      )

      # "Accept Suggestion" button only shown for suggested rows
      accept_suggestion_btn <- if (row_status == "suggested") {
        tags$button(
          class = "btn btn-primary",
          onclick = sprintf(
            "Shiny.setInputValue('%s', {t: Math.random()}, {priority: 'event'});",
            session$ns("accept_suggestion")
          ),
          "Accept Suggestion"
        )
      } else {
        NULL
      }

      # Build modal footer
      footer <- tagList(
        accept_suggestion_btn,
        div(
          id = session$ns("confirm_container"),
          style = "display:none;",
          actionButton(session$ns("modal_confirm"), "Confirm & Close", class = "btn-primary")
        ),
        tags$button(
          class = "btn btn-outline-secondary",
          onclick = sprintf(
            "Shiny.setInputValue('%s', {t: Math.random()}, {priority: 'event'});",
            session$ns("modal_skip")
          ),
          "Skip this row"
        ),
        modalButton("Cancel")
      )

      # Show modal
      showModal(modalDialog(
        title = "Compare Candidates",
        tagList(tagged_summary, flag_controls, cards_container),
        footer = footer,
        size = "l",
        easyClose = TRUE
      ))
    })

    observeEvent(input$modal_row_flag, {
      row_idx <- data_store$modal_row_idx
      if (is.null(row_idx)) {
        return()
      }

      tryCatch(
        {
          group_rows <- get_group_rows(row_idx, isolate(data_store$dedup_group_map))
          updated_df <- set_row_flags(data_store$resolution_state, group_rows, input$modal_row_flag)
          data_store$resolution_state <- updated_df

          flag <- normalize_row_flag(input$modal_row_flag)
          msg <- if (is.na(flag)) {
            sprintf("%d row(s) cleared", length(group_rows))
          } else {
            sprintf("%d row(s) flagged %s", length(group_rows), flag)
          }
          showNotification(msg, type = "message", duration = 2)
        },
        error = function(e) {
          showNotification(paste0("Error setting row flag: ", e$message), type = "error")
        }
      )
    }, ignoreInit = TRUE)

    # Handle modal candidate selection
    observeEvent(input$modal_candidate_select, {
      data_store$modal_selected_column <- input$modal_candidate_select$column
    })

    # Handle modal confirm
    observeEvent(input$modal_confirm, {
      row_idx <- data_store$modal_row_idx
      chosen_column <- data_store$modal_selected_column

      if (is.null(chosen_column)) {
        showNotification("Please select a candidate first", type = "warning")
        return()
      }

      options <- get_resolution_options(
        data_store$resolution_state,
        row_idx,
        data_store$dtxsid_cols,
        enrichment_cache = data_store$enrichment_cache
      )

      group_rows <- get_group_rows(row_idx, isolate(data_store$dedup_group_map))
      updated_df <- data_store$resolution_state
      for (r in group_rows) {
        updated_df <- resolve_row(updated_df, r, chosen_column, data_store$dtxsid_cols)
        # Safety reinforcement: resolve_row (Plan 01) sets .resolution_method="manual"
        updated_df$.resolution_method[r] <- "manual"
      }
      data_store$resolution_state <- updated_df
      data_store$consensus_summary <- recalc_consensus_summary(updated_df)

      opt <- options[[chosen_column]]
      notification_msg <- if (!is.na(opt$preferredName)) {
        sprintf("Resolved %d row(s): %s - %s", length(group_rows), opt$dtxsid, opt$preferredName)
      } else {
        sprintf("Resolved %d row(s): %s", length(group_rows), opt$dtxsid)
      }

      removeModal()
      showNotification(notification_msg, type = "message")

      data_store$modal_row_idx <- NULL
      data_store$modal_selected_column <- NULL
    })

    # Handle Accept Suggestion from modal (suggested rows only)
    observeEvent(input$accept_suggestion, {
      row_idx <- data_store$modal_row_idx
      if (is.null(row_idx)) {
        return()
      }

      suggested_col <- if (".suggested_column" %in% names(data_store$resolution_state)) {
        data_store$resolution_state$.suggested_column[row_idx]
      } else {
        NA_character_
      }

      if (is.na(suggested_col)) {
        showNotification("No suggestion available for this row", type = "warning")
        return()
      }

      tryCatch(
        {
          group_rows <- get_group_rows(row_idx, isolate(data_store$dedup_group_map))
          updated_df <- data_store$resolution_state
          for (r in group_rows) {
            updated_df <- resolve_row(updated_df, r, suggested_col, data_store$dtxsid_cols)
            updated_df$.resolution_method[r] <- "suggested-accept"
          }
          data_store$resolution_state <- updated_df
          data_store$consensus_summary <- recalc_consensus_summary(updated_df)

          opt_dtxsid <- updated_df$consensus_dtxsid[row_idx]
          pref_col <- sub("^dtxsid_", "preferredName_", suggested_col)
          opt_pref <- if (pref_col %in% names(updated_df)) updated_df[[pref_col]][row_idx] else NA_character_
          notification_msg <- if (!is.na(opt_pref)) {
            sprintf("Accepted suggestion for %d row(s): %s - %s", length(group_rows), opt_dtxsid, opt_pref)
          } else {
            sprintf("Accepted suggestion for %d row(s): %s", length(group_rows), opt_dtxsid)
          }

          removeModal()
          showNotification(notification_msg, type = "message")

          data_store$modal_row_idx <- NULL
          data_store$modal_selected_column <- NULL
        },
        error = function(e) {
          showNotification(paste0("Error accepting suggestion: ", e$message), type = "error")
        }
      )
    })

    # Handle modal skip
    observeEvent(input$modal_skip, {
      row_idx <- data_store$modal_row_idx
      if (is.null(row_idx)) {
        return()
      }

      group_rows <- get_group_rows(row_idx, isolate(data_store$dedup_group_map))
      updated_df <- data_store$resolution_state
      updated_df <- init_resolution_state(updated_df)
      updated_df$.pinned[group_rows] <- TRUE
      data_store$resolution_state <- updated_df
      data_store$consensus_summary <- recalc_consensus_summary(updated_df)

      removeModal()
      showNotification(
        sprintf("%d row(s) marked as skipped", length(group_rows)),
        type = "message"
      )

      data_store$modal_row_idx <- NULL
      data_store$modal_selected_column <- NULL
    })

    # Handle Validate All button for manual DTXSID entries
    observeEvent(input$validate_all, {
      queue <- data_store$manual_queue
      if (length(queue) == 0) {
        showNotification("No manual entries to validate", type = "warning", duration = 3)
        return()
      }

      row_indices <- as.integer(names(queue))
      all_dtxsids <- unname(unlist(queue))
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
            invalid_details <- c(invalid_details, sprintf("Row %d: %s", row_idx, entered_dtxsid))
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
      showNotification(msg, type = if (n_invalid > 0) "warning" else "message", duration = 8)

      # Detail notification for failures
      if (n_invalid > 0) {
        showNotification(
          paste("Failed entries:", paste(invalid_details, collapse = "; ")),
          type = "error",
          duration = NULL # Stays until dismissed
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

      tryCatch(
        {
          # Count disagree rows before
          pinned_before <- !is.na(data_store$resolution_state$.pinned) & data_store$resolution_state$.pinned
          before_count <- sum(
            data_store$resolution_state$consensus_status == "disagree" & !pinned_before,
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
          pinned_after <- !is.na(updated_df$.pinned) & updated_df$.pinned
          after_count <- sum(
            updated_df$consensus_status == "disagree" & !pinned_after,
            na.rm = TRUE
          )

          resolved_count <- before_count - after_count

          # Recalculate consensus summary
          data_store$consensus_summary <- recalc_consensus_summary(updated_df)

          showNotification(
            paste0("Applied priority chain: ", resolved_count, " rows resolved"),
            type = "message"
          )
        },
        error = function(e) {
          showNotification(
            paste0("Error applying priority: ", e$message),
            type = "error"
          )
        }
      )
    })

    # Handle Accept All Suggestions
    observeEvent(input$accept_all_suggestions, {
      req(data_store$resolution_state, data_store$dtxsid_cols)

      tryCatch(
        {
          pinned_vec <- !is.na(data_store$resolution_state$.pinned) & data_store$resolution_state$.pinned
          before_count <- sum(
            data_store$resolution_state$consensus_status == "suggested" & !pinned_vec,
            na.rm = TRUE
          )

          updated_df <- accept_all_suggestions(
            data_store$resolution_state,
            data_store$dtxsid_cols
          )

          data_store$resolution_state <- updated_df
          data_store$consensus_summary <- recalc_consensus_summary(updated_df)

          showNotification(
            sprintf("%d suggestion(s) accepted", before_count),
            type = "message"
          )
        },
        error = function(e) {
          showNotification(
            "Failed to accept suggestions. Please try again.",
            type = "error"
          )
        }
      )
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

        # Build all 8 export sheets
        sheets <- build_export_sheets(
          raw = data_store$raw,
          resolution_state = data_store$resolution_state,
          consensus_summary = data_store$consensus_summary,
          cleaning_audit = data_store$cleaning_audit,
          reference_lists = data_store$reference_lists,
          column_tags = data_store$column_tags,
          detection = data_store$detection,
          file_info = data_store$file_info,
          enrichment_cache = data_store$enrichment_cache,
          toxval_output = data_store$toxval_output
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
        session,
        "filter_errors",
        label = if (data_store$error_filter_active) "Show All" else "Show Errors"
      )
    })

    observeEvent(input$clear_table_filters, {
      data_store$error_filter_active <- FALSE
      data_store$selected_error_rows <- NULL
      data_store$selected_visible_rows <- NULL
      updateActionButton(session, "filter_errors", label = "Show Errors")
      shinyjs::hide("retag_selected")
    })

    # Track selected rows and show/hide retag button
    observe({
      selected <- reactable::getReactableState("curation_table", "selected")
      if (!is.null(selected) && length(selected) > 0 && isTRUE(data_store$error_filter_active)) {
        rep_rows <- data_store$display_row_map[selected]
        grp_map <- data_store$dedup_group_map
        all_rows <- unique(unlist(lapply(rep_rows, get_group_rows, dedup_group_map = grp_map)))
        data_store$selected_error_rows <- all_rows
        shinyjs::show("retag_selected")
      } else {
        data_store$selected_error_rows <- NULL
        shinyjs::hide("retag_selected")
      }
    })

    observe({
      selected <- reactable::getReactableState("curation_table", "selected")
      if (!is.null(selected) && length(selected) > 0) {
        rep_rows <- data_store$display_row_map[selected]
        grp_map <- data_store$dedup_group_map
        all_rows <- unique(unlist(lapply(rep_rows, get_group_rows, dedup_group_map = grp_map)))
        data_store$selected_visible_rows <- all_rows
      } else {
        data_store$selected_visible_rows <- NULL
      }
    })

    observeEvent(input$apply_batch_row_flag, {
      selected_rows <- data_store$selected_visible_rows
      if (is.null(selected_rows) || length(selected_rows) == 0) {
        showNotification("Select one or more visible rows first.", type = "warning")
        return()
      }

      if (is.null(input$batch_row_flag) || input$batch_row_flag == "") {
        showNotification("Choose a flag action first.", type = "warning")
        return()
      }

      tryCatch(
        {
          updated_df <- set_row_flags(data_store$resolution_state, selected_rows, input$batch_row_flag)
          data_store$resolution_state <- updated_df

          flag <- normalize_row_flag(input$batch_row_flag)
          msg <- if (is.na(flag)) {
            sprintf("%d row(s) cleared", length(selected_rows))
          } else {
            sprintf("%d row(s) flagged %s", length(selected_rows), flag)
          }
          showNotification(msg, type = "message")
          updateSelectInput(session, "batch_row_flag", selected = "")
        },
        error = function(e) {
          showNotification(paste0("Error applying row flag: ", e$message), type = "error")
        }
      )
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
              choices = list("(none)" = "", "Name" = "Name", "CASRN" = "CASRN", "Other" = "Other"),
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
        retry_result <- tryCatch(
          {
            run_curation_pipeline(
              clean_data = subset_data,
              column_tags = new_tags,
              progress_callback = function(stage, msg) {
                incProgress(0.2, detail = msg)
              }
            )
          },
          error = function(e) {
            showNotification(paste("Re-curation failed:", e$message), type = "error", duration = NULL)
            NULL
          }
        )

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
          n_resolved <- sum(
            updated_state$consensus_status[selected_rows] %in%
              c("agree", "agree_caveat", "single", "manual"),
            na.rm = TRUE
          )
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

    # Handle WQX Review button click - open modal with review options
    observeEvent(input$wqx_review_click, {
      req(data_store$resolution_state)

      row_idx <- input$wqx_review_click$row
      if (is.null(row_idx) || row_idx < 1 || row_idx > nrow(data_store$resolution_state)) {
        return()
      }

      row <- data_store$resolution_state[row_idx, ]
      data_store$wqx_modal_row_idx <- row_idx

      # Read display context
      name_cols <- names(data_store$column_tags)[data_store$column_tags == "Name"]
      input_name <- NA_character_
      for (nc in name_cols) {
        if (nc %in% names(row) && !is.na(row[[nc]])) {
          input_name <- row[[nc]]
          break
        }
      }
      # Get current preferred name from the same source chain as consensus_source
      current_name <- pick_source_aligned_values(row, "preferredName")[[1]]
      # Prefer override name if set
      if ("wqx_override_name" %in% names(row) && !is.na(row$wqx_override_name)) {
        current_name <- row$wqx_override_name
      }

      # Get match type from the same source chain as consensus_source
      match_tier_raw <- pick_source_aligned_values(row, "source_tier")[[1]]
      match_type_label <- switch(
        as.character(match_tier_raw),
        "wqx_exact" = "WQX Exact",
        "wqx_alias" = "WQX Alias",
        "wqx_fuzzy" = "WQX Fuzzy",
        "WQX"
      )

      # Confidence score (only for fuzzy), source-aligned like the displayed WQX name.
      confidence_raw <- pick_source_aligned_values(row, "wqx_confidence")[[1]]
      confidence <- suppressWarnings(as.numeric(confidence_raw))

      # Build context card (per D-07, UI-SPEC)
      context_card <- div(
        class = "card card-body bg-light mb-3",
        div(
          class = "row mb-2",
          div(class = "col-4", tags$strong("Input Name")),
          div(class = "col-8", if (!is.na(input_name)) input_name else "(unknown)")
        ),
        div(
          class = "row mb-2",
          div(class = "col-4", tags$strong("Current WQX Match")),
          div(class = "col-8", if (!is.na(current_name)) current_name else "(none)")
        ),
        div(
          class = "row mb-2",
          div(class = "col-4", tags$strong("Match Type")),
          div(class = "col-8", match_type_label)
        ),
        if (!is.na(confidence)) {
          div(
            class = "row mb-2",
            div(class = "col-4", tags$strong("Confidence Score")),
            div(class = "col-8", formatC(confidence, digits = 2, format = "f"))
          )
        }
      )

      # Type-ahead section (per D-06, UI-SPEC)
      typeahead_section <- div(
        tags$h6(class = "mt-3 mb-2", "Find a Different WQX Name"),
        selectizeInput(
          session$ns("wqx_typeahead"),
          label = NULL,
          choices = NULL,
          options = list(
            placeholder = "Type to search WQX names...",
            maxOptions = 20
          )
        )
      )

      # Modal footer: Accept Current, Use Selected Name (hidden), Reject Match
      footer <- tagList(
        tags$button(
          class = "btn btn-outline-secondary",
          `data-dismiss` = "modal",
          `data-bs-dismiss` = "modal",
          "Accept Current"
        ),
        div(
          id = session$ns("wqx_confirm_container"),
          style = "display:inline-block;",
          actionButton(
            session$ns("wqx_modal_confirm"),
            "Use Selected Name",
            class = "btn-primary",
            style = "display:none;"
          )
        ),
        tags$button(
          class = "btn btn-outline-danger",
          onclick = sprintf(
            "Shiny.setInputValue('%s', {t: Math.random()}, {priority: 'event'});",
            session$ns("wqx_reject_click")
          ),
          "Reject Match"
        )
      )

      showModal(modalDialog(
        title = "Review WQX Match",
        tagList(context_card, typeahead_section),
        footer = footer,
        size = "l",
        easyClose = TRUE
      ))

      # onFlushed defers updateSelectizeInput to a second flush cycle. Without it,
      # both showModal and updateSelectizeInput land in the same flush — and Shiny's
      # client processes inputMessages before modal, so the update targets a DOM
      # element that doesn't exist yet and is silently dropped.
      cache_dir <- resolve_reference_cache_dir()
      wqx_dict <- load_wqx_dictionary(cache_dir)
      display_type <- ifelse(wqx_dict$type == "canonical", "canonical", "alias")
      wqx_labels <- paste0(wqx_dict$name, " (", display_type, ")")
      wqx_choices <- stats::setNames(wqx_dict$canonical_name, wqx_labels)
      session$onFlushed(
        function() {
          updateSelectizeInput(session, "wqx_typeahead", choices = wqx_choices, server = TRUE)
        },
        once = TRUE
      )
    })

    # Show "Use Selected Name" button when type-ahead selection is made
    observeEvent(
      input$wqx_typeahead,
      {
        if (!is.null(input$wqx_typeahead) && input$wqx_typeahead != "") {
          shinyjs::show("wqx_modal_confirm")
        } else {
          shinyjs::hide("wqx_modal_confirm")
        }
      },
      ignoreInit = TRUE,
      ignoreNULL = FALSE
    )

    # Handle WQX modal confirm — override with type-ahead selection
    observeEvent(input$wqx_modal_confirm, {
      row_idx <- data_store$wqx_modal_row_idx
      new_name <- input$wqx_typeahead

      if (is.null(new_name) || new_name == "") {
        showNotification("Please select a WQX name first", type = "warning")
        return()
      }

      # Group-propagated mutation (per D-08: consensus_status stays "wqx", preferredName updated)
      group_rows <- get_group_rows(row_idx, isolate(data_store$dedup_group_map))
      updated_df <- data_store$resolution_state

      # Initialize wqx_override_name column if it doesn't exist
      if (!"wqx_override_name" %in% names(updated_df)) {
        updated_df$wqx_override_name <- NA_character_
      }

      for (r in group_rows) {
        updated_df$wqx_override_name[r] <- new_name
        # consensus_status stays "wqx" per D-08 — no change
      }
      data_store$resolution_state <- updated_df
      data_store$consensus_summary <- recalc_consensus_summary(updated_df)

      removeModal()
      showNotification(
        sprintf("WQX match overridden for %d row(s): %s", length(group_rows), new_name),
        type = "message"
      )
      data_store$wqx_modal_row_idx <- NULL
    })

    # Handle WQX reject — mark row unresolvable
    observeEvent(input$wqx_reject_click, {
      row_idx <- data_store$wqx_modal_row_idx
      if (is.null(row_idx)) {
        return()
      }

      # Group-propagated mutation (per D-08: consensus_status -> "unresolvable", needs_review -> TRUE)
      group_rows <- get_group_rows(row_idx, isolate(data_store$dedup_group_map))
      updated_df <- data_store$resolution_state

      if (!"needs_review" %in% names(updated_df)) {
        updated_df$needs_review <- FALSE
      }
      for (r in group_rows) {
        updated_df$consensus_status[r] <- "unresolvable"
        updated_df$needs_review[r] <- TRUE
      }
      data_store$resolution_state <- updated_df
      data_store$consensus_summary <- recalc_consensus_summary(updated_df)

      removeModal()
      showNotification(
        sprintf("WQX match rejected for %d row(s) \u2014 marked unresolvable", length(group_rows)),
        type = "message"
      )
      data_store$wqx_modal_row_idx <- NULL
    })

    # Curation completed indicator
    output$curation_completed <- reactive({
      !is.null(data_store$curation_status) && data_store$curation_status == "completed"
    })
    outputOptions(output, "curation_completed", suspendWhenHidden = FALSE)
  })
}
