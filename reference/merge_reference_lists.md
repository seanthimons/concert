# Merge Reference Lists

Merges imported reference lists with existing lists, giving priority to
imported entries on term conflicts (imported wins).

## Usage

``` r
merge_reference_lists(existing_lists, imported_ref_df)
```

## Arguments

- existing_lists:

  List with \$functional_categories, \$stop_words, \$block_patterns, and
  optionally \$strip_terms

- imported_ref_df:

  Combined reference list data frame with type column

## Value

Updated list with merged reference lists
