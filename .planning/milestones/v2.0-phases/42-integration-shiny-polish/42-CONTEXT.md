# Phase 42: Integration & Shiny Polish - Context

**Gathered:** 2026-04-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Users see a pre-flight recommendation modal before running the cleaning or harmonization pipeline that shows which steps will fire versus skip, and can edit the media classification table directly in the Harmonize tab with unmatched terms surfaced for user mapping. No new pipeline steps, no new tag types, no changes to cleaning/harmonization logic itself.

</domain>

<decisions>
## Implementation Decisions

### Pre-flight Modal Design
- **D-01:** Checklist with toggles — each pipeline step is a checkbox row showing step name, fire/skip status, and estimated change count. Steps pre-checked based on pre-check results (firing steps checked, skipping steps unchecked). User can manually toggle individual steps on/off before running.
- **D-02:** One unified modal — single modal with sections for Cleaning steps and Harmonization steps. User sees everything at once, one "Run Checked" action.
- **D-03:** Single new "Run Pipeline" button replaces both existing "Run Cleaning" and "Run Harmonization" buttons. Opens the unified pre-flight modal.
- **D-04:** When all pre-checks show 0 estimated changes, skip the modal and show a brief notification: "Pre-flight check: no steps have changes to apply. Run anyway?" with a link to open the full modal if desired.
- **D-05:** Pre-check data comes from existing Phase 37 infrastructure (`precheck_*` functions returning `list(should_run, est_changes)`). Harmonization steps need equivalent pre-checks added (units, duration, dates, media).

### Media Editor UX
- **D-06:** Modal-based editing — media classification table is a read-only DT display. Click a row to open an edit modal (same pattern as existing unit mapping and correction editors in mod_harmonize.R).
- **D-07:** Unmatched media terms appear at the top of the table with a visual indicator (highlighted rows). Clicking opens a modal pre-filled with the unmatched term; user fills in canonical value. Table divided into UNMATCHED section (top) and MAPPED section (below).
- **D-08:** Table columns: term, canonical, source, active (per MEDIT-01).

### Persistence & Re-run Cascade
- **D-09:** Separate user RDS file (`user_media_map.rds`) for user edits, distinct from AMOS-derived `amos_media.rds`. Keeps user customizations isolated from regenerated AMOS cache. Clean upgrade path.
- **D-10:** After saving media edits, show a notification: "Media mappings updated. Re-run harmonization to apply changes?" with a "Re-run now" action link. Non-intrusive, user-initiated re-run.
- **D-11:** Session-local working copy pattern: `media_map_working` initialized from merged user + AMOS maps at session start (same pattern as `unit_map_working` / `corrections_working`).

### AMOS Fallback Integration
- **D-12:** Source column with badge styling — "user" entries show blue badge (editable), "amos" entries show gray badge (read-only). AMOS entries visible in table but can only be overridden by adding a user entry for the same term.
- **D-13:** When user adds a mapping for a term that already exists in the AMOS map, show confirmation: "This term already has an AMOS mapping (canonical: X). Override with your mapping?" Prevents accidental overrides.
- **D-14:** Lookup priority at runtime: user map checked first, AMOS map as fallback (per MEDIT-03). User entry for a term always wins over AMOS entry for the same term.

### Claude's Discretion
- Harmonization pre-check implementation details (what constitutes "nothing to do" for units, duration, dates, media steps)
- Modal styling, button placement, and responsive layout within bslib framework
- DT table rendering options (pagination, search, row highlighting implementation)
- Notification/toast implementation for re-run prompt and empty pre-flight state
- Working copy merge strategy (how user + AMOS maps are combined at session start)
- Badge rendering approach in DT cells (HTML widget, CSS class, or DT callback)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & Roadmap
- `.planning/REQUIREMENTS.md` — RECO-01, RECO-02, MEDIT-01, MEDIT-02, MEDIT-03 requirements
- `.planning/ROADMAP.md` — Phase 42 success criteria (4 criteria)

