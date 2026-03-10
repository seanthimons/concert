# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.4 — Cleaning Pipeline Fixes

**Shipped:** 2026-03-10
**Phases:** 1 | **Plans:** 2 | **Sessions:** 1

### What Was Built
- Fixed bare formula detection false positives using consecutive-lowercase and abbreviation heuristics
- Fixed stop word substring matching with word boundary wrapping (`\b`)
- Protected letter-comma-letter IUPAC patterns (N,N- O,O- S,S-) from synonym splitting
- Created 42-assertion end-to-end validation test suite confirming all three fixes through full pipeline

### What Worked
- Single-phase milestone with clear scope — all 7 requirements targeted the same file, completed in one session
- Wave-based execution (fixes first, validation second) ensured tests could exercise the actual fixes
- Heuristic approach (consecutive lowercase) was simpler and more maintainable than trying to perfect the regex
- Reusing existing @@@ placeholder pattern for letter-comma-letter kept the codebase consistent
- All 241 tests passed with zero regressions — existing test suite provided confidence

### What Was Inefficient
- Nothing notable — this was a clean, focused bug fix milestone with no rework

### Patterns Established
- Heuristic pre-checks before regex validation (filter obvious non-matches before expensive checks)
- Word boundary wrapping for substring matching safety
- Extending placeholder protection patterns to new character classes (letters, not just digits)

### Key Lessons
1. **Small, focused milestones execute cleanly** — 1 phase, 2 plans, 7 requirements, done in one session. No scope creep, no rework.
2. **Heuristics beat perfection** — Instead of perfecting a regex to distinguish formulas from names, adding pre-checks that filter obvious non-formulas was simpler and more maintainable.
3. **Existing test suites are safety nets** — 199 existing tests catching regressions meant each fix could be verified immediately.

### Cost Observations
- Model mix: sonnet for execution/verification, opus for orchestration
- Sessions: 1 (execute + UAT + audit + complete in single session)
- Notable: Total execution time ~24 minutes for both plans (913s + 551s). Fastest milestone to date.

---

## Milestone: v1.3 — Data Cleaning Pipeline

**Shipped:** 2026-03-10
**Phases:** 7 | **Plans:** 15 | **Sessions:** ~8

### What Was Built
- Extracted 7 Shiny modules from monolithic app.R (2,276 → 203 lines)
- 12-step cleaning pipeline: unicode, whitespace/punctuation, CAS normalization, CAS rescue, multi-CAS detection, parenthetical stripping, quality adjective removal, salt reference removal, unspecified suffix removal, two-pass enclosure stripping, synonym splitting, empty row cleanup
- IUPAC-aware synonym splitting with placeholder-based comma protection
- Provenance-tracked reference lists (ComptoxR-seeded + user-editable) with blocking/warning flag taxonomy
- 7-sheet Excel export with re-import detection and selective config restore
- Post-curation QC with ComptoxR's 157 chemistry-specific unicode mappings
- Value box dashboard, step-by-step progress, and audit trail accordion

### What Worked
- Modularization-first approach (Phase 9) prevented app.R from becoming unmaintainable — all subsequent phases built cleanly on module architecture
- INTERLEAVED phase structure (pipeline + UI per phase) kept each phase self-contained and testable
- TDD continued to pay off — 95 name cleaning tests, 65 CAS tests, 40 pipeline tests caught regressions early
- ComptoxR direct usage eliminated custom implementation overhead for CAS operations and unicode cleaning
- Two-pass enclosure stripping pattern (discovered during Phase 12 testing) elegantly handled edge cases
- Smoke test requirement (added after Phase 10 icon crash) caught startup issues before UAT

