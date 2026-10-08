# One portable, append-only contract for review evidence and acknowledgments.
# These helpers never apply flags, select identities, or contact a service.

review_evidence_text <- function(x) {
  x <- trimws(as.character(x))
  x[is.na(x) | !nzchar(x)] <- NA_character_
  x
}

review_evidence_canonical <- function(x) {
  if (is.data.frame(x)) {
    x <- x[, sort(names(x)), drop = FALSE]
    rows <- lapply(seq_len(nrow(x)), function(i) review_evidence_canonical(as.list(x[i, , drop = FALSE])))
    keys <- vapply(rows, function(row) digest::digest(row, algo = "sha256"), character(1))
    return(rows[order(keys)])
  }
  if (is.list(x)) {
    if (!is.null(names(x))) x <- x[order(names(x))]
    return(lapply(x, review_evidence_canonical))
  }
  if (is.factor(x) || is.character(x)) return(review_evidence_text(x))
  x
}

review_evidence_fingerprint <- function(x) {
  digest::digest(review_evidence_canonical(x), algo = "sha256")
}

# Query records retain attribution/outcomes without treating response order,
# duplicate candidates or a displayed row number as new chemical evidence.
review_query_details <- function(raw) {
  if (is.na(raw) || !nzchar(raw)) return(NULL)
  records <- tryCatch(jsonlite::fromJSON(raw, simplifyVector = FALSE), error = function(e) NULL)
  if (!is.list(records)) return(raw)
  records <- lapply(records, function(record) {
    if (!is.list(record)) return(record)
    record$original_row_id <- NULL
    for (field in intersect(c("candidates", "cids"), names(record))) {
      record[[field]] <- sort(unique(as.character(unlist(record[[field]], use.names = FALSE))))
    }
    review_evidence_canonical(record)
  })
  keys <- vapply(records, review_evidence_fingerprint, character(1))
  records[order(keys)]
}

#' Construct explicit source/content review scope
#' @param df Source data frame.
#' @param row_indices Explicit selected row indices.
#' @param columns Source/content and lineage columns; exclude transient positions.
#' @return Canonical scope object for capture_review_decision().
#' @export
review_evidence_scope <- function(df, row_indices, columns) {
  if (!length(columns) || !all(columns %in% names(df))) {
    stop("Scope requires existing source/content columns.", call. = FALSE)
  }
  if (!length(row_indices) || anyNA(row_indices) || any(!row_indices %in% seq_len(nrow(df)))) {
    stop("Scope requires at least one existing row.", call. = FALSE)
  }
  content <- df[row_indices, unique(columns), drop = FALSE]
  rows <- review_evidence_canonical(content)
  keys <- vapply(rows, review_evidence_fingerprint, character(1))
  list(schema_version = 1L, columns = sort(unique(columns)), rows = rows,
       row_count = length(row_indices), ambiguous = anyDuplicated(keys) > 0L)
}

review_candidate_table <- function() {
  data.frame(source = character(), query = character(), cid = character(), dtxsid = character(),
             role = character(), stringsAsFactors = FALSE)
}

