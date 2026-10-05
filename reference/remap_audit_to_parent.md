# Remap audit trail row IDs from unique-string slice to parent dataset

When a step function runs on a deduplicated slice of a dataframe, its
audit trail contains row IDs 1..n_unique. This function expands those
IDs back to the full set of matching parent rows, producing an audit
trail with correct row IDs relative to the original (parent) dataframe.

## Usage

``` r
remap_audit_to_parent(audit_slice, parent_map)
```

## Arguments

- audit_slice:

  6-column audit tibble from the deduped unique-string slice. Row IDs
  are positions 1..n_unique within the unique slice.

- parent_map:

  Named list where names are character representations of positions in
  the unique slice ("1", "2", ...) and values are integer vectors of ALL
  parent row IDs that mapped to that unique value. Use original row IDs
  when lineage is available, otherwise parent row positions.

## Value

6-column audit tibble with row_id values expanded to parent row IDs.
Preserves all other columns (field, step, original_value, new_value,
reason).
