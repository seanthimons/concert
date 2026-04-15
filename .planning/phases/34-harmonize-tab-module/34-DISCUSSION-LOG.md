# Phase 34: Harmonize Tab Module - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-15
**Phase:** 34-harmonize-tab-module
**Areas discussed:** Module Layout, Editor Pattern, Unmatched Unit UX, QC Dashboard

---

## Module Layout

| Option | Description | Selected |
|--------|-------------|----------|
| Flat with accordions | Run button at top, QC boxes below, accordion panels for editors (like mod_clean_data.R) | ✓ |
| Stacked sections | Everything visible at once, scrollable page with section headers | |
| Primary/Secondary split | Main area for pipeline, sidebar/drawer for editors | |

**User's choice:** Flat with accordions
**Notes:** Follows established mod_clean_data.R pattern

---

## Editor Pattern

| Option | Description | Selected |
|--------|-------------|----------|
| rhandsontable for all | Spreadsheet-style inline editing | |
| Chips for corrections, rhandsontable for units | Mixed patterns optimized per data shape | |
| Modal forms + read-only tables | View in table, edit via modal dialogs | |
| Chip editors for everything | Chips with modal expand/edit for complex data | ✓ |

**User's choice:** Chip editors for everything — no rhandsontable
**Notes:** User explicitly stated "rhandsontable EVER. bad UI/UX. chip editors is very effective and easy to extend"

---

## Unmatched Unit UX

| Option | Description | Selected |
|--------|-------------|----------|
| Inline action chips | Warning-colored chips, click to add mapping | |
| Batch review panel | List with counts, bulk actions | ✓ |
| Toast notifications + manual add | Notification lists unmatched, user adds manually | |

**User's choice:** Batch review panel
**Notes:** More efficient for handling many unmatched units at once

---

## QC Dashboard

| Option | Description | Selected |
|--------|-------------|----------|
| On Harmonize tab only | Value boxes appear after pipeline completes | ✓ |
| On separate pre-export tab | QC as gate before export | |
| Both places | Summary on Harmonize, detailed on Export | |

**User's choice:** On Harmonize tab only
**Notes:** Immediate feedback loop: run → see QC → fix issues → re-run

---

## Claude's Discretion

- Exact accordion panel ordering
- Value box icons and color themes
- Modal form field layout and validation messages
- Chip badge colors for different unit categories
- Internal helper function organization

## Deferred Ideas

None — discussion stayed within phase scope