### What Was Inefficient
- ROADMAP checkboxes STILL lagged behind completion (Phase 9 and 12 unchecked at audit time) — 4th milestone with this issue
- Phase 12 verification never formally run — caught only by milestone audit
- bsicons icon name assumptions caused Phase 10 and Phase 15 crashes (`bs_icon("broom")` and `bs_icon("arrow-clockwise")` don't exist) — unit tests don't catch icon-level failures
- Plan 14-01 had to be merged inline with 14-02 as a deviation because the TDD structure didn't fit the export builder pattern
- SUMMARY frontmatter `requirements_completed` field only added to 3 of 15 summaries — inconsistent metadata

### Patterns Established
- Shiny module architecture: `mod_{name}_ui()` / `mod_{name}_server()` with NS namespacing
- `data_store` reactiveValues with single-writer pattern (upload module owns writes)
- Navigation callbacks as function parameters (`on_tags_applied`, `on_curation_complete`)
- Value box dashboard pattern for cleaning statistics
- `incProgress()` between inline pipeline steps for granular progress
- Placeholder-based protection (`@@@`, `%%%`) for IUPAC comma patterns in synonym splitting
- `icon()` wrapper instead of `bsicons::bs_icon()` for actionButton icons (Shiny's validateIcon check)
- Provenance tibble format `(term, source, active)` for reference list tracking
- Two-stage ChemReg export detection (sheet presence → marker validation)
- Smoke test as mandatory post-UI-change verification step

### Key Lessons
1. **Always smoke test after UI changes** — unit tests don't catch missing icons, broken module wiring, or source() failures. Phase 10 and 15 both crashed at startup despite all tests passing.
2. **Verify icon names exist in the specific library** — bsicons has a different icon set than fontawesome. Check before using.
3. **Run formal verification for every phase** — Phase 12 skipped verification and it became a milestone audit gap.
4. **Traceability automation is overdue** — 4 milestones of manual checkbox tracking with consistent lag. Consider automating checkbox updates at plan completion.
5. **Two-pass patterns emerge from testing** — the enclosure stripping two-pass pattern wasn't in the plan but emerged naturally from edge case testing. Let tests drive design.

### Cost Observations
- Model mix: sonnet for all plan execution, opus for orchestration/auditing
- Sessions: ~8 (modularization, foundation, CAS pipeline, name cleaning, reference filters, export, QC, milestone completion)
- Notable: 15 plans executed in ~113 minutes total (~7.5 min average per plan). Phase 12 P01 was slowest (1041s / 17 min) due to TDD with 95 tests.

---

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

| Milestone | Sessions | Phases | Plans | Key Change |
|-----------|----------|--------|-------|------------|
| v1.0 | ~3 | 2 | 2 | Established GSD workflow, learned bslib API |
| v1.1 | ~4 | 3 | 6 | Added TDD, prototype-first approach, UAT verification |
| v1.2 | ~5 | 3 | 6 | UAT-driven bugfixing, JS modal workarounds, helper extraction |
| v1.3 | ~8 | 7 | 15 | Modularization, smoke tests, 12-step pipeline, milestone auditing |
| v1.4 | 1 | 1 | 2 | Focused bug fix milestone, heuristic pre-checks, fastest completion |

### Top Lessons (Verified Across Milestones)

1. **Traceability must update atomically** — v1.0-v1.3 all had checkbox tracking lag. 4 milestones confirms this needs automation.
2. **Verify framework APIs before implementing** — v1.0 nav_panel_hidden, v1.2 modal actionButton, v1.3 bsicons icon names. Always check the actual API.
3. **UAT and smoke tests reveal what unit tests miss** — All milestones found issues during testing that specs didn't anticipate. v1.3 added mandatory smoke tests.
4. **Check for shadowing before debugging logic** — v1.2 auto-sourcing order, v1.3 icon library confusion. The problem is often environmental, not logical.
5. **Run verification for every phase** — v1.3 Phase 12 skipped verification; caught only by milestone audit. No exceptions.
6. **Small milestones execute fastest** — v1.4 completed in a single session with zero rework. Tight scope eliminates coordination overhead.
