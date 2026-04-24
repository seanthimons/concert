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

---

# v1.9 Pitfalls: Numeric Parsing, Unit Harmonization, Schema Mapping

**Domain:** Adding numeric result parsing, unit harmonization, and ToxVal schema output to existing ChemReg R package
**Milestone:** v1.9 Number and Unit Coercion Harmonization
**Researched:** 2026-04-14
**Sources:** sswqs_curation.R (EPA production script, HIGH confidence), ecotox_build.R (ComptoxR unit tables, HIGH confidence), PROJECT.md (ChemReg architecture, HIGH confidence)

---

## Critical Pitfalls (v1.9)

### v1.9 Pitfall 1: Fortran-Style Exponent Injection Before as.numeric()

**What goes wrong:** Source data from EPA bulk spreadsheets and regulatory databases contains values in malformed exponent formats: `4.56+02`, `6.90E+0.1`, `5.0 e-9`, `5x10^-9`. Calling `as.numeric()` on any of these returns `NA` silently — no warning, no error, the row disappears.

**Why it happens:** Fortran scientific notation is valid output from legacy EPA data systems. R's `as.numeric()` parses only standard `e`-notation. The failure is invisible when wrapped in `purrr::safely()` or when a downstream `filter(!is.na(parsed_value))` silently drops failed rows.

**Evidence from sswqs_curation.R (lines 769–782):**
```r
result = case_when(
  result == '6.90E+0.1' ~ '6.90E+01',           # one-off fix for malformed exponent
  .default = result
),
result = str_replace_all(result, "x10\\^?", "e"),       # "5x10^-9" -> "5e-9"
result = str_replace(result, "(?<=[0-9])(?<!e)([+-])(?=0\\d(?!\\d))", "e\\1"),  # "4.56+02" -> "4.56e+02"
result = str_remove_all(result, "[[:space:]]"),           # "5.0 e-9" -> "5.0e-9"
```

**Consequences:** Benchmark values silently become NA. `filter(!is.na(parsed_value))` drops legitimate data rows. Export row count is lower than source with no audit trail entry explaining the loss.

**Prevention:**
- Apply the full normalization chain (whitespace removal, `x10^` replacement, Fortran-exponent regex) BEFORE `as.numeric()`, not after.
- Track `num_bool = !is.na(parsed_value)` as a diagnostic flag and surface parse-failure counts in the UI before the user advances past the parsing step.
- Regression test vector: `"4.56+02"`, `"6.90E+0.1"`, `"5.0 e-9"`, `"5x10^-9"`, `"1.2E+003"`.

**Detection:** Log `sum(is.na(parsed_value))` before and after each normalization step. If count does not approach zero on known-good test data, a normalization step is missing or misordered.

**Phase address:** Numeric result parser phase (first numeric feature phase).

---

### v1.9 Pitfall 2: Range Splitting That Destroys Negative Values and Exponents

**What goes wrong:** Ranges like `5.6-7.8` are split on `-`. But negative values (`-0.5`), pH ranges (`6.5-8.5`), and already-normalized exponents (`4.56e-02`) also contain hyphens. A naive `str_split(result, "-")` silently destroys these.

**Evidence from sswqs_curation.R (lines 788–801):** The sswqs pipeline guards against this with `if_else(num_bool, as.list(result), str_split(...))` — splitting only strings that already failed `as.numeric()`. This guard is only safe after Pitfall 1 normalization has been applied. If normalization is skipped, `4.56e-02` is still a string here and gets split incorrectly.

**Consequences:** Negative benchmark values become two rows (sign fragment dropped; magnitude retained as wrong value). pH range boundaries are miscategorized. Incorrectly split rows inflate row counts with no audit entry.

**Prevention:**
- Numeric normalization (Pitfall 1) must precede range splitting. `num_bool` guard is only safe post-normalization.
- After splitting, re-run `as.numeric()` on each fragment and immediately filter `!is.na(parsed_value)` — fragments failing this are invalid splits.
- Dedicated test cases: `"-0.5"`, `"6.5-8.5"`, `"4.56e-02"`, `"1e-6"`, `"5.6-7.8"`, `"<0.001"`.

**Phase address:** Numeric result parser phase.

---

### v1.9 Pitfall 3: Unit Table Case-Sensitivity Collisions

**What goes wrong:** The ComptoxR ECOTOX unit table distinguishes case for scientifically meaningful symbols: `"mL"` (milliliter) vs `"ML"` (male organism), `"m"` (meter) vs `"M"` (molar), `"d"` (day) vs `"D"` (not in table). Global `tolower()` before lookup collapses these distinctions, producing wrong conversion factors — sometimes off by orders of magnitude.

**Evidence from ecotox_build.R:**
```r
"ML"   ,       1           , "male"              , "noscience"     ,  # line 458
"mL"   ,       0.001       , "l"                 , "volume"        ,  # line 297
"M"    ,       1           , "mol/l"             , "mol/volume"    ,  # line 330
"m"    ,       1           , "m"                 , "length"        ,  # line 343
```

**Consequences:** `"M"` (molar, 1 mol/L) becomes `"m"` (meter) after `tolower()`. The join finds the meter entry, not the molar entry. The conversion factor is wrong by approximately 6 orders of magnitude with no error raised.

**Prevention:**
- Do NOT globally lowercase units before table lookup.
- Apply micro-symbol normalization (`µ` → `u`, Unicode variants → ASCII) and nothing else before lookup.
- Perform case-sensitive lookup first; fall back to case-insensitive only for unmatched entries; flag those as LOW confidence.
- Store the original unit string in `unit_original` before any transformation.
- Test with: `"M"`, `"mL"`, `"ML"`, `"m"`, `"mg"`, `"MBq"`.

