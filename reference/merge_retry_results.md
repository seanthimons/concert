# Merge retry curation results back into original resolution state

Merge retry curation results back into original resolution state

## Usage

``` r
merge_retry_results(
  original_state,
  retry_results,
  selected_row_indices,
  tags_changed = FALSE
)
```

## Arguments

- original_state:

  Original resolution_state data frame

- retry_results:

  Retry pipeline results data frame

- selected_row_indices:

  Integer vector of original row indices that were re-curated

- tags_changed:

  Logical indicating if column tags were changed (default FALSE)

## Value

Updated original_state data frame with retry results merged
