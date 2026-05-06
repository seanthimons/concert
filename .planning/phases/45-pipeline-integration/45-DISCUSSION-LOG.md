# Phase 45: Pipeline Integration - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-06
**Phase:** 45-pipeline-integration
**Areas discussed:** Pipeline insertion point, Resolution data model, Source tier attribution

---

## Pipeline Insertion Point

| Option | Description | Selected |
|--------|-------------|----------|
| New tier inside run_curation_pipeline() | Add WQX as tier after starts-with, before consensus. 'miss' rows get passed to match_wqx(). Results flow into map_results_to_rows() and consensus naturally. Keeps all search logic in one orchestrator. | ✓ |
| Post-curation step on resolution_state | Run after run_curation_pipeline() returns. Scan resolution_state for unresolved rows, call match_wqx(), retrofit results. Simpler to add but requires manually patching consensus_status and resolved columns. | |
| You decide | Claude picks the best approach based on codebase patterns | |

**User's choice:** New tier inside run_curation_pipeline() (Recommended)
**Notes:** Clean fit with existing tier escalation pattern. final_missed names become WQX input.

---

## Resolution Data Model

| Option | Description | Selected |
|--------|-------------|----------|
| WQX name in preferredName, dtxsid stays NA | WQX canonical name fills the preferredName column. dtxsid remains NA. consensus_status gets new value 'wqx'. Minimal schema change — reuses existing columns. | ✓ |
| New wqx_name column alongside existing fields | Add a dedicated wqx_name column. Keeps CompTox and WQX results structurally separate. Downstream consumers need to check both columns. | |
| You decide | Claude picks the approach that best fits the existing data model | |

**User's choice:** WQX name in preferredName, dtxsid stays NA (Recommended)
**Notes:** Satisfies INTG-02 naturally — resolved name shows up in the same place CompTox results do.

---

## Source Tier Attribution

| Option | Description | Selected |
|--------|-------------|----------|
| Split: wqx_exact, wqx_alias, wqx_fuzzy | Maps directly to match_wqx() match_tier values. Preserves match quality in audit trail. Consistent with existing granularity. | ✓ |
| Single: wqx | All WQX matches get source_tier='wqx'. Simpler but loses tier detail. | |
| You decide | Claude picks based on existing source_tier conventions | |

**User's choice:** Split: wqx_exact, wqx_alias, wqx_fuzzy (Recommended)
**Notes:** Preserves full match quality information. Maps directly from match_wqx() output.

---

## Claude's Discretion

- Result tibble conversion format (match_wqx output → combined_results schema)
- Verbose flag propagation
- Progress callback messaging for WQX tier
- Input filtering before match_wqx()
- Test organization

## Deferred Ideas

- WQX fuzzy tier benchmarking at scale (from Phase 44)
- Threshold tuning with larger datasets (from Phase 44)
- Shiny UI for WQX results (WFUT-03)
