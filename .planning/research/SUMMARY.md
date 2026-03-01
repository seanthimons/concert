# Project Research Summary

**Project:** ChemReg v1.2 Curation Refinement
**Domain:** Chemical inventory data curation tool (R Shiny application)
**Researched:** 2026-03-01
**Confidence:** HIGH

## Executive Summary

ChemReg v1.2 is a curation refinement milestone that builds entirely on the existing stack with zero new dependencies. All planned features—bulk DTXSID validation, error row retry with re-tagging, smarter column visibility, richer resolution context, search chain reordering, and "Other" tag curation participation—can be implemented using capabilities already present in the codebase (ComptoxR 1.4.0, DT with Buttons extension, standard Shiny reactive patterns). The research reveals that this milestone is more about code logic refinement and UI polish than about integrating new technologies.

The recommended approach prioritizes search accuracy improvements first (reordering the search chain to exact → CAS → starts-with and enabling "Other" tags in full curation), followed by UI refinements that reduce cognitive load (hiding untagged columns automatically), and finally advanced workflows that improve error recovery (manual DTXSID entry and subset retry with re-tagging). This ordering minimizes risk by establishing data quality foundations before introducing complex merge-back workflows.

Key risks center around three areas: (1) **search precision collapse** if starts-with search moves to last-resort position without proper filtering—requires empirical validation on sample datasets before deployment; (2) **consensus algorithm confusion** when "Other" tagged columns participate equally in voting alongside Name and CASRN columns—needs semantic decision on whether Other columns vote, observe, or vote with reduced weight; (3) **retry merge state loss** if error row retry uses join-based merging instead of index-based replacement—must preserve row order and .pinned state to avoid breaking user mental model. All three risks are mitigable through careful testing and deliberate architectural choices documented in PITFALLS.md.

## Key Findings

### Recommended Stack

**No new dependencies required.** The existing stack (R 4.5.1, Shiny, bslib, DT, ComptoxR 1.4.0, tidyverse) already provides all capabilities needed for v1.2 features. ComptoxR's `chemi_amos_batch()` function supports bulk DTXSID validation, DT's Buttons extension provides column visibility controls via `columnDefs`, and standard Shiny reactive patterns handle row selection and subset workflows. The pipeline already captures `preferredName` and `rank` from CompTox API responses—these just need to be surfaced in the resolution dropdown HTML.

**Core technologies:**
- **ComptoxR 1.4.0** (existing): CompTox API access — `chemi_amos_batch()` function enables bulk DTXSID validation without additional packages
- **DT with Buttons extension** (existing): Interactive tables with column visibility — `columnDefs: list(visible = FALSE)` and `colvis` button already in use, just needs configuration expansion
- **Shiny reactiveValues pattern** (existing): State management — `input$tableId_rows_selected` provides row selection for subset workflows, no special packages needed
- **bslib modals** (existing): UI dialogs — native `modalDialog()` and `showModal()` sufficient for re-tagging UI during error retry

### Expected Features

The v1.2 feature landscape reveals a mix of table stakes (error row filtering, column visibility, manual identifier entry) and differentiators (smart auto-hiding of untagged columns, re-tag before retry, contextual resolution dropdowns with preferredName + rank). Research shows that bulk validation and subset retry are industry-standard patterns in data curation tools (AWS DMS, Databricks CDC pipelines) and users expect them for large datasets.

**Must have (table stakes):**
- **Error row filtering** — users expect ability to focus on problems (complexity: LOW, already exists via consensus_status filter)
- **Column visibility toggle** — universal table feature for messy multi-column data (complexity: LOW, DT colvis extension)
- **Manual identifier entry** — standard fallback when automated matching fails (complexity: MEDIUM, requires validation API + reactive handling)
- **Bulk validation** — avoid round-trip API calls for each manual entry (complexity: MEDIUM, CompTox Batch Search supports thousands at once)
- **Subset retry** — industry standard for large datasets, re-run failed items without full reprocess (complexity: MEDIUM, filter → modify → re-run → merge back pattern)

