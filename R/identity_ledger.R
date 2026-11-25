# Identity decision ledger: JSON Lines, append-only, latest line per selector wins.

# Fields that live only in the ledger; replay scripts and row records leave them out.
LEDGER_FIELDS <- c("evidence", "recorded_by", "recorded_at", "replaces", "note")

strip_ledger_fields <- function(decisions) {
  if (!length(decisions)) return(decisions)
  lapply(decisions, function(x) x[setdiff(names(x), LEDGER_FIELDS)])
}

ledger_json <- function(x) {
  as.character(jsonlite::toJSON(x, auto_unbox = TRUE, na = "null", null = "null", digits = NA))
}

ledger_key <- function(selector) ledger_json(selector[order(names(selector))])

ledger_now <- function() format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

read_identity_ledger <- function(path) {
  if (!file.exists(path)) return(list())
  lines <- readLines(path, encoding = "UTF-8", warn = FALSE)
  lines <- lines[nzchar(trimws(lines))]
  decisions <- lapply(seq_along(lines), function(n) {
    d <- tryCatch(jsonlite::fromJSON(lines[n], simplifyVector = TRUE), error = function(e) NULL)
    if (!is.list(d) || !is.list(d$selector)) {
      stop(sprintf("%s line %d is not a decision record.", basename(path), n), call. = FALSE)
    }
    # JSON null is a missing value here, never an absent field.
    d$selector <- lapply(d$selector, function(v) if (is.null(v)) NA else v)
    for (key in intersect(c("gui_review_input", "gui_replay_input"), names(d))) {
      d[[key]] <- Map(function(v, col) if (!is.null(v)) v else if (col == ".pinned") NA else NA_character_,
        d[[key]], names(d[[key]]))
    }
    d
  })
  keys <- vapply(decisions, function(d) ledger_key(d$selector), character(1))
  decisions <- decisions[!duplicated(keys, fromLast = TRUE)]
  decisions[!vapply(decisions, function(d) identical(d$action, "withdraw"), logical(1))]
}

append_identity_ledger <- function(path, decisions) {
  lines <- vapply(decisions, ledger_json, character(1))
  con <- file(path, open = "ab")
  on.exit(close(con))
  writeLines(enc2utf8(lines), con, useBytes = TRUE)
  invisible(path)
}

# What a recorded fingerprint depends on besides the ledger itself.
ledger_run_stamp <- function(decisions_path, input_path) {
  c(decisions = digest::digest(file = decisions_path, algo = "sha256"),
    input = digest::digest(file = input_path, algo = "sha256"),
    concert = as.character(utils::packageVersion("concert")))
}

ledger_context <- function(decisions_path, out_dir, need_run = TRUE) {
  d <- read_decisions(decisions_path)
  if (is.null(d$identity_ledger_path)) {
    stop("decisions.R must point at a ledger file: identity_decisions <- \"identity_decisions.jsonl\". ",
      "Convert existing list-form decisions with migrate_identity_ledger().", call. = FALSE)
  }
  if (!need_run) return(list(ledger = d$identity_ledger_path))
  state_path <- file.path(out_dir, "cache", "identity_state.rds")
  run <- if (file.exists(state_path)) readRDS(state_path)
  if (is.null(run) || !identical(run$stamp, ledger_run_stamp(decisions_path, d$input_path))) {
    stop("No current run to record against: decisions.R, the input file or concert changed since the last ",
      "complete run. Run curate_iterate() first.", call. = FALSE)
  }
  list(ledger = d$identity_ledger_path, run = run)
}

ledger_who <- function(recorded_by) {
  if (!is.character(recorded_by) || length(recorded_by) != 1L || is.na(recorded_by) || !nzchar(trimws(recorded_by))) {
    stop("recorded_by is required: say who made the decision (for example \"owner\").", call. = FALSE)
  }
  trimws(recorded_by)
}

