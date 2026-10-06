# Get started with concert

concert takes messy chemical datasets (CSV or XLSX with report headers,
odd unit strings, inconsistent names) and produces reviewable,
ToxVal-compatible output. It resolves chemical identities against the
EPA CompTox dashboard, harmonizes units and media, and keeps an audit
trail of every change.

You can use it three ways:

1.  **Shiny app**: interactive, step-by-step, with review tables.
2.  **Headless**: one
    [`curate_headless()`](https://seanthimons.github.io/concert/reference/curate_headless.md)
    call from a script.
3.  **Agent loop**:
    [`curate_iterate()`](https://seanthimons.github.io/concert/reference/curate_iterate.md)
    plus a `decisions.R` file, for automated curation.

## Installation

From a repository checkout, restore the locked environment and install:

``` r

renv::restore()
devtools::install()
library(concert)
```

Or install the latest release from GitHub:

``` r

pak::pak("seanthimons/concert")
```

## The pipeline

Every entry point runs the same stages, in the same order:

| Stage | What happens | Key functions |
|----|----|----|
| Ingest | Read the file, find where the data starts, drop frontmatter | [`safely_read_file()`](https://seanthimons.github.io/concert/reference/safely_read_file.md), [`detect_data_start()`](https://seanthimons.github.io/concert/reference/detect_data_start.md), [`extract_clean_data()`](https://seanthimons.github.io/concert/reference/extract_clean_data.md) |
| Tag | Say which columns hold names, CAS numbers, results, units | [`suggest_column_tags()`](https://seanthimons.github.io/concert/reference/suggest_column_tags.md) |
| Clean | Normalize CAS, strip name artifacts, flag multi-analyte cells | [`run_cleaning_pipeline()`](https://seanthimons.github.io/concert/reference/run_cleaning_pipeline.md) |
| Curate | Resolve names and CAS numbers to DTXSIDs via CompTox and WQX | [`run_curation_pipeline()`](https://seanthimons.github.io/concert/reference/run_curation_pipeline.md) |
| Review | Accept suggestions, pick candidates, flag rows | [`resolve_review_row()`](https://seanthimons.github.io/concert/reference/resolve_review_row.md), [`set_row_flags()`](https://seanthimons.github.io/concert/reference/set_row_flags.md) |
| Harmonize | Parse numeric results, convert units, map media, build ToxVal rows | [`parse_numeric_results()`](https://seanthimons.github.io/concert/reference/parse_numeric_results.md), [`harmonize_units()`](https://seanthimons.github.io/concert/reference/harmonize_units.md), [`harmonize_media()`](https://seanthimons.github.io/concert/reference/harmonize_media.md) |
| Export | Write an XLSX workbook with audit sheets and optional parquet | [`write_curation_output()`](https://seanthimons.github.io/concert/reference/write_curation_output.md) |

The Curate stage needs network access to CompTox. Everything else runs
offline from the reference data bundled with the package.

## The Shiny app

``` r

concert::run_app()
```

The app’s tabs follow the pipeline stages:

- **Data Preview** and **Detection Info** show what was read and why the
  header row was chosen. Switch to manual mode if detection is wrong.
- **Tag Columns** pre-fills tag suggestions from column names. Every
  `Result` column needs a paired `Unit` column.
- **Dataset Context** captures site or location metadata for the export.
- **Clean Data** runs the cleaning pipeline and shows the audit trail.
- **Run Curation** queries CompTox and WQX and scores candidates.
- **Harmonize** parses numbers, converts units, and maps media.
- **Review Results** is where you resolve disagreements, accept
  suggestions, and flag rows, then export.

Exports contain a `Pipeline Config` sheet. Uploading an exported
workbook back into the app restores tags, overrides, and reference-list
edits.

For a step-by-step walkthrough with screenshots, see [Curating a dataset
in the
app](https://seanthimons.github.io/concert/articles/app-walkthrough.html).

## Headless in one call

``` r

concert::curate_headless(
  input_path = "path/to/input.xlsx",
  output_path = "path/to/output.xlsx",
  tag_map = list(chemical_name = "Name", casrn = "CASRN", result = "Result", unit = "Unit"),
  harmonize = TRUE
)
```

See
[`vignette("headless-curation")`](https://seanthimons.github.io/concert/articles/headless-curation.md)
for the full option set and the agent loop.

## Where to next

- [`vignette("cleaning-pipeline")`](https://seanthimons.github.io/concert/articles/cleaning-pipeline.md):
  frontmatter detection and name/CAS cleaning, with the audit trail.
- [`vignette("harmonization")`](https://seanthimons.github.io/concert/articles/harmonization.md):
  numeric parsing, unit conversion, and media mapping.
- [`vignette("headless-curation")`](https://seanthimons.github.io/concert/articles/headless-curation.md):
  scripted and agent-driven curation, replay scripts.
