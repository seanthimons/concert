# Project Research Summary

**Project:** ChemReg v1.3 Data Cleaning Pipeline
**Domain:** R/Shiny chemical inventory data cleaning and curation
**Researched:** 2026-03-04
**Confidence:** HIGH

## Executive Summary

ChemReg v1.3 adds pre/post-curation data cleaning to the existing upload → detect → tag → curate workflow. Research confirms this is **low-risk, high-value enhancement** requiring only 2 new dependencies (openxlsx2 for multi-sheet Excel export, rhandsontable for editable reference lists). The 21-step cleaning pipeline follows established data transformation patterns (OpenRefine, Trifacta) with transparent audit trails and before/after comparison. Chemical-specific cleaning (CAS rescue, functional use flagging, IUPAC name handling) has no commercial analogs — this is greenfield opportunity built on the solid ComptoxR foundation already in use.

The recommended approach is **inline implementation first, modularize later**. The current app.R is 2,275 lines with a working reactiveValues() state pattern. Adding the "Clean Data" tab inline (Phase 1-4) is faster and lower-risk than refactoring to modules upfront. Extract modules in v1.4+ once the pipeline is proven stable. Critical architectural decision: cleaning must precede tagging in the workflow cascade, requiring explicit reset logic when reference lists change or files are re-uploaded.

Key risks center on **synonym splitting breaking IUPAC names** (commas in inverted forms like "butane, 2,2-dimethyl" vs. synonym separators), **reactive cascade explosion** from editable reference lists (UI freezing on every edit), and **Excel export failures** from audit trail columns exceeding cell/column limits. All three are mitigated with explicit protection rules (Phase 3), debounced edits with "Apply Changes" buttons (Phase 4), and separate audit trail sheets (Phase 1). The pitfalls research provides detailed detection and recovery strategies for each risk.

## Key Findings

### Recommended Stack

ChemReg's existing stack already provides 90% of needed capabilities. Only 2 packages need to be added:

**Core technologies:**
- **openxlsx2** (NEW): Multi-sheet Excel export with metadata — only package supporting arbitrary metadata sheets (audit trails, reference lists, manifest) and workbook properties for re-import detection. Replaces writexl for export only.
- **rhandsontable** (NEW): Editable reference lists with Excel-like UX — supports add/remove rows, dropdown validation, inline editing. DT with editable=TRUE only supports cell replacement, not row operations.
- **stringi** (existing via tidyverse): Unicode detection with `stri_enc_isascii()` — already available through stringr dependency.
- **withProgress()** (existing Shiny built-in): Pipeline progress tracking — already used in tiered curation, same pattern works for 21-step cleaning.
- **readxl** (existing): Multi-sheet Excel import and re-import detection via `excel_sheets()` — keep for all import needs.

**Architecture notes:** Use openxlsx2 for export, readxl for import. They complement each other. Use DT for display tables (fast, 10x faster than rhandsontable on large data), rhandsontable for editing small reference lists (10-50 rows). ComptoxR remains the core dependency for chemical cleaning (CAS validation, Unicode cleaning, formula extraction).

**Package to remove:** writexl (replaced by openxlsx2 for export)

### Expected Features

**Must have (table stakes):**
- Tabular data preview (before/after comparison) — users validate by seeing transformation impact
- Undo/redo or re-run capability — OpenRefine standard, users expect reversibility
- Visual flag distinction — red/blocking vs. yellow/warning vs. blue/info (universal UX pattern)
- Summary statistics cards — "X CAS rescued", "Y formulas detected", "Z flagged for review"
- Exportable results with audit trail — transparency and reproducibility baseline

**Should have (differentiators):**
- **Per-row audit trail** — "What changed and why?" for every transformation, displayed via DT child rows
- **Editable reference lists** — curators tune stop words/block lists without developer intervention
- **Blocking vs annotating flags** — blocking flags (formulas, empty names) stop curation; annotating flags (mixtures, functional categories) warn but proceed
- **Multi-sheet Excel export** — data + audit trail + reference lists + config + data dictionary in one file
- **Re-import detection** — recognize ChemReg exports, hot-load embedded reference lists and pipeline config
- **CAS-RN rescue pipeline** — extract CAS from name columns, validate checksums, split multi-CAS cells (no generic tool does this)
- **Functional use flagging** — detect "Fragrance", "Flavor", "Surfactant" as non-chemical categories
- **Post-curation QC** — re-validate CAS after API resolution, enrich with functional use + safety flags

