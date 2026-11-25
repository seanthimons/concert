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
    "pubchem",
    "desalt",
    "desalt_workflows",
    "accept_suggestions",
    "review_picks",
    "row_flags",
    "review_decision_evidence",
    "candidate_validation",
    "identity_decisions",
    "ignored_identifier_cols",
    "site_alias_map",
    "site_manifest",
    "harmonize",
    "toxval_identity_mode",
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
  d$pubchem <- isTRUE(d$pubchem)
  d$desalt <- isTRUE(d$desalt)
  d$desalt_workflows <- d$desalt_workflows %||% DESALT_WORKFLOWS
  d$accept_suggestions <- isTRUE(d$accept_suggestions)
  d$harmonize <- isTRUE(d$harmonize)
  d$toxval_identity_mode <- match.arg(d$toxval_identity_mode %||% "lookup", c("lookup", "accepted"))
  d$format <- d$format %||% "parquet"
  # A file name here is the JSON Lines ledger; everything downstream gets the resolved list.
  if (is.character(d$identity_decisions) && length(d$identity_decisions) == 1L) {
    d$identity_ledger_path <- as.character(fs::path_abs(d$identity_decisions, start = dirname(decisions_path)))
    ledger <- read_identity_ledger(d$identity_ledger_path)
    d["identity_decisions"] <- list(if (length(ledger)) ledger)
  }
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
    "# Tag values: Name, CASRN, Other, DTXSID (source evidence), Result, Numeric, Unit, Qualifier, ReportingLimit,",
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
    "# cleaning_steps <- list(chiral = FALSE, truncated = FALSE, synonyms = FALSE)",
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
    "# name and casrn as shown in pending.csv; a blank casrn matches rows with a blank CAS only.",
    "# multi_analyte_resolutions <- tibble::tibble(",
    "#   name = c(\"Lead + Zinc\", \"Chromium and compounds\"),",
    "#   casrn = c(NA, \"7440-47-3\"),",
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
    "# External lookups can take time on large datasets. Set either to FALSE when unnecessary.",
    "pubchem <- TRUE",
    "desalt <- TRUE",
    "# Structure parents from the chemi standardizer: \"qsar-ready\", \"ms-ready\", or both.",
    "desalt_workflows <- c(\"qsar-ready\", \"ms-ready\")",
    "",
    "# ignored_identifier_cols <- c(\"source_dtxsid\") # deliberate metadata-only use",
    "# review_decision_evidence <- NULL # explicit capture_review_decision() snapshots/acknowledgments",
    "# candidate_validation <- NULL # saved validate_review_candidates()$validation",
    "# identity_decisions <- \"identity_decisions.jsonl\" # ledger; change it only with record_identity_decision()",
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
    "# FOLLOW-UP/BAD disposition unresolved rows. VERIFIED requires a current identity or reviewed WQX name.",
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
  wqx_unresolved <- !is_multi & !flagged & status %in% "wqx" & !reviewed_wqx_rows(rs)
  verified_unresolved <- verified_unresolved_rows(rs)
  candidate_work <- state$candidate_review
  candidate_idx <- if (!is.null(candidate_work)) candidate_work$row_id[candidate_work$actionable %in% TRUE] else integer()
  candidate_validation <- seq_len(n) %in% candidate_idx
  scope <- identity_scope_blockers(rs)
  source <- source_identity_blockers(rs)
  source_review <- Reduce(`|`, source)
  # VERIFIED is not a scope decision; only FOLLOW-UP/BAD disposition scope work (#110).
  dispositioned <- rs$row_flag %in% c("FOLLOW-UP", "BAD")
  scope_review <- !dispositioned & (scope$scope | scope$conflict | scope$stale | source_review |
    wqx_correspondence_blockers(rs))
  # Split children share original_row_id, so drift matches on the part index too.
  row_key <- function(x) paste(as.integer(identity_col(x, "original_row_id")),
    as.integer(identity_col(x, "multi_analyte_part_index")))
  drift_at <- match(row_key(rs), if (NROW(state$identity_drift)) row_key(state$identity_drift) else character())
  drifted <- !is.na(drift_at)
  idx <- which(drifted | is_multi | needs_pick | no_match | wqx_unresolved | verified_unresolved |
    candidate_validation | scope_review)
  if (length(idx) == 0) {
    return(empty_pending())
  }

  pending_type <- ifelse(
    is_multi[idx],
    "multi_analyte",
    ifelse(verified_unresolved[idx], "verified_unresolved",
      ifelse(candidate_validation[idx], "candidate_validation",
        ifelse(scope_review[idx], "identity_scope", ifelse(no_match[idx], "no_match", status[idx]))))
  )
  pending_type[drifted[idx]] <- "identity_drift"
  drift_field <- function(col) {
    if (NROW(state$identity_drift)) as.character(state$identity_drift[[col]][drift_at[idx]]) else NA_character_
  }
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
      wqx_candidates <- normalize_review_candidates(rs, i)
      wqx_candidates <- wqx_candidates[grepl("^wqx_cas", wqx_candidates$source), , drop = FALSE]
      if (length(opts) == 0) {
        return(if (nrow(wqx_candidates)) candidate_review_text(wqx_candidates) else NA_character_)
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

  candidate_field <- function(col) {
    if (col %in% names(rs)) as.character(rs[[col]][idx]) else rep(NA_character_, length(idx))
  }

  tibble::tibble(
    row_index = if ("original_row_id" %in% names(rs)) as.integer(rs$original_row_id[idx]) else idx,
    pending_type = pending_type,
    name = name_vals,
    casrn = cas_vals,
    consensus_status = status[idx],
    row_flag = rs$row_flag[idx],
    row_flag_reason = rs$row_flag_reason[idx],
    identity_blockers = identity_review_state(rs)$identity_blockers[idx],
    suggested_dtxsid = suggested_dtxsid,
    suggested_split = split_suggestion,
    candidates = candidates,
    wqx_name = wqx_pending_field(rs, idx, "wqx_name"),
    wqx_cas = wqx_pending_field(rs, idx, "wqx_cas"),
    wqx_cas_status = wqx_pending_field(rs, idx, "wqx_cas_status"),
    wqx_cas_raw = wqx_pending_field(rs, idx, "wqx_cas_raw"),
    wqx_cas_provenance = wqx_pending_field(rs, idx, "wqx_cas_provenance"),
    wqx_cas_dtxsid_candidates = wqx_pending_field(rs, idx, "wqx_cas_dtxsid_candidates"),
    wqx_cas_candidate_names = wqx_pending_field(rs, idx, "wqx_cas_candidate_names"),
    wqx_cas_lookup_status = wqx_pending_field(rs, idx, "wqx_cas_lookup_status"),
    pubchem_query = candidate_field("pubchem_query"),
    pubchem_cid_candidates = candidate_field("pubchem_cid_candidates"),
    pubchem_dtxsid_candidates = candidate_field("pubchem_dtxsid_candidates"),
    pubchem_lookup_status = candidate_field("pubchem_lookup_status"),
    pubchem_query_details = candidate_field("pubchem_query_details"),
    parent_name_candidate = candidate_field("parent_name_candidate"),
    parent_dtxsid_candidates = candidate_field("parent_dtxsid_candidates"),
    parent_lookup_status = candidate_field("parent_lookup_status"),
    resolver_dtxsid_candidate = candidate_field("resolver_dtxsid_candidate"),
    resolver_query = candidate_field("resolver_query"),
    resolver_query_details = candidate_field("resolver_query_details"),
    resolver_name = candidate_field("resolver_name"),
    resolver_lookup_status = candidate_field("resolver_lookup_status"),
    tied_dtxsids = candidate_field(if ("tied_dtxsids" %in% names(rs)) "tied_dtxsids" else paste0("tied_dtxsids_", name_col)),
    cleaning_flag = if ("cleaning_flag" %in% names(rs)) as.character(rs$cleaning_flag[idx]) else NA_character_,
    drift_recorded_fingerprint = drift_field("recorded_fingerprint"),
    drift_current_fingerprint = drift_field("current_fingerprint"),
    drift_changed_columns = drift_field("changed_columns"),
    drift_decision = ifelse(drifted[idx], paste(drift_field("action"), dplyr::coalesce(drift_field("selected_dtxsid"), ""),
      drift_field("reason"), sep = " | "), NA_character_)
  )
}

