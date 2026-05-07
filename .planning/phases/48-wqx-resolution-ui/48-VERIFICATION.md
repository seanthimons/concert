---
phase: 48-wqx-resolution-ui
verified: 2026-05-07T20:30:33Z
status: gaps_found
score: 2/5
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 3/5
  gaps_closed:
    - "wqx_confidence column dropped by map_results_to_rows (fixed by Plan 03 -- 6th pre-allocation vector added)"
  gaps_remaining:
    - "CR-01: row$searchValue references non-existent column -- WQX Review modal crashes on click"
    - "WR-02: wqx_confidence column suffixed in multi-tag mode -- colDef guard and modal confidence lookup fail for common datasets"
  regressions: []
gaps:
  - truth: "User can click Review on a WQX row and see a modal with input name, current WQX match, match type, and confidence score"
    status: failed
    reason: "CR-01: wqx_review_click observer reads row$searchValue (line 1755), but searchValue is not a column in resolution_state. The $ accessor returns NULL, and is.na(NULL) returns logical(0), causing 'Error in if: argument is of length zero'. The modal never opens; user sees a red error notification instead."
    artifacts:
      - path: "R/mod_review_results.R"
        issue: "Line 1755: input_name <- row$searchValue -- column does not exist on resolution_state"
    missing:
      - "Replace row$searchValue with a lookup against the tagged Name column(s) from data_store$column_tags"
  - truth: "Review Results table shows a wqx_confidence column with the Jaro-Winkler score for rows resolved via WQX fuzzy matching"
    status: failed
    reason: "WR-02: In multi-tag mode (common case when both Name and CASRN are tagged), map_results_to_rows produces wqx_confidence_Chemical (suffixed), but the colDef guard at line 767 checks for wqx_confidence (unsuffixed). Guard evaluates FALSE; column appears raw/unformatted or not at all. Single-tag mode works correctly."
    artifacts:
      - path: "R/mod_review_results.R"
        issue: "Line 767: if ('wqx_confidence' %in% names(df_display)) -- never matches when column is wqx_confidence_Chemical"
      - path: "R/mod_review_results.R"
        issue: "Line 1788: if ('wqx_confidence' %in% names(row)) -- never matches in multi-tag mode; confidence always falls back to NA_real_"
    missing:
      - "Use grep('^wqx_confidence', names(df_display), value = TRUE) for colDef application (same pattern as preferredName_*)"
      - "Use grep('^wqx_confidence', names(row), value = TRUE) for modal confidence lookup"
human_verification:
  - test: "Verify WQX Conf. column appears in Review Results table after curation (after CR-01 and WR-02 fixes)"
    expected: "Upload a dataset with both Name and CASRN tagged. After curation, navigate to Review Results. The 'WQX Conf.' column should be visible with decimal similarity scores for fuzzy-matched rows and blank cells for exact/alias rows."
    why_human: "Requires a live Shiny session with a real WQX-matching dataset. Automated checks can only verify code structure."
  - test: "Verify WQX Review modal opens and shows correct context (after CR-01 fix)"
    expected: "Click 'Review' on a WQX fuzzy-matched row. Modal opens showing: Input Name (the user's original value from the tagged column), Current WQX Match, Match Type ('WQX Fuzzy'), and Confidence Score (decimal value). For exact/alias rows, Confidence Score row should be absent."
    why_human: "Requires live session; modal rendering depends on runtime data and corrected column reference."
  - test: "Verify type-ahead override persists in Excel export"
    expected: "Override a WQX match via type-ahead. Download Excel. Curated Data sheet contains wqx_override_name column with the user-selected canonical name."
    why_human: "Export correctness requires runtime confirmation; export_helpers.R passes resolution_state directly."
  - test: "Verify rejected row export"
    expected: "Reject a WQX match. Download Excel. Rejected row has consensus_status = 'unresolvable' and needs_review = TRUE."
    why_human: "Export recalculates needs_review from consensus_status at export time; requires runtime confirmation."
---

# Phase 48: WQX Resolution UI -- Verification Report

**Phase Goal:** Users can inspect WQX fuzzy match confidence, reject bad matches, search for the correct canonical WQX name, and have overrides persist through export
**Verified:** 2026-05-07T20:30:33Z
**Status:** gaps_found
**Re-verification:** Yes -- after gap closure (Plan 03 fixed wqx_confidence propagation through map_results_to_rows)

## Re-verification Summary