**Phase address:** Unit harmonization engine phase.

---

### v1.9 Pitfall 4: Compound Units Not Covered by Simple Lookup

**What goes wrong:** Regulatory benchmark data contains compound units: `"mg/kg bw/day"`, `"ug/L/h"`, `"mg/kg wet weight"`, `"nmol/mg protein"`, `"ppm-hour"`. These do not appear as single entries in the base ComptoxR unit table. A lookup miss produces `NA` for the conversion factor, which either silently propagates or triggers a `TRUE ~ cleaned_unit` fallback that exports the value unchanged with a wrong unit label.

**Evidence from ecotox_build.R (lines 785–797):** The build pipeline applies one-off string normalization for compound forms before table lookup (e.g., `"mgdrydiet"` → `"mg dry_diet"`, `"gwetbdwt"` → `"g wet_bdwt"`). This is evidence the real unit space exceeds the table by a significant margin.

**Evidence from sswqs_curation.R (line 836):**
```r
cleaned_unit %in% c("mg/kg fish tissue", "mg/kg wet weight") ~ "mg/kg (wet weight)",
```
These require explicit enumeration — they cannot be derived algorithmically from the base table.

**Consequences:** Benchmark values in compound units export with wrong or mismatched unit labels. The unit-value mismatch is invisible in ChemReg but causes schema validation failures at database load time.

**Prevention:**
- Implement two-tier lookup: (1) exact match on full string; (2) decompose `numerator/denominator` and look up components separately.
- Maintain an explicit extension table for compound units present in target regulatory datasets. Seed it from the `harmonized_unit` case_when in sswqs_curation.R.
- Log all lookup misses per run as an audit artifact. Surface a blocking warning if >5% of rows have unmatched units.

**Phase address:** Unit harmonization engine phase.

---

### v1.9 Pitfall 5: ToxVal Schema Column Type and Order Mismatch

**What goes wrong:** ToxVal schema requires 56 columns in a specific order with specific types. Using bare `NA` instead of `NA_character_` or `NA_real_` for placeholder columns, or using `select()` instead of `transmute()` (which can silently drop or reorder columns), produces type mismatches that DuckDB rejects at load time with opaque errors.

**Evidence from sswqs_curation.R (lines 1057–1139):** The script uses `transmute()` throughout with typed NA for all placeholders:
```r
toxval_id     = NA_character_,
chemical_id   = NA_character_,
toxval_numeric          = case_when(...),   # double
toxval_numeric_original = orig_result,      # character (raw string)
```
The schema contains both a double (`toxval_numeric`) and a character (`toxval_numeric_original`) in adjacent columns. Arrow's parquet writer will infer `NA` as logical type, which DuckDB will reject for a character column.

**Consequences:** Parquet files with bare `NA` carry logical type. DuckDB `COPY ... FROM PARQUET` fails or silently upcasts, producing wrong types in the database with no error at export time.

**Prevention:**
- Build the schema mapper against a canonical 56-column type manifest derived from the live toxval.duckdb schema.
- Use typed NA throughout: `NA_character_`, `NA_real_`, `NA_integer_` — never bare `NA`.
- Add a schema validation assertion before export: `stopifnot(all(names(result) == TOXVAL_SCHEMA_COLS))`.
- Write a test that reads the exported parquet back with `arrow::read_parquet()` and verifies each column's R type.

**Phase address:** ToxVal schema mapper phase.

---

### v1.9 Pitfall 6: `_original` Audit Columns Contaminated by Pre-Capture Cleaning

**What goes wrong:** If pipeline cleaning steps (comma removal, whitespace trimming) run BEFORE the `result_original` capture, the `_original` column contains a partially-cleaned value rather than the source cell value. QC review against the uploaded spreadsheet then fails because the "original" in ChemReg does not match what the user sees in their file.

**Evidence from sswqs_curation.R (lines 764–773):** The sswqs script deliberately cleans commas and whitespace BEFORE `rename(orig_result = result)`. This was intentional for SSWQS — commas in numbers are formatting artifacts. However, for ChemReg's user-uploaded files, qualifier symbols (`<`, `>`, `~`), chiral designations, and range hyphens must NOT be stripped before capture.

**Consequences:** `_original` audit column does not reflect the uploaded spreadsheet. Post-curation QC comparison against source data fails.

**Prevention:**
- Capture `result_original = result` as the absolute first mutation step, before any transformation.
- Apply only BOM stripping and invisible-whitespace normalization before capture; these are encoding artifacts, not content.
- All substantive transformations (qualifier extraction, comma removal, range splitting) operate on a working-copy column, never modifying `result_original`.

**Phase address:** Numeric result parser phase.

---

## Moderate Pitfalls (v1.9)

### v1.9 Pitfall 7: Qualifier Stripping That Loses Toxicological Meaning

**What goes wrong:** Values like `<0.001`, `>10`, `~5.6`, `ca. 3.2` contain qualifiers that carry meaning (detection limit, threshold, approximation). Stripping the qualifier to get a number without recording it separately produces an unqualified value that looks like an exact measurement.

**Prevention:**
- Extract the qualifier symbol (`<`, `>`, `<=`, `>=`, `~`, `ca.`, `approx`) into a separate `toxval_numeric_qualifier` column BEFORE numeric parsing.
- Map to ToxVal vocabulary: `<` → `"<"`, `>` → `">"`, no qualifier → `"="`, range midpoint → `"~"`.
- Never silently drop an unrecognized qualifier — flag the row.

