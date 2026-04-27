# Phase 41: Media Harmonizer & AMOS Pipeline - Context

**Gathered:** 2026-04-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can tag columns as Media and have the harmonization pipeline classify environmental media strings against a curated ENVO ontology subset, with AMOS-derived terms supplementing the vocabulary and canonical media values feeding back into ppb/ppm unit routing via `get_media_target()`. No new UI tab, no media editor UI (Phase 42), no recommendation modal (Phase 42), no date/duration changes (Phases 39-40 complete).

</domain>

<decisions>
## Implementation Decisions

### Media Vocabulary Source
- **D-01:** Canonical terms come from a curated ENVO subset (~20-30 terms) relevant to tox/regulatory data, not the full ENVO ontology hierarchy. Each canonical term carries an ENVO ID for traceability.
- **D-02:** The curated subset is expandable — after AMOS extraction reveals what's actually in the data, terms like blood, tissue, diet, etc. are added to close coverage gaps. Iterative vocabulary building.

### AMOS Extraction Strategy
- **D-03:** Keyword/regex extraction from `ComptoxR::chemi_amos_method_pagination()` method descriptions, using the curated ENVO subset as the search vocabulary. Deterministic and auditable.
- **D-04:** Compound/parenthetical media terms in AMOS descriptions (e.g., "water (freshwater)", "sediment (marine)") are expanded out before deduplication.
- **D-05:** Build script (`scripts/build_amos_media.R`) is a discovery pipeline: extract → expand parentheticals → deduplicate → report coverage gaps → output runtime cache. Produces both `inst/extdata/reference_cache/amos_media.rds` (flat term→canonical map) AND a coverage report showing what AMOS terms were unmatched against the ENVO subset.
- **D-06:** Iterative workflow: run build script, review coverage report, expand ENVO subset if needed, re-run. The build script is an analysis tool, not just a cache generator.

### Compound Media Resolution
- **D-07:** `harmonize_media()` uses a hierarchical media table with columns: `term`, `envo_id`, `parent`, `media_category`. Hierarchy is encoded in the table structure via the `parent` column, not via ontology traversal.
- **D-08:** Resolution order: exact match on full string first, then walk up the `parent` column to find the nearest ancestor with a `media_category`. Shallow hierarchy (2-3 levels max).
- **D-09:** `media_category` column holds the top-level routing value (aqueous / solid / air) — this is what `get_media_target()` consumes for ppb/ppm routing.
- **D-10:** Unmatched media terms are flagged as `media_unmatched`, not silently resolved to a component or default. Surfaced for user mapping in Phase 42's editor UI.
- **D-11:** "Freshwater sediment" and similar compound media are first-class entries in the table. Ambiguous multi-match inputs are flagged rather than silently picking one component (per MEDIA-03).

### ppb/ppm Routing Integration
- **D-12:** Three-tier cascade for media context in `harmonize_units()`: (1) per-row canonical media from tagged Media column, (2) manual `media` parameter as fallback, (3) aqueous default. Existing `media_inferred` flag only fires on tier 3 (aqueous default).
- **D-13:** Existing `curate_headless(media=)` parameter becomes a dataset-wide fallback. When a Media column is tagged, per-row canonical media from `harmonize_media()` overrides the manual parameter for matched rows. Unmatched rows fall back to the manual parameter, then to aqueous.
- **D-14:** No breaking changes — existing callers without Media-tagged columns see identical behavior.

### Tag Classification
- **D-15:** `Media` tag added to `study_types` group in `classify_tags()` alongside `StudyDate` (per Phase 40 D-13). Tag Columns dropdown shows Media in the "Study / Contextual" optgroup.

### Pipeline Wiring (Carried Forward)
- **D-16:** Media harmonization results merge into `expanded_curated` BEFORE `map_to_toxval_schema()` — same pattern as duration (Phase 39 D-10/D-11) and dates (Phase 40 D-16).
- **D-17:** Media harmonization slots in as a new stage in the harmonization pipeline (after date parsing, before ToxVal mapping). Stage numbering at Claude's discretion.
- **D-18:** `curate_headless()` gains Stage 3d conditional call for Media-tagged columns, mirroring the date Stage 3c pattern (Phase 40 D-18).
- **D-19:** `harmonize_media()` is dedup-eligible. Media strings are highly duplicative in regulatory datasets. Wrap with `dedup_step()` at the orchestrator level (Phase 37 D-11).

### Claude's Discretion
- Exact set of initial curated ENVO terms and IDs (~20-30 entries)
- Regex patterns for AMOS method description extraction
- Parenthetical expansion logic in build script
- Coverage report format (console output, markdown file, or both)
- Internal implementation of parent-walk resolution in `harmonize_media()`
- Stage numbering and progress bar percentages in `mod_harmonize.R`
- Test structure for MEDIA-03 compound media resolution
- `amos_media.rds` internal schema (columns, types)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & Roadmap
- `.planning/REQUIREMENTS.md` — MEDIA-01 through MEDIA-06, AMOS-01 through AMOS-03 requirements
- `.planning/ROADMAP.md` — Phase 41 success criteria (5 criteria)

