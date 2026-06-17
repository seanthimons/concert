---
# concert-i9me
title: Case-by-case resolution path for flagged multi-analytes
status: completed
type: feature
priority: normal
tags:
    - github:issue
created_at: 2026-05-11T22:37:00Z
updated_at: 2026-06-17T13:09:28-04:00
parent: concert-vwkd
---

## Proposal

Currently `flag_multi_analyte()` (step 8, `R/cleaning_pipeline.R:2823`) detects entries with naked `and` / `+` separators and sets `cleaning_flag = "WARNING: potential multi-analyte"` per Design Decision D-11. These warnings surface during review but have no structured resolution path â€” the user must manually edit outside the pipeline.

This feature would add a curation-time step where each flagged multi-analyte is presented to the user with three resolution actions:

1. **Split** â€” Break into separate rows (e.g., `"lead and arsenic"` â†’ two rows: `"lead"`, `"arsenic"`)
2. **Keep** â€” Mark as a legitimate combined analyte (e.g., `"Plutonium-239 and 240 combined"` is a single regulatory measurement)
3. **Rename** â€” Manually edit the value (e.g., normalize `"Thorium-230 and 232"` â†’ user types corrected forms)

Split would reuse the row-expansion machinery from `split_synonyms()` (step 6e), preserving `original_row_id` lineage and generating audit trail entries.

## Pinch Points

### Row expansion timing
Split happens after the main cleaning pipeline has run. Downstream steps (enrichment, DTXSID lookup, deduplication, consensus) must accept new rows injected mid-curation. `split_synonyms()` already handles this at step 6e, but multi-analyte resolution would occur later â€” after isotope expansion (step 7) and flagging (step 8). The pipeline may need a re-enrichment pass for newly split rows.

### Element carry-forward for isotope shorthand
Entries like `"Thorium-230 and 232"` require inferring that `232` means `Thorium-232`. This is a non-trivial parse: the resolver must detect `<Element>-<mass> and <mass>` patterns, carry the element name forward, and produce two canonical isotope names. Edge cases include mixed separators (`"Thorium-230, 232, and 234"`), non-numeric suffixes, and entries where the second token is ambiguous.

### Distinguishing combined analytes from multi-analytes
Some entries are legitimate single analytes that happen to contain `and`/`+`:
- `"Plutonium-239 and Plutonium-240 combined"` â€” a regulatory combined measurement
- `"nitrate + nitrite"` â€” often reported as a single parameter (EPA Method 353.2)
- `"2,4- and 2,6-Dinitrotoluene"` â€” isomer group reference

The resolver cannot auto-classify these; it must present them for human judgment. A "keep as combined" action must also clear the warning flag so it doesn't re-trigger on future pipeline runs.

### Audit trail integrity
Splitting a single row into N rows must produce N audit entries linking back to the original `row_id`. The `split_synonyms()` pattern (`synonym_count`, `synonym_index`, `original_row_id`) is the template, but multi-analyte splits have a different semantic: they aren't synonyms, they're distinct chemicals. The audit `step` and `reason` fields need a distinct label (e.g., `"multi_analyte_split"`).

### Interaction with deduplication
If `"Thorium-232"` already exists elsewhere in the dataset and the user splits `"Thorium-230 and 232"`, the newly created `"Thorium-232"` row becomes a duplicate. The dedup step must run again (or incrementally check) after multi-analyte resolution. This is the same concern synonym splitting has, but it adds another pass.

## Gaps

### No UI for per-row curation decisions
The current review/curation UI presents flagged rows but has no interactive action buttons per row. A resolution UI would need:
- A filtered view of only multi-analyte-flagged rows
- Action buttons (Split / Keep / Rename) per row
- A text input for the Rename case
- Preview of what split would produce before confirming

### No element carry-forward parser
There is no function today that can parse `"Thorium-230 and 232"` into `["Thorium-230", "Thorium-232"]`. `expand_isotope_shortcodes()` handles `th230` â†’ `Thorium-230` but doesn't decompose compound expressions. A new parser would be needed, likely using the existing `isotope_lookup` table for validation.

### No post-resolution re-enrichment path
After splitting, newly created rows lack DTXSID, functional use, and other enrichment data. There is no mechanism to selectively re-enrich a subset of rows. The current pipeline runs enrichment as a batch step; a targeted re-enrichment function would avoid reprocessing the entire dataset.

### Resolution persistence across sessions
If the user resolves multi-analytes but hasn't exported yet, the resolutions must survive session state. The current `data_store` reactiveValues hold cleaned data in memory only. Resolution decisions should be captured in the audit trail so they can be replayed if the pipeline is re-run on the same dataset.

### Flag clearing semantics
When a user chooses "Keep", the `cleaning_flag` WARNING must be cleared or replaced with a resolved status (e.g., `"multi_analyte_kept"`). The current flag column is a simple character field â€” there's no distinction between "unreviewed warning" and "reviewed and accepted". This matters for export filtering and reporting.



## GitHub

- GitHub #40: https://github.com/seanthimons/concert/issues/40

## Resolution

- [x] Added a case-by-case resolver for rows flagged by `flag_multi_analyte()`.
- [x] Supported `Split`, `Keep combined`, and `Rename` actions with `multi_analyte_resolution` audit records.
- [x] Preserved original row lineage for split rows and tracked split part index/count metadata.
- [x] Added a Shiny cleaning-review panel so resolved rows flow into the existing curation pipeline.
- [x] Added a headless `multi_analyte_resolutions` hook so scripted runs can apply the same decisions before curation.
- [x] Prevented kept/renamed/split rows from surfacing again as unresolved multi-analyte warnings in the current cleaned data.