Plan 03 successfully closed the original BLOCKER gap: `map_results_to_rows()` now carries `wqx_confidence` via a 6th pre-allocation vector (`wqx_conf_vec`), with a column presence guard and correct assignment in both single-tag and multi-tag branches. Three integration tests (Test Group 6, 25/25 passing) verify the fix.

However, two issues remain -- one critical (CR-01 from code review) and one warning elevated to gap (WR-02):

1. **CR-01:** The `wqx_review_click` observer reads `row$searchValue`, a column that does not exist in `resolution_state`. This causes an R error that prevents the WQX Review modal from opening. Since the modal is the entry point for SC-2 through SC-4 (type-ahead search, override, reject), this is a runtime blocker.

2. **WR-02:** In multi-tag mode (the common case when both Name and CASRN are tagged), `wqx_confidence` is column-suffixed (e.g., `wqx_confidence_Chemical`), but both consumer sites check for the unsuffixed name. This means SC-1 (confidence column visible) fails for multi-tag datasets.

## Goal Achievement

### Observable Truths (from ROADMAP.md Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Review Results table shows a wqx_confidence column with the Jaro-Winkler score for WQX fuzzy rows | FAILED | Pipeline now carries wqx_confidence through map_results_to_rows (fixed by Plan 03, confirmed at R/curation.R:549,563-565,576,584). However, in multi-tag mode the column is named `wqx_confidence_Chemical`, and the colDef guard at mod_review_results.R:767 checks for unsuffixed `wqx_confidence`. Guard is FALSE for multi-tag datasets; column appears raw or not at all. Single-tag mode works correctly. |
| 2 | User can type into a search input on a WQX-matched row and see matching WQX canonical names as type-ahead suggestions | FAILED | All modal infrastructure exists: observeEvent(wqx_review_click) at line 1743, selectizeInput("wqx_typeahead") at line 1820, updateSelectizeInput(server=TRUE) with full WQX dictionary at line 1873. However, the modal never opens due to CR-01: line 1755 reads `row$searchValue` (NULL), line 1796 evaluates `if (!is.na(NULL))` -> `if (logical(0))` -> R error. |
| 3 | User can select a type-ahead result to override a bad WQX fuzzy match, and the row reflects the new name | FAILED | Override logic is correctly wired: observeEvent(wqx_modal_confirm) at line 1891 writes wqx_override_name via group_rows loop, derive_resolution_html uses effective_wqx_name at line 148. But since the modal cannot open (CR-01), the user cannot reach this action. |
| 4 | User can reject a WQX fuzzy match and mark the row unresolvable | FAILED | Reject logic is correctly wired: observeEvent(wqx_reject_click) at line 1925 sets consensus_status = "unresolvable" and needs_review = TRUE. But since the modal cannot open (CR-01), the user cannot reach this action. |
| 5 | Exported Excel and Parquet files include the user's WQX override or unresolvable status | UNCERTAIN | export_helpers.R:41 passes resolution_state directly; wqx_override_name is not in the exclusion list. For rejected rows, export_helpers.R:43 recomputes needs_review from consensus_status. Logic is correct but depends on CR-01 being fixed first (user must be able to create overrides/rejections). Runtime confirmation needed. |

**Score: 2/5 truths verified** (SC-2 through SC-4 blocked by CR-01; SC-1 fails for multi-tag via WR-02; SC-5 uncertain)

Note: SC-2, SC-3, SC-4 infrastructure is fully wired and substantive -- the code logic is correct. Only the `row$searchValue` reference at line 1755 prevents the modal from opening. This is a single-line fix.

## Gap Closure Assessment (from Previous Verification)

