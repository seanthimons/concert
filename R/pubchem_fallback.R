unresolved_name_queries <- function(df, name_cols, original_data = NULL) {
  name_cols <- intersect(name_cols, names(df))
  empty <- list(rows = integer(), names = character(), role = character(), source_column = character(),
                original_row_id = character())
  if (!length(name_cols) || !nrow(df)) return(empty)
  ids <- df$consensus_dtxsid
  unresolved <- which(df$consensus_status %in% c("error", "unresolvable", "wqx") &
                        (is.na(ids) | !nzchar(trimws(ids))))
  if (!length(unresolved)) return(empty)
  result <- empty
  append_query <- function(rows, query, role, column) {
    result$rows <<- c(result$rows, rows)
    result$names <<- c(result$names, trimws(as.character(query)))
    result$role <<- c(result$role, rep(role, length(rows)))
    result$source_column <<- c(result$source_column, rep(column, length(rows)))
    lineage <- if ("original_row_id" %in% names(df)) as.character(df$original_row_id[rows]) else rep(NA_character_, length(rows))
    result$original_row_id <<- c(result$original_row_id, lineage)
  }
  # Keep the original first-Name behavior. Canonical queries supplement this
  # input; they never replace it or substitute an unsplit parent for a part.
  column <- name_cols[1]
  original <- as.character(df[[column]][unresolved])
  if (!is.null(original_data) && column %in% names(original_data) && "original_row_id" %in% names(df)) {
    input_rows <- if ("original_row_id" %in% names(original_data)) {
      match(df$original_row_id[unresolved], original_data$original_row_id)
    } else suppressWarnings(as.integer(df$original_row_id[unresolved]))
    valid <- !is.na(input_rows) & input_rows >= 1L & input_rows <= nrow(original_data)
    if ("multi_analyte_part_count" %in% names(df)) {
      valid <- valid & (is.na(df$multi_analyte_part_count[unresolved]) | df$multi_analyte_part_count[unresolved] <= 1L)
    }
    values <- as.character(original_data[[column]][input_rows[valid]])
    available <- !is.na(values) & nzchar(trimws(values))
    original[which(valid)[available]] <- values[available]
  }
  append_query(unresolved, original, "original", column)
  for (column in name_cols) {
    suffixes <- c(paste0("_lookup_", column), paste0("_", column), if (length(name_cols) == 1L) "")
    # A generated collision-safe field owns the evidence, even when empty;
    # never fall back into the raw input column it was created to protect.
    if (paste0("wqx_name_lookup_", column) %in% names(df)) suffixes <- suffixes[1L]
    canonical <- rep(NA_character_, length(unresolved))
    for (suffix in suffixes) {
      canonical_col <- paste0("wqx_name", suffix)
      if (canonical_col %in% names(df) && !canonical_col %in% name_cols) {
        candidate <- as.character(df[[canonical_col]][unresolved])
      } else {
        preferred <- paste0("preferredName", suffix)
        tier <- paste0("source_tier", suffix)
        if (!all(c(preferred, tier) %in% names(df))) next
        candidate <- ifelse(grepl("^wqx_", df[[tier]][unresolved]), as.character(df[[preferred]][unresolved]), NA_character_)
      }
      fill <- (is.na(canonical) | !nzchar(trimws(canonical))) & !is.na(candidate) & nzchar(trimws(candidate))
      canonical[fill] <- candidate[fill]
    }
    keep <- !is.na(canonical) & nzchar(trimws(canonical)) &
      (is.na(original) | tolower(trimws(canonical)) != tolower(trimws(original)))
    append_query(unresolved[keep], canonical[keep], "wqx_canonical", column)
  }
  result
}

fallback_join <- function(values) {
  values <- unique(values[!is.na(values) & nzchar(values)])
  if (length(values)) paste(values, collapse = "; ") else NA_character_
}

fallback_query_details <- function(info, indices, statuses, candidates, cids = NULL) {
  records <- lapply(indices, function(i) list(query = info$names[i], role = info$role[i],
    source_column = info$source_column[i], original_row_id = info$original_row_id[i],
    status = unname(statuses[info$names[i]]), candidates = candidates[[info$names[i]]] %||% character(),
    cids = if (is.null(cids)) character() else cids[[info$names[i]]] %||% character()))
  as.character(jsonlite::toJSON(records, auto_unbox = TRUE, na = "null", null = "null"))
}

