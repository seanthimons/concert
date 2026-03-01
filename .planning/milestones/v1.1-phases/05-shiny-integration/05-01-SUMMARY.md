---
phase: 05-shiny-integration
plan: 01
subsystem: curation-pipeline
tags: [shiny-integration, pipeline-orchestration, migration, ux]
dependency_graph:
  requires: [03-01, 04-02]
  provides: [integrated-pipeline, dedup-preview, progress-tracking]
  affects: [app.R, R/curation.R]
tech_stack:
  added: []
  patterns: [reactive-progress-callback, withProgress-tracking, backward-compat-report]
key_files:
  created: []
  modified: [R/curation.R, app.R]
decisions:
  - id: INTG-01
    summary: "Migrate pipeline functions into R/curation.R instead of sourcing R/prototype_pipeline.R"
    rationale: "Self-contained module reduces dependency complexity; prototype_pipeline.R kept as historical reference only"
  - id: INTG-02
    summary: "Use Shiny withProgress() for pipeline stage tracking instead of custom progress bar"
    rationale: "Built-in withProgress provides consistent UX with incremental updates at each tier; progress_callback updates both withProgress and reactive status field"
  - id: INTG-03
    summary: "Generate backward-compatible curation_report from new pipeline summaries"
    rationale: "Allows existing Review Results tab to work unchanged while new pipeline provides richer consensus data for Plan 02"
  - id: INTG-04
    summary: "Dedup preview fires immediately on apply_tags, not lazily"
    rationale: "User decision: instant feedback before clicking Start Curation; no API calls, just unique counts"
metrics:
  duration_seconds: 257
  tasks_completed: 2
  files_modified: 2
  commits: 2
  completed_date: "2026-03-01"
---

# Phase 05 Plan 01: Pipeline Integration and Progress UX

**One-liner:** Migrated prototype pipeline into self-contained R/curation.R with Shiny-integrated orchestrator, dedup preview, and step-by-step progress tracking.

## What Was Built

Replaced old R/curation.R stub with a fully integrated curation pipeline module:

**R/curation.R (607 lines):**
- Migrated 6 pipeline functions from R/prototype_pipeline.R: `deduplicate_tagged_columns`, `search_exact`, `search_starts_with`, `validate_and_lookup_cas`, `run_tiered_search`, `map_results_to_rows`
- Added `run_curation_pipeline()` orchestrator with progress callbacks for Shiny integration
- Added `get_dedup_preview()` helper for instant dedup counts (no API calls)
- Self-contained module (depends only on R/consensus.R, not prototype_pipeline.R)

**app.R integration:**
- Sourcing order: consensus.R → curation.R (prototype_pipeline.R no longer sourced)
- New reactive fields: `dedup_preview`, `consensus_data`, `consensus_summary`, `resolution_state`, `dtxsid_cols`, `priority_order`
- Dedup preview generated immediately on `apply_tags` (instant feedback)
- Run Curation wired to `run_curation_pipeline()` with `withProgress()` tracking
- Button disabled during execution, re-enabled on completion/error
- Progress messages shown with spinner in `curation_progress` output
- Backward-compatible `curation_report` generated from new summaries for existing Review tab

## Tasks Completed

### Task 1: Replace R/curation.R with migrated pipeline functions and new orchestrator

**Files:** R/curation.R
**Commit:** cfac3c2

**What changed:**
- Deleted old 166-line stub with obsolete `curate_chemical_data()` function
- Replaced with 607-line self-contained module containing all pipeline functions
- Migrated 6 functions verbatim from R/prototype_pipeline.R (lines 19-417)
- Added `run_curation_pipeline()` orchestrator with inline tier orchestration for progress callbacks
- Added `get_dedup_preview()` for tag-apply instant feedback
- No library() calls (packages loaded by load_packages.R)

**Verification:**
- All 8 functions load without error when consensus.R sourced first
- No dependency on prototype_pipeline.R (confirmed via grep)

### Task 2: Wire Run Curation tab with dedup preview and progress

