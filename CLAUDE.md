# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ChemReg is a Shiny application for uploading, cleaning, and validating chemical inventory data with intelligent frontmatter detection. It automatically detects where actual data begins in messy CSV/XLSX files, filtering out report headers, metadata, and other frontmatter.

## Development Commands

### Running the Application

```r
# Start the Shiny app
shiny::runApp()

# Or from command line (useful for live reload during development)
Rscript -e "shiny::runApp('app.R')"
```

### Package Management

```r
# Install all required packages
source("load_packages.R")

# The load_packages.R script uses pak for efficient package installation
# and supports Linux binary repositories for faster installation
```

### Testing

```r
# Run all unit tests
source("load_packages.R")
testthat::test_dir("tests")

# Or run test file directly
source("tests/test_data_detection.R")
```

**Shiny cold boot test is mandatory.** After any change that touches the Shiny app (UI modules, server logic, reactive state, app.R), verify the app starts cleanly from a fresh R session (`chemreg::run_app()`) before considering the work done. This catches missing imports, load-order issues, and broken reactive wiring that unit tests won't surface.

### Code Formatting

The project uses `air` for R code formatting with configuration in `air.toml`:
- Line width: 120 characters
- Indent: 2 spaces
- Auto line endings

## Git Workflow

### Commit Strategy

**Commit iteratively** as you make progress on tasks:

- **After each logical unit of work**: Commit when you complete a meaningful change (e.g., "Add merged cell detection to heuristic method", "Fix file validation for large Excel files")
- **After implementing a function or feature**: Commit when a new function is complete and tested
- **After fixing a bug**: Commit immediately after verifying the fix works
- **After refactoring**: Commit after restructuring code while tests still pass
- **Before switching contexts**: Commit current work before moving to a different task

**Commit message format:**
```
Brief summary of change (50 chars or less)

More detailed explanation if needed:
- What changed
- Why it changed
- Any side effects or considerations

```

### Branch Strategy

**Use feature branches** for all non-trivial work:

**When to create a feature branch:**
- Adding new features (e.g., `feature/cas-number-validation`)
- Major refactoring (e.g., `refactor/detection-ensemble`)
- Experimental changes (e.g., `experiment/machine-learning-detection`)
- Bug fixes (e.g., `fix/excel-encoding-issue`)

**When to work on main:**
- Quick documentation updates
- Typo fixes
- Very minor changes that don't affect functionality

**Branch naming conventions:**
```
feature/<descriptive-name>  # New features
fix/<issue-description>     # Bug fixes
refactor/<component-name>   # Code refactoring
test/<test-description>     # Adding/updating tests
docs/<doc-description>      # Documentation updates
experiment/<idea>           # Experimental/exploratory work
```

**Workflow example:**
```bash
# Create and switch to feature branch
git checkout -b feature/pattern-detection-improvements

# Make changes, test, and commit iteratively
git add R/data_detection.R tests/test_data_detection.R
git commit -m "Add regex support to pattern detection"

# Continue working with multiple commits
git commit -m "Add tests for regex patterns"
git commit -m "Update documentation for new pattern syntax"

# When feature is complete, push branch
git push -u origin feature/pattern-detection-improvements

# Create PR or merge to main when ready
```

**Development vs Production:**
- Consider using a `dev` branch for integration of multiple features before merging to `main`
- Keep `main` stable and deployable at all times
- Use feature branches that branch off and merge back to `dev`
- Periodically merge `dev` to `main` for releases

## Architecture

### Core Application Structure

**app.R** (Main Entry Point)
- Shiny UI/Server definition using `bslib` page_sidebar layout
- Three main tabs: Data Preview, Detection Info, Raw Data
- Reactive data store pattern for state management
- File upload with 50MB limit (configurable via `options(shiny.maxRequestSize)`)

**Data Flow:**
1. File Upload → Validation (`validate_file`)
2. Raw Read → Multiple fallback strategies (`safely_read_file`)
3. Frontmatter Detection → Ensemble of 3 algorithms (`detect_data_start`)
4. Data Extraction → Clean headers and rows (`extract_clean_data`)
5. Post-processing → Merged cell handling, janitor cleaning (`handle_merged_cells`)

### Helper Modules

**R/file_handlers.R**
- `safely_read_file()`: Multi-strategy file reading (rio → readxl/readr fallbacks)
- `validate_file()`: Pre-upload validation (extension, size checks)
- `calculate_smart_preview_rows()`: Dynamic preview sizing based on file size
- `format_file_size()`: Human-readable file size formatting

**R/data_detection.R** (Core Detection Logic)

Three detection algorithms that run in ensemble:

1. **Heuristic Method** (`detect_data_start_heuristic`)
   - Analyzes row fill ratios (% non-empty cells)
   - Looks for consistent data regions
   - Assumes header is row before high-fill-ratio data
   - Key params: `min_filled_ratio = 0.7`, `min_cols = 3`

