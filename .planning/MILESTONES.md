# Milestones

## v1.5 Disagreement Enrichment (Shipped: 2026-03-13)

**Phases completed:** 2 phases, 2 plans, 5 tasks
**Lines of code:** +822 across 7 R files
**Requirements:** 11/11 satisfied (ENRCH, COMP, COMPAT)
**Timeline:** 2 days (2026-03-10 → 2026-03-12)

**Key accomplishments:**
- CompTox enrichment pipeline with CASRN, molecular formula, and molecular weight via `ct_chemical_detail` with incremental caching
- Source column attribution and search tier labels per candidate (Exact/CAS/Starts-with/No match)
- Rich comparison modal replacing dropdown for disagree row resolution — card layout with enriched metadata
- Two-step resolution pattern (Select + Confirm) preventing accidental clicks, with Skip and Change options
- Consensus enrichment columns in 7-sheet Excel export (consensus_casrn, consensus_formula, consensus_mw)

---

## v1.4 Cleaning Pipeline Fixes (Shipped: 2026-03-10)

**Phases completed:** 1 phases, 2 plans, 4 tasks

**Key accomplishments:**
- (none recorded)

---

## v1.3 Data Cleaning Pipeline (Shipped: 2026-03-10)

**Phases completed:** 7 phases, 15 plans, 16 tasks
**Lines of code:** 14,548 across 18 R files (97 files changed, +25,372 / -3,880)
**Requirements:** 30/30 satisfied (MODL, INFRA, CAS, NAME, FILT, UIUX, EXPO, POST)
**Timeline:** 7 days (2026-03-04 → 2026-03-10)

**Key accomplishments:**
- Extracted 7 Shiny modules from monolithic app.R (2,276 → 203 lines) with full backward compatibility
- Built 12-step cleaning pipeline: unicode normalization, CAS rescue/validation/multi-CAS split, IUPAC-aware name cleaning with synonym splitting, reference-based flagging
- Provenance-tracked reference lists (ComptoxR-seeded + user-editable) with blocking/warning flag system and re-run cascade
- 7-sheet Excel export carrying curated data, audit trail, reference lists, and pipeline config with re-import detection
- Post-curation QC with ComptoxR's 157 chemistry-specific unicode mappings and auto-run on curation complete
- Value box dashboard, step-by-step progress indicator, and audit trail accordion for full cleaning pipeline visibility

**UAT:** All phases verified (7/7 VERIFICATION.md passed)

---

## v1.0 Curation UI Iteration (Shipped: 2026-02-27)

**Phases completed:** 2 phases, 2 plans, 0 tasks

**Key accomplishments:**
- Split single Curation tab into 3 top-level tabs: Tag Columns, Run Curation, Review Results
- Full-width layouts replacing nested card containers (navset_underline)
- Gated tab visibility — tabs appear only when workflow prerequisites are met
- Cascade reset on re-upload (confirmation modal) and tag changes
- CSS pulse animation on newly unlocked tabs
- Auto-switch to Review Results after curation completes

---


## v1.1 Curation Process Update (Shipped: 2026-03-01)

**Phases completed:** 3 phases, 6 plans, 10 tasks
**Lines of code:** 3,612 across 6 R files
**Requirements:** 15/15 satisfied (PROTO, DEDUP, CURE, CONS, INTG)

**Key accomplishments:**
- TDD-built pipeline with 6 modular functions: dedup tagged columns, tiered CompTox search (exact/starts-with/CAS), and result mapping
- Pipeline validated against sample_messy.csv (4 rows) and uncurated_chemicals (100 rows, 75 unique names, 49 unique CAS)
- Consensus classification with 5 status labels (agree/agree_caveat/disagree/single/error) and QC tier scoring
- Per-row override and en masse priority chain resolution with pinning protection
- Self-contained R/curation.R with Shiny orchestrator, dedup preview, and step-by-step progress tracking
- Review Results UI with consensus value boxes, color-coded table rows, resolution dropdowns, and full audit trail export

**UAT:** 12/12 tests passed

---


## v1.2 Curation Refinement (Shipped: 2026-03-03)

**Phases completed:** 3 phases, 6 plans, 7 tasks
**Lines of code:** 4,109 across 5 R files
**Requirements:** 12/12 satisfied (SRCH, RECV, UIPX)

**Key accomplishments:**
- Reordered search tiers (exact → CAS → starts-with) with 3-char minimum filter for improved precision
- "Other" tagged columns participate in full curation chain and consensus voting
- Column visibility tiers, color-coded badges, and enhanced resolution dropdowns with preferredName context
- Manual DTXSID entry with inline editing, queue system, and bulk CompTox validation
- Error row retry workflow: filter → select → re-tag → re-curate → merge-back with pin preservation
- Unresolvable status tracking and comprehensive Excel export with needs_review flagging

**UAT:** 10/10 tests passed

---