| Previous Gap | Status | Evidence |
|-------------|--------|----------|
| wqx_confidence dropped by map_results_to_rows | CLOSED | Plan 03 commit f6fba84: wqx_conf_vec pre-allocation at line 549, guarded fill at lines 563-565, assignment at lines 576 (single-tag) and 584 (multi-tag). 3 integration tests pass (Test Group 6). |

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `R/curation.R` | wqx_confidence column computed and propagated through map_results_to_rows | VERIFIED | wqx_confidence computed at line 767 (ifelse on match_tier). wqx_conf_vec pre-allocated at line 549, filled at line 564, assigned at lines 576/584. Column reaches output df. |
| `R/mod_review_results.R` | Review button, JS handler, wqx_confidence colDef, modal observers, override/reject logic | PARTIAL | All code present and substantive. Two defects: (1) CR-01 at line 1755 references non-existent column, (2) WR-02 at lines 767,1788 use unsuffixed column name that fails in multi-tag mode. |
| `tests/testthat/test-mod-review-helpers.R` | Unit and integration tests | VERIFIED | 25 tests, all passing. Test Group 6 covers map_results_to_rows wqx_confidence propagation with 3 integration tests. Test Groups 4-5 cover confidence computation and Review button HTML. |

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| R/curation.R (wqx_rows tibble) | R/curation.R (map_results_to_rows output) | wqx_conf_vec 6th vector | WIRED | Plan 03 fix confirmed: pre-allocate, fill, assign in both branches. |
| R/curation.R (map_results_to_rows output) | R/mod_review_results.R (colDef guard) | wqx_confidence column in resolution_state | PARTIAL | Column exists but is suffixed (`wqx_confidence_Chemical`) in multi-tag mode; guard checks unsuffixed name. Works in single-tag only. |
| R/mod_review_results.R (wqx_review_click observer) | R/mod_review_results.R (showModal) | Reads resolution_state row, shows modal | BROKEN | showModal at line 1859 is wired, but observer crashes at line 1755 before reaching it (row$searchValue -> NULL -> if(logical(0)) error). |
| R/mod_review_results.R (wqx_modal_confirm observer) | R/mod_review_results.R (resolution_state) | Updates wqx_override_name via group_rows | WIRED | Line 1909-1911: correct group-propagated mutation. Unreachable at runtime due to CR-01. |
| R/mod_review_results.R (wqx_reject_click observer) | R/mod_review_results.R (resolution_state) | Sets consensus_status = "unresolvable" | WIRED | Lines 1935-1937: correct mutation. WR-01 (needs_review init guard) is a minor inconsistency; export recalculates correctly. Unreachable at runtime due to CR-01. |
| R/mod_review_results.R (derive_resolution_html) | export (resolution_state) | wqx_override_name persists | WIRED | export_helpers.R excludes only .pinned and .manual_entry; wqx_override_name flows through. |

## Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| curation.R map_results_to_rows | wqx_conf_vec | lookup_deduped$wqx_confidence | Yes (guarded fill from real match data) | FLOWING |
| mod_review_results.R colDef | wqx_confidence in df_display | resolution_state via map_results_to_rows | Partial -- column present but suffixed in multi-tag mode; guard mismatches | STATIC (multi-tag) / FLOWING (single-tag) |
| mod_review_results.R modal context card | row$searchValue | resolution_state | NULL -- column does not exist | DISCONNECTED |
| mod_review_results.R modal confidence | row$wqx_confidence | resolution_state | Falls back to NA in multi-tag; correct in single-tag | STATIC (multi-tag) / FLOWING (single-tag) |
| mod_review_results.R wqx_modal_confirm | wqx_override_name | input$wqx_typeahead -> resolution_state | Real data from server-side selectize | FLOWING (when reachable) |
| mod_review_results.R wqx_reject_click | consensus_status | observer -> resolution_state | Sets "unresolvable" correctly | FLOWING (when reachable) |

## Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| wqx_conf_vec pre-allocated | grep "wqx_conf_vec <- rep" R/curation.R | Match at line 549 | PASS |
| wqx_conf_vec filled in inner loop | grep "wqx_conf_vec\[ridx\]" R/curation.R | Match at line 564 | PASS |
| wqx_confidence assigned to df | grep "wqx_confidence" R/curation.R (lines 569-586) | Lines 576 (single-tag) and 584 (multi-tag) | PASS |
| All unit tests pass | Rscript testthat::test_file | 25/25 PASS, 0 FAIL | PASS |
| row$searchValue references non-existent column | grep "searchValue" R/mod_review_results.R | Line 1755: input_name <- row$searchValue (CR-01 confirmed) | FAIL |
| colDef uses unsuffixed wqx_confidence | grep "wqx_confidence" R/mod_review_results.R | Lines 767, 1788: unsuffixed checks only (WR-02 confirmed) | FAIL |

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| CONF-03 | 48-01, 48-03 | Review Results table displays WQX fuzzy match confidence score as a visible column | BLOCKED | Pipeline computes and carries wqx_confidence correctly (Plan 03 fix). colDef exists (line 767-778). But column is suffixed in multi-tag mode and colDef guard fails. |
| RES-01 | 48-02 | User can search WQX dictionary via type-ahead input | BLOCKED | selectizeInput + updateSelectizeInput(server=TRUE) with full dictionary wired correctly. But modal never opens due to CR-01, so user cannot reach the search input. |
| RES-02 | 48-02 | User can reject a bad WQX fuzzy match and pick type-ahead or mark unresolvable | BLOCKED | Reject observer correctly sets consensus_status = "unresolvable". But modal never opens due to CR-01. |
| RES-03 | 48-02 | WQX manual overrides persist through export | BLOCKED | Export path is correctly wired (wqx_override_name flows through). But user cannot create overrides because modal never opens due to CR-01. |