**Files:** app.R
**Commit:** 2d5b751

**What changed:**
- Added `source(here::here("R", "consensus.R"))` before curation.R (required dependency order)
- Extended `data_store` reactiveValues with 6 new fields for consensus/resolution state
- Updated `reset_all_downstream()` to clear new fields
- Modified `observeEvent(input$apply_tags)` to call `get_dedup_preview()` immediately after tagging
- Enhanced `curation_summary` output to show dedup preview counts and API key status badge
- Replaced `observeEvent(input$run_curation)` body:
  - Disable button with `shinyjs::disable("run_curation")`
  - Wrap pipeline call in `withProgress()` with 5 stages (dedup, exact, starts-with/CAS, consensus, completion)
  - Progress callback updates both `withProgress` detail and `data_store$curation_status`
  - Store results in new fields: `consensus_data`, `consensus_summary`, `resolution_state`, `dtxsid_cols`
  - Generate backward-compatible `curation_report` from new summaries for existing Review tab
  - Re-enable button on completion/error via `finally` block
- Added `output$curation_progress` to render progress messages with spinner/badges

**Verification:**
- app.R sources load in correct order: file_handlers.R → data_detection.R → consensus.R → curation.R
- prototype_pipeline.R not sourced (grep confirmed FALSE)
- No Shiny syntax errors (all observeEvent blocks balanced)

## Deviations from Plan

None — plan executed exactly as written.

## Verification Results

**Automated checks passed:**
- All 8 functions present in R/curation.R namespace when loaded after consensus.R
- app.R source order correct (consensus.R before curation.R)
- prototype_pipeline.R not referenced in app.R

**Manual validation:**
- R/curation.R is self-contained (no prototype_pipeline.R dependency)
- Dedup preview logic non-blocking (no API calls, just unique() counts)
- Progress callback pattern compatible with Shiny reactive invalidation
- Backward-compat report structure matches old format (cas_validated, names_exact_match, etc.)

## Key Decisions Made

**INTG-01: Migration over sourcing**
Per user decision in plan frontmatter, migrated functions into R/curation.R instead of sourcing prototype_pipeline.R. This creates a clean separation: prototype_pipeline.R is historical reference only, while R/curation.R is the production runtime module.

**INTG-02: withProgress() for UX**
Used Shiny's built-in `withProgress()` instead of custom progress bar. This provides consistent Bootstrap modal with incremental updates at each tier (dedup → exact → starts-with → CAS → consensus). Progress messages also stored in reactive field for post-completion display.

**INTG-03: Backward-compatible report**
New pipeline produces richer summaries (dedup_summary, search_summary, consensus_summary), but existing Review Results tab expects old `curation_report` format. Generated backward-compatible report structure from new summaries to avoid breaking existing UI while Plan 02 builds new resolution UI.

**INTG-04: Eager dedup preview**
Per user decision, dedup preview fires immediately on `apply_tags`, not lazily on render. This gives instant feedback ("42 unique names, 15 unique CAS") before user clicks Start Curation. No API calls involved — just `unique()` counts.

## Dependencies

**Requires:**
- 03-01 (prototype pipeline functions to migrate)
- 04-02 (consensus logic for classify_consensus, find_dtxsid_cols, init_resolution_state)

**Provides:**
- Integrated pipeline orchestrator (`run_curation_pipeline`)
- Dedup preview helper (`get_dedup_preview`)
- Progress tracking infrastructure (reactive status field + withProgress)
- Backward-compatible curation_report for existing Review tab
- New consensus data fields for Plan 02 resolution UI (consensus_data, dtxsid_cols, resolution_state)

**Affects:**
- app.R Run Curation tab (now calls new pipeline)
- app.R Review Results tab (still works via backward-compat report)
- Future Plan 02 (will consume consensus_data and dtxsid_cols for resolution UI)

## Technical Notes

