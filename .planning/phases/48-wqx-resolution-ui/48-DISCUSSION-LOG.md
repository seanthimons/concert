# Phase 48: WQX Resolution UI - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-07
**Phase:** 48-wqx-resolution-ui
**Areas discussed:** Confidence display, Resolution trigger, Reject & override flow, Export integration

---

## Confidence Display

### Q1: How should the WQX fuzzy score appear in the Review Results table?

| Option | Description | Selected |
|--------|-------------|----------|
| Numeric column (Recommended) | Dedicated wqx_confidence column showing similarity score (0.00-1.00) for fuzzy matches, blank for exact/alias. Filterable and sortable. | ✓ |
| Color-coded badge | Score as teal badge with color intensity by confidence level. Compact but harder to filter/sort. | |
| Both (column + badge) | Numeric column for sorting/filtering AND score in Resolution cell badge. Maximum visibility, more horizontal space. | |

**User's choice:** Numeric column
**Notes:** Blank for exact/alias matches, score for fuzzy only.

### Q2: Should the wqx_confidence column be visible by default or hidden behind colvis?

| Option | Description | Selected |
|--------|-------------|----------|
| Visible by default (Recommended) | Column shows immediately so users notice low-confidence matches. Hideable via colvis. | ✓ |
| Hidden by default | Keeps table compact. Users opt in via colvis button. | |

**User's choice:** Visible by default

---

## Resolution Trigger

### Q3: How should the user initiate a WQX override on a fuzzy-matched row?

| Option | Description | Selected |
|--------|-------------|----------|
| Button opens modal (Recommended) | Teal "Review" button on WQX rows opens a modal with current match info + type-ahead search. Consistent with existing Compare modal pattern. | ✓ |
| Inline type-ahead in table | Small search input directly in Resolution cell. Novel pattern — nothing in the app works this way currently. | |
| Click the WQX badge itself | Clicking the teal [wqx] badge opens the modal. Clean but less obvious affordance. | |

**User's choice:** Button opens modal

### Q4: Should the Review button appear on all WQX rows or only fuzzy matches?

| Option | Description | Selected |
|--------|-------------|----------|
| Fuzzy only (Recommended) | Review button only on WQX Fuzzy rows. Exact and alias matches are reliable. | |
| All WQX rows | Review button on every WQX-resolved row (exact, alias, fuzzy). Lets users override even confident matches. | ✓ |
| You decide | Claude picks the approach. | |

**User's choice:** All WQX rows

---

## Reject & Override Flow

### Q5: Inside the WQX Review modal, what actions should be available?

| Option | Description | Selected |
|--------|-------------|----------|
| Three actions (Recommended) | Accept current, Pick different (type-ahead + confirm), Reject (mark unresolvable). All in one modal. | ✓ |
| Two actions + separate reject | Modal has Accept and Pick-different. Reject is a separate button on the table row. | |
| Two-step: review then decide | Modal shows info only. User closes modal, then uses dropdown on row. | |

**User's choice:** Three actions in one modal

---

## Export Integration

### Q6: How should WQX overrides and rejections appear in consensus_status for export?

| Option | Description | Selected |
|--------|-------------|----------|
| Reuse existing statuses (Recommended) | Override → "wqx" (updated preferredName). Rejection → "unresolvable" (needs_review=TRUE). No new status values. | ✓ |
| New WQX-specific statuses | Override → "wqx_manual". Rejection → "wqx_rejected". More granular but requires export changes. | |
| You decide | Claude picks whichever minimizes changes. | |

**User's choice:** Reuse existing statuses

---

## Claude's Discretion

- Internal wiring of match_distance propagation through pipeline
- SelectizeInput configuration for 124K-row dictionary
- Modal layout details
- Dedup group propagation pattern

## Deferred Ideas

None — discussion stayed within phase scope.
