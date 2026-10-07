# CONCERT <img src="man/figures/logo.png" align="right" height="139" alt="Concert hex sticker" />

Chemical Ontology & Nomenclature Crosswalk for Entity Registration & Translation.

CONCERT is an R package and Shiny application for cleaning, harmonizing, and
registering chemical regulatory and benchmark datasets. It helps users import
messy CSV/XLSX files, detect frontmatter, tag chemical and measurement columns,
curate identifiers, harmonize units and media, resolve WQX parameter matches,
and export reviewable ToxVal-compatible outputs.

## Installation

```r
# install.packages("pak")
pak::pak("seanthimons/concert")
```

GitHub-only dependencies (ComptoxR and a pinned reactable revision) are
installed automatically from `Remotes` in `DESCRIPTION`.

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

Names that CompTox leaves unresolved are looked up in the chemi resolver. Its hits
are review candidates and are checked against a local copy of the public DSSTox
database. That copy is about 800 MB, so CONCERT never downloads it unprompted;
without it, hits are marked `unverified`. To install it once and keep it current:

```r
options(concert.dsstox_install = TRUE)  # or run ComptoxR::dss_install() yourself
```

For agent-driven curation, the package ships a runner script and a skill:

```r
system.file("scripts/curate_loop.R", package = "concert")
system.file("skills/concert-curate/SKILL.md", package = "concert")
```

## Export Re-Import

CONCERT exports include a `Pipeline Config` sheet with a `concert_export`
marker. Legacy export markers from the former package name are no longer
accepted.

## Development

From a checkout, start R (4.5.1) in the repository root; renv bootstraps on
first launch. Restore the locked environment, which includes test dependencies:

```r
renv::restore()
devtools::load_all()
```

After deliberately changing dependencies, run `renv::snapshot()` and commit
`renv.lock`. `renv::status()` checks for drift.

To benchmark the review table on the 8,216-row case:

```r
source("scripts/benchmark_review_results.R")
benchmark_review_results()
run_review_benchmark_app()
```

Source identifiers can be configured explicitly in headless workflows with
`tag_map = list(chemical_name = "Name", source_dtxsid = "DTXSID")`.
The `DTXSID` role validates IDs through EPA CompTox chemical details and retains
raw values, normalized candidates, validation status, authority, and timestamp
as review evidence. Registry membership does not establish correspondence to the
source name or chemical scope and does not automatically assign consensus.
Unavailable validation remains distinct from a definitive missing record.

Retained identifier columns without this role produce unused-column diagnostics.
Use `ignored_identifier_cols = "dtxsid_metadata"` to deliberately keep an identifier
column as metadata. This configuration is preserved in generated replay scripts
and workbook Pipeline Config. Raw columns named `dtxsid` or `dtxsid_*` remain
input data and cannot become lookup votes through their names. `Other` retains
its generic name-search behavior; it does not provide source ID validation.
