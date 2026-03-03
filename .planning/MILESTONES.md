# Milestones

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