**Orphaned requirements check:** REQUIREMENTS.md maps CONF-03, RES-01, RES-02, RES-03 to Phase 48. All four appear in plan frontmatter. No orphaned requirements.

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| R/mod_review_results.R | 1755 | `row$searchValue` references non-existent column on resolution_state; causes R error "argument is of length zero" | BLOCKER | WQX Review modal crashes on click; blocks SC-2 through SC-4 |
| R/mod_review_results.R | 767, 1788 | Unsuffixed `wqx_confidence` check fails in multi-tag mode (column is `wqx_confidence_Chemical`) | BLOCKER | WQX Conf. column invisible and modal confidence always NA for common multi-tag datasets |
| R/mod_review_results.R | 1937 | `needs_review[r] <- TRUE` written without initialization guard; creates NA/TRUE mix | WARNING | In-memory inconsistency; export is correct (recalculates from consensus_status) |
| R/mod_review_results.R | 1944 | `--` (double hyphen) instead of em-dash in notification | INFO | Minor cosmetic inconsistency |

## Human Verification Required

### 1. WQX Conf. Column Visibility (blocked until WR-02 fix)

**Test:** After fixing WR-02, upload a dataset with both Name and CASRN tagged. Run curation. Navigate to Review Results.
**Expected:** "WQX Conf." column visible with decimal scores for fuzzy rows, blank for exact/alias.
**Why human:** Requires live Shiny session with real WQX-matching dataset.

### 2. WQX Review Modal -- Full Workflow (blocked until CR-01 fix)

**Test:** After fixing CR-01, click "Review" on a WQX fuzzy-matched row.
**Expected:** Modal opens with Input Name (user's original value), Current WQX Match, Match Type, and Confidence Score. Type-ahead works. Override and reject actions update the table.
**Why human:** Requires live session; modal rendering depends on runtime data.

### 3. Export Persistence (blocked until CR-01 fix)

**Test:** After fixing CR-01, override a WQX match via type-ahead and reject another. Download Excel.
**Expected:** Override row has wqx_override_name populated; rejected row has consensus_status = "unresolvable" and needs_review = TRUE.
**Why human:** Export path correctness requires runtime confirmation.

## Gaps Summary

**Two gaps found, both blocking goal achievement:**

1. **CR-01 (BLOCKER -- single-line fix):** `row$searchValue` at line 1755 references a column that does not exist in `resolution_state`. The `$` accessor returns NULL, `is.na(NULL)` returns `logical(0)`, and `if (logical(0))` throws an R error. This prevents the WQX Review modal from opening entirely, blocking SC-2, SC-3, SC-4, and indirectly SC-5. The fix is to read the input name from the tagged Name column via `data_store$column_tags` instead of `row$searchValue`.

2. **WR-02 (BLOCKER -- grep-pattern fix):** In multi-tag mode (common case with Name + CASRN tagged), `map_results_to_rows` produces `wqx_confidence_Chemical` (suffixed), but the colDef guard (line 767) and modal confidence lookup (line 1788) check for `wqx_confidence` (unsuffixed). This means the WQX Conf. column never appears and the modal confidence score is always NA for multi-tag datasets. The fix is to use `grep("^wqx_confidence", names(...))` for column lookup, consistent with the existing pattern for `preferredName_*` and `source_tier_*`.

**Root cause relationship:** These are independent bugs. CR-01 is a code review finding from the initial Plan 02 execution. WR-02 was identified in the code review but not addressed by Plan 03 (which focused only on the map_results_to_rows column-drop bug).

**Positive note:** The Plan 03 gap closure was successful. The original BLOCKER (wqx_confidence silently dropped by map_results_to_rows) is fully fixed with 3 integration tests proving the column reaches the output df. All 25 tests pass. The underlying logic for modal observers, override/reject actions, derive_resolution_html, and export persistence is correctly wired -- only the two reference bugs prevent it from working at runtime.

---

_Verified: 2026-05-07T20:30:33Z_
_Verifier: Claude (gsd-verifier)_
