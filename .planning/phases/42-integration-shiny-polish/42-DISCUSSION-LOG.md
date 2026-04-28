# Phase 42: Integration & Shiny Polish - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-27
**Phase:** 42-integration-shiny-polish
**Areas discussed:** Pre-flight modal design, Media editor UX, Persistence & re-run cascade, AMOS fallback integration

---

## Pre-flight Modal Design

### Modal Layout

| Option | Description | Selected |
|--------|-------------|----------|
| Step table with indicators | Table with one row per step: step name, fire/skip icon, estimated change count | |
| Grouped summary cards | Group steps into categories with summary counts per group | |
| Checklist with toggles | Each step is a checkbox, pre-checked based on pre-check results. User can toggle individual steps on/off. | ✓ |

**User's choice:** Checklist with toggles
**Notes:** Maximum user control — fits regulatory data context where users may want to skip specific steps intentionally.

### Modal Scope

| Option | Description | Selected |
|--------|-------------|----------|
| One unified modal | Single modal with sections for Cleaning steps and Harmonization steps | ✓ |
| Separate modals per pipeline | Each button opens its own pipeline-specific modal | |
| Separate, cleaning first | Cleaning modal first, harmonization modal auto-appears after | |

**User's choice:** One unified modal

### Trigger

| Option | Description | Selected |
|--------|-------------|----------|
| Either button opens it | Both existing buttons open the same unified modal | |
| Single new Run button | Replace both buttons with a single "Run Pipeline" button | ✓ |
| Context-sensitive open | Each button opens unified modal focused to relevant section | |

**User's choice:** Single new Run button

### Empty State

| Option | Description | Selected |
|--------|-------------|----------|
| Show modal anyway | Always show modal for consistency | |
| Show notification instead | Skip modal, show brief notification with option to open modal | ✓ |
| You decide | Claude's discretion | |

**User's choice:** Show notification instead

---

## Media Editor UX

### Editor Layout

| Option | Description | Selected |
|--------|-------------|----------|
| Inline DT table | Editable DT::datatable with direct cell editing | |
| Modal-based editing | Read-only table display, click row to open edit modal | ✓ |
| Accordion sub-panel | Collapsible section in Harmonize tab | |

**User's choice:** Modal-based editing
**Notes:** Consistent with existing unit mapping and correction editor patterns.

### Unmatched Terms UX

| Option | Description | Selected |
|--------|-------------|----------|
| Highlighted rows at top | Unmatched terms at top with visual indicator, UNMATCHED/MAPPED sections | ✓ |
| Separate unmatched panel | Dedicated card/section above main table | |
| Badge notification | Badge count on panel header with filter toggle | |

**User's choice:** Highlighted rows at top

---

## Persistence & Re-run Cascade

### Re-run Trigger

| Option | Description | Selected |
|--------|-------------|----------|
| Manual re-run only | Edits persist but pipeline only re-runs on manual button click | |
| Auto re-run after save | Automatically re-trigger pipeline after saving edits | |
| Prompt to re-run | Show notification with "Re-run now" action link | ✓ |

**User's choice:** Prompt to re-run

### Storage Architecture

| Option | Description | Selected |
|--------|-------------|----------|
| Separate user RDS | User edits in separate file from AMOS-derived cache | ✓ |
| Merged single RDS | All entries in one file with source column | |
| You decide | Claude's discretion | |

**User's choice:** Separate user RDS

---

## AMOS Fallback Integration

### Visual Distinction

| Option | Description | Selected |
|--------|-------------|----------|
| Source column with badge | Blue badge for user entries (editable), gray badge for AMOS (read-only) | ✓ |
| Separate sections | Two sections: "Your Mappings" and "AMOS Defaults" | |
| Merged, no distinction | All entries shown identically | |

**User's choice:** Source column with badge

### Override Behavior

| Option | Description | Selected |
|--------|-------------|----------|
| User entry wins silently | User entry takes priority, AMOS entry grayed out | |
| Confirm override | Show confirmation dialog before overriding AMOS mapping | ✓ |
| You decide | Claude's discretion | |

**User's choice:** Confirm override

---

## Claude's Discretion

- Harmonization pre-check implementation details
- Modal styling and responsive layout
- DT table rendering options
- Notification/toast implementation
- Working copy merge strategy
- Badge rendering approach in DT cells

## Deferred Ideas

None — discussion stayed within phase scope
