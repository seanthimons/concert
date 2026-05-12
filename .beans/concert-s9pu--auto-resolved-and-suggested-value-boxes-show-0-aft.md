---
# concert-s9pu
title: Auto-Resolved and Suggested value boxes show 0 after curation
status: completed
type: bug
priority: normal
created_at: 2026-05-11T15:14:19Z
updated_at: 2026-05-11T15:31:44Z
---

After running curation with test_auto_resolve.csv, the Auto-Resolved and Suggested value boxes on Review Results show 0 even though classify_auto_resolve() produces results (confirmed via unit tests and console).

Partially fixed: recalc_consensus_summary() now runs after classify_auto_resolve (e9c8f43), unname() restored on badge lookups (d6c2256). Needs verification after app restart + fresh curation run. If still broken, investigate reactive invalidation chain from data_store$consensus_summary to value box renderUI.

Repro: upload data/test_auto_resolve.csv, tag Chemical Name=Name + CAS Number=CASRN, Run Pipeline, Run Curation, check Review Results value boxes.


## Summary of Changes

Root cause was two-fold:
1. `recalc_consensus_summary()` was not called after `classify_auto_resolve()` â€” fixed in commit e9c8f43
2. `isTRUE(df$.pinned)` on a vector always returns FALSE, inflating disagree count and masking auto_resolved/suggested counts â€” fixed in commit 0c9d662 with vectorized `!is.na(df$.pinned) & df$.pinned`

Both fixes are now on main. Needs human UAT to confirm value boxes populate correctly.
