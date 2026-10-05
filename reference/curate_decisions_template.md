# Write a starter decisions.R for the agent curation loop

Reads the file, runs frontmatter detection and column tag suggestion,
and writes a decisions file the agent edits between
[`curate_iterate()`](https://seanthimons.github.io/concert/reference/curate_iterate.md)
runs. Every optional decision object is present as a commented schema
example.

## Usage

``` r
curate_decisions_template(input_path, out_dir, harmonize = FALSE)
```

## Arguments

- input_path:

  Path to the CSV/XLSX to curate.

- out_dir:

  Directory for `decisions.R` and all loop outputs.

- harmonize:

  Logical. Pre-set the `harmonize` switch in the template.

## Value

Invisibly, the path to the written decisions file.
