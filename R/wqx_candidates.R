# WQX dictionary identifiers are attributed review evidence, never lookup votes.
wqx_candidate_fields <- function() {
  c("wqx_input_name", "wqx_name", "wqx_match_tier", "wqx_match_distance", "wqx_alias_type",
    "wqx_cas", "wqx_cas_status", "wqx_cas_raw", "wqx_cas_provenance",
    "wqx_cas_dtxsid_candidates", "wqx_cas_candidate_names", "wqx_cas_lookup_status")
}

wqx_dictionary_candidates <- function(matches, lookup_fn = validate_and_lookup_cas) {
  n <- nrow(matches)
  column <- function(name, default = NA_character_) {
    if (name %in% names(matches)) matches[[name]] else rep(default, n)
  }
  distance <- column("match_distance", NA_real_)
  distance_text <- rep(NA_character_, n)
  present_distance <- !is.na(distance)
  distance_text[present_distance] <- sprintf("%.17g", distance[present_distance])
  evidence <- tibble::tibble(
    wqx_input_name = column("input_name"),
    wqx_name = column("wqx_name"),
    wqx_match_tier = column("match_tier"),
    wqx_match_distance = distance_text,
    wqx_alias_type = column("alias_type"),
    wqx_cas = column("wqx_cas"),
    wqx_cas_status = column("wqx_cas_status", "missing"),
    wqx_cas_raw = column("wqx_cas_raw"),
    wqx_cas_provenance = column("wqx_cas_provenance"),
    wqx_cas_dtxsid_candidates = rep(NA_character_, n),
    wqx_cas_candidate_names = rep(NA_character_, n),
    wqx_cas_lookup_status = column("wqx_cas_status", "missing")
  )
  eligible <- evidence$wqx_cas_status %in% "valid" & !is.na(evidence$wqx_cas)
  queries <- unique(evidence$wqx_cas[eligible])
  if (!length(queries)) return(evidence)
  # The primary CAS helper retains its historical best-hit behavior elsewhere.
  # WQX explicitly requests every candidate and an outage/no-hit distinction.
  lookup <- tryCatch({
    if (identical(lookup_fn, validate_and_lookup_cas)) lookup_fn(queries, preserve_candidates = TRUE)
    else lookup_fn(queries)
  }, error = function(e) NULL)
  evidence$wqx_cas_lookup_status[eligible] <- "unavailable"
  if (!is.data.frame(lookup)) return(evidence)
  key <- intersect(c("original_cas", "validated_cas", "searchValue"), names(lookup))
  if (!length(key) || !"dtxsid" %in% names(lookup)) return(evidence)
  if (!nrow(lookup)) {
    evidence$wqx_cas_lookup_status[eligible] <- "not_found"
    return(evidence)
  }
  for (cas in queries) {
    rows <- which(as.character(lookup[[key[1]]]) == cas)
    targets <- which(eligible & evidence$wqx_cas == cas)
    if (!length(rows)) {
      evidence$wqx_cas_lookup_status[targets] <- "not_found"
      next
    }
    ids <- as.character(lookup$dtxsid[rows])
    usable <- !is.na(ids) & grepl("^DTXSID[0-9]+$", ids)
    if (any(usable)) {
      evidence$wqx_cas_dtxsid_candidates[targets] <- paste(sort(unique(ids[usable])), collapse = "|")
      if ("preferredName" %in% names(lookup)) {
        names <- as.character(lookup$preferredName[rows])
        named <- usable & !is.na(names) & nzchar(trimws(names))
        if (any(named)) {
          labels <- paste0(ids[named], ":", names[named])
          evidence$wqx_cas_candidate_names[targets] <- paste(sort(unique(labels)), collapse = "|")
        }
      }
    }
    status <- if (any(usable)) "candidate" else "not_found"
    if (any(!is.na(ids) & nzchar(ids) & !usable)) status <- "unavailable"
    if ("lookup_status" %in% names(lookup)) {
      observed <- as.character(lookup$lookup_status[rows])
      if (any(observed %in% c("unavailable", "error", "failed", "timeout"))) status <- "unavailable"
    }
    evidence$wqx_cas_lookup_status[targets] <- status
  }
  evidence
}
