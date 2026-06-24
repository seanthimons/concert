# media_harmonizer.R
# Environmental media harmonization engine: string normalization, exact/parent-walk
# lookup against the generated CONCERT media cache, canonical resolution with
# category routing.
#
# Public API: harmonize_media()
# Internal: get_media_table(), walk_parent()

#' Load the generated CONCERT media vocabulary cache
#'
#' Reads amos_media.rds from the package reference cache. If the cache is absent
#' in a source checkout, falls back to building it from reviewable media source
#' tables so callers can degrade gracefully.
#'
#' @return Tibble with columns term, canonical_term, envo_id, parent,
#'   media_category, source, fetch_timestamp, assertion_mode, confidence,
#'   active; or NULL.
#' @keywords internal
find_local_media_table <- function() {
  cwd <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  parts <- strsplit(cwd, "/", fixed = TRUE)[[1]]
  if (length(parts) == 0L) {
    return("")
  }

  for (i in seq(length(parts), 1L)) {
    candidate_root <- paste(parts[seq_len(i)], collapse = "/")
    if (!nzchar(candidate_root)) {
      candidate_root <- "/"
    }
    candidate <- file.path(candidate_root, "inst", "extdata", "reference_cache", "amos_media.rds")
    if (file.exists(candidate)) {
      return(candidate)
    }
  }

  ""
}

get_media_table <- function() {
  package_path <- system.file("extdata/reference_cache/amos_media.rds", package = "concert")
  local_path <- find_local_media_table()
  path <- if (nzchar(package_path) && file.exists(package_path)) {
    package_path
  } else if (file.exists(local_path)) {
    local_path
  } else {
    ""
  }

  if (nzchar(path)) {
    readRDS(path)
  } else {
    source_tables <- tryCatch(load_media_source_tables(), error = function(e) NULL)
    if (is.null(source_tables)) {
      NULL
    } else {
      build_media_runtime_map(source_tables, fetch_timestamp = NA_character_)
    }
  }
}

find_local_media_source_dir <- function() {
  cwd <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  parts <- strsplit(cwd, "/", fixed = TRUE)[[1]]
  if (length(parts) == 0L) {
    return("")
  }

  for (i in seq(length(parts), 1L)) {
    candidate_root <- paste(parts[seq_len(i)], collapse = "/")
    if (!nzchar(candidate_root)) {
      candidate_root <- "/"
    }
    candidate <- file.path(candidate_root, "inst", "extdata", "reference_sources")
    if (
      file.exists(file.path(candidate, "media_canonical.csv")) &&
        file.exists(file.path(candidate, "media_aliases.csv")) &&
        file.exists(file.path(candidate, "media_ontology_nodes.csv"))
    ) {
      return(candidate)
    }
  }

  ""
}

resolve_media_source_dir <- function(source_dir = NULL) {
  if (!is.null(source_dir) && nzchar(source_dir)) {
    return(source_dir)
  }

  package_dir <- system.file("extdata/reference_sources", package = "concert")
  if (nzchar(package_dir) && dir.exists(package_dir)) {
    return(package_dir)
  }

  local_dir <- find_local_media_source_dir()
  if (nzchar(local_dir)) {
    return(local_dir)
  }

  ""
}

normalize_media_logical <- function(x) {
  raw <- trimws(tolower(as.character(x)))
  raw %in% c("true", "t", "1", "yes", "y")
}

normalize_media_character <- function(x) {
  out <- trimws(as.character(x))
  out[is.na(out) | !nzchar(out)] <- NA_character_
  out
}

normalize_media_lower_character <- function(x) {
  out <- normalize_media_character(x)
  tolower(out)
}

valid_media_routing_categories <- function() {
  c("aqueous", "air", "solid")
}

