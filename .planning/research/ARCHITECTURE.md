# Architecture Research: ChemReg v1.3 Integration

**Domain:** R/Shiny Chemical Inventory Cleaning Pipeline Integration
**Researched:** 2026-03-04
**Confidence:** HIGH

## Executive Summary

ChemReg v1.3 adds a pre/post-curation cleaning pipeline with interactive UI, editable reference lists, and multi-sheet Excel export/re-import. The existing app.R is 2,275 lines with a monolithic structure using reactiveValues() for state management and gated tab navigation. This research answers:

1. **Modularization strategy:** When and how to extract the "Clean Data" tab into a module vs inline implementation
2. **Reactive cascade updates:** How cleaning integrates into the existing upload → detect → preview → tag → curate → review flow
3. **Reference list state management:** Where editable lists live and how they trigger re-cleaning
4. **Multi-sheet export architecture:** Extending the existing writexl single-sheet export with embedded state
5. **Re-import detection:** Recognizing ChemReg exports without breaking CSV/XLSX flow
6. **Build order:** Dependency-aware implementation sequence

**Key Finding:** Don't modularize yet. Inline implementation with staged extraction later is lower risk, faster to ship, and aligns with Shiny best practices for incremental refactoring.

---

## Current Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Shiny UI Layer                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │ Upload   │  │ Detect   │  │ Preview  │  │ Tag      │    │
│  │ (sidebar)│  │ Info Tab │  │ Tab      │  │ Tab      │    │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘    │
│       │             │             │             │           │
│  ┌────┴─────┐  ┌────┴─────┐  ┌────┴─────┐                  │
│  │ Run      │  │ Review   │  │ (6 tabs) │                  │
│  │ Curation │  │ Results  │  │ Gated    │                  │
│  └──────────┘  └──────────┘  └──────────┘                  │
├─────────────────────────────────────────────────────────────┤
│                   Server Logic (app.R)                       │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  data_store (reactiveValues)                          │  │
│  │    raw, clean, detection, file_info                   │  │
│  │    column_tags, curation_results, consensus_data      │  │
│  │    resolution_state, dtxsid_cols, priority_order      │  │
│  │    error_filter_active, display_row_map, manual_queue │  │
│  └───────────────────────────────────────────────────────┘  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │ File     │  │ Detection│  │ Curation │  │ Consensus│   │
│  │ Handlers │  │ Ensemble │  │ Pipeline │  │ Classify │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
├─────────────────────────────────────────────────────────────┤
│                    Helper Modules (R/)                       │
│  file_handlers.R  data_detection.R  curation.R  consensus.R │
└─────────────────────────────────────────────────────────────┘
```

### Current Data Flow

```
Upload File (input$file_upload)
    ↓
validate_file() → safely_read_file() → detect_data_start()
    ↓
data_store$raw, data_store$clean, data_store$detection
    ↓ (show tabs: Detection Info, Raw Data, Tag Columns)
Tag Columns (UI: dropdowns per column)
    ↓ (input$apply_tags)
data_store$column_tags
    ↓ (show tab: Run Curation)
    ↓ (reset: curation_results, consensus_data, resolution_state)
Start Curation (input$run_curation)
    ↓
deduplicate_tagged_columns() → tiered search (exact → CAS → starts-with)
    ↓
classify_consensus() → resolution UI (if disagreements)
    ↓
data_store$curation_results, data_store$consensus_data
    ↓ (show tab: Review Results)
Export to Excel (downloadHandler)
    ↓