### Prior Phase Context
- `.planning/phases/39-duration-conversion/39-CONTEXT.md` — D-10/D-11 (merge before mapper), D-12 (category parameter on harmonize_units)
- `.planning/phases/40-date-parser/40-CONTEXT.md` — D-13 (study_types group), D-16/D-17/D-18 (pipeline wiring pattern)
- `.planning/phases/37-performance-architecture/37-CONTEXT.md` — D-07 (unit-key dedup), D-11/D-12 (dedup as orchestrator wrapper)

### Research (AMOS & Media)
- `.planning/research/STACK.md` §"ComptoxR AMOS Methods" — `chemi_amos_method_pagination()` API signature, extraction pipeline pattern
- `.planning/research/ARCHITECTURE.md` §"AMOS Extraction" — Build-time cache pattern, runtime prohibition
- `.planning/research/PITFALLS.md` §"AMOS corpus staleness" — Stale cache risk and mitigation
- `.planning/research/FEATURES.md` §"Media/Matrix Harmonization" — Feature dependency graph

### Unit Harmonization (ppb/ppm routing)
- `R/unit_harmonizer.R` — `harmonize_units()` (line 286) with `media` parameter, `get_media_target()` (line 194) for ppb/ppm→target unit routing
- `R/curate_headless.R` — `curate_headless()` (line 40) with `media` parameter documentation

### Tag System
- `R/tag_helpers.R` — `classify_tags()` (line 36) with `study_types = c("StudyDate")` (line 41). Media tag adds here.
- `R/tag_dispatch.R` — Tag dispatch helpers, single source of truth
- `R/mod_tag_columns.R` — Tag dropdown rendering with optgroup structure

### Pipeline Integration Points
- `R/mod_harmonize.R` — Stage-based harmonization pipeline, date stage as template for media stage insertion
- `R/curate_headless.R` — Headless harmonization path, Stage 3c date parsing as template for Stage 3d media

### ToxVal Schema
- `R/toxval_mapper.R` — `map_to_toxval_schema()` with `media` field extraction
- `inst/extdata/toxval_schema.rds` — 56-column schema manifest

### Reference Cache Pattern
- `inst/extdata/reference_cache/` — Existing RDS cache directory (unit tables, reference lists). `amos_media.rds` goes here.

### Existing Tests
- `tests/testthat/test-unit-harmonizer.R` — ppb/ppm media routing tests (lines 514-603), media_inferred flag tests (lines 559-577, 702-716)
- `tests/testthat/test-tag-dispatch.R` — Tag classification tests including study_types (lines 166-185)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `harmonize_units(media=)`: Already accepts media parameter. `get_media_target()` maps media strings to ppb/ppm target units. Phase 41 populates this parameter from tagged data instead of manual input.
- `classify_tags()`: Already has `study_types` group with StudyDate. Adding Media is a one-line change.
- `dedup_step()` + `remap_audit_to_parent()`: Phase 37 infrastructure. Media harmonization gets this wrapping for free.
- Duration/date stage wiring in `mod_harmonize.R` and `curate_headless.R`: Direct template for media stage insertion.
- `inst/extdata/reference_cache/` directory and RDS caching pattern: AMOS cache follows the same convention.

### Established Patterns
- Stage-based pipeline in `mod_harmonize.R`: corrections → parse → harmonize → duration → dates → ToxVal map. Media slots in after dates.
- `expanded_curated` construction from `resolution_state` via `orig_row_id` indexing. Media results merge into this before the mapper call.
- Build-time scripts in `scripts/`: `benchmark_pipeline.R` as precedent for standalone analysis scripts. `build_amos_media.R` follows same pattern.
- Reference cache RDS files with provenance tracking (fetch timestamp, source metadata).

### Integration Points
- `mod_harmonize.R` after date stage: Media stage inserts here
- `curate_headless.R` after Stage 3c: Same insertion point for headless path (Stage 3d)
- `classify_tags()`: Gains `"Media"` in `study_types` vector
- `mod_tag_columns.R`: Media appears in "Study / Contextual" optgroup (already exists from Phase 40)
- `harmonize_units()`: No API change — media parameter already exists. Phase 41 auto-populates it.
- `R/media_harmonizer.R`: New file — `harmonize_media()` function
- `scripts/build_amos_media.R`: New file — AMOS extraction/discovery pipeline
- `inst/extdata/reference_cache/amos_media.rds`: New file — AMOS-derived media term cache

</code_context>

<specifics>
## Specific Ideas

- The AMOS build script is a discovery tool, not just a cache generator — run it, review coverage, expand ENVO subset, re-run until satisfied
- Hierarchy via table structure (parent column) gives defensible resolution without ontology engine complexity
- Three-tier media cascade (tagged → manual → aqueous) mirrors how the codebase already handles missing context (flag it, don't guess)
- The curated ENVO subset may need backtracking after seeing actual AMOS media terms — expect iteration between build script output and vocabulary definition

</specifics>

<deferred>
## Deferred Ideas

- Media editor UI with unmatched term surfacing → Phase 42 (MEDIT-01/02/03)
- AMOS-derived terms as fallback behind user-editable map → Phase 42 (MEDIT-03)
- Full ENVO ontology traversal → unnecessary given curated subset approach; revisit only if coverage proves insufficient

None — discussion stayed within phase scope

</deferred>

---

*Phase: 41-media-harmonizer-amos-pipeline*
*Context gathered: 2026-04-27*