empty_pending <- function() {
  tibble::tibble(
    row_index = integer(),
    pending_type = character(),
    name = character(),
    casrn = character(),
    consensus_status = character(),
    row_flag = character(),
    row_flag_reason = character(),
    identity_blockers = character(),
    suggested_dtxsid = character(),
    suggested_split = character(),
    candidates = character(),
    wqx_name = character(),
    wqx_cas = character(),
    wqx_cas_status = character(),
    wqx_cas_raw = character(),
    wqx_cas_provenance = character(),
    wqx_cas_dtxsid_candidates = character(),
    wqx_cas_candidate_names = character(),
    wqx_cas_lookup_status = character(),
    pubchem_query = character(),
    pubchem_cid_candidates = character(),
    pubchem_dtxsid_candidates = character(),
    pubchem_lookup_status = character(),
    pubchem_query_details = character(),
    parent_name_candidate = character(),
    parent_dtxsid_candidates = character(),
    parent_lookup_status = character(),
    resolver_dtxsid_candidate = character(),
    resolver_query = character(),
    resolver_query_details = character(),
    resolver_name = character(),
    resolver_lookup_status = character(),
    tied_dtxsids = character(),
    cleaning_flag = character(),
    drift_recorded_fingerprint = character(),
    drift_current_fingerprint = character(),
    drift_changed_columns = character(),
    drift_decision = character()
  )
}

