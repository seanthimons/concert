---
name: concert-curate
description: Curate a chemical dataset with the CONCERT R package without the Shiny app. Use when asked to curate, clean, resolve, or harmonize a CSV/XLSX of chemical names, CAS numbers, and measurements headlessly. Runs a decide-run-inspect loop until every row is resolved or explicitly flagged, and leaves a replay.R script that reproduces the result in one call.
---

# CONCERT headless curation loop

You edit one file (`decisions.R`). A runner turns it into `status.md`, `pending.csv`, and `replay.R`. Repeat until `status.md` says `done: TRUE`. Never edit R package code to resolve a dataset; every decision lives in `decisions.R`.

## Setup

```bash
Rscript -e 'system.file("scripts/curate_loop.R", package = "concert")'   # locate the runner
Rscript <runner> --template <input.csv> <out_dir> [--harmonize]
```

This writes `<out_dir>/decisions.R` with the detected header row, suggested column tags, the pinned reference-list snapshot, and a commented schema example for every other decision object.

Run every command from the CONCERT project root so renv loads the current package. An `unused argument` error from `curate_headless()` means an older concert was loaded from another library.

## Loop

```bash
Rscript <runner> <out_dir>/decisions.R      # exit 0 = done, exit 2 = rows pending
```

Each run:

1. Read `<out_dir>/status.md`. If it has an `## Error` section, fix the cause in `decisions.R` and re-run.
2. Read `<out_dir>/pending.csv`. One row per unresolved data row. Columns: `row_index`, `pending_type`, `name`, `casrn`, `consensus_status`, `suggested_dtxsid`, `suggested_split`, `candidates`, `cleaning_flag`.
3. Add decisions for every pending row (see table below). Prefer a root-cause fix over a per-row pick when one correction clears many rows.
4. Re-run. The CompTox search is cached under `<out_dir>/cache/`, so re-runs are cheap unless cleaned names changed.

Stop after 10 iterations if `pending.csv` is not shrinking. Report what is left and why.

## Decision per pending_type

| pending_type | What it means | Decision object |
|---|---|---|
| `multi_analyte` | Cell names several analytes ("Lead + Zinc"). `suggested_split` shows the parts. | `multi_analyte_resolutions`: `row_index`, `action` (`split`, `keep`, `rename`), optional `value` |
| `disagree` | Name and CAS resolved to different DTXSIDs. `candidates` lists `dtxsid | preferredName | tier`. | `review_picks` with the correct `dtxsid`, or `row_flags` if neither candidate is right |
| `suggested` | Scored candidate below the auto-accept bar. `suggested_dtxsid` is CONCERT's pick. | Leave `accept_suggestions <- TRUE` to accept all, or override individual rows with `review_picks` |
| `no_match` | Nothing in CompTox matched. | Fix the name with `value_corrections` or a reference-list override, supply a `review_picks` DTXSID you know, or `row_flags` with `FOLLOW-UP` |

Row keys are content-based: `name` is the cleaned name, `casrn` the cleaned CAS. Unmatched keys are listed under `## Unmatched decisions` in `status.md`; fix the key rather than adding duplicates.

## Root-cause tools, cheapest first

1. `cleaning_steps`: switch off a cleaning step that mangles this dataset (`chiral`, `truncated`, `isotopes`, ...).
2. `reference_list_snapshot$<list>$overrides`: add stop words, block patterns, strip terms, or functional categories. Set `source = "agent"`, `active = TRUE`. `strip_terms` also take `match_mode` (`literal_word`, `literal_exact`, `regex`).
3. `value_corrections`: column-scoped pattern/replacement applied before cleaning. Use for prefixes, suffixes, known-bad CAS values, unit typos.
4. `tag_map`: wrong or missing tags cause most `no_match` rows. Every `Result` needs a `Unit`.

Do not pick a DTXSID you have not seen in `candidates` unless you are certain. Picks are validated against CompTox; unknown IDs abort the run.

## Flags

`row_flags` takes `flag` in `FOLLOW-UP` (needs a human), `BAD` (row is not a chemical or is unusable), `VERIFIED` (you confirmed the existing resolution). Always give a `reason`. Flagged rows leave `pending.csv` and stay flagged in the workbook.

## Harmonization

Set `harmonize <- TRUE` when measurements should be parsed and unit-converted into the ToxVal schema. Then `media`, `source_name`, `corrections`, and the unit/media map snapshots apply. Harmonization warnings appear in the workbook sheets, not in `pending.csv`.

## Done

When `done: TRUE`:

- `<out_dir>/<input>_curated.xlsx` holds the workbook (plus `_toxval.parquet` when harmonized).
- `<out_dir>/replay.R` reproduces the run with one `curate_headless()` call. Hand this to the user; it is the deliverable that makes the curation reproducible.

Report: rows resolved by CONCERT, rows you picked, rows you flagged and why, and any reference-list or value corrections you introduced.