**Should have (differentiators):**
- **Smart column hiding (auto-hide untagged)** — reduces cognitive load, most tools require manual toggle (complexity: LOW, single checkbox + reactive filter)
- **Re-tag before retry** — unique workflow: fix tag assignment and retry just errors (complexity: MEDIUM, subset-only tag invalidation vs. full cascade)
- **Contextual resolution dropdown** — show preferredName + QC level + rank, not just DTXSID (complexity: LOW-MEDIUM, data already available from pipeline)
- **Search chain reordering** — prioritize CAS validation over starts-with fuzzy matching (complexity: LOW, reorder function calls in `run_tiered_search()`)

**Defer (v2+):**
- **Inline editing of all cells** — scope creep, this is curation not general spreadsheet editing (complexity: HIGH, DT editable cells + validation loop)
- **Retry with search tier override** — power user feature, defer until demand proven (complexity: HIGH, per-row search strategy parameters)
- **Persistent preferences across sessions** — complexity not justified by value for single-file workflow (complexity: MEDIUM-HIGH, session state management across page refresh)

### Architecture Approach

The curation refinement features integrate cleanly into the existing pipeline architecture without requiring structural changes. The current system uses a four-stage pipeline (deduplicate → search → map → classify) that processes tagged columns through tiered CompTox API searches (exact → starts-with → CAS) and produces consensus results with resolution dropdowns for conflicts. New features either modify the pipeline order (search chain reordering), expand input scope (Other tags as searchable), or add parallel workflows that reuse pipeline components (subset retry).

**Major components:**
1. **Pipeline modifications** (R/curation.R) — reorder search tiers in `run_tiered_search()`, expand `deduplicate_tagged_columns()` to include Other tags, add `validate_dtxsid_bulk()` and `run_curation_subset()` helper functions
2. **Resolution state updates** (app.R) — extend `output$curation_table` hidden columns logic to include untagged original columns, modify `get_resolution_options()` to format dropdown HTML with preferredName/rank/qc_tier metadata
3. **Subset retry workflow** (app.R + R/curation.R) — new UI elements (retry button, modal dialog with tag dropdowns), new server observers for subset execution and merge-back logic using index-based replacement to preserve row order and .pinned state

**Key integration patterns:**
- **Function composition**: Subset retry reuses existing pipeline functions (deduplicate → search → map → classify) on filtered data
- **Reactive data store extensions**: Add `selected_rows` and `subset_tags` to reactiveValues for retry workflow state
- **Progressive disclosure**: Show manual entry and retry UI only when appropriate rows selected (error rows for manual entry, selected rows for retry)

### Critical Pitfalls

Research identified six critical pitfalls across the feature set, with clear prevention strategies documented:

1. **DT Column Index Drift After Hiding Columns** — When hiding columns via `columnDefs: list(visible = FALSE)`, JS callbacks using `data-row` attributes for R-side row indices (1-based) can misalign if mixing with DT column indices (0-based, visible only). Prevention: Always use R-side row indices in `data-row` attributes, never mix with DT column indices in callbacks, test with 0/1/10+ hidden columns scenarios.

2. **Starts-With Search Precision Collapse** — Moving starts-with to last-resort position (exact → CAS → starts-with) may degrade match quality because starts-with returns ALL prefix matches with no relevance filtering. For short queries like "Acet" or "Prop", this produces 100+ matches and `slice_min(rank, n=1)` arbitrarily picks top-ranked, which may not be user's intended chemical. Prevention: Run empirical validation on sample datasets with both tier orders, add length-based filtering (only use starts-with for queries 6+ characters), log tier attribution to audit match quality.

3. **Consensus Algorithm Breaks with Three Column Types** — The consensus logic assumes all dtxsid_* columns are semantically equivalent (Name or CASRN tags). When "Other" columns become curation participants, you have three tag types with different reliability levels, but consensus counts them equally. A 2-name + 1-CAS agreement gets the same QC tier as 3-name agreement, even though CAS is more reliable. Prevention: Decide Other's consensus role (vote equally vs. reduced weight vs. observe-only), update `find_dtxsid_cols` with tag awareness, revise QC tier calculation to be tag-type aware.

