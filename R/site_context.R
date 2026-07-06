# Dataset context helpers for site/location curation.

empty_site_manifest <- function() {
  tibble::tibble(
    source_site_label = character(),
    site_order = integer(),
    site_suborder = integer(),
    site_identifier = character(),
    site_name = character(),
    site_label = character(),
    latitude = numeric(),
    longitude = numeric(),
    grouping_type = character(),
    grouping_label = character(),
    source_row = integer(),
    source_site_id = character(),
    source_site_name = character(),
    source_latitude = character(),
    source_longitude = character(),
    source_grouping_value = character(),
    site_label_column = character(),
    site_id_column = character(),
    site_name_column = character(),
    latitude_column = character(),
    longitude_column = character(),
    grouping_column = character()
  )
}

site_context_manifest_columns <- function() {
  names(empty_site_manifest())
}

site_context_editable_columns <- function() {
  c(
    "site_order",
    "site_suborder",
    "site_identifier",
    "site_name",
    "site_label",
    "latitude",
    "longitude",
    "grouping_type",
    "grouping_label"
  )
}

site_context_clean_text <- function(x) {
  x <- trimws(as.character(x))
  x[is.na(x) | x == "" | tolower(x) %in% c("na", "nan", "null")] <- NA_character_
  x
}

site_context_chr <- function(x, n) {
  if (is.null(x)) {
    return(rep(NA_character_, n))
  }
  x <- site_context_clean_text(x)
  if (length(x) == n) {
    return(x)
  }
  length(x) <- n
  x
}

site_context_num <- function(x, n = length(x)) {
  if (is.null(x)) {
    return(rep(NA_real_, n))
  }
  raw <- site_context_chr(x, n)
  parsed <- suppressWarnings(as.numeric(raw))
  needs_clean <- is.na(parsed) & !is.na(raw)
  if (any(needs_clean)) {
    cleaned <- gsub("[^0-9eE+\\.-]", "", raw[needs_clean])
    parsed[needs_clean] <- suppressWarnings(as.numeric(cleaned))
  }
  parsed
}

site_context_format_number <- function(x) {
  if (length(x) != 1L || is.na(x)) {
    return(NA_character_)
  }
  sub("\\.?0+$", "", format(round(x, 7), scientific = FALSE, trim = TRUE))
}

site_context_header <- function(x) {
  x <- tolower(as.character(x))
  x <- gsub("[^a-z0-9]+", "_", x)
  x <- gsub("_+", "_", x)
  x <- gsub("^_|_$", "", x)
  x
}

site_context_nonblank <- function(x) {
  x <- site_context_clean_text(x)
  x[!is.na(x)]
}

site_context_alias_key <- function(x) {
  x <- site_context_clean_text(x)
  x <- gsub("\\s+", " ", x)
  x <- tolower(x)
  x[is.na(x) | x == ""] <- NA_character_
  x
}

site_context_coalesce_chr <- function(...) {
  values <- list(...)
  if (length(values) == 0L) {
    return(character())
  }

  n <- max(vapply(values, length, integer(1)), 0L)
  result <- rep(NA_character_, n)
  for (value in values) {
    value <- site_context_chr(value, n)
    fill <- is.na(result) & !is.na(value)
    result[fill] <- value[fill]
  }
  result
}

site_context_numeric_ratio <- function(x) {
  values <- site_context_nonblank(x)
  if (length(values) == 0L) {
    return(0)
  }
  mean(!is.na(site_context_num(values)))
}

site_context_coordinate_ratio <- function(x, lower, upper) {
  values <- site_context_nonblank(x)
  if (length(values) == 0L) {
    return(0)
  }
  nums <- site_context_num(values)
  mean(!is.na(nums) & nums >= lower & nums <= upper)
}

site_context_value_repeats <- function(x) {
  values <- tolower(site_context_nonblank(x))
  length(values) > 0L && dplyr::n_distinct(values) < length(values)
}

