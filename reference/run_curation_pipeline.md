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
  desalt = FALSE
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

## Value

List with results, dedup_summary, search_summary, consensus_summary