first_tag_col <- function(tags, tag) {
  cols <- names(tags)[unlist(tags) == tag]
  if (length(cols) == 0) NA_character_ else cols[1]
}

# Preferred name of each row's current identity: the consensus source's name, or the picked one.
preferred_names <- function(rs) {
  n <- nrow(rs)
  pref <- rep(NA_character_, n)
  src <- rs$consensus_source %||% rep(NA_character_, n)
  for (s in unique(src[!is.na(src)])) {
    col <- source_to_column("preferredName", s)
    mask <- !is.na(src) & src == s
    if (col %in% names(rs)) {
      pref[mask] <- as.character(rs[[col]][mask])
    }
  }
  if ("manual_preferredName" %in% names(rs)) {
    m <- !is.na(rs$manual_preferredName)
    pref[m] <- as.character(rs$manual_preferredName[m])
  }
  pref
}

# The flat result a pipeline reads: fixed column names after the source columns.
mapping_table <- function(state) {
  rs <- init_resolution_state(state$resolution_state)
  review <- identity_review_state(rs)
  name <- as.character(identity_col(rs, "consensus_name"))
  flag <- identity_col(rs, "row_flag")
  method <- identity_col(rs, ".resolution_method")
  fixed <- tibble::tibble(
    dtxsid = review$accepted_dtxsid,
    wqx_name = ifelse(reviewed_wqx_rows(rs), name, NA_character_),
    preferred_name = dplyr::coalesce(preferred_names(rs), name),
    identity_status = review$identity_status,
    decided_by = dplyr::case_when(
      !is.na(identity_col(rs, "identity_decision_record")) ~ "identity_decision",
      flag %in% c("BAD", "FOLLOW-UP") ~ "flag",
      method %in% c("manual", "manual_wqx", "user-pick") ~ "pick",
      method %in% c("bulk-accept", "suggested-accept") ~ "accepted_suggestion",
      TRUE ~ "automatic"
    ),
    row_flag = flag,
    identity_blockers = review$identity_blockers
  )
  source <- tibble::as_tibble(rs[identity_selector_columns(rs, state$merged_chemical_tags)])
  # The fixed names are the contract; a source column that shares one is renamed.
  clash <- names(source) %in% names(fixed)
  names(source)[clash] <- paste0("source_", names(source)[clash])
  dplyr::bind_cols(source, fixed)
}

