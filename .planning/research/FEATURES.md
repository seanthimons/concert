# Feature Landscape

**Domain:** Chemical inventory data cleaning and curation pipeline
**Researched:** 2026-03-04
**Confidence:** HIGH for UX patterns (verified with OpenRefine, DataTables, Shiny ecosystem); MEDIUM for chemical-specific workflows (limited domain-specific tools)

---

## Executive Summary

Data cleaning tools follow a "preview → transform → review" pattern with transparent audit trails and reproducible configurations. Table stakes include: interactive cleaning with undo/redo, visual distinction between blocking errors and warnings, exportable operation history, and tabular data display. Differentiators for chemical inventory: embedded audit trails per row, editable domain-specific reference lists (stop words, functional categories), smart re-import detection with state restoration, and multi-sheet Excel exports carrying configuration + data dictionary.

The R/Shiny ecosystem supports these patterns through: DT for editable tables with child row expansion, bslib tabs for progressive disclosure workflows, and writexl for multi-sheet exports. Chemical-specific features (CAS validation, functional use flagging) have no commercial analogs — this is greenfield opportunity.

---

## Table Stakes

Features users expect from data cleaning tools. Missing these = product feels incomplete or untrustworthy.

| Feature | Why Expected | Complexity | Dependencies | Notes |
|---------|--------------|------------|--------------|-------|
| **Tabular data preview** | Standard for all data tools; users need to see raw → clean transformation | Low | DT package (existing) | Already implemented in Data Preview tab |
| **Undo/redo operation history** | OpenRefine standard; users expect reversibility without data loss | Medium | Reactive values tracking pipeline state | Need stack of pipeline configs + data snapshots |
| **Visual flag distinction** | Error = red + blocking; Warning = yellow/orange + proceeds; universal UX pattern ([Baymard](https://baymard.com/blog/validations-vs-warnings), [NN/g](https://www.nngroup.com/articles/errors-forms-design-guidelines/)) | Low | Bootstrap color utilities (existing) | Red/exclamation for blocking flags; yellow/warning icon for annotations |
| **Summary statistics cards** | Users need "what changed?" counts before/after cleaning | Low | Existing summary card pattern from v1.0-1.2 | "X CAS rescued", "Y formulas detected", "Z flagged for review" |
| **Exportable results** | All tools export cleaned data; baseline expectation | Low | writexl (existing) | Enhanced to multi-sheet in differentiators |
| **Progressive workflow tabs** | ChemReg pattern (Data Preview → Tag → Curate); users expect linear progression | Low | bslib nav_panel (existing) | Insert "Clean Data" tab between Preview and Tag |
| **Batch operations** | Clean entire column/dataset at once; manual row-by-row = unacceptable | Medium | Pipeline functions vectorized over df columns | Pre-curation.R functions must be vectorized |
| **Before/after comparison** | Users validate by comparing distributions ([Juice Analytics](https://www.juiceanalytics.com/writing/guide-to-cleaning-data), [Tableau](https://help.tableau.com/current/prep/en-us/prep_clean.htm)) | Medium | DT with column visibility toggles | Show original + cleaned columns side-by-side or toggle |

---

## Differentiators

Features that set ChemReg apart from generic data cleaning tools. Not expected by all users, but highly valued by chemical inventory managers.

| Feature | Value Proposition | Complexity | Dependencies | Notes |
|---------|-------------------|------------|--------------|-------|
| **Per-row audit trail** | Transparency: "What changed and why?" for every cell transformation | High | DT child rows + comment columns in df | [DataTables child row API](https://datatables.net/examples/api/row_details.html); pipe-separated audit log per row |
| **Editable reference lists** | Curators can tune stop words, block lists, functional categories without developer intervention | High | DT editable tables + reactive re-run | [Shiny DT editable](https://rstudio.github.io/DT/shiny.html); save edits to reactiveVal, rerun pipeline on change |
| **Blocking vs annotating flags** | Blocking flags (formulas, empty names) stop curation; Annotating flags (mixtures, proprietary) warn but proceed | Medium | Flag type metadata + conditional routing in pipeline | No commercial analog; novel for chemical cleaning |
| **Multi-sheet Excel export** | Data + Audit Trail + Reference Lists + Config + Data Dictionary in one file | Medium | writexl multi-sheet API | Reproducibility: export carries full state for re-import ([data cleaning best practices](https://rebeccabarter.com/blog/2019-03-07_reproducible_pipeline)) |
| **Re-import detection** | Recognize ChemReg exports, hot-load embedded reference lists + pipeline config, skip redundant cleaning | High | Metadata sheet in Excel + detection logic on upload | Session restoration pattern from [datacleanr](https://github.com/the-Hull/datacleanr) R package |
| **CAS-RN rescue pipeline** | Extract CAS from name columns, validate checksums, split multi-CAS cells — domain-specific | Medium | ComptoxR (existing) + pipeline orchestration | No generic tool does this; chemical inventory unique need |
| **Functional use flagging** | Detect "Fragrance", "Flavor", "Surfactant" as non-chemical product categories | Medium | Reference list (EPA ChemExpo or keyword-based) | Chemical domain-specific; OpenRefine has no analog |
| **Post-curation QC** | Re-validate CAS after API resolution, enrich with functional use + safety flags from CompTox | Medium | ComptoxR functional use + safety flag APIs | Closes loop: cleaning → curation → validation |

---

## Anti-Features

Features to explicitly NOT build. These either conflict with design principles or introduce unacceptable complexity.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Fully manual cell-by-cell editing** | Doesn't scale; users with 10K+ rows need batch operations | Provide batch cleaning functions + flag exceptions for review |
| **Drag-and-drop pipeline builder** | High complexity, low ROI for R/Shiny; fixed pipeline is simpler and sufficient | Fixed 21-step pipeline with enable/disable toggles per step |
| **Real-time cleaning as user types** | Confusing; users can't tell what will change until they commit | Preview cleaned data in side-by-side table, apply on button click |
| **AI/ML-powered "smart" cleaning** | Opaque ("why did it change this?"); requires training data; chemical names too domain-specific | Explicit rule-based pipeline with transparent audit trail |
| **Session persistence across browser refresh** | High complexity (requires server-side storage or cookies); defer to future if needed | Export/re-import pattern achieves similar outcome with less complexity |
| **Inline formula editor for custom cleaning rules** | Requires DSL or R code eval; security + UX nightmare | Provide comprehensive reference list editors instead |
| **Version control / branching for cleaning recipes** | Over-engineering for single-user workflow; OpenRefine doesn't do this either | Export operation history as JSON; user manages versions externally if needed |

---

## Feature Dependencies

Visual graph of how features depend on each other:

```
File Upload (existing)
    ↓
Unicode Cleaning (ComptoxR::clean_unicode)
    ↓
CAS Pipeline (normalize → rescue → validate → split)
    ↓
Name Cleaning (terminal phrases → hazards → quality adjectives → formulas)
    ↓
Reference Filters (functional categories → stop words → block list → food names)
    ↓
Audit Trail Export (per-row comment columns)
    ↓
Pre-Curation Summary (counts + flags)
    ↓
Column Tagging (existing)
    ↓
Curation (existing)
    ↓
Post-Curation QC (CAS re-validation + functional use + safety flags)
    ↓
Multi-Sheet Export (data + audit + reference + config + dictionary)
```

**Critical path:** Unicode → CAS → Names → Audit
All cleaning steps depend on audit trail infrastructure (`append_comment()`).

**Optional:** Editable reference lists can be deferred (start with static lists in `cleaning_reference.R`).

---

## MVP Recommendation

Build in 3 increments:

### Phase 1: Core Cleaning (MVP for internal testing)
Prioritize:
1. ✅ **Audit trail infrastructure** (`append_comment()` — all other features depend on this)
2. ✅ **Unicode cleaning** (ComptoxR — easiest, highest ROI per real data analysis)
3. ✅ **CAS pipeline** (normalize → rescue → validate — 14.4% + 2.4% of rows in live data)
4. ✅ **Basic name cleaning** (terminal phrases, hazard warnings, formulas — high impact)
5. ✅ **Summary cards** (counts of changes)
6. ✅ **Before/after preview** (DT with column toggles)

**Defer:** Reference filters, editable lists, multi-sheet export, re-import.

**Why:** Validates pipeline architecture + audit trail pattern. Can test cleaning accuracy before building UI polish.

---

### Phase 2: Reference Filters + Editable Lists (Production-ready cleaning)
Add:
1. ✅ **Static reference lists** (`cleaning_reference.R` — functional categories, stop words, block list, food names)
2. ✅ **Reference filter flagging** (flag, don't remove — 2.5% + 2.2% of rows)
3. ✅ **Editable reference lists UI** (DT editable tables + reactive re-run)
4. ✅ **Blocking vs annotating flag distinction** (visual + routing logic)

**Defer:** Multi-sheet export, re-import.

**Why:** Completes cleaning feature set. Users can now tune reference lists without code changes.

---

### Phase 3: Reproducibility + QC (Research-grade workflow)
Add:
1. ✅ **Multi-sheet Excel export** (data + audit + reference state + config + dictionary)
2. ✅ **Re-import detection** (detect ChemReg export, restore reference lists + skip cleaning if already done)
3. ✅ **Post-curation QC** (CAS re-validation + functional use + safety flags)

**Why:** Closes the reproducibility loop. Users can share cleaned + curated data with full provenance.

---

## Integration with Existing ChemReg Features

| Existing Feature | How Cleaning Integrates | Impact |
|------------------|-------------------------|--------|
| **Data Preview tab** | Unchanged; shows post-detection, pre-cleaning data | None (backward compatible) |
| **Tag Columns tab** | Now receives cleaned data instead of raw data | Better match rates (fewer API misses due to noise) |
| **Run Curation tab** | Unchanged; tiered search operates on cleaned names/CAS | Improved consensus accuracy |
| **Review Results tab** | Gains post-curation QC columns (functional use, safety flags) | Richer metadata for curator decisions |
| **Excel export** | Enhanced to multi-sheet (data + audit + reference + config) | Replaces single-sheet export |

**Gating logic:**
- Clean Data tab unlocks after successful data detection (same as current Tag Columns gating).
- Tag Columns tab unlocks after Clean Data completes (user reviews cleaning results before tagging).
- No changes to existing curation flow gating.

---

## Complexity Assessment

| Feature | LOC Estimate | Risk | Notes |
|---------|--------------|------|-------|
| Audit trail (`append_comment()`) | 50 | Low | Pure function, easy to test |
| Unicode cleaning | 20 | Low | ComptoxR wrapper, already validated |
| CAS pipeline (4 functions) | 200 | Medium | Rescue logic complex (IUPAC comma handling) |
| Name cleaning (8 functions) | 400 | Medium | Hazard regex, terminal phrase heuristics |
| Reference filters (4 functions) | 150 | Low | Keyword matching, straightforward |
| Summary cards | 100 | Low | Count aggregation + Bootstrap cards |
| Before/after preview | 150 | Low | DT column visibility API |
| Editable reference lists | 300 | High | DT editable + reactive re-run + state management |
| Blocking vs annotating flags | 100 | Low | Conditional routing based on flag_type metadata |
| Multi-sheet export | 200 | Medium | writexl multi-sheet API, need data dictionary formatting |
| Re-import detection | 250 | High | Excel metadata sheet parsing + state restoration logic |
| Post-curation QC | 150 | Low | ComptoxR API calls, similar to existing curation |

**Total estimate:** ~2,070 LOC for full feature set (MVP Phase 1 ≈ 800 LOC).

---

## UX Pattern Details

### Audit Trail Display: Child Rows vs Side Panel vs Tooltip

**Options evaluated:**

| Pattern | Pros | Cons | Best For |
|---------|------|------|----------|
| **Expandable child rows** ([DataTables](https://datatables.net/examples/api/row_details.html)) | Keeps context (row visible above details), no lost scroll position, familiar pattern | Increases vertical space when expanded, may push other rows off-screen | Moderate-length audit logs (5-10 transformations per row) |
| **Side panel drawer** ([HighLevel audit logs](https://help.gohighlevel.com/support/solutions/articles/155000006667-audit-logs-introducing-the-new-design-experience)) | Persistent view (doesn't change table layout), arrow keys navigate between rows, rich formatting possible | Context switch (row → panel), horizontal space constraint on small screens | Deep audit logs with before/after values, timestamps, user info |
| **Tooltip on hover** | Minimal UI clutter, instant preview | Text-only (no formatting), disappears on mouse-out, limited space | Very short logs (1-2 line summary) |

**Recommendation for ChemReg:** Start with **child rows** (simpler, standard DT pattern). Upgrade to side panel if users request richer formatting (before/after value comparison, color-coded change types).

**Implementation:**
- DT `row().child()` API creates child row on click
- Format audit log as HTML list: `<ul><li>Unicode: swapped α with .alpha.</li><li>Extraneous parenthesis: (EPA added)</li></ul>`
- Click chevron icon to expand/collapse

---

### Editable Reference Lists: Inline vs Modal vs Separate Page

**Options evaluated:**

| Pattern | Pros | Cons | Best For |
|---------|------|------|----------|
| **Inline editable table** ([DT editable](https://rstudio.github.io/DT/shiny.html)) | Familiar spreadsheet UX, immediate edits, bulk copy-paste | Validation timing (on blur? enter key?), accidental edits, state management | Small lists (< 50 items), single-column data |
| **Modal dialog with form** | Clear workflow (open → edit → save), easy validation, no accidental edits | Extra clicks, context switch | Adding new items, editing multi-field records |
| **Separate "Configure" tab** | Dedicated space, persistent (no modal dismiss), can include instructions | Workflow interruption (leave Clean Data tab → edit → return), risk of forgetting to re-run pipeline | Power users, extensive customization |

**Recommendation for ChemReg:** **Inline editable table** for small lists (stop words, food names, block list). **Modal for adding new items** (avoids inline validation complexity). **Separate tab** only if users need extensive help text or configuration beyond simple lists.

**Implementation:**
- DT editable table via `editable = "cell"` option
- Listen to `input$tableId_cell_edit` event
- Update `reactiveVal()` with edited list
- "Apply Changes" button re-runs pipeline with updated list
- Warning: "Unsaved changes" if user leaves tab with edits pending

---

### Blocking vs Annotating Flags: Visual Design

**Color conventions** ([Baymard](https://baymard.com/blog/validations-vs-warnings), [NN/g](https://www.nngroup.com/articles/errors-forms-design-guidelines/)):

| Flag Type | Color | Icon | Behavior |
|-----------|-------|------|----------|
| **Blocking** | Red (`bg-danger`) | `⛔` or `❌` | Row excluded from curation; user must fix or accept data loss |
| **Annotating** | Yellow/Orange (`bg-warning`) | `⚠️` | Row proceeds to curation; flag stored as metadata for review |
| **Info** | Blue (`bg-info`) | `ℹ️` | FYI only (e.g., "CAS rescued from name column") |

**ChemReg examples:**

| Flag | Type | Why | Example |
|------|------|-----|---------|
| "Name is formula" (H2O, NaCl) | Blocking | Formulas won't match CompTox names; curation will fail | Red row highlight |
| "Empty name and CAS" | Blocking | Nothing to curate | Red row highlight |
| "Name is mixture" (60:40 w/w) | Annotating | Mixtures may match single component or fail; let curator decide | Yellow badge in row |
| "Name is functional use" (Fragrance) | Annotating | May be generic category or actual chemical (e.g., linalool as fragrance) | Yellow badge in row |
| "Proprietary / trade secret" | Annotating | Likely non-chemical but could be ambiguous naming | Yellow badge in row |

**Implementation:**
- Flagging functions return `data.frame` with `flag_type` column: `"blocking"`, `"annotating"`, `"info"`
- UI filters rows: `blocking_rows <- df %>% filter(flag_type == "blocking")`
- Before curation: show count of blocking flags, require user to acknowledge ("X rows will be excluded")
- DT row styling via `formatStyle()`: red background for blocking, yellow for annotating

---

### Multi-Sheet Excel Export: Best Practices

**Sheet structure** ([data organization guide](https://www.tandfonline.com/doi/full/10.1080/00031305.2017.1375989)):

| Sheet Name | Contents | Purpose |
|------------|----------|---------|
| **Data** | Cleaned + curated chemical data | Main output for analysis |
| **Audit_Trail** | Row-by-row transformation log | Provenance tracking |
| **Reference_Lists** | Stop words, block list, functional categories (as exported) | Reproducibility: shows which filters were applied |
| **Pipeline_Config** | Enabled/disabled steps, settings (e.g., CAS checksum strictness) | Reproducibility: full pipeline state |
| **Data_Dictionary** | Column name, description, data type, example values | Metadata for downstream users |
| **README** | File creation date, ChemReg version, contact info | Human-readable header |

**Data Dictionary format:**

| Column_Name | Description | Data_Type | Example | Source |
|-------------|-------------|-----------|---------|--------|
| `chemical_name_clean` | Chemical name after pre-curation cleaning | Character | "acetone" | Cleaned from raw_chem_name |
| `casrn_normalized` | CAS-RN after normalization and validation | Character | "67-64-1" | Validated via ComptoxR |
| `consensus_dtxsid` | Resolved DTXSID from tiered curation | Character | "DTXSID1020001" | CompTox API curation |
| `consensus_status` | Agreement level across tagged columns | Factor | "agree", "disagree", "error" | Consensus classification |
| `functional_use` | EPA functional use category (post-curation) | Character | "solvent; cleaning agent" | CompTox functional use API |
| `audit_trail_name` | All transformations applied to name column | Character | "Unicode: α→.alpha. \| Parens: (ACS)" | Cleaning pipeline |

**writexl implementation:**
```r
wb_list <- list(
  Data = cleaned_curated_df,
  Audit_Trail = audit_df,
  Reference_Lists = bind_rows(
    stop_words = tibble(type = "stop_words", value = stop_words_list),
    block_list = tibble(type = "block_list", value = block_list),
    ...
  ),
  Pipeline_Config = tibble(step = names(pipeline_config), enabled = unlist(pipeline_config)),
  Data_Dictionary = data_dictionary_df,
  README = tibble(info = c("File created:", Sys.time(), "ChemReg version:", "1.3.0", ...))
)
writexl::write_xlsx(wb_list, path = "ChemReg_export.xlsx")
```

---

### Re-Import Detection: Heuristics

**How to detect ChemReg export vs fresh upload:**

| Method | Pros | Cons | Reliability |
|--------|------|------|-------------|
| **Sheet name pattern** | Fast (check `excel_sheets()`), non-invasive | False positives if user manually creates sheets named "Audit_Trail" | 90% |
| **Metadata in README sheet** | Explicit (e.g., `ChemReg_version: 1.3.0`), authoritative | Requires parsing README sheet | 99% |
| **Column name pattern** | Check for `audit_trail_name`, `consensus_dtxsid`, `pipeline_config_*` | Invasive (loads data), slow for large files | 95% |
| **Custom property in Excel metadata** | Most reliable, no sheet pollution | Requires `openxlsx` (writexl doesn't support custom properties) | 100% (if supported) |

**Recommendation:** Combine **README sheet** + **column name pattern** as fallback.

**Workflow on re-import:**
1. User uploads file
2. Check if README sheet exists with `ChemReg_version` key
3. If yes → extract `Reference_Lists` and `Pipeline_Config` sheets, restore to reactiveVals
4. Check if `Data` sheet already has cleaned columns (`chemical_name_clean`, `casrn_normalized`)
5. If yes → skip pre-curation pipeline, jump directly to Tag Columns tab
6. Show modal: "Re-import detected. Restored reference lists: X stop words, Y block list items. Pipeline skipped."

**Edge case:** User edits exported file, re-imports. Solution: hash `Data` sheet content, store in README. On re-import, compare hash. If mismatch → warn "Data modified since export; re-running pipeline."

---

## Sources

### UX Patterns & Data Cleaning Tools
- [OpenRefine Official Site](https://openrefine.org/) — Open-source data cleaning with faceting and undo/redo
- [OpenRefine Undo/Redo Documentation](https://guides.library.unlv.edu/open-refine/undo-redo) — Operation history and JSON export
- [Trifacta Data Wrangling Overview](https://www.softcrylic.com/blogs/trifacta-a-tool-for-the-modern-day-data-analyst/) — Recipe-based transformation UI
- [Data Table Design UX Best Practices](https://www.pencilandpaper.io/articles/ux-pattern-analysis-enterprise-data-tables) — Expandable row patterns
- [Audit Trail UI Pattern (HighLevel)](https://help.gohighlevel.com/support/solutions/articles/155000006667-audit-logs-introducing-the-new-design-experience) — Side drawer with before/after values

### Validation & Error Handling
- [Form Validations vs Warnings (Baymard)](https://baymard.com/blog/validations-vs-warnings) — Blocking errors vs proceed-with-warning pattern
- [NN/g Error Message Guidelines](https://www.nngroup.com/articles/errors-forms-design-guidelines/) — Visual design for errors
- [Building UX for Error Validation](https://medium.com/@olamishina/building-ux-for-error-validation-strategy-36142991017a) — Red/orange/green color conventions

### Reproducibility & Export
- [Reproducible Data Cleaning Guide](https://b-greve.gitbook.io/beginners-guide-to-clean-data/data-modeling/reproducibility) — Document every transformation
- [Creating a Data Cleaning Workflow](https://cghlewis.com/blog/data_clean_02/) — Session info and script export
- [datacleanr R Package](https://github.com/the-Hull/datacleanr) — Interactive + reproducible cleaning with recipe export
- [Multi-Sheet Excel Best Practices](https://www.tandfonline.com/doi/full/10.1080/00031305.2017.1375989) — Data dictionary structure

### R Shiny Implementation
- [DT in Shiny](https://rstudio.github.io/DT/shiny.html) — Editable tables and cell edit events
- [DataTables Child Rows](https://datatables.net/examples/api/row_details.html) — Expandable row details API
- [editbl Package](https://cran.r-project.org/web/packages/editbl/editbl.pdf) — Referenced table pattern for Shiny
- [Progressive Disclosure Pattern](https://ui-patterns.com/patterns/ProgressiveDisclosure) — Reveal information as needed
- [shinymgr Framework](https://journal.r-project.org/articles/RJ-2024-009/) — Tab-based workflow management

### Chemical Inventory Context
- [Chemical Inventory Management Best Practices](https://www.fldata.com/chemical-inventory-management-best-practices) — Data validation and reconciliation
- [Chemical Inventory Software Comparison](https://safetyculture.com/apps/chemical-inventory-software) — Feature landscape for chemical tracking tools
- [Data Cleaning Best Practices 2025](https://clevercsv.com/data-cleaning-best-practices/) — Audit trails and standardization
