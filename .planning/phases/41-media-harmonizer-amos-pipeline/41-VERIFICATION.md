---
phase: 41-media-harmonizer-amos-pipeline
verified: 2026-04-27T18:30:00Z
status: gaps_found
score: 3/5
overrides_applied: 0
gaps:
  - truth: "A column tagged Media routes through harmonize_media() in the Shiny pipeline"
    status: failed
    reason: "dedup_step() is called with harmonize_media as step_fn, but dedup_step expects fn(df,...) -> list(cleaned_data, audit_trail). harmonize_media expects fn(character_vector, orig_row_id) -> tibble. This crashes at runtime whenever a Media column is tagged and Run Harmonization is clicked. Confirmed in cleaning_pipeline.R:220 (step_fn receives df_unique data frame) and :225 (accesses result$cleaned_data which is NULL on a flat tibble)."
    artifacts:
      - path: "R/mod_harmonize.R"
        issue: "dedup_step(harmonize_media, input_df, dedup_cols = media_cols_pre[1]) at line ~349 will crash: harmonize_media receives a data frame, and result$cleaned_data on the returned tibble is NULL"
      - path: "R/curate_headless.R"
        issue: "dedup_step(harmonize_media, input_df, dedup_cols = media_cols_pre[1]) at line 342 has the same contract mismatch"
    missing:
      - "Replace dedup_step(harmonize_media, ...) with a direct call: media_col_values <- as.character(input_df[[media_cols_pre[1]]]); media_tibble <- harmonize_media(raw_media = media_col_values, orig_row_id = seq_len(nrow(input_df)))"
      - "Applies to both R/mod_harmonize.R (media pre-stage ~line 349) and R/curate_headless.R (Stage 3d ~line 342)"

  - truth: "A column tagged Media routes through harmonize_media() in the headless pipeline"
    status: failed
    reason: "Same dedup_step contract mismatch as the Shiny pipeline. Additionally, Stage 3d (media harmonization) executes AFTER Stage 3 (unit harmonization) in curate_headless.R. The three-tier cascade check at line 252 ('media' %in% names(input_df)) is always FALSE when Stage 3 runs because input_df$media is only populated later in Stage 3d. Per-row media context never reaches harmonize_units() in the headless path."
    artifacts:
      - path: "R/curate_headless.R"
        issue: "Stage 3d block (lines 337-358) runs AFTER Stage 3 harmonize_units call (line 257). media_for_harmonize at line 252 always falls back to the scalar media parameter because input_df$media does not exist yet."
    missing:
      - "Move Stage 3d (lines 337-358) to before Stage 3 (before line 241) in curate_headless.R so input_df$media is populated before harmonize_units() is called"
      - "Also fix the dedup_step contract mismatch (see first gap)"
      - "After moving Stage 3d before Stage 3, the cascade at line 252 will correctly pick up per-row media_category from the tagged column"

human_verification:
  - test: "Run Harmonization with a Media-tagged column in the Shiny UI after gap fixes"
    expected: "Pipeline completes without error; matched/unmatched notification shown; ppb values route to mg/L (aqueous) or mg/kg (solid) based on tagged media values"
    why_human: "Requires uploading a file, tagging a column as Media, clicking Run Harmonization, and inspecting the QC dashboard and harmonized values in the UI"
---

# Phase 41: Media Harmonizer & AMOS Pipeline — Verification Report

