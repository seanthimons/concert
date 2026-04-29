---
phase: 37-performance-architecture
status: secured
threats_total: 13
threats_closed: 13
threats_open: 0
audited: 2026-04-25
---

## Threat Register

| Threat ID | Category | Component | Disposition | Status | Evidence |
|-----------|----------|-----------|-------------|--------|----------|
| T-37-01 | Tampering | remap_audit_to_parent | mitigate | CLOSED | `R/cleaning_pipeline.R:233` — `stopifnot(max(remapped_audit$row_id) <= nrow(df))` inside `dedup_step()`; companion assertion test at `tests/testthat/test-dedup-infrastructure.R:238-260` |
| T-37-02 | Information Disclosure | dedup key with NAs | mitigate | CLOSED | `R/cleaning_pipeline.R:188` — `ifelse(is.na(vals), "__NA__", as.character(vals))` before `paste0` key construction; NA grouping behavior tested at `tests/testthat/test-dedup-infrastructure.R:162-188` |
| T-37-03 | Denial of Service | dedup on high-cardinality columns | mitigate | CLOSED | `R/cleaning_pipeline.R:197` — `if (n_total == 0 \|\| n_distinct / n_total > uniqueness_threshold)` bypass with default threshold 0.5; tested at `tests/testthat/test-dedup-infrastructure.R:95-124` (D-03 uniqueness bypass) |
| T-37-04 | Tampering | audit row_id out of range | mitigate | CLOSED | `R/cleaning_pipeline.R:232-234` — `stopifnot(max(remapped_audit$row_id) <= nrow(df))` (same PERF-02 assertion as T-37-01); error path exercised by `tests/testthat/test-dedup-infrastructure.R:238-260` (bad parent_map with index 999 into 3-row parent) |
| T-37-05 | Tampering | precheck returns FALSE incorrectly | mitigate | CLOSED | SKIP-03 false-negative companion tests present for all 7 pre-check functions in `tests/testthat/test-precheck-infrastructure.R`: lines 65 (unicode), 106 (trim), 149 (CAS), 190 (name_cleaning), 241 (isotope), 284 (multi_analyte), 330 (chiral_restore) |
| T-37-06 | Denial of Service | precheck itself is expensive | accept | CLOSED | Accepted — see Accepted Risks section |
| T-37-07 | Information Disclosure | est_changes leaks row counts | accept | CLOSED | Accepted — see Accepted Risks section |
| T-37-08 | Tampering | Composite name chain loses audit entries | mitigate | CLOSED | `R/cleaning_pipeline.R:2083` — `dplyr::bind_rows(audit_parts)` inside `name_chain_pass1`; `R/cleaning_pipeline.R:2147` — `dplyr::bind_rows(audit_parts)` inside `name_chain_pass2`; integration test at `tests/testthat/test-cleaning-pipeline.R:129-146` validates audit trail is non-empty after full pipeline run |
| T-37-09 | Tampering | Pass 2 dedup keys stale after synonym split | mitigate | CLOSED | `R/cleaning_pipeline.R:2163-2169` — `dedup_step(name_chain_pass2, df_final, ...)` where `df_final` is the post-synonym, post-empty-row-removal dataset (`R/cleaning_pipeline.R:2126`); integration test at `tests/testthat/test-cleaning-pipeline.R:141` asserts `result$audit_trail$row_id <= nrow(result$cleaned_data)` on full pipeline including synonym-split path |
| T-37-10 | Denial of Service | Dedup on wide name columns | accept | CLOSED | Accepted — see Accepted Risks section |
| T-37-11 | Tampering | Unit-key groups wrong rows together | mitigate | CLOSED | `R/unit_harmonizer.R:374` — `paste0(normalized[ppx_mask], "\|\|", media_vec[ppx_mask])` includes media in ppx key; `R/unit_harmonizer.R:375` — `paste0(normalized[molarity_mask], "\|\|", mw_vec[molarity_mask])` includes mw in molarity key; tested at `tests/testthat/test-unit-harmonizer.R:841-856` (ppb + aqueous vs solid produces distinct `harmonized_unit` values "mg/L" vs "mg/kg") |
| T-37-12 | Tampering | match() returns NA for unknown key | mitigate | CLOSED | `R/unit_harmonizer.R:477` — `stopifnot(!anyNA(key_to_unique))` with comment "T-37-12: match is guaranteed (unique_keys derived from dedup_keys)" |
| T-37-13 | Denial of Service | paste0 on large vectors | accept | CLOSED | Accepted — see Accepted Risks section |

## Accepted Risks

### T-37-06: Denial of Service — precheck itself is expensive

**Rationale:** All pre-check predicate functions use cheap vectorized primitives that scan data at O(n) in a single pass. Specifically: `precheck_unicode_to_ascii` uses `stringi::stri_enc_isascii` (C-level vectorized), `precheck_trim_whitespace` uses `clean_text_field` once per column (vectorized), `precheck_isotope_shortcodes` uses `stringr::str_detect` (vectorized regex), and `precheck_multi_analyte` uses `stringr::str_detect`. The cost of each pre-check is negligible relative to the step it gates. No mitigation is required.

**Plan reference:** 37-02-PLAN.md threat register T-37-06.

---

### T-37-07: Information Disclosure — est_changes leaks row counts

**Rationale:** `est_changes` is a field in the internal `list(should_run, est_changes)` return contract of pre-check functions. It is only consumed inside `run_cleaning_pipeline()` (as a future enabler for RECO-01 in Phase 42) and is never exposed via any user-facing API, Shiny reactive output, or logged output. No information disclosure path exists to external parties.

**Plan reference:** 37-02-PLAN.md threat register T-37-07.

---

### T-37-10: Denial of Service — Dedup on wide name columns creates large composite keys

**Rationale:** Name columns in this pipeline are typically 1-2 columns (e.g., `chemical_name`). The `paste0` composite key for two columns is bounded and presents no overhead. Additionally, the uniqueness bypass at threshold 0.5 (D-03, verified as T-37-03) handles the case where the name column is effectively unique, short-circuiting to direct processing before any dedup overhead accumulates.

**Plan reference:** 37-03-PLAN.md threat register T-37-10.

---

### T-37-13: Denial of Service — paste0 on large vectors

**Rationale:** `paste0` in R is O(n) vectorized and operates at the C level. For 100K rows it is measured in milliseconds. The dedup savings on subsequent expensive string operations (CAS normalization, unicode conversion, regex-based name stripping) far exceed the key-construction cost. No mitigation is warranted.

**Plan reference:** 37-04-PLAN.md threat register T-37-13.

## Security Audit 2026-04-25

| Metric | Value |
|--------|-------|
| Phase | 37-performance-architecture |
| Plans audited | 37-01, 37-02, 37-03, 37-04 |
| ASVS Level | 1 |
| Threats total | 13 |
| Threats closed | 13 |
| Threats open | 0 |
| Mitigate disposition | 9 |
| Accept disposition | 4 |
| Transfer disposition | 0 |
| Unregistered threat flags | 0 (37-03-SUMMARY.md reports none) |
| Implementation files verified | R/cleaning_pipeline.R, R/unit_harmonizer.R |
| Test files verified | tests/testthat/test-dedup-infrastructure.R, tests/testthat/test-precheck-infrastructure.R, tests/testthat/test-cleaning-pipeline.R, tests/testthat/test-unit-harmonizer.R |

All 9 mitigate-disposition threats have verified implementation evidence (code assertions and/or test coverage) in the implementation files. All 4 accept-disposition threats have documented rationale above. No unregistered threat flags were identified in either SUMMARY.md file.
