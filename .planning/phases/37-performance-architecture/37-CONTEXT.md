# Phase 37: Performance Architecture - Context

**Gathered:** 2026-04-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Make the cleaning and harmonization pipelines production-fast at 100K+ rows via distinct-string dedup and short-circuit evaluation. No new pipeline steps, no new UI features, no new tag types. Pure performance architecture applied to existing pipelines.

</domain>

<decisions>
## Implementation Decisions

### Dedup Eligibility
- **D-01:** All string-in/string-out steps are dedup-eligible. Excludes synonym splitting (changes row count), CAS rescue from text (adds columns), and multi-CAS detection (adds flag columns).
- **D-02:** Dedup scoped to columns each step actually processes — CAS steps dedup CAS-tagged columns, Name steps dedup Name-tagged columns, Other/harmonization-tagged columns dedup when they're being processed by a step.
- **D-03:** `dedup_step()` includes a runtime uniqueness check — if `n_distinct / n_total > 0.5`, bypass dedup and run the step directly. Threshold is tunable.

### Pre-check Behavior
- **D-04:** Skipped steps produce an empty typed audit tibble (zero rows, correct 6 columns) PLUS a `message()` log line (e.g., "Step unicode_to_ascii skipped -- pre-check FALSE"). Audit trail stays clean for code; console shows skip decisions for debugging.
- **D-05:** Pre-checks use cheap full-column vectorized scans via existing stringr/stringi primitives (e.g., `stringi::stri_enc_isascii()` for unicode detection). No sampling.
- **D-06:** Pre-checks return `list(should_run = TRUE/FALSE, est_changes = integer)` — the estimated change count front-loads Phase 42's recommendation modal (RECO-01) needs.

### Harmonization Dedup
- **D-07:** Harmonization uses unit-key dedup — compute conversion factor once per distinct unit combo (unit string for standard, unit+media for ppx, unit+MW for molarity), then broadcast-multiply to all matching rows. The numeric value is NOT part of the dedup key since multiplication is already O(1) vectorized.

### Migration Sequence
- **D-08:** Parallel tracks — cleaning pipeline and harmonization dedup proceed simultaneously since they're independent codepaths with separate tests.
- **D-09:** Within the cleaning track, simple-first order: unicode -> whitespace -> CAS normalization -> name cleaning chain -> remaining steps.
- **D-10:** Name cleaning chain uses two dedup passes split at the synonym boundary. Pre-synonym steps (chiral protect through second enclosures) share one dedup pass. Synonym split runs without dedup. Post-synonym steps (isotope, multi-analyte, chiral restore) share a second dedup pass on the new row set. 2 dedup cycles instead of 8.

### Carried Forward (from v2.0 research)
- **D-11:** Dedup is an orchestrator wrapper (`dedup_step()`), NOT internal to step functions. Step functions keep their existing `list(cleaned_data, audit_trail)` contract unchanged.
- **D-12:** Short-circuit pre-checks are orchestrator-only. Step functions always receive data and return results — they don't know about skipping.
- **D-13:** Migration is one step at a time with 953+ tests green after each migration.

### Claude's Discretion
- Exact implementation of `dedup_step()` wrapper and `remap_audit_to_parent()` internals
- Pre-check predicate function signatures and naming conventions
- Test structure for SKIP-03 false-negative companion tests
- How the uniqueness threshold bypass is implemented (config param vs. hardcoded)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Performance Architecture
- `.planning/REQUIREMENTS.md` -- PERF-01 through PERF-04 and SKIP-01 through SKIP-03 requirements
- `.planning/ROADMAP.md` -- Phase 37 success criteria (5 criteria)

### Existing Pipeline Code
- `R/cleaning_pipeline.R` -- Current 15-step cleaning pipeline with `run_cleaning_pipeline()` orchestrator (line 1546+)
- `R/unit_harmonizer.R` -- `harmonize_units()` function (line 261+) with three conversion paths (standard, ppx, molarity)
- `R/cleaning_pipeline.R` lines 50-98 -- `build_audit_trail()` pattern for audit trail construction

### Pipeline Consumers
- `R/curate_headless.R` -- `curate_headless()` calls cleaning pipeline and harmonization
- `R/mod_harmonize.R` -- Shiny module calls `harmonize_units()` interactively

### Audit Trail Contract
- `R/cleaning_pipeline.R` lines 79-97 -- 6-column audit tibble schema (row_id, field, step, original_value, new_value, reason)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `build_audit_trail()`: Vectorized audit trail builder with pre-allocated vectors — serves as the pattern for dedup audit remap
- `inject_row_lineage()`: Row lineage tracking already in pipeline — dedup remap must preserve lineage
- Hash-based unit lookup in `harmonize_units()` (line 400): Already uses `stats::setNames()` hash maps for O(1) lookups — unit-key dedup extends this pattern
- Existing MW dedup in `harmonize_units()` (line 340): `unique_dtxsids <- unique(dtxsid_vec[needs_api_lookup])` — partial dedup already exists for API calls

### Established Patterns
- Every cleaning step returns `list(cleaned_data, audit_trail)` — dedup wrapper must preserve this contract
- Audit trail uses 6-column tibble schema: row_id, field, step, original_value, new_value, reason
- `dplyr::bind_rows()` accumulates audit trails sequentially in the orchestrator
- Tag-dependent steps receive `tag_map` and operate only on tagged columns

### Integration Points
- `run_cleaning_pipeline()` is the single orchestration point — `dedup_step()` and pre-checks integrate here
- `harmonize_units()` is called from `mod_harmonize.R` (Shiny) and `curate_headless.R` (headless) — dedup must work in both paths
- Test suite at 953+ tests validates each step independently — migration can use existing tests as regression safety net

</code_context>

<specifics>
## Specific Ideas

- User noted that stringr/stringi already have unicode detection primitives (e.g., `stringi::stri_enc_isascii()`) — use these for pre-checks rather than custom regex
- Double dedup concept for harmonization: unit-key dedup for conversion factor computation, then vectorized multiply for actual values — avoids deduping on (value, unit) pairs since multiplication is already O(1)
- Synonym split as a hard structural boundary in the name chain was identified during red-teaming — this constraint shapes the two-pass dedup architecture

</specifics>

<deferred>
## Deferred Ideas

None -- discussion stayed within phase scope

</deferred>

---

*Phase: 37-performance-architecture*
*Context gathered: 2026-04-24*
