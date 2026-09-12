# Stage functions that compose into curate_headless(). Each stage takes the
# state list returned by the previous stage and returns it with more fields.
# State fields (added in order):
#   ingest:    input_path, file_ext, raw_df, detection, clean_data, tag_map,
#              reference_lists, site_manifest, site_alias_map, file_info
#   clean:     cleaning_result, merged_tags, merged_chemical_tags
#   curate:    resolution_state, consensus_summary, enrichment_cache,
#              enrichment_failed, script_baseline_state
#   review:    resolution_state (edited), consensus_summary
#   harmonize: harmonize (logical), harmonization_refs,
#              harmonization_runtime_result, toxval_output, harmonize_audit,
#              detection_results

#' Stage 1: read a file, detect frontmatter, and validate the tag map
#'
#' @inheritParams curate_headless
#' @return A curation state list. See [curate_headless()] for the composed run.
#' @export
stage_ingest <- function(
  input_path,
  tag_map,
  header_row = NULL,
  reference_lists = NULL,
  reference_list_snapshot = NULL,
  activate_all_references = FALSE,
  site_manifest = NULL,
  site_alias_map = NULL
) {
  if (!file.exists(input_path)) {
    stop(sprintf("curate_headless: file not found: %s", input_path))
  }

  file_ext <- tolower(tools::file_ext(input_path))
  if (!file_ext %in% c("csv", "xlsx", "xls")) {
    stop(sprintf(
      "curate_headless: unsupported file type '%s'. Use csv, xlsx, or xls.",
      file_ext
    ))
  }

  if (!is.null(reference_lists) && !is.null(reference_list_snapshot)) {
    stop(
      "curate_headless: provide either reference_lists or reference_list_snapshot, not both.",
      call. = FALSE
    )
  }

  if (!is.null(reference_list_snapshot)) {
    cache_dir <- resolve_reference_cache_dir()
    reference_lists <- reconstruct_reference_list_snapshot(
      reference_list_snapshot,
      cache_dir = cache_dir
    )
  } else if (is.null(reference_lists)) {
    cache_dir <- resolve_reference_cache_dir()
    reference_lists <- load_all_reference_lists(cache_dir)
  } else {
    expected <- c("stop_words", "functional_categories", "block_patterns", "strip_terms", "isotope_lookup")
    missing_keys <- setdiff(expected, names(reference_lists))
    if (length(missing_keys) > 0) {
      stop(sprintf(
        "curate_headless: reference_lists is missing required keys: %s",
        paste(missing_keys, collapse = ", ")
      ))
    }
  }
  if (isTRUE(activate_all_references)) {
    reference_lists <- activate_all_reference_terms(reference_lists)
  }

  message(sprintf("[headless] Reading file: %s", basename(input_path)))
  raw_df <- safely_read_file(input_path, file_ext)

  if (!is.null(header_row)) {
    detection <- detect_data_start(raw_df, mode = "manual", manual_row = header_row)
  } else {
    detection <- detect_data_start(raw_df, mode = "auto")
  }

  message(sprintf(
    "[headless] Detection: method=%s, confidence=%.2f, header_row=%d",
    detection$method,
    detection$confidence,
    detection$header_row
  ))

  clean_data <- extract_clean_data(raw_df, detection)
  clean_data <- handle_merged_cells(clean_data)
  clean_data <- janitor::clean_names(clean_data)
  clean_data <- janitor::remove_empty(clean_data, which = c("rows", "cols"))
  assert_no_source_result_flag(clean_data, "curate_headless input")

  site_alias_map_for_export <- build_site_alias_map(site_context_alias_source(site_alias_map, site_manifest))
  site_manifest_input <- if (nrow(site_alias_map_for_export) > 0L) site_alias_map_for_export else site_manifest
  site_manifest_for_export <- build_site_manifest(site_manifest_input)

  missing_cols <- setdiff(names(tag_map), names(clean_data))
  if (length(missing_cols) > 0) {
    stop(sprintf(
      "curate_headless: tag_map column names not found after normalization: %s\nActual columns: %s",
      paste(missing_cols, collapse = ", "),
      paste(names(clean_data), collapse = ", ")
    ))
  }

  list(
    input_path = input_path,
    file_ext = file_ext,
    raw_df = raw_df,
    detection = detection,
    clean_data = clean_data,
    tag_map = tag_map,
    reference_lists = reference_lists,
    site_manifest = site_manifest_for_export,
    site_alias_map = site_alias_map_for_export,
    file_info = list(name = basename(input_path), size = file.info(input_path)$size)
  )
}