# PubChem is a source of review candidates, not a source of accepted DTXSIDs.
add_pubchem_candidates <- function(df, name_cols, original_data = NULL,
                                   search_fn = ComptoxR::pubchem_search,
                                   synonyms_fn = ComptoxR::pubchem_synonyms) {
  df$pubchem_query <- NA_character_
  df$pubchem_cid_candidates <- NA_character_
  df$pubchem_dtxsid_candidates <- NA_character_
  df$pubchem_lookup_status <- NA_character_

  df$pubchem_query_details <- NA_character_
  info <- unresolved_name_queries(df, name_cols, original_data)
  keep <- !is.na(info$names) & nzchar(info$names)
  queries <- unique(info$names[keep])
  if (!length(queries)) return(df)
  statuses <- stats::setNames(rep("no_hit", length(queries)), queries)
  cid_results <- candidate_results <- stats::setNames(vector("list", length(queries)), queries)
  for (query in queries) {
    hits <- tryCatch(search_fn(query, type = "name"), error = function(e) e)
    if (inherits(hits, "error")) { statuses[query] <- "error"; next }
    cids <- unique(as.character(hits$cid))
    cids <- cids[!is.na(cids) & nzchar(cids)]
    if (!length(cids)) next
    cid_results[[query]] <- cids
    syns <- tryCatch(synonyms_fn(as.integer(cids), tidy = TRUE), error = function(e) e)
    if (inherits(syns, "error")) { statuses[query] <- "synonyms_error"; next }
    if (all(c("cid", "synonym") %in% names(syns))) {
      cid <- as.character(syns$cid)
      synonym <- as.character(syns$synonym)
      if (length(cid) == length(synonym)) {
        matches <- !is.na(cid) & grepl("^[1-9][0-9]*$", cid) &
          !is.na(synonym) & grepl("^DTXSID[0-9]+$", synonym)
        if (any(matches)) candidate_results[[query]] <- unique(paste0(cid[matches], ":", synonym[matches]))
      }
    }
    statuses[query] <- "hit"
  }
  for (row in unique(info$rows[keep])) {
    indices <- which(keep & info$rows == row)
    query <- unique(info$names[indices])
    df$pubchem_query[row] <- fallback_join(query)
    df$pubchem_cid_candidates[row] <- fallback_join(unlist(cid_results[query], use.names = FALSE))
    df$pubchem_dtxsid_candidates[row] <- fallback_join(unlist(candidate_results[query], use.names = FALSE))
    # An empty alternate query never hides a successful query. Failures remain
    # in the summary as well as in the exact attributed query records.
    status <- unique(unname(statuses[query]))
    if ("hit" %in% status) status <- status[status != "no_hit"]
    df$pubchem_lookup_status[row] <- fallback_join(status)
    df$pubchem_query_details[row] <- fallback_query_details(info, indices, statuses, candidate_results, cid_results)
  }

  df
}

# Parent names are search suggestions only; a parent DTXSID never identifies its salt.
add_salt_parent_candidates <- function(df, name_cols, original_data = NULL,
                                       search_fn = ComptoxR::ct_chemical_search_equal_bulk) {
  df$parent_name_candidate <- NA_character_
  df$parent_dtxsid_candidates <- NA_character_
  df$parent_lookup_status <- NA_character_
  queries_info <- unresolved_name_queries(df, name_cols, original_data)
  original <- queries_info$role == "original"
  queries_info <- lapply(queries_info, function(values) values[original])
  rows <- queries_info$rows
  if (!length(rows)) return(df)

  # Whole terminal expressions only. Keep isotope labels, hydrates and any
  # remaining name components for review; prefix salts need manual handling.
  suffix <- paste(c("hydrogen fumarate", "acid tartrate", "hydrochloride",
                    "hydrobromide", "methanesulfonate", "sulphate", "sulfate",
                    "embonate", "pamoate", "mesylate", "maleate", "lactate",
                    "tartrate", "fumarate", "phosphate", "citrate", "acetate",
                    "chloride", "bromide",
                    "sodium", "potassium"), collapse = "|")
  pattern <- paste0("(?i)\\s+(?:", suffix, ")$")
  query <- queries_info$names
  eligible <- !is.na(query) & grepl(pattern, query, perl = TRUE)
  rows <- rows[eligible]
  if (!length(rows)) return(df)
  parent <- trimws(sub(pattern, "", query[eligible], perl = TRUE))
  valid <- nzchar(parent) & !grepl("(?i)(?:\\bcomplex|,\\s*basic)$", parent, perl = TRUE)
  rows <- rows[valid]
  parent <- parent[valid]
  if (!length(rows)) return(df)
  df$parent_name_candidate[rows] <- parent

  for (name in unique(parent)) {
    target <- rows[parent == name]
    hits <- tryCatch(search_fn(name), error = function(e) e)
    if (inherits(hits, "error")) {
      df$parent_lookup_status[target] <- "error"
      next
    }
    if (is.null(hits) || !nrow(hits)) {
      df$parent_lookup_status[target] <- "no_hit"
      next
    }
    value_col <- grep("^search.?value$", names(hits), ignore.case = TRUE, value = TRUE)[1]
    id_col <- grep("^dtxsid$", names(hits), ignore.case = TRUE, value = TRUE)[1]
    if (is.na(id_col) || is.na(value_col)) {
      df$parent_lookup_status[target] <- "error"
      next
    }
    matching <- tolower(trimws(as.character(hits[[value_col]]))) == tolower(name)
    ids <- unique(as.character(hits[[id_col]][!is.na(matching) & matching]))
    ids <- ids[!is.na(ids) & grepl("^DTXSID[0-9]+$", ids)]
    df$parent_lookup_status[target] <- if (length(ids)) "candidate" else "no_hit"
    if (length(ids)) df$parent_dtxsid_candidates[target] <- paste(ids, collapse = "; ")
  }
  df
}

