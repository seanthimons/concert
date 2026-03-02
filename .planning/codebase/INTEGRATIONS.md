# External Integrations

**Analysis Date:** 2026-02-26

## APIs & External Services

**Chemical Data & Validation:**
- **EPA Comptox Chemistry Dashboard** - Chemical identifier validation and lookup
  - SDK/Client: `ComptoxR` (custom R package)
  - Auth: `ctx_api_key` environment variable
  - Functions:
    - `ComptoxR::ct_search()` - Chemical name lookup and batch search
    - `ComptoxR::is_cas()` - Validate CAS number format
    - `ComptoxR::as_cas()` - Normalize CAS numbers
  - Request method: POST (for batch processing)
  - Usage location: `R/curation.R` lines 41-44, 113-122
  - Error handling: Curation fails with user notification if API key missing (`app.R` lines 927-934)
  - Search parameters:
    - `search_method`: "exact", "starts", or "contains"
    - Supports batch processing of chemical names

## Data Storage

**Databases:**
- **None** - Application is stateless
  - No persistent database backend
  - Data stored in user's local files (CSV, XLSX)
  - In-memory data store during session: `data_store <- reactiveValues()` (`app.R`)
  - Optional file hash tracking via checkpoint system (not enabled by default)

**File Storage:**
- **Local filesystem only**
  - Upload directory: Temporary Shiny upload directory (`shiny::parseFilePath()`)
  - Maximum file size: 50MB (configurable)
  - Supported formats: CSV, XLSX, XLS
  - Test data: `data/` directory (sample chemical files)
  - Output: User downloads cleaned data (no server-side persistence)

**Caching:**
- **None** - No caching layer
- **In-memory state**: `reactiveValues()` for current session only
- **Optional hash caching** via `checkpoint.R` (currently disabled, `deploy = FALSE` line 18)

## Authentication & Identity

**Auth Provider:**
- **Custom (Environment Variable)**
  - No user authentication system
  - API access controlled by `ctx_api_key` environment variable
  - Set at system level before launching app
  - Implementation: `Sys.getenv("ctx_api_key")` check

**Access Control:**
- None (no multi-user support)
- Application is single-session, self-contained
- Curation features require valid EPA Comptox API key

## Monitoring & Observability

**Error Tracking:**
- **None** - No error tracking service integrated
- Local error handling via `tryCatch()` and `purrr::safely()`
- File reading failures logged implicitly via `showNotification()`

**Logs:**
- **Console output** - Execution logs visible in R console
- **Approach**:
  - No persistent log file
  - User-facing notifications via `showNotification()` (`app.R` multiple locations)
  - Detection method results stored in session data (`all_results` field in detection output)
- **Example log points**:
  - File validation results (`R/file_handlers.R` line 196)
  - Detection method confidence scores (`R/data_detection.R` lines 314-316)
  - Curation status updates (`app.R` line 949)

**Debug Output:**
- Detection info tab shows:
  - All three detection method results and confidence scores
  - Metadata rows identified
  - Recommended header row

## CI/CD & Deployment

**Hosting:**
- **Not pre-configured** - Application ready for deployment to:
  - Shiny Server (open source)
  - RStudio Connect (enterprise)
  - Shinyapps.io (cloud)
  - Docker containerization (manual setup required)

**CI Pipeline:**
- **None** - No automated CI/CD configured
- **Testing**: Manual via `testthat::test_dir("tests")`
- **Code formatting**: Manual via `air` formatter

**Package Installation Pipeline:**
- **pak** handles automatic dependency resolution
- Binary repositories for Linux (if applicable)
- GitHub packages via `remotes::install_github()`

## Environment Configuration

**Required env vars:**
- **ctx_api_key** - EPA Comptox Chemistry Dashboard API key
  - Required for curation operations
  - If missing: Feature blocked with error notification

**Optional env vars:**
- None explicitly defined
- R-level options available:
  - `shiny.maxRequestSize` - Upload limit (default 50MB)