**Progress callback pattern:**
```r
progress_callback <- function(stage, msg) {
  data_store$curation_status <- msg
  incProgress(0.2, detail = msg)
}
```
The callback updates both `withProgress()` (for modal) and reactive field (for post-completion display). Since `run_curation_pipeline()` runs synchronously, reactive updates don't flush mid-execution, but `incProgress()` does update the modal in real-time.

**Inline tier orchestration:**
The original `run_tiered_search()` was monolithic (returned combined results with no intermediate callbacks). The new `run_curation_pipeline()` orchestrates tiers inline to fire progress callbacks after each stage:
- After exact search: "Exact match: X/Y found, Z falling back..."
- After starts-with: "Starts-with: X more found..."
- After CAS: "CAS validated: X valid, Y invalid..."
- After consensus: "Consensus: X agree, Y disagree, Z partial..."

**Dedup preview optimization:**
`get_dedup_preview()` calls `deduplicate_tagged_columns()` but returns early with just counts. No API calls, no mapping — just `unique()` on tagged column values. This is safe for instant feedback on large datasets.

**Backward-compat report structure:**
```r
list(
  total_rows = nrow(results),
  cas_validated = search_summary$n_cas_valid,
  cas_invalid = dedup_summary$n_cas - search_summary$n_cas_valid,
  names_exact_match = search_summary$n_exact,
  names_fuzzy_match = search_summary$n_starts_with,
  names_no_match = search_summary$n_miss
)
```
Maps new summaries to old field names so existing Review Results value boxes render unchanged.

## Next Steps (Plan 02)

Plan 02 will build Resolution UI:
- Consume `consensus_data` and `dtxsid_cols` from data_store
- Render disagree rows with resolution options
- Implement row-level pin/resolve actions
- Add en masse priority chain UI with drag-and-drop column ordering
- Export fully resolved data with consensus columns

## Files Modified

**Created:** None (all modifications to existing files)

**Modified:**
- `R/curation.R` (148 → 607 lines): Migrated pipeline functions + orchestrator + dedup preview helper
- `app.R` (1318 lines): Added consensus.R source, new reactive fields, dedup preview on apply_tags, new run_curation handler with withProgress, curation_progress output

## Commits

1. **cfac3c2** — feat(05-01): migrate pipeline functions into R/curation.R
   - Replaced old curation.R with 6 migrated functions from prototype_pipeline.R
   - Added run_curation_pipeline() orchestrator with progress callbacks
   - Added get_dedup_preview() helper
   - Self-contained module (no prototype_pipeline.R dependency)

2. **2d5b751** — feat(05-01): wire Run Curation tab with new pipeline and progress
   - Added consensus.R source before curation.R
   - Extended data_store with 6 new reactive fields
   - Dedup preview on apply_tags
   - Run Curation calls run_curation_pipeline() with withProgress()
   - Button disabled during execution
   - Progress messages with spinner
   - Backward-compat report for existing Review tab

## Self-Check

**Files exist:**
```bash
[ -f "R/curation.R" ] && echo "FOUND: R/curation.R" || echo "MISSING: R/curation.R"
[ -f "app.R" ] && echo "FOUND: app.R" || echo "MISSING: app.R"
```

**Commits exist:**
```bash
git log --oneline --all | grep -q "cfac3c2" && echo "FOUND: cfac3c2" || echo "MISSING: cfac3c2"
git log --oneline --all | grep -q "2d5b751" && echo "FOUND: 2d5b751" || echo "MISSING: 2d5b751"
```

**Functions load:**
```bash
Rscript -e "source('R/consensus.R'); source('R/curation.R'); stopifnot('run_curation_pipeline' %in% ls(), 'get_dedup_preview' %in% ls())"
```

Running self-check...

## Self-Check: PASSED

All verifications passed:
- ✓ FOUND: R/curation.R
- ✓ FOUND: app.R
- ✓ FOUND: cfac3c2 (commit 1)
- ✓ FOUND: 2d5b751 (commit 2)
- ✓ PASSED: Functions load correctly (run_curation_pipeline, get_dedup_preview)