# ---- Structure-based parents (chemi standardizer) --------------------------

DESALT_WORKFLOWS <- c("qsar-ready", "ms-ready")

# Returns one row per requested DTXSID; unresolved records keep NA fields.
desalt_lookup_structures <- function(dtxsids) {
  res <- suppressWarnings(suppressMessages(ComptoxR::chemi_resolver_lookup_bulk(dtxsids, tidy = FALSE)))
  out <- tibble::tibble(dtxsid = dtxsids, smiles = NA_character_, name = NA_character_, casrn = NA_character_)
  for (x in res) {
    i <- match(x$chemical$sid %||% NA_character_, dtxsids)
    if (is.na(i)) next
    out$smiles[i] <- x$chemical$smiles %||% NA_character_
    out$name[i] <- x$chemical$name %||% NA_character_
    out$casrn[i] <- x$chemical$casrn %||% NA_character_
  }
  out
}

desalt_standardize <- function(smiles, workflow) {
  suppressWarnings(suppressMessages(ComptoxR::chemi_stdizer(workflow = workflow, smiles = smiles)))
}

empty_parent_cache <- function() {
  tibble::tibble(dtxsid = character(), workflow = character(), parent_dtxsid = character(),
                 parent_name = character(), parent_casrn = character(), parent_status = character())
}

# One cache row per DTXSID and workflow. Statuses: self (single unlabelled
# component, or unchanged by the workflow), parent, isotope_parent, stereo_lost
# (may combine with isotope_parent), mixture, no_parent, not_registered,
# markush (CXSMILES with variable attachment, e.g. Xylenes; not standardized),
# no_structure, error.
# `rec` is the structure lookup row, or NULL when the lookup failed.
structure_parent <- function(dtxsid, rec, workflow, stdize_fn) {
  row <- function(status, parent = NA_character_, name = NA_character_, casrn = NA_character_) {
    tibble::tibble(dtxsid = dtxsid, workflow = workflow, parent_dtxsid = parent,
                   parent_name = name, parent_casrn = casrn, parent_status = status)
  }
  if (is.null(rec)) return(row("error"))
  smiles <- rec$smiles
  if (is.na(smiles) || !nzchar(smiles)) return(row("no_structure"))
  if (grepl("*", smiles, fixed = TRUE)) return(row("markush"))
  isotope <- "\\[[0-9]+[A-Z]"
  labelled <- grepl(isotope, smiles)
  if (!grepl(".", smiles, fixed = TRUE) && !labelled) return(row("self", dtxsid, rec$name, rec$casrn))
  res <- tryCatch(stdize_fn(smiles, workflow), error = function(e) e)
  if (inherits(res, "error")) return(row("error"))
  if (!length(res)) return(row("no_parent"))
  field <- function(f) vapply(res, function(x) x[[f]] %||% NA_character_, character(1))
  keep <- !duplicated(field("sid"))
  ids <- field("sid")[keep]
  names <- field("name")[keep]
  cas <- field("casrn")[keep]
  if (length(ids) > 1) {
    join <- function(x) paste(ifelse(is.na(x), "?", x), collapse = "; ")
    return(row("mixture", join(ids), join(names), join(cas)))
  }
  if (is.na(ids)) return(row("not_registered"))
  if (ids == dtxsid) return(row("self", dtxsid, rec$name, rec$casrn))
  out_smiles <- res[[1]]$smiles %||% ""
  stereo <- "[@/\\\\]"
  flags <- c(
    if (labelled && !grepl(isotope, out_smiles)) "isotope_parent",
    if (grepl(stereo, smiles) && !grepl(stereo, out_smiles)) "stereo_lost"
  )
  row(if (length(flags)) paste(flags, collapse = "; ") else "parent", ids, names, cas)
}

