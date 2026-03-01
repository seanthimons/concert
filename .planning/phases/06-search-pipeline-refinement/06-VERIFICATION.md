---
phase: 06-search-pipeline-refinement
verified: 2026-03-01T20:30:00Z
status: passed
score: 9/9 must-haves verified
re_verification: false
---

# Phase 6: Search Pipeline Refinement Verification Report

**Phase Goal:** Improve curation accuracy via optimized search tier order and expanded tag participation
**Verified:** 2026-03-01T20:30:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| #   | Truth                                                                                      | Status     | Evidence                                                                                                   |
| --- | ------------------------------------------------------------------------------------------ | ---------- | ---------------------------------------------------------------------------------------------------------- |
| 1   | Exact-miss Name values flow to CAS validation before starts-with                          | ✓ VERIFIED | R/curation.R:513-540 — Tier 2 calls validate_and_lookup_cas(missed_names) before Tier 3 starts-with       |
| 2   | Starts-with tier only receives values that failed both exact and CAS tiers                | ✓ VERIFIED | R/curation.R:542-577 — starts-with operates on still_missed after CAS fallback, not original missed_names |
| 3   | Starts-with tier skips values shorter than 3 characters                                   | ✓ VERIFIED | R/curation.R:544 — sw_candidates = still_missed[nchar(still_missed) >= 3]                                  |
| 4   | Other tagged column values are included in unique_names and searched via full tier chain  | ✓ VERIFIED | R/curation.R:19,44-48 — other_cols extracted, included in searchable_cols for unique_names                |
| 5   | Other column results create dtxsid_Other columns that consensus auto-detects              | ✓ VERIFIED | R/consensus.R:18 — find_dtxsid_cols() uses grep("^dtxsid_", ...) pattern (auto-detects dtxsid_Other)      |
| 6   | User sees a Match Type column in Review Results showing which search tier resolved each row | ✓ VERIFIED | app.R:1402-1437 — match_type column derived from source_tier_* with friendly labels                       |
| 7   | Match Type uses friendly labels: Exact Match, CAS Lookup, Starts-With, No Match           | ✓ VERIFIED | app.R:1393-1400 — tier_label_map maps internal tiers to friendly labels                                   |
| 8   | User sees a transient notification after search with tier breakdown counts                | ✓ VERIFIED | app.R:1257-1268 — showNotification with tier counts, 8-second duration                                    |
| 9   | source_tier_* columns remain hidden in the DT table                                       | ✓ VERIFIED | app.R:1537 — hidden_cols includes grep("^source_tier_", names(df))                                        |

**Score:** 9/9 truths verified

### Required Artifacts

| Artifact                          | Expected                                                        | Status     | Details                                                                                           |
| --------------------------------- | --------------------------------------------------------------- | ---------- | ------------------------------------------------------------------------------------------------- |
| R/curation.R                      | Reordered tier chain (exact → CAS → starts-with)               | ✓ VERIFIED | Lines 493-577: Tier 1 exact, Tier 2 CAS on misses, Tier 3 starts-with with 3-char filter         |
| R/curation.R                      | Other tag extraction via other_cols                             | ✓ VERIFIED | Lines 19, 44-48: other_cols extracted, combined with name_cols in searchable_cols                 |
| tests/test_prototype_pipeline.R   | Tests for tier reorder and Other tag participation             | ✓ VERIFIED | Lines 271-312: 3 Other tag tests; line 318-328: 3-char filter test                                |
| app.R                             | Match Type column derivation, DT rendering, search notification | ✓ VERIFIED | Lines 1402-1437: match_type derivation; 1257-1268: notification; 1537: source_tier_* hidden       |

### Key Link Verification

| From                                                | To                                               | Via                                                        | Status     | Details                                                                                    |
| --------------------------------------------------- | ------------------------------------------------ | ---------------------------------------------------------- | ---------- | ------------------------------------------------------------------------------------------ |
| R/curation.R deduplicate_tagged_columns()           | R/curation.R run_curation_pipeline() tier chain  | unique_names includes Other column values                  | ✓ WIRED    | Line 44: searchable_cols = c(name_cols, other_cols); line 461: dedup_result called        |
| R/curation.R run_curation_pipeline() CAS tier       | R/curation.R validate_and_lookup_cas()           | missed_names fed to CAS validation before starts-with      | ✓ WIRED    | Line 515: validate_and_lookup_cas(missed_names) called in Tier 2                          |
| app.R output$curation_table                         | R/curation.R source_tier_* columns               | Derives match_type from source_tier columns in resolution_state | ✓ WIRED    | Lines 1402-1434: match_type derived via sapply over source_tier_* columns                 |
| app.R observeEvent(input$run_curation)              | R/curation.R search_summary                      | Reads pipeline_result$search_summary for notification      | ✓ WIRED    | Lines 1259-1262: notification uses search_summary fields (n_exact, n_cas_valid, etc.)     |

