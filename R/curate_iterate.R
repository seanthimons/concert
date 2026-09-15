# Agent-driven curation loop: one decisions.R file in, status.md + pending.csv
# + replay.R out. Re-run until pending.csv is empty.

decision_object_names <- function() {
  c(
    "input_path",
    "output_path",
    "header_row",
    "tag_map",
    "reference_list_snapshot",
    "activate_all_references",
    "value_corrections",
    "cleaning_steps",
    "multi_analyte_resolutions",
    "wqx_threshold",
    "starts_with",
    "accept_suggestions",
    "review_picks",
    "row_flags",
    "site_alias_map",
    "site_manifest",
    "harmonize",
    "format",
    "media",
    "source_name",
    "unit_map_snapshot",
    "media_map_snapshot",
    "corrections"
  )
}

read_decisions <- function(decisions_path) {
  env <- new.env(parent = globalenv())
  sys.source(decisions_path, envir = env)
  get_or <- function(name, default = NULL) {
    if (exists(name, envir = env, inherits = FALSE)) get(name, envir = env) else default
  }

  d <- lapply(decision_object_names(), get_or)
  names(d) <- decision_object_names()

  if (is.null(d$input_path)) {
    stop("decisions.R must define input_path.", call. = FALSE)
  }
  if (is.null(d$tag_map) || length(d$tag_map) == 0) {
    stop("decisions.R must define a non-empty tag_map.", call. = FALSE)
  }
  d$tag_map <- as.list(d$tag_map)
  d$tag_map <- d$tag_map[!vapply(d$tag_map, function(x) is.null(x) || !nzchar(x), logical(1))]

  d$activate_all_references <- isTRUE(d$activate_all_references)
  d$wqx_threshold <- d$wqx_threshold %||% 0.85
  d$starts_with <- isTRUE(d$starts_with)
  d$accept_suggestions <- isTRUE(d$accept_suggestions)
  d$harmonize <- isTRUE(d$harmonize)
  d$format <- d$format %||% "parquet"
  d
}

