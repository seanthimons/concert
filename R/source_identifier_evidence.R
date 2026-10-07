# Source identifiers are candidates for review, never independent lookup votes.
normalize_source_dtxsid <- function(x) toupper(trimws(as.character(x)))

validate_source_identifier_config <- function(df, tags, ignored_identifier_cols = character()) {
  missing <- setdiff(c(names(tags), ignored_identifier_cols), names(df))
  if (length(missing)) stop("Unknown source identifier configuration columns: ", paste(missing, collapse = ", "))
  overlap <- intersect(names(tags)[unlist(tags) %in% "DTXSID"], ignored_identifier_cols)
  if (length(overlap)) stop("Source DTXSID columns cannot also be ignored: ", paste(overlap, collapse = ", "))
  invisible(TRUE)
}

#' Diagnose retained identifier columns without a source evidence role
#' @param df Retained input rows.
#' @param tags Named column role list.
#' @param ignored_identifier_cols Columns deliberately retained as metadata.
#' @return Structured column diagnostics. No values or roles are changed.
#' @export
unused_source_identifier_diagnostics <- function(df, tags = list(), ignored_identifier_cols = character()) {
  validate_source_identifier_config(df, tags, ignored_identifier_cols)
  configured <- names(tags)[unlist(tags) %in% "DTXSID"]
  cols <- setdiff(names(df), c(configured, ignored_identifier_cols))
  rows <- lapply(cols, function(col) {
    values <- normalize_source_dtxsid(df[[col]])
    nonempty <- !is.na(values) & nzchar(values)
    valid <- nonempty & grepl("^DTXSID[0-9]+$", values)
    header <- grepl("(^|_)dtxsid($|_)", tolower(col))
    if (!any(nonempty) || (!header && !any(valid))) return(NULL)
    tibble::tibble(column = col, nonempty_count = sum(nonempty), valid_format_count = sum(valid),
      sample = paste(utils::head(unique(values[nonempty]), 3L), collapse = "; "),
      diagnostic = "unused_source_identifier",
      remediation = "Assign DTXSID role or add column to ignored_identifier_cols")
  })
  dplyr::bind_rows(tibble::tibble(column = character(), nonempty_count = integer(),
    valid_format_count = integer(), sample = character(), diagnostic = character(), remediation = character()), rows)
}

source_identifier_lookup <- function(ids) {
  ComptoxR::ct_chemical_detail_search_bulk(ids, projection = "chemicaldetailall")
}

#' Validate source DTXSID membership without accepting source identity
#' @param df Rows with source identifier columns.
#' @param tags Named roles, including explicit DTXSID roles.
#' @param lookup_fn Injectable batched authoritative details lookup.
#' @param checked_at Validation timestamp; injectable for deterministic tests.
#' @return Long evidence table, retaining original row and column values.
#' @export
source_identifier_evidence <- function(df, tags, lookup_fn = source_identifier_lookup,
                                      checked_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")) {
  validate_source_identifier_config(df, tags)
  cols <- names(tags)[unlist(tags) %in% "DTXSID"]
  evidence <- dplyr::bind_rows(tibble::tibble(row_index = integer(), source_column = character(),
    source_raw_id = character(), source_candidate_id = character()), lapply(cols, function(col) {
    tibble::tibble(row_index = seq_len(nrow(df)), source_column = col,
      source_raw_id = as.character(df[[col]]), source_candidate_id = normalize_source_dtxsid(df[[col]]))
  }))
  evidence$validation_status <- "invalid_format"
  evidence$validation_reason <- "Missing or malformed DTXSID"
  evidence$preferred_name <- NA_character_
  evidence$casrn <- NA_character_
  evidence$authority <- "EPA CompTox chemical/detail/search/by-dtxsid (chemicaldetailall)"
  evidence$checked_at <- checked_at
  evidence$identity_status <- "identity_unconfirmed"
  valid <- !is.na(evidence$source_candidate_id) & grepl("^DTXSID[0-9]+$", evidence$source_candidate_id)
  ids <- unique(evidence$source_candidate_id[valid])
  if (!length(ids)) return(evidence)
  response <- tryCatch(lookup_fn(ids), error = function(e) e)
  unavailable <- inherits(response, "error") || !is.data.frame(response) || !"dtxsid" %in% names(response)
  if (unavailable) {
    evidence$validation_status[valid] <- "unavailable"
    evidence$validation_reason[valid] <- if (inherits(response, "error")) conditionMessage(response) else "Missing authoritative response schema"
    return(evidence)
  }
  returned <- normalize_source_dtxsid(response$dtxsid)
  for (id in ids) {
    rows <- which(valid & evidence$source_candidate_id == id)
    hit <- which(!is.na(returned) & returned == id)
    status <- if (!length(hit)) {
      if (any(!is.na(returned) & !returned %in% ids)) "returned_id_mismatch" else "not_found"
    } else if (length(hit) > 1L) "ambiguous" else "validated"
    evidence$validation_status[rows] <- status
    evidence$validation_reason[rows] <- switch(status, validated = "Exact unique authoritative ID; source correspondence requires review",
      ambiguous = "Multiple authoritative records returned", returned_id_mismatch = "Returned ID does not match requested ID",
      not_found = "No authoritative record returned")
    if (status == "validated") {
      if ("preferredName" %in% names(response)) evidence$preferred_name[rows] <- as.character(response$preferredName[hit])
      if ("casrn" %in% names(response)) evidence$casrn[rows] <- as.character(response$casrn[hit])
    }
  }
  evidence
}

attach_source_identifier_evidence <- function(df, tags, lookup_fn = source_identifier_lookup) {
  evidence <- source_identifier_evidence(df, tags, lookup_fn)
  direct <- find_dtxsid_cols(df)
  multi <- is_multi_analyte_review_row(df)
  for (col in unique(evidence$source_column)) {
    e <- evidence[evidence$source_column == col, , drop = FALSE]
    for (i in seq_len(nrow(e))) {
      row <- e$row_index[i]
      ids <- unlist(df[row, direct, drop = FALSE], use.names = FALSE)
      ids <- ids[!is.na(ids) & nzchar(ids)]
      conflicting <- length(ids) && any(ids != e$source_candidate_id[i])
      wqx <- find_wqx_evidence_only_cols(df, direct, row)
      wqx_names <- vapply(wqx, function(x) as.character(df[[source_field_column(x, "preferredName")]][row]), character(1))
      if (length(wqx_names) && !is.na(e$preferred_name[i])) {
        # Name inequality can be a synonym, not a definitive identity rejection.
        if (any(normalize_identity_evidence_name(wqx_names) != normalize_identity_evidence_name(e$preferred_name[i]), na.rm = TRUE)) {
          e$identity_status[i] <- "scope_review"
        }
      }
      if (isTRUE(conflicting)) e$identity_status[i] <- "identity_conflict"
      if (multi[row] || ("multi_analyte_part_count" %in% names(df) &&
          !is.na(df$multi_analyte_part_count[row]) && df$multi_analyte_part_count[row] > 1L)) {
        e$identity_status[i] <- "scope_review"
      }
    }
    evidence$identity_status[evidence$source_column == col] <- e$identity_status
    for (field in setdiff(names(e), c("row_index", "source_column"))) {
      df[[paste0("source_id_", col, "_", field)]] <- e[[field]][match(seq_len(nrow(df)), e$row_index)]
    }
  }
  list(data = df, evidence = evidence)
}