site_context_score_site_id <- function(name, values) {
  header <- site_context_header(name)
  exact <- c(
    "site_id",
    "siteid",
    "site_identifier",
    "site_code",
    "station_id",
    "stationid",
    "station_identifier",
    "station_code",
    "location_id",
    "locationid",
    "location_identifier",
    "loc_id",
    "sampling_site_id",
    "sample_site_id",
    "monitoring_location_id",
    "monitoring_location_identifier",
    "monitoring_location_code"
  )

  score <- 0
  if (header %in% exact) {
    score <- 100
  } else if (grepl("(site|station|location).*(id|identifier|code)$", header) ||
    grepl("^(id|identifier|code).*(site|station|location)", header)) {
    score <- 90
  } else if (header %in% c("site", "station")) {
    score <- 55
  }

  if (score > 0 && site_context_numeric_ratio(values) > 0.95 && score < 90) {
    score <- score - 20
  }
  if (score > 0 && site_context_value_repeats(values)) {
    score <- score + 5
  }
  score
}

site_context_score_site_label <- function(name, values) {
  header <- site_context_header(name)
  exact <- c(
    "site_label",
    "station_label",
    "location_label",
    "sample_location",
    "sampling_location",
    "sampling_site",
    "sampling_station",
    "station_name",
    "location_name",
    "monitoring_location_name",
    "monitoring_location"
  )

  score <- 0
  if (header %in% exact) {
    score <- 105
  } else if (grepl("(site|station|location).*(label|name|description)$", header) ||
    grepl("^(label|name|description).*(site|station|location)", header)) {
    score <- 90
  } else if (grepl("(sample|sampling).*(site|station|location)", header)) {
    score <- 85
  }

  if (score > 0 && length(site_context_nonblank(values)) > 0L) {
    score <- score + 5
  }
  score
}

site_context_score_site_name <- function(name, values) {
  header <- site_context_header(name)
  exact <- c(
    "site_name",
    "station_name",
    "location_name",
    "sample_location",
    "sampling_location",
    "monitoring_location_name",
    "monitoring_location"
  )

  score <- 0
  if (header %in% exact) {
    score <- 100
  } else if (grepl("(site|station|location).*(name|description)$", header) ||
    grepl("^(name|description).*(site|station|location)", header)) {
    score <- 85
  }

  if (score > 0 && length(site_context_nonblank(values)) > 0L) {
    score <- score + 5
  }
  score
}

site_context_score_latitude <- function(name, values) {
  header <- site_context_header(name)
  ratio <- site_context_coordinate_ratio(values, -90, 90)
  exact <- c(
    "latitude",
    "lat",
    "decimal_latitude",
    "lat_dd",
    "latitude_dd",
    "monitoring_location_latitude"
  )

  if (header %in% exact) {
    return(90 + as.integer(ratio >= 0.8) * 10)
  }
  if (header %in% c("y", "y_coord", "y_coordinate") && ratio >= 0.8) {
    return(55)
  }
  if (grepl("(^|_)lat(itude)?($|_)", header) && ratio >= 0.5) {
    return(80)
  }
  0
}

site_context_score_longitude <- function(name, values) {
  header <- site_context_header(name)
  ratio <- site_context_coordinate_ratio(values, -180, 180)
  exact <- c(
    "longitude",
    "long",
    "lon",
    "lng",
    "decimal_longitude",
    "lon_dd",
    "long_dd",
    "longitude_dd",
    "monitoring_location_longitude"
  )

  if (header %in% exact) {
    return(90 + as.integer(ratio >= 0.8) * 10)
  }
  if (header %in% c("x", "x_coord", "x_coordinate") && ratio >= 0.8) {
    return(55)
  }
  if (grepl("(^|_)(lon|long|lng)(itude)?($|_)", header) && ratio >= 0.5) {
    return(80)
  }
  0
}

