---
phase: 41-media-harmonizer-amos-pipeline
plan: "02"
subsystem: media-harmonization
tags:
  - amos
  - envo
  - media-classification
  - build-time-pipeline
dependency_graph:
  requires:
    - inst/extdata/reference_cache/amos_media.rds (curated ENVO subset from Plan 01)
    - ComptoxR API key (ctx_api_key env var)
    - R/media_harmonizer.R (harmonize_media for runtime consumption)
  provides:
    - scripts/build_amos_media.R (AMOS extraction pipeline)
    - inst/extdata/reference_cache/amos_media.rds (enriched: 26 curated + 7 AMOS-derived)
    - refresh_amos_cache() function for manual cache refresh
  affects:
    - harmonize_media() at runtime (reads enriched amos_media.rds via get_media_table())
    - Phase 41 Plan 03 (pipeline wiring uses this enriched cache)
tech_stack:
  added: []
  patterns:
    - Single-pass combined alternation regex (str_extract_all over all descriptions)
    - Vectorized parenthetical expansion (str_match on whole vector, no per-element loop)
    - all_pages=FALSE with large limit for ComptoxR 1.4.0 pagination workaround
    - do.call(c, lapply(..., `[[`, "results")) for list flattening without nested loops
    - vapply with FUN.VALUE=character(2L) for typed two-field extraction in one pass
    - str_extract with longest-first alternation for fuzzy substring inheritance
key_files:
  created:
    - scripts/build_amos_media.R
  modified:
    - inst/extdata/reference_cache/amos_media.rds
decisions:
  - "all_pages=FALSE required for ComptoxR 1.4.0: all_pages=TRUE returns 7400 pages with 0 records each; all_pages=FALSE with limit=10000 returns all 7400 records in one page"
  - "API signature is limit/offset/all_pages (not start/rows/verbose as documented in plan context -- actual formals inspected at runtime)"
  - "7 AMOS-derived terms added: solid, marine, atmospheric, aqueous, lake, river, ocean -- broad vocabulary terms found in AMOS not mapped to curated ENVO IDs but included as amos_derived for Phase 42 editor surfacing"
  - "Combined alternation pattern (curated + broad vocab, longest-first sort) enables single-pass extraction without per-term outer loop"
metrics:
  duration: "~25 minutes (including API debugging iterations)"
  completed: "2026-04-27"
  tasks_completed: 1
  files_created: 1
  files_modified: 1
  lines_written: 368
---

# Phase 41 Plan 02: AMOS Media Extraction Pipeline Summary

**One-liner:** Standalone AMOS extraction pipeline fetching 7,400 EPA CompTox method records, extracting media terms via single-pass combined regex, and enriching the ENVO vocabulary cache from 26 to 33 terms.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create AMOS build script with extraction, expansion, and cache write | afa3c3f | scripts/build_amos_media.R, inst/extdata/reference_cache/amos_media.rds |

## What Was Built

### scripts/build_amos_media.R (368 lines)

Standalone discovery pipeline with 7 numbered sections:

- **Section 0 (Configuration):** `here::here()` root, `stopifnot` guards for ComptoxR/stringr/dplyr/tibble, loads curated-only base from existing amos_media.rds
- **Section 1 (Fetch):** `ComptoxR::chemi_amos_method_pagination(limit=10000, offset=0, all_pages=FALSE)` fetches all 7,400 AMOS records; flattens nested list with `do.call(c, lapply(..., "results"))`; extracts description + matrix text fields in one `vapply` pass (2-row character matrix)
- **Section 2 (Extract):** Builds single alternation regex covering curated terms + 38 broad media vocabulary terms, sorted longest-first; `str_extract_all` over all 11,675 text fields in one vectorized sweep
- **Section 3 (Expand):** `expand_parenthetical_vec()` vectorizes over the whole extracted term vector using `str_match()` — handles "X (Y)" → base, qualifier, qualifier+base without per-element loop
- **Section 4 (Match):** Exact match via `%in%` + vectorized `match()`; fuzzy inheritance via `str_extract(unmatched_raw, combined_pattern)` — single call returns best curated substring match per unmatched term
- **Section 5 (Build):** Merges curated_refreshed + amos_entries with `dplyr::bind_rows` + `dplyr::distinct(term, .keep_all=TRUE)` (curated wins on collision)
- **Section 6 (Write + Report):** `saveRDS` to `inst/extdata/reference_cache/amos_media.rds`; coverage report printed to console via single `message(paste(..., collapse="\n"))`
- **Section 7 (Refresh):** `refresh_amos_cache(force=FALSE, max_age_days=30)` checks fetch_timestamp age and re-sources the script if stale

