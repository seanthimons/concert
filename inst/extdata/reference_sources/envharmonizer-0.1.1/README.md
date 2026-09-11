# CSV and Parquet tables

Choose one format for each table. Parquet preserves column types and missing
values directly. CSV is UTF-8; its missing-value token is
`__ENVHARMONIZER_MISSING__`. Empty strings are not missing values. Use the column
types in `table-manifest.json` when importing CSV; do not infer identifier types.
Both formats contain the same rows, columns, and values as the released R tables.

## AMOS

Start with `methods.csv` or `methods.parquet`. Add the assertion tables needed
for your analysis, joining on `amos_method_id`:

| Table | Contents |
|---|---|
| `methods` | Source method records |
| `method_matrices` | Method-to-matrix assertions |
| `method_analytical_assertions` | Method-to-analytical assertions |
| `matrix_terms`, `matrix_edges`, `matrix_synonyms` | Matrix labels, hierarchy, and synonyms |
| `analytical_terms`, `analytical_edges`, `analytical_synonyms` | Analytical labels, hierarchy, and synonyms |
| `method_methodologies_raw`, `method_functional_classes_raw` | Original source assertions |
| `instrument_mentions` | Instrument evidence |
| `concert_media_map` | Optional CONCERT compatibility mapping |

A method can have multiple assertions. Keep these relationships; flattening
them into one row per method loses information or duplicates method records.
The source and ontology versions are recorded in `release-manifest.json`.
See `AMOS-ATTRIBUTION.md` for source attribution.

## ECOTOX

These are mapping tables, not a second ECOTOX database or an export of all
toxicity results. Keep using your source-only ECOTOX DuckDB for results.

| ECOTOX source release | Dictionary | Review evidence |
|---|---|---|
| `ecotox_ascii_06_11_2026.zip` | `lifestage_dictionary` | `lifestage_review` |
| `ecotox_ascii_09_15_2026.zip` | `lifestage_dictionary_09_15_2026` | `lifestage_review_09_15_2026` |

Each name has `.csv` and `.parquet` alternatives. Select the database's exact
recorded release. Match source descriptions through `org_lifestage`; retain
the source rows and columns and mapping provenance. R users can instead call
`envharmonizer::harmonize_lifestage()` for a checked join.

Experimental mappings; not independently reviewed. September applicability
uses June mapping evidence after native code-description parity checks.
Do not relabel the evidence release. Read `ECOTOX-REVIEW.md` and
`ECOTOX-ATTRIBUTION.md` before use.

## Reproducibility

Keep `release-manifest.json`, `table-manifest.json`, `SHA256SUMS`, and the license
and review files with the selected tables. Verify SHA-256 before import.
The release manifest preserves source evidence unchanged; the table manifest
records export hashes, row counts, and CSV types. No RDS files or databases
are included in this export bundle. RDS remains embedded in the R package.

Maintainers generate the bundle offline from the released tables:

```r
source('scripts/export-tables.R')
export_tables('artifacts/table-exports-v0.1.1')
```

The output directory must not already exist. The exporter checks both formats
against the source tables before reporting success. It does not refresh AMOS,
ontologies, ECOTOX, or mapping decisions.
