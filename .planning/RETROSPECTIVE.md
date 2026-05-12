# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v2.2 — WQX Pipeline Refinement

**Shipped:** 2026-05-08
**Phases:** 2 | **Plans:** 7

### What Was Built
- Pipeline reorder: WQX dictionary matching fires as Tier 3 before CompTox starts-with, with starts-with gated behind opt-in toggle (default OFF)
- Configurable WQX fuzzy threshold (0.50–1.00) via pre-flight slider with synced numeric input, threaded through Shiny and headless paths
- WQX confidence column (Jaro-Winkler similarity) surfaced in Review Results as "WQX Conf." with dedup for multi-tag datasets
- WQX Review modal with selectize type-ahead over 124K-entry dictionary, override/reject actions with dedup group propagation
- Override/reject persistence through export via `wqx_override_name` on `resolution_state`

### What Worked
- TDD RED-GREEN cycle in Plan 01 caught issues early — vectorized review_btn approach (pre-compute, mask-subset) was clean
- Gap closure wave pattern (Plans 03-05) continued to be effective: Plan 03 fixed a silent column drop, Plan 04 fixed 4 code review findings, Plan 05 fixed 2 UAT issues
- `session$onFlushed(once=TRUE)` for deferring selectize init solved the 124K-row modal loading timing issue cleanly
- grep-based column lookup (`grep('^wqx_confidence', names(x))`) handled both single-tag and multi-tag suffixed column names without mode detection
- Content guard pattern (`if ("col" %in% names(df))`) for backward compatibility with non-WQX-enabled curation runs

### What Was Inefficient
- REQUIREMENTS.md traceability table never updated during execution — all 10 requirements still "Pending" at milestone close despite all being implemented. This is the 6th+ milestone with this issue.
- Plan 01 had to add `wqx_confidence` to the pipeline but Plan 03 discovered it was silently dropped by `map_results_to_rows()` — the pre-allocation vector pattern is easy to miss when adding new columns
- `row$searchValue` reference in the modal observer (Plan 04, CR-01 BLOCKER) crashed the modal on first click — the column never existed on `resolution_state`. Code review should have caught this before execution.
- gsd-tools summary-extract couldn't extract one-liners from SUMMARY files — same issue as v2.0

### Patterns Established
- **Filter() for all-NA column dedup**: `Filter(function(col) any(!is.na(...)))` removes duplicate colDefs in multi-tag mode while preserving data
- **onFlushed selectize init**: `session$onFlushed(once=TRUE)` wrapping `updateSelectizeInput(server=TRUE)` for large-dictionary modals
- **grep-based column family lookup**: `grep('^prefix_', names(df), value=TRUE)` for suffix-agnostic column matching across single/multi-tag modes
- **Pre-allocation checklist**: When adding a new column to curation results, must update all pre-allocation vectors in `map_results_to_rows()`

### Key Lessons
1. **Pre-allocation vectors are a maintenance trap** — `map_results_to_rows()` has N pre-allocated vectors that must all be extended when adding a new output column. Plan 01 added `wqx_confidence` to `wqx_rows` but forgot the mapping function. Add a checklist comment listing all vectors.
2. **Test modal observers with real data** — `row$searchValue` was never on `resolution_state`; a single manual test would have caught this before Plan 04 gap closure.
3. **Gap closure plans remain healthy** — 3 gap closure plans (03-05) out of 5 total for Phase 48. This ratio is consistent with v2.0. Budget for it.
4. **Selectize + large datasets need deferred init** — `showModal()` + immediate `updateSelectizeInput(server=TRUE)` races the DOM. Always defer via `onFlushed`.

### Cost Observations
- Sessions: Multiple across 3 days (2026-05-06 → 2026-05-08)
- Notable: Phase 47 was fast (2 plans, ~1 hour). Phase 48 required 5 plans with 3 gap closure waves. 78 files changed, +7,896 / -6,522 lines.

---

## Milestone: v2.1 — WQX Parameter Harmonization

**Shipped:** 2026-05-06
**Phases:** 4 | **Plans:** 7