### Prior Phase Context
- `.planning/phases/37-performance-architecture/37-CONTEXT.md` — D-04/D-05/D-06 (pre-check behavior, est_changes, message logging)
- `.planning/phases/41-media-harmonizer-amos-pipeline/41-CONTEXT.md` — D-07/D-08/D-09/D-10 (media table schema, hierarchy, resolution, unmatched flagging)

### Pre-check Infrastructure
- `R/cleaning_pipeline.R` lines 248-470 — `precheck_*` functions returning `list(should_run, est_changes)`
- `R/cleaning_pipeline.R` lines 1948-2180 — Pre-check calls in `run_cleaning_pipeline()` orchestrator

### Existing Modal/Editor Patterns
- `R/mod_harmonize.R` lines 906-960 — Unit mapping edit modal pattern (showModal/modalDialog)
- `R/mod_harmonize.R` lines 175-200 — Working copy initialization from `data_store$reference_lists`
- `R/mod_harmonize.R` lines 1010-1060 — "Add" button modal pattern
- `R/mod_harmonize.R` lines 1320-1340 — Unmatched term "Add mapping" modal

### Pipeline Trigger Points
- `R/mod_clean_data.R` lines 62-66 — "Run Cleaning" button (to be replaced)
- `R/mod_clean_data.R` lines 130-340 — Cleaning pipeline execution observer
- `R/mod_harmonize.R` lines 74-79 — "Run Harmonization" button (to be replaced)
- `R/mod_harmonize.R` lines 204-622 — Harmonization pipeline execution observer

### Media Harmonizer
- `R/media_harmonizer.R` — `harmonize_media()` function, media map schema
- `inst/extdata/reference_cache/amos_media.rds` — AMOS-derived media term cache

### Reference List Persistence
- `R/cleaning_reference.R` — RDS-based reference list loading/saving pattern

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `precheck_*` functions: 7 pre-check functions already implemented for cleaning steps, returning `list(should_run, est_changes)`. Direct data source for modal.
- `showModal/modalDialog` pattern: 5+ modal implementations in mod_harmonize.R for edit/add operations. Direct template for media editor modals.
- `unit_map_working` / `corrections_working`: Session-local editable copy pattern with one-shot initialization from `data_store$reference_lists`. Direct template for `media_map_working`.
- `rerun_now` link: `R/mod_harmonize.R` line 762 — existing "re-run now" action link that triggers harmonization via `shinyjs::click()`. Template for re-run prompt after media edits.
- `cleaning_reference.R`: RDS load/save infrastructure for reference lists. Template for `user_media_map.rds` persistence.

### Established Patterns
- Modal-based editing: Click row → open modal with pre-filled fields → save → update working copy → notify. Consistent across unit mappings and corrections.
- Reference list lifecycle: Package ships defaults → user edits persist to RDS → session loads merged view → working copy for session edits.
- Pre-check integration: Orchestrator calls `precheck_*` before each step, uses `should_run` to decide, logs skip messages.

### Integration Points
- `mod_clean_data.R`: "Run Cleaning" button replaced with "Run Pipeline" that opens unified pre-flight modal
- `mod_harmonize.R`: "Run Harmonization" button removed; harmonization steps included in unified modal
- New media editor panel/card in Harmonize tab layout
- `data_store$media_map_working`: New reactive value for session-local media map edits
- `data_store$reference_lists`: Gains `media_map` entry (merged user + AMOS at load time)

</code_context>

<specifics>
## Specific Ideas

- The unified pre-flight modal creates a single entry point for both pipelines — this is a workflow simplification, not just a modal wrapper
- Unmatched terms at the top of the media table creates a "fix these first" workflow that naturally guides users to close coverage gaps
- Separate user RDS from AMOS RDS means `scripts/build_amos_media.R` can be re-run freely without clobbering user customizations
- The "confirm override" dialog for AMOS entries prevents accidental loss of curated AMOS mappings while still giving users full control

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 42-integration-shiny-polish*
*Context gathered: 2026-04-27*
