# Phase 8: Error Recovery Workflows — Context

## Phase Goal
Enable users to manually resolve curation errors and retry failed rows.

## Requirements Covered
RECV-01, RECV-02, RECV-03, RECV-04, RECV-05

---

## 1. Manual DTXSID Entry

**Interaction model:** Inline cell editing — user clicks the DTXSID cell directly on any error-status row to type/paste a DTXSID value.

**Confirm behavior:** Validate on blur (when user clicks away or tabs out). Entry is saved and queued for bulk validation.

**No modal, no batch panel.** Each cell is edited individually, case by case.

**Visual indicator:** Manually-entered DTXSIDs display a badge or icon (e.g., small "manual" badge) to distinguish them from auto-resolved values. This persists even after validation.

---

## 2. Bulk Validation UX

**Trigger:** Dedicated "Validate All" button — validates all manually-entered DTXSIDs in one batch against CompTox API. No auto-validation on entry.

**Progress feedback:** Progress bar with count ("Validating 3 of 12...") during bulk validation.

**Failure handling:** Both summary notification AND inline cell indicators.
- Summary: "8 validated, 2 failed" notification listing which rows failed and why.
- Inline: Invalid cells get red border/message so user can find and fix them.

**On success:** Auto-populate preferredName immediately and update consensus status. No separate review/apply step.

---

## 3. Re-tag & Re-curate Flow

**Row selection:** Error filter view — button to filter the table to show only error rows, then select from those. No always-visible checkboxes.

**Re-tag approach:** Bulk re-tag as default (modal shows column-to-tag mapping, apply to all selected), with individual row override capability. Same pattern as existing en masse resolution flow.

**Confirmation:** After re-tagging, user sees updated tags and must click "Re-curate" to trigger the search pipeline. Not automatic.

**Search pipeline:** Full tier chain (exact → CAS → starts-with). No option to pick individual tiers. Consistent with initial curation behavior.

---

## 4. Result Merging & Status

**Merge style:** Silent replace — re-curated results update in place as if they succeeded originally. No before/after comparison or highlight animation.

**Consensus status for manual entries:** Distinct "manual" status. Manually-resolved rows do NOT get "unanimous" — they are distinguishable from auto-resolved rows.

**Pin preservation:** Pinned resolutions on non-selected rows are NEVER touched. Re-curation only affects the selected error rows.

**Re-fail behavior:** If a re-curated row still fails, it gets a new "unresolvable" status (distinct from plain "error"). Signals the user that retry didn't work and manual DTXSID entry is the next step.

**Row order:** Always original upload order. Re-curated rows slot back into their original positions. Table order never changes.

---

## Deferred Ideas

None captured during discussion.

---

## Decisions Summary

| Area | Decision | Rationale |
|------|----------|-----------|
| DTXSID entry | Inline cell click | Simplest UX, case-by-case editing |
| Entry confirm | On blur | Natural flow, no extra button clicks |
| Manual indicator | Badge/icon | Distinguishes manual from auto without being intrusive |
| Validation trigger | Dedicated button | Batches API calls, user controls timing |
| Validation progress | Progress bar + count | Clear feedback for potentially slow API calls |
| Validation failure | Summary + inline | User sees both overview and per-cell details |
| Post-validation | Auto-populate | No unnecessary confirmation step |
| Error row selection | Filter view | Focus on error rows without cluttering main table |
| Re-tag approach | Bulk + override | Matches existing en masse pattern |
| Re-curate trigger | Explicit confirm | User reviews tags before committing to API calls |
| Search tiers | Full pipeline | Consistency with initial curation |
| Merge style | Silent replace | Clean, non-disruptive update |
| Manual status | Distinct "manual" | Audit trail for how resolution was achieved |
| Pin safety | Never touch pins | Prevents accidental loss of user decisions |
| Re-fail status | "unresolvable" | Clear signal to try manual entry instead |
| Row order | Original order always | Prevents disorientation |
