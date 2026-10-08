# Orchestrate the full curation pipeline: dedup -\> search -\> map -\> consensus -\> resolution

Orchestrate the full curation pipeline: dedup -\> search -\> map -\>
consensus -\> resolution

## Usage

``` r
run_curation_pipeline(
  clean_data,
  column_tags,
  progress_callback = NULL,
  dedup_only = FALSE,
  wqx_threshold = 0.85,
  starts_with = FALSE,
  pubchem = FALSE,
  original_data = NULL,
  desalt = FALSE,
  ignored_identifier_cols = character(),
  source_lookup_fn = source_identifier_lookup,
  wqx_cas_lookup_fn = validate_and_lookup_cas
)
```

## Arguments

- clean_data:

  The cleaned data frame (data_store\$clean)

- column_tags:

  Named list (col_name -\> "Name"\|"CASRN"\|"Other")

- progress_callback:

  Optional function(stage, message) for reporting progress to Shiny

- dedup_only:

  If TRUE, return after dedup stage with just counts (for preview)

- wqx_threshold:

  Numeric WQX fuzzy matching threshold.

- starts_with:

  Logical. If TRUE, enables CompTox starts-with fallback search for
  names unresolved by exact, CAS, and WQX matching.

- pubchem:

  Logical. If TRUE, add exact-name PubChem candidates for unresolved
  rows without assigning DTXSIDs.

- original_data:

  Optional input rows used for the original name lookup.

- desalt:

  Logical. If TRUE, suggest parent names and DTXSIDs for unresolved salt
  names without assigning them. Independent of `pubchem`.

- ignored_identifier_cols:

  Deliberately unused identifier metadata columns.

- source_lookup_fn:

  Injectable authoritative source DTXSID details lookup.

- wqx_cas_lookup_fn:

  Injectable CAS lookup for canonical WQX dictionary evidence. Receives
  deduplicated valid CAS values and returns original_cas (or
  validated_cas), dtxsid, preferredName, and optional lookup_status. All
  hits remain review candidates; no candidate is selected or accepted.
  Statuses distinguish candidate, not_found, unavailable, missing,
  invalid, and ambiguous dictionary evidence. Independent of `pubchem`.
  Mapped `wqx_match_distance` is lossless 17-digit decimal text for
  portable evidence fingerprints; the matcher's `match_distance` remains
  numeric.

## Value

List with results, dedup_summary, search_summary, consensus_summary