site_context_grouping_type <- function(name) {
  header <- site_context_header(name)
  if (header %in% c("watershed", "basin", "subbasin", "sub_basin", "catchment", "huc", "huc8", "huc_8") ||
    grepl("(watershed|catchment|subbasin|sub_basin)", header)) {
    return("watershed")
  }
  if (grepl("(treatment_train|treatment_process|process_stage|unit_process)", header)) {
    return("treatment_train")
  }
  if (header %in% c("site_group", "location_group", "station_group", "group", "region", "area", "zone") ||
    grepl("(site|location|station)_group", header)) {
    return("group")
  }
  NA_character_
}

site_context_score_grouping <- function(name, values) {
  type <- site_context_grouping_type(name)
  if (is.na(type)) {
    return(0)
  }
  if (length(site_context_nonblank(values)) == 0L) {
    return(30)
  }
  80
}

site_context_best_column <- function(df, scorer, min_score) {
  if (is.null(df) || ncol(df) == 0L) {
    return(NA_character_)
  }
  scores <- vapply(names(df), function(col) scorer(col, df[[col]]), numeric(1))
  if (length(scores) == 0L || max(scores, na.rm = TRUE) < min_score) {
    return(NA_character_)
  }
  names(scores)[which.max(scores)]
}

#' Detect Site/Location Columns In A Dataset
#'
#' Uses cleaned header names and conservative value checks to identify likely
#' source site labels, site identifiers, site names, coordinates, and optional
#' grouping metadata.
#'
#' @param df Data frame after file detection/extraction.
#'
#' @return A list with detected column names and `has_site_context`.
#' @export
detect_site_columns <- function(df) {
  if (is.null(df) || !inherits(df, "data.frame") || ncol(df) == 0L) {
    return(list(
      site_id = NA_character_,
      site_label = NA_character_,
      site_name = NA_character_,
      latitude = NA_character_,
      longitude = NA_character_,
      grouping = NA_character_,
      grouping_type = NA_character_,
      has_site_context = FALSE
    ))
  }

  site_id <- site_context_best_column(df, site_context_score_site_id, 50)
  site_label <- site_context_best_column(df, site_context_score_site_label, 50)
  site_name <- site_context_best_column(df, site_context_score_site_name, 50)
  latitude <- site_context_best_column(df, site_context_score_latitude, 50)
  longitude <- site_context_best_column(df, site_context_score_longitude, 50)

  if (!is.na(latitude) && identical(latitude, longitude)) {
    longitude <- NA_character_
  }

  grouping <- site_context_best_column(df, site_context_score_grouping, 50)
  grouping_type <- if (!is.na(grouping)) site_context_grouping_type(grouping) else NA_character_

  list(
    site_id = site_id,
    site_label = site_label,
    site_name = site_name,
    latitude = latitude,
    longitude = longitude,
    grouping = grouping,
    grouping_type = grouping_type,
    has_site_context = !is.na(site_label) || !is.na(site_id) || !is.na(site_name) || (!is.na(latitude) && !is.na(longitude))
  )
}

site_context_detection_summary <- function(detection) {
  if (is.null(detection) || !isTRUE(detection$has_site_context)) {
    return(character(0))
  }
  detection_value <- function(field) site_context_detection_value(detection, field)
  parts <- c(
    if (!is.na(detection_value("site_label"))) paste("site label:", detection_value("site_label")) else NULL,
    if (!is.na(detection_value("site_id"))) paste("site ID:", detection_value("site_id")) else NULL,
    if (!is.na(detection_value("site_name"))) paste("site name:", detection_value("site_name")) else NULL,
    if (!is.na(detection_value("latitude"))) paste("latitude:", detection_value("latitude")) else NULL,
    if (!is.na(detection_value("longitude"))) paste("longitude:", detection_value("longitude")) else NULL,
    if (!is.na(detection_value("grouping"))) paste("grouping:", detection_value("grouping")) else NULL
  )
  parts
}