#' Stage 2: run the cleaning pipeline
#'
#' @param state State list from [stage_ingest()].
#' @inheritParams curate_headless
#' @return The state with `cleaning_result`, `merged_tags`, and
#'   `merged_chemical_tags` added.
#' @export
stage_clean <- function(state, multi_analyte_resolutions = NULL, value_corrections = NULL, cleaning_steps = NULL) {
  tag_groups <- classify_tags(state$tag_map)
  chemical_tag_map <- tag_groups$chemical_tags

  input_data <- state$clean_data
  correction_audit <- empty_cleaning_audit()
  if (!is.null(value_corrections) && nrow(value_corrections) > 0) {
    message(sprintf("[headless] Applying %d value corrections...", nrow(value_corrections)))
    correction_result <- apply_value_corrections(input_data, value_corrections)
    input_data <- correction_result$cleaned_data
    correction_audit <- correction_result$audit_trail
  }

  message("[headless] Running cleaning pipeline...")
  cleaning_result <- run_cleaning_pipeline(
    input_data,
    chemical_tag_map,
    state$reference_lists,
    mask = cleaning_steps
  )
  cleaning_result$audit_trail <- dplyr::bind_rows(correction_audit, cleaning_result$audit_trail)
  merged_chemical_tags <- combine_tag_maps(chemical_tag_map, cleaning_result$new_tags)
  merged_tags <- combine_tag_maps(state$tag_map, cleaning_result$new_tags)

  if (!is.null(multi_analyte_resolutions) && length(multi_analyte_resolutions) > 0) {
    message("[headless] Applying multi-analyte resolutions...")
    name_cols <- names(merged_chemical_tags)[merged_chemical_tags == "Name"]
    multi_result <- apply_multi_analyte_resolutions(
      cleaning_result$cleaned_data,
      name_cols,
      multi_analyte_resolutions
    )
    cleaning_result$cleaned_data <- multi_result$cleaned_data
    cleaning_result$audit_trail <- dplyr::bind_rows(
      cleaning_result$audit_trail,
      multi_result$audit_trail
    )
  }

  state$cleaning_result <- cleaning_result
  state$merged_chemical_tags <- merged_chemical_tags
  state$merged_tags <- merged_tags
  state
}

