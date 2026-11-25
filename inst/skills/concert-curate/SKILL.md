---
name: concert-curate
description: Curate a chemical dataset with the CONCERT R package without the Shiny app. Use when asked to curate, clean, resolve, or harmonize a CSV/XLSX of chemical names, CAS numbers, and measurements headlessly. Runs a decide-run-inspect loop until every row is resolved or explicitly flagged, and leaves a replay.R script that reproduces the result in one call.
---

# CONCERT headless curation loop

You edit one file (`decisions.R`). A runner turns it into `status.md`, `pending.csv`, and `replay.R`. Repeat until `status.md` says `done: TRUE`. Never edit R package code to resolve a dataset; every decision lives in `decisions.R`.

## Setup

This skill ships inside the concert package. From any repo, locate it with `Rscript -e 'system.file("skills/concert-curate/SKILL.md", package = "concert")'`; do not copy it per repo.

```bash
Rscript -e 'system.file("scripts/curate_loop.R", package = "concert")'   # locate the runner
Rscript <runner> --template <input.csv> <out_dir> [--harmonize]
```

This writes `<out_dir>/decisions.R` with the detected header row, suggested column tags, the pinned reference-list snapshot, and a commented schema example for every other decision object.

The runner installs the latest concert GitHub release before each run, so it works from any directory. If the runner file itself changed in that release, re-run the locate command once to pick up the new path. If the install fails (read-only library, `--vanilla`, offline) the runner warns and uses the installed concert; set `CONCERT_SKIP_INSTALL=1` to skip the attempt.

## Loop

```bash
Rscript <runner> <out_dir>/decisions.R      # exit 0 = done, exit 2 = rows pending
```

Each run:

1. Read `<out_dir>/status.md`. If it has an `## Error` section, fix the cause in `decisions.R` and re-run.
2. Read `<out_dir>/pending.csv`. One row per unresolved data row. It includes the cleaned name and CAS, CompTox candidates, and, when enabled, PubChem and salt-parent candidates.
3. Add decisions for every pending row (see table below). Prefer a root-cause fix over a per-row pick when one correction clears many rows.
4. Re-run. Curation searches are cached under `<out_dir>/cache/`; changed names or lookup switches require new searches.

Stop after 10 iterations if `pending.csv` is not shrinking. Report what is left and why.

## Decision per pending_type

| pending_type | What it means | Decision object |
|---|---|---|
| `multi_analyte` | Cell names several analytes ("Lead + Zinc"). `suggested_split` shows the parts. | `multi_analyte_resolutions`: `name`, `casrn` (both as shown in `pending.csv`; blank `casrn` matches blank CAS only), `action` (`split`, `keep`, `rename`), optional `value` (rename value, or split parts separated by `;`) and `note` |
| `disagree` | Name and CAS resolved to different DTXSIDs. `candidates` lists `dtxsid | preferredName | tier`. | `review_picks` with the correct `dtxsid`, or `row_flags` if neither candidate is right |
| `suggested` | Scored candidate below the auto-accept bar. `suggested_dtxsid` is CONCERT's pick. | Leave `accept_suggestions <- TRUE` to accept all, or override individual rows with `review_picks` |
| `no_match` | Nothing in CompTox matched. | Fix the name with `value_corrections` or a reference-list override, supply a `review_picks` DTXSID you know, or `row_flags` with `FOLLOW-UP` |
| `identity_drift` | An identity decision in the ledger was recorded against evidence that has since changed (new input, new concert or DSSTox version). The decision was not applied. `drift_decision` shows what it was, `drift_changed_columns` what changed (when the decision carries a snapshot); the rest of the row shows the evidence now. | Review the row again, then use the ledger commands below: `reconfirm` if the decision still holds, `record` to change or withdraw it. |

Row keys are content-based: `name` is the cleaned name, `casrn` the cleaned CAS. Unmatched keys are listed under `## Unmatched decisions` in `status.md`; fix the key rather than adding duplicates.

A measurement that is not one chemical ("Hardness", "Total suspended solids") resolves to a WQX characteristic, not a DTXSID. When concert's `wqx_name` in `pending.csv` is right, confirm it with `row_flags` `VERIFIED`. When another characteristic is right, add a `review_picks` row with `wqx_name` in place of `dtxsid`; the name is checked against the WQX dictionary and an alias becomes its canonical name. Each `review_picks` row carries exactly one of `dtxsid` or `wqx_name`.

A pick or flag covers every row with its `name` (and `casrn`). Rows that clean to the same name sometimes need different answers ("Ammonia, total" and "Ammonia, total (as N)", or one name reported by two sources). Add a column named after an input column, such as `source_label`, to the `review_picks` or `row_flags` table: the row then covers only input rows holding that value. A blank value narrows nothing. Later rows override earlier ones, so a broad row followed by a narrow one works. Do not write a script to apply per-source decisions.