#' Record identity decisions in the ledger
#'
#' Appends one line per decision to the JSON Lines ledger that `decisions.R`
#' names (`identity_decisions <- "identity_decisions.jsonl"`). Each decision is
#' fingerprinted against the last [curate_iterate()] run, checked with
#' [apply_identity_decisions()], and written with a snapshot of the evidence it
#' was made on. Nothing is written unless every decision passes. Run
#' [curate_iterate()] again to apply them.
#'
#' The ledger is append-only. The latest line for a source row wins, so record
#' a row again to change its decision, or with `action = "withdraw"` to remove
#' it.
#'
#' @param decisions_path Path to `decisions.R`.
#' @param decisions Data frame, one decision per row. `row_index` is the row
#'   as shown in `pending.csv`; add `name` to pick one part of a split row.
#'   `action` is `accept`, `retain_unresolved` or `withdraw`. `scope`,
#'   `conflict`, `reason` and `evidence_reference` are as in
#'   [apply_identity_decisions()]; `accept` also needs `selected_dtxsid` and
#'   `correspondence = TRUE`. `withdraw` needs only `row_index` and `reason`.
#'   A batch of only withdrawals needs no completed run, so it can remove a
#'   decision that stops [curate_iterate()].
#' @param recorded_by Who made the decision, for example `"owner"`.
#' @param out_dir Output directory of the run. Defaults to the decisions file
#'   directory.
#' @return Invisibly, the ledger path.
#' @export
record_identity_decision <- function(decisions_path, decisions, recorded_by, out_dir = dirname(decisions_path)) {
  recorded_by <- ledger_who(recorded_by)
  decisions <- tibble::as_tibble(decisions)
  if (!nrow(decisions) || !all(c("row_index", "action", "reason") %in% names(decisions))) {
    stop("decisions needs at least one row with row_index, action and reason.", call. = FALSE)
  }
  # A withdrawal works off the ledger alone, so it can remove a line that stops the run.
  ctx <- ledger_context(decisions_path, out_dir, need_run = !all(decisions$action %in% "withdraw"))
  live <- read_identity_ledger(ctx$ledger)
  df <- if (!is.null(ctx$run)) init_resolution_state(ctx$run$resolution_state)
  name_col <- if (!is.null(ctx$run)) first_tag_col(ctx$run$tags, "Name") else NA_character_
  field <- function(col, k) {
    value <- if (col %in% names(decisions)) as.character(decisions[[col]][k]) else NA_character_
    if (is.na(value) || !nzchar(trimws(value))) NA_character_ else trimws(value)
  }
  now <- ledger_now()
  new <- lapply(seq_len(nrow(decisions)), function(k) {
    if (identical(field("action", k), "withdraw")) {
      hit <- Filter(function(d) {
        as.integer(d$selector$original_row_id) %in% suppressWarnings(as.integer(field("row_index", k))) &&
          (is.na(field("name", k)) || field("name", k) %in% unlist(d$selector))
      }, live)
      if (length(hit) != 1L) {
        stop(sprintf("Nothing to withdraw: row_index %s has %d recorded decisions. For a split row, add `name`.",
          field("row_index", k), length(hit)), call. = FALSE)
      }
      if (is.na(field("reason", k))) stop("Withdrawing a decision requires a reason.", call. = FALSE)
      return(list(selector = hit[[1]]$selector, action = "withdraw", reason = field("reason", k),
        recorded_by = recorded_by, recorded_at = now))
    }
    rows <- which(df$original_row_id %in% suppressWarnings(as.integer(field("row_index", k))))
    if (!is.na(field("name", k)) && !is.na(name_col)) rows <- rows[df[[name_col]][rows] %in% field("name", k)]
    if (length(rows) != 1L) {
      stop(sprintf("row_index %s matches %d rows. For a split row, add `name` as shown in pending.csv.",
        field("row_index", k), length(rows)), call. = FALSE)
    }
    decision <- list(selector = gui_identity_selector(df, rows, ctx$run$tags), action = field("action", k),
      scope = field("scope", k), conflict = field("conflict", k), selected_dtxsid = field("selected_dtxsid", k),
      correspondence = as.logical(field("correspondence", k)), reason = field("reason", k),
      evidence_reference = field("evidence_reference", k),
      evidence_fingerprint = identity_evidence_fingerprint(df, rows),
      evidence = identity_evidence_snapshot(df, rows), recorded_by = recorded_by, recorded_at = now)
    decision[!vapply(decision, function(v) length(v) == 1L && is.na(v), logical(1))]
  })
  keys <- vapply(new, function(d) ledger_key(d$selector), character(1))
  if (anyDuplicated(keys)) stop("Two decisions name the same source row.", call. = FALSE)
  withdraw <- vapply(new, function(d) identical(d$action, "withdraw"), logical(1))
  # Dry run: every hard stop the next iteration would raise fires here, before anything is written.
  if (any(!withdraw)) apply_identity_decisions(list(resolution_state = df), new[!withdraw])
  append_identity_ledger(ctx$ledger, new)
  message(sprintf("[ledger] recorded %d decision(s) in %s. Run curate_iterate() to apply.", length(new), ctx$ledger))
  invisible(ctx$ledger)
}