# What a run's result depends on: versions, and a hash of each file the run reads.
run_lock <- function(decisions_path, d) {
  base <- dirname(decisions_path)
  tokens <- utils::getParseData(parse(decisions_path, keep.source = TRUE))
  named <- vapply(tokens$text[tokens$token == "STR_CONST"], function(s) {
    tryCatch(as.character(eval(parse(text = s)))[1], error = function(e) NA_character_)
  }, character(1))
  named <- named[!is.na(named) & nzchar(named)]
  # ponytail: only files decisions.R names as a string are seen. Paths built at run time
  # (file.path(), here::here()) and files read by a sourced file are not; hash those by
  # naming them in decisions.R, or walk source() calls here if that proves too easy to miss.
  # A relative name is tried against the working directory, as sys.source() reads it, then next to
  # decisions.R, so check the lock from the directory the run used.
  paths <- c(decisions_path, d$input_path, d$identity_ledger_path, named, file.path(base, named))
  paths <- paths[file.exists(paths) & !dir.exists(paths)]
  # The workbook is an output: hashing it would make every finished run look changed.
  paths <- setdiff(unique(as.character(fs::path_real(paths))),
    if (!is.null(d$output_path) && file.exists(d$output_path)) as.character(fs::path_real(d$output_path)))
  files <- vapply(paths, function(p) digest::digest(file = p, algo = "sha256"), character(1))
  names(files) <- as.character(fs::path_rel(paths, start = fs::path_real(base)))
  dsstox <- tryCatch(suppressMessages(ComptoxR::db_installed_version("dsstox")), error = function(e) NA_character_)
  list(
    versions = list(
      concert = as.character(utils::packageVersion("concert")),
      ComptoxR = as.character(utils::packageVersion("ComptoxR")),
      dsstox = if (length(dsstox) == 1L && !is.na(dsstox)) as.character(dsstox) else "not installed"
    ),
    files = as.list(files[order(names(files))])
  )
}