#' Add structure-based parent DTXSIDs for resolved rows
#'
#' Standardizes each `consensus_dtxsid` structure with the chemi standardizer
#' and writes `parent_dtxsid_<workflow>`, `parent_name_<workflow>`,
#' `parent_casrn_<workflow>`, and `parent_status_<workflow>` columns per
#' workflow. `consensus_dtxsid` is never changed. Results are cached per
#' DTXSID and workflow; errors are retried on the next call.
#'
#' @param df Resolution state with `consensus_dtxsid`.
#' @param cache Parent cache from a previous call, or NULL.
#' @param workflows One or both of "qsar-ready" and "ms-ready".
#' @param lookup_fn,stdize_fn Injectable DTXSID structure lookup and standardizer calls.
#' @return List with `data` and `cache`.
#' @keywords internal
add_structure_parents <- function(df, cache = NULL, workflows = DESALT_WORKFLOWS,
                                  lookup_fn = desalt_lookup_structures,
                                  stdize_fn = desalt_standardize) {
  workflows <- match.arg(workflows, DESALT_WORKFLOWS, several.ok = TRUE)
  cache <- cache %||% empty_parent_cache()
  if (!"consensus_dtxsid" %in% names(df)) return(list(data = df, cache = cache))

  ids <- unique(df$consensus_dtxsid[grepl("^DTXSID[0-9]+$", df$consensus_dtxsid)])
  done <- paste(cache$dtxsid, cache$workflow)[cache$parent_status != "error"]
  missing <- ids[!vapply(ids, function(id) all(paste(id, workflows) %in% done), logical(1))]
  if (length(missing)) {
    structures <- tryCatch(lookup_fn(missing), error = function(e) {
      message(sprintf("[desalt] Structure lookup failed: %s", conditionMessage(e)))
      NULL
    })
    fresh <- do.call(rbind, lapply(missing, function(id) {
      rec <- if (!is.null(structures)) as.list(structures[match(id, structures$dtxsid), ])
      do.call(rbind, lapply(workflows, function(wf) structure_parent(id, rec, wf, stdize_fn)))
    }))
    stale <- paste(cache$dtxsid, cache$workflow) %in% paste(fresh$dtxsid, fresh$workflow)
    cache <- rbind(cache[!stale, ], fresh)
  }

  for (wf in workflows) {
    suffix <- gsub("-", "_", wf)
    hit <- cache[cache$workflow == wf, ]
    i <- match(df$consensus_dtxsid, hit$dtxsid)
    for (col in c("parent_dtxsid", "parent_name", "parent_casrn", "parent_status")) {
      df[[paste0(col, "_", suffix)]] <- hit[[col]][i]
    }
  }
  list(data = df, cache = cache)
}

