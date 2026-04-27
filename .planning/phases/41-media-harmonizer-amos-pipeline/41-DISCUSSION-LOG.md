# Phase 41: Media Harmonizer & AMOS Pipeline - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-27
**Phase:** 41-media-harmonizer-amos-pipeline
**Areas discussed:** Media vocabulary source, AMOS extraction strategy, Compound media resolution, ppb/ppm routing integration

---

## Media Vocabulary Source

| Option | Description | Selected |
|--------|-------------|----------|
| Curated ENVO subset | Hand-pick ~20-30 ENVO terms relevant to tox data, each with ENVO ID. Manually expandable. | ✓ |
| Full ENVO hierarchy | Download and traverse full ontology tree from ENVO_00010483. Comprehensive but heavy, requires ontology parser. | |
| Data-driven flat table | Build vocabulary empirically from AMOS/ECOTOX/SSWQS. No ENVO IDs, just normalized strings. | |

**User's choice:** Curated ENVO subset
**Notes:** User noted they may need to backtrack and expand the subset after seeing actual AMOS media terms. Expects iterative vocabulary building.

---

## AMOS Extraction Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Keyword/regex extraction | Scan method descriptions for known media terms using ENVO subset as search vocabulary. Deterministic. | ✓ |
| NLP-style chunking | Extract media-related noun phrases, then map to ENVO. Heavier, less deterministic, catches unexpected terms. | |

**User's choice:** Keyword/regex extraction
**Notes:** User identified that AMOS methods contain compound/parenthetical media terms that need expansion and deduplication. Build script should produce both a runtime cache AND a coverage report showing unmatched terms. Iterative workflow: extract → review gaps → expand vocabulary → re-run.

---

## Compound Media Resolution

| Option | Description | Selected |
|--------|-------------|----------|
| Exact match first, then flag | Look up full string, flag unmatched as media_unmatched. No guessing. | |
| Exact match, then component fallback with flag | Try full string, then individual words. Flag as media_partial_match. | |
| Hierarchical resolution via table | Table with parent column encoding shallow hierarchy (2-3 levels). Walk up parent chain. media_category column for routing. | ✓ |

**User's choice:** Hierarchical resolution via table structure
**Notes:** User initially noted full hierarchy "feels the most defensible, but very complex." Agreed that encoding hierarchy via a parent column in a flat table (rather than ontology traversal) provides the defensibility without the complexity. media_category column (aqueous/solid/air) is what ppb/ppm routing consumes.

---

## ppb/ppm Routing Integration

| Option | Description | Selected |
|--------|-------------|----------|
| Tagged column replaces manual parameter | Three-tier cascade: tagged Media → manual media param → aqueous default. media_inferred only on tier 3. | ✓ |
| Tagged column AND manual parameter coexist | Manual param sets dataset-wide default, tagged column overrides per-row. | |
| Tagged column only, remove manual parameter | Breaking change, simplest code but loses backward compat. | |

**User's choice:** Tagged column replaces manual parameter (three-tier cascade)
**Notes:** No breaking changes. Existing curate_headless(media=) callers without Media-tagged columns see identical behavior.

---

## Claude's Discretion

- Exact set of initial curated ENVO terms and IDs
- Regex patterns for AMOS method description extraction
- Parenthetical expansion logic
- Coverage report format
- Internal implementation of parent-walk resolution
- Stage numbering and progress bar percentages
- Test structure for compound media resolution
- amos_media.rds internal schema

## Deferred Ideas

- Media editor UI → Phase 42 (MEDIT-01/02/03)
- AMOS terms as fallback behind user map → Phase 42 (MEDIT-03)
- Full ENVO ontology traversal → unnecessary unless coverage proves insufficient
