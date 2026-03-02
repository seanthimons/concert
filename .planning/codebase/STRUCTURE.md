# Codebase Structure

**Analysis Date:** 2026-02-26

## Directory Layout

```
chemreg/
├── app.R                          # Main Shiny application (UI + server, 1127 lines)
├── load_packages.R                # Package installation and initialization
├── air.toml                       # Air code formatter configuration
├── checkpoint.R                   # Optional data integrity checking utility
├── CLAUDE.md                      # Project-specific development guidelines
│
├── R/                             # Core application modules
│   ├── file_handlers.R            # File I/O and validation functions
│   ├── data_detection.R           # Frontmatter detection algorithms
│   └── curation.R                 # Chemical data validation and lookup
│
├── tests/                         # Test suite
│   └── test_data_detection.R      # Unit tests for detection methods
│
├── data/                          # Test and sample data
│   ├── chemical_validation_test_README.md
│   ├── create_sample_excel.R      # Script to generate test files
│   └── [test data files]
│
└── .planning/
    └── codebase/                  # GSD analysis documents (created by this tool)
        ├── ARCHITECTURE.md        # System design and data flow
        ├── STRUCTURE.md           # Directory layout and file purposes (this file)
        ├── CONVENTIONS.md         # Coding style and patterns
        ├── TESTING.md             # Testing framework and patterns
        ├── STACK.md               # Technology dependencies
        ├── INTEGRATIONS.md        # External API and service integrations
        └── CONCERNS.md            # Technical debt and issues
```

## Directory Purposes

**Root Level:**
- Purpose: Application configuration, entry points, development utilities
- Contains: Shiny app entry point, package management, formatting rules
- Key files: `app.R` (main), `load_packages.R` (dependencies), `air.toml` (style config)

**R/ Directory:**
- Purpose: Modular application logic organized by responsibility
- Contains: Helper functions for file I/O, detection algorithms, chemical curation
- Key files: Three core modules imported by `app.R` (lines 34-36)
- Organization: Each file handles one concern (file I/O, detection, curation)

**tests/ Directory:**
- Purpose: Unit testing for core detection algorithms
- Contains: 11 test cases covering clean files, frontmatter, edge cases
- Key files: `test_data_detection.R` (comprehensive coverage of detection module)
- Run with: `testthat::test_dir("tests")` or source individual test file

**data/ Directory:**
- Purpose: Sample files, test data, and data generation utilities
- Contains: Chemical inventory test data, metadata files, generation scripts
- Key files: `create_sample_excel.R` (generates test datasets), CSV/XLSX test files

**.planning/codebase/ Directory:**
- Purpose: GSD analysis artifacts documenting architecture and conventions
- Contains: Architecture maps, structure guides, coding conventions, testing patterns
- Auto-generated: Created by `/gsd:map-codebase` orchestrator
- Used by: `/gsd:plan-phase` and `/gsd:execute-phase` to understand codebase structure

## Key File Locations

**Entry Points:**

- `app.R`: Main Shiny application
  - UI definition: Lines 45-275 (page_sidebar with sidebar + navset_card_tab)
  - Server logic: Lines 279-1124 (reactiveValues, observeEvents, output renderers)
  - Run with: `shiny::runApp()` or `Rscript -e "shiny::runApp('app.R')"`

- `load_packages.R`: Package initialization
  - Auto-installs packages via pak
  - Defines custom operators (%ni%, %||%)
  - Auto-generates air.toml if missing

**Configuration:**

- `air.toml`: Code formatting rules
  - Line width: 120 characters
  - Indent: 2 spaces
  - Auto-applied via air formatter

- `CLAUDE.md`: Development notes
  - Project overview, architecture guide, development commands
  - Configuration points (detection sensitivity, preview defaults)
  - Testing structure and common patterns

**Core Logic:**

- `R/file_handlers.R`: File I/O operations
  - `safely_read_file()`: Multi-strategy reader (readr → readxl → rio)
  - `read_csv_robust()`: CSV with 5 encoding/delimiter fallbacks
  - `read_excel_robust()`: Excel file reading with error handling
  - `validate_file()`: Pre-upload checks (extension, size)
  - `calculate_smart_preview_rows()`: Dynamic preview sizing
  - `format_file_size()`: Human-readable formatting

- `R/data_detection.R`: Frontmatter detection algorithms
  - `detect_data_start_heuristic()`: Fill ratio analysis
  - `detect_pattern_based()`: Chemistry keyword matching
  - `detect_by_type_consistency()`: Type stability scoring
  - `detect_data_start()`: Ensemble orchestration
  - `extract_clean_data()`: Header + data extraction
  - `handle_merged_cells()`: Fill down first column detection

- `R/curation.R`: Chemical validation
  - `validate_cas_numbers()`: CAS number validation via ComptoxR
  - `lookup_chemical_names()`: Chemical name lookup via EPA CompTox API
  - `curate_chemical_data()`: Main orchestrator combining validation

**Testing:**

- `tests/test_data_detection.R`: 11 test cases
  - Test: Heuristic detection, pattern detection, type consistency
  - Test: Ensemble selection, manual override, merged cells
  - Run: `testthat::test_dir("tests")` from R console
  - Uses synthetic chemical data (Acetone, Ethanol, Benzene)

## Naming Conventions

