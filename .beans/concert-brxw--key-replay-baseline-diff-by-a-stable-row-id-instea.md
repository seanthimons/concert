---
# concert-brxw
title: Key replay baseline diff by a stable row id instead of row position
status: todo
type: feature
priority: low
tags:
    - replay
created_at: 2026-07-14T19:41:52Z
updated_at: 2026-07-14T19:41:52Z
---

Follow-up from concert-496k.

## Context
`build_baseline_diff_rows()` / `restore_script_baseline()` persist and replay the automated-vs-final review diff (`baseline_cells`) using **positional** `row_index`. If `nrow(script_baseline_state) != nrow(resolution_state)`, `build_baseline_diff_rows()` returns NULL and the workbook is exported with no baseline metadata, forcing the lossy `empty_review_baseline()` reconstruction on resume.

Today this mismatch is not produced by the pipeline: harmonization preserves row order/count (matches back by `orig_row_id`), and row-splitting (CAS-split, multi-analyte) happens at the cleaning stage before the baseline is captured. So positional alignment currently holds and this is not an active bug.

## Why file it
There is no stable, exported row identifier to fall back on if a future feature ever changes `resolution_state` row count after the baseline snapshot (e.g. a post-curation split, row deletion, or merge). If that happens, positional `baseline_cells` silently break.

## Proposed work
- Add a persistent, unique row-lineage id that survives cleaning -> curation -> harmonization -> export -> import (extend `original_row_id` / `inject_row_lineage` so it reaches `resolution_state` and the Curated Data + Session State sheets).
- Key `build_baseline_diff_rows()` and `restore_script_baseline()` on that id instead of `row_index`, aligning by id and treating split children (no baseline match) as pipeline-produced rather than edits.
- Fall back to positional when the id is absent (older workbooks).

## Not doing now
Deferred deliberately: no current mechanism produces the mismatch, and adding + threading a new persistent column is real scope. Revisit if a post-curation row-count-changing feature lands, or if a workbook is seen with dropped baseline_cells traceable to nrow mismatch (not a null baseline).
