# Flag measurement qualifiers in names

Fraction terms ("Copper, dissolved") and reporting bases ("Nitrate (as
N)") describe a measurement, not a chemical. Appends
`WARNING: measurement qualifier [<terms>]` to `cleaning_flag`; the name
is unchanged. Runs before enclosure stripping so "(total)" is still
visible.

## Usage

``` r
flag_measurement_qualifier(df, name_cols)
```

## Arguments

- df:

  Dataframe with name columns

- name_cols:

  Character vector of Name-tagged column names

## Value

List with cleaned_data (tibble) and audit_trail (tibble)