# Normalized source attribution is evidence, never a trusted consensus column.
normalize_review_candidates <- function(df, row_indices = seq_len(nrow(df)), source_id_cols = "source_dtxsid") {
  out <- list()
  add <- function(source, query, tokens, role = "candidate", paired = FALSE) {
    tokens <- review_evidence_text(tokens)
    tokens <- tokens[!is.na(tokens)]
    tokens <- trimws(unlist(strsplit(tokens, "[;|]")))
    if (paired) {
      tokens <- tokens[grepl("^[1-9][0-9]*:DTXSID[0-9]+$", tokens)]
      cid <- sub(":.*$", "", tokens)
      ids <- sub("^[^:]+:", "", tokens)
    } else {
      ids <- tokens[grepl("^DTXSID[0-9]+$", tokens)]
      cid <- rep(NA_character_, length(ids))
    }
    if (length(ids)) {
      out[[length(out) + 1L]] <<- data.frame(source = source, query = query, cid = cid,
        dtxsid = ids, role = role, stringsAsFactors = FALSE)
    }
  }
  value <- function(col, i) if (col %in% names(df)) review_evidence_text(df[[col]][i]) else NA_character_
  add_details <- function(source, i, paired = FALSE) {
    raw <- value(paste0(source, "_query_details"), i)
    details <- if (!is.na(raw)) tryCatch(jsonlite::fromJSON(raw, simplifyVector = FALSE),
      error = function(e) NULL) else NULL
    if (!is.list(details) || !length(details)) return(FALSE)
    for (entry in details) {
      if (!is.list(entry) || length(entry$query) != 1L) return(FALSE)
      role <- if (isTRUE(entry$role == "wqx_canonical")) "vocabulary_name_candidate" else "candidate"
      add(source, entry$query, unlist(entry$candidates, use.names = FALSE), role, paired)
    }
    TRUE
  }
  for (i in row_indices) {
    if (!add_details("resolver", i)) {
      query <- value("resolver_query", i)
      if (is.na(query)) query <- value("pubchem_query", i)
      add("resolver", query, value("resolver_dtxsid_candidate", i))
    }
    if (!add_details("pubchem", i, paired = TRUE)) {
      add("pubchem", value("pubchem_query", i), value("pubchem_dtxsid_candidates", i), paired = TRUE)
    }
    for (col in wqx_review_columns(df, "wqx_cas_dtxsid_candidates")) {
      suffix <- sub("^wqx_cas_dtxsid_candidates", "", col)
      add(paste0("wqx_cas", suffix), value(paste0("wqx_cas", suffix), i), value(col, i),
        role = "vocabulary_cas_candidate")
    }
    for (col in intersect(source_id_cols, names(df))) {
      add(paste0("source:", col), NA_character_, toupper(value(col, i)), role = "source_metadata")
    }
    add("parent", value("parent_name_candidate", i), value("parent_dtxsid_candidates", i), role = "parent_suggestion")
    for (col in grep("^tied_dtxsids($|_)", names(df), value = TRUE)) {
      add(col, NA_character_, value(col, i), role = "tie")
    }
  }
  if (!length(out)) return(review_candidate_table())
  result <- unique(do.call(rbind, out))
  result <- result[do.call(order, c(result, list(na.last = TRUE))), , drop = FALSE]
  rownames(result) <- NULL
  result
}

normalize_review_validation <- function(validation = NULL) {
  template <- data.frame(dtxsid = character(), outcome = character(), authority = character(),
    version = character(), reason = character(), stringsAsFactors = FALSE)
  if (is.null(validation) || !NROW(validation)) return(template)
  validation <- as.data.frame(validation, stringsAsFactors = FALSE)
  if (!all(c("dtxsid", "outcome") %in% names(validation))) {
    stop("Validation requires dtxsid and outcome columns.", call. = FALSE)
  }
  allowed <- c("valid", "rejected", "unavailable", "unknown", "invalid", "ambiguous", "conflicting", "stale")
  if (anyNA(validation$outcome) || any(!validation$outcome %in% allowed)) {
    stop("Unsupported validation outcome; unavailable is not rejected.", call. = FALSE)
  }
  for (col in setdiff(names(template), names(validation))) validation[[col]] <- NA_character_
  validation <- validation[, names(template), drop = FALSE]
  validation[] <- lapply(validation, review_evidence_text)
  validation <- unique(validation)
  validation <- validation[do.call(order, c(validation, list(na.last = TRUE))), , drop = FALSE]
  rownames(validation) <- NULL
  validation
}