site_context_detection_value <- function(detection, field) {
  value <- detection[[field]]
  if (is.null(value) || length(value) == 0L || is.na(value[1])) {
    return(NA_character_)
  }
  as.character(value[1])
}

site_context_column_values <- function(df, col) {
  if (is.null(col) || length(col) == 0L || is.na(col) || !col %in% names(df)) {
    return(NULL)
  }
  df[[col]]
}

site_context_first_nonmissing <- function(x) {
  idx <- which(!is.na(x))
  if (length(idx) == 0L) {
    return(NA)
  }
  x[idx[1]]
}

site_context_key <- function(site_identifier, site_name, latitude, longitude) {
  site_identifier <- site_context_clean_text(site_identifier)
  site_name <- site_context_clean_text(site_name)
  latitude <- suppressWarnings(as.numeric(latitude))
  longitude <- suppressWarnings(as.numeric(longitude))

  if (!is.na(site_identifier)) {
    return(paste0("id:", tolower(site_identifier)))
  }
  if (!is.na(site_name)) {
    return(paste0("name:", tolower(site_name)))
  }
  if (!is.na(latitude) && !is.na(longitude)) {
    return(paste0(
      "coord:",
      site_context_format_number(latitude),
      ",",
      site_context_format_number(longitude)
    ))
  }
  NA_character_
}

site_context_coordinate_identifier <- function(latitude, longitude) {
  if (is.na(latitude) || is.na(longitude)) {
    return(NA_character_)
  }
  paste0(
    "coord:",
    site_context_format_number(latitude),
    ",",
    site_context_format_number(longitude)
  )
}

site_context_coordinate_identifiers <- function(latitude, longitude) {
  vapply(
    seq_along(latitude),
    function(i) site_context_coordinate_identifier(latitude[i], longitude[i]),
    character(1)
  )
}

