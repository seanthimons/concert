# Architecture

**Analysis Date:** 2026-02-26

## Pattern Overview

**Overall:** Shiny MVC with reactive state management and multi-algorithm ensemble pattern for data detection.

**Key Characteristics:**
- Reactive data store (`reactiveValues()`) as single source of truth for application state
- Multi-stage data pipeline: Upload → Validation → Detection → Extraction → Cleaning → Curation
- Ensemble detection approach combining three independent algorithms with confidence scoring
- Modular helper functions organized by responsibility (file handling, detection, curation)
- Observer-based event handling for UI reactivity and data flow orchestration

## Layers

**Presentation Layer (UI):**
- Purpose: BSLib-based Shiny UI with sidebar navigation, tabs, and conditional panels
- Location: `app.R` (lines 45-275)
- Contains: Page structure, cards, inputs, outputs, form elements
- Depends on: Server reactives for data and conditional rendering
- Used by: Server layer for rendering outputs

**Server/Business Logic Layer:**
- Purpose: Orchestrates user interactions, coordinates data processing, manages state
- Location: `app.R` (lines 279-1124)
- Contains: Event handlers (observeEvent, observe), reactive expressions, output renderers
- Depends on: Helper modules (file_handlers.R, data_detection.R, curation.R) and data_store reactiveValues
- Used by: Presentation layer receives computed outputs; triggered by UI inputs

**Data Processing Layer:**
- Purpose: Implements core algorithms for file I/O, detection, and chemical validation
- Location: `R/file_handlers.R`, `R/data_detection.R`, `R/curation.R`
- Contains: Pure functions with defined inputs/outputs
- Depends on: External packages (readr, readxl, ComptoxR, dplyr, purrr, stringr)
- Used by: Server layer calls these functions to process data

**State Management:**
- Purpose: Holds application state across reactive events
- Location: `app.R` lines 281-293, reactive expressions throughout server
- Contains: Raw data, cleaned data, detection results, file metadata, column tags, curation results
- Accessed by: All output renderers, event handlers, and downstream functions

## Data Flow

**Upload & Detection Flow:**

1. **File Upload Triggered** (line 296): `observeEvent(input$file_upload)`
2. **Validation** (line 300): `validate_file()` checks extension and size
3. **Raw Read** (line 322): `safely_read_file()` uses strategy-based reading (readr → readxl → rio fallback)
4. **Detection Ensemble** (line 333): `detect_data_start()` runs three methods in parallel:
   - `detect_data_start_heuristic()`: Analyzes fill ratios per row
   - `detect_pattern_based()`: Scores rows by chemistry keyword matches
   - `detect_by_type_consistency()`: Evaluates type stability across columns
5. **Best Method Selection** (lines 313-316 in data_detection.R): Chooses highest confidence result
6. **Data Extraction** (line 352): `extract_clean_data()` uses detected header/data rows to set column names
7. **Post-Processing** (lines 358-363): Merged cell handling, janitor cleaning (clean_names, remove_empty)
8. **State Storage** (lines 382-385): Stores in `data_store` reactiveValues
9. **UI Update**: Reactive outputs automatically update via `renderDT()`, `renderUI()`, etc.

**Detection Mode Switch Flow:**

1. **Mode/Row Change** (line 447): `observeEvent(c(input$detection_mode, input$manual_header_row))`
2. **Re-detect** (line 453): Call `detect_data_start()` with mode and manual_row
3. **Re-extract** (line 460): Call `extract_clean_data()` with new detection
4. **Re-clean** (lines 461-464): Apply janitor transformations
5. **Update Store** (lines 488-489): Update `data_store$clean` and `data_store$detection`
6. **Auto-Render**: All dependent outputs re-render automatically

**Curation Flow:**

1. **Column Selection** (line 799): User selects columns via checkbox in sidebar
2. **Column Tagging** (line 864): User assigns tags (Name, CASRN, Other) to columns
3. **Curation Execution** (line 923): `observeEvent(input$run_curation)`
4. **Data Processing** (line 959): `curate_chemical_data()` processes tagged columns:
   - CAS columns: `validate_cas_numbers()` uses ComptoxR validation
   - Name columns: `lookup_chemical_names()` queries ComptoxR API
5. **Results Storage** (lines 974-976): Store curated data, report, and status in data_store
6. **Export** (line 1041): `downloadHandler()` creates Excel file with original + curated data