### What Was Built
- WQX dictionary loader with EPA Characteristic + Alias CSV download and combined 124K-row RDS cache
- Three-tier WQX name matcher: exact canonical, alias crosswalk, Jaro-Winkler fuzzy with configurable threshold
- Pipeline integration: WQX fires automatically as Tier 3b after CompTox for unresolved names
- Consensus classification with "wqx" status, teal badges, and tier-specific match type labels
- Dedup priority fix: resolved rows preferred over NA-dtxsid exact misses

### What Worked
- Following the established harmonization pattern (core function → pipeline wiring → UI integration) kept execution clean
- WQX dictionary as combined canonical+alias RDS (single file for both tier-1 and tier-2 lookups) follows existing reference cache pattern
- Jaro-Winkler over Levenshtein was the right choice for chemical name fuzzy matching (prefix/suffix variations)
- Dedup priority bug (CompTox NA results shadowing WQX resolution) caught during UAT with real dataset

### What Was Inefficient
- Stale test fixes from Phases 37-41 deferred again — tracked as bean but not addressed
- REQUIREMENTS.md traceability not updated during execution

### Patterns Established
- WQX dictionary as single combined RDS serving both exact and alias lookups
- Teal color family for WQX UI elements (distinct from CompTox green but still "resolved" palette)
- Unconditional tier firing for fallback matchers (no toggle needed when only reached on failure)

### Key Lessons
1. **Dedup logic must prefer resolved rows** — when the same input name appears in both CompTox (NA result) and WQX (resolved) batches, the resolved row must win
2. **Wild dataset UAT is essential** — sswqs.xlsx revealed the dedup shadowing bug that synthetic test data missed

### Cost Observations
- Sessions: Multiple across 8 days (2026-04-29 → 2026-05-06)
- Notable: 4 phases, 7 plans. +1,303 / -39 across 14 files.

---

## Milestone: v2.0 — Pipeline Performance & Date/Media Harmonization

**Shipped:** 2026-04-29
**Phases:** 6 | **Plans:** 20

### What Was Built
- Distinct-string dedup architecture (`dedup_step()` + `remap_audit_to_parent()`) with two-pass cleaning pipeline migration and unit-key dedup in harmonizer
- Short-circuit pre-checks for all cleaning/harmonization steps with false-negative companion tests and `build_skip_result()` helper
- Benchmark harness (`scripts/benchmark_pipeline.R`) with `bench::press()` grid, `use_dedup` toggle for before/after comparison
- Duration conversion engine with hours base unit, 23 conversion + 34 synonym entries, "m" ambiguity flagging, ToxVal `study_duration_value`/`study_duration_units` wiring
- Multi-format date parser (`parse_dates()`) handling ISO/MDY/DMY/SAS/YYYYMMDD/year-only/2-digit-year with day≤12 ambiguity detection
- ENVO-based media harmonizer with AMOS build-time pipeline (26 curated + 7 AMOS-derived terms), compound media resolution, and ppb/ppm routing loop closure
- Unified "Run Pipeline" button with pre-flight modal (fire/skip per step), media classification editor with unmatched term surfacing, pre-flight progress indicator, and post-pipeline completion summary

### What Worked
- Dedup-as-orchestrator-wrapper pattern kept step functions pure and testable — zero changes needed to individual step function signatures
- Two-pass dedup architecture (Pass 1: name chain steps 6-pre through 6d3, Pass 2: steps 7-9) correctly handled data dependencies without over-deduplicating
- Custom duration synonym map instead of `lubridate::duration()` avoided the "m" = months pitfall — the explicit ambiguity flagging is the right approach for regulatory data
- Pre-synonym molarity classification cleanly separated M (Molar) from m (minutes) without upstream changes
- Gap closure plans (41-04, 42-04, 42-05) were effective at catching UAT-discovered issues — the UAT → gap plan → fix → re-verify cycle worked well
- DT `selection=none` was the simplest fix for the row-click conflict in the media editor — no JS workaround needed
- 4-element `classify_tags()` return (chemical, numeric, metadata, study_type) extended cleanly without breaking existing callers

### What Was Inefficient
- REQUIREMENTS.md traceability table never updated during execution — all 32 non-BENCH requirements still showed "Pending" at milestone close despite all phases completing. This is the 5th+ milestone with this issue.
- Phase 37 checkbox in ROADMAP.md was never checked despite all 4 plans completing
- No formal milestone audit was run — accepted as known gap
- The gsd-tools summary-extract CLI couldn't reliably extract one-liners from SUMMARY.md files — had to fall back to manual reading