**Secrets location:**
- Environment variable (system-level)
- No `.env` file support (would need explicit loading)
- Credentials should NOT be committed to git (`.gitignore` should exclude `.env`)

## Webhooks & Callbacks

**Incoming:**
- **None** - Application does not receive webhooks

**Outgoing:**
- **None** - Application does not send webhooks or callbacks
- Data is pulled on-demand via ComptoxR API calls
- User manually initiates curation via "Run Curation" button (`app.R` line 923)

## Data Flow for Chemical Validation

**Sequence:**
1. User uploads CSV/XLSX file
   - File validated: `validate_file()` (`R/file_handlers.R` line 158)
   - Size check: 50MB limit
   - Extension check: .csv, .xlsx, .xls only

2. File read with fallback strategies
   - CSV: `read_csv_robust()` tries UTF-8 → Latin-1 → semicolon → tab → base R
   - Excel: `read_excel_robust()` via `readxl::read_excel()`
   - Result: Raw tibble with column names V1, V2, etc.

3. Frontmatter detection (3-method ensemble)
   - **Heuristic**: Row fill ratio analysis
   - **Pattern-based**: Keyword matching (chemistry-focused)
   - **Type consistency**: Column type stability check
   - Highest confidence method selected
   - Location: `R/data_detection.R` lines 275-331

4. Data extraction and cleaning
   - Header applied: `extract_clean_data()` (`R/data_detection.R` line 340)
   - Merged cells handled: `handle_merged_cells()` (`R/data_detection.R` line 386)
   - janitor cleaning: `clean_names()` + `remove_empty()`
   - Result: Clean tibble with snake_case headers

5. Optional curation (requires ComptoxR API key)
   - User tags columns as "Chemical Name" or "CASRN"
   - Triggers: `observeEvent(input$run_curation)` (`app.R` line 923)
   - For Name columns: `lookup_chemical_names()` → ComptoxR API call
   - For CAS columns: `validate_cas_numbers()` → ComptoxR validation
   - Results: DTXSID, preferred names, validation status
   - Location: `R/curation.R` lines 98-165

6. User download
   - Cleaned data exported via Shiny download handler
   - Format: CSV or Excel (user selectable)
   - No server-side storage

## API Request Patterns

**ComptoxR Chemical Lookup:**
```r
# From R/curation.R lines 41-44
results <- ComptoxR::ct_search(
  query = unique(clean_names),           # Chemical names or CAS numbers
  request_method = "POST",               # Batch processing for efficiency
  search_method = search_method          # "exact", "starts", or "contains"
)
```

**Expected Response Fields:**
- `dtxsid` - Unique Comptox identifier
- `preferredName` - EPA standard chemical name
- `casrn` - CAS Registry Number
- Match metadata for confidence scoring

**Error Handling:**
- Missing API key: Check `Sys.getenv("ctx_api_key")` (`app.R` line 927)
- Network failure: ComptoxR handles gracefully (tested via ComptoxR package error handling)
- No matches: Returns empty tibble with NA values (`R/curation.R` lines 49-57)

## Integration Points with External Systems

**File System Integration:**
- **Upload path**: R temp directory (managed by Shiny)
- **Output path**: User downloads (browser-managed)
- **Test data**: `data/` directory (local)
- **Sample file**: `uncurated_chemicals_2023-05-16_12-43-41.csv`

**Package Repository Integration:**
- **Installation source**: r-universe (ropensci, cran)
- **GitHub integration**: remotes for ComptoxR package
- **Fallback**: CRAN mirrors
- **Binary detection**: Automatic per OS/R version

**R Session Integration:**
- **Environment variable reading**: `Sys.getenv("ctx_api_key")`
- **Package discovery**: `requireNamespace()` for conditional loading
- **File system access**: `here::here()` for relative paths, `fs` for operations

---

*Integration audit: 2026-02-26*
