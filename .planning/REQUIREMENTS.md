# Requirements: ChemReg

**Defined:** 2026-03-04
**Core Value:** Users can go from a messy chemical inventory file to validated, curated chemical data in one workflow — upload, detect, tag, curate, resolve, export.

## v1.3 Requirements

Requirements for v1.3 Data Cleaning Pipeline. Each maps to roadmap phases.

### Modularization (MODL)

- [ ] **MODL-01**: User can use all existing app functionality after codebase is refactored into Shiny modules
- [ ] **MODL-02**: App.R is reduced to orchestration-only code (<500 lines) with each tab extracted to its own module

### Infrastructure (INFRA)

- [ ] **INFRA-01**: User can see a per-row audit trail showing every cleaning transformation applied (what changed and why)
- [ ] **INFRA-02**: User can configure reference lists (stop words, block lists, functional categories) that are loaded at app startup
- [ ] **INFRA-03**: Unicode characters in chemical names and CAS fields are automatically cleaned to ASCII equivalents via ComptoxR::clean_unicode()
- [ ] **INFRA-04**: Leading/trailing punctuation, whitespace, and extraction artifacts (underscores, asterisks) are automatically stripped from all text fields

### CAS-RN Cleaning (CAS)

- [ ] **CAS-01**: User can see placeholder text in CAS fields ('no cas', 'n/a', 'proprietary', '-', 'withheld', etc.) detected and set to NA with audit comment
- [ ] **CAS-02**: User can see CAS-RNs normalized to canonical NNN-NN-N format with checksum validation; invalid CAS set to NA with audit comment
- [ ] **CAS-03**: User can see CAS-RNs embedded in chemical name columns extracted, moved to the CAS column, and stripped from the name
- [ ] **CAS-04**: User can see rows with multiple CAS-RNs split into separate rows with audit comment logging the original multi-CAS value

### Chemical Name Cleaning (NAME)

- [ ] **NAME-01**: User can see trailing parentheticals and brackets stripped from chemical names, with protection for chemical name fragments containing "yl"
- [ ] **NAME-02**: User can see formulas and CAS-RNs extracted from parentheticals and preserved as separate tagged values for curation
- [ ] **NAME-03**: User can see comma/semicolon-separated synonyms split into separate entries, with IUPAC inverted-name comma protection (digit-comma-digit patterns preserved)
- [ ] **NAME-04**: User can see quality adjectives ('tech grade', 'pure'), salt references ('and its salts'), and 'unspecified' suffixes stripped from names with audit comments

### Reference Data Filters (FILT)

- [ ] **FILT-01**: Functional and product use category reference lists are seeded from ComptoxR functions and cached locally as baseline data
- [ ] **FILT-02**: User can enrich all reference lists (functional/product categories, stop words, block list) via file upload or manual entry on top of seeded baseline
- [ ] **FILT-03**: User can see names matching reference list entries flagged as warning, with match source indicated (ComptoxR-seeded vs user-added vs app-default)
- [ ] **FILT-04**: User can see bare molecular formulas (H2O, NaCl, CuSO4) detected and flagged as blocking (name set to NA, CAS still curated)
- [ ] **FILT-05**: User can edit all reference lists (add/remove entries) via in-app editors and re-run cleaning with updated lists
- [ ] **FILT-06**: User can see blocking flags (red) visually distinguished from warning flags (yellow) with clear indication of which block curation vs which annotate only

### Clean Data Tab & UX (UIUX)

- [ ] **UIUX-01**: User can access a "Clean Data" tab between Data Preview and Tag Columns in the gated workflow
- [ ] **UIUX-02**: User can see summary cards showing cleaning statistics (CAS rescued, formulas detected, synonyms split, rows flagged, etc.)
- [ ] **UIUX-03**: User can see before/after data comparison showing cleaning transformations applied to their data
- [ ] **UIUX-04**: User can run cleaning pipeline with step-by-step progress indicator
- [ ] **UIUX-05**: User can re-run cleaning after modifying reference lists, with downstream state (tags, curation) properly invalidated