### Patterns Established
- **Dedup orchestrator wrapper**: `dedup_step(fn, df, col, ...)` wraps any step function; step functions stay pure `list(cleaned_data, audit_trail)` returners
- **Pre-check predicate convention**: `precheck_<step_name>(values)` returns TRUE if step should fire, FALSE to skip; paired with `build_skip_result()` for typed empty audit
- **Category parameter for harmonize_units()**: `category = "concentration"|"duration"` selects which subset of the unit table to use
- **Build-time ontology extraction**: AMOS/ENVO data extracted at build time, committed as RDS, never called at runtime
- **Three-tier media cascade**: user_map → amos_map → envo_base in `harmonize_media()`
- **Unified pipeline button**: single entry point with pre-flight modal replaces separate Clean/Harmonize buttons

### Key Lessons
1. **Traceability automation is now critical** — 5+ milestones with requirements tracking lag. Manual checkbox updates simply do not happen during execution. This needs to be automated or eliminated.
2. **Gap closure plans are a healthy pattern** — Phases 41 and 42 each needed gap closure sub-plans after UAT revealed issues. Planning for 1-2 gap closure rounds is realistic.
3. **Duration/date/media all followed the same integration pattern** — core function → tag system extension → pipeline wiring → ToxVal mapping. This 4-step pattern should be templated for future harmonization types.
4. **Pre-flight modals improve user confidence** — showing fire/skip indicators before running gives users control and transparency. Apply this pattern to other long-running operations.
5. **Build-time data extraction is the right boundary** — AMOS methods require API calls and ontology extraction. Doing this at build time and committing the result keeps the runtime fast and reproducible.

### Cost Observations
- Sessions: Multiple across 5 days (2026-04-24 → 2026-04-28)
- Notable: 156 commits, 6 phases, 20 plans. Largest milestone by plan count and code change volume (+6,209 / -756 lines across 32 files).

---

## Milestone: v1.7 — UI Polish & Isotope Cleaning

**Shipped:** 2026-04-13
**Phases:** 2 | **Plans:** 3 | **Sessions:** 2 (execution + post-audit tech debt fix)

### What Was Built
- Review Results column headers now wrap to full text (`wrap=TRUE` in reactable call)
- `renderWidget` console warning eliminated by removing redundant `elementId`; `unname(unlist())` pattern silences jsonlite 2.0.0 named vector deprecation
- Isotope shortcode expansion in cleaning pipeline — `u234` → `Uranium-234` using ComptoxR isotope list with greedy element matching (Pb before P)
- Chiral designation protection via content-encoded placeholders (`###CHIRAL_PLUS###`, `###CHIRAL_R###`) that survive synonym splitting and restore cleanly before curation
- Multi-analyte expression flagging (naked `+`/`and` between analytes) as WARNING without auto-splitting

### What Worked
- Milestone audit (gsd:audit-milestone) caught the missing chiral restore path before archiving — the fix was applied in the same session, preventing chiral compounds from failing ComptoxR lookup
- Content-encoded placeholder scheme (`###CHIRAL_PLUS###` vs `###CHIRAL_1###`) was the right design — stateless restore requires no row-index tracking, survives synonym split row reordering
- Source-code assertion tests (readLines + grep) are valid and sufficient for Shiny parameter choices that require a live session to test at runtime — avoids blocking on integration setup
- Phase 23 executed cleanly with zero deviations from plan — tight scope and clear implementation spec enabled this

### What Was Inefficient
- The audit identified a missing restore path that should have been caught during Phase 23 execution — "protect" without "restore" is an incomplete pattern. Checklist during implementation should include "does this placeholder need a restore call downstream?"
- Nyquist VALIDATION.md files were not created for either phase — missed validation coverage

### Patterns Established
- **Protect/restore bracket pattern**: Any placeholder substitution (`###X###`) must be paired with a restore call downstream. The protect function should document the expected restore location.
- **Content-encoded placeholders over sequential numbers**: `###CHIRAL_PLUS###` is self-describing and enables stateless restore; `###CHIRAL_1###` requires external state that gets lost across pipeline steps
- **Source-code assertion tests**: `readLines() + grep()` valid for testing parameter choices in Shiny modules that can't be tested without full reactive session

