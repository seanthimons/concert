# Phase 47: Pipeline Reordering, Threshold Control & Starts-With Toggle - Context

**Gathered:** 2026-05-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Reorder the curation search chain so WQX matching fires before CompTox starts-with, expose the WQX fuzzy threshold as a configurable slider in the pre-flight modal, and make the starts-with tier opt-in (off by default). Both settings must also be exposed in the headless API.

</domain>

<decisions>
## Implementation Decisions

### Search Chain Ordering
- **D-01:** New tier order: Exact → CAS → WQX → Starts-with. WQX receives all names that failed exact+CAS (no minimum character filter — it's a local dictionary lookup with no API cost).
- **D-02:** Starts-with only receives names still unresolved after WQX, even when the starts-with toggle is on. WQX-resolved names never enter the starts-with batch (satisfies SC-5).

### Pre-flight Modal Layout
- **D-03:** Add a new accordion section titled "Search Settings" below the existing cleaning steps accordion in the pre-flight modal (`mod_clean_data.R`). This section contains the WQX threshold control and the starts-with toggle.
- **D-04:** WQX threshold control is a `sliderInput` with a companion `numericInput` showing the exact value. Range 0.50–1.00, step 0.01, default 0.85.
- **D-05:** Starts-with toggle is a switch/checkbox, off by default (per TOG-01). When off, the pipeline skips starts-with entirely (per TOG-02).

### Headless API
- **D-06:** Add two named top-level arguments to `curate_headless()`: `wqx_threshold = 0.85` and `starts_with = FALSE`. These match the modal defaults.
- **D-07:** `run_curation_pipeline()` also gains these parameters and passes `wqx_threshold` through to `match_wqx()` and gates the starts-with tier on the `starts_with` flag.

### Claude's Discretion
- Internal wiring of how the pre-flight modal values are passed from UI → server → `run_curation_pipeline()`
- Whether the slider and numeric input are synced via `observe()` or `updateSliderInput()`/`updateNumericInput()`
- Notification/progress message text for the reordered tiers

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Pipeline Code
- `R/curation.R` — Contains `run_curation_pipeline()` with the current tier sequence (lines 620–925). This is the primary file to modify for reordering.
- `R/wqx_matching.R` — Contains `match_wqx()` which already accepts a `threshold` parameter (line 21).
- `R/curate_headless.R` — Contains `curate_headless()` which needs new arguments (lines 63–76 for current signature).

### UI Code
- `R/mod_clean_data.R` — Contains the pre-flight modal (lines 146–300 area). New "Search Settings" accordion section goes here.
- `R/mod_run_curation.R` — Contains the curation execution module. May need to pass new params through.

### Requirements
- `.planning/REQUIREMENTS.md` — ORD-01, ORD-02 (ordering), TOG-01, TOG-02 (toggle), CONF-01, CONF-02 (threshold)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `match_wqx(threshold=)` parameter already exists — no new WQX matching logic needed, just pass the user's value through
- Pre-flight modal accordion pattern (`bslib::accordion`, `bslib::accordion_panel`) already established in `mod_clean_data.R`
- `preflight_checks` reactiveVal pattern can be extended with search settings

### Established Patterns
- Pipeline tiers are inline in `run_curation_pipeline()` (not dispatched via a separate function) — new WQX position follows the same inline pattern
- Pre-flight modal collects settings via `input$*` and passes them into the pipeline call
- `curate_headless()` uses simple named arguments (not config lists) for all parameters

### Integration Points
- `run_curation_pipeline()` is called from both `mod_run_curation.R` (Shiny path) and `curate_headless()` (headless path) — both callers need to pass new params
- The `progress_callback` stages in `run_curation_pipeline()` need reordering to match the new tier sequence
- `search_summary` list in pipeline return value already has `n_wqx` — no schema change needed

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 47-pipeline-reordering-threshold-control-starts-with-toggle*
*Context gathered: 2026-05-06*