#' Write a starter decisions.R for the agent curation loop
#'
#' Reads the file, runs frontmatter detection and column tag suggestion, and
#' writes a decisions file the agent edits between `curate_iterate()` runs.
#' Every optional decision object is present as a commented schema example.
#'
#' @param input_path Path to the CSV/XLSX to curate.
#' @param out_dir Directory for `decisions.R` and all loop outputs.
#' @param harmonize Logical. Pre-set the `harmonize` switch in the template.
#' @return Invisibly, the path to the written decisions file.
#' @export
curate_decisions_template <- function(input_path, out_dir, harmonize = FALSE) {
  if (!file.exists(input_path)) {
    stop(sprintf("file not found: %s", input_path), call. = FALSE)
  }
  fs::dir_create(out_dir, recurse = TRUE)

  raw_df <- safely_read_file(input_path, tolower(tools::file_ext(input_path)))
  detection <- detect_data_start(raw_df, mode = "auto")
  clean_data <- extract_clean_data(raw_df, detection)
  clean_data <- janitor::clean_names(handle_merged_cells(clean_data))
  clean_data <- janitor::remove_empty(clean_data, which = c("rows", "cols"))
  suggestions <- suggest_column_tags(names(clean_data))

  tagged <- names(suggestions)[nzchar(unlist(suggestions))]
  untagged <- setdiff(names(suggestions), tagged)
  tag_lines <- vapply(
    tagged,
    function(col) paste0("  ", r_name(col), " = ", script_literal(suggestions[[col]])),
    character(1)
  )
  if (length(tag_lines) > 1) {
    tag_lines[-length(tag_lines)] <- paste0(tag_lines[-length(tag_lines)], ",")
  }
  untagged_lines <- vapply(untagged, function(col) paste0("  # ", r_name(col), " = \"\""), character(1))

  snapshot <- build_reference_list_snapshot(load_all_reference_lists(resolve_reference_cache_dir()))

  lines <- c(
    "# CONCERT agent curation decisions. Edit, then run curate_iterate() again.",
    "# Tag values: Name, CASRN, Other, Result, Numeric, Unit, Qualifier, ReportingLimit,",
    "#   Uncertainty, UncertaintyCoverage, Duration, DurationUnit, Species, ExposureRoute, StudyDate, Media",
    "library(concert)",
    "",
    paste0("input_path <- ", script_literal(normalizePath(input_path, winslash = "/"))),
    paste0(
      "output_path <- ",
      script_literal(file.path(
        normalizePath(out_dir, winslash = "/"),
        paste0(tools::file_path_sans_ext(basename(input_path)), "_curated.xlsx")
      ))
    ),
    "",
    sprintf("# Detected by %s, confidence %.2f. Set to NULL to re-detect.", detection$method, detection$confidence),
    paste0("header_row <- ", script_literal(as.integer(detection$header_row))),
    "",
    "# Suggested tags. Untagged columns are listed as comments; fill in or leave out.",
    "tag_map <- list(",
    tag_lines,
    untagged_lines,
    ")",
    "",
    "# --- Cleaning -------------------------------------------------------------",
    "# Switch cleaning steps off when they misfire on this dataset.",
    "# cleaning_steps <- list(chiral = FALSE, truncated = FALSE)",
    "",
    "# Dataset-specific rewrites applied before cleaning. match_mode: regex (default), literal_exact, literal_word.",
    "# value_corrections <- tibble::tibble(",
    "#   column = c(\"chemical_name\"),",
    "#   pattern = c(\"^Total \"),",
    "#   replacement = c(\"\"),",
    "#   match_mode = c(\"regex\")",
    "# )",
    "",
    "# Multi-analyte rows from pending.csv (pending_type == \"multi_analyte\"). action: split, keep, rename.",
    "# multi_analyte_resolutions <- tibble::tibble(",
    "#   row_index = c(12L, 40L),",
    "#   action = c(\"split\", \"rename\"),",
    "#   value = c(NA, \"Chromium (VI)\")",
    "# )",
    "",
    "# Reference lists: add rows to overrides (source = \"agent\", active = TRUE). match_mode for strip_terms only.",
    paste0("reference_list_snapshot <- ", reference_snapshot_script_literal(snapshot)),
    "activate_all_references <- FALSE",
    "",
    "# --- Curation -------------------------------------------------------------",
    "wqx_threshold <- 0.85",
    "starts_with <- FALSE",
    "",
    "# --- Review ---------------------------------------------------------------",
    "# Accept every row CONCERT scored as \"suggested\".",
    "accept_suggestions <- TRUE",
    "",
    "# Pick a DTXSID for a row by its cleaned name (+ CAS when present). DTXSIDs are validated against CompTox.",
    "# review_picks <- tibble::tibble(",
    "#   name = c(\"Chromium\"),",
    "#   casrn = c(NA),",
    "#   dtxsid = c(\"DTXSID1020322\")",
    "# )",
    "",
    "# Rows you cannot resolve. flag: FOLLOW-UP, BAD, or VERIFIED. Flagged rows leave pending.csv.",
    "# row_flags <- tibble::tibble(",
    "#   name = c(\"Unknown organic\"),",
    "#   casrn = c(NA),",
    "#   flag = c(\"FOLLOW-UP\"),",
    "#   reason = c(\"No CompTox candidate; needs chemist\")",
    "# )",
    "",
    "# --- Harmonization --------------------------------------------------------",
    paste0("harmonize <- ", if (isTRUE(harmonize)) "TRUE" else "FALSE"),
    "# format <- \"parquet\"           # parquet, csv, both",
    "# media <- \"aqueous\"            # aqueous, air, solid",
    "# source_name <- \"My Source\"",
    "# corrections <- tibble::tibble(pattern = c(\"^6\\\\.90E\\\\+0\\\\.1$\"), replacement = c(\"6.90E+01\"))",
    "# unit_map_snapshot / media_map_snapshot: copy from a Shiny replay script when needed.",
    ""
  )

  path <- file.path(out_dir, "decisions.R")
  writeLines(lines, path)
  invisible(path)
}

