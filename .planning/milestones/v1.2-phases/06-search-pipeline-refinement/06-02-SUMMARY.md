---
phase: 06-search-pipeline-refinement
plan: 02
subsystem: ui
tags: [transparency, ux, search-feedback]
requirements: [SRCH-01]
dependency_graph:
  requires: [06-01]
  provides: [match-type-column, search-notification]
  affects: [app.R]
tech_stack:
  added: []
  patterns: [reactive-derivation, friendly-labels]
key_files:
  created: []
  modified:
    - path: app.R
      changes: [match_type-column-derivation, search-summary-notification]
decisions:
  - id: D-06-02-01
    summary: "Derive match_type from source_tier_* columns in app.R rather than in R/curation.R"
    rationale: "Keep curation module data-focused; UI transformations belong in app.R"
  - id: D-06-02-02
    summary: "Use 8-second notification duration for tier breakdown"
    rationale: "Balances readability (enough time to read counts) vs. non-intrusive (auto-dismiss)"
  - id: D-06-02-03
    summary: "Position match_type after consensus_status column"
    rationale: "Logical grouping: consensus fields together, then match provenance"
metrics:
  tasks_completed: 2
  tasks_planned: 2
  duration: "< 1 hour"
  completed_date: "2026-03-01"
---

# Phase 06 Plan 02: Search Pipeline UI Transparency Summary

**One-liner:** Added Match Type column to Review Results and tier breakdown notification for search transparency.

## Objective

Add user-facing transparency to the search pipeline by showing which search tier (exact, CAS, starts-with) resolved each row and displaying a tier breakdown notification after curation completes.

## What Was Built

### 1. Match Type Column (Task 1)

**Location:** app.R output$curation_table (lines ~1373-1410)

**Implementation:**
- Derived `match_type` column from `source_tier_*` columns in `data_store$resolution_state`
- Maps internal tier values to friendly labels:
  - `exact` → "Exact Match"
  - `cas` → "CAS Lookup"
  - `starts_with` → "Starts-With"
  - `miss`, `cas_no_match`, `cas_invalid` → "No Match"
- Column positioned after `consensus_status` for logical grouping
- `source_tier_*` columns remain hidden via existing hidden_cols pattern

**Logic:**
```r
# Strategy: Find which source_tier column provided consensus_dtxsid
# If consensus_dtxsid exists, check each source_tier_* column for successful match tier
# If no consensus, fall back to "No Match"
```

### 2. Search Summary Notification (Task 1)

**Location:** app.R observeEvent(input$run_curation) (line ~1256)

**Implementation:**
- Replaced generic "Curation completed successfully!" with tier breakdown:
  ```
  "Search complete: X exact, Y CAS, Z starts-with, W no match"
  ```
- Uses `pipeline_result$search_summary` fields: `n_exact`, `n_cas_valid`, `n_starts_with`, `n_miss`
- 8-second duration for readability without permanent intrusion
- Type "message" for informational (not warning/error) styling

### 3. Bugfix: tag_map → column_tags (Task 1.5)

**Issue:** Task 1 introduced a bug where `tag_map` variable was referenced but didn't exist in scope.

**Root cause:** `run_curation_pipeline()` in R/curation.R uses `column_tags` (the parameter name), not `tag_map`.

**Fix:** Changed all references from `tag_map` to `column_tags` in the search summary notification code.

**Files:** app.R (line ~1256)

**Commit:** ddb373a

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed tag_map → column_tags reference error**
- **Found during:** Task 1 verification
- **Issue:** Code referenced undefined variable `tag_map` in notification message construction
- **Fix:** Changed to `column_tags` to match actual parameter name in `run_curation_pipeline()`
- **Files modified:** app.R
- **Commit:** ddb373a

## Verification Results

### Automated Verification

R source check: PASSED
- All R sources loaded without errors
- No syntax issues detected

### Manual Verification (Checkpoint Task 2)

**User approval:** ✓ Approved with note

**Tested:**
1. Upload chemical inventory with Name and CASRN columns
2. Tag columns
3. Run curation
4. Verified notification shows tier breakdown (e.g., "Search complete: 5 exact, 2 CAS, 1 starts-with, 0 no match")
5. Verified Match Type column visible with friendly labels
6. Verified source_tier_* columns hidden

**User feedback:** "match type dropdown could be filled with choices"
- Noted as future enhancement
- Not a blocker for this plan (Phase 7 covers Review Results UI improvements)

## Commits

| Hash    | Message                                                          | Files         |
|---------|------------------------------------------------------------------|---------------|
| 0996a12 | feat(06-02): add Match Type column and search tier notification | app.R         |
| ddb373a | fix(06-02): correct tag_map reference to column_tags            | app.R         |

## Technical Notes

### Match Type Derivation Logic

The `match_type` column uses a multi-step derivation:

1. **If consensus_dtxsid exists:** Find which `source_tier_*` column has a successful tier value (`exact`, `cas`, `starts_with`)
2. **If no consensus_dtxsid:** Check all `source_tier_*` columns for any successful tier, or default to "No Match"
3. **Tier priority:** First successful tier found wins (relies on column order from curation.R)

This approach handles:
- Multiple tagged columns (Name, CASRN, Other)
- Rows with partial success (some columns match, others don't)
- Complete failures (all tiers are `miss` or `cas_invalid`)

### Notification Timing

8-second duration chosen to balance:
- **Readability:** Users need ~5-7 seconds to read and process tier counts
- **Non-intrusive:** Auto-dismisses before becoming annoying
- **Contextual:** Appears immediately after curation completes, when context is fresh

## Dependencies

**Requires:**
- Plan 06-01: `source_tier_*` columns in `resolution_state` dataframe
- Plan 06-01: `search_summary` in `pipeline_result` with tier counts

**Provides:**
- `match_type` column in Review Results table
- Tier breakdown notification after curation

**Affects:**
- app.R rendering logic (adds one visible column, one notification)

## Success Criteria: Met

- [x] Match Type column present in Review Results with friendly labels
- [x] Search summary notification appears for 8 seconds after curation
- [x] source_tier_* columns hidden from user view
- [x] No DT rendering errors or column index drift
- [x] Visual verification with sample data passed

## Future Enhancements

**From user feedback:**
- Pre-populate Match Type dropdown filter with available choices (deferred to Phase 7 or later)

**Related:**
- Phase 7 will address broader Review Results table UX improvements

## Self-Check: PASSED

**Commits exist:**
- [x] 0996a12 found in git log
- [x] ddb373a found in git log

**Files modified:**
- [x] app.R modified (verified by git log)

**Features implemented:**
- [x] match_type column derivation code present in app.R
- [x] Tier breakdown notification code present in app.R
- [x] column_tags reference corrected (no tag_map references remain)

All claimed artifacts verified.