**Files:**

- Snake case with descriptive names: `file_handlers.R`, `data_detection.R`, `curation.R`
- Test files: `test_*.R` pattern matching test discovery
- Config files: Lowercase with dot notation: `air.toml`, `.gitignore`
- Markdown docs: UPPERCASE for documentation: `CLAUDE.md`, `README.md`

**Directories:**

- Lowercase for functionality: `R/`, `tests/`, `data/`, `.planning/`
- Nested under functional area: `.planning/codebase/` for analysis docs

**Functions:**

- Snake case: `detect_data_start()`, `safely_read_file()`, `validate_file()`
- Private/internal prefixed with dot or wrapped in purrr::safely: `read_csv_robust()` (internal helper)
- Descriptive action verbs: `detect_*`, `validate_*`, `extract_*`, `handle_*`, `curate_*`

**Variables & Objects:**

- Snake case: `data_store`, `raw_df`, `clean_df`, `detection`, `column_tags`, `curation_results`
- Reactive stores: All lowercase: `data_store`, `filtered_data()`
- Tibbles/dataframes: `*_df` suffix: `raw_df`, `clean_df`, `preview_data`
- Lists: descriptive: `detection`, `curation_result`, `validation`
- Vectors: plural: `metadata_rows`, `candidate_rows`, `header_indicators`

**Constants & Configuration:**

- Upper camelCase for config values: `maxRequestSize = 50 * 1024^2`
- Underscored for detection params: `min_filled_ratio = 0.7`, `scan_rows = 50`
- Quoted strings for UI labels: `"Chemical Name"`, `"Detection Confidence"`

## Where to Add New Code

**New Detection Algorithm:**

1. Create function in `R/data_detection.R` following pattern:
   - Function name: `detect_*_method()` (e.g., `detect_by_neural_network()`)
   - Returns: `list(header_row, data_start_row, metadata_rows, method, confidence)`
   - Error handling: Wrap in `purrr::safely()` at call site (line 290-292)

2. Add to ensemble in `detect_data_start()` (line 289-292):
   ```r
   new_method = purrr::safely(detect_by_neural_network)(df)
   ```

3. Add tests in `tests/test_data_detection.R`:
   - Test with clean file (baseline)
   - Test with frontmatter (main use case)
   - Test with edge cases (empty, single row, etc.)

4. Document expected confidence range in CLAUDE.md

**New File Format Support:**

1. Add extension to `validate_file()` allowed_extensions (R/file_handlers.R line 171)
2. Add reading strategy in `safely_read_file()` (R/file_handlers.R lines 10-32)
3. Create robust reader function (e.g., `read_parquet_robust()`)
4. Update fileInput accept parameter in app.R line 73
5. Test with sample file in data/ directory

**New Chemical Validation Method:**

1. Create function in `R/curation.R` with signature:
   - Input: Vector of chemical identifiers (names or CAS numbers)
   - Output: Tibble with original, validated, match status, confidence
   - Error handling: Return "no_match" for failures, don't throw

2. Integrate into `curate_chemical_data()`:
   - Check column_tags for method type (e.g., new tag "SMILES")
   - Call new validation function for tagged columns
   - Bind results with other methods

3. Update column tagging UI in app.R line 850-856:
   - Add new option to selectInput choices
   - Update curation_summary output to reflect new type

**New Utility Function:**

1. Add to appropriate module:
   - File utilities: `R/file_handlers.R`
   - Detection utilities: `R/data_detection.R`
   - Curation utilities: `R/curation.R`
   - General: New `R/utils.R`

2. Pattern: Snake case, descriptive action verb, roxygen2 docstring
3. Export: Include `@export` tag if used outside module
4. Test: Add unit test in tests/test_*.R with similar test pattern

**New UI Tab:**

1. Add `nav_panel()` to navset_card_tab (app.R line 155-274)
2. Create corresponding server output renderer (e.g., `output$new_tab <- renderUI()`)
3. Add observeEvent handler for button actions
4. Use `data_store` for reactive data access
5. Show notifications for user feedback

## Special Directories

**tests/ Directory:**

- Purpose: Automated testing via testthat framework
- Generated: No (manual test files)
- Committed: Yes (essential for CI/CD)
- Structure: One test file per module (test_data_detection.R)
- Discovery: Files match `test_*.R` pattern
- Run: `testthat::test_dir("tests")` from R console

**data/ Directory:**

- Purpose: Test datasets and sample files
- Generated: Partially (create_sample_excel.R generates files)
- Committed: Yes (needed for reproducible testing)
- Contents: CSV/XLSX files with various frontmatter patterns
- Usage: Sample files tested with all detection algorithms

**.planning/ Directory:**

- Purpose: GSD orchestration artifacts
- Generated: Yes (auto-created by `/gsd:map-codebase`)
- Committed: Yes (documents codebase for future AI agents)
- Structure: Subdirectory `codebase/` with 7 markdown files
- Read by: `/gsd:plan-phase`, `/gsd:execute-phase` commands

**Root-level Utility Files:**

- `checkpoint.R`: Optional data integrity checking (not currently used)
- `clean_chems.R`, `clean_chems_2.R`: Experimental cleaning scripts
- `scrap.R`: Temporary exploration code

---

*Structure analysis: 2026-02-26*
