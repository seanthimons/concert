# Build Export Sheets

Converts CONCERT pipeline state into a named list of data frames ready
for Excel export via writexl::write_xlsx().

## Usage

``` r
build_export_sheets(
  raw,
  resolution_state,
  consensus_summary,
  cleaning_audit,
  reference_lists,
  column_tags,
  detection,
  file_info,
  enrichment_cache = NULL,
  detected_data = NULL,
  cleaned_data = NULL,
  toxval_output = NULL,
  harmonize_audit = NULL,
  site_manifest = NULL,
  site_alias_map = NULL,
  script_baseline_state = NULL,
  media_map = NULL,
  media_results = NULL,
  ignored_identifier_cols = character(),
  review_decision_evidence = NULL,
  identity_decisions = NULL,
  candidate_validation = NULL,
  review_reconciliation = NULL,
  candidate_review = NULL,
  source_identifier_evidence = NULL,
  identifier_diagnostics = NULL,
  toxval_identity_mode = c("lookup", "accepted"),
  cleaning_steps = NULL
)
```

## Arguments

- raw:

  Original uploaded data frame

- resolution_state:

  Curated data with consensus_dtxsid, consensus_status

- consensus_summary:

  List with n_agree, n_disagree, etc.

- cleaning_audit:

  Data frame with audit trail (may be NULL)

- reference_lists:

  List with \$functional_categories, \$stop_words, \$block_patterns, and
  \$strip_terms

- column_tags:

  Named list of all applied column tags.

- detection:

  List with \$method, \$confidence

- file_info:

  List with \$name, \$size

- enrichment_cache:

  Enrichment cache data frame (may be NULL)

- detected_data:

  Data frame after header detection/extraction. When provided, this is
  written to Raw Data instead of the headerless ingest snapshot.

- cleaned_data:

  Data frame produced by the Clean Data workflow (may be NULL). When
  provided, a Cleaned Data sheet is included.

- toxval_output:

  Tibble with 56 ToxVal columns from map_to_toxval_schema(), or NULL
  (default). When NULL, the ToxVal Output sheet contains a placeholder
  note row.

- harmonize_audit:

  Tibble with numeric measurement harmonization audit rows, or NULL
  (default). When provided, an additional Harmonization Audit sheet is
  appended.

- site_manifest:

  Optional curated site/location manifest from Dataset Context. When
  provided and non-empty, a Site Manifest sheet is included.

- site_alias_map:

  Optional Dataset Context raw-label alias map. When provided and
  non-empty, a Site Alias Map sheet is included and the Site Manifest is
  rebuilt from these mappings.

- script_baseline_state:

  Optional automated resolution state captured before Review Results
  edits. When provided, cells that differ from `resolution_state` are
  persisted as `baseline_cell` records in Session State so re-imported
  sessions can regenerate replay review overrides.

- media_map:

  Effective media map, including user overrides.

- media_results:

  Row-level media identity, routing and original-value audit.

- ignored_identifier_cols:

  Deliberately unused identifier metadata columns.

- review_decision_evidence:

  Portable immutable decision evidence.

- identity_decisions:

  Explicit structured source-identity decisions.

- candidate_validation:

  Structured candidate-validation outcomes.

- review_reconciliation:

  Optional reconciliation report.

- candidate_review:

  Optional candidate-validation report.

- source_identifier_evidence:

  Optional source-ID evidence report.

- identifier_diagnostics:

  Optional unused/source-ID diagnostics.

- toxval_identity_mode:

  Portable ToxVal identity policy, lookup or accepted.

- cleaning_steps:

  Optional applied named logical cleaning-step mask.

## Value

Named list of data frames with sheet names as keys

## Details

The Curated Data sheet marks `needs_review = TRUE` for
error/unresolvable identities, pending `FOLLOW-UP` flags, incoming
`needs_review = TRUE` values, and unreviewed WQX-only candidates,
including exact, alias, and fuzzy matches. To complete WQX identity
review, use
[`set_row_flag()`](https://seanthimons.github.io/concert/reference/set_row_flag.md)
with `"VERIFIED"` (or `row_flags` in
[`stage_review()`](https://seanthimons.github.io/concert/reference/stage_review.md)),
or explicitly accept a WQX identity in Review Results, which records
`consensus_source = "manual_wqx"`. These outcomes resolve the WQX
requirement, but do not clear a separate incoming review requirement,
pending `FOLLOW-UP`, or error/unresolvable status. `BAD` alone does not
create or clear a review requirement.