#' Construct evidence for an explicit review
#' @param automated Pre-review lookup state.
#' @param final Final reviewed state, separately retained from automated evidence.
#' @param row_indices Explicit reviewed rows.
#' @param validation Structured validation data with dtxsid/outcome and optional authority/version/reason.
#' @param source_id_cols Source DTXSID metadata column names, never promoted to consensus.
#' @param scope_cols Source/content columns binding evidence to each source row.
#' @return Versioned snapshot for capture_review_decision().
#' @export
review_evidence_snapshot <- function(automated, final = automated,
                                     row_indices = seq_len(nrow(automated)), validation = NULL,
                                     source_id_cols = "source_dtxsid", scope_cols = character()) {
  selected <- function(df) {
    cols <- intersect(c("consensus_dtxsid", "consensus_status", "consensus_source", "consensus_name",
      "manual_preferredName", ".pinned", ".manual_entry", ".resolution_method", scope_cols), names(df))
    # Workbook readers infer logical for an entirely blank column. Known review
    # text fields retain their semantic type; an absent/empty manual label is the
    # same lookup evidence. Source/content types are preserved separately.
    values <- df[row_indices, cols, drop = FALSE]
    for (col in intersect(c("consensus_dtxsid", "consensus_status", "consensus_source",
      "consensus_name", "manual_preferredName", ".resolution_method"), names(values))) {
      values[[col]] <- as.character(values[[col]])
    }
    if ("manual_preferredName" %in% names(values) && all(is.na(review_evidence_text(values$manual_preferredName)))) {
      values$manual_preferredName <- NULL
    }
    review_evidence_canonical(values)
  }
  lookup_cols <- grep("^(dtxsid|preferredName|source_tier|match_tier|tied_dtxsids|resolver_lookup_status|pubchem_lookup_status|parent_lookup_status)($|_)",
    names(automated), value = TRUE)
  source_fields <- grep("^source_id_.*_(source_raw_id|source_candidate_id|validation_status|validation_reason|identity_status|authority|authority_version|preferred_name|casrn)$",
    names(automated), value = TRUE)
  lookup_cols <- unique(c(lookup_cols, source_fields))
  lookup_cols <- unique(c(lookup_cols, wqx_review_columns(automated),
    intersect(c("resolver_query", "resolver_query_details", "pubchem_query", "pubchem_query_details"), names(automated))))
  candidate_scope <- lapply(row_indices, function(i) {
    list(source_content = review_evidence_canonical(as.list(automated[i, intersect(scope_cols, names(automated)), drop = FALSE])),
         candidates = normalize_review_candidates(automated, i, source_id_cols))
  })
  candidate_keys <- vapply(candidate_scope, review_evidence_fingerprint, character(1))
  candidate_scope <- candidate_scope[order(candidate_keys)]
  validation <- normalize_review_validation(validation)
  observed <- review_observed_validation(automated, row_indices, source_id_cols)
  # Current observed source results take precedence over supplied same-authority
  # history. An outage must not be concealed by replaying a prior valid table.
  if (nrow(observed)) {
    key <- function(x) paste(x$dtxsid, x$authority, x$version, sep = "|")
    validation <- validation[!key(validation) %in% key(observed), , drop = FALSE]
    validation <- normalize_review_validation(rbind(validation, observed))
  }
  relevant <- unique(c(normalize_review_candidates(automated, row_indices, source_id_cols)$dtxsid,
    as.character(automated$consensus_dtxsid[row_indices]), as.character(final$consensus_dtxsid[row_indices])))
  validation <- validation[validation$dtxsid %in% relevant, , drop = FALSE]
  lookup <- automated[row_indices, unique(c(intersect(scope_cols, names(automated)), lookup_cols)), drop = FALSE]
  for (col in setdiff(lookup_cols, scope_cols)) lookup[[col]] <- as.character(lookup[[col]])
  for (col in intersect(c("resolver_query_details", "pubchem_query_details"), names(lookup))) {
    lookup[[col]] <- I(lapply(as.character(lookup[[col]]), review_query_details))
  }
  for (col in intersect(wqx_review_columns(automated,
    c("wqx_cas_dtxsid_candidates", "wqx_cas_candidate_names")), names(lookup))) {
    lookup[[col]] <- vapply(as.character(lookup[[col]]), function(value) {
      if (is.na(value)) return(NA_character_)
      paste(sort(unique(trimws(strsplit(value, "|", fixed = TRUE)[[1]]))), collapse = "|")
    }, character(1))
  }
  list(schema_version = 1L, automated = selected(automated), final = selected(final),
    candidate_scope = candidate_scope,
    candidates = normalize_review_candidates(automated, row_indices, source_id_cols),
    validation = normalize_review_validation(validation),
    lookup = review_evidence_canonical(lookup))
}