#' Stage 3: run the CompTox curation search and optional candidate postprocessing
#'
#' @param state State list from [stage_clean()].
#' @inheritParams curate_headless
#' @param cache_dir Optional directory. When set, the CompTox search result is
#'   cached by a hash of the cleaned chemical columns and search settings, and
#'   the candidate enrichment cache persists across runs. Used by
#'   [curate_iterate()] so re-runs after review edits skip the API.
#' @return The state with `resolution_state`, `consensus_summary`,
#'   `enrichment_cache`, `enrichment_failed`, and `script_baseline_state` added.
#' @export
stage_curate <- function(
  state,
  wqx_threshold = 0.85,
  starts_with = FALSE,
  postprocess_candidates = FALSE,
  cache_dir = NULL
) {
  cleaned <- state$cleaning_result$cleaned_data
  search_cache_path <- NULL
  enrichment_cache_path <- NULL
  pipeline_result <- NULL
  if (!is.null(cache_dir)) {
    fs::dir_create(cache_dir, recurse = TRUE)
    key_cols <- intersect(
      c(names(state$merged_chemical_tags), "cleaning_flag", "isotope_dtxsid"),
      names(cleaned)
    )
    key <- digest::digest(list(cleaned[key_cols], wqx_threshold, starts_with))
    search_cache_path <- file.path(cache_dir, paste0("curation_", key, ".rds"))
    enrichment_cache_path <- file.path(cache_dir, "enrichment.rds")
    if (file.exists(search_cache_path)) {
      message("[headless] Curation search loaded from cache")
      pipeline_result <- readRDS(search_cache_path)
    }
  }

  if (is.null(pipeline_result)) {
    message("[headless] Running curation pipeline (CompTox API search)...")
    pipeline_result <- run_curation_pipeline(
      cleaned,
      state$merged_chemical_tags,
      wqx_threshold = wqx_threshold,
      starts_with = starts_with
    )
    if (!is.null(search_cache_path)) {
      saveRDS(pipeline_result, search_cache_path)
    }
  }
  resolution_state <- pipeline_result$results
  consensus_summary <- pipeline_result$consensus_summary
  enrichment_cache <- NULL
  enrichment_failed <- character(0)
  if (!is.null(enrichment_cache_path) && file.exists(enrichment_cache_path)) {
    enrichment_cache <- readRDS(enrichment_cache_path)
  }

  if (isTRUE(postprocess_candidates)) {
    message("[headless] Running post-curation candidate enrichment...")
    postprocess_result <- postprocess_curation_candidates(
      resolution_state = resolution_state,
      column_tags = state$merged_chemical_tags,
      dtxsid_cols = find_dtxsid_cols(resolution_state),
      enrichment_cache = enrichment_cache
    )
    resolution_state <- postprocess_result$resolution_state
    consensus_summary <- postprocess_result$consensus_summary
    enrichment_cache <- postprocess_result$enrichment_cache
    enrichment_failed <- postprocess_result$enrichment_failed
    if (!is.null(enrichment_cache_path) && !is.null(enrichment_cache)) {
      saveRDS(enrichment_cache, enrichment_cache_path)
    }
    message(sprintf(
      "[headless] Candidate postprocessing: %d auto-resolved, %d suggested",
      postprocess_result$n_auto,
      postprocess_result$n_suggested
    ))
  }

  state$resolution_state <- resolution_state
  state$consensus_summary <- consensus_summary
  state$enrichment_cache <- enrichment_cache
  state$enrichment_failed <- enrichment_failed
  state$script_baseline_state <- resolution_state
  state
}

#' Stage 4: apply Review Results edits
#'
#' @param state State list from [stage_curate()].
#' @inheritParams curate_headless
#' @return The state with `resolution_state` and `consensus_summary` updated,
#'   plus `unmatched_decisions`: a character vector naming any `review_picks`
#'   or `row_flags` entries that matched no row.
#' @export
stage_review <- function(
  state,
  review_overrides = NULL,
  accept_suggestions = FALSE,
  review_picks = NULL,
  row_flags = NULL
) {
  rs <- state$resolution_state
  unmatched <- character(0)
  changed <- FALSE

  if (review_overrides_present(review_overrides)) {
    message("[headless] Applying review overrides...")
    rs <- apply_review_overrides(rs, review_overrides)
    changed <- TRUE
  }

  if (isTRUE(accept_suggestions)) {
    rs <- accept_all_suggestions(init_resolution_state(rs), find_dtxsid_cols(rs))
    changed <- TRUE
  }

  name_col <- first_tag_col(state$merged_chemical_tags, "Name")
  cas_col <- first_tag_col(state$merged_chemical_tags, "CASRN")

  if (!is.null(review_picks) && NROW(review_picks) > 0) {
    picks <- tibble::as_tibble(review_picks)
    if (!all(c("name", "dtxsid") %in% names(picks))) {
      stop("review_picks must have name and dtxsid columns (casrn optional).", call. = FALSE)
    }
    if (!"casrn" %in% names(picks)) {
      picks$casrn <- NA_character_
    }
    message(sprintf("[headless] Applying %d review picks...", nrow(picks)))
    validation <- validate_manual_dtxsids(unique(picks$dtxsid))
    invalid <- setdiff(unique(picks$dtxsid), validation$searchValue[validation$is_valid])
    if (length(invalid) > 0) {
      stop(
        sprintf("review_picks contains DTXSIDs CompTox does not know: %s", paste(invalid, collapse = ", ")),
        call. = FALSE
      )
    }
    rs <- init_resolution_state(rs)
    for (col in c("consensus_dtxsid", "consensus_source", "consensus_status", "manual_preferredName")) {
      if (!col %in% names(rs)) rs[[col]] <- NA_character_
    }
    for (i in seq_len(nrow(picks))) {
      mask <- content_row_mask(rs, name_col, cas_col, picks$name[i], picks$casrn[i])
      if (!any(mask)) {
        unmatched <- c(unmatched, sprintf("review_picks: name=%s casrn=%s", picks$name[i], picks$casrn[i]))
        next
      }
      pref <- validation$preferredName[match(picks$dtxsid[i], validation$searchValue)]
      rs$consensus_status[mask] <- "manual"
      rs$consensus_dtxsid[mask] <- picks$dtxsid[i]
      rs$consensus_source[mask] <- "manual_entry"
      rs$manual_preferredName[mask] <- pref
      rs$.manual_entry[mask] <- TRUE
      rs$.pinned[mask] <- TRUE
      rs$.resolution_method[mask] <- "manual"
    }
    changed <- TRUE
  }

  if (!is.null(row_flags) && NROW(row_flags) > 0) {
    flags <- tibble::as_tibble(row_flags)
    if (!all(c("name", "flag") %in% names(flags))) {
      stop("row_flags must have name and flag columns (casrn and reason optional).", call. = FALSE)
    }
    if (!"casrn" %in% names(flags)) {
      flags$casrn <- NA_character_
    }
    if (!"reason" %in% names(flags)) {
      flags$reason <- NA_character_
    }
    message(sprintf("[headless] Applying %d row flags...", nrow(flags)))
    rs <- init_resolution_state(rs)
    for (i in seq_len(nrow(flags))) {
      mask <- content_row_mask(rs, name_col, cas_col, flags$name[i], flags$casrn[i])
      if (!any(mask)) {
        unmatched <- c(unmatched, sprintf("row_flags: name=%s casrn=%s", flags$name[i], flags$casrn[i]))
        next
      }
      rs <- set_row_flags(rs, which(mask), flags$flag[i], flags$reason[i])
    }
    changed <- TRUE
  }

  state$resolution_state <- rs
  if (changed) {
    state$consensus_summary <- recalc_consensus_summary(rs)
  }
  state$unmatched_decisions <- unmatched
  state
}

