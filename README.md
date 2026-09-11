# Concert <img src="man/figures/logo.png" align="right" height="139" alt="Concert hex sticker" />

Chemical Ontology & Nomenclature Crosswalk for Entity Registration & Translation.

CONCERT is an R package and Shiny application for cleaning, harmonizing, and
registering chemical regulatory and benchmark datasets. It helps users import
messy CSV/XLSX files, detect frontmatter, tag chemical and measurement columns,
curate identifiers, harmonize units and media, resolve WQX parameter matches,
and export reviewable ToxVal-compatible outputs.

## Installation

From a checkout, start R in the repository root and restore the locked environment
(R 4.5.1). The first session bootstraps renv automatically.

```r
renv::restore()
devtools::install()
library(concert)
```

The lockfile includes development/test dependencies. After deliberately changing
dependencies, run `renv::snapshot()` and commit `renv.lock`; `renv::status()` checks
for drift. `DESCRIPTION` pins the experimental reactable server-paging revision
and declares its V8 dependency. Review filters preload 100 choices and search the
full server-held column; empty columns stay in exports but are omitted from the
review table. Page size and column visibility update without rebuilding the table.
The header checkbox selects the current page; selections are retained across pages
for batch actions. Data edits refresh the server's table snapshot.

To measure the 8,216-row review case or run it interactively:

```r
source("scripts/benchmark_review_results.R")
benchmark_review_results()
run_review_benchmark_app()
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