### Requirements Coverage

| Requirement | Source Plan     | Description                                                                                        | Status      | Evidence                                                                                            |
| ----------- | --------------- | -------------------------------------------------------------------------------------------------- | ----------- | --------------------------------------------------------------------------------------------------- |
| SRCH-01     | 06-01, 06-02    | Search tier order is exact → CAS → starts-with (starts-with moved to last resort)                 | ✓ SATISFIED | R/curation.R lines 493-577: Tier reorder implemented; tests/test_prototype_pipeline.R: tier tests  |
| SRCH-02     | 06-01           | "Other" tagged columns are searched against CompTox using the full search chain                   | ✓ SATISFIED | R/curation.R lines 19,44-48: Other columns included in unique_names; tests: Other tag tests        |
| SRCH-03     | 06-01           | "Other" column DTXSID results participate equally in consensus classification                     | ✓ SATISFIED | R/consensus.R line 18: find_dtxsid_cols() auto-detects dtxsid_Other (no code changes needed)       |

**Orphaned requirements:** None — all requirements mapped to Phase 6 in REQUIREMENTS.md are addressed by plans.

### Anti-Patterns Found

| File                          | Line | Pattern                   | Severity | Impact                                         |
| ----------------------------- | ---- | ------------------------- | -------- | ---------------------------------------------- |
| app.R                         | 100  | placeholder = "No file..." | ℹ️ Info  | Legitimate UI placeholder text, not anti-pattern |

**No blocker or warning anti-patterns found.**

### Human Verification Required

#### 1. Visual Match Type Column Display

**Test:** Upload chemical inventory with Name and CASRN columns, tag columns, run curation, verify Match Type column visible in Review Results table

**Expected:** Match Type column appears after consensus_status with friendly labels (Exact Match, CAS Lookup, Starts-With, No Match)

**Why human:** Visual layout and column positioning require human inspection of rendered DT table

#### 2. Tier Breakdown Notification

**Test:** Run curation and observe notification at top-right of app

**Expected:** Notification displays "Search complete: X exact, Y CAS, Z starts-with, W no match" for 8 seconds, then auto-dismisses

**Why human:** Notification timing, visibility, and readability require human observation

#### 3. Other Tag Functionality End-to-End

**Test:** Tag a column as "Other" (e.g., supplier codes or synonyms), run curation, verify Other column values appear in search and consensus

**Expected:**
- Other column values searched via full tier chain
- dtxsid_Other column appears in resolution_state
- Other results participate in consensus classification with equal vote weight

**Why human:** End-to-end flow across multiple modules requires integrated testing

#### 4. CAS Fallback Precision Improvement

**Test:** Upload file with Name column containing CAS numbers (e.g., "67-64-1"), run curation

**Expected:** Name values that are valid CAS numbers resolve via CAS Lookup (Tier 2) rather than fuzzy starts-with matching

**Why human:** Real-world CAS-in-Name scenario validation requires actual CompTox API calls

### Verification Notes

**Automated verification:**
- All tests pass (49 passed, 4 skipped for missing API key, 0 failures)
- R source loads without errors
- Commits verified in git log (a0e71bd, b162928, 0996a12, ddb373a)
- Key patterns verified via grep/inspection

**Test coverage:**
- deduplicate_tagged_columns: 6 existing tests + 3 new Other tag tests
- Tier reorder: 1 new 3-char filter test
- CAS fallback: Verified via code inspection (API tests skipped without key)
- Match Type: Verified via code inspection (UI testing requires human)

**Wiring verification:**
- deduplicate_tagged_columns called in run_curation_pipeline (line 461)
- validate_and_lookup_cas called in Tier 2 CAS fallback (line 515)
- match_type derives from source_tier_* columns (lines 1402-1434)
- search_summary used in notification (lines 1259-1262)

**No gaps found** — all must-haves verified at all three levels (exists, substantive, wired).

---

_Verified: 2026-03-01T20:30:00Z_
_Verifier: Claude (gsd-verifier)_