### Export & Re-Import (EXPO)

- [ ] **EXPO-01**: User can export a multi-sheet Excel file containing curated data, cleaning audit trail, reference list state, and pipeline configuration
- [ ] **EXPO-02**: User can re-import a ChemReg export and see a confirmation modal offering to restore embedded reference lists and pipeline state
- [ ] **EXPO-03**: User can see the multi-sheet export serve as both a standalone audit document and a ChemReg re-entry point

### Post-Curation QC (POST)

- [ ] **POST-01**: User can see resolved CAS-RNs re-validated after curation, with any invalid CAS flagged
- [ ] **POST-02**: User can see any remaining non-ASCII characters flagged in the final output as a QC check

## v1.4+ Requirements

Deferred to future releases. Tracked but not in current roadmap.

### Enrichment

- **ENRCH-01**: User can see resolved chemicals enriched with OECD functional use categories via CompTox API
- **ENRCH-02**: User can see resolved chemicals enriched with safety flags via CompTox API

### UX Polish

- **UIPX-01**: User can see richer context in resolution dropdown (carried from v1.2)
- **UIPX-02**: User can see improved column visibility in Review Results table (carried from v1.2)
- **FOOD-01**: User can see food names (yeast culture, sweet whey, etc.) flagged as a separate reference category

## Out of Scope

| Feature | Reason |
|---------|--------|
| Hazard warning stripping as standalone step | Handled by extracting useful content (formulas, CAS-RNs) from parentheticals + sending remaining strings through curation as "Other" tag |
| Drag-and-drop pipeline builder | High complexity, low ROI; fixed pipeline with reference list editing is sufficient |
| Real-time cleaning as-you-type | Confusing UX; explicit "Run Cleaning" button with before/after preview preferred |
| AI/ML-powered cleaning | Opaque audit trail, chemical names too domain-specific for generic models |
| Cell-by-cell manual editing in cleaning tab | Doesn't scale; batch operations + flag exceptions preferred |
| Session persistence across browser refresh | High complexity, defer to future |
| Contains search tier | Too fuzzy, may produce unreliable matches (carried from v1.2) |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| MODL-01 | Phase 9 | Pending |
| MODL-02 | Phase 9 | Pending |
| INFRA-01 | Phase 10 | Pending |
| INFRA-02 | Phase 10 | Pending |
| INFRA-03 | Phase 10 | Pending |
| INFRA-04 | Phase 10 | Pending |
| UIUX-01 | Phase 10 | Pending |
| CAS-01 | Phase 11 | Pending |
| CAS-02 | Phase 11 | Pending |
| CAS-03 | Phase 11 | Pending |
| CAS-04 | Phase 11 | Pending |
| UIUX-02 | Phase 11 | Pending |
| UIUX-04 | Phase 11 | Pending |
| NAME-01 | Phase 12 | Pending |
| NAME-02 | Phase 12 | Pending |
| NAME-03 | Phase 12 | Pending |
| NAME-04 | Phase 12 | Pending |
| UIUX-03 | Phase 12 | Pending |
| FILT-01 | Phase 13 | Pending |
| FILT-02 | Phase 13 | Pending |
| FILT-03 | Phase 13 | Pending |
| FILT-04 | Phase 13 | Pending |
| FILT-05 | Phase 13 | Pending |
| FILT-06 | Phase 13 | Pending |
| UIUX-05 | Phase 13 | Pending |
| EXPO-01 | Phase 14 | Pending |
| EXPO-02 | Phase 14 | Pending |
| EXPO-03 | Phase 14 | Pending |
| POST-01 | Phase 15 | Pending |
| POST-02 | Phase 15 | Pending |

**Coverage:**
- v1.3 requirements: 30 total
- Mapped to phases: 30
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-04*
*Last updated: 2026-03-04 after roadmap creation*