## Key Abstractions

**reactiveValues Data Store:**
- Purpose: Centralized state management holding all application data
- Examples: `data_store$raw`, `data_store$clean`, `data_store$detection`, `data_store$column_tags`
- Pattern: Single point of truth; reactives and observers watch for changes and trigger updates

**Detection Result Object:**
- Purpose: Standardizes output from all three detection algorithms
- Structure: `list(header_row, data_start_row, metadata_rows, method, confidence, all_results)`
- Pattern: Ensemble selection via confidence score; all_results preserved for debugging (lines 716-735 in app.R)

**Curation Result Object:**
- Purpose: Consolidates chemical validation results with reporting metadata
- Structure: `list(curated_data = tibble, report = list(cas_validated, names_exact_match, ...))`
- Pattern: Separate tibble for row-level results, list for aggregate statistics

**File Strategy Pattern:**
- Purpose: Graceful fallback for multiple file formats and encodings
- Examples: `read_csv_robust()` tries UTF-8 → Latin-1 → semicolon → tab → base R (lines 37-104)
- Pattern: Each strategy wrapped in tryCatch; error feeds to next strategy

## Entry Points

**Application Entry:**
- Location: `app.R` line 1127
- Triggers: `shiny::runApp()` or user navigates to app URL
- Responsibilities: Initializes UI, boots server logic, establishes reactive contexts

**File Upload Entry:**
- Location: Line 296 `observeEvent(input$file_upload)`
- Triggers: User selects file via `fileInput()`
- Responsibilities: Validates, reads, detects, extracts, cleans, stores to data_store

**Detection Mode Change:**
- Location: Line 447 `observeEvent(c(input$detection_mode, input$manual_header_row))`
- Triggers: User toggles Auto/Manual or changes manual row number
- Responsibilities: Re-runs detection with new parameters, updates stored clean data

**Curation Execution:**
- Location: Line 923 `observeEvent(input$run_curation)`
- Triggers: User clicks "Start Curation" button
- Responsibilities: Validates API key, calls curate_chemical_data(), stores results

## Error Handling

**Strategy:** Multi-layered with graceful degradation:

**Layer 1 - Validation (Pre-Processing):**
- `validate_file()` (file_handlers.R line 158): Checks extension, size; returns success flag and message
- Returns early with user-facing error notification if validation fails (line 303-308)

**Layer 2 - Safe Function Wrapping:**
- `purrr::safely()` wraps detection methods (data_detection.R lines 290-292)
- Prevents one method failure from crashing ensemble; all failures handled in lines 301-310
- Fallback detection returns low-confidence result (0.3) instead of crashing

**Layer 3 - Try-Catch Blocks:**
- Main file upload handler wrapped in tryCatch (line 318-443)
- Detection mode change wrapped in tryCatch (line 450-498)
- Curation execution wrapped via safely() (line 959)

**Layer 4 - User Notifications:**
- All errors show `showNotification()` with error type and message
- Processing notifications cleared before error display (line 410)
- Full stack trace logged to R console for debugging (lines 430-434)

**Specific Error Patterns:**
- Empty file after cleaning: Warning notification, no data displayed (lines 366-375, 466-476)
- No columns after cleaning: Stop processing, error shown (lines 377-379, 478-484)
- Curation API key missing: Error notification halts curation (lines 927-933)
- Detection method failures: Logged in errors field, fallback used (lines 309, 491-496)

## Cross-Cutting Concerns

**Logging:**
- Console messages for debugging (lines 330, 340-348, 354-355)
- Format: "Raw data dimensions: ", "Detection: method=", etc.
- Used for tracing data flow during development
- Error logging includes file name, error message, and stack trace (lines 430-434)

**Validation:**
- File-level: `validate_file()` checks type and size before processing
- Data-level: `extract_clean_data()` validates row numbers against dataframe bounds (lines 345, 357, 366)
- Result-level: Checks for empty rows/columns after cleaning (lines 325-327, 365-379, 466-484)
- CAS/Name validation: ComptoxR functions handle invalid input (curation.R lines 9-15, 24-90)

**Authentication:**
- API Key: Environment variable `ctx_api_key` required for curation (line 927)
- Check performed via `Sys.getenv()` before API calls (line 927)
- Missing key shows error, returns early without attempting curation (lines 928-933)

---

*Architecture analysis: 2026-02-26*
