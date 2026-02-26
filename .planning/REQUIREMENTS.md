# Requirements: ChemReg — Curation UI Iteration

**Defined:** 2026-02-26
**Core Value:** Users can go from a messy chemical inventory file to validated, curated chemical data in one workflow

## v1 Requirements

Requirements for this iteration. Each maps to roadmap phases.

### Tab Structure

- [ ] **TAB-01**: Curation tab is replaced with 3 separate top-level tabs: Tag Columns, Run Curation, Review Results
- [x] **TAB-02**: Tag Columns tab is hidden until data is uploaded and detected successfully
- [x] **TAB-03**: Run Curation tab is hidden until at least one column is tagged
- [x] **TAB-04**: Review Results tab is hidden until curation completes successfully

### Tag Columns

- [ ] **TAG-01**: User can assign column types (Chemical Name, CASRN, Other) via dropdowns with full tab space
- [ ] **TAG-02**: User sees empty state message when tab is visible but no columns are selected
- [ ] **TAG-03**: Apply Tags button is present and functional

### Run Curation

- [ ] **CURE-01**: User sees tagged column summary before running curation
- [ ] **CURE-02**: User can click Start Curation to run CompTox lookup
- [ ] **CURE-03**: User sees progress feedback during curation

### Review Results

- [ ] **REV-01**: User sees curation statistics (CAS validated, names matched)
- [ ] **REV-02**: User can browse curated results in a data table
- [ ] **REV-03**: User can download curated data as Excel

### UX Polish

- [x] **UX-01**: Tabs start hidden using nav_panel_hidden() (no flash on startup)
- [x] **UX-02**: Back navigation works — completed tabs remain accessible
- [ ] **UX-03**: Each tab uses full available space instead of nested cards

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Progress & Feedback

- **PROG-01**: Visual progress indicator showing current step (e.g., "Step 2 of 3")
- **PROG-02**: Completion checkmarks on finished tabs
- **PROG-03**: Step validation summary ("2 columns still need tags")

### Convenience

- **CONV-01**: Batch tagging ("Tag all as Chemical Name")
- **CONV-02**: Undo/reset step without restarting workflow
- **CONV-03**: Inline help tooltips for tagging options

## Out of Scope

| Feature | Reason |
|---------|--------|
| Drag-and-drop column tagging | Decided against — dropdowns simpler, more accessible |
| Wizard-style Next/Back navigation | Tabs preferred — users see all steps upfront |
| Sub-tabs within curation section | Top-level tabs chosen for visibility |
| Auto-advance to next tab | Disorienting — users should control navigation |
| Session persistence across browser refresh | High complexity, defer to future |
| New tag types or curation features | Not in scope for this UI iteration |
| Changes to upload/detection/export logic | Existing pipeline untouched |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| TAB-01 | Phase 1 | Pending |
| TAB-02 | Phase 2 | Complete |
| TAB-03 | Phase 2 | Complete |
| TAB-04 | Phase 2 | Complete |
| TAG-01 | Phase 1 | Pending |
| TAG-02 | Phase 1 | Pending |
| TAG-03 | Phase 1 | Pending |
| CURE-01 | Phase 1 | Pending |
| CURE-02 | Phase 1 | Pending |
| CURE-03 | Phase 1 | Pending |
| REV-01 | Phase 1 | Pending |
| REV-02 | Phase 1 | Pending |
| REV-03 | Phase 1 | Pending |
| UX-01 | Phase 2 | Complete |
| UX-02 | Phase 2 | Complete |
| UX-03 | Phase 1 | Pending |

**Coverage:**
- v1 requirements: 16 total
- Mapped to phases: 16
- Unmapped: 0 ✓

---
*Requirements defined: 2026-02-26*
*Last updated: 2026-02-26 after roadmap creation*
