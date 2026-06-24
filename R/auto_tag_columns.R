#' Suggest Column Tags From Header Names
#'
#' Heuristically guesses a tag type for each column from its (already
#' `janitor::clean_names()`-normalized) header name. This powers the
#' "suggest, don't auto-apply" pre-fill in the Tag Columns step: the returned
#' suggestions seed the dropdowns, but the user always reviews and applies.
#'
#' The matcher is **name-only** (no cell-value sampling) and **precision-first**:
#' it matches on whole tokens, prefers the most specific (longest) keyword
#' phrase, drops dangerous generic tokens (bare `name`, `date`, `value`, `id`,
#' `exposure`), and emits at most one suggestion for the singular chemical tags
#' (`Name`, `CASRN`).
#'
#' Every emitted value is a member of the `classify_tags()` taxonomy
#' (`R/tag_helpers.R`); unmatched columns return `""`.
#'
#' @param col_names Character vector of column names (post-`clean_names()`).
#'
#' @return A named list, one element per input column (1:1, order preserved),
#'   whose value is a tag type (e.g. `"CASRN"`, `"Name"`, `"Result"`) or `""`
#'   when no confident match is found. Returns an empty named list for
#'   zero-length input. Returned as a list (not an atomic vector) so callers can
#'   safely use `suggestions[[col]] %||% ""` without a subscript-out-of-bounds
#'   error on missing keys.
#'
#' @examples
#' suggest_column_tags(c("cas_number", "chemical_name", "supplier_name"))
#' # $cas_number    -> "CASRN"
#' # $chemical_name -> "Name"
#' # $supplier_name -> ""   (generic 'name' without a chemical qualifier)
#'
#' @export
suggest_column_tags <- function(col_names) {
  if (length(col_names) == 0) {
    return(stats::setNames(list(), character(0)))
  }

  phrase_table <- .auto_tag_phrase_table()
  norm_headers <- lapply(col_names, .auto_tag_tokens)

  # First pass: best match per column (highest specificity, then tag priority).
  raw <- vapply(
    norm_headers,
    function(tokens) .auto_tag_best_match(tokens, phrase_table),
    character(1)
  )
  # Carry the winning specificity so singular-tag de-duplication can keep the
  # strongest match.
  specs <- vapply(
    norm_headers,
    function(tokens) .auto_tag_best_spec(tokens, phrase_table),
    integer(1)
  )

  # Do not let identifier/code columns steal the singular Name suggestion from
  # the actual analyte/name column in UAT-style datasets.
  identifier_name <- raw == "Name" &
    vapply(norm_headers, .auto_tag_is_identifier_header, logical(1)) &
    !vapply(norm_headers, .auto_tag_has_explicit_name_phrase, logical(1))
  raw[identifier_name] <- ""
  specs[identifier_name] <- 0L

  # Second pass: enforce at-most-one suggestion for singular chemical tags.
  for (singular in c("Name", "CASRN")) {
    idx <- which(raw == singular)
    if (length(idx) > 1) {
      keep <- idx[which.max(specs[idx])] # ties -> first occurrence (which.max)
      drop <- setdiff(idx, keep)
      raw[drop] <- ""
    }
  }

  stats::setNames(as.list(raw), col_names)
}

#' Normalize a header into whole-word tokens.
#'
#' Lowercases and replaces every run of non-alphanumeric characters (including
#' the underscores produced by `janitor::clean_names()`) with a single space,
#' then splits into tokens. Keywords are normalized the same way so that
#' multi-word phrases such as `"duration unit"` match `"duration_unit"`.
#' @noRd
.auto_tag_tokens <- function(x) {
  x <- tolower(as.character(x))
  x <- gsub("[^a-z0-9]+", " ", x)
  x <- trimws(x)
  if (!nzchar(x)) {
    return(character(0))
  }
  strsplit(x, "\\s+")[[1]]
}

#' Is `needle` a contiguous sub-sequence of `hay` (both token vectors)?
#' @noRd
.auto_tag_is_subseq <- function(needle, hay) {
  n <- length(needle)
  h <- length(hay)
  if (n == 0L || n > h) {
    return(FALSE)
  }
  for (i in seq_len(h - n + 1L)) {
    if (all(hay[i:(i + n - 1L)] == needle)) {
      return(TRUE)
    }
  }
  FALSE
}

#' Does a header look like an identifier/code column?
#' @noRd
.auto_tag_is_identifier_header <- function(tokens) {
  any(tokens %in% c("id", "identifier", "code"))
}

#' Does a header explicitly describe a name, not only an entity token?
#' @noRd
.auto_tag_has_explicit_name_phrase <- function(tokens) {
  explicit_name_phrases <- list(
    c("chemical", "name"),
    c("compound", "name"),
    c("substance", "name"),
    c("analyte", "name"),
    c("reagent", "name"),
    c("ingredient", "name")
  )

  any(vapply(explicit_name_phrases, .auto_tag_is_subseq, logical(1), hay = tokens))
}

#' Per-column best tag (value) or "".
#' @noRd
.auto_tag_best_match <- function(tokens, phrase_table) {
  .auto_tag_pick(tokens, phrase_table)$tag
}