### Key Lessons
1. **Every protect call needs a documented restore** — When writing `protect_X()`, immediately write or stub `restore_X()` and add a comment noting where the restore must be called. The audit catching this is a safety net, not the plan.
2. **Milestone audit is worth running before archiving** — It caught a real data quality bug (chiral compounds failing curation) that all unit tests missed. Budget time for it.
3. **Small UI milestones execute fast but accumulate audit findings** — Phase 22 was ~25min to execute but 3 deferred verification items noted. Small scope ≠ no tech debt.

### Cost Observations
- Model mix: sonnet for execution, opus for orchestration and audit
- Sessions: 2 (main execution + post-audit tech debt fix)
- Notable: Core execution fast (Phase 22: 25min, Phase 23: 40min total). Tech debt fix after audit was 15min.

---

## Milestone: v1.6 — Cleaning Ruleset Fixes

**Shipped:** 2026-03-20
**Phases:** 3 | **Plans:** 3 | **Sessions:** 1

### What Was Built
- Multi-locant IUPAC comma protection via repeat-until-stable loop in `split_synonyms()` — fixes 2,4,6-trichlorophenol and longer chains
- Roman numeral oxidation state protection (`ROMAN_NUMERAL_PATTERN` constant + `has_roman` gating) in both paren and bracket enclosure stripping paths
- Unicode cleaning test alignment — all dot-notation assertions corrected to plain text format matching current ComptoxR output, prime symbol test coverage added

### What Worked
- Auto-advance chain (discuss → plan → execute) completed all 3 phases in a single session with zero user intervention
- CONTEXT.md from discuss-phase provided precise line numbers and code references — executor agents had zero ambiguity
- Verifier caught a missed file (`test_unicode_comptoxr.R`) that the executor overlooked — the verification gate saved a gap
- All phases were small, focused fixes (1-2 tasks each) — tight scope eliminated coordination overhead

### What Was Inefficient
- Phase 21 executor missed `tests/test_unicode_comptoxr.R` (a second file with the same stale assertions) — required an inline fix after verification flagged it
- Multiple background test-run tasks accumulated and had to be killed — executor spawned too many parallel test processes

### Patterns Established
- Repeat-until-stable loop for regex protection: iterate until no more replacements, cap at 10 iterations
- Module-level regex constants (e.g., `ROMAN_NUMERAL_PATTERN`) for patterns used across multiple code paths
- Content-based gating in `should_strip` expressions: extensible pattern — add new checks like `has_roman` alongside existing `has_yl`, `has_percentage`

### Key Lessons
1. **Verify ALL test files, not just the obvious ones** — Phase 21 executor fixed `test_cleaning_pipeline.R` but missed `test_unicode_comptoxr.R` which had identical stale assertions. Grep for the pattern across the entire test directory.
2. **Auto-advance works well for small, well-scoped milestones** — 3 phases, 3 plans, zero user intervention. The pipeline (discuss → plan → execute → verify) ran cleanly end-to-end.
3. **Live R session verification in CONTEXT.md is high-value** — Running `ComptoxR::clean_unicode("α")` during discuss-phase and recording the actual output eliminated guesswork for downstream agents.

### Cost Observations
- Model mix: opus for orchestration/planning, sonnet for execution/verification
- Sessions: 1 (all 3 phases auto-advanced in a single chain)
- Notable: Entire milestone completed in ~2 hours wall time including discuss, plan, execute, and verify for all 3 phases

---

## Milestone: v1.5 — Disagreement Enrichment

**Shipped:** 2026-03-13
**Phases:** 2 | **Plans:** 2 | **Sessions:** 1

### What Was Built
- CompTox enrichment pipeline with CASRN, molecular formula, molecular weight via `ct_chemical_detail` with incremental caching
- Source column attribution and search tier labels per candidate
- Rich comparison modal with candidate cards showing enriched metadata, replacing dropdown
- Two-step resolution (Select + Confirm) with Skip and Change options
- Consensus enrichment columns in Excel export