4. **Retry Merge Loses Resolution State** — Using `left_join()` to merge retried subset back into original data creates duplicated columns (dtxsid_Name.x, dtxsid_Name.y) and loses .pinned state or row order. Prevention: Use row index-based replacement `original[indices, cols] <- retried[match(...), cols]` instead of join, preserve .pinned explicitly before merge, validate row count invariant (nrow unchanged).

5. **Manual DTXSID Entry Bypasses Validation** — Manual entry creates a new path that bypasses the pipeline's guaranteed API-validated IDs. Invalid DTXSIDs (typos, wrong format, non-existent) flow into consensus_dtxsid, breaking downstream assumptions. Prevention: Validate via `ComptoxR::ct_get_dtxsid_details()` before storing, batch validation for bulk paste, store `consensus_source = "manual"` and `manual_validated = TRUE/FALSE` columns, provide instant feedback with green checkmark/red X.

6. **Hidden Column Filter Breaks DT Filtering** — DT's `filter = "top"` generates filter inputs for ALL columns including hidden ones. Invisible filters accumulate state (browser autocomplete, user typing before hiding), causing mysterious empty table states. Prevention: Remove hidden columns from display_df before passing to datatable(), or disable filtering on hidden columns via `searchable: FALSE` in columnDefs.

## Implications for Roadmap

Based on research, suggested phase structure prioritizes foundational accuracy improvements, then UI polish, then advanced workflows:

### Phase 1: Search Chain Foundations
**Rationale:** Lowest risk, highest immediate value. Improves data quality without introducing new UI complexity or merge-back workflows. Search chain reordering (exact → CAS → starts-with) prioritizes specific identifiers over fuzzy matching, and enabling Other tags expands curation coverage. Both are self-contained backend changes with no new state management.

**Delivers:** More accurate chemical matching via CAS-prioritized search tier order, full curation participation for "Other" tagged columns

**Addresses:**
- Search chain reordering (FEATURES.md: differentiator, code change only)
- "Other" tag as full curation participant (FEATURES.md: differentiator, code change only)