writexl::write_xlsx(list("Curated Data", "Summary", "Column Tags"))
```

### Cascade Reset Pattern

**Critical:** ChemReg uses strict invalidation on state changes.

| Trigger | Reset Scope | Rationale |
|---------|-------------|-----------|
| Re-upload file | ALL downstream state (tags, curation, consensus, resolution) | New data invalidates all derived state |
| Tag change | Curation results, consensus, resolution | Different columns → different curation input |
| Re-run curation | Resolution state only | New curation results → old resolutions invalid |

**Implementation:** Explicit `data_store$field <- NULL` assignments in observers, not reactive dependency chains. This prevents partial state inconsistencies.

---

## New Architecture: v1.3 Cleaning Pipeline Integration

### System Overview with Cleaning Pipeline

```
┌─────────────────────────────────────────────────────────────┐
│                     Extended UI Layer                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │ Upload   │  │ Detect   │  │ Preview  │  │ CLEAN    │    │
│  │ (sidebar)│  │ Info Tab │  │ Tab      │  │ DATA TAB │◄── NEW
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘    │
│       │             │             │             │           │
│  ┌────┴─────┐  ┌────┴─────┐  ┌────┴─────┐  ┌────┴─────┐    │
│  │ Tag      │  │ Run      │  │ Review   │  │ (7 tabs) │    │
│  │ Columns  │  │ Curation │  │ Results  │  │ Gated    │    │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘    │
├─────────────────────────────────────────────────────────────┤
│                  Server Logic (app.R + NEW)                  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  data_store (reactiveValues) — EXTENDED                │  │
│  │    raw, clean, detection, file_info                    │  │
│  │    cleaned_data ◄── NEW (post-pre_curation)            │  │
│  │    cleaning_audit ◄── NEW (comment columns)            │  │
│  │    cleaning_stats ◄── NEW (summary counts)             │  │
│  │    reference_lists ◄── NEW (editable stop words, etc.) │  │
│  │    column_tags, curation_results, consensus_data       │  │
│  │    resolution_state, dtxsid_cols, priority_order       │  │
│  │    error_filter_active, display_row_map, manual_queue  │  │
│  └───────────────────────────────────────────────────────┘  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │ File     │  │ Detection│  │ PRE-     │  │ Curation │   │
│  │ Handlers │  │ Ensemble │  │ CURATION │  │ Pipeline │   │
│  └──────────┘  └──────────┘  └────┬─────┘  └──────────┘   │
│                                    │                         │
│  ┌──────────┐  ┌──────────┐  ┌────┴─────┐  ┌──────────┐   │
│  │ POST-    │  │ Consensus│  │ Cleaning │  │ Export   │   │
│  │ CURATION │  │ Classify │  │ Reference│  │ Multi-   │   │
│  │ QC       │  │          │  │          │  │ Sheet    │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
├─────────────────────────────────────────────────────────────┤
│                 Helper Modules (R/ — EXTENDED)               │
│  file_handlers.R  data_detection.R  curation.R  consensus.R │
│  pre_curation.R ◄── NEW                                     │
│  post_curation.R ◄── NEW                                    │
│  cleaning_reference.R ◄── NEW                               │
└─────────────────────────────────────────────────────────────┘
```

### Extended Cascade Reset Pattern

| Trigger | Reset Scope | Rationale |
|---------|-------------|-----------|
| Re-upload file | ALL (including cleaned_data, cleaning_audit, reference_lists) | New raw data invalidates everything |
| Edit reference list + re-run cleaning | cleaned_data, cleaning_audit, tags, curation, consensus, resolution | Reference change → different cleaning output → all downstream invalid |
| Tag change | Curation results, consensus, resolution (NOT cleaning) | Cleaning is independent of tagging |
| Re-run curation | Resolution state only (NOT cleaning or tags) | Same as before |

**Critical new dependency:** Tags now operate on `cleaned_data` not `clean`, so cleaning MUST precede tagging in the workflow.

---

## Integration Points

### 1. Clean Data Tab UI/Server — Inline vs Module

**Decision: Inline implementation in app.R (Phase 1), extract to module later (Phase 2+).**

**Inline-first is correct for v1.3 because:**

1. **Lower risk:** The existing app has 6 tabs all implemented inline. Adding a 7th inline tab is consistent with current architecture.
2. **Faster to ship:** Module communication requires explicit input/output contracts, reactive triggers, and namespace management.
3. **Easier to debug:** All reactive logic lives in one file during initial development.
4. **Refactoring path exists:** Once stable, extract using the "stratégie du petit r" pattern.

### 2. Reference List State Management

**Decision: Store in `data_store$reference_lists` as a named list of character vectors.**

```r
data_store$reference_lists <- list(
  stop_words = c("proprietary", "ingredient", "hazard", ...),
  block_list = c("alcohol", "Acrylic Polymer", ...),
  food_names = c("yeast culture", "food starch", ...),
  functional_categories = c("fragrance", "parfum", "flavor", ...)
)
```

### 3. Multi-Sheet Excel Export Architecture

**Decision: Extend existing `writexl::write_xlsx()` with additional sheets for cleaning state.**

**Why writexl over openxlsx:** writexl is 2x faster, writes smaller files, and ChemReg already depends on it.

### 4. Re-Import Detection

**Decision: Check for "Metadata" sheet presence and `source = "ChemReg"` during upload.**

---

## Recommended Build Order

### Phase 1: Foundation (No UI Yet)

1. **P1.1: Create `R/cleaning_reference.R`** — 4 functions returning character vectors
2. **P1.2: Create `R/pre_curation.R` — Part 1** — Infrastructure (`append_comment`, `canonicalize_strings`)
3. **P1.3: `R/pre_curation.R` — Part 2** — 21 cleaning functions per PRE_POST_CURATION_PLAN.md
4. **P1.4: `R/pre_curation.R` — Part 3** — Pipeline orchestrator `run_pre_curation()`

**Dependencies:** None
**Time estimate:** 3-5 days

### Phase 2: UI Integration (Inline in app.R)

5. **P2.1: Extend `data_store` reactiveValues** — Add cleaned_data, cleaning_audit, cleaning_stats, reference_lists
6. **P2.2: Source new helper modules**
7. **P2.3: Add Clean Data tab UI**
8. **P2.4: Add cleaning observers**
9. **P2.5: Update Tag Columns to use `cleaned_data`**
10. **P2.6: Update cascade reset on re-upload**

**Dependencies:** Phase 1 complete
**Time estimate:** 2-3 days

### Phase 3: Multi-Sheet Export

11. **P3.1: Extend Excel export handler** — Add Cleaning Audit, Stats, Reference Lists, Metadata sheets
12. **P3.2: Implement re-import detection** — Hot-load embedded state

**Dependencies:** Phase 2 complete
**Time estimate:** 1 day

### Phase 4: Post-Curation QC (Optional for v1.3.0)

13. **P4.1: Create `R/post_curation.R`** — QC functions (CAS validation, Unicode check, functional use lookup)
14. **P4.2: Wire post-curation into Review Results tab**

**Dependencies:** Phase 3 complete
**Time estimate:** 1-2 days

### Phase 5: Refactor to Modules (Future, v1.4+)

15. **P5.1: Extract cleaning module**
16. **P5.2: Extract curation module**

**Dependencies:** Phase 2-4 proven stable
**Time estimate:** 3-4 days

---

## Data Flow Changes: Before vs After

### Current Flow (v1.2)

```
Upload → data_store$raw
    ↓