### inst/extdata/reference_cache/amos_media.rds (enriched)

| Metric | Value |
|--------|-------|
| Total terms | 33 |
| envo_curated | 26 (unchanged from Plan 01) |
| amos_derived | 7 (solid, marine, atmospheric, aqueous, lake, river, ocean) |
| fetch_timestamp | 2026-04-27T16:49:34 (all 33 rows) |
| media_category domain | aqueous, solid, air |

Coverage report output:
```
AMOS terms extracted:    23
Matched to ENVO subset:  23 (100.0%)
Unmatched (gaps):        0
```

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed ComptoxR API signature mismatch**
- **Found during:** Task 1 first run
- **Issue:** Plan context specified `chemi_amos_method_pagination(start=0, rows=10000, verbose=FALSE)` but actual ComptoxR 1.4.0 formals are `limit`, `offset`, `all_pages`. Script failed immediately with "unused arguments".
- **Fix:** Changed call to `chemi_amos_method_pagination(limit=10000, offset=0, all_pages=FALSE)`. Inspected formals with `formals(ComptoxR::chemi_amos_method_pagination)` to confirm.
- **Files modified:** scripts/build_amos_media.R
- **Commit:** afa3c3f

**2. [Rule 1 - Bug] Fixed all_pages=TRUE returning empty results**
- **Found during:** Task 1 second run
- **Issue:** `all_pages=TRUE` with `limit=10000` returned 7,400 pages with 0 records each (ComptoxR 1.4.0 pagination behaviour). `all_pages=FALSE` with same limit returns all 7,400 records in a single page.
- **Fix:** Changed to `all_pages=FALSE`. Added comment documenting this ComptoxR 1.4.0 behaviour for future maintainers.
- **Files modified:** scripts/build_amos_media.R
- **Commit:** afa3c3f

**3. [Rule 1 - Bug] Fixed API response structure (nested list, not data.frame)**
- **Found during:** Task 1 structure inspection
- **Issue:** Plan context referenced `nrow(amos_raw)` and column-name detection assuming a data.frame response. Actual response is a nested list: `result[[page]]$results[[record]]$field`.
- **Fix:** Replaced data.frame column detection with `do.call(c, lapply(..., "results"))` flattening and `vapply` two-field extraction. Used `$description` and `$matrix` fields (confirmed from response inspection).
- **Files modified:** scripts/build_amos_media.R
- **Commit:** afa3c3f

## Known Stubs

None. The amos_media.rds cache is fully populated with real AMOS-derived terms and real fetch_timestamp. The 7 AMOS-derived rows with NA canonical_term/envo_id are intentional — these are broad vocabulary terms (solid, marine, etc.) not present in the curated ENVO subset. They are not stubs; they are coverage gap candidates for Phase 42's editor UI.

## Threat Surface Scan

No new network endpoints introduced. The AMOS fetch occurs at build-time only (never at runtime), consistent with T-41-04 disposition. The `tryCatch` wrapper satisfies T-41-05 (DoS). Coverage report prints to console only (T-41-06 accepted). `fetch_timestamp` column satisfies T-41-07 provenance tracking.

## Self-Check: PASSED

| Check | Result |
|-------|--------|
| scripts/build_amos_media.R exists | FOUND |
| inst/extdata/reference_cache/amos_media.rds exists | FOUND |
| ComptoxR references >= 2 | FOUND (6) |
| saveRDS present | FOUND |
| refresh_amos_cache function | FOUND |
| fetch_timestamp references | FOUND (5) |
| COVERAGE REPORT text | FOUND |
| expand_parenthetical present | FOUND |
| stopifnot ComptoxR guard | FOUND |
| source = "amos_derived" | FOUND |
| dplyr::distinct(term, .keep_all = TRUE) | FOUND |
| amos_media.rds has both envo_curated and amos_derived rows | FOUND (26 + 7) |
| fetch_timestamp non-NA for all 33 rows | FOUND |
| Commit afa3c3f exists | FOUND |
| air format exits cleanly | PASS |
