# Candidate validation reports consume captured evidence; they never select IDs.

candidate_review_table <- function() {
  data.frame(row_id = integer(), name = character(), casrn = character(), flag = character(),
    reason = character(), decision_id = character(), revision = integer(), status = character(),
    actionable = logical(), change_reason = character(), candidates = character(),
    prior_candidates = character(), prior_validation_outcomes = character(), validation_outcomes = character(),
    evidence_fingerprint = character(), scope_fingerprint = character(), stringsAsFactors = FALSE)
}

candidate_review_text <- function(x) {
  if (!NROW(x)) return(NA_character_)
  paste(apply(x, 1L, function(row) paste(ifelse(is.na(row), "", row), collapse = "|")), collapse = ";")
}

# Outages are limitations, not new usable evidence. Retain definitive prior
# outcomes through a later outage rather than fabricating a rejection or reopening.
candidate_review_validation_basis <- function(x) {
  x <- normalize_review_validation(x)
  x[x$outcome %in% c("valid", "rejected", "invalid", "ambiguous", "conflicting", "stale"), , drop = FALSE]
}

candidate_review_delta <- function(prior, current) {
  if (!identical(review_evidence_fingerprint(prior$candidates),
                 review_evidence_fingerprint(current$candidates))) return("candidates_changed")
  old <- candidate_review_validation_basis(prior$validation)
  new <- candidate_review_validation_basis(current$validation)
  if (!NROW(new)) return("unchanged")
  # Only supplied meaningful current outcomes replace earlier evidence for the ID.
  old <- old[old$dtxsid %in% new$dtxsid, , drop = FALSE]
  if (!identical(review_evidence_fingerprint(old), review_evidence_fingerprint(new))) {
    return("validation_changed")
  }
  "unchanged"
}

#' Report candidate validation work without changing identity or flags
#'
#' Missing historical evidence is informational. Only changed evidence from a
#' captured no-hit, rejected, or deferred decision opens candidate validation.
#' Unchanged dispositions and repeated unavailable checks do not reopen work.
#' @param automated Pre-review lookup data.
#' @param final Final reviewed data with preserved flags and identities.
#' @param row_flags Optional content-keyed reviewer decisions.
#' @param evidence Portable review_decision_evidence object.
#' @param name_col,cas_col Source name and optional CAS column names.
#' @param scope_data Immutable source/content data, aligned with automated rows.
#' @param scope_cols Source/content and lineage columns defining review scope.
#' @param validation Optional structured candidate validation outcomes.
#' @param source_id_cols Source ID metadata columns, never consensus votes.
#' @return Stable data frame; actionable rows require candidate validation, never acceptance.
#' @export
build_candidate_review <- function(automated, final = automated, row_flags = NULL,
                                   evidence = NULL, name_col, cas_col = NA_character_,
                                   scope_data = automated,
                                   scope_cols = c(name_col, cas_col), validation = NULL,
                                   source_id_cols = "source_dtxsid") {
  evidence <- validate_review_evidence(evidence)
  out <- candidate_review_table()
  scope_cols <- unique(scope_cols[!is.na(scope_cols) & nzchar(scope_cols)])
  if (!name_col %in% names(automated) || NROW(final) != NROW(automated) ||
      NROW(scope_data) != NROW(automated)) stop("Candidate review requires aligned source and final rows.", call. = FALSE)
  get <- function(df, col, i) if (length(col) == 1L && !is.na(col) && col %in% names(df)) {
    review_evidence_text(df[[col]][i])
  } else NA_character_
  flagged <- if ("row_flag" %in% names(final)) !is.na(review_evidence_text(final$row_flag)) else rep(FALSE, nrow(final))
  selected <- if ("consensus_dtxsid" %in% names(final)) !is.na(review_evidence_text(final$consensus_dtxsid)) else rep(FALSE, nrow(final))
  indices <- which(flagged & !selected)
  if (!length(indices)) return(out)
  results <- vector("list", length(indices))
  for (j in seq_along(indices)) {
    i <- indices[j]
    name <- get(automated, name_col, i)
    cas <- get(automated, cas_col, i)
    flag <- get(final, "row_flag", i)
    reason <- get(final, "row_flag_reason", i)
    key <- review_decision_key(name, cas)
    matched_rows <- i
    missing_cas_scope <- FALSE
    if (!is.null(row_flags) && NROW(row_flags)) {
      flags <- as.data.frame(row_flags, stringsAsFactors = FALSE)
      if (!all(c("name", "flag") %in% names(flags))) stop("row_flags requires name and flag.", call. = FALSE)
      candidates <- which(!is.na(flags$name) & !is.na(name) & as.character(flags$name) == name)
      if (length(candidates)) {
        for (k in rev(candidates)) {
          target_cas <- get(flags, "casrn", k)
          if (!is.na(target_cas) && !is.na(cas) && target_cas != cas) next
          flag <- get(flags, "flag", k)
          reason <- get(flags, "reason", k)
          explicit_key <- get(flags, "decision_id", k)
          key <- if (is.na(explicit_key)) review_decision_key(name, target_cas) else explicit_key
          missing_cas_scope <- !is.na(target_cas) && (is.na(cas_col) || !cas_col %in% names(automated))
          matched_rows <- which(content_row_mask(automated, name_col, cas_col, name, target_cas))
          break
        }
      }
    }
    scope <- review_evidence_scope(scope_data, matched_rows, scope_cols)
    # Use the same snapshot operation as the reconciliation consumer. Bind each
    # candidate row to content when the strengthened contract is available.
    args <- list(automated = automated, final = final, row_indices = matched_rows,
                 validation = validation, source_id_cols = source_id_cols)
    if ("scope_cols" %in% names(formals(review_evidence_snapshot))) args$scope_cols <- scope_cols
    current <- do.call(review_evidence_snapshot, args)
    comparison <- compare_review_decision(evidence, key, scope, current)
    prior <- comparison$decision
    delta <- if (is.null(prior)) "baseline_missing" else candidate_review_delta(prior$current, current)
    if (comparison$status == "scope_changed" || missing_cas_scope) delta <- "scope_changed"
    disposition <- if (is.null(prior)) NA_character_ else prior$disposition
    row_candidates <- normalize_review_candidates(automated, i, source_id_cols)
    usable <- row_candidates$role != "parent_suggestion"
    has_candidates <- any(usable)
    actionable <- has_candidates && !is.na(flag) && flag != "BAD" && !is.null(prior) &&
      disposition %in% c("no_hit", "rejected", "deferred") &&
      delta != "unchanged" && comparison$status != "acknowledged"
    status <- if (is.null(prior)) "baseline_missing" else if (comparison$status == "acknowledged") {
      "acknowledged"
    } else if (actionable) "candidate_validation" else if (!has_candidates) "no_candidates" else "already_dispositioned"
    results[[j]] <- data.frame(row_id = as.integer(i), name = name, casrn = cas,
      flag = flag, reason = reason, decision_id = key,
      revision = if (is.null(prior)) NA_integer_ else prior$revision, status = status,
      actionable = isTRUE(actionable), change_reason = delta,
      candidates = candidate_review_text(row_candidates),
      prior_candidates = if (is.null(prior)) NA_character_ else candidate_review_text(prior$current$candidates),
      prior_validation_outcomes = if (is.null(prior)) NA_character_ else candidate_review_text(prior$current$validation),
      validation_outcomes = candidate_review_text(current$validation),
      evidence_fingerprint = review_evidence_fingerprint(current),
      scope_fingerprint = review_evidence_fingerprint(scope), stringsAsFactors = FALSE)
  }
  do.call(rbind, results)
}