# Rows whose cleaned Name (and CAS, when given) equal the decision key.
content_row_mask <- function(rs, name_col, cas_col, name, casrn) {
  if (is.na(name_col)) {
    stop("review_picks and row_flags need a Name-tagged column.", call. = FALSE)
  }
  mask <- !is.na(rs[[name_col]]) & as.character(rs[[name_col]]) == as.character(name)
  if (!is.na(casrn) && nzchar(casrn) && !is.na(cas_col)) {
    mask <- mask & !is.na(rs[[cas_col]]) & as.character(rs[[cas_col]]) == as.character(casrn)
  }
  mask
}

#' Stage 5: run numeric, unit, media, and ToxVal harmonization
#'
#' @param state State list from [stage_review()].
#' @inheritParams curate_headless
#' @return The state with `harmonize`, `harmonization_refs`,
#'   `harmonization_runtime_result`, `toxval_output`, `harmonize_audit`, and
#'   `detection_results` added. When `harmonize = FALSE` only `harmonize` is set.
#' @export
stage_harmonize <- function(
  state,
  harmonize = FALSE,
  unit_map = NULL,
  unit_map_snapshot = NULL,
  corrections = NULL,
  media_map = NULL,
  media_map_snapshot = NULL,
  media = NULL,
  source_name = NULL
) {
  state$harmonize <- isTRUE(harmonize)
  if (!state$harmonize) {
    return(state)
  }

  message("[headless] Running harmonization pipeline...")

  if (!is.null(unit_map_snapshot)) {
    if (!is.null(unit_map)) {
      stop("curate_headless: provide either unit_map or unit_map_snapshot, not both.", call. = FALSE)
    }
    unit_map <- reconstruct_unit_map_snapshot(unit_map_snapshot)
  }
  if (!is.null(media_map_snapshot)) {
    if (!is.null(media_map)) {
      stop("curate_headless: provide either media_map or media_map_snapshot, not both.", call. = FALSE)
    }
    media_map <- reconstruct_media_map_snapshot(media_map_snapshot)
  }

  harmonization_refs <- resolve_harmonization_references(
    unit_map = unit_map,
    corrections = corrections,
    media_map = media_map,
    reference_lists = state$reference_lists
  )

  runtime_result <- run_harmonization_runtime(
    input_data = state$resolution_state,
    tag_map = state$merged_tags,
    unit_map = harmonization_refs$unit_map,
    corrections = harmonization_refs$corrections,
    media_map = harmonization_refs$media_map,
    media = media,
    source_name = source_name %||% tools::file_path_sans_ext(basename(state$input_path))
  )

  # Advance the replay baseline to the harmonized stage too, so an exported
  # workbook diffs review edits against a like-staged baseline (see the
  # matching logic in mod_harmonize).
  baseline <- state$script_baseline_state
  if (!is.null(baseline) && nrow(baseline) == nrow(runtime_result$data)) {
    harmonized_baseline <- runtime_result$data
    for (col in intersect(review_override_columns(), names(harmonized_baseline))) {
      harmonized_baseline[[col]] <- if (col %in% names(baseline)) {
        baseline[[col]]
      } else {
        empty_review_override_column(col, nrow(harmonized_baseline))
      }
    }
    state$script_baseline_state <- harmonized_baseline
  }

  state$harmonization_refs <- harmonization_refs
  state$harmonization_runtime_result <- runtime_result
  state$resolution_state <- runtime_result$data
  state$toxval_output <- runtime_result$toxval_output
  state$harmonize_audit <- runtime_result$harmonize_audit
  state$detection_results <- runtime_result$detection_results

  message(sprintf(
    "[headless] ToxVal schema: %d rows x %d columns",
    nrow(state$toxval_output),
    ncol(state$toxval_output)
  ))
  state
}

