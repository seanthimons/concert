unresolved_name_queries <- function(df, name_cols, original_data = NULL) {
  name_cols <- intersect(name_cols, names(df))
  if (!length(name_cols) || !nrow(df)) return(list(rows = integer(), names = character()))

  unresolved <- which(df$consensus_status %in% c("error", "unresolvable") &
                        (is.na(df$consensus_dtxsid) | df$consensus_dtxsid == ""))
  if (!length(unresolved)) return(list(rows = integer(), names = character()))

  names_to_search <- as.character(df[[name_cols[1]]][unresolved])
  if (!is.null(original_data) && name_cols[1] %in% names(original_data) &&
      "original_row_id" %in% names(df)) {
    ids <- suppressWarnings(as.integer(df$original_row_id[unresolved]))
    valid <- !is.na(ids) & ids >= 1L & ids <= nrow(original_data)
    if ("multi_analyte_part_count" %in% names(df)) {
      valid <- valid & (is.na(df$multi_analyte_part_count[unresolved]) |
                          df$multi_analyte_part_count[unresolved] <= 1L)
    }
    original_names <- as.character(original_data[[name_cols[1]]][ids[valid]])
    valid[valid] <- !is.na(original_names) & nzchar(trimws(original_names))
    names_to_search[valid] <- as.character(original_data[[name_cols[1]]][ids[valid]])
  }
  list(rows = unresolved, names = trimws(names_to_search))
}

# PubChem is a source of review candidates, not a source of accepted DTXSIDs.
add_pubchem_candidates <- function(df, name_cols, original_data = NULL,
                                   search_fn = ComptoxR::pubchem_search,
                                   synonyms_fn = ComptoxR::pubchem_synonyms) {
  df$pubchem_query <- NA_character_
  df$pubchem_cid_candidates <- NA_character_
  df$pubchem_dtxsid_candidates <- NA_character_
  df$pubchem_lookup_status <- NA_character_

  queries_info <- unresolved_name_queries(df, name_cols, original_data)
  unresolved <- queries_info$rows
  names_to_search <- queries_info$names
  if (!length(unresolved)) return(df)
  df$pubchem_query[unresolved] <- names_to_search
  queries <- unique(names_to_search[!is.na(names_to_search) & nzchar(names_to_search)])

  for (name in queries) {
    rows <- unresolved[!is.na(names_to_search) & names_to_search == name]
    hits <- tryCatch(search_fn(name, type = "name"), error = function(e) e)
    if (inherits(hits, "error")) {
      df$pubchem_lookup_status[rows] <- "error"
      next
    }

    cids <- unique(as.character(hits$cid))
    cids <- cids[!is.na(cids) & nzchar(cids)]
    if (!length(cids)) {
      df$pubchem_lookup_status[rows] <- "no_hit"
      next
    }

    df$pubchem_cid_candidates[rows] <- paste(cids, collapse = "; ")
    syns <- tryCatch(synonyms_fn(as.integer(cids), tidy = TRUE), error = function(e) e)
    if (inherits(syns, "error")) {
      df$pubchem_lookup_status[rows] <- "synonyms_error"
      next
    }
    matches <- grepl("^DTXSID[0-9]+$", syns$synonym)
    candidates <- unique(paste0(syns$cid[matches], ":", syns$synonym[matches]))
    if (length(candidates)) {
      df$pubchem_dtxsid_candidates[rows] <- paste(candidates, collapse = "; ")
    }
    df$pubchem_lookup_status[rows] <- "hit"
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