#' Explicitly validate saved candidate IDs with an injected authority
#'
#' This operation does not rerun name searches or download DSSTox. The service
#' must return structured outcomes, including exact requested DTXSID. Errors and
#' absent results mean unavailable, whereas an explicit rejected result preserves
#' definitive rejection. Validation establishes membership, never correspondence.
#' @param candidates Normalized candidate data frame, or character IDs.
#' @param validator Function accepting one DTXSID and returning a data frame with
#'   dtxsid and outcome columns (valid/rejected/unavailable/unknown/invalid/ambiguous/conflicting/stale).
#' @param authority,version Nonempty authority and build/version identifiers.
#' @param cache Existing returned versioned cache, or NULL.
#' @param refresh Explicitly refresh even cached definitive results.
#' @return List with normalized validation and versioned cache. Unavailable results
#'   are not cached as definitive outcomes and may be retried explicitly.
#' @export
validate_review_candidates <- function(candidates, validator, authority, version,
                                       cache = NULL, refresh = FALSE) {
  if (!is.function(validator)) stop("An explicit candidate validator is required.", call. = FALSE)
  for (value in list(authority, version)) {
    if (length(value) != 1L || is.na(value) || !nzchar(trimws(value))) {
      stop("Validator authority and version must be nonempty scalars.", call. = FALSE)
    }
  }
  if (is.null(cache)) cache <- list(schema_version = 1L, entries = list())
  if (!is.list(cache) || !identical(cache$schema_version, 1L) || !is.list(cache$entries)) {
    stop("Unsupported candidate validation cache schema.", call. = FALSE)
  }
  ids <- if (is.data.frame(candidates)) candidates$dtxsid else candidates
  ids <- sort(unique(review_evidence_text(ids)))
  ids <- ids[!is.na(ids)]
  results <- vector("list", length(ids))
  for (i in seq_along(ids)) {
    id <- ids[i]
    key <- review_evidence_fingerprint(list(id = id, authority = authority, version = version))
    if (!grepl("^DTXSID[0-9]+$", id)) {
      outcome <- data.frame(dtxsid = id, outcome = "invalid", reason = "Malformed DTXSID")
    } else if (!isTRUE(refresh) && !is.null(cache$entries[[key]])) {
      outcome <- normalize_review_validation(cache$entries[[key]])
      if (NROW(outcome) != 1L || outcome$dtxsid != id || outcome$authority != authority || outcome$version != version) {
        stop("Candidate validation cache entry does not match its key.", call. = FALSE)
      }
    } else {
      outcome <- tryCatch(validator(id), error = function(e) {
        data.frame(dtxsid = id, outcome = "unavailable", reason = conditionMessage(e))
      })
      if (is.null(outcome) || !NROW(outcome)) {
        outcome <- data.frame(dtxsid = id, outcome = "unavailable", reason = "Validator returned no structured result")
      } else {
        outcome <- normalize_review_validation(outcome)
        if (NROW(outcome) != 1L || is.na(outcome$dtxsid) || outcome$dtxsid != id) {
          outcome <- data.frame(dtxsid = id, outcome = "ambiguous", reason = "Authority result did not uniquely match requested ID")
        }
      }
    }
    outcome$authority <- authority
    outcome$version <- version
    outcome <- normalize_review_validation(outcome)
    results[[i]] <- outcome
    if (outcome$outcome %in% c("valid", "rejected", "invalid", "ambiguous", "conflicting")) {
      cache$entries[[key]] <- outcome
    }
  }
  list(validation = normalize_review_validation(if (length(results)) do.call(rbind, results) else NULL), cache = cache)
}
