# Domain Pitfalls

**Domain:** R/Shiny chemical inventory data cleaning pipeline
**Researched:** 2026-03-04
**Confidence:** MEDIUM

## Critical Pitfalls

### Pitfall 1: Synonym Splitting Breaking IUPAC Names

**What goes wrong:**
Comma-based synonym splitting (`"xylene, dimethylbenzene"`) falsely splits IUPAC names that use commas for locant separation (`"butane, 2,2-dimethyl"`) or stereochemical notation (`"(1R,3R;1R,3S)-compound"`). The live ChemReg dataset has 1,000+ rows with comma-separated synonyms but also contains inverted IUPAC names where the comma is syntactically significant.

**Why it happens:**
IUPAC allows two naming forms: `"2,2-dimethylbutane"` (canonical) and `"butane, 2,2-dimethyl"` (inverted). The inverted form looks identical to a synonym list ([IUPAC nomenclature](https://en.wikipedia.org/wiki/IUPAC_nomenclature_of_organic_chemistry)). Commas also appear in digit-comma-digit patterns (`1,4-dioxane`) and parenthetical stereochemistry descriptors. Naive splitting on all commas destroys these names.

**How to avoid:**
1. **Protect digit-comma-digit patterns**: Don't split within `\d+,\d+` sequences
2. **Protect parenthetical content**: Don't split on commas inside `()`, `[]`, or `{}`
3. **Detect inverted IUPAC form**: If a string matches `^[A-Z][a-z]+,\s+\d` (name followed by comma-space-digit), treat as single name
4. **Prefer semicolons**: Split on semicolons first (least ambiguous), then cautiously on commas
5. **Log all splits**: Audit trail should show what was split and how many parts resulted

**Warning signs:**
- Test dataset shows splits creating 1-character fragments
- Post-split names contain only numbers (`"2,2-dimethyl"` split into `["2", "2-dimethyl"]`)
- CompTox curation shows sudden match rate drop after synonym splitting enabled
- Names like `"propane"` appearing in data that should be `"propane, 2-methyl"`

**Phase to address:**
Phase 3 (Name Cleaning Core) — P3.3: Synonym splitting function must implement protection rules before general deployment. Write 20+ test cases covering edge cases from live data before integration.

---

### Pitfall 2: Reactive Cascade Explosion from Editable Reference Lists

**What goes wrong:**
When a user edits a reference list (stop words, block list, functional categories), the app re-runs the entire 21-step pre-curation pipeline, which triggers tag column invalidation, which cascades to curation invalidation, which forces Review Results re-render, which triggers Excel export cache invalidation. A single stop-word addition causes 5-10 seconds of re-computation and UI lock.

**Why it happens:**
Shiny's reactive programming model follows the principle that if A depends on B, changing B invalidates A ([Mastering Shiny Ch. 15](https://mastering-shiny.org/reactivity-objects.html)). Reference lists feed into pre-curation → pre-curation feeds into tagged data → tagged data feeds into curation results. Without explicit isolation, changing reference data creates a reactive chain that re-computes everything downstream. The issue compounds because `withProgress()` blocks the reactive context, preventing concurrent user actions during re-computation ([Mastering Shiny Ch. 8](https://mastering-shiny.org/action-feedback.html)).

**How to avoid:**
1. **Debounce reference edits**: Use `shinyjs::delay()` or `debounce()` to batch rapid edits into a single re-run trigger
2. **Add explicit "Apply Changes" button**: Don't auto-rerun on every keystroke in editable reference tables — let users stage changes then commit
3. **Use `isolate()` for display**: UI components showing pipeline results should use `isolate()` to read data without taking reactive dependencies
4. **Cache intermediate results**: Store pre-curation results in a `reactiveVal()` that only invalidates when reference data explicitly changes and user confirms
5. **Show diff preview**: Before re-running pipeline, show user how many rows will be affected by the reference list change

**Warning signs:**
- UI becomes unresponsive for multiple seconds after reference list edit
- Progress bar appears mid-typing in editable table
- Browser shows "Shiny is busy" gray overlay frequently during reference editing
- User reports in testing: "I can't edit the list without the app freezing"

**Phase to address:**
Phase 4 (Reference Data Filters) — P4.1/P4.2/P4.3. Implement staged editing pattern with explicit "Apply" action before wiring reference tables into the reactive graph. Test with 50+ rapid edits to verify debouncing works.

---

### Pitfall 3: App.R Crossing 3,000 Lines Without Modularization

**What goes wrong:**
`app.R` already at 2,275 lines will grow to 3,000+ with "Clean Data" tab logic, reference list editing UI, audit trail display, and multi-sheet export configuration. File becomes unmaintainable — 10+ minute context load time for LLM assistance, difficult to trace reactive dependencies, high merge conflict probability, and impossible to test in isolation.

**Why it happens:**
Shiny's single-file app pattern (`app.R`) encourages putting all UI and server logic in one place ([Engineering Production-Grade Shiny Apps](https://engineering-shiny.org/structuring-project.html)). As features accumulate (data preview, detection, tagging, curation, resolution, now cleaning), the file grows linearly. Without explicit modularization ([Mastering Shiny Ch. 19](https://mastering-shiny.org/scaling-modules.html)), developers add new tabs by copy-pasting existing tab patterns, each bringing 150-300 lines of UI + server logic.

**How to avoid:**
1. **Extract tab logic into modules NOW**: Before adding "Clean Data" tab, create `R/modules/mod_data_preview.R`, `mod_tag_columns.R`, `mod_review_results.R`. Each module exports `*_ui()` and `*_server()` functions
2. **Use R package structure**: Move all R code to `R/` directory (already partially done), use `devtools::load_all()` instead of `source()` ([Mastering Shiny Ch. 20](https://mastering-shiny.org/scaling-packaging.html))
3. **One reactiveValues per module**: Don't use a global `data_store` — each module should have its own state and communicate via return values
4. **Limit app.R to orchestration**: Target app.R under 500 lines — just theme, layout, and module calls
5. **Refactor before adding**: Don't add 800 lines of cleaning UI to existing 2,275-line file — refactor first, then add new module

**Warning signs:**
- Scrolling through `app.R` takes 5+ seconds
- Search for function definition requires Ctrl+F + manual inspection of 3+ locations
- Merge conflicts on every parallel feature branch
- "Which observer handles X?" requires 20+ minutes of tracing
- New developer ramp-up time exceeds 1 week

**Phase to address:**
Before Phase 1 (Foundation) starts. Create technical debt repayment phase: extract existing 6 tabs into modules (`mod_data_preview`, `mod_detection_info`, `mod_raw_data`, `mod_tag_columns`, `mod_run_curation`, `mod_review_results`). Verify all existing functionality works before proceeding to pre-curation pipeline. Budget 8-12 hours for this refactoring.

---

### Pitfall 4: Progress Tracking Lies in Multi-Step Pipeline

**What goes wrong:**
21-step pre-curation pipeline shows progress bar incrementing linearly (5% per step), but step 17 (`split_multi_cas()`) takes 40% of total runtime on datasets with extensive multi-CAS rows. Progress bar sits at 80% for 30 seconds, then jumps to 100% instantly. Users think the app froze and kill the browser tab. Post-curation functional use enrichment API calls time out silently, progress bar completes, but data is incomplete.

**Why it happens:**
`withProgress()` defaults to equal-weight steps ([Shiny Progress Documentation](https://shiny.posit.co/r/articles/build/progress/)). Setting `incProgress(amount = 1/21)` assumes each step takes 1/21 of runtime, but: (1) steps have vastly different complexity (unicode cleaning is instant, CAS splitting is O(n*m) for n rows with m CAS numbers each), (2) API calls have variable latency (exact match: 100ms, starts-with search: 5-10s), (3) nested `withProgress()` for curation tiers [can create visual issues](https://rstudio.github.io/shiny/reference/withProgress.html) where second-level bars overlap first-level bars in the UI.

**How to avoid:**
1. **Measure empirical step weights**: Run pipeline on representative data (1,000+ rows), record time per step, calculate proportional weights. Use `incProgress(amount = step_weight)` instead of equal fractions
2. **Show absolute time estimates**: Use `detail = "Estimated X seconds remaining"` based on measured rates ([withProgress documentation](https://rdrr.io/cran/shiny/man/withProgress.html))
3. **Separate fast vs slow steps**: Group instant operations (unicode, canonicalization) into one progress tick; show individual ticks for slow operations (CAS splitting, API calls)
4. **Timeout handling**: Wrap API calls in `tryCatch()` with explicit timeout, show "X of Y API calls completed" message instead of hanging progress
5. **Use Progress reference class for async**: If post-curation API calls are batched asynchronously, `withProgress()` won't work — use `Progress$new()` reference class instead

**Warning signs:**
- User testing: "I thought it crashed" (progress bar stationary for 10+ seconds)
- Progress bar jumps from 30% to 100% in one update
- Estimated time remaining shows "5 seconds" for 30 seconds straight
- Excel export completes but post-curation functional use columns are empty (silent timeout)

**Phase to address:**
Phase 1 (Foundation) P1.1 through Phase 6 (Post-Curation QC). Before implementing `run_pre_curation()` orchestrator, create `estimate_step_duration()` helper that benchmarks each step on test dataset. Use those durations to calculate `incProgress()` weights. Re-benchmark after Phase 5 name cleaning functions are integrated (performance may change). Add timeout tests for Phase 6 API calls.

---

### Pitfall 5: Audit Trail Columns Causing Excel Export Failure

**What goes wrong:**
After running pre-curation pipeline with all 21 steps, each row has 2-5 transformations logged in `name_comment` and `casrn_comment` columns. Pipe-separated strings grow to 500-1,000+ characters. When exporting to Excel via `writexl::write_xlsx()`, strings exceeding 32,767 characters (Excel cell limit) cause silent truncation or export failure. Wide dataframes (original columns + curated columns + match_type + consensus columns + 2 comment columns + post-curation flags) hit Excel's 16,384 column limit when functional use enrichment adds 10+ category columns.

**Why it happens:**
Excel .xlsx format has hard limits: 32,767 characters per cell ([Excel 31-character sheet name limit](https://www.keynotesupport.com/excel-basics/worksheet-names-characters-allowed-prohibited.shtml)), 16,384 columns per sheet, 1,048,576 rows per sheet ([writexl documentation](https://cran.r-project.org/web/packages/writexl/writexl.pdf) does not enforce these limits — it writes the file, but Excel may refuse to open it or silently corrupt data). Audit trail comments concatenate messages with pipe separator: `"Unicode detected: swapped α with .alpha. | Extraneous parenthesis: (EPA added) | Name is functional use: surfactant"`. Each transformation adds 50-200 characters. After 21 steps, a heavily-transformed row can exceed the cell limit. Post-curation enrichment (functional use categories, safety flags) adds 5-15 new columns, pushing wide datasets over the column limit.

**How to avoid:**
1. **Truncate comment cells at 30,000 characters**: Add `truncate_long_strings()` helper before export, append `"... [truncated]"` suffix
2. **Separate audit trail sheet**: Don't put comments in main data sheet — create dedicated "Audit Trail" sheet with row_id → comments mapping, one comment per row
3. **Column count check**: Before export, count `ncol(df)` — if >16,000, split into multiple sheets ("Data_part1", "Data_part2") or omit post-curation enrichment columns from main sheet (put in separate "Enrichment" sheet)
4. **Compression for large datasets**: Use `compression = 9` parameter in `write_xlsx()` (not documented in standard CRAN docs but supported by underlying libxlsxwriter)
5. **Warning notification**: If audit trail strings approach 25,000 characters or column count >15,000, show `showNotification()` warning: "Large export may not open in Excel. Consider CSV export instead."

**Warning signs:**
- Excel shows "file corrupted" error when opening exported .xlsx
- Opening exported file shows `#####` in comment columns (column too narrow, but actually indicates character overflow)
- Exported file missing last 50 columns (silent truncation at column limit)
- Export takes 30+ seconds for 1,000 row dataset (indicates wide dataframe)
- RStudio console shows `write_xlsx()` warning about character encoding (indicates non-ASCII in very long strings)

**Phase to address:**
Phase 2 (CAS-RN Pipeline) P2.1 onward. Every function that calls `append_comment()` should also implement `truncate_audit_comment()` check. By Phase 6 (Post-Curation QC) P6.4 export, add `validate_excel_limits()` helper that checks row/column/cell constraints before calling `write_xlsx()`. Create "Audit Trail" sheet architecture in P1.1 audit infrastructure design.

---

### Pitfall 6: Re-Import Detection Overwriting User Edits

**What goes wrong:**
User uploads ChemReg export, app detects embedded state (column tags, pipeline config, reference lists), auto-restores everything. User had edited stop-word list in Excel before re-upload intending to use custom list, but app ignores the Excel edits and loads the embedded reference lists from hidden metadata sheet. User re-tags columns with different mappings, runs curation, then clicks "Re-upload file" to fix a data issue — app resets tags to original embedded state, wiping out the new tag configuration.

**Why it happens:**
Re-import detection is designed to preserve state across sessions, but the feature doesn't distinguish between "initial load of previous export" vs. "re-upload after user made external changes" vs. "re-upload after user made in-app changes." State restoration logic in `observeEvent(input$file_upload)` reads embedded metadata and immediately calls `updateSelectInput()` / `data_store$tags <- embedded_tags`, overwriting any in-session user modifications. The [Shiny file input documentation](https://recology.info/2024/03/shiny-file-inputs/) notes that file input resets when user uploads a new file, but doesn't address state collision between embedded metadata and current reactive state ([R-bloggers on state restoration](https://www.r-bloggers.com/2019/06/shiny-application-with-modules-saving-and-restoring-from-rds/)).

**How to avoid:**
1. **Detect state divergence**: Before auto-restoring, compare embedded state vs. current `data_store` state. If current state is non-default (tags exist, reference lists modified), show modal: "This file contains previous settings. Restore them or keep current settings?"
2. **Explicit "Load State" button**: Don't auto-restore — show notification "This file was exported from ChemReg. Click 'Restore Settings' to load column tags and reference lists." Let user decide
3. **Track modification timestamps**: Embed `exported_at` timestamp in metadata sheet. If re-uploading a file exported 5 minutes ago but user has made 20 reference list edits since, prioritize in-session edits
4. **Show state diff preview**: Modal shows side-by-side comparison: "Embedded tags: CAS → col_A, Name → col_B | Current tags: CAS → col_C, Name → col_D"
5. **Preserve external edits**: If user edited the data sheet in Excel (added rows, changed values), detect this by comparing row counts / checksums, and don't restore old state — treat as new upload

**Warning signs:**
- User testing: "I changed the tags but they got reset when I re-uploaded"
- User reports reference list edits disappearing after file re-upload
- Support requests: "How do I edit the stop-word list? I changed it in Excel but the app ignores my changes"
- Embedded state timestamp is 1 hour old but user has been working in the app for 2 hours (indicates stale state restoration)

**Phase to address:**
v1.3 Design Phase (before implementation starts). Define state restoration UX: auto-restore on initial upload, explicit confirmation on subsequent uploads, preservation of in-session modifications. Implement in Phase 1 P1.1 alongside audit trail infrastructure (both deal with state management). Write 10+ test scenarios for state collision cases before coding.

---

### Pitfall 7: Flag Behavior Confusion (Blocking vs Annotating)

**What goes wrong:**
Pre-curation flags functional category names ("fragrance", "surfactant") as non-chemical, setting them to `NA` and blocking curation. User expected these to be annotated but still searchable because they want to identify what functional use category the entry belongs to. Post-curation safety flags are informational-only but displayed identically to pre-curation blocking flags in the UI. User doesn't understand why some flags stop curation (formula-as-name, stop words) while others don't (functional categories, food names, mixture ratios).

**Why it happens:**
The PRE_POST_CURATION_PLAN.md specifies "flag, don't remove" for reference data filters (functional categories, food names, stop words), but doesn't define whether flagged rows should: (1) be excluded from curation entirely, (2) be sent to curation with a warning annotation, or (3) be visually marked but processed normally. The original Python `clean_chems.py` removed flagged entries outright; the R port switches to flagging for conservativeness, but the intended user workflow isn't specified. Research on [form validation UX](https://www.smashingmagazine.com/2022/08/error-messages-ux-design/) and [validation vs warnings patterns](https://baymard.com/blog/validations-vs-warnings) shows users perceive all flags as errors unless explicitly distinguished. [Alert fatigue research](https://www.splunk.com/en_us/blog/learn/alert-fatigue.html) shows that too many warnings cause users to ignore all of them.

**How to avoid:**
1. **Explicit flag taxonomy**: Define 3 flag types with visual distinction:
   - **BLOCKING** (red badge, stops curation): formula-as-name, empty name after cleaning, invalid CAS with no name
   - **WARNING** (yellow badge, proceeds to curation with annotation): functional categories, food names, mixture ratios, stop words
   - **INFO** (blue badge, post-curation only): safety flags, functional use enrichment, unicode detected
2. **Per-flag-type filtering UI**: In "Clean Data" tab, show 3 separate filter sections: "Blocking Flags (X rows — must resolve before curation)", "Warning Flags (Y rows — will proceed with annotation)", "Info Flags (Z rows — reference only)"
3. **Inline flag explanation**: Tooltip or expandable card explaining what each flag means and what action is required: "Formula-as-name: This entry is a molecular formula, not a chemical name. It will not be sent to curation. Edit the name or mark for manual review."
4. **Flag override**: Allow user to override blocking flags: "Proceed with curation anyway" checkbox converts BLOCKING → WARNING for selected rows
5. **Graduated disclosure**: Don't show all flags upfront — default to showing only BLOCKING flags, with "Show warnings (Y)" and "Show info (Z)" expandable sections

**Warning signs:**
- User testing: "Why did curation skip these rows?" (referring to flagged-but-not-blocked rows)
- Support requests: "How do I turn off functional category filtering? I want to search these anyway."
- User clicks "Run Curation" expecting 1,000 rows, only 850 get curated, no explanation why 150 were excluded
- Post-curation safety flags shown in red (blocking visual style) but don't actually block anything, causing confusion

**Phase to address:**
v1.3 Design Phase — before Phase 1 implementation. Define flag taxonomy document with examples. Implement 3-tier flag system in Phase 1 P1.1 (audit trail infrastructure includes flag type tracking). UI distinction in Phase 4 (Reference Data Filters) when flags are first introduced. Create 15+ user testing scenarios covering flag interpretation before Phase 4 ships.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Storing audit comments in main dataframe columns | Simple to implement, no separate data structure needed | Bloats dataframe, hits Excel export limits, makes column selection complex | Acceptable for MVP if dataset <500 rows and <10 transformations per row; must migrate to separate audit trail sheet before production |
| Using `source()` instead of R package structure | No refactoring required, works immediately | Can't use `devtools::test()`, `R CMD check`, or namespace isolation; file loading order bugs; hard to distribute as reusable module | Never acceptable for apps >1,000 lines — refactor before adding v1.3 features |
| Global `data_store` reactiveValues object | Easy to access from any observer, no parameter passing needed | Impossible to trace data dependencies, reactivity debugging nightmare, can't test server logic in isolation | Acceptable only during prototype phase; must refactor to module return values before v1.3 milestone |
| Auto-restoring state on re-import without user confirmation | Seamless UX when it works correctly | Silently overwrites user modifications, no recourse if wrong state loaded | Never acceptable — always show confirmation modal for state restoration |
| Equal-weight progress bar steps | Trivial to implement (`incProgress(1/n)`), no benchmarking needed | User perceives app as frozen when stuck on slow step | Acceptable for pipelines where all steps take <2 seconds each; must use weighted progress if any step >5 seconds |
| Hard-coded reference lists in R/cleaning_reference.R | No CSV parsing, no file I/O, guaranteed available | Lists become stale, requires code change + redeployment to update, can't be customized per deployment | Acceptable for MVP; must add CSV-based loading + UI editing before production deployment |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| writexl multi-sheet export | Passing dataframe list with unvalidated sheet names (special characters, >31 chars, "History" reserved word) | Sanitize sheet names before export: `make.names(names(sheet_list), unique=TRUE) %>% substr(1,31) %>% str_replace_all("[\\[\\]:*?/\\\\]", "_")`. Test with edge case names: "Data (2024)", "History", "Very_Long_Name_That_Exceeds_Limit". [Excel sheet naming rules](https://bettersolutions.com/excel/worksheets/naming.htm) |
| ComptoxR API calls in pipeline | No timeout handling — API latency spikes cause `withProgress()` to hang indefinitely | Wrap API calls in `possibly(..., otherwise = NA, quiet=FALSE)` with `purrr::safely()`. Set global timeout via `httr::timeout(30)` in .Rprofile. Show "X/Y completed" message with failed DTXSIDs logged. |
| DT editable tables for reference lists | Using `input$tableId_cell_edit` to update reactiveValues directly in observer → reactive loop when re-rendering DT with updated data | Use `DT::replaceData()` or `dataTableProxy()` to update table without invalidating the input binding ([Using DT in Shiny](https://rstudio.github.io/DT/shiny.html)). Debounce edits with `shinyjs::delay(2000, ...)` before triggering downstream pipeline re-run. |
| Shiny modules with namespace isolation | Forgetting `ns()` wrapper on input IDs in module UI, causing inputs to not connect to module server | Every `inputId` in module UI must use `ns("id")`. Every output in module server must use bare `"id"` (namespace applied by `moduleServer()`). Test by creating 2 instances of same module — if they interfere, namespace is broken. [Shiny Modules documentation](https://shiny.posit.co/r/articles/improve/modules/) |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Re-running entire 21-step pipeline on reference list edit | UI freezes for 5-10 seconds per edit, progress bar appears mid-typing, browser "not responding" | Implement "Apply Changes" button pattern, cache intermediate results with `bindCache()`, debounce edits with `debounce(reactiveVal(...), millis=2000)` | >500 rows AND >3 reference list edits per session |
| Wide dataframe with 50+ columns in DT::renderDataTable | Initial render takes 10+ seconds, scrolling is janky, column hiding UI unresponsive | Use `options = list(deferRender = TRUE, scroller = TRUE, scrollX = TRUE, scrollY = "600px")` for large tables ([Shiny Data Tables Guide](https://www.datanovia.com/learn/tools/shiny-apps/interactive-features/data-tables.html)). Default to showing only 15 key columns, hide others with `columnDefs = list(list(visible=FALSE, targets=c(16:50)))`. | >30 columns OR >1,000 rows |
| Audit trail comment strings >10,000 characters | DT rendering slows to 1-2 seconds per page change, Excel export takes 30+ seconds, memory usage spikes | Truncate displayed comments to 500 chars with "... (show full)" expandable link. Store full comments in separate sheet on export. Use `DT::formatStyle()` with `textOverflow: 'ellipsis'`. | Average comment length >5,000 characters OR >20 transformations per row |
| Reactive observers re-rendering outputs on every keystroke in search box | CPU spikes to 100%, app becomes unresponsive during typing, outputs flicker | Use `debounce(reactive(input$search), millis=500)` instead of reading `input$search` directly. For expensive outputs, use `req(nchar(input$search) >= 3)` to skip until minimum length reached ([Shiny Reactive Programming Guide](https://www.datanovia.com/learn/tools/shiny-apps/fundamentals/reactive-programming.html)). | Search triggers >5 outputs AND dataset >500 rows |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Embedding CompTox API key in exported Excel metadata sheet | API key visible to anyone opening the file, potential quota abuse if key is extracted and reused | Never export API keys. Instead, export API call results (DTXSIDs, names, CAS) as data. Embed only non-sensitive config: pipeline step flags, reference list versions, thresholds. If API key is needed for re-curation, require user to re-enter it in app. |
| Allowing arbitrary sheet names in Excel export from user input | Malicious user provides sheet name with formula injection payload (`=cmd|'/c calc'!A1`), Excel executes on open | Sanitize all user-provided strings before using as sheet names: strip `=+-@`, limit to alphanumeric + underscore + hyphen, max 31 chars. Use `make.names()` + whitelist regex: `str_replace_all(name, "[^A-Za-z0-9_-]", "_")`. |
| Trusting embedded metadata in re-imported ChemReg exports without validation | User manually edits metadata sheet, embeds malicious R code in serialized reference list, `readRDS()` executes code on load | Never use `readRDS()` on user-provided data. Store reference lists as plain CSV in metadata sheet (not serialized R objects). Validate all loaded metadata against schema before applying: check column names, data types, value ranges. If validation fails, discard embedded state and treat as fresh upload. |
| Displaying raw user-uploaded data in DT without sanitization | User uploads CSV with `<script>alert('XSS')</script>` in chemical name field, DT renders HTML, script executes in browser | Use `escape = TRUE` in `DT::datatable()` (default in newer versions, but verify). Never set `escape = FALSE` on user-provided columns. Only use `escape = FALSE` for app-generated HTML like resolution dropdowns on known-safe column. |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Showing all 21 pre-curation steps in progress bar with technical function names | User sees "Canonicalizing strings (step 3/21)" and doesn't understand what's happening or why it's slow | Group steps into 5-6 user-facing stages: "Fixing encoding issues", "Cleaning chemical names", "Validating CAS numbers", "Checking reference databases", "Finalizing". Show stage name + progress within stage. |
| Flagging 40% of uploaded rows with 5+ different flag types | User overwhelmed, doesn't know where to start, abandons workflow ("flag fatigue") | Default view: show only BLOCKING flags (must fix to proceed). Collapsible sections for WARNING flags (grouped by type: "15 functional categories", "8 formulas") and INFO flags (post-curation only). Provide "Accept all warnings" bulk action. [Guidelines on inline validation](https://www.smashingmagazine.com/2022/09/inline-validation-web-forms-ux/) |
| Re-import state restoration without explanation | App auto-fills column tags and reference lists when user uploads file, no indication why or how to undo | Show prominent notification: "This file was previously exported from ChemReg. Column tags and settings have been restored. [Undo] [Dismiss]". Undo button clears embedded state and treats as fresh upload. Notification persists until dismissed. |
| DT editable reference list with no save confirmation | User edits 10 rows in stop-word table, accidentally navigates away from tab, edits lost because no "Apply" was clicked | Add "You have unsaved changes" warning if user navigates away from reference list tab with uncommitted edits. Show visual indicator (orange dot on tab title) when edits are staged but not applied. Require explicit "Apply Changes" or "Discard" action. |
| Excel export completing silently with truncated data | User downloads file, Excel opens with `#####` in columns or missing columns, no indication that data was truncated | Before export, check limits. If exceeded, show modal: "Your data is too large for Excel format (50 columns, 16k limit is 16,384). Truncated columns saved to 'Additional_Data.csv'. [Download Both] [Cancel]". Alternatively, offer CSV export for datasets exceeding limits. |
| Progress bar stuck at 95% for 30 seconds during API calls | User thinks app crashed, kills browser tab, loses work | Use detailed progress messages: "Validating chemicals with CompTox API... 145/200 completed (estimated 25 seconds remaining)". If API call batch is slow, show per-item progress, not just overall bar. For post-curation enrichment, show "Optional step — may take 1-2 minutes" with Skip button. |

## "Looks Done But Isn't" Checklist

- [ ] **Synonym splitting**: Often missing IUPAC comma protection — verify `"butane, 2,2-dimethyl"` doesn't split into two names
- [ ] **Editable reference lists**: Often missing debounce/apply button — verify editing stop-word list 5 times rapidly doesn't trigger 5 pipeline re-runs
- [ ] **Excel export**: Often missing cell/column limit checks — verify 1,000-row dataset with 20-step audit trail exports without truncation or corruption
- [ ] **Progress tracking**: Often missing weighted steps — verify 21-step pipeline doesn't appear frozen during slow CAS splitting step
- [ ] **Re-import detection**: Often missing state conflict resolution — verify re-uploading file after in-app tag changes prompts user instead of silently overwriting
- [ ] **Flag taxonomy UI**: Often missing visual distinction between blocking/warning/info — verify user can tell which flags require action vs. which are informational
- [ ] **Reactive isolation**: Often missing `isolate()` on display outputs — verify editing reference list with "Apply" button doesn't auto-rerun pipeline until button clicked
- [ ] **Module namespacing**: Often missing `ns()` wrappers — verify creating 2 instances of reference list editor module doesn't cause input ID collision
- [ ] **Audit trail export**: Often missing separate sheet architecture — verify comment columns in main data sheet are truncated to 30k chars and full trail is in separate sheet
- [ ] **API timeout handling**: Often missing fallback for failed calls — verify CompTox API timeout on 5/100 chemicals doesn't cause entire post-curation step to fail silently

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Synonym splitting broke IUPAC names | MEDIUM | Roll back to pre-split data if audit trail preserved original. Manually review split rows (filter for single-char fragments or digit-only names). Add IUPAC protection rules to `split_synonyms()`, re-run on original data. Test with [OPSIN parser](https://opsin.ch.cam.ac.uk/) to validate names post-split. |
| Reactive cascade from reference list edit | LOW | Add `isolate()` to downstream observers. Wrap reference list reactiveVal in `debounce(..., millis=2000)`. Add explicit "Apply Changes" actionButton, move pipeline trigger from `observeEvent(input$ref_table_cell_edit)` to `observeEvent(input$apply_button)`. Test by editing 10 rows rapidly. |
| App.R >3,000 lines | HIGH (8-12 hours) | Extract each tab into module: `mod_data_preview.R`, `mod_tag_columns.R`, etc. Create `R/modules/` directory. Replace tab UI/server code in `app.R` with `mod_*_ui(id)` and `mod_*_server(id, data_store)`. Test each module in isolation with `testServer()`. Verify reactive dependencies still work. |
| Progress bar lying about time remaining | LOW | Benchmark each pipeline step on 1,000-row test dataset. Calculate proportional weights: `step_weight <- measured_time / sum(all_times)`. Replace `incProgress(1/21)` with `incProgress(amount=step_weights[i])`. Add absolute time estimates: `detail = paste("~", round(remaining_time), "seconds remaining")`. |
| Audit trail exceeding Excel cell limit | MEDIUM | Implement separate "Audit_Trail" sheet in export. Main data sheet includes only row_id + truncated_comment (500 chars max). Audit sheet has columns: row_id, step_number, step_name, original_value, transformed_value, reason. User can VLOOKUP row_id to see full history. Add `validate_excel_limits()` pre-export check. |
| Re-import overwriting user edits | LOW | Add state divergence detection: `if (!identical(embedded_tags, data_store$tags))` show modal. Modal includes side-by-side comparison, radio buttons: "Restore embedded settings" vs "Keep current settings" vs "Merge (keep current tags, restore reference lists)". Embed modification timestamp, compare to session start time. |
| Flag behavior confusion | MEDIUM | Define flag taxonomy enum: `BLOCKING`, `WARNING`, `INFO`. Update all flagging functions to set `flag_type` column. Create `filter_flagged_rows()` helper that filters by type. UI shows 3 separate accordion sections with counts. Add tooltip explanation per flag. Create flag override mechanism: checkbox converts BLOCKING→WARNING for selected rows. |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Synonym splitting breaking IUPAC names | Phase 3 (P3.3) | Test with 20+ edge cases: inverted IUPAC, digit-comma-digit, parenthetical stereochemistry. Verify no single-char fragments after split. Check CompTox match rate doesn't drop post-split. |
| Reactive cascade explosion | Phase 4 (P4.1/P4.2/P4.3) | Edit reference list 10 times in 5 seconds. Verify only 1 pipeline re-run (or 0 if "Apply" not clicked). Check browser performance profiler for reactive chain length. |
| App.R crossing 3,000 lines | **Before Phase 1 (refactor first)** | Extract 6 existing tabs into modules. Verify `app.R` <500 lines. Create `tests/testthat/test-modules.R` with `testServer()` cases for each module. Check all existing UI still renders. |
| Progress tracking lies | Phase 1 (P1.1) + Phase 6 (P6.1) | Benchmark all steps on 1,000-row test dataset. Calculate weights. Verify progress bar doesn't pause >5 seconds on any step. Test with slow API endpoint (throttled CompTox sandbox). |
| Audit trail Excel limits | Phase 1 (P1.1 audit infrastructure) + Phase 6 (P6.4 export) | Create test dataset with 50-step transformation history per row. Verify export succeeds. Open in Excel, verify no truncation. Check file size <50MB for 1,000 rows. |
| Re-import overwriting edits | Phase 1 (P1.1 state management) | Upload ChemReg export. Edit tags and reference lists in app. Re-upload same file. Verify modal appears with state conflict options. Test "keep current" preserves in-app edits. |
| Flag behavior confusion | **v1.3 Design Phase** + Phase 1 (P1.1 flag taxonomy) | Define BLOCKING/WARNING/INFO in design doc. Implement 3-color badge system. User testing: "Which flags must you fix before curation?" Verify 80%+ correct answer rate. Test with 15+ flag interpretation scenarios. |

## Sources

**Shiny Reactivity & Progress:**
- [Engineering Production-Grade Shiny Apps - Common Application Caveats](https://engineering-shiny.org/common-app-caveats.html)
- [Mastering Shiny - User feedback](https://mastering-shiny.org/action-feedback.html)
- [Mastering Shiny - Reactive building blocks](https://mastering-shiny.org/reactivity-objects.html)
- [Shiny Progress indicators](https://shiny.posit.co/r/articles/build/progress/)
- [withProgress documentation](https://rdrr.io/cran/shiny/man/withProgress.html)

**Shiny Modules & Code Organization:**
- [Mastering Shiny - Shiny modules](https://mastering-shiny.org/scaling-modules.html)
- [Engineering Production-Grade Shiny Apps - Structuring Your Project](https://engineering-shiny.org/structuring-project.html)
- [Mastering Shiny - Packages](https://mastering-shiny.org/scaling-packaging.html)
- [Shiny - Modularizing Shiny app code](https://shiny.posit.co/r/articles/improve/modules/)

**Editable Tables:**
- [Shiny Data Tables: Complete DT Package Guide](https://www.datanovia.com/learn/tools/shiny-apps/interactive-features/data-tables.html)
- [Using DT in Shiny](https://rstudio.github.io/DT/shiny.html)
- [rhandsontable](https://jrowen.github.io/rhandsontable/)
- [Better Than Excel: Use These R Shiny Packages Instead](https://www.appsilon.com/post/forget-about-excel-use-r-shiny-packages-instead)

**Excel Export:**
- [writexl CRAN documentation](https://cran.r-project.org/web/packages/writexl/writexl.pdf)
- [Learn How To Export R Data Frames To Multiple Excel Sheets](https://statistics.arabpsychology.com/r-export-data-frames-to-multiple-excel-sheets/)
- [Excel Worksheets - Naming](https://bettersolutions.com/excel/worksheets/naming.htm)
- [Rules for Naming Microsoft Excel Worksheets](https://www.keynotesupport.com/excel-basics/worksheet-names-characters-allowed-prohibited.shtml)

**UX & Validation:**
- [Designing Better Error Messages UX](https://www.smashingmagazine.com/2022/08/error-messages-ux-design/)
- [A Complete Guide To Live Validation UX](https://www.smashingmagazine.com/2022/09/inline-validation-web-forms-ux/)
- [Form Usability: Validations vs Warnings – Baymard](https://baymard.com/blog/validations-vs-warnings)
- [Preventing Alert Fatigue](https://www.splunk.com/en_us/blog/learn/alert-fatigue.html)

**State Management & Re-import:**
- [Shiny application (with modules) – Saving and Restoring from RDS](https://www.r-bloggers.com/2019/06/shiny-application-with-modules-saving-and-restoring-from-rds/)
- [Shiny file inputs](https://recology.info/2024/03/shiny-file-inputs/)
- [R Shiny and audit trail for user data](https://forum.posit.co/t/r-shiny-and-audit-trail-for-user-data/50364)

**Chemical Name Parsing:**
- [OPSIN: Open Parser for Systematic IUPAC Nomenclature](https://opsin.ch.cam.ac.uk/)
- [IUPAC nomenclature of organic chemistry - Wikipedia](https://en.wikipedia.org/wiki/IUPAC_nomenclature_of_organic_chemistry)
- [IUPAC Blue Book chapter P-1](https://iupac.qmul.ac.uk/BlueBook/P1.html)

---
*Pitfalls research for: R/Shiny chemical inventory data cleaning pipeline*
*Researched: 2026-03-04*
