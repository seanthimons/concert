# Requirements: ChemReg v1.9

**Defined:** 2026-04-14
**Core Value:** Users can go from messy regulatory/benchmark data files to validated, harmonized, toxval-compatible datasets in one workflow.

## v1.9 Requirements

Requirements for Number and Unit Coercion Harmonization milestone. Each maps to roadmap phases.

### Static Data Foundations

- [x] **DATA-01**: Unit conversion table (`inst/extdata/unit_conversion.rds`) with ECOTOX tribble (~200 rows) + regulatory extensions from SSWQS
- [x] **DATA-02**: ToxVal schema manifest (`inst/extdata/toxval_schema.rds`) — zero-row typed tibble for 56-column validation
- [x] **DATA-03**: `load_unit_map()` loader function in `cleaning_reference.R` following existing RDS caching pattern
- [ ] **DATA-04**: User-editable unit table UI following v1.3 reference list editor pattern with re-run cascade

### Numeric Parsing

- [x] **PARS-01**: Normalization chain — whitespace removal, `x10^` → `e`, Fortran exponents (`4.56+02`), comma stripping
- [x] **PARS-02**: Qualifier extraction (`<`, `>`, `<=`, `>=`, `~`) before any range splitting
- [ ] **PARS-03**: Range splitting with stable `.id` column — `"5-10"` → low/mid/high rows, numeric pre-guard to protect negatives and exponents
- [x] **PARS-04**: Parse result tibble structure: `numeric_value`, `qualifier`, `range_bin` (as_is/low/mid/high), `parse_flag`
- [x] **PARS-05**: `orig_result` capture as absolute first step before any transformation for audit trail
- [ ] **PARS-06**: One-off corrections table — user-editable `(pattern, replacement)` for source-specific malformed values

### Unit Harmonization

- [ ] **UNIT-01**: Case-safe unit lookup — case-sensitive match first, case-insensitive fallback flagged LOW confidence
- [ ] **UNIT-02**: Unit string normalization — micro-symbol variants (`µ`/`\u03BC` → `u`), latin-ascii, spacing around "per" → "/"
- [ ] **UNIT-03**: Compound unit decomposition — handle `mg/kg bw/day`, `mg/kg wet weight`, etc. via explicit enumeration
- [ ] **UNIT-04**: Unit conversion arithmetic — `parsed_value * multiplier`, store `conversion_factor` in audit trail
- [ ] **UNIT-05**: Harmonization result tibble: `harmonized_value`, `harmonized_unit`, `orig_unit`, `conversion_factor`, `unit_flag`
- [ ] **UNIT-06**: Unmatched-unit review UI — show unmatched units, allow inline add to unit table, re-run harmonization

### ToxVal Schema & Export

- [ ] **SCHM-01**: ToxVal 56-column schema transmutation with `*_original` audit columns for all harmonized fields
- [ ] **SCHM-02**: Typed NA (`NA_character_`, `NA_real_`) throughout — never bare `NA` to prevent parquet type mismatch
- [ ] **SCHM-03**: Parquet export via `arrow::write_parquet()` with explicit schema assertion; read-back validation test
- [ ] **SCHM-04**: CSV export fallback when arrow unavailable (arrow in Suggests with `requireNamespace()` guard)
- [ ] **SCHM-05**: `curate_headless()` extension with `harmonize=TRUE` param (default FALSE for backward compat)

### UI Integration

- [ ] **UITG-01**: Extended column tagging — add Result, Unit, Qualifier, Duration, DurationUnit, Species, ExposureRoute to selectInput choices
- [ ] **UITG-02**: Tag type dispatch — numeric pipeline receives only Result/Unit/Qualifier/Duration tags; chemical cleaning pipeline never receives them
- [ ] **UITG-03**: Cascade reset extension — null `harmonize_results`, `harmonize_audit`, `toxval_output` on re-upload, tag change, or re-run curation
- [ ] **UITG-04**: Harmonize tab module following `mod_run_curation.R` pattern — button-triggered pipeline, `withProgress()`, write to data_store
- [ ] **UITG-05**: Pre-export QC dashboard — value boxes: rows parsed, rows harmonized, rows with dtxsid, rows with NA toxval_numeric
- [ ] **UITG-06**: Sheet 8 "ToxVal Output" in existing Excel export (separate sheet, not merged with data)

## v2+ Requirements

Deferred to future release. Tracked but not in current roadmap.

### Exposure Classification

- **EXPR-01**: Protection code decoder (generalize SSWQS 55-row lookup to user-uploadable table)
- **EXPR-02**: Duration classification lookup (acute/subacute/subchronic/chronic/developmental/reproductive)
- **EXPR-03**: Habitat/media classification with controlled vocabulary

### Advanced Harmonization

- **ADVH-01**: Narrative filter review UI — show excluded rows with reason, allow curator confirmation
- **ADVH-02**: Range midpoint toggle — user choice: low/high/mid vs low/high only vs midpoint only
- **ADVH-03**: Automatic unit class inference from column name patterns

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| `units` CRAN package | Domain mismatch — does not know pCi/L, NTU, CFU/100mL, pH standard units |
| Automatic unit inference from column names | Anti-feature per research; produces untracked wrong conversions |
| Bidirectional unit conversion | No downstream use case; introduces floating-point drift |
| Real-time parsing as-you-type | Confusing UX; explicit "Run Harmonization" button preferred (consistent with v1.3 cleaning) |
| Cell-by-cell manual editing in harmonization | Doesn't scale; batch operations + one-off corrections table preferred |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| DATA-01 | Phase 29 | Complete |
| DATA-02 | Phase 29 | Complete |
| DATA-03 | Phase 29 | Complete |
| DATA-04 | Phase 34 | Pending |
| PARS-01 | Phase 30 | Complete |
| PARS-02 | Phase 30 | Complete |
| PARS-03 | Phase 30 | Pending |
| PARS-04 | Phase 30 | Complete |
| PARS-05 | Phase 30 | Complete |
| PARS-06 | Phase 34 | Pending |
| UNIT-01 | Phase 31 | Pending |
| UNIT-02 | Phase 31 | Pending |
| UNIT-03 | Phase 31 | Pending |
| UNIT-04 | Phase 31 | Pending |
| UNIT-05 | Phase 31 | Pending |
| UNIT-06 | Phase 34 | Pending |
| SCHM-01 | Phase 32 | Pending |
| SCHM-02 | Phase 32 | Pending |
| SCHM-03 | Phase 35 | Pending |
| SCHM-04 | Phase 35 | Pending |
| SCHM-05 | Phase 35 | Pending |
| UITG-01 | Phase 33 | Pending |
| UITG-02 | Phase 33 | Pending |
| UITG-03 | Phase 33 | Pending |
| UITG-04 | Phase 34 | Pending |
| UITG-05 | Phase 34 | Pending |
| UITG-06 | Phase 35 | Pending |

**Coverage:**
- v1.9 requirements: 27 total
- Mapped to phases: 27
- Unmapped: 0

---
*Requirements defined: 2026-04-14*
*Last updated: 2026-04-14 after initial definition*