**Phase address:** Numeric result parser phase.

---

### v1.9 Pitfall 8: Row Explosion from Range Handling Without Stable Row ID

**What goes wrong:** The pipeline splits range values (`"5.6-7.8"`) into two rows (low, high) and adds a synthetic midpoint row. Without a stable `.id` column assigned BEFORE any row-count-changing operation, joins to chemical identity, source metadata, and unit columns produce Cartesian products or lost associations.

**Evidence from sswqs_curation.R (line 781):**
```r
.id = 1:n()   # assigned before unnest — every exploded row carries source row identity
```

**Prevention:**
- Assign stable source row ID before any operation that changes row count.
- Document that output row count will be 1x (point), 2x (range endpoints), or 3x (range + midpoint) the source row count. Surface this count change in the UI.
- Joins to all non-numeric columns must happen before range expansion.

**Phase address:** Numeric result parser phase.

---

### v1.9 Pitfall 9: Cascade Reset Not Extended for New Column Tag Types

**What goes wrong:** ChemReg's existing cascade reset invalidates curation when column tags change. Adding new tag types (Result, Unit, Duration, Qualifier) without wiring them into the same `observeEvent` chain means a user can re-tag a unit column after running harmonization without the harmonized output being cleared.

**Evidence from PROJECT.md (line 171):** "Cascade reset on tag changes: Strict invalidation prevents stale curation results."

**Prevention:**
- New tag types must be added to the same cascade reset observer chain as the existing `"Name"`, `"CASRN"`, `"Other"` tags.
- The harmonization step must be gated: it cannot run if unit or result tags have changed since the last confirmed run.
- Test: change a unit tag after running harmonization, verify the harmonized output is cleared and the user must re-run.

**Phase address:** Extended column tagging UI phase.

---

### v1.9 Pitfall 10: Unit Harmonization Double-Conversion When Pipeline Steps Are Reordered

**What goes wrong:** The sswqs pipeline harmonizes raw units to an intermediate unit (ug/L) in one step, then the ToxVal mapper converts that intermediate to the final schema unit (mg/L). If these steps are reordered or the mapper consumes the raw `parsed_value` instead of the post-harmonization value, a 1000x double-conversion occurs silently.

**Evidence from sswqs_curation.R (lines 955–966):**
```r
toxval_numeric = case_when(
  harmonized_unit == "ug/l" ~ parsed_value / 1000,  # intermediate -> final
  harmonized_unit == "mg/l" ~ parsed_value,
  TRUE ~ parsed_value
),
```
The schema mapper assumes `parsed_value` is already in the intermediate harmonized unit, not the original source unit.

**Prevention:**
- Document the three-stage unit pipeline explicitly: raw source unit → intermediate harmonized unit → final ToxVal schema unit.
- The schema mapper must consume a named column that has passed through harmonization, not the original parsed value.
- Unit test the full chain: `1 mg/L input → 1000 ug/L intermediate → 1 mg/L final`.

**Phase address:** Unit harmonization and ToxVal schema mapper phases.

---

## Minor Pitfalls (v1.9)

### v1.9 Pitfall 11: Narrative Criteria Partially Parsing as Numeric

**What goes wrong:** Regulatory files contain narrative rows ("See regulation 4.2", "Not to exceed background"). These fail `as.numeric()` and should be dropped. But narratives beginning with numbers ("3-5 times background", "10 or less colonies") partially parse, producing wrong numeric values.