# The chemi resolver reaches DSSTox records the public CTX API lacks (e.g.
# Prochloraz-d4, DTXSID801539501), so hits are review candidates only and
# carry whether the DTXSIDs are in the public DSSTox build (public, not_public,
# some_public when a name has several hits, unverified, no_hit, error).
add_resolver_candidates <- function(df, name_cols, original_data = NULL,
                                    lookup_fn = ComptoxR::chemi_resolver_lookup_bulk,
                                    public_fn = dsstox_public_ids) {
  df$resolver_dtxsid_candidate <- NA_character_
  df$resolver_name <- NA_character_
  df$resolver_lookup_status <- NA_character_
  df$resolver_query <- NA_character_
  df$resolver_query_details <- NA_character_
  info <- unresolved_name_queries(df, name_cols, original_data)
  keep <- !is.na(info$names) & nzchar(info$names)
  queries <- unique(info$names[keep])
  if (!length(queries)) return(df)
  hits <- tryCatch(lookup_fn(queries, tidy = FALSE), error = function(e) e)
  statuses <- stats::setNames(rep("no_hit", length(queries)), queries)
  candidate_results <- name_results <- stats::setNames(vector("list", length(queries)), queries)
  public <- character()
  if (inherits(hits, "error")) {
    statuses[] <- "error"
  } else {
    # Identifier matches only; an InChIKey inferred from the name is not proof
    # of source identity. DUPLICATE still carries an attributed candidate.
    ok <- Filter(function(h) isTRUE(h$result %in% c("FOUND", "DUPLICATE")) &&
      !is.null(h$chemical$sid) && isTRUE(h$resolvedBy %in% c("Name", "CAS", "DTXSID")), hits)
    hit <- tibble::tibble(
      query = vapply(ok, function(h) as.character(h$query), character(1)),
      sid = vapply(ok, function(h) as.character(h$chemical$sid), character(1)),
      name = vapply(ok, function(h) as.character(h$chemical$name %||% NA_character_), character(1)))
    hit <- hit[!duplicated(hit[c("query", "sid")]), ]
    if (nrow(hit)) {
      public <- tryCatch(public_fn(unique(hit$sid)), error = function(e) {
        message("[resolver] Hits left unverified: ", conditionMessage(e)); e
      })
    }
    for (query in queries) {
      selected <- hit[hit$query == query, ]
      responses <- Filter(function(h) identical(as.character(h$query), query), hits)
      failed <- any(vapply(responses, function(h) isTRUE(h$result %in% c("ERROR", "FAILED")), logical(1)))
      if (nrow(selected)) {
        candidate_results[[query]] <- selected$sid
        name_results[[query]] <- selected$name
        statuses[query] <- if (inherits(public, "error")) "unverified" else {
          n <- sum(selected$sid %in% public)
          if (n == nrow(selected)) "public" else if (n == 0L) "not_public" else "some_public"
        }
        if (failed) statuses[query] <- paste(statuses[query], "error", sep = "; ")
      } else if (failed) statuses[query] <- "error"
    }
  }
  for (row in unique(info$rows[keep])) {
    indices <- which(keep & info$rows == row)
    query <- unique(info$names[indices])
    candidates <- unique(unlist(candidate_results[query], use.names = FALSE))
    df$resolver_query[row] <- fallback_join(query)
    df$resolver_dtxsid_candidate[row] <- fallback_join(candidates)
    df$resolver_name[row] <- fallback_join(unlist(name_results[query], use.names = FALSE))
    status <- unique(unname(statuses[query]))
    if (length(candidates)) {
      status <- if (inherits(public, "error")) "unverified" else {
        n <- sum(candidates %in% public)
        if (n == length(candidates)) "public" else if (n == 0L) "not_public" else "some_public"
      }
      if (any(grepl("error", statuses[query], fixed = TRUE))) status <- c(status, "error")
    }
    df$resolver_lookup_status[row] <- fallback_join(status)
    df$resolver_query_details[row] <- fallback_query_details(info, indices, statuses, candidate_results)
  }

  df
}

.dsstox_checked <- new.env(parent = emptyenv())

# The local DSSTox build mirrors the public dashboard. It is ~800 MB, so it is
# only downloaded or refreshed when options(concert.dsstox_install = TRUE);
# otherwise a missing copy leaves hits "unverified" and a stale copy is used
# as-is. Checked once per session.
ensure_dsstox <- function() {
  if (isTRUE(.dsstox_checked$done)) return(invisible())
  fresh <- suppressMessages(suppressWarnings(ComptoxR::dss_diag_freshness()))
  allow <- isTRUE(getOption("concert.dsstox_install", FALSE))
  upstream_known <- !is.na(fresh$latest_upstream_version)
  if (fresh$status == "missing") {
    if (!allow) {
      stop("local DSSTox copy not installed; set options(concert.dsstox_install = TRUE) ",
           "or run ComptoxR::dss_install() (~800 MB) to verify resolver hits", call. = FALSE)
    }
    ComptoxR::dss_install()
  } else if (allow && (fresh$status == "stale" || (fresh$status == "unknown" && upstream_known))) {
    message("[dsstox] Refreshing local DSSTox database")
    ComptoxR::dss_disconnect()
    ComptoxR::dss_install(overwrite = TRUE)
  }
  .dsstox_checked$done <- TRUE
  invisible()
}

dsstox_public_ids <- function(ids) {
  ensure_dsstox()
  unique(suppressMessages(ComptoxR::dss_synonyms(ids))$DTXSID)
}