**Phase Goal:** Users can tag columns as Media and have the harmonization pipeline classify environmental media strings against the ENVO ontology, with AMOS-derived terms supplementing the vocabulary and canonical media values feeding back into ppb/ppm unit routing.
**Verified:** 2026-04-27T18:30:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| #  | Truth | Status | Evidence |
|----|-------|--------|----------|
| 1  | harmonize_media() maps raw media strings to canonical ENVO terms | VERIFIED | R/media_harmonizer.R:124 exports harmonize_media(). 62 tests pass. Exact match, parent-walk, and unmatched paths all tested. |
| 2  | Compound media like 'freshwater sediment' are first-class entries | VERIFIED | amos_media.rds has freshwater sediment as a curated entry with media_category="solid". Test at line 117 confirms exact match with media_flag="". |
| 3  | A column tagged Media routes through harmonize_media() in the Shiny pipeline | FAILED | dedup_step() contract mismatch: harmonize_media receives a data frame but expects a character vector; result$cleaned_data returns NULL on the tibble output. Runtime crash confirmed by code review CR-01. |
| 4  | A column tagged Media routes through harmonize_media() in the headless pipeline | FAILED | Same dedup_step crash as Shiny. Additionally, Stage 3d runs AFTER Stage 3 in curate_headless.R (line 337 vs line 241), so per-row media_category never populates input_df$media before harmonize_units() is called. WR-01 from code review. |
| 5  | AMOS extraction pipeline produces enriched amos_media.rds with fetch timestamp | VERIFIED | scripts/build_amos_media.R (368 lines) ran successfully. amos_media.rds contains 33 terms (26 envo_curated + 7 amos_derived). fetch_timestamp="2026-04-27T16:49:34" on all 33 rows. |

**Score:** 3/5 truths verified

### Deferred Items

