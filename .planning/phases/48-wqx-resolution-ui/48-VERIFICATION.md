---
phase: 48-wqx-resolution-ui
verified: 2026-05-07T00:00:00Z
status: gaps_found
score: 3/5
overrides_applied: 0
gaps:
  - truth: "Review Results table shows a wqx_confidence column with the Jaro-Winkler score for rows resolved via WQX fuzzy matching"
    status: failed
    reason: "wqx_confidence is added to wqx_rows in curation.R but silently dropped by map_results_to_rows(), which only pre-allocates and writes 5 hard-coded columns (dtxsid, preferredName, searchName, rank, source_tier). The column is present in lookup_deduped but never read or assigned to df. resolution_state has no wqx_confidence column; the colDef guard is always FALSE; the WQX Conf. column never appears in the table; the confidence score in the modal always falls back to NA_real_."
    artifacts:
      - path: "R/curation.R"
        issue: "map_results_to_rows() lines 543-579 allocates only 5 vectors and writes only 5 columns; wqx_confidence in lookup_deduped is never read. Single-column path (line 566-571) must add wqx_conf_vec <- rep(NA_real_, input_rows), fill it in the inner loop, and assign df$wqx_confidence <- wqx_conf_vec."
    missing:
      - "Add wqx_conf_vec pre-allocation in map_results_to_rows() for-col loop (line 548 area)"
      - "Fill wqx_conf_vec[ridx] from lookup_deduped$wqx_confidence[match_pos] inside inner for-i loop (guarded by presence check)"
      - "Assign df$wqx_confidence <- wqx_conf_vec in single-tag-col branch (line 566)"
      - "Handle multi-tag-col suffix branch analogously (line 572)"
human_verification:
  - test: "Verify WQX Conf. column appears in Review Results table after curation"
    expected: "Upload a dataset with chemical names that produce WQX fuzzy matches. After curation, navigate to Review Results. The 'WQX Conf.' column should be visible with decimal scores (e.g. 0.87) for fuzzy-matched rows and blank cells for exact/alias rows."
    why_human: "Requires a live Shiny session with a real WQX-matching dataset. Automated checks can only verify code structure; actual column appearance requires runtime verification with real data."
  - test: "Verify confidence score appears in WQX Review modal for fuzzy rows"
    expected: "After fixing WR-01, click Review on a fuzzy-matched WQX row. The context card should show a 'Confidence Score' row with a decimal value. For exact/alias rows, the Confidence Score row should be absent."
    why_human: "Requires live session and data; depends on WR-01 being fixed first."
  - test: "Verify wqx_override_name persists in Excel export after override action"
    expected: "Override a WQX match via type-ahead. Download Excel. The Curated Data sheet should contain the wqx_override_name column with the user-selected canonical name on the overridden row."
    why_human: "Export correctness requires a live session; export_helpers.R passes resolution_state through directly (no explicit exclude of wqx_override_name) but this must be confirmed at runtime."
  - test: "Verify rejected WQX rows show unresolvable status and needs_review=TRUE in Excel export"
    expected: "Reject a WQX match. Download Excel. The rejected row should have consensus_status='unresolvable' and needs_review=TRUE on the Curated Data sheet."
    why_human: "Export recalculates needs_review from consensus_status in export_helpers.R:43, so this should work correctly, but the recomputation behavior needs runtime confirmation."
---

# Phase 48: WQX Resolution UI — Verification Report

