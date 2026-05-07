# Phase 47: Pipeline Reordering, Threshold Control & Starts-With Toggle - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-06
**Phase:** 47-pipeline-reordering-threshold-control-starts-with-toggle
**Areas discussed:** Search chain position, Pre-flight modal layout, Starts-with toggle scope, Headless argument design

---

## Search Chain Position

| Option | Description | Selected |
|--------|-------------|----------|
| Exact → CAS → WQX → Starts-with | WQX fires on names that failed exact+CAS. Starts-with only gets what WQX couldn't resolve. Matches requirement literally. | ✓ |
| Exact → WQX → CAS → Starts-with | WQX fires immediately after exact miss, before CAS validation. Maximum WQX priority but CAS numbers in Name columns won't be validated until after WQX. | |
| Exact → CAS → WQX (no starts-with unless toggled) | Same as option 1 but starts-with completely gated behind toggle. | |

**User's choice:** Exact → CAS → WQX → Starts-with
**Notes:** None

### Follow-up: WQX Input Filter

| Option | Description | Selected |
|--------|-------------|----------|
| All names that failed exact+CAS | WQX dictionary lookup is local (no API call), so no cost to trying short names. | ✓ |
| Only names ≥ 3 chars | Mirror the starts-with minimum length filter. | |

**User's choice:** All names that failed exact+CAS
**Notes:** None

---

## Pre-flight Modal Layout

| Option | Description | Selected |
|--------|-------------|----------|
| New accordion section: "Search Settings" | Second accordion panel below cleaning steps. Contains threshold slider and starts-with toggle. Keeps search config separate from cleaning config. | ✓ |
| Above the accordion, as top-level controls | Place slider + toggle outside accordion at top of modal body. More visible but breaks accordion pattern. | |
| Inline within cleaning accordion | Add them as items inside existing cleaning steps panel. Simpler but conflates cleaning and search. | |

**User's choice:** New accordion section: "Search Settings"
**Notes:** None

### Follow-up: Threshold UI Widget

| Option | Description | Selected |
|--------|-------------|----------|
| Slider + numeric input | sliderInput with companion numericInput. Range 0.50–1.00, step 0.01, default 0.85. | ✓ |
| Numeric input only | Just a numericInput box. Simpler, less discoverable. | |
| Preset dropdown | Labeled presets (Strict/Default/Loose/Very Loose). No custom values. | |

**User's choice:** Slider + numeric input
**Notes:** None

---

## Starts-with Toggle Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Only names that failed exact + CAS + WQX | Starts-with only gets names still unresolved after WQX. Clean waterfall. Satisfies SC-5. | ✓ |
| All names that failed exact + CAS (skip WQX filter) | Same pool as today. Would need de-duplication. Violates SC-5. | |

**User's choice:** Only names that failed exact + CAS + WQX
**Notes:** None

---

## Headless Argument Design

| Option | Description | Selected |
|--------|-------------|----------|
| Two named arguments | Add wqx_threshold = 0.85 and starts_with = FALSE as top-level args. Simple, matches modal defaults. | ✓ |
| Single config list argument | search_config = list(...). Extensible but adds indirection. | |
| You decide | Claude picks the approach. | |

**User's choice:** Two named arguments
**Notes:** None

---

## Claude's Discretion

- Internal wiring of how pre-flight modal values pass from UI → server → run_curation_pipeline()
- Slider/numeric input sync mechanism
- Notification/progress message text for reordered tiers

## Deferred Ideas

None — discussion stayed within phase scope.
