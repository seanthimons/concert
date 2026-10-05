# Load ToxVal schema manifest

Returns a zero-row tibble defining the 56-column ToxVal schema with
proper column types. Use this as a template for creating
ToxVal-compatible output.

## Usage

``` r
load_toxval_schema(cache_dir)
```

## Arguments

- cache_dir:

  Directory for cache files (e.g., "inst/extdata")

## Value

Zero-row tibble with 56 typed columns

## Details

All columns use typed NA values (NA_character\_, NA_real\_,
NA_integer\_) to ensure parquet compatibility and proper column type
inference.

Schema includes:

- Identifiers: source_hash, dtxsid, casrn, name, source_name

- Toxicity values: toxval_type, toxval_numeric, toxval_units, etc.

- Study design: study_type, study_duration\_\*, generation, lifestage

- Species: species_common, species_scientific, strain, sex

- Exposure: exposure_route, exposure_method, critical_effect

- Source/provenance: source, subsource, year, title, author

- Quality: quality, qc_status, priority_id

- Audit columns: \*\_original fields for harmonization tracking