**Avoids:**
- Starts-With Search Precision Collapse (PITFALLS.md #2): Empirical validation on sample datasets before deployment
- Consensus Algorithm Breaks with Three Column Types (PITFALLS.md #3): Decide Other's consensus role and update logic before enabling Other search

**Research flag:** NEEDS empirical validation — test tier order (exact → CAS → starts vs. exact → starts → CAS) on 100-row sample dataset with known ground truth. Compare consensus_status distribution (agree/disagree/error percentages) to choose optimal order.

### Phase 2: UI Refinements (Column Visibility)
**Rationale:** Medium complexity, high polish value. Reduces cognitive load for users reviewing messy chemical data with 20+ original columns. Standard DT configuration change with no backend modifications. Establishes clean UI foundation before adding manual entry and retry workflows.

**Delivers:** Automatically hide untagged columns in Review Results table, user toggle to show/hide via colvis button

**Addresses:**
- Smart column hiding (FEATURES.md: differentiator, LOW complexity)
- Column visibility toggle (FEATURES.md: table stakes, LOW complexity)

**Avoids:**
- DT Column Index Drift (PITFALLS.md #1): Test resolution dropdown with 0, 1, 10+ hidden columns to verify data-row attribute correctness
- Hidden Column Filter Breaks DT Filtering (PITFALLS.md #6): Disable filtering on hidden columns via `searchable: FALSE` or remove from display_df

**Research flag:** STANDARD pattern — DT columnDefs well-documented, skip research-phase. Follow existing implementation in app.R lines 1413-1437.

### Phase 3: Manual DTXSID Entry with Validation
**Rationale:** Highest table-stakes priority from FEATURES.md. Enables users to fix errors that API can't resolve (chemicals not in CompTox, ambiguous names). Single-direction workflow (user → validation → update) is simpler than bidirectional retry with merge-back. Establishes validation patterns before subset retry complexity.

**Delivers:** Modal dialog for manual DTXSID entry on selected error rows, bulk validation via ComptoxR, preview of proposed changes before commit

**Addresses:**
- Manual DTXSID entry (FEATURES.md: table stakes, MEDIUM complexity)
- Bulk validation (FEATURES.md: table stakes, MEDIUM complexity)
- Validation preview (FEATURES.md: differentiator, MEDIUM complexity)

**Avoids:**
- Manual DTXSID Entry Bypasses Validation (PITFALLS.md #5): Implement validation API call before storing, batch validation for bulk paste, instant feedback UI

**Research flag:** STANDARD pattern — modal dialogs + API validation well-documented in Shiny ecosystem. Follow existing `showModal()` usage in codebase.

### Phase 4: Error Row Retry with Re-tagging
**Rationale:** Most complex feature, requires subset pipeline + merge logic + modal UX. Builds on validation patterns from Phase 3 (modal dialog, bulk operations). Delivers high value for users who mis-tagged columns initially—retry just errors without full reprocess. Should come last to avoid risking earlier phases with merge-back complexity.

**Delivers:** Subset retry workflow (filter error rows → re-tag in modal → re-curate subset → merge back), preserves row order and .pinned state

**Addresses:**
- Subset retry (FEATURES.md: table stakes, MEDIUM complexity)
- Re-tag before retry (FEATURES.md: differentiator, MEDIUM complexity)

**Avoids:**
- Retry Merge Loses Resolution State (PITFALLS.md #4): Use index-based replacement not join, preserve .pinned explicitly, validate row count invariant
- Redundant consensus classification (PITFALLS.md performance trap): Only classify retried rows, replace in original without re-classifying all

**Research flag:** NEEDS careful testing — merge-back logic requires thorough unit tests for row order preservation, .pinned state, column count validation. Test scenarios: retry with same tags, retry with new tag added, retry with tag removed.

### Phase 5: Contextual Resolution Dropdown
**Rationale:** Final polish feature. Data (preferredName, rank, qc_tier) already exists in resolution_state, just needs HTML formatting change in `get_resolution_options()`. Low risk, high UX value. Should come after retry workflow to avoid complicating testing (retry + new dropdown format = two variables changing).

**Delivers:** Resolution dropdown shows "DTXSID - PreferredName (Rank X, QC Tier)" instead of raw DTXSID

**Addresses:**
- Contextual resolution dropdown (FEATURES.md: differentiator, LOW-MEDIUM complexity)

**Avoids:**
- No major pitfalls—straightforward HTML string concatenation

**Research flag:** STANDARD pattern — HTML formatting in Shiny, skip research-phase. Follow existing `get_resolution_options()` pattern in app.R lines 1383-1409.

### Phase Ordering Rationale

- **Phase 1 → 2**: Search reordering and Other tag enablement should stabilize before UI changes (both affect consensus results, want stable data before adding column hiding)
- **Phase 2 → 3**: Column hiding polish before manual entry reduces visual clutter for error resolution workflow
- **Phase 3 → 4**: Manual entry establishes validation patterns (modal dialog, bulk API calls) before subset retry complexity
- **Phase 4 → 5**: Retry workflow should work with existing dropdown format before adding richer context (reduces test matrix: retry + old dropdown, then add new dropdown)

**Dependency chain discovered:**
- Search tier order affects consensus distribution → affects which rows need manual entry/retry → affects UX priorities
- Other tag participation affects consensus algorithm → must resolve voting semantics before enabling search
- Column hiding affects visible columns → must not break resolution dropdown indices (PITFALLS #1)
- Subset retry merge strategy → must preserve .pinned state from manual entry (Phase 3 creates pinned rows, Phase 4 must preserve them)

### Research Flags

**Phases needing deeper research during planning:**
- **Phase 1 (Search Foundations)**: Empirical tier order validation — run curation on 100-row sample with both orders, compare match quality metrics (precision, recall, consensus rate)
- **Phase 1 (Other Tag)**: Consensus semantics decision — document whether Other columns vote equally, vote reduced, or observe-only; update consensus logic accordingly
- **Phase 4 (Error Retry)**: Merge-back testing — create comprehensive test suite for index-based replacement: same-tag retry, new-tag addition, tag removal, row order preservation, .pinned state preservation

**Phases with standard patterns (skip research-phase):**
- **Phase 2 (Column Visibility)**: DT columnDefs well-documented, existing implementation in codebase to follow
- **Phase 3 (Manual Entry)**: Modal dialogs and API validation standard Shiny patterns, follow existing `showModal()` usage
- **Phase 5 (Dropdown Context)**: HTML formatting in Shiny, straightforward extension of existing `get_resolution_options()` function

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All required capabilities verified in existing codebase (ComptoxR `chemi_amos_batch()`, DT Buttons extension, Shiny reactive row selection). Zero new dependencies confirmed via function signature inspection and package documentation. |
| Features | HIGH | Table stakes and differentiators validated against industry patterns (AWS DMS, Databricks CDC for subset retry; DataTables, MUI for column visibility). FEATURES.md correctly identifies bulk validation and manual entry as expected, re-tagging as unique differentiator. |
| Architecture | HIGH | Integration points clearly defined via codebase analysis (app.R 1,719 lines, R/curation.R 624 lines, R/consensus.R 229 lines). All new features map to existing patterns (function composition for subset retry, reactive store extensions, progressive disclosure). |
| Pitfalls | MEDIUM-HIGH | Critical pitfalls identified via codebase inspection (column index drift, consensus voting) and official documentation (CompTox search behavior, DT filter state). Starts-with precision collapse is MEDIUM confidence—requires empirical validation. Recovery strategies documented with cost estimates. |

**Overall confidence:** HIGH — All v1.2 features implementable with existing stack and standard patterns. Main uncertainty is empirical tier order validation (needs real data testing) and Other tag consensus semantics (needs product decision, not research).

### Gaps to Address

**Search tier order optimization:**
- **Gap**: No empirical data on match quality for exact → CAS → starts vs. exact → starts → CAS
- **How to handle**: During Phase 1 planning, run curation on 100-row sample dataset (50 exact matches, 30 CAS-only, 20 typos) with both orders. Compare consensus_status distribution. Choose order that maximizes agree rate while minimizing false positives.
- **Validation needed**: Test with short queries (2-3 letters like "Pb", "Hg") vs. long queries (8+ letters) to ensure starts-with filtering works across query length spectrum

**Other tag consensus voting semantics:**
- **Gap**: No product decision on whether Other columns should vote equally with Name/CASRN, vote reduced weight, or observe-only
- **How to handle**: During Phase 1 planning, document decision in ARCHITECTURE.md based on user intent for Other tag (if Other = supplier codes/batch IDs, should be observe-only; if Other = alternate names, should vote equally)
- **Implementation**: Update `classify_consensus()` with tag-aware logic before enabling Other search—test scenarios: 1 Name + 1 CAS + 1 Other all agree; 1 Name + 1 Other agree, CAS NA; 2 Other + 1 Name

**Retry merge-back edge cases:**
- **Gap**: No test coverage for subset retry with new tag addition (adds new dtxsid_* columns to resolution_state)
- **How to handle**: During Phase 4 planning, create comprehensive unit tests for merge_subset_results() function: (1) same-tag retry preserves column count, (2) new-tag retry adds columns without .x/.y suffixes, (3) tag-removal retry removes columns, (4) all scenarios preserve row order and .pinned state
- **Validation needed**: Test with edge case: retry 3 error rows, user adds "Other" tag to one column → verify dtxsid_Other column appears for retried rows, NA for non-retried rows

## Sources

### Primary (HIGH confidence)

**Existing Codebase (verified via source inspection):**
- `app.R` (1,719 lines) — DT table rendering (lines 1370-1484), resolution dropdown HTML (lines 1383-1409), hidden columns via columnDefs (line 1437), current .pinned state handling
- `R/curation.R` (624 lines) — `run_tiered_search()` tier order (lines 274-363), `deduplicate_tagged_columns()` tag filtering (lines 16-58), preferredName/rank capture (lines 67-101, 393)
- `R/consensus.R` (229 lines) — `classify_consensus()` logic (lines 25-40), `find_dtxsid_cols()` pattern matching (line 53), QC tier calculation (line 31)

**Official Documentation:**
- [ComptoxR GitHub Repository](https://github.com/seanthimons/ComptoxR) — `chemi_amos_batch(dtxsids = ...)` function signature verified via `args()`, bulk DTXSID validation capability confirmed
- [DT Package Documentation - Extensions](https://rstudio.github.io/DT/extensions.html) — Buttons extension with colvis support, column visibility API via columnDefs
- [DT Shiny Documentation - Row Selection](https://rstudio.github.io/DT/shiny.html) — `input$tableId_rows_selected` usage for subset workflows
- [US EPA CompTox Dashboard - Batch Search](https://www.epa.gov/comptox-tools/chemicals-dashboard-help-batch-search) — Batch search supports exact matches, bulk validation for DTXSIDs/CASRNs
- [US EPA CompTox Dashboard - Basic Search](https://www.epa.gov/comptox-tools/chemicals-dashboard-help-basic-search) — Exact vs. substring search behavior, starts-with returns all prefix matches

### Secondary (MEDIUM confidence)

**Industry Patterns and Best Practices:**
- [AWS DMS Data Validation](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Validating.html) — Subset retry patterns for ETL pipelines, idempotent merge via unique key validation
- [Databricks Blog - Late Arriving Dimensions](https://www.databricks.com/blog/2020/12/15/handling-late-arriving-dimensions-using-a-reconciliation-pattern.html) — Retry and merge-back patterns for CDC pipelines
- [Data Validation in ETL - Integrate.io](https://www.integrate.io/blog/data-validation-etl/) — Bulk validation patterns, error recovery workflows
- [Bulk Action UX Guidelines - Eleken](https://www.eleken.co/blog-posts/bulk-actions-ux) — UI patterns for multi-row selection, bulk operations feedback
- [DataTables Column Visibility Examples](https://datatables.net/examples/api/show_hide.html) — Official examples for columnDefs and colvis button configuration

**UI Framework Documentation:**
- [DT GitHub Issue #153 - Column Visibility](https://github.com/rstudio/DT/issues/153) — Community patterns for hiding columns, pitfall discussions on filter state
- [MUI X Data Grid - Column Visibility](https://mui.com/x/react-data-grid/column-visibility/) — Priority-based defaults, user override patterns
- [Mastering Shiny - Reactivity Objects](https://mastering-shiny.org/reactivity-objects.html) — Reference semantics of reactiveValues, state preservation patterns

### Tertiary (LOW confidence - needs validation)

**Search Strategy Tradeoffs:**
- [Enabling High-Throughput Searches - PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC8630643/) — CompTox current search limitations, future fuzzy matching plans (confirms starts-with has no relevance scoring, supports precision collapse concern)
- [Sourcing Chemical Data from CompTox - ScienceDirect](https://www.sciencedirect.com/science/article/pii/S0160412021001914) — Identifier search exact match requirement, spelling issues (confirms tier order affects match quality, needs empirical validation)

**Join and Merge Behavior:**
- [dplyr Mutating Joins Documentation](https://dplyr.tidyverse.org/reference/mutate-joins.html) — Official join documentation (confirms join doesn't preserve attributes like .pinned, validates anti-pattern concern)
- [How to Merge Data in R - InfoWorld](https://www.infoworld.com/article/2264570/how-to-merge-data-in-r-using-r-merge-dplyr-or-datatable.html) — Join mechanics and attribute preservation (no guarantees for custom attributes)

---

*Research completed: 2026-03-01*
*Ready for roadmap: yes*
*Phase count estimate: 5 phases*
*Research flags: 3 needs-validation items, 3 standard-pattern items*
