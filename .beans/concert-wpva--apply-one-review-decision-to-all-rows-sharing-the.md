---
# concert-wpva
title: Apply one review decision to all rows sharing the same name + CAS structure
status: todo
type: feature
priority: normal
tags:
    - github:issue
    - github:55
created_at: 2026-07-20T22:50:04Z
updated_at: 2026-07-20T22:50:50Z
---

## Problem

Regulatory tables repeat a substance once per guidance value — e.g. in `nwqs_concert_staging.csv`, GenX appears at rows 107/108/293 (MCL / MCLG / Health Advisory) and PFBS at 139/140/334, each with identical analyte + CAS. In the consolidated "Rows Needing Review" surface every duplicate is flagged independently, so the same split decision must be staged N times.

## Proposal

When a review decision is staged for a row, offer to apply it to all rows sharing the same `(name, CAS structure)` key, mapping the resolution back to every matching parent row — the same lineage strategy used by name/CAS curation dedup: `deduplicate_tagged_columns()` / `dedup_key_map` (`R/curation.R:21`). Search/decide once per unique key, fan back to all rows via the key map.

## Design questions

- **Sameness key**: name + set of CAS values (confirmed with user). Confirm primary Name field only vs all Name cols; CAS structure as ordered list vs set.
- **UI**: an "apply to all matching rows" checkbox on the stage panel; guard so it does not clobber rows the user intends to treat differently.
- **Lineage**: reuse `dedup_key_map` so split children map back to the correct parent rows.

## Context

Follow-up to the review-surface consolidation (branch `refactor/consolidate-review-resolution`). Sameness rule confirmed with user 2026-07-20. Engine already in place: `resolve_review_row()` / `apply_review_resolutions()` (`R/cleaning_pipeline.R`).