pending_rows <- function(state) {
  rs <- state$resolution_state
  n <- nrow(rs)
  if (n == 0) {
    return(empty_pending())
  }
  rs <- init_resolution_state(rs)
  dtxsid_cols <- find_dtxsid_cols(rs)
  name_col <- first_tag_col(state$merged_chemical_tags, "Name")
  cas_col <- first_tag_col(state$merged_chemical_tags, "CASRN")

  pinned <- !is.na(rs$.pinned) & rs$.pinned
  flagged <- !is.na(rs$row_flag)
  status <- rs$consensus_status %||% rep(NA_character_, n)

  is_multi <- is_multi_analyte_review_row(rs)
  needs_pick <- !is_multi & !pinned & !flagged & status %in% c("disagree", "suggested")
  no_match <- !is_multi & !pinned & !flagged & status %in% c("error", "unresolvable")
  idx <- which(is_multi | needs_pick | no_match)
  if (length(idx) == 0) {
    return(empty_pending())
  }

  pending_type <- ifelse(is_multi[idx], "multi_analyte", ifelse(no_match[idx], "no_match", status[idx]))
  name_vals <- if (!is.na(name_col)) as.character(rs[[name_col]][idx]) else NA_character_
  cas_vals <- if (!is.na(cas_col)) as.character(rs[[cas_col]][idx]) else NA_character_
  suggested_col <- if (".suggested_column" %in% names(rs)) {
    rs$.suggested_column[idx]
  } else {
    rep(NA_character_, length(idx))
  }

  candidates <- vapply(
    idx,
    function(i) {
      opts <- get_resolution_options(rs, i, dtxsid_cols, state$enrichment_cache)
      if (length(opts) == 0) {
        return(NA_character_)
      }
      paste(
        vapply(
          opts,
          function(o) {
            paste(o$dtxsid %||% NA, o$preferredName %||% NA, o$source_tier %||% NA, sep = " | ")
          },
          character(1)
        ),
        collapse = " ; "
      )
    },
    character(1)
  )

  suggested_dtxsid <- vapply(
    seq_along(idx),
    function(k) {
      col <- suggested_col[k]
      if (is.na(col) || !col %in% names(rs)) NA_character_ else as.character(rs[[col]][idx[k]])
    },
    character(1)
  )

  split_suggestion <- vapply(
    seq_along(idx),
    function(k) {
      if (!is_multi[idx[k]] || is.na(name_vals[k])) {
        return(NA_character_)
      }
      paste(suggest_multi_analyte_parts(name_vals[k]), collapse = " | ")
    },
    character(1)
  )

  tibble::tibble(
    row_index = if ("original_row_id" %in% names(rs)) as.integer(rs$original_row_id[idx]) else idx,
    pending_type = pending_type,
    name = name_vals,
    casrn = cas_vals,
    consensus_status = status[idx],
    suggested_dtxsid = suggested_dtxsid,
    suggested_split = split_suggestion,
    candidates = candidates,
    cleaning_flag = if ("cleaning_flag" %in% names(rs)) as.character(rs$cleaning_flag[idx]) else NA_character_
  )
}

empty_pending <- function() {
  tibble::tibble(
    row_index = integer(),
    pending_type = character(),
    name = character(),
    casrn = character(),
    consensus_status = character(),
    suggested_dtxsid = character(),
    suggested_split = character(),
    candidates = character(),
    cleaning_flag = character()
  )
}

first_tag_col <- function(tags, tag) {
  cols <- names(tags)[unlist(tags) == tag]
  if (length(cols) == 0) NA_character_ else cols[1]
}