#' Stage 6: write outputs and build the result list
#'
#' @param state State list from [stage_harmonize()].
#' @inheritParams curate_headless
#' @return The list documented under the [curate_headless()] return value.
#' @export
stage_export <- function(state, output_path = NULL, format = "parquet", write_files = TRUE) {
  if (write_files) {
    sheets <- build_export_sheets(
      raw = state$raw_df,
      resolution_state = state$resolution_state,
      consensus_summary = state$consensus_summary,
      cleaning_audit = state$cleaning_result$audit_trail,
      reference_lists = state$reference_lists,
      column_tags = state$merged_tags,
      detection = state$detection,
      file_info = state$file_info,
      enrichment_cache = state$enrichment_cache,
      detected_data = state$clean_data,
      cleaned_data = state$cleaning_result$cleaned_data,
      toxval_output = state$toxval_output,
      harmonize_audit = state$harmonize_audit,
      site_manifest = state$site_manifest,
      site_alias_map = state$site_alias_map,
      script_baseline_state = state$script_baseline_state,
      media_map = if (isTRUE(state$harmonize)) state$harmonization_refs$media_map else NULL,
      media_results = state$harmonization_runtime_result$media_results
    )

    fs::dir_create(dirname(output_path), recurse = TRUE)
    write_curation_output(output_path, "xlsx", sheets = sheets)
    message(sprintf("[headless] Output written to: %s", output_path))

    if (isTRUE(state$harmonize)) {
      toxval_base <- sub("\\.xlsx$", "", output_path, ignore.case = TRUE)
      if (format %in% c("parquet", "both")) {
        parquet_path <- paste0(toxval_base, "_toxval.parquet")
        write_curation_output(parquet_path, "parquet", toxval_tibble = state$toxval_output)
        message(sprintf("[headless] Parquet written: %s", basename(parquet_path)))
      }
      if (format %in% c("csv", "both")) {
        csv_path <- paste0(toxval_base, "_toxval.csv")
        write_curation_output(csv_path, "csv", toxval_tibble = state$toxval_output)
        message(sprintf("[headless] CSV written: %s", basename(csv_path)))
      }
    }
  }

  if (isTRUE(state$harmonize)) {
    runtime <- state$harmonization_runtime_result
    invisible(list(
      data = state$toxval_output,
      audit_trail = state$cleaning_result$audit_trail,
      harmonize_audit = state$harmonize_audit,
      harmonize_results = runtime$harmonize_results,
      media_results = runtime$media_results,
      duration_results = runtime$duration_results,
      date_results = runtime$date_results,
      detection = state$detection_results,
      detection_results = state$detection_results,
      row_data = state$resolution_state
    ))
  } else {
    invisible(list(data = state$resolution_state, audit_trail = state$cleaning_result$audit_trail))
  }
}