#' Re-confirm identity decisions whose evidence changed
#'
#' For the decisions the last [curate_iterate()] run reported as
#' `identity_drift`, appends a ledger line that keeps the decision and takes
#' the current evidence fingerprint and snapshot. Use it only after reviewing
#' each row against its current evidence. Stops, writing nothing, when the
#' number of drifted decisions is not `expected` or a named row has not
#' drifted.
#'
#' @inheritParams record_identity_decision
#' @param note Why the decisions still hold on the changed evidence.
#' @param expected Number of decisions the caller means to re-confirm.
#' @param rows Optional `row_index` values to restrict to. Default: every
#'   drifted decision.
#' @return Invisibly, the ledger path.
#' @export
reconfirm_identity_decisions <- function(decisions_path, note, expected, recorded_by, rows = NULL,
                                         out_dir = dirname(decisions_path)) {
  recorded_by <- ledger_who(recorded_by)
  if (!is.character(note) || length(note) != 1L || is.na(note) || !nzchar(trimws(note))) {
    stop("A note is required: say why the decisions still hold.", call. = FALSE)
  }
  if (!is.numeric(expected) || length(expected) != 1L || is.na(expected)) {
    stop("expected must be the number of decisions you mean to re-confirm.", call. = FALSE)
  }
  ctx <- ledger_context(decisions_path, out_dir)
  drift <- ctx$run$drift
  if (!NROW(drift)) drift <- tibble::tibble(original_row_id = integer(), decision = list())
  if (!is.null(rows)) {
    missing <- setdiff(rows, drift$original_row_id)
    if (length(missing)) stop("Not drifted: row_index ", paste(missing, collapse = ", "), ".", call. = FALSE)
    drift <- drift[drift$original_row_id %in% rows, , drop = FALSE]
  }
  # A second call on the same run finds its own lines and has nothing left to do.
  live <- read_identity_ledger(ctx$ledger)
  names(live) <- vapply(live, function(d) ledger_key(d$selector), character(1))
  stale <- vapply(seq_len(nrow(drift)), function(k) {
    identical(live[[ledger_key(drift$decision[[k]]$selector)]]$evidence_fingerprint, drift$recorded_fingerprint[k])
  }, logical(1))
  drift <- drift[stale, , drop = FALSE]
  if (nrow(drift) != expected) {
    stop(sprintf("%d drifted decision(s) to re-confirm, expected %s. Nothing recorded.", nrow(drift), expected),
      call. = FALSE)
  }
  now <- ledger_now()
  new <- lapply(seq_len(nrow(drift)), function(k) {
    decision <- drift$decision[[k]]
    decision$evidence_fingerprint <- drift$current_fingerprint[k]
    decision$evidence <- drift$current_evidence[[k]]
    decision$replaces <- drift$recorded_fingerprint[k]
    decision$note <- trimws(note)
    decision$recorded_by <- recorded_by
    decision$recorded_at <- now
    decision
  })
  # Dry run, as in record_identity_decision(): a decision that no longer validates is not re-confirmed.
  if (length(new)) apply_identity_decisions(list(resolution_state = init_resolution_state(ctx$run$resolution_state)), new)
  append_identity_ledger(ctx$ledger, new)
  message(sprintf("[ledger] re-confirmed %d decision(s) in %s. Run curate_iterate() to apply.", length(new), ctx$ledger))
  invisible(ctx$ledger)
}

#' Move list-form identity decisions into a ledger file
#'
#' One-time conversion for a `decisions.R` that defines `identity_decisions`
#' as an R list. Writes each decision as one line of a JSON Lines ledger next
#' to `decisions.R`. It does not edit `decisions.R`: afterwards, replace the
#' list there with `identity_decisions <- "identity_decisions.jsonl"`.
#'
#' @inheritParams record_identity_decision
#' @param ledger Ledger file name, relative to the decisions file directory.
#' @return Invisibly, the ledger path.
#' @export
migrate_identity_ledger <- function(decisions_path, ledger = "identity_decisions.jsonl") {
  d <- read_decisions(decisions_path)
  path <- file.path(dirname(decisions_path), ledger)
  if (!is.null(d$identity_ledger_path) || file.exists(path)) {
    stop("A ledger already exists; nothing to migrate.", call. = FALSE)
  }
  if (!length(d$identity_decisions)) stop("decisions.R has no list-form identity_decisions to migrate.", call. = FALSE)
  now <- ledger_now()
  append_identity_ledger(path, lapply(d$identity_decisions, function(x) {
    c(x, list(recorded_by = "migrated", recorded_at = now))
  }))
  message(sprintf("[ledger] wrote %d decision(s) to %s. Now set identity_decisions <- \"%s\" in decisions.R.",
    length(d$identity_decisions), path, ledger))
  invisible(path)
}
