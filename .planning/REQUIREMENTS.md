# Requirements: ChemReg

**Defined:** 2026-03-31
**Core Value:** Users can go from a messy chemical inventory file to validated, curated chemical data in one workflow — upload, detect, clean, tag, curate, resolve, export.

## v1.7 Requirements

Requirements for v1.7 UI Polish & Isotope Cleaning. Each maps to roadmap phases.

### UI Polish

- [x] **UIPOL-01**: Review Results DT table column headers wrap to show full text instead of truncating
- [x] **UIPOL-02**: Remove explicit widget ID from results table to silence `renderWidget` warning
- [x] **UIPOL-03**: Convert named vectors to named lists to fix `jsonlite` deprecation warning

### Isotope Cleaning

- [x] **ISOT-01**: Isotope shortcode expansion step added to pre-curation cleaning pipeline, ordered before bare formula detection
- [x] **ISOT-02**: Known isotope list (from ComptoxR) used for greedy matching — short element codes (<5 chars) expanded to full element names (e.g., `u234` → `Uranium-234`). Naked shortcodes AND spelled-out/hyphenated forms normalized to `Name-Mass` format.
- [x] **ISOT-03**: Carbon backbone patterns and deuterium d-prefix patterns excluded from expansion
- [x] **CHIR-01**: Chiral designation protection — `(+)`, `(-)`, `(±)`, `(R)`, `(S)` etc. protected from enclosure stripping via placeholder pattern and flagged with WARNING
- [x] **MANA-01**: Multi-analyte flagging — rows with naked ` + ` or ` and ` between analyte tokens flagged as WARNING (no auto-split)

## Future Requirements

(None deferred from this milestone)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Comparison modal data updates | Deferred — user needs more time to decide what to show |
| Isotope expansion for long/ambiguous codes | Only short (<5 char) element codes; longer codes too risky for false positives |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| UIPOL-01 | Phase 22 | Complete |
| UIPOL-02 | Phase 22 | Complete |
| UIPOL-03 | Phase 22 | Complete |
| ISOT-01 | Phase 23 | Complete |
| ISOT-02 | Phase 23 | Complete |
| ISOT-03 | Phase 23 | Complete |
| CHIR-01 | Phase 23 | Complete |
| MANA-01 | Phase 23 | Complete |

**Coverage:**
- v1.7 requirements: 8 total
- Mapped to phases: 8
- Unmapped: 0

---
*Requirements defined: 2026-03-31*
*Last updated: 2026-03-31 after roadmap creation*