### What Worked
- Tight scope (2 phases, 2 plans) kept execution clean and fast — completed in a single session
- Phase 17 enrichment pipeline provided clean data contract for Phase 18 modal UI
- Incremental caching pattern (pass existing_cache to skip already-fetched DTXSIDs) avoided redundant API calls
- Two-step resolution (Select + Confirm) was the right UX decision — prevents accidental clicks while keeping flow fast
- Resolved both v1.2 tech debt items (dropdown context, column visibility) organically via the modal UI

### What Was Inefficient
- Nothing notable — cleanest milestone execution alongside v1.4. Two focused phases with clear contracts.

### Patterns Established
- Incremental caching: pass `existing_cache` tibble to enrichment function, skip already-fetched DTXSIDs
- Card-based modal for complex selection: better than dropdown for multi-attribute comparison
- Two-step confirm pattern (Select highlights, Confirm commits) for destructive/important actions
- Enrichment cache as single reactive source of truth consumed across modules

### Key Lessons
1. **Modal UI beats dropdowns for multi-attribute decisions** — enrichment metadata (5+ fields per candidate) can't fit in a dropdown label. Modal cards with full metadata are the right pattern.
2. **Clean data contracts between phases pay off** — Phase 17's `enrich_candidates()` returning a structured tibble made Phase 18 trivial to implement.
3. **Tech debt resolves itself with the right feature** — v1.2's "richer dropdown context" and "column visibility" concerns both dissolved when the comparison modal was built.

### Cost Observations
- Model mix: sonnet for execution, opus for orchestration
- Sessions: 1 (both phases executed + milestone completion)
- Notable: Total execution time ~44 minutes for both plans (31min + 13min). Second fastest milestone after v1.4.

---

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
- Two-stage CONCERT export detection (sheet presence → marker validation)
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
| v1.5 | 1 | 2 | 2 | Enrichment + modal UI, tech debt resolved organically, clean data contracts |
| v1.6 | 1 | 3 | 3 | Full auto-advance chain, verifier catching missed files, repeat-until-stable pattern |
| v1.7 | 2 | 2 | 3 | Milestone audit catches missing restore path, content-encoded placeholders, source-code assertion tests |
| v1.8 | — | 5 | 5 | R package migration, run_app() launcher, curate_headless(), 953 tests |
| v1.9 | — | 9 | 20 | Unit harmonization, ToxVal schema, extended tagging, harmonize tab, parquet export |
| v2.0 | — | 6 | 20 | Dedup architecture, pre-checks, duration/date/media harmonization, pre-flight modal |
| v2.1 | — | 4 | 7 | WQX dictionary matching, 3-tier fuzzy, dedup priority fix, teal UI family |
| v2.2 | — | 2 | 7 | Pipeline reorder, threshold slider, WQX Review modal, selectize onFlushed pattern |

### Top Lessons (Verified Across Milestones)

1. **Traceability must update atomically** — v1.0-v2.2 all had checkbox tracking lag. 6+ milestones confirms this needs automation or elimination.
2. **Verify framework APIs before implementing** — v1.0 nav_panel_hidden, v1.2 modal actionButton, v1.3 bsicons icon names. Always check the actual API.
3. **UAT and smoke tests reveal what unit tests miss** — All milestones found issues during testing that specs didn't anticipate. v1.3 added mandatory smoke tests.
4. **Check for shadowing before debugging logic** — v1.2 auto-sourcing order, v1.3 icon library confusion. The problem is often environmental, not logical.
5. **Run verification for every phase** — v1.3 Phase 12 skipped verification; caught only by milestone audit. No exceptions.
6. **Small milestones execute fastest** — v1.4 and v1.6 both completed in single sessions with zero rework. Tight scope eliminates coordination overhead.
7. **Grep the full test directory for patterns being fixed** — v1.6 Phase 21 missed a second test file with identical stale assertions. Always search broadly.
8. **Gap closure plans are healthy, not rework** — v2.0 Phases 41 and 42 each needed gap closure sub-plans after UAT. Plan for 1-2 rounds.
9. **Harmonization features follow a repeatable pattern** — core function → tag system → pipeline wiring → ToxVal mapping. Template this for future types.
10. **Build-time data extraction is the right boundary for ontology data** — AMOS methods at build time, committed RDS at runtime. Fast and reproducible.