#' Extract Site Candidates
#'
#' Builds a first-seen, distinct raw-label list from detected site/location
#' columns. User order fields are left blank by default; source row order
#' remains available as the deterministic fallback order.
#'
#' @param df Data frame after file detection/extraction.
#' @param detection Optional result from `detect_site_columns()`.
#'
#' @return A site manifest candidate tibble.
#' @export
extract_site_candidates <- function(df, detection = NULL) {
  if (is.null(df) || !inherits(df, "data.frame") || nrow(df) == 0L) {
    return(empty_site_manifest())
  }
  if (is.null(detection)) {
    detection <- detect_site_columns(df)
  }
  if (!isTRUE(detection$has_site_context)) {
    return(empty_site_manifest())
  }

  n <- nrow(df)
  site_label_column <- site_context_detection_value(detection, "site_label")
  site_id_column <- site_context_detection_value(detection, "site_id")
  site_name_column <- site_context_detection_value(detection, "site_name")
  latitude_column <- site_context_detection_value(detection, "latitude")
  longitude_column <- site_context_detection_value(detection, "longitude")
  grouping_column <- site_context_detection_value(detection, "grouping")
  grouping_type <- site_context_detection_value(detection, "grouping_type")

  detected_source_site_label <- site_context_chr(site_context_column_values(df, site_label_column), n)
  source_site_id <- site_context_chr(site_context_column_values(df, site_id_column), n)
  source_site_name <- site_context_chr(site_context_column_values(df, site_name_column), n)
  source_latitude <- site_context_chr(site_context_column_values(df, latitude_column), n)
  source_longitude <- site_context_chr(site_context_column_values(df, longitude_column), n)
  source_grouping <- site_context_chr(site_context_column_values(df, grouping_column), n)
  latitude <- site_context_num(source_latitude, n)
  longitude <- site_context_num(source_longitude, n)

  latitude[latitude < -90 | latitude > 90] <- NA_real_
  longitude[longitude < -180 | longitude > 180] <- NA_real_

  coordinate_label <- site_context_coordinate_identifiers(latitude, longitude)
  source_site_label <- site_context_coalesce_chr(
    detected_source_site_label,
    source_site_name,
    source_site_id,
    coordinate_label
  )
  keys <- site_context_alias_key(source_site_label)

  keep <- !is.na(keys) & !duplicated(keys)
  if (!any(keep)) {
    return(empty_site_manifest())
  }

  first_rows <- which(keep)
  rows <- lapply(seq_along(first_rows), function(i) {
    row <- first_rows[i]
    group_rows <- which(keys == keys[row])
    lat_value <- site_context_first_nonmissing(latitude[group_rows])
    lon_value <- site_context_first_nonmissing(longitude[group_rows])
    id_value <- site_context_first_nonmissing(source_site_id[group_rows])
    name_value <- site_context_first_nonmissing(source_site_name[group_rows])
    grouping_value <- site_context_first_nonmissing(source_grouping[group_rows])
    if (is.na(id_value)) {
      id_value <- site_context_coordinate_identifier(lat_value, lon_value)
    }
    if (is.na(id_value)) {
      id_value <- source_site_label[row]
    }
    if (is.na(name_value)) {
      name_value <- source_site_label[row]
    }
    label_value <- source_site_label[row]

    tibble::tibble(
      source_site_label = source_site_label[row],
      site_order = NA_integer_,
      site_suborder = 1L,
      site_identifier = id_value,
      site_name = name_value,
      site_label = label_value,
      latitude = as.numeric(lat_value),
      longitude = as.numeric(lon_value),
      grouping_type = if (!is.na(grouping_value)) grouping_type else NA_character_,
      grouping_label = grouping_value,
      source_row = row,
      source_site_id = source_site_id[row],
      source_site_name = source_site_name[row],
      source_latitude = site_context_first_nonmissing(source_latitude[group_rows]),
      source_longitude = site_context_first_nonmissing(source_longitude[group_rows]),
      source_grouping_value = grouping_value,
      site_label_column = site_label_column,
      site_id_column = site_id_column,
      site_name_column = site_name_column,
      latitude_column = latitude_column,
      longitude_column = longitude_column,
      grouping_column = grouping_column
    )
  })

  dplyr::bind_rows(rows) |>
    normalize_site_manifest()
}

#' Normalize A Site Manifest
#'
#' Coerces a site manifest to the canonical CONCERT schema while preserving
#' user-facing site identifiers and source audit columns.
#'
#' @param site_manifest Data frame-like site manifest.
#'
#' @return A tibble with canonical site manifest columns.
#' @export
normalize_site_manifest <- function(site_manifest) {
  if (is.null(site_manifest) || !inherits(site_manifest, "data.frame") || nrow(site_manifest) == 0L) {
    return(empty_site_manifest())
  }

  manifest <- tibble::as_tibble(site_manifest)
  template <- empty_site_manifest()
  missing_cols <- setdiff(names(template), names(manifest))
  for (col in missing_cols) {
    manifest[[col]] <- template[[col]][NA_integer_]
  }
  manifest <- manifest[, names(template), drop = FALSE]

  n <- nrow(manifest)
  manifest$site_order <- suppressWarnings(as.integer(manifest$site_order))
  manifest$site_suborder <- suppressWarnings(as.integer(manifest$site_suborder))
  manifest$source_row <- suppressWarnings(as.integer(manifest$source_row))
  manifest$latitude <- site_context_num(manifest$latitude, n)
  manifest$longitude <- site_context_num(manifest$longitude, n)

  char_cols <- setdiff(names(manifest), c("site_order", "site_suborder", "source_row", "latitude", "longitude"))
  for (col in char_cols) {
    manifest[[col]] <- site_context_chr(manifest[[col]], n)
  }

  manifest$site_suborder[is.na(manifest$site_suborder)] <- 1L
  manifest$source_row[is.na(manifest$source_row)] <- seq_len(n)[is.na(manifest$source_row)]
  manifest$latitude[manifest$latitude < -90 | manifest$latitude > 90] <- NA_real_
  manifest$longitude[manifest$longitude < -180 | manifest$longitude > 180] <- NA_real_
  manifest$source_site_label <- site_context_coalesce_chr(
    manifest$source_site_label,
    manifest$source_site_name,
    manifest$source_site_id,
    site_context_coordinate_identifiers(manifest$latitude, manifest$longitude)
  )
  manifest
}