write_status_md <- function(path, state, pending, done, decisions, error = NULL) {
  summary <- state$consensus_summary %||% list()
  summary_lines <- if (length(summary)) {
    paste0("| ", sub("^n_", "", names(summary)), " | ", unlist(summary), " |")
  } else {
    character(0)
  }
  pending_counts <- if (nrow(pending)) table(pending$pending_type) else integer(0)
  pending_lines <- if (length(pending_counts)) {
    paste0("| ", names(pending_counts), " | ", as.integer(pending_counts), " |")
  } else {
    "| (none) | 0 |"
  }
  unmatched <- state$unmatched_decisions %||% character(0)

  lines <- c(
    "# CONCERT curation status",
    "",
    paste0("- input: ", decisions$input_path),
    paste0("- run at: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
    paste0("- rows: ", NROW(state$resolution_state)),
    paste0("- done: ", if (done) "TRUE" else "FALSE"),
    "",
    if (!is.null(error)) c("## Error", "", "```", conditionMessage(error), "```", "") else character(0),
    "## Consensus",
    "",
    "| status | n |",
    "|---|---|",
    summary_lines,
    "",
    "## Pending",
    "",
    "| type | n |",
    "|---|---|",
    pending_lines,
    "",
    if (length(unmatched)) c("## Unmatched decisions", "", paste0("- ", unmatched), "") else character(0),
    "## Next",
    "",
    if (done) {
      c("All rows resolved or flagged. Outputs written next to decisions.R; replay.R reproduces this run.")
    } else {
      c(
        "Open pending.csv. For each row: add a review_picks entry (dtxsid), a row_flags entry, or a",
        "multi_analyte_resolutions entry, or fix the root cause with value_corrections / reference_list_snapshot.",
        "Then run curate_iterate() again."
      )
    },
    ""
  )
  writeLines(lines, path)
}

#' Run one iteration of the agent curation loop
#'
#' Sources `decisions.R`, runs the staged headless pipeline with a curation
#' cache, and writes `status.md`, `pending.csv`, and `replay.R` next to it.
#' When no rows are pending it also writes the curated workbook (and ToxVal
#' files when `harmonize` is set). Re-run after editing `decisions.R` until
#' `status.md` reports `done: TRUE`.
#'
#' @param decisions_path Path to a decisions file. Create one with
#'   [curate_decisions_template()].
#' @param out_dir Output directory. Defaults to the decisions file directory.
#' @param verbose Logical. Print pipeline messages.
#' @return Invisibly, a list with `done`, `pending`, and `state`.
#' @export
curate_iterate <- function(decisions_path, out_dir = dirname(decisions_path), verbose = TRUE) {
  if (!file.exists(decisions_path)) {
    stop(sprintf("decisions file not found: %s. Run curate_decisions_template() first.", decisions_path), call. = FALSE)
  }
  fs::dir_create(out_dir, recurse = TRUE)
  d <- read_decisions(decisions_path)
  cache_dir <- file.path(out_dir, "cache")
  status_path <- file.path(out_dir, "status.md")

  run <- function() {
    state <- stage_ingest(
      input_path = d$input_path,
      tag_map = d$tag_map,
      header_row = d$header_row,
      reference_list_snapshot = d$reference_list_snapshot,
      activate_all_references = d$activate_all_references,
      site_manifest = d$site_manifest,
      site_alias_map = d$site_alias_map
    )
    state <- stage_clean(
      state,
      multi_analyte_resolutions = d$multi_analyte_resolutions,
      value_corrections = d$value_corrections,
      cleaning_steps = d$cleaning_steps
    )
    state <- stage_curate(
      state,
      wqx_threshold = d$wqx_threshold,
      starts_with = d$starts_with,
      postprocess_candidates = TRUE,
      cache_dir = cache_dir
    )
    state <- stage_review(
      state,
      accept_suggestions = d$accept_suggestions,
      review_picks = d$review_picks,
      row_flags = d$row_flags
    )
    stage_harmonize(
      state,
      harmonize = d$harmonize,
      unit_map_snapshot = d$unit_map_snapshot,
      corrections = d$corrections,
      media_map_snapshot = d$media_map_snapshot,
      media = d$media,
      source_name = d$source_name
    )
  }

  state <- tryCatch(
    if (verbose) run() else withCallingHandlers(run(), message = function(m) invokeRestart("muffleMessage")),
    error = function(e) {
      write_status_md(status_path, list(), empty_pending(), FALSE, d, error = e)
      stop(e)
    }
  )

  pending <- pending_rows(state)
  done <- nrow(pending) == 0
  readr::write_csv(pending, file.path(out_dir, "pending.csv"), na = "")

  replay <- generate_concert_script(
    input_path = d$input_path,
    output_path = d$output_path %||% file.path(out_dir, "curated.xlsx"),
    tag_map = d$tag_map,
    header_row = d$header_row %||% state$detection$header_row,
    wqx_threshold = d$wqx_threshold,
    starts_with = d$starts_with,
    harmonize = d$harmonize,
    media = d$media,
    unit_map = if (d$harmonize) state$harmonization_refs$unit_map else NULL,
    corrections = d$corrections,
    media_map = if (d$harmonize) state$harmonization_refs$media_map else NULL,
    format = d$format,
    source_name = d$source_name,
    reference_lists = state$reference_lists,
    activate_all_references = d$activate_all_references,
    site_manifest = d$site_manifest,
    site_alias_map = d$site_alias_map,
    value_corrections = d$value_corrections,
    cleaning_steps = d$cleaning_steps,
    multi_analyte_resolutions = d$multi_analyte_resolutions,
    accept_suggestions = d$accept_suggestions,
    review_picks = d$review_picks,
    row_flags = d$row_flags
  )
  writeLines(replay, file.path(out_dir, "replay.R"))

  write_status_md(status_path, state, pending, done, d)

  if (done) {
    output_path <- d$output_path %||% file.path(out_dir, "curated.xlsx")
    if (verbose) {
      stage_export(state, output_path = output_path, format = d$format, write_files = TRUE)
    } else {
      suppressMessages(stage_export(state, output_path = output_path, format = d$format, write_files = TRUE))
    }
  }

  message(sprintf(
    "[iterate] %s: %d pending (%s)",
    if (done) "DONE" else "NOT DONE",
    nrow(pending),
    if (nrow(pending)) {
      paste(names(table(pending$pending_type)), as.integer(table(pending$pending_type)), collapse = ", ")
    } else {
      "none"
    }
  ))
  invisible(list(done = done, pending = pending, state = state))
}