None identified.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `R/media_harmonizer.R` | harmonize_media() with ENVO-based classification | VERIFIED | 199 lines. Exports harmonize_media(), get_media_table(), walk_parent(). system.file() cache loading. |
| `tests/testthat/test-media-harmonizer.R` | Comprehensive tests | VERIFIED | 263 lines, 24 test_that blocks across 9 sections. All 62 assertions pass. |
| `inst/extdata/reference_cache/amos_media.rds` | Curated ENVO vocabulary (26+ entries) | VERIFIED | 33 rows: 26 envo_curated + 7 amos_derived. 620 bytes. All 7 schema columns present. |
| `scripts/build_amos_media.R` | AMOS extraction pipeline | VERIFIED | 368 lines. All 7 sections present. Fetches 7,400 AMOS records, extracts terms, expands parentheticals, writes cache. |
| `R/tag_helpers.R` | Media in study_types | VERIFIED | Line 41: study_types <- c("StudyDate", "Media") |
| `R/mod_tag_columns.R` | Media in dropdown | VERIFIED | Line 93: "Media" = "Media" in Study / Contextual optgroup |
| `R/mod_harmonize.R` | Media pre-stage + media_for_harmonize | STUB/WIRED | Code exists and is wired, but dedup_step contract mismatch means it crashes at runtime. The intent is correct; the call site is broken. |
| `R/curate_headless.R` | Stage 3d + three-tier cascade | STUB/WIRED | Code exists, but Stage 3d runs after Stage 3 (wrong order), and same dedup_step crash applies. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| R/media_harmonizer.R | inst/extdata/reference_cache/amos_media.rds | system.file() in get_media_table() | WIRED | Line 17: system.file("extdata/reference_cache/amos_media.rds", package = "chemreg") |
| R/media_harmonizer.R | R/unit_harmonizer.R | media_category output feeds get_media_target() | WIRED | harmonize_media() produces media_category column with values "aqueous"/"air"/"solid" matching get_media_target() contract |
| scripts/build_amos_media.R | inst/extdata/reference_cache/amos_media.rds | saveRDS() at end of pipeline | WIRED | Line 310: saveRDS(enriched_media, cache_path) |
| R/mod_harmonize.R | R/media_harmonizer.R | harmonize_media() call in media pre-stage | NOT_WIRED | dedup_step(harmonize_media, ...) call at line ~349 has contract mismatch — passes data frame where character vector expected; crashes before harmonize_media can execute |
| R/curate_headless.R | R/media_harmonizer.R | harmonize_media() call in Stage 3d | NOT_WIRED | Same dedup_step contract mismatch at line 342; Stage 3d also runs after Stage 3 |
| R/mod_harmonize.R | R/unit_harmonizer.R | media = media_for_harmonize in harmonize_units() Stage 3 | PARTIAL | media parameter is present in the call at line ~414, but media_for_harmonize will always be NULL because dedup_step crashes before media_tibble can be populated |
| R/curate_headless.R | R/unit_harmonizer.R | media = media_for_harmonize in Stage 3 | PARTIAL | media_for_harmonize logic at line 252 checks "media" %in% names(input_df), but input_df$media is only set in Stage 3d which runs after Stage 3; always falls back to scalar media parameter |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|-------------------|--------|
| R/mod_harmonize.R media pre-stage | media_tibble$media_category | dedup_step(harmonize_media, ...) | No — crash before data flows | HOLLOW — dedup_step contract mismatch prevents data from reaching media_for_harmonize |
| R/curate_headless.R Stage 3d | input_df$media | dedup_step(harmonize_media, ...) | No — crash before data flows | HOLLOW — same contract mismatch; Stage 3 runs before Stage 3d anyway |
| harmonize_media() core | canonical_out/category_out | amos_media.rds via get_media_table() | Yes — 33-term vocabulary loaded and matched | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| harmonize_media("water") returns aqueous | devtools::test(filter='media') | 62/62 PASS | PASS |
| harmonize_media("freshwater sediment") returns first-class entry | Same test run | Section 4 tests pass | PASS |
| amos_media.rds has both source types | readRDS inspection | 26 envo_curated + 7 amos_derived | PASS |
| Shiny cold boot (from 41-03-SUMMARY) | Task 3 cold boot | "Listening on" reported | PASS (human-verified during execution) |
| dedup_step(harmonize_media) with data frame arg | Code review CR-01 | Contract mismatch; result$cleaned_data = NULL | FAIL |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| MEDIA-01 | 41-01 | harmonize_media() returning tibble with orig_row_id, raw_media, canonical_media, media_flag | SATISFIED | Implementation returns 6-column tibble (adds envo_id and media_category beyond REQUIREMENTS.md spec, which is additive not breaking). REQUIREMENTS.md signature differs from ROADMAP/PLAN spec — implementation follows more detailed PLAN spec. |
| MEDIA-02 | 41-01 | Media vocabulary derived from ENVO ontology | SATISFIED | amos_media.rds curated from ENVO: water (ENVO:00002006), soil (ENVO:00001998), etc. All 26 curated entries have ENVO IDs. |
| MEDIA-03 | 41-01 | Compound media types are first-class entries | SATISFIED | freshwater sediment is a curated entry with parent=sediment, media_category=solid, not derived from component picking. Test Section 4 verifies media_flag="" (exact match, not parent_walk). |
| MEDIA-04 | 41-03 | Media tag type added to classify_tags(); Harmonize tab recognizes Media-tagged columns | PARTIALLY SATISFIED | Tag added to study_types (not metadata_types as REQUIREMENTS.md states — plan says study_types and that is what was implemented). Shiny recognizes Media-tagged columns via has_study check. However media harmonization itself crashes at runtime due to CR-01. |
| MEDIA-05 | 41-03 | Canonical media values feed back into harmonize_units() as media parameter, closing ppb/ppm routing loop | BLOCKED | media_for_harmonize variable exists in both pipelines, but it is always NULL in Shiny (dedup_step crash) and always falls back to scalar parameter in headless (Stage 3d after Stage 3 + crash). ppb/ppm routing with per-row media tags does not work. |
| MEDIA-06 | 41-03 | curate_headless() harmonize block gains Stage 3d for Media-tagged columns | BLOCKED | Stage 3d code block exists at lines 337-358 but: (1) same dedup_step crash, (2) runs after Stage 3 so media routing is ineffective even if crash is fixed. |
| AMOS-01 | 41-02 | build_amos_media.R calls chemi_amos_method_pagination(), extracts media terms from ~7,500 method descriptions | SATISFIED | Script ran successfully. 7,400 AMOS records fetched. Media terms extracted via single-pass regex. 7 AMOS-derived terms added to cache. |
| AMOS-02 | 41-02 | Results cached as inst/extdata/reference_cache/amos_media.rds, committed, never called at runtime | SATISFIED | amos_media.rds committed to git (present in worktree). get_media_table() uses system.file() read-only at runtime — never fetches from API. |
| AMOS-03 | 41-02 | Cache includes fetch timestamp; refresh_amos_cache() for explicit manual refresh with staleness warning | SATISFIED | All 33 rows have fetch_timestamp="2026-04-27T16:49:34". refresh_amos_cache(force, max_age_days) at lines 342-368 checks age and warns before re-sourcing. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| R/mod_harmonize.R | ~349 | dedup_step(harmonize_media, input_df, ...) — harmonize_media does not conform to dedup_step step_fn contract (expects df->list(cleaned_data, audit_trail), gets char->tibble) | BLOCKER | Crashes the entire harmonization pipeline when a Media column is tagged. Shiny error notification shown but media classification never executes. |
| R/curate_headless.R | 342 | Same dedup_step contract mismatch as mod_harmonize.R | BLOCKER | Crashes curate_headless() when harmonize=TRUE and Media column is tagged. |
| R/curate_headless.R | 337 vs 241 | Stage 3d (media) runs AFTER Stage 3 (units). media_for_harmonize at line 252 checks names(input_df) for "media" column that doesn't exist yet. | BLOCKER | Even after fixing the crash, per-row media routing will not work in headless pipeline until stage order is corrected. |
| R/media_harmonizer.R | 158-160 | match_idx <- lookup_hash[normalized] — indexing named vector by NA produces unsuppressed warning | WARNING | Emits R warning on NA inputs. Tests pass because warnings don't fail test assertions, but callers may see unexpected console output. |
| R/mod_tag_columns.R | 137 | validate_tag_pairing result computed but never used | WARNING | Users receive no notification about Result/Unit pairing violations. Silent UX gap. |