2. **Pattern Matching** (`detect_pattern_based`)
   - Searches for chemistry-specific keywords (CAS, formula, hazard, etc.)
   - Scores each row based on keyword matches
   - Optimized for chemical inventory headers
   - Keyword list in function definition

3. **Type Consistency** (`detect_by_type_consistency`)
   - Checks if rows after candidate header have consistent types
   - Scans up to 50 rows (`scan_rows` parameter)
   - Looks for numeric/text consistency per column

**Ensemble Selection** (`detect_data_start`)
- Runs all three methods with `purrr::safely()` error handling
- Selects method with highest confidence score
- Returns metadata rows, header row, data start row, and all method results
- Manual override available via `mode = "manual"` parameter

### State Management

The app uses `reactiveValues()` data store pattern:
```r
data_store <- reactiveValues(
  raw = NULL,      # Original uploaded data frame
  clean = NULL,    # Processed data with proper headers
  detection = NULL,# Detection results (method, confidence, rows)
  file_info = NULL # File metadata (name, size)
)
```

### Detection Mode Switching

The app supports two modes:
- **Automatic**: Runs ensemble detection algorithms
- **Manual**: User specifies header row number directly

When detection mode or manual row changes, the app:
1. Re-runs detection on stored raw data
2. Re-extracts clean data
3. Updates reactive data store
4. UI automatically updates via reactive outputs

### Post-Processing Pipeline

After detection, data goes through:
1. `extract_clean_data()`: Extracts rows and applies detected headers
2. `handle_merged_cells()`: Fills down first column if merged cell pattern detected
3. `janitor::clean_names()`: Converts headers to snake_case
4. `janitor::remove_empty()`: Removes empty rows and columns

## Key Configuration Points

### File Upload Limits
In `app.R`, line 12-14:
```r
options(shiny.maxRequestSize = 50 * 1024^2)  # 50MB default
```

### Detection Sensitivity
In `R/data_detection.R`:
- `min_filled_ratio = 0.7`: Minimum fill ratio for heuristic method (line 11)
- `min_cols = 3`: Minimum filled columns required (line 11)
- `scan_rows = 50`: Type consistency scan depth (line 185)

### Preview Defaults
In `R/file_handlers.R`, `calculate_smart_preview_rows()` (lines 102-112):
- ≤100 rows → preview 50
- ≤1000 rows → preview 25
- >1000 rows → preview 10

## Testing Structure

**tests/test_data_detection.R**
- 11 test cases covering all detection methods
- Tests for clean files, frontmatter, empty files, manual override
- Tests for merged cells, validation, smart preview calculation
- Uses synthetic chemical data (Acetone, Ethanol, CAS numbers)
- Run with `testthat::test_dir("tests")`

## Data Checkpoint System

**checkpoint.R** (Optional infrastructure file)
- Not currently used by main app
- Provides hash-based integrity checking for raw data files
- Configuration via config list (raw_dir, hash_file, max_age_days, file_pattern)
- Three integrity checks:
  1. File existence (gross check)
  2. File age validation (max_age_days threshold)
  3. Hash integrity (missing/new/changed files via MD5)
- Interactive rebuild prompts or automatic rebuild in non-interactive mode
- Uses `digest` for file hashing, `cli` for formatted output

## Package Dependencies

Core packages (always loaded):
- **Shiny stack**: shiny, bslib, bsicons, DT, shinyjs
- **File I/O**: rio, readxl, writexl, janitor
- **Tidyverse**: dplyr, purrr, tidyr, stringr, readr, tibble
- **Utilities**: here, fs, digest
- **Testing**: testthat

The `load_packages.R` script:
- Auto-installs `pak` if not present
- Uses r-universe Linux binary repos for faster installation (line 17-22)
- Defines custom `%ni%` operator (Negate `%in%`)
- Auto-generates `air.toml` if not present (line 246-261)

## Development Notes

### When Modifying Detection Algorithms

1. Add new detection methods in `R/data_detection.R`
2. Return list with: `header_row`, `data_start_row`, `method`, `confidence`
3. Add method to ensemble in `detect_data_start()` function
4. Write corresponding tests in `tests/test_data_detection.R`
5. Test with sample files in `data/` directory

### When Adding New File Format Support

1. Add extension to `validate_file()` allowed_extensions (R/file_handlers.R:134)
2. Add fallback reading strategy in `safely_read_file()` (R/file_handlers.R:10)
3. Update fileInput accept parameter in app.R:45

### Common Chemistry Keywords

The pattern matcher recognizes (R/data_detection.R:125-136):
- Chemical identifiers: chemical, cas, formula, molecular, structure, compound, substance, reagent, solvent
- Safety: hazard, safety, ghs, sds, msds
- Quantity: quantity, qty, mass, volume, concentration, purity, grade
- Metadata: supplier, manufacturer, storage, location, expiry, batch, lot