**Defer (anti-features):**
- Fully manual cell-by-cell editing — doesn't scale; use batch operations + flag exceptions
- Drag-and-drop pipeline builder — high complexity, low ROI; fixed pipeline with enable/disable toggles is sufficient
- Real-time cleaning as-you-type — confusing; preview cleaned data, apply on button click
- AI/ML-powered "smart" cleaning — opaque audit trail, chemical names too domain-specific

### Architecture Approach

ChemReg follows the **reactive state management pattern** with explicit cascade resets. Current flow: Upload → detect → preview → tag → curate → review. New flow inserts cleaning between preview and tag: Upload → detect → preview → **clean** → tag → curate → **post-curation QC** → review. Critical change: curation now operates on `cleaned_data` not `clean`, requiring explicit wiring in the "Run Curation" observer.

**Major components:**
1. **R/pre_curation.R** — 21 cleaning functions + pipeline orchestrator with `withProgress()` tracking
2. **R/post_curation.R** — QC functions (CAS re-validation, Unicode check, functional use enrichment)
3. **R/cleaning_reference.R** — 4 functions returning character vectors (stop words, block list, functional categories, food names)
4. **Clean Data tab (inline in app.R)** — summary cards, reference list editors (rhandsontable), before/after preview (DT), re-run cleaning button
5. **Extended data_store reactiveValues** — add cleaned_data, cleaning_audit, cleaning_stats, reference_lists

**State management pattern:** Explicit `data_store$field <- NULL` assignments on state changes, not reactive dependency chains. This prevents partial state inconsistencies. New cascade rule: editing reference lists + re-running cleaning invalidates tags, curation, consensus, and resolution (all downstream state).

**Modularization strategy:** Inline implementation first (Phase 1-4), extract to modules later (v1.4+). Building inline is lower risk, faster to ship, and easier to debug during initial development. Once stable, extract using the "stratégie du petit r" pattern (incremental refactoring with tests).

### Critical Pitfalls

1. **Synonym splitting breaking IUPAC names** — Comma-based splitting (`"xylene, dimethylbenzene"`) falsely splits inverted IUPAC names (`"butane, 2,2-dimethyl"`) where commas are syntactically significant. **Mitigation:** Protect digit-comma-digit patterns, parenthetical content, detect inverted form via `^[A-Z][a-z]+,\s+\d` regex. Log all splits. Write 20+ test cases covering edge cases before deployment (Phase 3).

