# Run complete cleaning pipeline with audit trail tracking

Orchestrates multiple cleaning steps: 0. Row lineage injection (always)

1.  Unicode to ASCII conversion

2.  Whitespace and punctuation artifact stripping

3.  CAS normalization (if tag_map provided)

4.  CAS rescue from text (if tag_map provided)

5.  Multi-CAS detection (if tag_map provided)

## Usage

``` r
run_cleaning_pipeline(
  df,
  tag_map = NULL,
  reference_lists = NULL,
  use_dedup = TRUE,
  mask = NULL
)
```

## Arguments

- df:

  Dataframe to clean

- tag_map:

  Optional named list mapping column names to types ("CASRN", "Name",
  "Other")

- reference_lists:

  Optional list of reference data (unused in Phase 11, reserved for
  future)

- use_dedup:

  Logical. When TRUE (default), uses dedup_step() wrappers and pre-check
  predicates for performance optimization. Set to FALSE for benchmark
  comparison against the non-dedup baseline path.

- mask:

  Optional named list of logicals switching cleaning steps on or off
  (`unicode`, `whitespace`, `cas`, `names`, `synonyms`, `isotopes`,
  `multi`, `chiral`, `truncated`, `bare_formula`, `reference_flags`).
  Missing entries use the defaults.

## Value

List with cleaned_data (tibble), audit_trail (tibble), and new_tags
(list)

## Details

Each step generates an audit trail. Final audit trail combines all
changes.

## Examples

``` r
df <- tibble::tibble(chemical_name = c("  acetone  ", "cafe\u0301"))
result <- run_cleaning_pipeline(df)
#> • \u0301
#> ℹ Consider updating data-raw/unicode_map.R to include these.
#> Warning: There was 1 warning in `dplyr::mutate()`.
#> ℹ In argument: `dplyr::across(tidyselect::where(is.character), clean_unicode)`.
#> Caused by warning:
#> ! 1 unhandled Unicode symbol(s) detected:
result$cleaned_data  # => tibble with cleaned values
#> # A tibble: 2 × 2
#>   original_row_id chemical_name
#>             <int> <chr>        
#> 1               1 acetone      
#> 2               2 café         
result$audit_trail   # => tibble with change records
#> # A tibble: 1 × 6
#>   row_id field         step                      original_value new_value reason
#>    <int> <chr>         <chr>                     <chr>          <chr>     <chr> 
#> 1      1 chemical_name trim_whitespace_punctuat… "  acetone  "  acetone   Strip…

# With CAS processing
df <- tibble::tibble(cas = c("67641", "no cas"), name = c("acetone", "ethanol 64-17-5"))
tag_map <- list(cas = "CASRN", name = "Name")
result <- run_cleaning_pipeline(df, tag_map)
result$new_tags  # => list(cas_extract_name = "CASRN")
#> $cas_extract_name
#> [1] "CASRN"
#> 
```