read_media_source_csv <- function(path, required_cols) {
  if (!file.exists(path)) {
    stop(sprintf("Media source table not found: %s", path), call. = FALSE)
  }

  tbl <- readr::read_csv(
    path,
    col_types = readr::cols(.default = readr::col_character()),
    show_col_types = FALSE
  )

  missing_cols <- setdiff(required_cols, names(tbl))
  if (length(missing_cols) > 0L) {
    stop(
      sprintf(
        "Media source table %s is missing required column(s): %s",
        basename(path),
        paste(missing_cols, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  tibble::as_tibble(tbl)
}

validate_media_ontology_nodes <- function(ontology) {
  missing_node_id <- is.na(ontology$node_id) | !nzchar(ontology$node_id)
  if (any(missing_node_id)) {
    stop("Media ontology nodes require node_id for every row.", call. = FALSE)
  }

  duplicate_nodes <- unique(ontology$node_id[duplicated(ontology$node_id)])
  if (length(duplicate_nodes) > 0L) {
    stop(
      sprintf("Duplicate media ontology node_id value(s): %s", paste(duplicate_nodes, collapse = ", ")),
      call. = FALSE
    )
  }

  missing_parents <- setdiff(ontology$parent_id[!is.na(ontology$parent_id)], ontology$node_id)
  if (length(missing_parents) > 0L) {
    stop(
      sprintf("Media ontology parent_id value(s) not found: %s", paste(missing_parents, collapse = ", ")),
      call. = FALSE
    )
  }

  invalid_routes <- setdiff(
    unique(ontology$routing_category[!is.na(ontology$routing_category)]),
    valid_media_routing_categories()
  )
  if (length(invalid_routes) > 0L) {
    stop(
      sprintf("Invalid media ontology routing category value(s): %s", paste(invalid_routes, collapse = ", ")),
      call. = FALSE
    )
  }

  parent_by_id <- stats::setNames(ontology$parent_id, ontology$node_id)
  for (node_id in ontology$node_id) {
    visited <- character(0)
    current <- node_id
    repeat {
      if (current %in% visited) {
        stop(
          sprintf("Media ontology parent cycle detected at node_id: %s", current),
          call. = FALSE
        )
      }

      visited <- c(visited, current)
      parent_id <- unname(parent_by_id[current])
      if (is.na(parent_id) || !nzchar(parent_id)) {
        break
      }
      current <- parent_id
    }
  }

  invisible(TRUE)
}

media_ontology_ancestor_ids <- function(node_id, parent_by_id) {
  path <- character(0)
  current <- node_id
  repeat {
    path <- c(current, path)
    parent_id <- unname(parent_by_id[current])
    if (is.na(parent_id) || !nzchar(parent_id)) {
      break
    }
    current <- parent_id
  }

  path
}

build_media_ontology_index <- function(ontology) {
  validate_media_ontology_nodes(ontology)

  parent_by_id <- stats::setNames(ontology$parent_id, ontology$node_id)
  label_by_id <- stats::setNames(ontology$label, ontology$node_id)
  route_by_id <- stats::setNames(ontology$routing_category, ontology$node_id)

  path_ids <- lapply(ontology$node_id, media_ontology_ancestor_ids, parent_by_id = parent_by_id)
  ontology$ontology_path <- vapply(path_ids, function(ids) {
    labels <- unname(label_by_id[ids])
    labels[is.na(labels) | !nzchar(labels)] <- ids[is.na(labels) | !nzchar(labels)]
    paste(labels, collapse = " > ")
  }, character(1))

  ontology$physical_state <- vapply(path_ids, function(ids) {
    if (length(ids) < 2L) {
      return(NA_character_)
    }
    physical <- unname(label_by_id[ids[2]])
    if (is.na(physical) || !nzchar(physical)) {
      return(NA_character_)
    }
    physical
  }, character(1))

  ontology$derived_routing_category <- vapply(seq_along(path_ids), function(i) {
    routes <- unique(unname(route_by_id[path_ids[[i]]]))
    routes <- routes[!is.na(routes) & nzchar(routes)]
    if (length(routes) == 0L) {
      return(NA_character_)
    }
    if (length(routes) > 1L) {
      stop(
        sprintf(
          "Conflicting media routing categories in ontology path for %s: %s",
          ontology$node_id[i],
          paste(routes, collapse = ", ")
        ),
        call. = FALSE
      )
    }
    routes
  }, character(1))

  ontology$has_children <- ontology$node_id %in% ontology$parent_id[!is.na(ontology$parent_id)]
  ontology
}

validate_media_canonical_ontology <- function(canonical, ontology) {
  missing_ontology <- is.na(canonical$ontology_node_id) | !nzchar(canonical$ontology_node_id)
  if (any(canonical$active & missing_ontology)) {
    stop(
      sprintf(
        "Active canonical media rows require ontology_node_id: %s",
        paste(canonical$canonical_media[canonical$active & missing_ontology], collapse = ", ")
      ),
      call. = FALSE
    )
  }

  unknown_nodes <- setdiff(canonical$ontology_node_id[!is.na(canonical$ontology_node_id)], ontology$node_id)
  if (length(unknown_nodes) > 0L) {
    stop(
      sprintf("Canonical media references unknown ontology_node_id value(s): %s", paste(unknown_nodes, collapse = ", ")),
      call. = FALSE
    )
  }

  invalid_categories <- setdiff(
    unique(canonical$routing_category[!is.na(canonical$routing_category)]),
    valid_media_routing_categories()
  )
  if (length(invalid_categories) > 0L) {
    stop(
      sprintf(
        "Invalid media routing category value(s): %s",
        paste(invalid_categories, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  node_match <- match(canonical$ontology_node_id, ontology$node_id)
  derived_route <- ontology$derived_routing_category[node_match]
  both_missing <- is.na(canonical$routing_category) & is.na(derived_route)
  route_equal <- canonical$routing_category == derived_route
  route_equal[is.na(route_equal)] <- FALSE
  route_mismatch <- !(both_missing | route_equal)
  route_mismatch <- route_mismatch & (canonical$active | !is.na(canonical$routing_category))
  route_mismatch[is.na(route_mismatch)] <- FALSE
  if (any(route_mismatch)) {
    bad <- canonical[route_mismatch, , drop = FALSE]
    expected <- ifelse(is.na(derived_route[route_mismatch]), "<none>", derived_route[route_mismatch])
    actual <- ifelse(is.na(bad$routing_category), "<none>", bad$routing_category)
    stop(
      sprintf(
        "Canonical media routing_category does not match ontology-derived route: %s",
        paste(sprintf("%s=%s expected %s", bad$canonical_media, actual, expected), collapse = ", ")
      ),
      call. = FALSE
    )
  }

  non_leaf <- ontology$has_children[node_match]
  allowed_grouping_rank <- ontology$rank[node_match] %in% c("abstract", "routing")
  invalid_grouping <- canonical$active & non_leaf & !allowed_grouping_rank
  invalid_grouping[is.na(invalid_grouping)] <- FALSE
  if (any(invalid_grouping)) {
    stop(
      sprintf(
        "Canonical media cannot reference non-leaf ontology node(s) unless rank is abstract or routing: %s",
        paste(canonical$canonical_media[invalid_grouping], collapse = ", ")
      ),
      call. = FALSE
    )
  }

  canonical$derived_routing_category <- derived_route
  canonical$ontology_path <- ontology$ontology_path[node_match]
  canonical$physical_state <- ontology$physical_state[node_match]
  canonical
}

#' Load reviewable media vocabulary source tables
#'
#' @param source_dir Optional directory containing media_canonical.csv and
#'   media_aliases.csv.
#' @return List with canonical and aliases tibbles.
#' @keywords internal
load_media_source_tables <- function(source_dir = NULL) {
  source_dir <- resolve_media_source_dir(source_dir)
  if (!nzchar(source_dir)) {
    stop("Media source table directory not found.", call. = FALSE)
  }

  canonical <- read_media_source_csv(
    file.path(source_dir, "media_canonical.csv"),
    c("canonical_media", "ontology_node_id", "routing_category", "envo_id", "envo_source", "active")
  )
  aliases <- read_media_source_csv(
    file.path(source_dir, "media_aliases.csv"),
    c("term", "canonical_media", "assertion_mode", "confidence", "source", "active")
  )
  ontology <- read_media_source_csv(
    file.path(source_dir, "media_ontology_nodes.csv"),
    c("node_id", "parent_id", "label", "rank", "routing_category", "envo_id", "definition", "active")
  )

  canonical$canonical_media <- trimws(tolower(as.character(canonical$canonical_media)))
  canonical$ontology_node_id <- normalize_media_lower_character(canonical$ontology_node_id)
  canonical$routing_category <- normalize_media_lower_character(canonical$routing_category)
  canonical$envo_id <- normalize_media_character(canonical$envo_id)
  canonical$envo_source <- normalize_media_character(canonical$envo_source)
  canonical$active <- normalize_media_logical(canonical$active)

  aliases$term <- trimws(tolower(as.character(aliases$term)))
  aliases$canonical_media <- trimws(tolower(as.character(aliases$canonical_media)))
  aliases$canonical_media[!nzchar(aliases$canonical_media)] <- NA_character_
  aliases$assertion_mode <- trimws(tolower(as.character(aliases$assertion_mode)))
  aliases$confidence <- trimws(tolower(as.character(aliases$confidence)))
  aliases$source <- trimws(tolower(as.character(aliases$source)))
  aliases$active <- normalize_media_logical(aliases$active)

  ontology$node_id <- normalize_media_lower_character(ontology$node_id)
  ontology$parent_id <- normalize_media_lower_character(ontology$parent_id)
  ontology$label <- normalize_media_lower_character(ontology$label)
  ontology$rank <- normalize_media_lower_character(ontology$rank)
  ontology$routing_category <- normalize_media_lower_character(ontology$routing_category)
  ontology$envo_id <- normalize_media_character(ontology$envo_id)
  ontology$definition <- normalize_media_character(ontology$definition)
  ontology$active <- normalize_media_logical(ontology$active)

  ontology <- build_media_ontology_index(ontology)
  canonical <- validate_media_canonical_ontology(canonical, ontology)

  valid_modes <- c("auto", "user", "pending")
  invalid_modes <- setdiff(unique(aliases$assertion_mode), valid_modes)
  invalid_modes <- invalid_modes[!is.na(invalid_modes)]
  if (length(invalid_modes) > 0L) {
    stop(
      sprintf(
        "Invalid media assertion_mode value(s): %s",
        paste(invalid_modes, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  list(canonical = canonical, aliases = aliases, ontology_nodes = ontology)
}

empty_media_runtime_map <- function() {
  tibble::tibble(
    term = character(),
    canonical = character(),
    canonical_term = character(),
    envo_id = character(),
    parent = character(),
    media_category = character(),
    ontology_node_id = character(),
    ontology_path = character(),
    physical_state = character(),
    source = character(),
    fetch_timestamp = character(),
    assertion_mode = character(),
    confidence = character(),
    active = logical()
  )
}

#' Build the generated runtime media map from reviewable source tables
#'
#' @param source_tables List returned by load_media_source_tables().
#' @param fetch_timestamp Timestamp string to stamp into the generated cache.
#' @return Tibble compatible with legacy amos_media.rds consumers.
#' @keywords internal
build_media_runtime_map <- function(source_tables = load_media_source_tables(),
                                    fetch_timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%S")) {
  canonical_tbl <- source_tables$canonical
  aliases_tbl <- source_tables$aliases

  if (is.null(canonical_tbl) || is.null(aliases_tbl)) {
    return(empty_media_runtime_map())
  }

  if (!"derived_routing_category" %in% names(canonical_tbl)) {
    canonical_tbl$derived_routing_category <- canonical_tbl$routing_category
  }
  for (col in c("ontology_node_id", "ontology_path", "physical_state")) {
    if (!col %in% names(canonical_tbl)) {
      canonical_tbl[[col]] <- NA_character_
    }
  }

  canonical_lookup <- canonical_tbl
  canonical_lookup$key <- canonical_lookup$canonical_media

  identity_rows <- tibble::tibble(
    term = canonical_tbl$canonical_media,
    canonical = canonical_tbl$canonical_media,
    canonical_term = canonical_tbl$canonical_media,
    envo_id = canonical_tbl$envo_id,
    parent = NA_character_,
    media_category = canonical_tbl$derived_routing_category,
    ontology_node_id = canonical_tbl$ontology_node_id,
    ontology_path = canonical_tbl$ontology_path,
    physical_state = canonical_tbl$physical_state,
    source = "concert",
    fetch_timestamp = fetch_timestamp,
    assertion_mode = "auto",
    confidence = "high",
    active = canonical_tbl$active
  )

  alias_match <- match(aliases_tbl$canonical_media, canonical_lookup$key)
  has_canonical <- !is.na(alias_match)
  alias_rows <- tibble::tibble(
    term = aliases_tbl$term,
    canonical = ifelse(has_canonical, aliases_tbl$canonical_media, NA_character_),
    canonical_term = ifelse(has_canonical, aliases_tbl$canonical_media, NA_character_),
    envo_id = ifelse(has_canonical, canonical_lookup$envo_id[alias_match], NA_character_),
    parent = NA_character_,
    media_category = ifelse(has_canonical, canonical_lookup$derived_routing_category[alias_match], NA_character_),
    ontology_node_id = ifelse(has_canonical, canonical_lookup$ontology_node_id[alias_match], NA_character_),
    ontology_path = ifelse(has_canonical, canonical_lookup$ontology_path[alias_match], NA_character_),
    physical_state = ifelse(has_canonical, canonical_lookup$physical_state[alias_match], NA_character_),
    source = aliases_tbl$source,
    fetch_timestamp = fetch_timestamp,
    assertion_mode = aliases_tbl$assertion_mode,
    confidence = aliases_tbl$confidence,
    active = aliases_tbl$active
  )

  dplyr::bind_rows(alias_rows, identity_rows) |>
    dplyr::distinct(term, .keep_all = TRUE) |>
    dplyr::arrange(term)
}

media_value_present <- function(x) {
  !is.na(x) & nzchar(trimws(as.character(x)))
}

escape_regex <- function(x) {
  gsub("([][{}()+*^$.|?\\\\])", "\\\\\\1", x)
}

media_term_in_text <- function(term, text) {
  if (is.na(term) || is.na(text) || !nzchar(term) || !nzchar(text)) {
    return(FALSE)
  }

  pattern <- sprintf("(^|[^[:alnum:]_])%s($|[^[:alnum:]_])", escape_regex(term))
  grepl(pattern, text, perl = TRUE)
}

is_resolved_media_row <- function(media_tbl, idx) {
  valid_idx <- !is.na(idx)
  out <- rep(FALSE, length(idx))
  if (any(valid_idx)) {
    rows <- idx[valid_idx]
    out[valid_idx] <- media_value_present(media_tbl$canonical_term[rows]) &
      media_value_present(media_tbl$media_category[rows])
  }
  out
}

prepare_media_table <- function(media_tbl) {
  if (is.null(media_tbl) || nrow(media_tbl) == 0L) {
    return(media_tbl)
  }

  if (!"canonical_term" %in% names(media_tbl) && "canonical" %in% names(media_tbl)) {
    media_tbl$canonical_term <- media_tbl$canonical
  }
  if (!"envo_id" %in% names(media_tbl)) {
    media_tbl$envo_id <- NA_character_
  }
  if (!"media_category" %in% names(media_tbl)) {
    media_tbl$media_category <- NA_character_
  }
  if (!"ontology_node_id" %in% names(media_tbl)) {
    media_tbl$ontology_node_id <- NA_character_
  }
  if (!"ontology_path" %in% names(media_tbl)) {
    media_tbl$ontology_path <- NA_character_
  }
  if (!"physical_state" %in% names(media_tbl)) {
    media_tbl$physical_state <- NA_character_
  }
  if (!"parent" %in% names(media_tbl)) {
    media_tbl$parent <- NA_character_
  }
  if (!"active" %in% names(media_tbl)) {
    media_tbl$active <- TRUE
  }
  if (!"source" %in% names(media_tbl)) {
    media_tbl$source <- "concert"
  }
  if (!"assertion_mode" %in% names(media_tbl)) {
    media_tbl$assertion_mode <- ifelse(media_tbl$source == "user", "user", "auto")
  }

  active_flag <- as.logical(media_tbl$active)
  active_flag[is.na(active_flag)] <- FALSE
  media_tbl$term <- trimws(tolower(as.character(media_tbl$term)))
  media_tbl$canonical_term <- trimws(as.character(media_tbl$canonical_term))
  media_tbl$parent <- trimws(tolower(as.character(media_tbl$parent)))
  media_tbl$parent[!media_value_present(media_tbl$parent)] <- NA_character_
  media_tbl$ontology_node_id <- normalize_media_lower_character(media_tbl$ontology_node_id)
  media_tbl$ontology_path <- normalize_media_character(media_tbl$ontology_path)
  media_tbl$physical_state <- normalize_media_lower_character(media_tbl$physical_state)
  media_tbl$source <- trimws(tolower(as.character(media_tbl$source)))
  media_tbl$assertion_mode <- trimws(tolower(as.character(media_tbl$assertion_mode)))

  auto_flag <- media_tbl$assertion_mode %in% c("auto", "user")
  auto_flag[is.na(auto_flag)] <- FALSE
  media_tbl <- media_tbl[active_flag & auto_flag, , drop = FALSE]
  if (nrow(media_tbl) == 0L) {
    return(media_tbl)
  }

  user_priority <- ifelse(media_tbl$source == "user" | media_tbl$assertion_mode == "user", 0L, 1L)
  media_tbl <- media_tbl[order(user_priority, media_tbl$term), , drop = FALSE]
  media_tbl <- media_tbl[!duplicated(media_tbl$term), , drop = FALSE]

  media_tbl
}

normalize_media_map_for_display <- function(media_map) {
  if (is.null(media_map) || !is.data.frame(media_map) || nrow(media_map) == 0L) {
    return(empty_media_runtime_map())
  }

  tbl <- tibble::as_tibble(media_map)
  if (!"term" %in% names(tbl)) {
    return(empty_media_runtime_map())
  }
  if (!"canonical" %in% names(tbl)) {
    tbl$canonical <- if ("canonical_term" %in% names(tbl)) tbl$canonical_term else NA_character_
  }
  if (!"canonical_term" %in% names(tbl)) {
    tbl$canonical_term <- tbl$canonical
  }
  if (!"envo_id" %in% names(tbl)) {
    tbl$envo_id <- NA_character_
  }
  if (!"parent" %in% names(tbl)) {
    tbl$parent <- NA_character_
  }
  if (!"media_category" %in% names(tbl)) {
    tbl$media_category <- NA_character_
  }
  if (!"ontology_node_id" %in% names(tbl)) {
    tbl$ontology_node_id <- NA_character_
  }
  if (!"ontology_path" %in% names(tbl)) {
    tbl$ontology_path <- NA_character_
  }
  if (!"physical_state" %in% names(tbl)) {
    tbl$physical_state <- NA_character_
  }
  if (!"source" %in% names(tbl)) {
    tbl$source <- "concert"
  }
  if (!"fetch_timestamp" %in% names(tbl)) {
    tbl$fetch_timestamp <- NA_character_
  }
  if (!"assertion_mode" %in% names(tbl)) {
    tbl$assertion_mode <- ifelse(tbl$source == "user", "user", "auto")
  }
  if (!"confidence" %in% names(tbl)) {
    tbl$confidence <- NA_character_
  }
  if (!"active" %in% names(tbl)) {
    tbl$active <- TRUE
  }

  tbl <- tibble::tibble(
    term = trimws(tolower(as.character(tbl$term))),
    canonical = normalize_media_character(tbl$canonical),
    canonical_term = normalize_media_character(tbl$canonical_term),
    envo_id = normalize_media_character(tbl$envo_id),
    parent = normalize_media_character(tbl$parent),
    media_category = normalize_media_character(tbl$media_category),
    ontology_node_id = normalize_media_lower_character(tbl$ontology_node_id),
    ontology_path = normalize_media_character(tbl$ontology_path),
    physical_state = normalize_media_lower_character(tbl$physical_state),
    source = trimws(tolower(as.character(tbl$source))),
    fetch_timestamp = as.character(tbl$fetch_timestamp),
    assertion_mode = trimws(tolower(as.character(tbl$assertion_mode))),
    confidence = normalize_media_character(tbl$confidence),
    active = as.logical(tbl$active)
  )
  tbl$active[is.na(tbl$active)] <- FALSE
  tbl$assertion_mode[is.na(tbl$assertion_mode) | !nzchar(tbl$assertion_mode)] <- ifelse(
    tbl$source[is.na(tbl$assertion_mode) | !nzchar(tbl$assertion_mode)] == "user",
    "user",
    "auto"
  )
  tbl
}

#' Build rows for the Media Classification editor
#'
#' Combines active CONCERT/user mappings, unresolved AMOS aliases, and unique
#' raw unmatched uploaded terms produced by harmonize_media().
#'
#' @param media_map Media map tibble from load_media_map().
#' @param media_results harmonize_media() output, or NULL before pipeline run.
#' @return Tibble for DT rendering and tests.
#' @keywords internal
build_media_editor_rows <- function(media_map, media_results) {
  map_rows <- normalize_media_map_for_display(media_map)
  unresolved_map <- is.na(map_rows$canonical) | !nzchar(map_rows$canonical)
  keep_map <- (map_rows$source %in% c("concert", "user") & map_rows$active) |
    (
      map_rows$source == "amos" &
      (unresolved_map | map_rows$assertion_mode == "pending") &
      (map_rows$active | map_rows$assertion_mode == "pending"))
  map_rows <- map_rows[keep_map, , drop = FALSE]

  count_terms <- function(terms, count_col) {
    terms <- trimws(tolower(as.character(terms)))
    terms <- terms[!is.na(terms) & nzchar(terms)]
    if (length(terms) == 0L) {
      empty_counts <- tibble::tibble(term = character(), count = integer())
      names(empty_counts)[2] <- count_col
      return(empty_counts)
    }

    counts <- as.data.frame(table(terms), stringsAsFactors = FALSE)
    names(counts) <- c("term", count_col)
    counts <- tibble::as_tibble(counts)
    counts[[count_col]] <- as.integer(counts[[count_col]])
    counts
  }

  hit_counts <- tibble::tibble(term = character(), hit_count = integer())
  unmatched_counts <- tibble::tibble(term = character(), unmatched_count = integer())
  if (!is.null(media_results) && is.data.frame(media_results) && nrow(media_results) > 0L) {
    raw_col <- if ("raw_media" %in% names(media_results)) media_results$raw_media else character(0)
    flag_col <- if ("media_flag" %in% names(media_results)) media_results$media_flag else character(0)
    hit_counts <- count_terms(raw_col, "hit_count")
    if (length(flag_col) == length(raw_col)) {
      unmatched_counts <- count_terms(raw_col[flag_col == "media_unmatched"], "unmatched_count")
    }
  }

  if (nrow(map_rows) > 0L) {
    hit_match <- match(map_rows$term, hit_counts$term)
    unmatched_match <- match(map_rows$term, unmatched_counts$term)
    map_rows$hit_count <- ifelse(
      is.na(hit_match),
      0L,
      hit_counts$hit_count[hit_match]
    )
    map_rows$unmatched_count <- ifelse(
      is.na(unmatched_match),
      0L,
      unmatched_counts$unmatched_count[unmatched_match]
    )
    map_rows$is_raw_unmatched <- map_rows$unmatched_count > 0L
  } else {
    map_rows$hit_count <- integer(0)
    map_rows$unmatched_count <- integer(0)
    map_rows$is_raw_unmatched <- logical(0)
  }

  new_unmatched <- unmatched_counts[!unmatched_counts$term %in% map_rows$term, , drop = FALSE]
  if (nrow(new_unmatched) > 0L) {
    hit_match <- match(new_unmatched$term, hit_counts$term)
    uploaded_rows <- tibble::tibble(
      term = new_unmatched$term,
      canonical = NA_character_,
      canonical_term = NA_character_,
      envo_id = NA_character_,
      parent = NA_character_,
      media_category = NA_character_,
      ontology_node_id = NA_character_,
      ontology_path = NA_character_,
      physical_state = NA_character_,
      source = "uploaded",
      fetch_timestamp = NA_character_,
      assertion_mode = "pending",
      confidence = NA_character_,
      active = TRUE,
      hit_count = ifelse(
        is.na(hit_match),
        new_unmatched$unmatched_count,
        hit_counts$hit_count[hit_match]
      ),
      unmatched_count = new_unmatched$unmatched_count,
      is_raw_unmatched = TRUE
    )
    map_rows <- dplyr::bind_rows(map_rows, uploaded_rows)
  }

  if (nrow(map_rows) == 0L) {
    return(tibble::tibble(
      term = character(),
      canonical = character(),
      canonical_term = character(),
      envo_id = character(),
      parent = character(),
      media_category = character(),
      ontology_node_id = character(),
      ontology_path = character(),
      physical_state = character(),
      source = character(),
      fetch_timestamp = character(),
      assertion_mode = character(),
      confidence = character(),
      active = logical(),
      hit_count = integer(),
      unmatched_count = integer(),
      is_raw_unmatched = logical()
    ))
  }

  unresolved <- is.na(map_rows$canonical) | !nzchar(map_rows$canonical)
  source_rank <- dplyr::case_when(
    map_rows$source == "uploaded" ~ 0L,
    map_rows$source == "amos" ~ 1L,
    map_rows$source == "user" ~ 2L,
    map_rows$source == "concert" ~ 3L,
    TRUE ~ 4L
  )
  map_rows[
    order(
      source_rank,
      -map_rows$hit_count,
      !unresolved,
      map_rows$ontology_path,
      map_rows$media_category,
      map_rows$term
    ),
    ,
    drop = FALSE
  ]
}

infer_media_categories <- function(media_tbl) {
  if (is.null(media_tbl) || nrow(media_tbl) == 0L || !"media_category" %in% names(media_tbl)) {
    return(media_tbl)
  }

  source_idx <- which(
    media_value_present(media_tbl$canonical_term) &
      media_value_present(media_tbl$media_category)
  )
  if (length(source_idx) == 0L) {
    return(media_tbl)
  }

  unique_donor <- function(key, key_vec) {
    candidates <- source_idx[key_vec[source_idx] == key]
    if (length(candidates) == 0L) {
      return(NA_integer_)
    }
    categories <- unique(media_tbl$media_category[candidates])
    categories <- categories[media_value_present(categories)]
    if (length(categories) != 1L) {
      return(NA_integer_)
    }
    candidates[1]
  }

  term_keys <- media_tbl$term
  canonical_keys <- trimws(tolower(media_tbl$canonical_term))

  missing_category <- which(
    media_value_present(media_tbl$canonical_term) &
      !media_value_present(media_tbl$media_category)
  )
  for (i in missing_category) {
    key <- trimws(tolower(media_tbl$canonical_term[i]))
    donor <- unique_donor(key, term_keys)
    if (is.na(donor)) {
      donor <- unique_donor(key, canonical_keys)
    }
    if (!is.na(donor)) {
      media_tbl$media_category[i] <- media_tbl$media_category[donor]
      for (col in c("envo_id", "ontology_node_id", "ontology_path", "physical_state")) {
        if (
          col %in% names(media_tbl) &&
            !media_value_present(media_tbl[[col]][i]) &&
            media_value_present(media_tbl[[col]][donor])
        ) {
          media_tbl[[col]][i] <- media_tbl[[col]][donor]
        }
      }
    }
  }

  media_tbl
}

#' Walk the parent hierarchy for a normalized media string
#'
#' Given a normalized (trimws + tolower) input string that did not produce a
#' resolved exact match, attempts to find the best ancestor by checking whether
#' a table term appears as a full token/phrase in the input.  Embedded
#' substrings such as \code{"water"} in \code{"wastewater"} are intentionally
#' ignored.  When a candidate is found, walks up the \code{parent} column until
#' an entry with both a canonical term and media category is reached.
#'
#' Returns the integer row index of the resolved entry, or \code{NA_integer_}.
#'
#' @param norm_term Single normalized character string.
#' @param media_tbl Tibble returned by \code{get_media_table()}.
#' @return Integer row index or NA_integer_.
#' @keywords internal
walk_parent <- function(norm_term, media_tbl) {
  if (is.na(norm_term) || !nzchar(norm_term)) {
    return(NA_integer_)
  }

  tbl_terms <- media_tbl$term
  is_candidate <- vapply(tbl_terms, media_term_in_text, logical(1L), text = norm_term)

  candidate_idx <- which(is_candidate)
  if (length(candidate_idx) == 0L) {
    return(NA_integer_)
  }

  cand_lens <- nchar(tbl_terms[candidate_idx])
  candidate_idx <- candidate_idx[order(cand_lens, decreasing = TRUE)]

  for (best_cand in candidate_idx) {
    visited <- integer(0)
    current <- best_cand

    repeat {
      if (current %in% visited) {
        break
      }
      visited <- c(visited, current)

      if (is_resolved_media_row(media_tbl, current)) {
        return(current)
      }

      parent_term <- media_tbl$parent[current]
      if (is.na(parent_term)) {
        break
      }

      parent_idx <- match(parent_term, tbl_terms)
      if (is.na(parent_idx)) {
        break
      }

      current <- parent_idx
    }
  }

  NA_integer_
}

#' Harmonize environmental media strings to canonical CONCERT media terms
#'
#' Maps a character vector of raw environmental media strings against the
#' generated CONCERT media vocabulary cache (\code{amos_media.rds}). Resolution
#' order: (1) user assertions; (2) active bundled auto assertions; (3)
#' parent-walk for partial/compound matches; (4) \code{media_unmatched} flag
#' for everything else. Pending source-table aliases are not auto-resolved.
#'
#' @param raw_media Character vector of media strings to harmonize.
#' @param orig_row_id Integer vector of row IDs corresponding to each element
#'   of \code{raw_media}.  Defaults to \code{seq_along(raw_media)} for direct
#'   column processing.
#' @param media_map Optional tibble with columns term, canonical_term, envo_id,
#'   media_category, source, active, and assertion_mode. When NULL (default),
#'   falls back to the bundled generated media cache via get_media_table().
#'   Pass a merged map from load_media_map() to enable user-defined mappings
#'   (MEDIT-03, D-14). If the tibble uses \code{canonical} instead of
#'   \code{canonical_term} (display schema), the column is translated
#'   internally before lookup.
#' @return A tibble with 6 columns:
#'   \describe{
#'     \item{orig_row_id}{Integer row position for join-by-position merge.}
#'     \item{raw_media}{Original input string, preserved for audit.}
#'     \item{canonical_media}{Canonical CONCERT media term, or
#'       \code{NA_character_} if unmatched.}
#'     \item{envo_id}{ENVO identifier for the matched term, or
#'       \code{NA_character_}.}
#'     \item{media_category}{Top-level routing value: \code{"aqueous"},
#'       \code{"air"}, \code{"solid"}, or \code{NA_character_}.}
#'     \item{media_flag}{One of: \code{""} (exact match), \code{"parent_walk"},
#'       \code{"media_unmatched"}.}
#'   }
#' @importFrom tibble tibble
#' @export
harmonize_media <- function(raw_media, orig_row_id = seq_along(raw_media), media_map = NULL) {
  # Empty-input guard: return typed 0-row tibble (T-41-02 DoS mitigation)
  n <- length(raw_media)
  if (n == 0L) {
    return(tibble::tibble(
      orig_row_id = integer(0),
      raw_media = character(0),
      canonical_media = character(0),
      envo_id = character(0),
      media_category = character(0),
      media_flag = character(0)
    ))
  }

  # Use passed-in map or fall back to bundled AMOS table (D-14 priority order)
  media_tbl <- if (!is.null(media_map) && nrow(media_map) > 0) {
    # Validate required column: term must be present
    if (!"term" %in% names(media_map)) {
      get_media_table()
    } else {
      media_map
    }
  } else {
    get_media_table()
  }

  media_tbl <- prepare_media_table(media_tbl)
  media_tbl <- infer_media_categories(media_tbl)

  if (is.null(media_tbl) || nrow(media_tbl) == 0L) {
    return(tibble::tibble(
      orig_row_id = as.integer(orig_row_id),
      raw_media = as.character(raw_media),
      canonical_media = NA_character_,
      envo_id = NA_character_,
      media_category = NA_character_,
      media_flag = rep("media_unmatched", n)
    ))
  }

  # Normalize input: trim whitespace and lower-case (vectorized)
  normalized <- trimws(tolower(raw_media))

  # Build O(1) hash map: normalized term -> row index
  lookup_hash <- stats::setNames(seq_len(nrow(media_tbl)), media_tbl$term)

  # Exact match (vectorized, NA-safe)
  non_na_mask <- !is.na(normalized)
  match_idx <- rep(NA_integer_, n)
  match_idx[non_na_mask] <- lookup_hash[normalized[non_na_mask]]

  # Pre-allocate output vectors
  canonical_out <- rep(NA_character_, n)
  envo_out <- rep(NA_character_, n)
  category_out <- rep(NA_character_, n)
  media_flag <- rep("media_unmatched", n)

  # Fill resolved exact matches (vectorized where possible). Exact rows without
  # a usable routing category stay unmatched so ppb/ppm never default silently.
  exact_mask <- !is.na(match_idx) & is_resolved_media_row(media_tbl, match_idx)
  if (any(exact_mask)) {
    idx_vec <- match_idx[exact_mask]
    canonical_out[exact_mask] <- media_tbl$canonical_term[idx_vec]
    envo_out[exact_mask] <- media_tbl$envo_id[idx_vec]
    category_out[exact_mask] <- media_tbl$media_category[idx_vec]
    media_flag[exact_mask] <- ""
  }

  # Parent-walk for remaining unmatched rows. Media columns are often highly
  # duplicated, so resolve each distinct normalized term once.
  unmatched_positions <- which(!exact_mask)
  unmatched_terms <- unique(normalized[unmatched_positions])
  unmatched_terms <- unmatched_terms[!is.na(unmatched_terms) & nzchar(unmatched_terms)]

  for (term in unmatched_terms) {
    resolved <- walk_parent(term, media_tbl)
    if (!is.na(resolved)) {
      term_positions <- unmatched_positions[normalized[unmatched_positions] == term]
      canonical_out[term_positions] <- media_tbl$canonical_term[resolved]
      envo_out[term_positions] <- media_tbl$envo_id[resolved]
      category_out[term_positions] <- media_tbl$media_category[resolved]
      media_flag[term_positions] <- "parent_walk"
    }
    # else: stays "media_unmatched" / NA (already initialized)
  }

  tibble::tibble(
    orig_row_id = as.integer(orig_row_id),
    raw_media = as.character(raw_media),
    canonical_media = canonical_out,
    envo_id = envo_out,
    media_category = category_out,
    media_flag = media_flag
  )
}