#' Build A Deterministic Site Alias Map
#'
#' Filters blank aliases and blank canonical destinations, then keeps one row
#' for each distinct raw dataset site label in first-seen order.
#'
#' @param site_manifest Site manifest candidate or user-edited site context.
#'
#' @return A deterministic, distinct site alias map.
#' @export
build_site_alias_map <- function(site_manifest) {
  alias_map <- normalize_site_manifest(site_manifest)
  if (nrow(alias_map) == 0L) {
    return(alias_map)
  }

  source_keys <- site_context_alias_key(alias_map$source_site_label)
  canonical_keys <- vapply(seq_len(nrow(alias_map)), function(i) {
    site_context_key(
      alias_map$site_identifier[i],
      alias_map$site_name[i],
      alias_map$latitude[i],
      alias_map$longitude[i]
    )
  }, character(1))

  keep <- !is.na(source_keys) & !is.na(canonical_keys)
  if (!any(keep)) {
    return(empty_site_manifest())
  }

  alias_map <- alias_map[keep, , drop = FALSE]
  source_keys <- source_keys[keep]
  alias_map <- alias_map[!duplicated(source_keys), , drop = FALSE]
  rownames(alias_map) <- NULL
  tibble::as_tibble(alias_map)
}

site_context_alias_source <- function(site_alias_map = NULL, site_manifest = NULL) {
  if (!is.null(site_alias_map) && inherits(site_alias_map, "data.frame") && nrow(site_alias_map) > 0L) {
    return(site_alias_map)
  }
  site_manifest
}

#' Build A Deterministic Site Manifest
#'
#' Sorts by user-curated order/suborder, filters blank rows, and enforces one
#' row per site identifier/name/coordinate key.
#'
#' @param site_manifest Site manifest candidate or user-edited site context.
#'
#' @return A deterministic, ordered, distinct site manifest.
#' @export
build_site_manifest <- function(site_manifest) {
  manifest <- normalize_site_manifest(site_manifest)
  if (nrow(manifest) == 0L) {
    return(manifest)
  }

  keys <- vapply(seq_len(nrow(manifest)), function(i) {
    site_context_key(
      manifest$site_identifier[i],
      manifest$site_name[i],
      manifest$latitude[i],
      manifest$longitude[i]
    )
  }, character(1))

  nonblank <- !is.na(keys)
  if (!any(nonblank)) {
    return(empty_site_manifest())
  }

  manifest <- manifest[nonblank, , drop = FALSE]
  keys <- keys[nonblank]
  stable_row <- seq_len(nrow(manifest))
  order_idx <- order(manifest$site_order, manifest$site_suborder, manifest$source_row, stable_row, na.last = TRUE)
  manifest <- manifest[order_idx, , drop = FALSE]
  keys <- keys[order_idx]
  manifest <- manifest[!duplicated(keys), , drop = FALSE]
  rownames(manifest) <- NULL
  tibble::as_tibble(manifest)
}

#' Build CHORUS Site Manifest Payload
#'
#' Produces the ordered, distinct site manifest CONCERT sends downstream. CHORUS
#' should still validate and deduplicate on ingest.
#'
#' @param site_manifest Site manifest candidate or user-edited site context.
#'
#' @return A deterministic site manifest tibble.
#' @export
build_chorus_site_manifest <- function(site_manifest) {
  build_site_manifest(site_manifest)
}
