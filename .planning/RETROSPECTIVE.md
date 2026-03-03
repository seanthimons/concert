# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.1 — Curation Process Update

**Shipped:** 2026-03-01
**Phases:** 3 | **Plans:** 6 | **Sessions:** ~4

### What Was Built
- TDD-built pipeline with 6 modular functions: dedup, tiered CompTox search (exact/starts-with/CAS), result mapping
- Consensus classification with 5 status labels (agree/agree_caveat/disagree/single/error) and QC tier scoring
- Per-row override and en masse priority chain resolution with pinning protection
- Self-contained R/curation.R orchestrator with Shiny progress tracking
- Review Results UI with value boxes, color-coded rows, resolution dropdowns, and 3-sheet Excel export

### What Worked
- TDD approach for Phases 3-4 (write failing tests → implement → pass) produced reliable, testable functions
- Prototype-first approach validated pipeline logic in isolation before Shiny wiring
- Migrating functions into R/curation.R (self-contained) eliminated fragile cross-file sourcing
- Phase 5 auto-advance executed both plans and verification cleanly
- UAT passed 12/12 on first attempt — no rework needed

### What Was Inefficient
- ROADMAP.md and REQUIREMENTS.md traceability tracking didn't update during Phases 3-4 execution (same issue as v1.0) — phase checkboxes and requirement status lagged behind actual completion
- Phase 5 executor generated ~600 lines in curation.R but the plan specified "copy verbatim" for 6 functions — migration could have been more mechanical
- Two separate sessions for Phases 3-4 vs Phase 5 due to context limits — could have been one with better context management

### Patterns Established
- `progress_callback` pattern for Shiny: `withProgress()` + `incProgress()` with a callback function passed to long-running pipeline
- DT `escape=FALSE` + JS `Shiny.setInputValue` for inline interactive controls in data tables
- Dynamic `observeEvent` generation inside `observe()` for variable-length UI controls
- `resolution_state` reactive pattern: resolution updates flow through a single reactive df, UI re-renders automatically

### Key Lessons
1. TDD for pipeline functions pays off — tests from Phase 3 continued to validate through Phase 5 integration
2. Self-contained modules (migrating functions in) are better than cross-file `source()` chains for Shiny apps
3. Traceability tracking (requirements, roadmap checkboxes) must be updated atomically with plan completion — not deferred
4. User feedback during UAT reveals UX needs (richer dropdown context, column visibility) that specs don't anticipate

### Cost Observations
- Model mix: sonnet for all execution and verification, opus for orchestration
- Sessions: ~4 (Phase 3+4 execution, Phase 5 planning, Phase 5 execution + UAT, milestone completion)
- Notable: Phase 5 execution completed 2 plans in ~7 minutes total (257s + 170s)

---

## Milestone: v1.0 — Curation UI Iteration

**Shipped:** 2026-02-27
**Phases:** 2 | **Plans:** 2 | **Sessions:** ~3

### What Was Built
- Split single Curation tab into 3 top-level tabs (Tag Columns, Run Curation, Review Results)
- Gated tab visibility with cascade reset and re-upload confirmation modal
- Full-width layouts replacing nested card containers
- CSS pulse animation on newly unlocked tabs

### What Worked
- Small, focused phases (1 plan each) kept execution clean
- Auto-advance pipeline (discuss → plan → execute) completed both phases efficiently
- Keeping business logic untouched (R/curation.R, R/data_detection.R) reduced risk

### What Was Inefficient
- `nav_panel_hidden()` was used by the auto-advance executor but doesn't support title args — required a manual bugfix after Phase 2 completed
- REQUIREMENTS.md traceability table wasn't updated during Phase 1 execution — all 11 Phase 1 requirements showed as "Pending" at milestone completion
- Phase 2 executor used `nav_panel_hidden` despite research showing it works differently — the research-to-implementation gap caused the tab title bug

### Patterns Established
- `nav_panel()` + `session$onFlushed()` hide is the correct pattern for gated tabs that need titles in bslib
- Cascade reset pattern: tag changes silently hide all downstream tabs; re-upload shows confirmation modal
- `show_tab_with_pulse()` helper for animated tab reveals

