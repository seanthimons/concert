---
# chemreg-xy1e
title: Fix WQX resolution shadowed by NA-dtxsid exact results
status: completed
type: bug
priority: normal
created_at: 2026-05-06T21:34:54Z
updated_at: 2026-05-06T21:37:57Z
---

Temperature and other WQX-resolvable names fail to get WQX resolution because: (1) CompTox exact search returns a row with dtxsid=NA for names like 'temperature', (2) this row is added to all_results with source_tier='exact', (3) WQX correctly resolves the name later, but map_results_to_rows deduplicates by searchValue using arrange(rank) + distinct(), which picks the earlier NA-dtxsid row over the WQX row. Fix: in map_results_to_rows dedup logic, prefer rows with non-NA resolution (dtxsid or preferredName) over empty rows.

## Summary of Changes

Fixed in `R/curation.R` `map_results_to_rows()` (line 514-518): the dedup logic now sorts by resolution status before rank, so rows with non-NA dtxsid or preferredName (e.g., WQX matches) are preferred over empty CompTox exact-miss rows for the same searchValue.

**Root cause:** CompTox exact search returns a row for every queried name, even when no match is found (dtxsid=NA). This row was added to `all_results` with `source_tier='exact'`. When WQX later resolved the same name, `map_results_to_rows` deduplicated by `arrange(rank) + distinct(searchValue)` and kept the first (NA-dtxsid exact) row, shadowing the WQX result.

**Verified against sswqs.xlsx (46,782 rows, 823 unique analytes):** 101 WQX resolutions now flow through correctly, including 'temperature' as wqx_exact.
