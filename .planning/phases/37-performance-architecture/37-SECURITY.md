---
phase: 37-performance-architecture
status: open_threats
threats_total: 7
threats_closed: 5
threats_open: 2
audited: 2026-04-24
---

# Security Audit — Phase 37: Performance Architecture

## OPEN_THREATS

**Phase:** 37 — performance-architecture
**Closed:** 5/7 | **Open:** 2/7
**ASVS Level:** 1

---

### Closed Threats

| Threat ID | Category | Disposition | Evidence |
|-----------|----------|-------------|----------|
| T-37-01 | Tampering | mitigate | `R/cleaning_pipeline.R` line 233: `stopifnot(max(remapped_audit$row_id) <= nrow(df))` inside `dedup_step`; companion test at `tests/testthat/test-dedup-infrastructure.R` line 238 (PERF-02 sentinel test) |
| T-37-02 | Information Disclosure | mitigate | `R/cleaning_pipeline.R` lines 186-189: `ifelse(is.na(vals), "__NA__", as.character(vals))` in dedup key construction (T-37-02 comment at line 185); NA handling test at `tests/testthat/test-dedup-infrastructure.R` line 162 |
| T-37-03 | Denial of Service | mitigate | `R/cleaning_pipeline.R` line 197: `n_distinct / n_total > uniqueness_threshold` bypass with `uniqueness_threshold = 0.5`; D-03 bypass test at `tests/testthat/test-dedup-infrastructure.R` line 95 |
| T-37-04 | Tampering | mitigate | Same `stopifnot` assertion at `R/cleaning_pipeline.R` line 233 covers audit row_id range enforcement (PERF-02); PERF-02 sentinel error test at `tests/testthat/test-dedup-infrastructure.R` line 238 uses `expect_error` to verify assertion fires |
| T-37-10 | Denial of Service | accept | Name columns are typically 1-2 columns; composite key size is bounded by column count. The D-03 uniqueness bypass (verified under T-37-03 above) handles any high-cardinality degenerate case. No additional mitigation required. |

---

### Open Threats

| Threat ID | Category | Mitigation Expected | Files Searched |
|-----------|----------|---------------------|----------------|
| T-37-08 | Tampering | `name_chain_pass1` composite function with `dplyr::bind_rows(audit_parts)` inside `run_cleaning_pipeline()`; steps 6-pre through 6d3 grouped into one dedup pass | `R/cleaning_pipeline.R` (lines 1784-1839, orchestrator name chain section) |
| T-37-09 | Tampering | `name_chain_pass2` composite function wrapping Steps 7-9 in `dedup_step()` on `df_final` (post-synonym row set); test confirming row_ids valid after synonym-induced row expansion | `R/cleaning_pipeline.R` (lines 1865-1878, orchestrator Steps 7-9); `tests/testthat/test-cleaning-pipeline.R` |

---

### Gap Detail

**T-37-08 and T-37-09 — Plan 03 orchestrator migration not applied**

The 37-03-SUMMARY.md reports that `run_cleaning_pipeline()` was fully migrated with `name_chain_pass1`, `name_chain_pass2`, and `dedup_step()` wiring for all dedup-eligible steps (commits `8db7378` and `168c0ce`). However, the current state of `R/cleaning_pipeline.R` shows the orchestrator still using direct individual step calls for steps 6-pre through 9, with no composite functions, no `dedup_step()` wrappers in the name chain section, and no precheck predicates.

The `use_dedup` parameter is declared in the roxygen comment at line 1713 but is not referenced anywhere in the function body (lines 1730-1894). The `name_chain_pass1` and `name_chain_pass2` closures described in Plan 03 are absent. Steps 7-9 (`expand_isotope_shortcodes`, `flag_multi_analyte`, `restore_chiral_designations`) are called directly at lines 1866-1878 without dedup wrapping.

The consequence for T-37-08: the composite function's `dplyr::bind_rows(audit_parts)` accumulation pattern is not present, so the audit completeness guarantee for the name chain group depends solely on the individual per-step `bind_rows` calls in the existing orchestrator. Those calls are present, so audit entries are not currently lost — but the declared mitigation architecture (composite dedup function) does not exist.

The consequence for T-37-09: Pass 2 dedup is absent, so no dedup key is constructed on the post-synonym `df_final` row set. The stale-key risk does not materialize in the current code because dedup is not applied at all in Pass 2, but the intended mitigation (validated dedup on the correct row set) is not in place.

**Next steps:** Implement Plan 03 orchestrator migration or document both threats as accepted risks with explicit rationale in this file, then re-run `/gsd-secure-phase`.

---

### Unregistered Flags

37-03-SUMMARY.md `## Threat Flags` section states: "None — no new network endpoints, auth paths, or schema changes introduced."

No unregistered threat flags to log.

---

### Accepted Risks Log

| Threat ID | Risk Description | Acceptance Rationale | Accepted Date |
|-----------|-----------------|----------------------|---------------|
| T-37-10 | Denial of Service — dedup on wide name columns creates large composite paste0 keys | Name columns are typically 1-2 per dataset. Key length is bounded by column count, not row count. The D-03 uniqueness bypass (0.5 threshold) further limits overhead when data is already high-cardinality. No unbounded growth path exists in practice. | 2026-04-24 |
