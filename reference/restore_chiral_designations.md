# Restore chiral designation placeholders to original markers

Reverses protect_chiral_designations() by replacing
`###CHIRAL_{TOKEN}###` back to the original chiral marker (e.g.,
\###CHIRAL_PLUS### -\> (+)). Must run AFTER all name cleaning steps and
BEFORE ComptoxR lookup.

## Usage

``` r
restore_chiral_designations(df, name_cols)
```

## Arguments

- df:

  Dataframe with name columns that may contain chiral placeholders

- name_cols:

  Character vector of Name-tagged column names

## Value

List with cleaned_data (tibble) and audit_trail (tibble)
