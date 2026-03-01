# Phase 3: Prototype Pipeline - Context

**Gathered:** 2026-02-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Standalone R script that deduplicates tagged column values and runs tiered CompTox API searches (exact match → starts-with → CAS validation) to produce a lookup results table with metadata. Script runs against `data/sample_messy.csv` (7 rows) and validates against first 100 rows of `uncurated_chemicals_2023-05-16_12-43-41.csv`. No Shiny integration — that's Phase 5.

</domain>

<decisions>
## Implementation Decisions

### Multiple match handling
- Bulk functions (`ct_chemical_search_equal_bulk`) return one hit per input — no special handling needed
- Non-bulk functions: coerce rank to integer, take lowest-ranked (top) result. Mark with `#NOTE` comment indicating this is a tweakable area if results need more refinement
- Starts-with tier: only fires for values with zero exact matches. If starts-with returns multiple matches, keep all — multiple match resolution is deferred to downstream phases

### Output structure
- Primary key: original input value (the deduplicated string itself)
- Result columns: `dtxsid`, `preferredName`, `searchName` (resolution method: approved name, cas-rn, synonym), `searchValue` (original input key), `rank` (integer)
- No separate `search_tier` column — `searchName` is sufficient to infer which tier resolved it
- Script produces two outputs: (1) lookup table keyed by unique input value, (2) joined-back table mapped to all original rows proving the full round-trip

### CAS validation
- Use `ComptoxR::as_cas()` to normalize messy CAS strings (strips non-digits, removes leading zeros, reformats to standard `xx-yy-z`, validates check digit)
- Valid CAS numbers (non-NA after `as_cas()`) get DTXSID lookup via `ct_chemical_search_equal_bulk()`
- Invalid CAS (NA from `as_cas()`) are skipped — not usable as CAS numbers

### Error & miss handling
- All-tier misses: include input value in results table with NA for DTXSID and other fields (easy to count/filter)
- API errors (CompTox down, timeout, rate limit): fail fast, print error message. User re-runs when API is back
- Console progress messages via `message()` — e.g., "Searching 45 unique names...", "Falling back on 3 misses..."
- No checkpointing or partial save — re-run from scratch if interrupted (100 rows should be fast)

### Claude's Discretion
- Script file organization (single file vs modular functions)
- Exact console message wording and formatting
- How to structure the dedup step internally
- Test data generation approach

</decisions>

<specifics>
## Specific Ideas

- CompToxR functions to use: `ct_chemical_search_equal_bulk()` for exact match, `ct_chemical_search_start_with()` for starts-with fallback, `ComptoxR::as_cas()` + `ComptoxR::is_cas()` for CAS validation
- `searchName` field from CompToxR response tells you resolution method (approved name, CAS-RN, synonym) — use this instead of a manual tier column

</specifics>

<deferred>
## Deferred Ideas

- Multiple starts-with match resolution (picking best from ambiguous results) — Phase 4 consensus or later
- Checkpointing/partial save for large datasets — not needed for prototype scale

</deferred>

---

*Phase: 03-prototype-pipeline*
*Context gathered: 2026-02-27*