#' Per-column winning specificity (0 when no match).
#' @noRd
.auto_tag_best_spec <- function(tokens, phrase_table) {
  .auto_tag_pick(tokens, phrase_table)$spec
}

#' Choose the best (tag, spec) for a token vector.
#'
#' Highest specificity (longest phrase) wins; ties broken by `priority` (lower
#' = preferred), so e.g. `duration unit` resolves to DurationUnit over Unit.
#' @noRd
.auto_tag_pick <- function(tokens, phrase_table) {
  best_tag <- ""
  best_spec <- 0L
  best_priority <- .Machine$integer.max
  if (length(tokens) == 0L) {
    return(list(tag = best_tag, spec = best_spec))
  }
  for (i in seq_along(phrase_table$tag)) {
    if (.auto_tag_is_subseq(phrase_table$phrase[[i]], tokens)) {
      spec <- phrase_table$spec[i]
      priority <- phrase_table$priority[i]
      if (spec > best_spec || (spec == best_spec && priority < best_priority)) {
        best_tag <- phrase_table$tag[i]
        best_spec <- spec
        best_priority <- priority
      }
    }
  }
  list(tag = best_tag, spec = best_spec)
}

#' Pre-compiled phrase table mapping keyword phrases -> tag types.
#'
#' Built once per `suggest_column_tags()` call (cheap; not inside the per-column
#' loop). Every `tag` value MUST be a member of the `classify_tags()` taxonomy
#' (chemical: Name, CASRN, Other; numeric: Result, Numeric, Unit, Qualifier,
#' ReportingLimit, Uncertainty, UncertaintyCoverage, Duration, DurationUnit;
#' metadata: Species, ExposureRoute; study: StudyDate, Media). Phrases are
#' precision-first: generic single tokens (bare `name`,
#' `date`, `value`, `id`, `exposure`) are intentionally excluded.
#' @noRd
.auto_tag_phrase_table <- function() {
  # tag -> character vector of keyword phrases (space-separated words)
  keywords <- list(
    CASRN = c("casrn", "cas rn", "cas number", "cas no", "cas registry number", "cas registry", "cas"),
    Name = c(
      "chemical name",
      "compound name",
      "substance name",
      "analyte name",
      "reagent name",
      "ingredient name",
      "chemical",
      "compound",
      "substance",
      "analyte",
      "reagent"
    ),
    Other = c(
      "molecular formula",
      "chemical formula",
      "formula",
      "smiles",
      "inchi",
      "inchikey",
      "dtxsid",
      "structure",
      "synonym",
      "synonyms"
    ),
    Result = c("result value", "result", "concentration", "conc", "measurement", "measured value"),
    Numeric = c("numeric measurement", "numeric value", "numeric"),
    Unit = c("unit of measure", "units", "unit", "uom"),
    Qualifier = c("qualifier", "qual"),
    ReportingLimit = c(
      "reporting limit",
      "report limit",
      "result reporting limit",
      "rl",
      "mda",
      "mdc",
      "detection limit",
      "method detection limit",
      "quantitation limit",
      "limit of quantitation",
      "lod",
      "loq"
    ),
    Uncertainty = c(
      "uncertainty",
      "counting uncertainty",
      "measurement uncertainty",
      "result uncertainty",
      "two sigma uncertainty",
      "one sigma uncertainty",
      "sigma"
    ),
    UncertaintyCoverage = c(
      "uncertainty coverage",
      "coverage factor",
      "coverage",
      "sigma coverage",
      "uncertainty type"
    ),
    Duration = c("exposure duration", "study duration", "exposure period", "exposure time", "duration"),
    DurationUnit = c("duration unit", "duration units", "duration uom", "time unit"),
    Species = c("test species", "test organism", "species", "organism", "animal"),
    ExposureRoute = c("route of exposure", "exposure route", "administration route", "exposure pathway", "route"),
    StudyDate = c("study start date", "study date", "test date", "sample date", "sampling date", "collection date"),
    Media = c("sample matrix", "exposure media", "test media", "sample type", "media", "medium", "matrix")
  )

  # Tie-break priority (lower = preferred) when two tags match at equal
  # specificity. More specific concepts win over generic Name/Other/Result.
  priority_order <- c(
    "CASRN",
    "DurationUnit",
    "UncertaintyCoverage",
    "ReportingLimit",
    "ExposureRoute",
    "StudyDate",
    "Species",
    "Media",
    "Unit",
    "Qualifier",
    "Uncertainty",
    "Duration",
    "Result",
    "Numeric",
    "Other",
    "Name"
  )

  tags <- character(0)
  phrases <- list()
  specs <- integer(0)
  priorities <- integer(0)
  for (tag in names(keywords)) {
    for (kw in keywords[[tag]]) {
      toks <- .auto_tag_tokens(kw)
      tags <- c(tags, tag)
      phrases <- c(phrases, list(toks))
      specs <- c(specs, length(toks))
      priorities <- c(priorities, match(tag, priority_order))
    }
  }

  list(tag = tags, phrase = phrases, spec = specs, priority = priorities)
}