### Human Verification Required

#### 1. End-to-end Media tag pipeline (after gap fixes)

**Test:** Upload a CSV with a media column (values: "water", "soil", "air"). Tag it as Media. Tag another column as Result, another as Unit (units including ppb). Click Run Harmonization.
**Expected:** Media pre-stage notification shows matched/unmatched counts. ppb values route correctly: water rows -> mg/L (aqueous), soil rows -> mg/kg (solid). expanded_curated$media is populated before ToxVal export.
**Why human:** Requires live Shiny session with real file; ppb routing correctness requires inspecting per-row harmonized_unit values in the QC output.

### Gaps Summary

Two blocking gaps prevent full goal achievement. Both stem from the same root cause: the code review finding CR-01 (dedup_step contract mismatch) and WR-01 (Stage 3d ordering) from `41-REVIEW.md`.

**Root cause:** `dedup_step()` (R/cleaning_pipeline.R:184) requires its `step_fn` to accept a data frame and return `list(cleaned_data, audit_trail)`. This contract was designed for cleaning pipeline steps. `harmonize_media()` has a different contract: it accepts a character vector and returns a flat tibble. Calling `dedup_step(harmonize_media, ...)` passes a data frame where a character vector is expected, and then tries to access `result$cleaned_data` on a flat tibble (returns NULL), crashing at `df_remapped <- result$cleaned_data[key_to_unique_idx, ]`.

**Shiny path (Truth 3):** dedup_step crashes in mod_harmonize.R media pre-stage. tryCatch catches it and shows an error notification, but `media_for_harmonize` stays NULL. Unit harmonization proceeds with NULL media context (aqueous default) rather than per-row context.

**Headless path (Truth 4):** Same dedup_step crash in curate_headless.R Stage 3d. Additionally, even if the crash were fixed, Stage 3d runs at lines 337-358 while Stage 3 runs at lines 241-262. The media_for_harmonize cascade at line 252 checks `"media" %in% names(input_df)` — this is always FALSE because input_df$media is only set in Stage 3d (later). Per-row media routing in harmonize_units never activates.

**Fix required:**

```r
# Replace dedup_step(harmonize_media, ...) with direct call in both files:
media_col_values <- as.character(input_df[[media_cols_pre[1]]])
media_tibble <- harmonize_media(
  raw_media = media_col_values,
  orig_row_id = seq_len(nrow(input_df))
)
```

And in curate_headless.R, move Stage 3d block to before Stage 3 (before line 217/241).

The three truths that PASS — harmonize_media() core function (Truth 1), compound media handling (Truth 2), and AMOS pipeline/cache (Truth 5) — are fully functional. The 24-test suite passes cleanly (62 assertions). The vocabulary, classification logic, tag infrastructure, and dropdown UI are all correct. Only the pipeline call-site wiring is broken.

---

_Verified: 2026-04-27T18:30:00Z_
_Verifier: Claude (gsd-verifier)_