### UI Theme Customization

The app uses bslib with Flatly bootswatch theme (app.R:22-26):
```r
theme = bs_theme(
  version = 5,
  bootswatch = "flatly",
  primary = "#007bff"
)
```

## Error Handling Patterns

The codebase uses consistent error handling:
- `purrr::safely()` for detection methods (prevents one method failure from crashing ensemble)
- `tryCatch()` with fallbacks in file reading
- Validation before processing (file type, size, dataframe structure)
- Graceful degradation (fallback detection if all methods fail)
- User notifications for all error states (via `showNotification()`)

## R Performance Patterns

The cleaning pipeline processes datasets with 100k+ rows. Avoid these anti-patterns that cause O(n²) or worse performance:

### Growing-List Pattern (O(n²) memory allocation)

**BAD** - List grows inside loop, causing repeated memory reallocation:
```r
audit_rows <- list()
for (idx in seq_len(nrow(df))) {
  audit_rows[[length(audit_rows) + 1]] <- tibble::tibble(row_id = idx, ...)
}
dplyr::bind_rows(audit_rows)
```

**GOOD** - Pre-allocate vectors, build single tibble at end:
```r
all_row_ids <- integer()
all_values <- character()
for (col_name in cols) {
  changed_idx <- which(original != cleaned)
  all_row_ids <- c(all_row_ids, changed_idx)
  all_values <- c(all_values, original[changed_idx])
}
tibble::tibble(row_id = all_row_ids, value = all_values)
```

### Regex Compilation Inside Loops (O(n×m) compilation overhead)

**BAD** - Regex compiled on every iteration:
```r
for (idx in seq_len(nrow(df))) {
  for (term in terms) {
    pattern <- stringr::regex(paste0("\\b", term, "\\b"), ignore_case = TRUE)
    stringr::str_detect(df$col[idx], pattern)
  }
}
```

**GOOD** - Pre-compile all patterns once, use vectorized detection:
```r
compiled_patterns <- lapply(terms, function(term) {
  stringr::regex(paste0("\\b", term, "\\b"), ignore_case = TRUE)
})
for (pattern in compiled_patterns) {
  matches <- stringr::str_detect(df$col, pattern)  # vectorized over entire column
}
```

### Row-by-Row Loops When Vectorization Is Possible

**BAD** - Scalar operations in loop:
```r
for (idx in seq_len(nrow(df))) {
  if (!is.na(df$col[idx]) && df$col[idx] != "") {
    df$result[idx] <- "flagged"
  }
}
```

**GOOD** - Vectorized comparison and assignment:
```r
to_flag <- which(!is.na(df$col) & df$col != "")
df$result[to_flag] <- "flagged"
```

### Scalar Column Assignment (copy-on-modify)

**BAD** - Each assignment copies the entire column:
```r
for (idx in seq_len(nrow(df))) {
  df$col[idx] <- new_value  # triggers copy-on-modify each iteration
}
```

**GOOD** - Batch updates or work on extracted vector:
```r
col_values <- df$col
col_values[changed_indices] <- new_values
df$col <- col_values
```

### Audit Trail Building in Cleaning Functions

All cleaning functions in `R/cleaning_pipeline.R` return `list(cleaned_data, audit_trail)`. Use this pattern:

```r
my_cleaning_function <- function(df, cols) {
  df_result <- df

  # Pre-allocate audit vectors (not a list of tibbles)
  audit_row_ids <- integer()
  audit_fields <- character()
  audit_originals <- character()
  audit_news <- character()

  for (col_name in cols) {
    original_vals <- df[[col_name]]
    cleaned_vals <- some_vectorized_operation(original_vals)

    # Vectorized change detection
    changed_idx <- which(!is.na(original_vals) & !is.na(cleaned_vals) & original_vals != cleaned_vals)

    if (length(changed_idx) > 0) {
      df_result[[col_name]] <- cleaned_vals

      # Batch append to vectors
      audit_row_ids <- c(audit_row_ids, as.integer(changed_idx))
      audit_fields <- c(audit_fields, rep(col_name, length(changed_idx)))
      audit_originals <- c(audit_originals, original_vals[changed_idx])
      audit_news <- c(audit_news, cleaned_vals[changed_idx])
    }
  }

  # Single tibble construction at end
  audit_trail <- tibble::tibble(
    row_id = audit_row_ids,
    field = audit_fields,
    step = rep("my_step", length(audit_row_ids)),
    original_value = audit_originals,
    new_value = audit_news,
    reason = paste0("Cleaned ", audit_fields)
  )

  list(cleaned_data = df_result, audit_trail = audit_trail)
}