**Phase Goal:** Users can inspect WQX fuzzy match confidence, reject bad matches, search for the correct canonical WQX name, and have overrides persist through export
**Verified:** 2026-05-07
**Status:** gaps_found
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths (from ROADMAP.md Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Review Results table shows a wqx_confidence column with the Jaro-Winkler score for rows resolved via WQX fuzzy matching | FAILED | wqx_confidence computed and added to wqx_rows in curation.R:761-765, but map_results_to_rows() (lines 543-579) only writes 5 hard-coded columns — wqx_confidence never reaches resolution_state. The colDef guard at mod_review_results.R:767 is always FALSE. |
| 2 | User can type into a search input on a WQX-matched row and see matching WQX canonical names appear as type-ahead suggestions | VERIFIED | observeEvent(wqx_review_click) at line 1743 shows modal with selectizeInput("wqx_typeahead"), then calls updateSelectizeInput(server=TRUE) with full WQX dictionary after showModal. JS handler at line 297-300 dispatches wqx_review_click on button click. |
| 3 | User can select a type-ahead result to override a bad WQX fuzzy match, and the row reflects the new canonical name | VERIFIED | observeEvent(wqx_modal_confirm) at line 1891 reads input$wqx_typeahead, writes wqx_override_name via group_rows loop. derive_resolution_html uses effective_wqx_name = ifelse(!is.na(wqx_override), wqx_override, pref_name) at line 148. |
| 4 | User can reject a WQX fuzzy match and mark the row unresolvable without selecting an alternative | VERIFIED | observeEvent(wqx_reject_click) at line 1925 sets consensus_status[r] <- "unresolvable" and needs_review[r] <- TRUE for all group rows. Null-check on wqx_modal_row_idx guards against orphan fires. The "Reject Match" button fires wqx_reject_click via onclick JS. |
| 5 | Exported Excel and Parquet files include the user's WQX override or unresolvable status on the affected rows | UNCERTAIN (human) | export_helpers.R:41 passes resolution_state directly to curated_data_sheet; only .pinned and .manual_entry are removed (line 45); wqx_override_name is not in the exclude list so it flows through. For rejected rows, export_helpers.R:43 recomputes needs_review from consensus_status == "unresolvable" — correct. Parquet export is headless-only (harmonize=TRUE path in curate_headless.R). Runtime confirmation needed. |

**Score: 3/5 truths verified** (SC-1 failed due to WR-01 data-loss bug; SC-5 uncertain pending human verification)

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `R/curation.R` | wqx_confidence column in wqx_rows tibble | PARTIAL | wqx_confidence correctly computed in wqx_rows (line 761-765) and enters combined_results. Dropped by map_results_to_rows() before returning resolved_df. |
| `R/mod_review_results.R` | Review button HTML, JS handler, wqx_confidence colDef, modal observers | VERIFIED | Contains: wqx-review-btn (2x), wqx_review_click (3x), wqx_modal_confirm (4x), wqx_reject_click (2x), WQX Conf. (1x), wqx_override_name (7x), effective_wqx_name (3x), Review WQX Match (1x), wqx_typeahead (5x). All observers present and substantive. |
| `tests/testthat/test-mod-review-helpers.R` | Unit tests for wqx_confidence and Review button rendering | STUB (integration gap) | 18 tests present and passing. Tests in Group 4 inline the ifelse formula directly rather than calling the pipeline — WR-01 (column dropped by mapper) is invisible to the test suite. No test calls run_curation_pipeline or map_results_to_rows to assert wqx_confidence in output. |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| R/curation.R (wqx_rows tibble) | R/mod_review_results.R (wqx_confidence colDef) | wqx_confidence column propagated through map_results_to_rows → resolution_state | NOT_WIRED | wqx_confidence enters combined_results but map_results_to_rows() never reads or writes it. resolution_state has no wqx_confidence column. |
| R/mod_review_results.R (observeEvent wqx_review_click) | R/mod_review_results.R (showModal) | Reads resolution_state row, shows modal with context | WIRED | showModal(modalDialog(title = "Review WQX Match", ...)) at line 1859 inside wqx_review_click observer. |
| R/mod_review_results.R (observeEvent wqx_modal_confirm) | R/mod_review_results.R (resolution_state) | Updates wqx_override_name via get_group_rows loop | WIRED | Line 1909-1911: updated_df$wqx_override_name[r] <- new_name inside for(r in group_rows). |
| R/mod_review_results.R (observeEvent wqx_reject_click) | R/mod_review_results.R (resolution_state) | Sets consensus_status = "unresolvable", needs_review = TRUE | WIRED | Lines 1935-1937 inside wqx_reject_click observer. consensus_status = "unresolvable" is primary; needs_review = TRUE written without initialization guard (WR-02). |
| R/mod_review_results.R (derive_resolution_html) | export (resolution_state) | wqx_override_name persists through CSV/Excel download | WIRED | export_helpers.R:41 starts from resolution_state; dplyr::select(-any_of(c(".pinned", ".manual_entry"))) does not remove wqx_override_name. |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| mod_review_results.R renderReactable (wqx_confidence colDef) | wqx_confidence in df_display | run_curation_pipeline → map_results_to_rows | No — column dropped by mapper; guard at line 767 always FALSE | DISCONNECTED |
| mod_review_results.R (wqx_review_click observer) | wqx_confidence for modal confidence score | resolution_state$wqx_confidence | No — column absent from resolution_state due to WR-01; falls back to NA_real_ always | DISCONNECTED |
| mod_review_results.R (wqx_modal_confirm observer) | wqx_override_name in resolution_state | input$wqx_typeahead (server-populated from load_wqx_dictionary) | Yes — updateSelectizeInput(server=TRUE) loads real dictionary entries | FLOWING |
| mod_review_results.R (wqx_reject_click observer) | consensus_status in resolution_state | wqx_reject_click input event, observer sets "unresolvable" | Yes — mutation correctly propagated | FLOWING |

---

### Behavioral Spot-Checks

Step 7b: SKIPPED for all but static checks — modal interactions and reactable rendering require a running Shiny session.

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| wqx_confidence computed in wqx_rows tibble | grep "wqx_confidence = ifelse" R/curation.R | Match at line 761 | PASS |
| map_results_to_rows writes wqx_confidence | grep "wqx_confidence" R/curation.R (lines 543-614) | No match in mapper body | FAIL — column not carried through |
| wqx-review-btn present in derive_resolution_html | grep -c "wqx-review-btn" mod_review_results.R => 2 | 2 matches | PASS |
| All 4 modal observers present | grep -c "observeEvent.input\$wqx_" mod_review_results.R | wqx_review_click (1), wqx_modal_confirm (1), wqx_reject_click (1), wqx_typeahead (1) | PASS |
| effective_wqx_name priority in derive_resolution_html | grep "effective_wqx_name" => 3 | 3 matches (assignment, wqx_has_pref, result assignment) | PASS |
| TDD commits exist | git log efc1066 12643c5 b40a7ab 42602d6 | All 4 commits verified | PASS |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| CONF-03 | 48-01 | Review Results table displays WQX fuzzy match confidence score as a visible column | BLOCKED | wqx_confidence colDef exists in mod_review_results.R:767-779 but the column is never present in resolution_state due to WR-01. The guard condition is always FALSE. Column never renders. |
| RES-01 | 48-02 | User can search WQX dictionary via type-ahead input to find correct canonical name | SATISFIED | selectizeInput("wqx_typeahead") in modal with updateSelectizeInput(server=TRUE, choices=wqx_choices) loading full ~124K dictionary. observeEvent(wqx_typeahead) shows/hides confirm button. |
| RES-02 | 48-02 | User can reject a bad WQX fuzzy match and pick type-ahead or mark unresolvable | SATISFIED | observeEvent(wqx_reject_click) sets consensus_status = "unresolvable". Modal footer has "Reject Match" button with JS onclick that fires wqx_reject_click. Warning WR-02: needs_review column written without initialization guard but export behavior is correct since export recalculates from consensus_status. |
| RES-03 | 48-02 | WQX manual overrides persist through export | SATISFIED (human verify) | export_helpers.R:41-45 passes resolution_state to curated_data_sheet; wqx_override_name not in exclusion list. wqx_override_name column initialized lazily on first override and written to resolution_state. Export also recalculates needs_review = (consensus_status %in% c("error", "unresolvable")), correctly covering rejected rows. Runtime confirmation recommended. |

**Orphaned requirements check:** REQUIREMENTS.md maps CONF-03, RES-01, RES-02, RES-03 to Phase 48. All four appear in plan frontmatter. No orphaned requirements.

---

### Anti-Patterns Found

| File | Location | Pattern | Severity | Impact |
|------|----------|---------|----------|--------|
| R/curation.R | lines 543-579 (map_results_to_rows) | wqx_confidence written to combined_results but the mapper only carries 5 hard-coded column vectors; new column silently discarded | BLOCKER | wqx_confidence never reaches resolution_state; CONF-03 fails; WQX Conf. column never appears; confidence score always NA in modal |
| tests/testthat/test-mod-review-helpers.R | lines 118-163 (Test Group 4) | Tests inline the ifelse formula directly rather than calling map_results_to_rows or run_curation_pipeline — pipeline integration gap is invisible to test suite | WARNING | WR-01 was not caught before shipping; adding an integration-level test for map_results_to_rows output would have caught it |
| R/mod_review_results.R | line 1937 (wqx_reject_click observer) | updated_df$needs_review[r] <- TRUE without initialization guard; creates column with NA/TRUE mix if column not yet present in resolution_state | WARNING | In-state needs_review is NA for non-rejected rows (not FALSE); export is correct because export_helpers.R:43 recomputes from consensus_status; no user-facing impact but downstream observers would see mixed NA/TRUE |
| R/mod_review_results.R | lines 151-155 (derive_resolution_html) | review_btn vector pre-allocated over all n rows, then only WQX-row subsets used; slightly less efficient than the compare-btn pattern which constructs only for matching rows | INFO | No correctness impact; unused button strings are never inserted into DOM |
| R/mod_review_results.R | line 1944 | Notification uses -- (double hyphen) instead of — (U+2014 em-dash) per UI-SPEC | INFO | Minor cosmetic inconsistency with other notifications in the file |

---

### Human Verification Required

#### 1. WQX Conf. Column Visibility (blocked until WR-01 fixed)

**Test:** After fixing WR-01, upload a dataset with chemical names that produce WQX fuzzy matches (e.g., sswqs.xlsx). Run curation. Navigate to Review Results.
**Expected:** A "WQX Conf." column is visible with decimal similarity scores (e.g., 0.87) for fuzzy-matched rows and blank cells for exact/alias rows.
**Why human:** Requires a live Shiny session with a real WQX-matching dataset; column visibility depends on runtime colDef application.

#### 2. WQX Review Modal — Confidence Score in Context Card (blocked until WR-01 fixed)

**Test:** After fixing WR-01, click "Review" on a WQX fuzzy-matched row.
**Expected:** Modal opens showing a context card with four fields: Input Name, Current WQX Match, Match Type ("WQX Fuzzy"), and Confidence Score (decimal value). For exact/alias rows, the Confidence Score row should be absent.
**Why human:** Requires live session; confidence score rendering in the modal context card depends on wqx_confidence being present in resolution_state (which WR-01 currently prevents).

#### 3. WQX Override Persists in Excel Export

**Test:** Override a WQX match via type-ahead. Download Excel export.
**Expected:** Curated Data sheet contains wqx_override_name column with the user-selected canonical name on the overridden row.
**Why human:** Export correctness for wqx_override_name requires runtime confirmation; export_helpers.R does not explicitly include or exclude the column.

#### 4. Rejected Row Export

**Test:** Reject a WQX match. Download Excel export.
**Expected:** Rejected row has consensus_status = "unresolvable" and needs_review = TRUE in the Curated Data sheet.
**Why human:** Export recalculates needs_review from consensus_status at export time; confirming this at runtime closes the WR-02 export concern.

---

### Gaps Summary

**One blocker gap found:** The `wqx_confidence` column is correctly computed in `curation.R` but is silently dropped by `map_results_to_rows()`. This function uses a pre-allocated vector pattern for exactly 5 columns and does not carry arbitrary extra columns from `lookup_deduped` into the output data frame. As a result, `resolution_state` has no `wqx_confidence` column, the `if ("wqx_confidence" %in% names(df_display))` guard is always FALSE, and the "WQX Conf." column never appears in the Review Results table. The Confidence Score row in the WQX Review modal context card also always falls back to `NA_real_`.

This bug (WR-01 from the code review) was flagged before verification and is confirmed. The fix requires modifying `map_results_to_rows()` to carry `wqx_confidence` through the same pre-allocation pattern used for the other 5 columns.

The remaining 3 requirements (RES-01, RES-02, RES-03) are implemented correctly. The override and reject workflows are wired, the modal opens with correct context, type-ahead loads the WQX dictionary, group propagation is applied, and export reads `resolution_state` directly so `wqx_override_name` and updated `consensus_status` flow through.

The test suite gap (WR-03) means a similar regression would not be caught automatically. An integration-level test for `map_results_to_rows` output would close this.

---

_Verified: 2026-05-07_
_Verifier: Claude (gsd-verifier)_
