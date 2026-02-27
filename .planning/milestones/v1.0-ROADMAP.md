# Roadmap: ChemReg — Curation UI Iteration

## Overview

Transform ChemReg's curation workflow from a single stacked-card tab into a multi-tab gated experience. Users currently scroll through vertically stacked cards (Tag Columns → Run Curation → Review Results) in one "Curation" tab. This iteration breaks each step into its own top-level tab with conditional visibility based on workflow state. The result: clearer workflow steps, better space utilization, and guided progression through upload → tag → curate → review → export.

## Phases

**Phase Numbering:**
- Integer phases (1, 2): Planned milestone work
- Decimal phases (1.1, 1.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Multi-Tab Structure** - Extract curation cards into 3 separate tabs with full-width layouts
- [x] **Phase 2: Gated Navigation** - Implement conditional tab visibility based on workflow state

## Phase Details

### Phase 1: Multi-Tab Structure
**Goal**: Users can access Tag Columns, Run Curation, and Review Results as separate top-level tabs instead of stacked cards
**Depends on**: Nothing (first phase)
**Requirements**: TAB-01, TAG-01, TAG-02, TAG-03, CURE-01, CURE-02, CURE-03, REV-01, REV-02, REV-03, UX-03
**Success Criteria** (what must be TRUE):
  1. User sees "Tag Columns", "Run Curation", and "Review Results" as separate tabs in main navigation
  2. User can assign column types via dropdowns in Tag Columns tab with full available width
  3. User can start curation and see progress in Run Curation tab
  4. User can browse results and download Excel in Review Results tab
  5. All tabs use full available space without nested card containers
**Plans**: 1 plan

Plans:
- [x] 01-01-PLAN.md -- Restructure UI into 6 tabs with full-width layout, sidebar toggle, and behavioral polish

### Phase 2: Gated Navigation
**Goal**: Users follow the correct workflow sequence because tabs appear only when prerequisites are met
**Depends on**: Phase 1
**Requirements**: TAB-02, TAB-03, TAB-04, UX-01, UX-02
**Success Criteria** (what must be TRUE):
  1. User cannot see Tag Columns tab until data is uploaded and detected successfully
  2. User cannot see Run Curation tab until at least one column is tagged
  3. User cannot see Review Results tab until curation completes successfully
  4. User can navigate back to completed steps (Tag Columns remains accessible after proceeding to Run Curation)
  5. No flash of hidden tabs on app startup
**Plans**: 1 plan

Plans:
- [x] 02-01-PLAN.md -- Implement gated tab navigation with conditional visibility, cascade reset, and re-upload confirmation modal

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Multi-Tab Structure | 1/1 | Complete | 2026-02-26 |
| 2. Gated Navigation | 1/1 | Complete | 2026-02-26 |