## Identity decision ledger

Row-scoped identity decisions (accept a DTXSID for one source row, or keep it unresolved with a scope) live in a JSON Lines file that `decisions.R` names: `identity_decisions <- "identity_decisions.jsonl"`. Never edit that file and never write a script to change it. Use the runner, after a complete run with the current `decisions.R`:

```bash
Rscript <runner> record <out_dir>/decisions.R batch.csv --by owner
Rscript <runner> reconfirm <out_dir>/decisions.R --expect 3 --note "CAS unchanged; only the preferred name moved" --by owner
```

`batch.csv` has one decision per line: `row_index` (from `pending.csv`), `action` (`accept`, `retain_unresolved`, `withdraw`), `scope`, `conflict`, `selected_dtxsid`, `correspondence` (`TRUE` for `accept`), `reason`, `evidence_reference`; add `name` to pick one part of a split row. The latest line per source row wins, so recording a row again replaces its decision. `--by` names who decided, not who typed. `reconfirm` covers every drifted decision unless `--rows 3,7` narrows it, and refuses when the count is not `--expect`. Both commands write nothing if any decision fails, and both need a re-run to take effect. If the run itself stops on a ledger line (its row no longer exists, or its DTXSID is no longer valid), record a `withdraw` for that `row_index`: a batch of only withdrawals needs no completed run. A `decisions.R` that still holds an R list of decisions is converted once with `Rscript <runner> migrate <out_dir>/decisions.R`.

## PubChem and salt-parent candidates

The template enables `pubchem <- TRUE` and `desalt <- TRUE`. These lookups can take time: PubChem searches each unique unresolved name and fetches synonyms for its CIDs; desalting searches CompTox for eligible parent names. A large unresolved set or changed names can make a run slow. The runner caches unchanged curation searches between runs. Set either switch to `FALSE` in `decisions.R` when its candidates are unnecessary. With `desalt`, resolved rows also get structure-based `parent_*_<workflow>` columns from the chemi standardizer; `desalt_workflows` picks `"qsar-ready"`, `"ms-ready"`, or both (default).

For `no_match` rows, inspect `pubchem_query`, `pubchem_cid_candidates`, `pubchem_dtxsid_candidates`, `parent_name_candidate`, `parent_dtxsid_candidates`, `resolver_dtxsid_candidate`, `resolver_name`, `tied_dtxsids`, and their lookup statuses in `pending.csv`. `tied_dtxsids` lists DTXSIDs that CompTox ranks equally for the name; pick by the analyte the source meant (e.g. acid versus anion). PubChem IDs and parent IDs are leads for review, never accepted resolutions. A parent DTXSID identifies the parent, not its salt. Confirm the correct chemical identity and use `review_picks` only for a verified DTXSID of the original analyte; otherwise correct the name or flag the row `FOLLOW-UP`.

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

`done: TRUE` means no row is pending. It does not mean every match is right. Before reporting:

1. Read `## Low-similarity matches` in `status.md`. These are accepted DTXSIDs whose preferred name barely resembles the input name (past misses: "Total PFAS" to "Total Furans", "COD" to "Total Oxygen Demand", "TKN" to nitrogen gas). For each row add `row_flags` with `VERIFIED` if correct, `review_picks` if wrong, or `FOLLOW-UP` if unsure.
2. Skim the workbook's preferred names once for analogs (methyl vs ethyl, salt vs parent, gas vs ion). Automatic and `accept_suggestions` hits get no other second look.
3. Re-run until the low-similarity section is empty or every row in it is flagged.

Then:

- `<out_dir>/<input>_curated.xlsx` holds the workbook (plus `_toxval.parquet` when harmonized).
- `<out_dir>/mapping.csv` (written when done) is the flat result for a pipeline: one line per row with the source columns, `dtxsid`, `wqx_name`, `preferred_name`, `identity_status`, `decided_by` (`automatic`, `pick`, `accepted_suggestion`, `identity_decision`, `flag`), `row_flag` and `identity_blockers`. Read this; do not write a script to build one.
- `<out_dir>/run_lock.json` records what the run read: a hash of the input file, `decisions.R`, the ledger and every file `decisions.R` names, plus the concert, ComptoxR and DSSTox versions. `Rscript <runner> check <out_dir>/decisions.R` exits 0 when the last run is done and none of that changed, 3 when a re-run is needed. Do not hash inputs yourself.
- For a trial run that leaves the committed outputs alone, add `--out-dir <scratch_dir> --output <scratch_dir>/curated.xlsx`. Do not copy or rewrite `decisions.R` for this.
- `<out_dir>/replay.R` reproduces the run with one `curate_headless()` call. Hand this to the user; it is the deliverable that makes the curation reproducible.

Report: rows resolved by CONCERT, rows you picked, rows you flagged and why, and any reference-list or value corrections you introduced.
