# CONCERT

Chemical Ontology & Nomenclature Crosswalk for Entity Registration & Translation.

CONCERT is an R package and Shiny application for cleaning, harmonizing, and
registering chemical regulatory and benchmark datasets. It helps users import
messy CSV/XLSX files, detect frontmatter, tag chemical and measurement columns,
curate identifiers, harmonize units and media, resolve WQX parameter matches,
and export reviewable ToxVal-compatible outputs.

## Installation

```r
devtools::install()
library(concert)
```

## Launch the App

```r
concert::run_app()
```

For a fixed local port:

```r
concert::run_app(port = 3838, launch.browser = FALSE)
```

## Headless Curation

```r
concert::curate_headless(
  input = "path/to/input.xlsx",
  output = "path/to/output.xlsx",
  tag_map = list(
    chemical_name = "Name",
    casrn = "CASRN"
  ),
  harmonize = TRUE
)
```

## Export Re-Import

CONCERT exports include a `Pipeline Config` sheet with a `concert_export`
marker. Legacy export markers from the former package name are no longer
accepted.