validate_review_evidence <- function(evidence) {
  if (is.null(evidence)) return(list(schema_version = 1L, decisions = list(), acknowledgments = list()))
  if (!is.list(evidence) || !identical(evidence$schema_version, 1L) ||
      !is.list(evidence$decisions) || !is.list(evidence$acknowledgments)) {
    stop("Unsupported review_decision_evidence schema.", call. = FALSE)
  }
  for (record in evidence$decisions) {
    if (!identical(record$schema_version, 1L) ||
        !identical(record$scope_fingerprint, review_evidence_fingerprint(record$scope)) ||
        !identical(record$evidence_fingerprint, review_evidence_fingerprint(record$current)) ||
        !identical(record$record_fingerprint, review_evidence_fingerprint(record[setdiff(names(record), "record_fingerprint")]))) {
      stop("Review decision evidence was modified or is invalid.", call. = FALSE)
    }
  }
  evidence
}

#' Capture evidence from an explicit review decision
#'
#' Append an immutable versioned decision to the portable
#' `review_decision_evidence` object. Call only when the reviewer explicitly
#' supplies the evidence they reviewed; replaying a flag does not capture it.
#' @param evidence Existing contract object, or NULL.
#' @param decision_id Stable nonempty identifier for the decision.
#' @param scope Explicit source/content scope from review_evidence_scope().
#' @param current Snapshot from review_evidence_snapshot().
#' @param disposition Structured basis: no_hit, rejected, deferred,
#'   scope_conflict, accepted, or other. Accepted records do not grant acceptance.
#' @param flag Reviewer flag, retained verbatim.
#' @param reason Reviewer reason, retained verbatim and never parsed.
#' @param revision Optional next revision; defaults to the next integer.
#' @param recorded_at Explicit audit time; does not participate in comparison.
#' @return Updated portable contract object; prior records are preserved.
#' @export
capture_review_decision <- function(evidence = NULL, decision_id, scope, current, disposition,
                                    flag = NA_character_, reason = NA_character_, revision = NULL,
                                    recorded_at = format(Sys.time(), tz = "UTC", usetz = TRUE)) {
  evidence <- validate_review_evidence(evidence)
  if (length(decision_id) != 1L || is.na(decision_id) || !nzchar(trimws(decision_id))) {
    stop("decision_id must be a nonempty scalar.", call. = FALSE)
  }
  if (!disposition %in% c("no_hit", "rejected", "deferred", "scope_conflict", "accepted", "other")) {
    stop("Unsupported structured disposition.", call. = FALSE)
  }
  if (!identical(scope$schema_version, 1L) || !length(scope$rows) || isTRUE(scope$ambiguous)) {
    stop("Explicit review requires an unambiguous source/content scope.", call. = FALSE)
  }
  if (!identical(current$schema_version, 1L)) stop("Unsupported evidence snapshot.", call. = FALSE)
  prior <- Filter(function(x) identical(x$decision_id, decision_id), evidence$decisions)
  next_revision <- if (length(prior)) max(vapply(prior, function(x) x$revision, integer(1))) + 1L else 1L
  if (is.null(revision)) revision <- next_revision
  if (length(revision) != 1L || is.na(revision) || revision != next_revision) {
    stop("Revision must append the next decision revision.", call. = FALSE)
  }
  record <- list(schema_version = 1L,
    decision_id = decision_id, revision = as.integer(revision), scope = scope,
    scope_fingerprint = review_evidence_fingerprint(scope), current = current,
    evidence_fingerprint = review_evidence_fingerprint(current), disposition = disposition,
    flag = flag, reason = reason, recorded_at = recorded_at)
  record$record_fingerprint <- review_evidence_fingerprint(record)
  evidence$decisions[[length(evidence$decisions) + 1L]] <- record
  evidence
}