# Accepted matches whose preferred name looks nothing like the input name.
# Catches wrong automatic hits ("Total PFAS" -> "Total Furans") that never
# reach pending.csv. Token Jaccard on lowercase words: shared prefixes such as
# "Total" do not rescue a match whose distinguishing token differs.
low_similarity_rows <- function(state, threshold = 0.5) {
  rs <- state$resolution_state
  name_col <- first_tag_col(state$merged_chemical_tags, "Name")
  empty <- tibble::tibble(row_index = integer(), name = character(), dtxsid = character(), preferred_name = character())
  if (NROW(rs) == 0 || is.na(name_col) || !"consensus_dtxsid" %in% names(rs)) {
    return(empty)
  }
  rs <- init_resolution_state(rs)
  pref <- preferred_names(rs)
  name <- as.character(rs[[name_col]])
  ok <- !is.na(rs$consensus_dtxsid) & !is.na(pref) & !is.na(name) & is.na(rs$row_flag) & !(rs$.pinned %in% TRUE)
  if (!any(ok)) {
    return(empty)
  }
  sim <- rep(NA_real_, nrow(rs))
  sim[ok] <- name_token_similarity(name[ok], pref[ok])
  idx <- which(ok & sim < threshold)
  tibble::tibble(
    row_index = if ("original_row_id" %in% names(rs)) as.integer(rs$original_row_id[idx]) else idx,
    name = name[idx],
    dtxsid = as.character(rs$consensus_dtxsid[idx]),
    preferred_name = pref[idx]
  )
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
  low_sim <- if (length(state)) low_similarity_rows(state) else NULL
  low_sim_lines <- if (NROW(low_sim)) {
    c(
      "## Low-similarity matches",
      "",
      "Accepted resolutions whose preferred name differs from the input name. Confirm each with",
      "`row_flags` (VERIFIED) or override it with `review_picks` before calling the curation done.",
      "",
      "| row | name | dtxsid | preferred name |",
      "|---|---|---|---|",
      paste0("| ", low_sim$row_index, " | ", low_sim$name, " | ", low_sim$dtxsid, " | ", low_sim$preferred_name, " |"),
      ""
    )
  } else {
    character(0)
  }

  lines <- c(
    "# CONCERT curation status",
    "",
    paste0("- input: ", decisions$input_path),
    paste0("- run at: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
    paste0("- rows: ", NROW(state$resolution_state)),
    paste0("- done: ", if (done) "TRUE" else "FALSE"),
    paste0("- queue_complete: ", if (done) "TRUE" else "FALSE"),
    if (length(state$completion)) paste0("- ", names(state$completion)[-1], ": ", unlist(state$completion[-1])),
    "Queue completion records decisions and dispositions. Reconciliation completion",
    "and accepted identity are separate; acknowledgments never clear flags.",
    "",
    if (!is.null(error)) c("## Error", "", "```", conditionMessage(error), "```", "") else character(0),
    if (NROW(state$search_failures)) c(
      "## Search failures",
      "",
      "These lookups failed and their hits are missing. Rerun with `refresh_cache = TRUE` once the API recovers.",
      "",
      "| lookup | failed | unit |",
      "|---|---|---|",
      paste0("| ", state$search_failures$lookup, " | ", state$search_failures$n, " | ", state$search_failures$unit, " |"),
      ""
    ) else character(0),
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
    if (NROW(state$resolution_state) && any(verified_unresolved_rows(state$resolution_state))) {
      c(
        "## Contradictory verification",
        "",
        paste0(
          "VERIFIED rows with unresolved current identity: ",
          sum(verified_unresolved_rows(state$resolution_state)), "."
        ),
        "Prior flags and reasons are preserved in pending.csv. An explicit validated pick or",
        "FOLLOW-UP/BAD disposition is required; repeating VERIFIED alone does not resolve these rows.",
        ""
      )
    } else character(0),
    low_sim_lines,
    if (NROW(state$identity_drift)) {
      c(
        "## Drifted decisions",
        "",
        paste0("Identity decisions whose recorded evidence no longer matches the row: ",
          nrow(state$identity_drift), ". None of them was applied."),
        "Each is an `identity_drift` row in pending.csv; `drift_changed_columns` names what changed when known.",
        "Review each row as it is now. Keep the decisions that still hold with reconfirm_identity_decisions()",
        "(runner: `reconfirm`); change or withdraw the others with record_identity_decision() (runner: `record`).",
        "With list-form decisions and no ledger, set `evidence_fingerprint` to `drift_current_fingerprint` instead.",
        "replay.R stops on these decisions until they are resolved.",
        ""
      )
    } else character(0),
    "## Next",
    "",
    if (done) {
      c(
        "The review queue is complete: rows have identities or explicit dispositions.",
        "This does not mean every identity is accepted.",
        "Outputs written next to decisions.R; replay.R reproduces this run."
      )
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

#' Read a decision table
#'
#' Reads a decision table from CSV, either the text block a replay script
#' carries or a file. Every column is read as text, so names and CASRNs arrive
#' exactly as written. Stops when a `casrn` or `cas_value` value is not
#' CAS-shaped, which is what a spreadsheet leaves behind after rewriting a
#' CASRN as a date (`103-02-6` becomes `0103-02-06`). Also stops when a line
#' does not have the header's number of fields, which is what an unquoted comma
#' in a hand-edited value leaves behind: write `"1,2-Dichloroethane"`, quotes
#' included.
#'
#' @param path Path to a decision table CSV.
#' @param text CSV text to read instead of a file. One leading newline is
#'   dropped, so the header can start on its own line.
#' @return A tibble of character columns.
#' @export
read_decision_table <- function(path = NULL, text = NULL) {
  label <- path %||% "decision table"
  # readr only warns about a malformed line and shifts its columns; stop instead.
  raw <- suppressWarnings(readr::read_csv(
    if (is.null(text)) path else I(sub("^\r?\n", "", text)),
    col_types = readr::cols(.default = "c"),
    na = "",
    trim_ws = FALSE,
    name_repair = "check_unique",
    progress = FALSE
  ))
  malformed <- unique(readr::problems(raw)$row)
  if (length(malformed)) {
    stop(
      sprintf(
        "%s: line(s) %s do not have %d fields. Put a value that contains a comma in double quotes: \"1,2-Dichloroethane\".",
        label,
        paste(malformed, collapse = ", "),
        ncol(raw)
      ),
      call. = FALSE
    )
  }
  # as.list() drops readr's column-spec class, leaving a plain tibble.
  out <- tibble::as_tibble(as.list(raw))
  for (col in intersect(c("casrn", "cas_value"), names(out))) {
    bad <- which(!is_cas_shaped(out[[col]]))
    if (length(bad)) {
      stop(
        sprintf(
          "%s: %s is not CAS-shaped on line(s) %s: %s. A spreadsheet may have rewritten it as a date.",
          label,
          col,
          paste(bad + 1L, collapse = ", "),
          paste(unique(out[[col]][bad]), collapse = ", ")
        ),
        call. = FALSE
      )
    }
  }
  out
}

# NA counts as CAS-shaped: a blank casrn is a valid key. A cas_value may list
# several CAS numbers separated by ";".
is_cas_shaped <- function(x) {
  cas <- "\\d{2,7}-\\d{2}-\\d"
  is.na(x) | stringr::str_detect(as.character(x), paste0("^", cas, "(\\s*;\\s*", cas, ")*$"))
}

# TRUE when read_decision_table() returns the table as written, so replay.R
# can carry it as CSV text: no list columns, and no CAS value the reader rejects.
decision_table_is_csv <- function(x) {
  x <- tibble::as_tibble(x)
  cas <- unlist(x[intersect(c("casrn", "cas_value"), names(x))])
  NROW(x) > 0 && !any(vapply(x, is.list, logical(1))) && all(is_cas_shaped(cas))
}

#' Run one iteration of the agent curation loop
#'
#' Sources `decisions.R`, runs the staged headless pipeline with a curation
#' cache, and writes `status.md`, `pending.csv`, and `replay.R` next to it.
#' `replay.R` is one self-contained file: its decision tables are CSV text
#' blocks, one decision per line, with multi-analyte resolutions recorded by
#' name and CASRN.
#' When no rows are pending it also writes the curated workbook (and ToxVal
#' files when `harmonize` is set). Re-run after editing `decisions.R` until
#' `status.md` reports `done: TRUE`.
#'
#' @param decisions_path Path to a decisions file. Create one with
#'   [curate_decisions_template()].
#' @param out_dir Output directory. Defaults to the decisions file directory.
#' @param verbose Logical. Print pipeline messages.
#' @param output_path Workbook path for this run. Overrides `output_path` in
#'   `decisions.R`, so a trial run in another `out_dir` needs no edited copy
#'   of the decisions file.
#' @param check_lock Logical. When `TRUE`, run nothing: compare the files and
#'   versions the last run in `out_dir` recorded in `run_lock.json` with the
#'   current ones and return what changed.
#' @section Run lock:
#' A run that finishes writes `run_lock.json` in `out_dir`: the concert,
#' ComptoxR and local DSSTox versions, and a SHA-256 of `decisions.R`, the
#' input file, the identity ledger and every existing file `decisions.R`
#' names as a string. A failed run leaves no lock. The lock does not cover
#' files whose paths `decisions.R` builds at run time, files read by a file
#' it sources, or web lookups cached in `out_dir/cache`.
#' @section Mapping:
#' When the run is done it writes `mapping.csv`: one line per curated row
#' with the source columns, then `dtxsid`, `wqx_name`, `preferred_name`,
#' `identity_status`, `decided_by` (`automatic`, `pick`,
#' `accepted_suggestion`, `identity_decision` or `flag`), `row_flag` and
#' `identity_blockers`.
#' @return Invisibly, a list with `done`, `pending`, `identity_drift` and
#'   `state`. `identity_drift` lists identity decisions that were skipped
#'   because their recorded evidence fingerprint no longer matches the row;
#'   each is also an `identity_drift` row in `pending.csv`. It is `NULL` when
#'   there are no identity decisions. With `check_lock = TRUE`, a list with
#'   `current` (nothing changed since the lock), `done` (that run was done)
#'   and `changed` (what differs).
#' @export
curate_iterate <- function(decisions_path, out_dir = dirname(decisions_path), verbose = TRUE,
                           output_path = NULL, check_lock = FALSE) {
  if (!file.exists(decisions_path)) {
    stop(sprintf("decisions file not found: %s. Run curate_decisions_template() first.", decisions_path), call. = FALSE)
  }
  d <- read_decisions(decisions_path)
  lock_path <- file.path(out_dir, "run_lock.json")
  # Hashed before the run, so a file that changes while it runs makes the lock stale, not wrong.
  lock <- run_lock(decisions_path, d)
  if (check_lock) {
    old <- if (file.exists(lock_path)) jsonlite::fromJSON(lock_path) else list()
    flat <- function(x) unlist(x[c("versions", "files")])
    keys <- union(names(flat(old)), names(flat(lock)))
    changed <- keys[!vapply(keys, function(k) identical(unname(flat(old)[k]), unname(flat(lock)[k])), logical(1))]
    if (!length(old)) changed <- "run_lock.json"
    message(if (length(changed)) paste0("[lock] changed since the last run: ", paste(changed, collapse = ", ")) else
      "[lock] nothing changed since the last run.")
    return(invisible(list(current = !length(changed), done = isTRUE(old$done), changed = changed)))
  }
  fs::dir_create(out_dir, recurse = TRUE)
  if (!is.null(output_path)) d$output_path <- output_path
  cache_dir <- file.path(out_dir, "cache")
  status_path <- file.path(out_dir, "status.md")
  unlink(c(lock_path, file.path(out_dir, "mapping.csv")))
  # Clear prior reports before running: a failure must not present old work as current.
  readr::write_csv(empty_review_reconciliation(), file.path(out_dir, "review_reconciliation.csv"))
  readr::write_csv(candidate_review_table(), file.path(out_dir, "candidate_review.csv"))
  readr::write_csv(empty_pending(), file.path(out_dir, "pending.csv"))
  identity_state_path <- file.path(cache_dir, "identity_state.rds")
  unlink(identity_state_path)

  run <- function() {
    state <- stage_ingest(
      input_path = d$input_path,
      tag_map = d$tag_map,
      header_row = d$header_row,
      reference_list_snapshot = d$reference_list_snapshot,
      activate_all_references = d$activate_all_references,
      site_manifest = d$site_manifest,
      site_alias_map = d$site_alias_map,
      ignored_identifier_cols = d$ignored_identifier_cols %||% character()
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
      pubchem = d$pubchem,
      desalt = d$desalt,
      desalt_workflows = d$desalt_workflows,
      postprocess_candidates = TRUE,
      cache_dir = cache_dir
    )
    state <- stage_review(
      state,
      accept_suggestions = d$accept_suggestions,
      review_picks = d$review_picks,
      row_flags = d$row_flags,
      review_decision_evidence = d$review_decision_evidence,
      candidate_validation = d$candidate_validation,
      identity_decisions = d$identity_decisions,
      on_identity_drift = "report"
    )
    stage_harmonize(
      state,
      harmonize = d$harmonize,
      toxval_identity_mode = d$toxval_identity_mode,
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
  # A drifted decision blocks completion even if its row is somehow not in pending.
  done <- nrow(pending) == 0 && !NROW(state$identity_drift)
  state$completion <- review_completion(state, pending)
  readr::write_csv(state$review_reconciliation, file.path(out_dir, "review_reconciliation.csv"), na = "")
  readr::write_csv(state$candidate_review, file.path(out_dir, "candidate_review.csv"), na = "")
  readr::write_csv(state$identifier_diagnostics %||% unused_source_identifier_diagnostics(data.frame()),
    file.path(out_dir, "identifier_diagnostics.csv"), na = "")
  identity_report <- state$resolution_state
  identity_report[names(state$accepted_identity_state)] <- state$accepted_identity_state
  readr::write_csv(identity_report, file.path(out_dir, "identity_review.csv"), na = "")
  readr::write_csv(pending, file.path(out_dir, "pending.csv"), na = "")
  # What the ledger recorder fingerprints against, valid only for these exact inputs.
  fs::dir_create(cache_dir)
  saveRDS(list(resolution_state = state$identity_decision_input, tags = state$merged_chemical_tags,
    drift = state$identity_drift, stamp = ledger_run_stamp(decisions_path, d$input_path)), identity_state_path)

  replay <- generate_concert_script(
    input_path = d$input_path,
    output_path = d$output_path %||% file.path(out_dir, "curated.xlsx"),
    tag_map = d$tag_map,
    header_row = d$header_row %||% state$detection$header_row,
    wqx_threshold = d$wqx_threshold,
    starts_with = d$starts_with,
    pubchem = d$pubchem,
    desalt = d$desalt,
    desalt_workflows = d$desalt_workflows,
    harmonize = d$harmonize,
    toxval_identity_mode = d$toxval_identity_mode,
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
    multi_analyte_resolutions = state$multi_analyte_resolutions_replay,
    accept_suggestions = d$accept_suggestions,
    review_picks = d$review_picks,
    row_flags = d$row_flags,
    review_decision_evidence = d$review_decision_evidence,
    candidate_validation = d$candidate_validation,
    identity_decisions = strip_ledger_fields(d$identity_decisions),
    ignored_identifier_cols = d$ignored_identifier_cols %||% character()
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
    readr::write_csv(mapping_table(state), file.path(out_dir, "mapping.csv"), na = "")
  }
  # Last, so a lock exists only for a run whose outputs were all written.
  jsonlite::write_json(c(lock, list(done = done)), lock_path, auto_unbox = TRUE, pretty = TRUE)

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
  invisible(c(list(done = done, pending = pending, identity_drift = state$identity_drift, state = state),
    state$completion))
}


review_completion <- function(state, pending) {
  reconciliation <- state$review_reconciliation %||% empty_review_reconciliation()
  candidate <- state$candidate_review %||% candidate_review_table()
  identity <- identity_review_state(state$resolution_state)
  flags <- identity_col(state$resolution_state, "row_flag")
  rs <- state$resolution_state
  canonical <- identity_col(rs, "consensus_name")
  wqx_reviewed <- reviewed_wqx_rows(rs)
  reviewed <- identity$identity_eligible | wqx_reviewed | flags %in% "BAD"
  list(queue_complete = nrow(pending) == 0L,
    reconciliation_complete = !any(reconciliation$actionable %in% TRUE),
    reconciliation_items = sum(reconciliation$actionable %in% TRUE),
    candidate_validation_items = sum(candidate$actionable %in% TRUE),
    baseline_missing = sum(reconciliation$baseline_status %in% "baseline_missing"),
    follow_up_rows = sum(flags %in% "FOLLOW-UP"),
    accepted_identity_rows = sum(identity$identity_eligible),
    identity_review_complete = all(reviewed),
    review_complete = nrow(pending) == 0L && !any(reconciliation$actionable %in% TRUE) &&
      !any(candidate$actionable %in% TRUE) && all(reviewed))
}