**Prevention:**
- Apply a narrative pre-filter before numeric parsing using regex on known signal phrases (`"\\bsee\\b|\\bwithin\\b|\\busing\\b|\\bmore\\b|\\bnot\\b"`).
- Surface filtered rows in the UI as "non-parsable" rather than silently dropping them.
- Allow the narrative filter pattern list to be user-configurable as a reference list (consistent with ChemReg's existing reference list pattern).

**Phase address:** Numeric result parser phase.

---

### v1.9 Pitfall 12: Duration Column Format Ambiguity

**What goes wrong:** Exposure duration appears in three forms across regulatory datasets: numeric with unit (`"96 h"`), code (`"A"` for acute, `"C"` for chronic), and free text description. A single regex applied to a mixed column silently fails the forms it was not designed for.

**Evidence:** The sswqs pipeline decodes duration from a code column (line 136–143). The ECOTOX pipeline (ecotox_build.R lines 545–571) converts numeric duration+unit to hours using a separate conversion table. These are fundamentally different parsers.

**Prevention:**
- Tag the duration column type explicitly in the column tagging step (Code / Free Text / Numeric+Unit).
- Implement a dedicated parser per form; do not attempt a unified regex.
- Map codes to canonical values using an explicit lookup (`"A"` → `"acute"`, `"C"` → `"chronic"`), not pattern inference.

**Phase address:** Duration/exposure classification phase.

---

### v1.9 Pitfall 13: Arrow/Parquet Type Drift Across Package Versions

**What goes wrong:** `arrow::write_parquet()` behavior for logical NA columns changed between Arrow 12 and Arrow 14. Parquet written with Arrow 12 loads correctly; the same code with Arrow 14 writes non-nullable logical columns, causing DuckDB `COPY` to fail with a type error.

**Prevention:**
- Specify Arrow version in DESCRIPTION `Imports` or `Suggests`.
- Write a schema-type assertion test: after export, read back with `arrow::read_parquet()` and run `vapply(df, class, character(1))` to verify all 56 column types match the manifest.

**Phase address:** ToxVal schema mapper / export phase.

---

## Integration Pitfalls (Adding v1.9 to Existing v1.8 ChemReg)

These pitfalls are specific to adding numeric/unit/schema features to a v1.8 codebase with 953 passing tests, 8 active Shiny modules, and a `curate_headless()` public API.

### INT-1: Chemical Name Cleaning Pipeline Must Not Touch Numeric Columns

The existing `cleaning_pipeline.R` runs 15 steps on chemical name columns. Numeric result columns must never pass through these steps. Specifically, the parenthetical stripping step would destroy `"(95% CI: 1.2-3.4)"` style values. The unicode cleaning step would corrupt subscript digits in chemical formulas used as result values. The two pipelines must be completely separate code paths, dispatched by column tag type — never by position or "all columns".

### INT-2: `curate_headless()` tag_map Must Extend Additively, Not Break

`curate_headless()` currently accepts `tag_map` values of `"Name"`, `"CASRN"`, or `"Other"`. Adding `"Result"`, `"Unit"`, `"Duration"`, `"Qualifier"` must be an additive extension. Any validation logic inside `curate_headless()` that rejects unknown tag values must be updated before new tag types are used. The existing three tag types and their downstream behavior must remain unchanged — regression tests must confirm this.

### INT-3: 7-Sheet Excel Export Must Accommodate New Column Set

The existing `export_helpers.R` writes a fixed 7-sheet structure. ToxVal schema output (56 columns) replaces the current ~15-column data sheet. The config sheet, which `config_import.R` reads by column name, must remain structurally unchanged. Adding 56 columns to Sheet 1 risks hitting the 16,384-column Excel limit if combined with audit trail columns. The data sheet and ToxVal export should be separate sheets.

### INT-4: New Code Belongs in New Files to Protect the 953-Test Regression Surface

The numeric parsing and unit harmonization features touch none of the existing `R/cleaning_pipeline.R`, `R/consensus.R`, or `R/curation.R` logic. New code belongs in dedicated new files (`R/numeric_parser.R`, `R/unit_harmonizer.R`, `R/toxval_mapper.R`) with their own test files. If any existing file must be modified, treat all 953 existing tests as regression candidates and run the full test suite before merging.

---

## Phase-Specific Warnings (v1.9)

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Numeric result parser | Fortran exponents silently NA (P1) | Full normalization chain before as.numeric(); diagnostic parse-failure count in UI |
| Numeric result parser | Range split destroys negatives (P2) | num_bool guard; test vector with negatives, pH ranges, exponents |
| Numeric result parser | _original captured after cleaning (P6) | Capture result_original as very first pipeline step |
| Numeric result parser | Qualifier stripping loses meaning (P7) | Extract qualifier before numeric parse; map to ToxVal vocabulary |
| Numeric result parser | Row explosion without stable ID (P8) | Assign .id before any row-count-changing operation; joins before expansion |
| Unit harmonization engine | Case-sensitive symbol collision (P3) | Case-sensitive lookup first; no global tolower(); test M vs m vs mL vs ML |
| Unit harmonization engine | Compound units not in table (P4) | Two-tier lookup; explicit extension table; block export if >5% miss rate |
| Unit harmonization engine | Double-conversion if steps reordered (P10) | Three-stage pipeline documented; schema mapper consumes harmonized column only |
| Extended column tagging | Cascade reset not extended (P9) | Wire new tag types into existing observeEvent chain; gate harmonization on confirmed tags |
| ToxVal schema mapper | NA type mismatch (P5) | Typed NA throughout; schema-type assertion test post-export |
| ToxVal schema mapper | Column order drift (P5) | transmute() not select(); 56-column canonical manifest as constant |
| Narrative rows | Text starting with digits partially parses (P11) | Pre-filter narratives before numeric pipeline; surface as "non-parsable" in UI |
| Duration classification | Mixed format in single column (P12) | Tag form type in column tagging; separate parsers per form; explicit code lookup |
| Export parquet | Type drift across Arrow versions (P13) | Pin Arrow version; read-back type assertion test |
| Integration | Chemical cleaning runs on numeric columns (INT-1) | Dispatch by tag type only; never "all columns" |
| Integration | curate_headless() rejects new tag types (INT-2) | Update validation before adding new tags; regression-test existing three tag values |
| Integration | Export column explosion (INT-3) | ToxVal output on separate sheet from existing data sheet |
| Integration | Existing tests become regression candidates (INT-4) | New features in new files; full test suite run before merge |

---

## Sources (v1.9)

- `C:/Users/sxthi/Documents/curation/epa/sswqs/sswqs_curation.R` — EPA production benchmark curation script; direct evidence for P1, P2, P4, P6, P7, P8, P10 (HIGH confidence — production code)
- `C:/Users/sxthi/Documents/ComptoxR/inst/ecotox/ecotox_build.R` — Unit conversion table and duration dictionary; direct evidence for P3, P4, P12 (HIGH confidence — production code)
- `C:/Users/sxthi/Documents/chemreg/.planning/PROJECT.md` — Architecture constraints and key decisions log; evidence for INT-1 through INT-4 and P9 (HIGH confidence — authoritative project document)

---

# v2.0 Pitfalls: Dedup-Remap Architecture, Short-Circuit Evaluation, Date/Duration Parsing, Media Harmonization

**Domain:** Adding performance optimization + date/duration parsing + media harmonization to existing ChemReg R package
**Milestone:** v2.0 Pipeline Performance & Date/Media Harmonization
**Researched:** 2026-04-24
**Confidence:** HIGH (codebase read + authoritative sources)

---

## Critical Pitfalls (v2.0)

### v2.0 Pitfall 1: Dedup-Remap Row ID Mismatch Corrupts Audit Trail

**What goes wrong:**
The distinct-string dedup pattern extracts unique strings, processes them, then joins results back to the parent dataset. When `build_audit_trail()` is called on the unique-string work table, it records `which(original_vals != cleaned_vals)` as `row_id` — those are positions 1..N in the work table, not positions in the parent 100k-row dataset. The audit trail reports "row 42 changed" but the actual parent row is 42,089. The export looks correct; only a source-vs-audit cross-check reveals the corruption.

**Why it happens:**
`build_audit_trail(df_original, df_cleaned, ...)` was designed for whole-dataframe transforms. Its `changed_idx <- which(...)` is always relative to whatever dataframe is passed in. When a developer runs a step on the 5,000-unique-string slice and passes that slice to `build_audit_trail`, the function behaves correctly for the slice — it has no knowledge of parent row positions.

**How to avoid:**
- Extract uniques with their origin row positions: `split(seq_along(all_vals), all_vals)` gives a list mapping each unique string to all parent rows that contain it.
- After processing the unique slice, define `remap_audit_to_parent(unique_audit, origin_map)` that expands each unique-slice row ID into all parent row IDs before appending to `audit_combined`.
- The `remap_audit_to_parent` function must be written and tested before any step is migrated to the dedup path.
- CI assertion: for any dedup step, `max(audit$row_id) <= nrow(parent_df)` must hold.

**Warning signs:**
- Audit trail has far fewer entries than the parent-dataset changed-value count.
- Audit row IDs cluster in a small range (e.g., 1-5,000) on a 100k-row dataset.
- Re-running the pipeline on the same data produces a different audit trail (non-determinism in unique-string ordering).

**Phase to address:** Dedup architecture phase — first phase of this milestone. `remap_audit_to_parent` must exist before any step is migrated.

---

### v2.0 Pitfall 2: Short-Circuit False Negative — Pre-Check Uses Simpler Condition Than the Step

**What goes wrong:**
A step pre-check returns "nothing to do" so the step is skipped. But the pre-check tests a necessary condition, not a sufficient one. Example: a date-parsing pre-check calls `all(is.na(col))` and skips when all values are NA. But the step also converts sentinel strings (`"N/A"`, `"none"`, `"--"`, `"unknown"`) to proper `NA`. Those strings pass `!is.na()` so the pre-check returns "clean", the step is skipped, and sentinels survive into curated output as character values.

**Why it happens:**
Pre-checks are written to be fast and simple. The developer models "is there anything to process?" but encodes a weaker test. Any case the pre-check does not enumerate becomes a silent false skip.

**How to avoid:**
- For each pre-check, write a companion test that constructs a vector the pre-check would pass (return "skip") but the step would transform. If such a vector exists, the pre-check is unsafe.
- Default to "run" on uncertainty. Pre-checks are performance optimizations, not gatekeepers. A false negative (skipping a needed step) is worse than a false positive (running an unneeded step).
- After wiring in the short-circuit layer, add a pipeline integration test: feed a dataset containing at least one transformable value per step, verify the audit trail captures it even when pre-check conditions are borderline.

**Warning signs:**
- Sentinel strings like `"N/A"`, `"--"`, `"none"` appear in curated output.
- A step reports "0 changes" on a dataset that visually contains dirty values.
- Pre-check pass rate > 90% on real messy regulatory data.

**Phase to address:** Short-circuit evaluation phase. Pre-check definitions must be reviewed against full step logic before enabling skip behavior.

---

### v2.0 Pitfall 3: Ambiguous Date Format — Silent Wrong-Month or Wrong-Year Parsing

**What goes wrong:**
`lubridate::mdy("01/02/2024")` and `lubridate::dmy("01/02/2024")` both succeed silently and return different dates. AMOS and ECOTOX study records mix US-format and European-format dates from multi-lab contributors. Choosing the wrong parse order produces plausible-looking but wrong dates. As of lubridate 1.3.0 the format used is no longer printed by default — ambiguous parses are invisible unless `options(lubridate.verbose = TRUE)` is set.

**Why it happens:**
Most EPA datasets are US-format, so the developer hardcodes `mdy()`. European-format dates with day <= 12 parse without error under either order — both interpretations are numerically valid. Only day values 13-31 expose the wrong choice, and those are a minority of dates.

**How to avoid:**
- Never rely on automatic format detection. Inspect a sample of date values and confirm order before choosing a parse function.
- Use `lubridate::parse_date_time(x, orders = c("mdy", "dmy", "ymd"))` with per-row logging of which format was inferred.
- Flag rows where day <= 12 AND month <= 12 as "format ambiguous" in the audit trail.
- Validate parsed dates against known study year ranges: a study date of 1924 on a modern regulatory record is a canary for wrong format.
- Set `options(lubridate.verbose = TRUE)` during development.

**Warning signs:**
- Date distribution histogram shows no dates with day > 12 — wrong-format rows silently became NA.
- Parsed dates where swapping day and month still produces a valid calendar date (no detection signal).
- NA rate in the parsed date column higher than raw data inspection would suggest.

**Phase to address:** Date/duration parsing phase. Format detection strategy must be locked before any date column is processed.

---

### v2.0 Pitfall 4: Duration Parsing — Compound and Fractional Inputs Break Simple Regex

**What goes wrong:**
A duration field contains `"2d 4h"`, `"0.5 days"`, `"96 hrs"`, `"2 weeks"`, or `"48"` (unit-free). A regex designed for the common case (`(\d+)\s*(h|d)`) misses compound expressions entirely, silently drops them to NA, or converts `"2 weeks"` as 2 hours because the unit synonym map omits "weeks". Fractional values like `"0.5"` paired with `"d"` convert correctly only if the fractional is handled before the unit factor is applied — casting to integer first produces 0.

**Why it happens:**
ECOTOX duration fields were designed for single-value database entry. When source data is free-text, contributors write compound strings that look numeric but are not. The parser handles the common case and ignores everything else.

**How to avoid:**
- Parse in two passes: first attempt to split on whitespace into `(value, unit)` pairs; if more than one pair is found, convert each to hours and sum.
- Build an explicit unit synonym map: `h/hr/hrs/hour/hours -> 1`, `d/day/days -> 24`, `wk/week/weeks -> 168`, `min/minute/minutes -> 1/60`, `s/sec/second/seconds -> 1/3600`.
- Do NOT use `lubridate::duration()` for ECOTOX free-text fields: the `"m"` abbreviation means months in lubridate (not minutes) unless an ISO 8601 `"P"` prefix is present. `"10 min"` will parse as 10 months.
- Required test cases: `"96h"`, `"4 days"`, `"2d 4h"`, `"0.5 hr"`, `"2 weeks"`, `"48"` (unit-free), NA, `""`, `"N/A"`.

**Warning signs:**
- Duration NA rate > 5% on clean-looking data.
- `"24h"` and `"1d"` do not compare equal after conversion.
- Very large hour values suggesting a unit was applied at the wrong scale (weeks treated as days).

**Phase to address:** Date/duration parsing phase. Must include compound, fractional, and abbreviation-ambiguity test cases before the phase is considered complete.

---

### v2.0 Pitfall 5: Media Classification — Overlapping Categories Produce Silent Single-Pick

**What goes wrong:**
Many media descriptions match multiple categories: `"freshwater sediment"` matches both `"aqueous"` and `"sediment"`; `"soil pore water"` matches both `"soil"` and `"aqueous"`. A rule-based classifier picks the first-matching rule without flagging the ambiguity. Downstream ppb/ppm unit routing in `unit_harmonizer.R` then uses the wrong conversion factor for those rows silently, with no audit entry.

**Why it happens:**
Rule lists are built with single-match assumptions. "Most specific first" ordering is implicit and undocumented. When two rules fire, tie-breaking is rule order rather than domain logic.

**How to avoid:**
- Count how many rules match each input string. If count > 1, assign `media_ambiguous = TRUE` and expose in the UI.
- Pre-enumerate known compound categories as first-class values: `"freshwater_sediment"`, `"marine_sediment"`, `"soil_porewater"`. These are explicit entries, not joins of two rules.
- Test that every new media category correctly threads through the existing ppb/ppm routing branch in `harmonize_units()` or triggers an explicit fallback.

**Warning signs:**
- Media output contains only the most-common categories with no compound or ambiguous values — silently collapsed.
- ppb values for sediment-type records are converting using the aqueous factor (factor-of-1000 error vs mg/kg dry weight).
- High `media = NA` rate on records that have visible media descriptions.

**Phase to address:** Media harmonization phase. Define compound category vocabulary before writing classifier rules.

---

### v2.0 Pitfall 6: AMOS Ontology Extraction — Overfitting to High-Frequency Descriptions

**What goes wrong:**
The ~7,500 AMOS method descriptions are skewed: `"freshwater"` and `"estuarine"` appear hundreds of times; `"hypersaline"` and `"interstitial water"` appear once or twice. A classifier built from 50-100 sampled examples is calibrated on common types and misses the long tail. Rare types fall through to NA, which looks like a data quality issue rather than a classifier failure.

**Why it happens:**
Developers sample visible, common examples to write rules. The long tail only becomes visible when running on the full 7,500-row corpus. NeurIPS 2024 OLLM research confirms this pattern: high-frequency concepts are memorized; low-frequency ones underfit.

**How to avoid:**
- Before writing any rules, tabulate all unique descriptions sorted by frequency. Explicitly identify the long tail (fewer than 5 occurrences).
- Define `"unclassified"` as a valid output value distinct from `NA`. `NA` means no answer attempted; `"unclassified"` means the classifier ran but could not map. Both are acceptable, but they have different downstream implications.
- Build iteratively: rules for top-20 types first, run on full corpus, inspect all unclassified rows, add rules for the next tier.
- Never ship a classifier where a non-empty input produces `NA` without a warning. All unclassified outputs go to a review queue.
- Budget explicitly for manual curation of the long tail (~100-200 descriptions).

**Warning signs:**
- Unclassified rate > 15% on the full AMOS corpus.
- All unclassified rows cluster around specific method types — systematic miss, not random noise.
- Classifier was tested only on the same examples used to write the rules (no held-out validation set).

**Phase to address:** AMOS ontology pipeline phase. Requires full corpus exploration before classifier design.

---

### v2.0 Pitfall 7: Dedup Layer Passes Slice Row IDs to `build_audit_trail` Without Remap

**What goes wrong:**
`build_audit_trail(df_original, df_cleaned, ...)` records `which(original_vals != cleaned_vals)` as `row_id`. When called on a 5,000-unique-string slice, it records IDs 1-5,000. These positions are meaningless in the parent 100k-row dataframe. The step appears to have audited correctly but the audit trail is useless for tracing changes back to source rows.

**How to avoid:**
- Do not change `build_audit_trail`'s signature. Define `remap_audit_to_parent(audit_tbl, origin_map)` separately.
- The dedup coordinator calls `build_audit_trail` on the slice, then immediately calls `remap_audit_to_parent` before appending to `audit_combined`.
- CI assertion: for any step using the dedup path, `nrow(audit_for_this_step) >= parent_changed_count`.

**Warning signs:**
- Audit entry count for a dedup step is roughly `length(unique(values))` instead of `sum(values_changed_in_parent)`.
- Step reports "42 strings changed" but the parent data has 4,200 rows containing those strings.

**Phase to address:** Dedup architecture phase — same phase as Pitfall 1.

---

## Moderate Pitfalls (v2.0)

### v2.0 Pitfall 8: Benchmark Measures Warm-Cache Dedup Cost, Misses Real-Workload Profile

**What goes wrong:**
A `bench::mark()` comparison of "full pipeline" vs "dedup pipeline" on a warm in-memory session shows 3x improvement. Real production runs show 1.4x, because the benchmark excluded: cold-start regex compilation, RDS cache load for reference lists, the remap step cost, and GC pressure from intermediate allocations.

**How to avoid:**
- Use `profvis::profvis({run_cleaning_pipeline(...)})` first to identify actual hotspots. Then benchmark only those hotspots.
- Include the reference list load from disk in the benchmark. Reset the cache between bench iterations.
- Test on real data with a measured string uniqueness rate. Synthetic data with 100% unique strings overstates dedup benefit.
- Include the remap step in the measurement.
- Report median, not mean (R benchmark distributions are right-skewed).

**Warning signs:**
- Benchmark dataset has > 50% unique strings.
- Benchmark was run without a fresh R session.
- Measured improvement exceeds 5x on a non-trivial pipeline.

**Phase to address:** Performance benchmark harness phase. Methodology must be documented before measuring results.

---

### v2.0 Pitfall 9: `lubridate` `"m"` Abbreviation Means Months, Not Minutes

**What goes wrong:**
`lubridate::duration("10 min")` parses correctly, but `lubridate::duration("10 m")` is 10 months. ECOTOX duration fields frequently use `"m"` as a unit abbreviation for minutes. A duration parser that calls `lubridate::duration()` on raw field values will silently produce month-scale durations for minute-scale exposures.

**How to avoid:**
- Do not use `lubridate::duration()` for ECOTOX or regulatory free-text duration fields. Use the custom unit synonym map (Pitfall 4).
- If lubridate is used anywhere in the duration path, add an explicit assertion: `parse_duration("10 m")` must equal 1/6 hours (not 10 months).

**Phase to address:** Date/duration parsing phase.

---

### v2.0 Pitfall 10: AMOS Cache Not Invalidated When Corpus Updates

**What goes wrong:**
The AMOS corpus is fetched via `ComptoxR::chemi_amos_method_pagination()` and cached as RDS. When the corpus updates upstream, the classifier runs against stale data with no visible signal.

**How to avoid:**
- Implement the same cache-age check used by other reference list loaders: store fetch timestamp in cache metadata; surface a prompt when cache is older than a configurable TTL (30 days is appropriate for AMOS).
- Export `refresh_amos_cache()` for explicit manual refresh.

**Phase to address:** AMOS ontology pipeline phase.

---

## Integration Pitfalls (v2.0 into Existing v1.9 ChemReg)

### v2.0 INT-1: Short-Circuit Layer Must Not Skip `inject_row_lineage`

`inject_row_lineage()` adds `original_row_id` as the first column. It must run before any pre-check fires. If a pre-check short-circuits the pipeline before lineage injection, downstream audit row IDs have no anchor. Guard: `inject_row_lineage` runs unconditionally as the first operation in `run_cleaning_pipeline`; all pre-checks operate on the lineage-injected dataframe.

### v2.0 INT-2: New Step Parameters Must Be Plumbed Through `curate_headless()`

Date format order, duration base unit, media category source path — all are new configurable parameters. `curate_headless()` is the public scripting API. Any parameter settable in the Shiny UI must also be settable headlessly. Missing parameters in `curate_headless()` means headless users cannot reproduce a Shiny run.

### v2.0 INT-3: Dedup Map Must Not Use `original_row_id` as the Dedup Key

`original_row_id` is the row identity key injected by `inject_row_lineage()`. It is unique per row. Deduplicating on `original_row_id` produces a "unique" set identical to the full dataset — no benefit, added overhead. The dedup key is always the string content being processed.

### v2.0 INT-4: ppb/ppm Routing Must Accept New Media Values Without Crashing

The existing routing branches on `media == "aqueous"`. When media harmonization adds new valid values (`"sediment"`, `"soil"`, `"air"`, compound types), the routing must handle them explicitly. Unhandled media values that previously did not exist will silently produce NA conversion factors for rows that previously harmonized correctly.

### v2.0 INT-5: Migrate Steps One at a Time — Run Full Test Suite After Each Migration

Each step migrated to the dedup path is a potential regression. Do not batch-migrate all steps and then debug a cascade of failures. After migrating any single step, run all 953 tests before proceeding.

---

## Performance Traps (v2.0)

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| `unique()` called per-column inside dedup loop | Runtime grows with column count despite identical data | Pre-extract all unique strings across target columns once | Any dataset > 10k rows |
| Remap join via `dplyr::left_join` on full parent | Doubles memory; triggers copy-on-modify for wide table | Use `match()` with direct vector assignment | > 50k rows, > 30 columns |
| Loading AMOS corpus on every pipeline run | 7,500+ API calls per run | Cache as RDS with timestamp TTL | Every run without cache |
| Profiling on synthetic data with 100% unique strings | Dedup benefit overstated; benchmark misleading | Measure uniqueness rate on real data first | Always |
| Regex compilation inside dedup loop per unique string | Compilation overhead negates matching benefit | Pre-compile all patterns before the loop | > 1,000 unique strings |

---

## "Looks Done But Isn't" Checklist (v2.0)

- [ ] **Dedup-remap:** Every audit `row_id` is within `[1, nrow(parent_df)]` — assert `all(audit$row_id <= nrow(parent_df))`
- [ ] **Dedup-remap:** Identical input strings in N parent rows produce N audit entries, not 1
- [ ] **Short-circuit:** Every pre-check has a companion test with a value that passes the pre-check but would be transformed by the step
- [ ] **Date parsing:** Test suite covers dates where day and month are both <= 12; format choice is documented per dataset
- [ ] **Duration:** Test suite covers: integer+unit, fractional+unit, compound two-unit, unit-only, number-only, NA, empty string, `"N/A"`, `"unknown"`
- [ ] **Duration:** `"10 m"` does not parse as 10 months — confirm lubridate is not used in the free-text duration path
- [ ] **Media classification:** Compound-media inputs produce compound category or `media_ambiguous = TRUE` — never silently single-pick
- [ ] **Media/ppb routing:** All new media values pass through `harmonize_units()` ppb/ppm branch correctly or trigger explicit fallback
- [ ] **AMOS classifier:** Held-out validation set exists; unclassified rate is measured and documented
- [ ] **`curate_headless()`:** Date format, duration base unit, and media config parameters are plumbed through; 953 existing tests still pass
- [ ] **Benchmark:** Profile run on real data with measured uniqueness rate; cold-start time included; methodology documented before results

---

## Pitfall-to-Phase Mapping (v2.0)

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Dedup row ID mismatch (P1, P7) | Dedup architecture phase | `remap_audit_to_parent` tested; `max(audit$row_id) <= nrow(parent)` assertion passes |
| Short-circuit false negative (P2) | Short-circuit evaluation phase | Companion test per pre-check; integration test on dirty data captures all changes |
| Ambiguous date format (P3) | Date/duration parsing phase | Format documented per dataset; ambiguous-zone dates flagged in audit |
| Compound/fractional duration (P4) | Date/duration parsing phase | Full test vector passes including compound, fractional, `"10 min"` |
| `lubridate` "m" collision (P9) | Date/duration parsing phase | `parse_duration("10 m")` == 1/6 hours assertion present in test suite |
| Media category overlap (P5) | Media harmonization phase | Overlapping inputs produce compound category or ambiguity flag |
| ppb routing with new media (INT-4) | Media harmonization phase | `harmonize_units()` tests extended to all new media values |
| AMOS ontology overfitting (P6) | AMOS ontology pipeline phase | Held-out validation; unclassified rate acceptable and documented |
| AMOS cache staleness (P10) | AMOS ontology pipeline phase | Cache TTL and refresh mechanism implemented |
| Benchmark measures wrong thing (P8) | Performance benchmark phase | Methodology documented; real data; cold-start included |
| `inject_row_lineage` skipped (INT-1) | Dedup + short-circuit phases | Lineage column present in all outputs regardless of pre-check result |
| `curate_headless` missing new params (INT-2) | Each new feature phase | Headless integration test covers new parameters |
| Regression from dedup migration (INT-5) | Each migration phase | Full test suite passes after each individual step migration |

---

## Sources (v2.0)

- ChemReg codebase `R/cleaning_pipeline.R` — `build_audit_trail`, `run_cleaning_pipeline`, `inject_row_lineage` implementation (HIGH confidence — read directly)
- ChemReg codebase `R/unit_harmonizer.R` — ppb/ppm media routing, `harmonize_units` API (HIGH confidence — read directly)
- [lubridate duration reference](https://lubridate.tidyverse.org/reference/duration.html) — "m" = months vs minutes, fractional support, ISO 8601 parsing
- [lubridate parse dates reference](https://lubridate.tidyverse.org/reference/ymd.html) — silent format inference, `lubridate.verbose` option
- [datefixR documentation](https://docs.ropensci.org/datefixR/) — DMY default assumption, error reporting for ambiguous inputs
- [Advanced R: Measuring performance](https://adv-r.hadley.nz/perf-measure.html) — microbenchmarks mislead for real workloads
- [bench package guide](https://rguides.dev/guides/r-bench-microbenchmark/) — median vs mean, warm-cache pitfalls
- [dplyr distinct dedup guide](https://thelinuxcode.com/r-dplyr-distinct-function-a-deep-practical-guide-to-reliable-deduplication/) — key definition bugs, non-deterministic tie-breaking
- [5 Data Pipeline Mistakes (Medium, 2025)](https://medium.com/@kalluripradeep99/5-data-pipeline-mistakes-that-cost-me-weeks-of-debugging-a565c746ed8b) — row mismatch from schema changes
- [ECOTOXr CRAN PDF](https://cran.r-project.org/web/packages/ECOTOXr/ECOTOXr.pdf) — `as_unit_ecotox`, `mixed_to_single_unit`, duration conversion functions
- [Washington State Deduplication Report 2025](https://doh.wa.gov/sites/default/files/2025-05/RecordDeduplicationReport1.pdf) — R dedup pipeline correctness pitfalls
- [NeurIPS 2024 OLLM](https://neurips.cc/virtual/2024/poster/94942) — overfitting on high-frequency concepts; low-frequency ontology terms underfit

---
*v2.0 pitfalls appended: 2026-04-24*