2. **Reactive cascade explosion from editable reference lists** — Single stop-word edit triggers full 21-step pipeline re-run, tag invalidation, curation invalidation, causing 5-10 seconds of UI freeze. **Mitigation:** Add explicit "Apply Changes" button (don't auto-rerun on keystroke), debounce edits with `debounce(reactiveVal, millis=2000)`, use `isolate()` on display outputs. Show diff preview before re-running (Phase 4).

3. **App.R crossing 3,000 lines without modularization** — File already at 2,275 lines will grow to 3,000+ with cleaning tab, becoming unmaintainable (10+ minute LLM context load, difficult dependency tracing, high merge conflicts). **Mitigation:** Extract existing 6 tabs into modules BEFORE adding Phase 1 (8-12 hour refactoring). Target app.R <500 lines (orchestration only). Each module gets own state, communicates via return values.

4. **Progress tracking lies in multi-step pipeline** — 21 steps with equal weight (5% each) but step 17 (`split_multi_cas()`) takes 40% of runtime; progress sits at 80% for 30 seconds. **Mitigation:** Measure empirical step weights via benchmarking 1,000-row test dataset, use weighted `incProgress(amount=step_weight)`. Show absolute time estimates. Separate fast vs. slow steps (Phase 1).

5. **Audit trail columns causing Excel export failure** — Pipe-separated comment strings grow to 500-1,000+ characters, exceeding Excel's 32,767 character cell limit. Wide dataframes (50+ columns) hit 16,384 column limit. **Mitigation:** Truncate displayed comments to 500 chars, store full trail in separate "Audit_Trail" sheet. Validate limits before export with `validate_excel_limits()` helper. Show warning if dataset too large for Excel format (Phase 1 + Phase 6).

6. **Re-import detection overwriting user edits** — App detects ChemReg export, auto-restores embedded reference lists and tags, silently overwriting any in-session modifications. **Mitigation:** Detect state divergence, show modal: "Restore embedded settings or keep current settings?" with side-by-side diff. Track modification timestamps. Never auto-restore without confirmation (Phase 1).

7. **Flag behavior confusion (blocking vs. annotating)** — All flags displayed identically despite different behaviors; blocking flags stop curation, annotating flags warn but proceed. Users overwhelmed by 40% of rows flagged with 5+ types. **Mitigation:** Implement 3-tier visual taxonomy (red/blocking, yellow/warning, blue/info). Default view shows only blocking flags, collapsible sections for warnings. Add tooltip explanations and override mechanism (v1.3 Design Phase + Phase 4).

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 0: Refactor Before Building (CRITICAL)
**Rationale:** App.R already at 2,275 lines. Adding 800+ lines of cleaning UI without modularization creates technical debt that compounds over time (Pitfall #3). Extract existing tabs into modules now before adding new features.

**Delivers:**
- 6 modules: `mod_data_preview`, `mod_detection_info`, `mod_raw_data`, `mod_tag_columns`, `mod_run_curation`, `mod_review_results`
- R/ directory with proper structure (`R/modules/`, existing helpers stay in `R/`)
- app.R reduced to <500 lines (orchestration only)
- Tests proving all existing functionality still works

**Time estimate:** 8-12 hours
**Risk mitigation:** Prevents "unmaintainable monolith" pattern before adding complexity

---

### Phase 1: Foundation (Audit Trail + Reference Data)
**Rationale:** All cleaning features depend on audit trail infrastructure (`append_comment()`). Reference data (stop words, block lists, functional categories, food names) must be defined before they can be used in filters. Progress tracking infrastructure sets pattern for all later phases.

**Delivers:**
- `R/cleaning_reference.R` — 4 functions returning reference character vectors
- `R/pre_curation.R` foundation — `append_comment()`, `canonicalize_strings()`, progress weight helpers
- Extended `data_store` with cleaned_data, cleaning_audit, cleaning_stats, reference_lists
- Separate "Audit_Trail" sheet architecture for export (prevents Excel cell limit issues)

**Addresses:**
- Pitfall #5 (audit trail Excel limits) via separate sheet design
- Pitfall #4 (progress tracking) via benchmarking infrastructure
- Pitfall #6 (re-import state) via state management design

**Stack:** No new dependencies (foundation only)
**Time estimate:** 2-3 days

---

### Phase 2: CAS-RN Pipeline
**Rationale:** CAS cleaning is highest-value, lowest-risk starting point. Research shows 14.4% + 2.4% of rows benefit from CAS rescue and normalization. ComptoxR already provides all needed functions. CAS cleaning is independent of name cleaning, can be tested in isolation.

**Delivers:**
- 4 CAS cleaning functions: normalize, rescue, validate, split multi-CAS
- Integration with audit trail (comment logging)
- Summary stats: "X CAS rescued from names", "Y CAS validated", "Z multi-CAS split"

**Addresses:**
- Features: CAS rescue pipeline (differentiator)
- Pitfall #1 preparation (synonym splitting protection patterns — tested here with CAS splitting before name synonym splitting)

**Uses:** ComptoxR (existing), stringi for pattern detection
**Time estimate:** 3-4 days

---

### Phase 3: Name Cleaning Core
**Rationale:** Name cleaning is most complex (8 functions) and highest-risk (Pitfall #1: synonym splitting). Build on audit trail and CAS patterns from Phase 1-2. Must implement IUPAC comma protection before general deployment.

**Delivers:**
- 8 name cleaning functions: terminal phrases, hazard warnings, quality adjectives, formulas, proprietary indicators, synonym splitting (with IUPAC protection), extraneous parentheses, stop word trimming
- 20+ test cases for synonym splitting edge cases (inverted IUPAC, digit-comma-digit, parenthetical)
- Before/after name comparison in UI

**Addresses:**
- **Pitfall #1 (synonym splitting IUPAC names)** — critical mitigation via protection rules and extensive testing
- Features: Basic name cleaning (table stakes), formula detection (differentiator)

**Risk:** HIGH — synonym splitting is most error-prone operation
**Time estimate:** 4-5 days

---

### Phase 4: Reference Data Filters + Editable Lists
**Rationale:** With CAS and name cleaning proven, add reference-based filtering (functional categories, food names, block lists). This phase introduces UI complexity (editable tables, reactive cascade management). Must implement debouncing and "Apply Changes" pattern to avoid Pitfall #2.

**Delivers:**
- 4 reference filter functions: functional category detection, food name flagging, block list matching, custom stop words
- rhandsontable editable tables for all 4 reference lists
- Debounced editing with explicit "Apply Changes" button
- Flag taxonomy UI: red/blocking, yellow/warning, blue/info badges
- "Re-run Cleaning" workflow with state invalidation

**Addresses:**
- **Pitfall #2 (reactive cascade explosion)** — critical mitigation via debouncing and staged editing
- **Pitfall #7 (flag behavior confusion)** — 3-tier visual taxonomy implementation
- Features: Editable reference lists (differentiator), blocking vs. annotating flags (differentiator)

**Stack:** **rhandsontable** (NEW) for editable tables
**Risk:** MEDIUM — reactive cascade management requires careful testing
**Time estimate:** 5-6 days

---

### Phase 5: Multi-Sheet Export + Re-Import Detection
**Rationale:** With full cleaning pipeline working, add reproducibility features. Multi-sheet export carries complete state (data + audit + reference lists + config). Re-import detection enables session restoration. This phase completes the reproducibility loop.

**Delivers:**
- 7-sheet Excel export: Data, Audit_Trail, Reference_Lists, Pipeline_Config, Data_Dictionary, Manifest, README
- Re-import detection via Manifest sheet parsing
- State restoration with conflict resolution modal (Pitfall #6 mitigation)
- Excel limit validation before export

**Addresses:**
- **Pitfall #6 (re-import overwriting edits)** — state divergence detection and confirmation modal
- **Pitfall #5 (Excel limits)** — final validation in export handler
- Features: Multi-sheet export (differentiator), re-import detection (differentiator)

**Stack:** **openxlsx2** (NEW) for multi-sheet export with metadata
**Time estimate:** 3-4 days

---

### Phase 6: Post-Curation QC (Optional for v1.3.0)
**Rationale:** Closes the loop: cleaning → curation → validation. Re-validates CAS after API resolution, enriches with functional use and safety flags from CompTox. Can be deferred to v1.3.1 if timeline is tight.

**Delivers:**
- `R/post_curation.R` — CAS re-validation, Unicode check, functional use lookup, safety flag enrichment
- Integration with Review Results tab (new columns)
- Timeout handling for API calls (Pitfall #4 mitigation for async operations)

**Addresses:**
- Features: Post-curation QC (differentiator)
- Pitfall #4 extension (progress tracking for API calls with variable latency)

**Uses:** ComptoxR functional use and safety flag APIs (existing)
**Risk:** LOW — similar to existing curation pipeline
**Time estimate:** 2-3 days

---

### Phase Ordering Rationale

**Dependencies:**
- Phase 0 must come before all others (creates clean modular structure for new features)
- Phase 1 is foundation for all cleaning (audit trail, reference data, state management)
- Phase 2 (CAS) and Phase 3 (names) are independent of each other but both depend on Phase 1
- Phase 4 (reference filters) depends on Phases 1-3 (uses cleaned CAS/names as input)
- Phase 5 (export) depends on Phases 1-4 (exports cleaned data + reference state)
- Phase 6 (post-QC) depends on existing curation pipeline, can run in parallel with Phases 1-5 if needed

**Groupings:**
- Phases 1-3: Core cleaning pipeline (no UI beyond basic preview)
- Phase 4: UI complexity (editable tables, reactive management)
- Phase 5: Reproducibility (export/import)
- Phase 6: Enrichment (post-curation)

**Risk mitigation:**
- Start with lowest-risk, highest-value (CAS cleaning)
- Tackle highest-risk operation (synonym splitting) after patterns established
- Add UI complexity (editable tables) after core pipeline proven
- Optional phase (post-QC) can be deferred if needed

### Research Flags

**Phases likely needing deeper research during planning:**
- **Phase 3 (Name Cleaning Core):** Synonym splitting IUPAC protection — may need consultation with chemist or OPSIN parser testing to validate edge cases
- **Phase 4 (Reference Filters):** Flag taxonomy UX — should conduct user testing to verify 3-tier system is intuitive (blocking vs. warning vs. info)

**Phases with standard patterns (skip research-phase):**
- **Phase 0 (Refactor):** Well-documented Shiny module patterns, no domain-specific complexity
- **Phase 1 (Foundation):** Straightforward reactive state management, established audit trail patterns
- **Phase 2 (CAS Pipeline):** ComptoxR functions already exist and are documented, low uncertainty
- **Phase 5 (Export):** Standard multi-sheet Excel export, openxlsx2 has comprehensive documentation
- **Phase 6 (Post-QC):** Same pattern as existing curation pipeline, no new concepts

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | **HIGH** | Only 2 new packages needed (openxlsx2, rhandsontable), both mature CRAN packages with active maintenance. All other needs satisfied by existing dependencies (stringi via tidyverse, withProgress built-in, readxl existing). Source quality: official CRAN docs, package manuals, verified community comparisons. |
| Features | **HIGH** | UX patterns verified via OpenRefine, DataTables, Shiny ecosystem documentation. Chemical-specific features (CAS rescue, functional use flagging) have no commercial analogs, but this is validated opportunity (live ChemReg data shows 14.4% + 2.4% of rows benefit). Table stakes and differentiators clearly defined. |
| Architecture | **HIGH** | Current app.R structure documented and understood. Inline-first approach is correct per Shiny best practices and Engineering Production-Grade Shiny Apps guide. State management patterns proven in existing codebase (reactiveValues cascade reset). Module extraction path is clear for v1.4+. |
| Pitfalls | **MEDIUM** | 7 critical pitfalls identified with detailed mitigation strategies, but severity estimates are based on inference from community reports and best practices, not direct experience with ChemReg scale. Synonym splitting IUPAC protection rules are based on IUPAC spec understanding, need chemist validation. Flag taxonomy UX needs user testing to confirm intuitiveness. |

**Overall confidence:** **HIGH**

### Gaps to Address

**Synonym splitting IUPAC protection validation:**
- Research identified protection patterns (digit-comma-digit, inverted form detection, parenthetical), but these are based on IUPAC spec interpretation
- **Mitigation:** During Phase 3 implementation, test with OPSIN parser or consult with chemist to validate edge cases. Create 20+ test cases from live ChemReg data before deployment. If protection fails on real data, fall back to semicolon-only splitting (safer).

**Editable reference list UX confirmation:**
- Research recommends rhandsontable over DT for editing, but user preference for Excel-like UX vs. form-based editing is assumed
- **Mitigation:** During Phase 4 implementation, build both patterns as prototypes (rhandsontable inline table + modal form for adding items). Quick user testing (5 minutes) to confirm which is more intuitive before committing to full implementation.

**Flag taxonomy intuitiveness:**
- 3-tier system (red/blocking, yellow/warning, blue/info) is based on universal UX patterns, but chemical inventory context may introduce confusion
- **Mitigation:** During Phase 4 implementation, create 15+ user testing scenarios: "Which flags must you fix before curation?" Verify 80%+ correct answer rate. If confusion persists, add inline tooltips with explicit explanations per flag type.

**Excel export limits on very large datasets:**
- Mitigation strategies (separate audit sheet, truncation, limit validation) are based on Excel spec research, but performance on 10,000+ row datasets is unknown
- **Mitigation:** During Phase 5 implementation, test export with synthetic 10,000-row dataset containing heavy transformations (20+ steps per row). Measure export time, file size, Excel open time. If limits are hit, implement CSV fallback option for datasets exceeding thresholds.

**Re-import state divergence detection accuracy:**
- Heuristics (timestamp comparison, state hash) are theoretically sound, but edge cases (user edits Excel data sheet manually, system clock skew) may cause false positives/negatives
- **Mitigation:** During Phase 5 implementation, create 10+ test scenarios: initial upload, re-upload after in-app edits, re-upload after Excel edits, re-upload after both. Verify modal appears correctly in each case. If heuristics are too noisy, simplify to always-prompt-on-re-import (safer but less seamless).

## Sources

### Primary (HIGH confidence)

**Stack Research:**
- [openxlsx2 Package Manual](https://cran.r-universe.dev/openxlsx2/doc/manual.html) — Multi-sheet export capabilities
- [openxlsx2 Documentation](https://janmarvin.github.io/openxlsx2/) — Workbook properties API
- [rhandsontable Documentation](https://jrowen.github.io/rhandsontable/) — Editable table patterns
- [Shiny withProgress Documentation](https://shiny.posit.co/r/reference/shiny/latest/withprogress.html) — Progress tracking built-in
- [readxl Documentation](https://readxl.tidyverse.org/) — Multi-sheet import
- [stringi Documentation](https://stringi.gagolewski.com/) — Unicode detection

**Architecture Research:**
- [Engineering Production-Grade Shiny Apps - Chapter 3: Structuring Your Project](https://engineering-shiny.org/structuring-project.html) — Modularization strategy
- [Mastering Shiny - Chapter 19: Shiny modules](https://mastering-shiny.org/scaling-modules.html) — Module patterns
- [Mastering Shiny - Chapter 15: Reactive building blocks](https://mastering-shiny.org/reactivity-objects.html) — State management
- [Shiny - Modularizing Shiny app code](https://shiny.posit.co/r/articles/improve/modules/) — Official module guide

**Feature Research:**
- [OpenRefine Official Site](https://openrefine.org/) — Data cleaning UX patterns
- [DataTables Child Rows](https://datatables.net/examples/api/row_details.html) — Audit trail display pattern
- [DT in Shiny](https://rstudio.github.io/DT/shiny.html) — Editable tables

### Secondary (MEDIUM confidence)

**Pitfall Research:**
- [Mastering Shiny - User feedback](https://mastering-shiny.org/action-feedback.html) — Progress tracking pitfalls
- [Form Validations vs Warnings (Baymard)](https://baymard.com/blog/validations-vs-warnings) — Flag taxonomy UX
- [NN/g Error Message Guidelines](https://www.nngroup.com/articles/errors-forms-design-guidelines/) — Visual design for errors
- [writexl CRAN documentation](https://cran.r-project.org/web/packages/writexl/writexl.pdf) — Excel limits
- [Excel Worksheets - Naming](https://bettersolutions.com/excel/worksheets/naming.htm) — Sheet naming constraints

**UX Pattern Research:**
- [Trifacta Data Wrangling Overview](https://www.softcrylic.com/blogs/trifacta-a-tool-for-the-modern-day-data-analyst/) — Recipe-based transformation
- [Data Table Design UX Best Practices](https://www.pencilandpaper.io/articles/ux-pattern-analysis-enterprise-data-tables) — Expandable rows
- [Reproducible Data Cleaning Guide](https://b-greve.gitbook.io/beginners-guide-to-clean-data/data-modeling/reproducibility) — Audit trail patterns

### Tertiary (LOW confidence)

**Chemical Domain:**
- [IUPAC nomenclature of organic chemistry - Wikipedia](https://en.wikipedia.org/wiki/IUPAC_nomenclature_of_organic_chemistry) — Inverted name forms
- [Chemical Inventory Management Best Practices](https://www.fldata.com/chemical-inventory-management-best-practices) — Domain validation needs

**Community Best Practices:**
- [R-bloggers: Comparing writexl, openxlsx, and xlsx](https://www.r-bloggers.com/2023/05/comparing-r-packages-for-writing-excel-files-an-analysis-of-writexl-openxlsx-and-xlsx-in-r/) — Package comparison
- [Appsilon: Better Than Excel - Use R Shiny Packages](https://appsilon.com/forget-about-excel-use-r-shiny-packages-instead/) — rhandsontable vs DT

---
*Research completed: 2026-03-04*
*Ready for roadmap: yes*
