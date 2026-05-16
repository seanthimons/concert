# Phase 51: Row Flagging - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md -- this log preserves the alternatives considered.

**Date:** 2026-05-16
**Phase:** 51-row-flagging
**Areas discussed:** Flag Semantics, Individual Flag Control, Batch Flagging, Export Shape

---

## Flag Semantics

| Option | Description | Selected |
|--------|-------------|----------|
| Annotations only | `row_flag` is independent of `consensus_status` and `needs_review`. | yes |
| BAD sets review | `BAD` also sets or contributes to `needs_review = TRUE` in export. | |
| Status-changing flags | Flags alter row status behavior in the Review Results workflow. | |

**User's choice:** Keep flags separate from `needs_review`.
**Notes:** The user asked for the conceptual distinction. Decision: `needs_review` is system judgment; `BAD` is user judgment. Export includes both so downstream users can filter for everything.

---

## Individual Flag Control

| Option | Description | Selected |
|--------|-------------|----------|
| Inline table flag column | Every row has a compact flag dropdown/chip in Review Results. | |
| Modal-only flagging | User opens the row review modal to set or clear a flag. | yes |
| Both | Inline quick flag plus modal display/edit. | |

**User's choice:** Modal only.
**Notes:** Individual flagging should not add an inline editable control to each table row.

---

## Batch Flagging

| Option | Description | Selected |
|--------|-------------|----------|
| Selected visible rows | User selects rows in Review Results, then applies one flag to that selected set. | yes |
| Filtered set action | User applies a flag to all rows matching current table filters, even if not manually selected. | |
| Status-based batches | User applies a flag to all DISAGREE / ERROR / SUGGESTED / etc. rows via preset buttons. | |

**User's choice:** Selected visible rows.
**Notes:** Filters/search may narrow the visible table, but batch mutation only applies to explicitly selected rows.

---

## Export Shape

| Option | Description | Selected |
|--------|-------------|----------|
| Simple flag column | Export `row_flag` with `BAD`, `FOLLOW-UP`, `VERIFIED`, or blank. | yes |
| Flag plus metadata | Export `row_flag`, `row_flagged_at`, and `row_flag_method`. | |
| Flag plus notes | Export `row_flag` and a free-text `row_flag_note`. | |

**User's choice:** Simple flag column.
**Notes:** No timestamp, method, or free-text note columns in this phase.

---

## Codex's Discretion

- Exact modal control layout for flag buttons/dropdown.
- Whether the table shows a read-only flag chip/column, as long as editing remains modal-only.
- Internal function naming and file placement.
- Exact batch action button placement.

## Deferred Ideas

- Flag timestamps, flag methods, and free-text notes.
- Inline editable flag controls.
- Having `BAD` change `needs_review` or `consensus_status`.