detect_data_start() → data_store$clean
    ↓
Tag Columns → data_store$column_tags
    ↓
run_curation(clean) → data_store$curation_results
    ↓
classify_consensus() → data_store$consensus_data
    ↓
Export (3 sheets)
```

### New Flow (v1.3)

```
Upload → data_store$raw
    ↓
detect_data_start() → data_store$clean
    ↓
run_pre_curation(clean) → data_store$cleaned_data ◄── NEW
    ↓
Tag Columns (uses cleaned_data) → data_store$column_tags
    ↓
run_curation(cleaned_data) → data_store$curation_results ◄── CHANGED INPUT
    ↓
classify_consensus() → data_store$consensus_data
    ↓
run_post_curation(consensus_data) → QC warnings ◄── NEW
    ↓
Export (7 sheets) ◄── NEW
```

**Critical change:** Curation pipeline input switches from `data_store$clean` to `data_store$cleaned_data`. This must be wired in `observeEvent(input$run_curation)`.

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Modularizing Too Early

**What people do:** Extract the Clean Data tab into a module before the pipeline is proven stable.

**Why it's wrong:** Module communication adds complexity, debugging is harder, boundaries may need redrawing during development.

**Do this instead:** Build inline first, prove the pipeline works, THEN extract to module.

### Anti-Pattern 2: Over-Engineering Reference List Storage

**What people do:** Store reference lists in a database or external YAML config file.

**Why it's wrong:** Reference lists are small, change infrequently, and are user-editable. Adding database/file I/O increases deployment complexity.

**Do this instead:** Store in `data_store$reference_lists` as in-memory character vectors, export with Excel multi-sheet.

### Anti-Pattern 3: Reactive Dependency Chains for Cascade Reset

**What people do:** Rely on reactive invalidation to cascade resets.

**Why it's wrong:** Reactive chains can trigger partial updates, hard to reason about order, causes flickering UI.

**Do this instead:** Explicit `data_store$field <- NULL` assignments, centralize reset logic in helper functions.

### Anti-Pattern 4: Using openxlsx for Simple Multi-Sheet Export

**What people do:** Add openxlsx dependency for multi-sheet export because it has more features.

**Why it's wrong:** ChemReg already uses writexl, which is 2x faster and produces smaller files. openxlsx features (styling, formulas) are not needed.

**Do this instead:** Use writexl::write_xlsx() with a named list of data frames.

---

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 1-1,000 rows per file | Current inline architecture is fine; no changes needed |
| 1,000-50,000 rows | Pre-curation pipeline may slow down; consider withProgress() for long-running cleaning steps |
| 50,000+ rows | Consider chunked processing, background jobs (promises + future), async curation |

### First Bottleneck: Pre-Curation Runtime

For large files (>10k rows), the 21-step pipeline may take >10 seconds.

**Solution:** Wrap `run_pre_curation()` in `withProgress()` (already proven in existing curation pipeline).

### Second Bottleneck: Multi-Sheet Excel Export

For files with >50k rows and 7 sheets, writexl may take >5 seconds.

**Solution:** Generate Excel file asynchronously using future/promises (deferred to v1.4+).

---

## Integration Testing Strategy

### Test 1: Upload → Clean → Tag → Curate → Export (Happy Path)

1. Upload `data/chemical_validation_test.csv` (172 rows)
2. Verify Clean Data tab appears with summary cards
3. Verify `data_store$cleaned_data` has 21 cleaning steps applied
4. Tag columns, verify tagging uses cleaned_data
5. Run curation, verify consensus uses cleaned_data
6. Export, verify 7 sheets present in Excel

### Test 2: Reference List Edit → Re-Run Cleaning

1. Upload file
2. Edit stop words list (add "foo", "bar")
3. Click "Re-run Cleaning"
4. Verify cleaned_data updated, tags/curation reset
5. Verify new stop words flagged in cleaning audit

### Test 3: Re-Import ChemReg Export

1. Export curated data
2. Close app, restart
3. Re-upload exported Excel file
4. Verify metadata detected, state restored
5. Verify cleaned_data, reference_lists, column_tags all present

### Test 4: Backward Compatibility (Non-ChemReg Excel)

1. Upload a normal Excel file (not ChemReg export)
2. Verify normal upload flow (no hot-load)
3. Verify cleaning runs, app functions normally

### Test 5: Cascade Reset on Re-Upload

1. Upload file, clean, tag, curate
2. Re-upload different file
3. Verify confirmation modal appears
4. Confirm replacement
5. Verify ALL state reset (cleaned_data, tags, curation, reference_lists)

---

## Sources

### Shiny Architecture and Modules
- [Engineering Production-Grade Shiny Apps - Chapter 3: Structuring Your Project](https://engineering-shiny.org/structuring-project.html)
- [Shiny - Modularizing Shiny app code (Official Posit Guide)](https://shiny.posit.co/r/articles/improve/modules/)
- [Mastering Shiny - Chapter 19: Shiny modules](https://mastering-shiny.org/scaling-modules.html)
- [How to Modularize an Existing Shiny App](https://dataenthusiast.ca/2023/how-to-modularize-existing-shiny-app/)
- [A beginner's guide to Shiny modules - Emily Riederer](https://emilyriederer.netlify.app/post/shiny-modules/)
- [5 Modularization - Shiny App Workflows](https://b-klaver.github.io/shinyWorkflows/modularization.html)

### Reactive Programming and State Management
- [Mastering Shiny - Chapter 15: Reactive building blocks](https://mastering-shiny.org/reactivity-objects.html)
- [Mastering Shiny - Chapter 16: Escaping the graph](https://mastering-shiny.org/reactivity-components.html)
- [How to Modify Reactive Values in Shiny Apps - Nela Tomić](https://medium.com/@netomics/modifying-reactive-values-in-shiny-apps-f5df29fb6603)
- [Communication between modules and its whims - Rtask](https://rtask.thinkr.fr/communication-between-modules-and-its-whims/)
- [Shiny Modules (part 2): Share reactive among multiple modules - ArData](https://www.ardata.fr/en/post/2019/04/26/share-reactive-among-shiny-modules/)

### Excel Multi-Sheet Export/Import
- [R: How to Export Data Frames to Multiple Excel Sheets - Statology](https://www.statology.org/r-export-to-excel-multiple-sheets/)
- [Read Excel Files - readxl package](https://readxl.tidyverse.org/)
- [How to read a XLSX file with multiple Sheets in R? - GeeksforGeeks](https://www.geeksforgeeks.org/r-language/how-to-read-a-xlsx-file-with-multiple-sheets-in-r/)
- [Introduction - openxlsx package](https://ycphs.github.io/openxlsx/articles/Introduction.html)

### Shiny Configuration and Editable Data
- [Mastering Shiny - Chapter 10: Dynamic UI](https://mastering-shiny.org/action-dynamic.html)
- [Shiny module to interactively edit a data.frame - datamods package](https://dreamrs.github.io/datamods/reference/edit-data.html)

---

*Architecture research for: ChemReg v1.3 Pre/Post-Curation Cleaning Pipeline Integration*
*Researched: 2026-03-04*
*Confidence: HIGH (Shiny patterns verified via official documentation and community best practices; multi-sheet export confirmed via package docs)*
