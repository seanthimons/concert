# Map curated data to ToxVal schema

Transforms CONCERT's curated and harmonized data into the 56-column
ToxVal-compatible format with typed NAs and \*\_original audit columns.

## Usage

``` r
map_to_toxval_schema(curated_data, harmonized_data, source_name = NULL)
```

## Arguments

- curated_data:

  Tibble from curation pipeline containing at minimum:

  - dtxsid: DSSTox substance identifier

  - casrn: CAS Registry Number

  - name: Chemical name Optional columns: qualifier, orig_result,
    toxval_type, species_common, etc.

- harmonized_data:

  Tibble from harmonize_units() containing:

  - orig_row_id: Row identifier linking back to curated_data

  - orig_unit: Original unit string before normalization

  - harmonized_value: Numeric value after conversion

  - harmonized_unit: Target canonical unit

  - conversion_factor: Multiplier applied

  - unit_flag: Conversion quality flag

- source_name:

  Optional dataset identifier. Defaults to "user_upload".

## Value

Tibble with 56 ToxVal columns including:

- Mapped values from curated_data and harmonized_data

- Typed NA values for unmapped columns (NA_character\_, NA_real\_)

- source_hash: SHA256 digest of row content

- \*\_original audit columns preserving pre-harmonization values

## Examples

``` r
if (FALSE) { # \dontrun{
curated <- tibble::tibble(
  dtxsid = "DTXSID7020182",
  casrn = "71-43-2",
  name = "Benzene"
)
harmonized <- tibble::tibble(
  orig_row_id = 1L,
  orig_unit = "ug/L",
  harmonized_value = 0.5,
  harmonized_unit = "mg/L",
  conversion_factor = 0.001,
  unit_flag = ""
)
result <- map_to_toxval_schema(curated, harmonized)
} # }
```
