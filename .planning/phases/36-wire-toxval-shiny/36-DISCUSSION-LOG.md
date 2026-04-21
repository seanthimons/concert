# Phase 36: Wire ToxVal Schema in Shiny Path - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-21
**Phase:** 36-wire-toxval-shiny
**Areas discussed:** Mapper call placement, Input assembly, SCHM-04 revision, Error handling

---

## Mapper Call Placement

| Option | Description | Selected |
|--------|-------------|----------|
| Inline in pipeline | Call map_to_toxval_schema() at end of Run Harmonization observeEvent, matching curate_headless() pattern | ✓ |
| Separate reactive | observe() watching data_store$harmonize_results, auto-runs mapper on change | |
| Separate button | Add 'Map to ToxVal' button for explicit user control | |

**User's choice:** Inline in pipeline (Recommended)
**Notes:** Matches the curate_headless() pattern where the mapper runs inline after harmonization.

---

## Input Assembly

| Option | Description | Selected |
|--------|-------------|----------|
| Join in mod_harmonize | Read resolution_state and harmonize_results from data_store, pass both to mapper | ✓ |
| Pre-join in data_store | Create reactive that pre-joins into combined tibble | |
| You decide | Claude decides | |

**User's choice:** Join in mod_harmonize (Recommended)
**Notes:** None — straightforward.

### Source Name Default

| Option | Description | Selected |
|--------|-------------|----------|
| Use uploaded filename | Extract from data_store$file_info$name | ✓ |
| Default 'user_upload' | Use mapper's existing default | |
| You decide | Claude picks | |

**User's choice:** Use uploaded filename
**Notes:** Most informative, matches headless convention.

---

## SCHM-04 Revision

| Option | Description | Selected |
|--------|-------------|----------|
| Re-word and close | Update description to 'CSV as user-selectable format' and mark complete | |
| Mark complete with note | Check box, add note: 'Superseded by D-02. CSV available as format choice, not fallback.' | ✓ |
| Leave as-is | Don't touch SCHM-04 wording | |

**User's choice:** Mark complete with note
**Notes:** Functionality exists from Phase 35; only wording is stale.

---

## Error Handling

| Option | Description | Selected |
|--------|-------------|----------|
| Warn and skip | Show notification, set toxval_output to NULL, Sheet 8 shows placeholder | |
| Partial output | Run mapper with missing curation data, fill chemical IDs with NA | |
| Block harmonization | Don't allow Run Harmonization until curation is complete | ✓ |

**User's choice:** Block harmonization
**Notes:** Enforces full linear workflow.

### Gate Mechanism

| Option | Description | Selected |
|--------|-------------|----------|
| Hide tab entirely | Don't show Harmonize tab until curation completes | ✓ |
| Disable button + message | Disable Run Harmonization button with message | |

**User's choice:** Hide tab entirely
**Notes:** Matches existing progressive tab reveal pattern.

### Gate Trigger

| Option | Description | Selected |
|--------|-------------|----------|
| Both required | req(numeric_tags, resolution_state) — need numeric tags AND curation complete | ✓ |
| Curation only | req(resolution_state) — tab visible after curation regardless of numeric tags | |

**User's choice:** Both required (Recommended)
**Notes:** Harmonization needs both numeric tags (to know what to parse) and curation results (for toxval mapper).

---

## Claude's Discretion

- Exact position within harmonize observeEvent for mapper call
- Column selection from resolution_state for curated_data argument
- withProgress message text
- Error notification wording
- Test case selection

## Deferred Ideas

None — discussion stayed within phase scope