### Key Lessons
1. Always verify bslib function signatures (title vs value as first arg) — `nav_panel_hidden()` and `nav_panel()` have different APIs
2. Update traceability tables during plan execution, not just at milestone completion
3. Auto-advance pipelines need post-execution verification to catch API misuse bugs

### Cost Observations
- Model mix: primarily sonnet for execution, opus for discussion
- Sessions: ~3 (project setup, Phase 1+2 auto-advance, bugfix + milestone completion)
- Notable: Both phases completed in a single auto-advance chain

---

## Milestone: v1.2 — Curation Refinement

**Shipped:** 2026-03-03
**Phases:** 3 | **Plans:** 6 | **Sessions:** ~5

### What Was Built
- Reordered search tiers (exact → CAS → starts-with) with 3-char minimum for improved precision
- "Other" tagged columns participate in full curation chain and consensus voting
- Column visibility tiers, color-coded badges, and enhanced resolution dropdowns
- Manual DTXSID entry with inline editing, queue system, and bulk CompTox validation
- Error row retry workflow: filter → select → re-tag → re-curate → merge-back with pin preservation
- Unresolvable status tracking and Excel export with needs_review flagging

### What Worked
- Parallel plan execution within phases (08-01 backend, 08-02 frontend, 08-03 workflow) kept each plan focused
- UAT-driven bugfixing caught real issues (row duplication, modal binding, summary counts) before shipping
- recalc_consensus_summary() helper eliminated the 4-site summary drift bug permanently

### What Was Inefficient
- Row duplication bug persisted across 3 fix attempts because the root cause (Shiny auto-sourcing prototype_pipeline.R over curation.R) was architectural, not in the join logic being debugged
- Shiny actionButton in modals fails to re-register on reopen — required 5 iterations to discover this is a known Shiny limitation, ultimately solved with JS-triggered buttons reading DOM values
- Summary count calculations were duplicated in 4 places with inconsistent fields — should have been a helper from the start

### Patterns Established
- `recalc_consensus_summary()` single source of truth for all status counts
- JS `Shiny.setInputValue` with DOM value collection for reliable modal buttons
- Vector indexing over dplyr joins when row count must be preserved
- `R/archive/` directory for historical reference files that shouldn't be auto-sourced

### Key Lessons
1. When a fix doesn't work, check if something is overwriting your code — Shiny auto-sources `R/*.R` alphabetically, so a prototype file can silently shadow production functions
2. Shiny modal inputs have known binding issues — use JS-side DOM reading for reliability
3. Extract shared calculations into helpers immediately rather than copy-pasting with drift risk
4. Test data must follow the same format standards as real data (CSV quoting for commas)

### Cost Observations
- Model mix: opus for orchestration/UAT, sonnet for plan execution
- Sessions: ~5 (planning, Phase 6+7 execution, Phase 8 execution, UAT rounds, milestone completion)
- Notable: UAT Phase 8 required extended debugging (row duplication + modal buttons) across 2 sessions

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Sessions | Phases | Key Change |
|-----------|----------|--------|------------|
| v1.0 | ~3 | 2 | Established GSD workflow, learned bslib API |
| v1.1 | ~4 | 3 | Added TDD, prototype-first approach, UAT verification |
| v1.2 | ~5 | 3 | UAT-driven bugfixing, JS modal workarounds, helper extraction |

### Top Lessons (Verified Across Milestones)

1. **Traceability must update atomically** — v1.0 and v1.1 had tracking lag. v1.2 improved but roadmap checkboxes still lagged.
2. **Verify framework APIs before implementing** — v1.0 nav_panel_hidden bug, v1.2 Shiny modal actionButton limitation. Research → verify → implement.
3. **UAT reveals needs that specs miss** — All three milestones found issues during UAT that weren't in specs.
4. **Check for shadowing before debugging logic** — v1.2 row duplication: 3 fix attempts on join logic when the real cause was file auto-sourcing order.