#' Acknowledge current evidence for an existing decision revision
#'
#' This resolves only the matching reconciliation event. It does not modify
#' historical evidence, reviewer flags, or accepted identity.
#' @inheritParams capture_review_decision
#' @return Updated portable contract with a versioned acknowledgment.
#' @export
acknowledge_review_evidence <- function(evidence, decision_id, revision, scope, current,
                                        recorded_at = format(Sys.time(), tz = "UTC", usetz = TRUE)) {
  evidence <- validate_review_evidence(evidence)
  records <- Filter(function(x) identical(x$decision_id, decision_id) && x$revision == revision,
    evidence$decisions)
  if (length(records) != 1L || isTRUE(scope$ambiguous) ||
      !identical(records[[1]]$scope_fingerprint, review_evidence_fingerprint(scope))) {
    stop("Acknowledgment requires the exact decision revision and source/content scope.", call. = FALSE)
  }
  evidence$acknowledgments[[length(evidence$acknowledgments) + 1L]] <- list(schema_version = 1L,
    decision_id = decision_id, revision = as.integer(revision),
    scope_fingerprint = review_evidence_fingerprint(scope),
    evidence_fingerprint = review_evidence_fingerprint(current), recorded_at = recorded_at)
  evidence
}

compare_review_decision <- function(evidence, decision_id, scope, current) {
  evidence <- validate_review_evidence(evidence)
  records <- Filter(function(x) identical(x$decision_id, decision_id), evidence$decisions)
  if (!length(records)) return(list(status = "baseline_missing", decision = NULL, acknowledged = FALSE))
  record <- records[[which.max(vapply(records, function(x) x$revision, integer(1)))]]
  scope_key <- review_evidence_fingerprint(scope)
  current_key <- review_evidence_fingerprint(current)
  if (isTRUE(scope$ambiguous) || !identical(record$scope_fingerprint, scope_key)) {
    return(list(status = "scope_changed", decision = record, acknowledged = FALSE))
  }
  acknowledged <- any(vapply(evidence$acknowledgments, function(x) {
    identical(x$schema_version, 1L) && identical(x$decision_id, decision_id) && x$revision == record$revision &&
      identical(x$scope_fingerprint, scope_key) && identical(x$evidence_fingerprint, current_key)
  }, logical(1)))
  status <- if (identical(record$evidence_fingerprint, current_key)) "unchanged" else if (acknowledged) "acknowledged" else "changed"
  list(status = status, decision = record, acknowledged = acknowledged,
    current_fingerprint = current_key, scope_fingerprint = scope_key)
}


# Preserve available observed validation without guessing legacy service builds.
review_observed_validation <- function(df, rows, source_id_cols) {
  pieces <- list()
  stems <- sub("_validation_status$", "", grep("^source_id_.*_validation_status$", names(df), value = TRUE))
  field <- function(stem, suffix) {
    col <- paste0(stem, "_", suffix)
    if (col %in% names(df)) as.character(df[[col]][rows]) else rep(NA_character_, length(rows))
  }
  outcomes <- c(validated = "valid", not_found = "rejected", invalid_format = "invalid",
    returned_id_mismatch = "conflicting", ambiguous = "ambiguous", unavailable = "unavailable")
  for (stem in stems) {
    outcome <- unname(outcomes[field(stem, "validation_status")])
    outcome[is.na(outcome)] <- "unknown"
    pieces[[length(pieces) + 1L]] <- data.frame(dtxsid = field(stem, "source_candidate_id"),
      outcome = outcome, authority = field(stem, "authority"), version = field(stem, "authority_version"),
      reason = field(stem, "validation_reason"), stringsAsFactors = FALSE)
  }
  for (row in rows) {
    candidates <- normalize_review_candidates(df, row, source_id_cols)
    ids <- candidates$dtxsid[candidates$source == "resolver"]
    status <- if ("resolver_lookup_status" %in% names(df)) as.character(df$resolver_lookup_status[row]) else NA_character_
    if (!length(ids)) next
    outcome <- if (status %in% c("unverified", "error")) "unavailable" else
      if (status %in% "public") "valid" else "unknown"
    pieces[[length(pieces) + 1L]] <- data.frame(dtxsid = ids, outcome = outcome,
      authority = "Legacy resolver public-membership check", version = "unversioned",
      reason = paste("Observed resolver status:", status), stringsAsFactors = FALSE)
  }
  if (!length(pieces)) return(normalize_review_validation())
  out <- do.call(rbind, pieces)
  out <- out[!is.na(out$dtxsid) & grepl("^DTXSID[0-9]+$", out$dtxsid), , drop = FALSE]
  normalize_review_validation(out)
}
