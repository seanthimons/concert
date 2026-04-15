# Phase 32: ToxVal Schema Mapper - Context

**Gathered:** 2026-04-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Create a schema mapper function that transforms ChemReg's curated and harmonized data into the 56-column ToxVal format with proper typed NAs and `*_original` audit columns.

**Scope:**
1. Expand `toxval_schema.rds` from 7 columns to full 56-column schema manifest
2. Create `map_to_toxval_schema()` function that outputs ToxVal-compatible tibble
3. Generate `*_original` audit columns for all harmonized fields
4. Ensure typed NA values throughout (`NA_character_`, `NA_real_`)

**Not in scope:**
- Parquet export (Phase 35)
- UI integration (Phase 34)
- Value lookups for hierarchical fields (supercategories)

</domain>

<decisions>
## Implementation Decisions

### Function Design
- **D-01:** Create `map_to_toxval_schema()` in new file `R/toxval_mapper.R` (exported function)
- **D-02:** Input signature: `map_to_toxval_schema(curated_data, harmonized_data, source_name = NULL)`
  - `curated_data` = output from curation pipeline (has dtxsid, casrn, name columns)
  - `harmonized_data` = output from harmonize_units() (has harmonized_value, harmonized_unit, orig_unit)
  - `source_name` = optional dataset identifier (defaults to "user_upload")
- **D-03:** Return full 56-column tibble with all ToxVal columns, using typed NAs for missing fields

### Column Mapping Strategy
- **D-04:** Static mapping table from ChemReg column tags to ToxVal column names:
  ```
  ChemReg Tag → ToxVal Column
  ─────────────────────────────
  dtxsid → dtxsid
  casrn → casrn
  name → name
  Result (harmonized) → toxval_numeric
  Unit (harmonized) → toxval_units
  Qualifier → qualifier
  Species → species_common
  Duration → study_duration_value
  DurationUnit → study_duration_units
  ExposureRoute → exposure_route
  ToxvalType → toxval_type
  ```
- **D-05:** Unmapped ToxVal columns receive typed NA values based on schema types

### Source Identity Fields
- **D-06:** `source` column = `source_name` parameter (or "user_upload" default)
- **D-07:** `sub_source` = NA_character_ (user can populate later)
- **D-08:** `source_hash` = SHA256 of concatenated row values (matches existing ToxVal convention)
- **D-09:** `source_url` = NA_character_ (user can populate later)

### Original Audit Columns
- **D-10:** Generate `*_original` column for every harmonized field:
  - `toxval_numeric_original` = pre-harmonization numeric value (from `orig_result` column)
  - `toxval_units_original` = pre-harmonization unit string (from `orig_unit` column)
  - `study_duration_value_original` = raw duration value
  - etc.
- **D-11:** If source data has no transformation (identity mapping), `*_original` = same as harmonized value
- **D-12:** Capture originals from earliest possible state (before any cleaning/normalization)

### Typed NA Strategy
- **D-13:** Character columns → `NA_character_`
- **D-14:** Numeric columns (DOUBLE) → `NA_real_`
- **D-15:** No bare `NA` anywhere in output tibble
- **D-16:** Verify via `stopifnot(all(vapply(result, typeof, "") != "logical"))` assertion

### Schema Manifest Expansion
- **D-17:** Replace current 7-column `toxval_schema.rds` with full 56-column schema
- **D-18:** Schema manifest is zero-row tibble with correct column types (validation template)
- **D-19:** Column order matches ToxVal database exactly (for parquet compatibility)

### Hierarchical Fields (Supercategories)
- **D-20:** Leave supercategory columns as NA_character_:
  - `toxval_type_supercategory`
  - `species_supercategory`
  - `toxicological_effect_category`
- **D-21:** Defer value lookups to future phase (Phase 34 or v2+)

### QC Fields
- **D-22:** `qc_category` = "user_curated"
- **D-23:** `qc_status` = "pass" if no blocking flags, "review" if any warning flags

### Study Metadata
- **D-24:** Study metadata columns (year, study_type, study_duration_class, etc.) populated from tagged columns when available, NA otherwise
- **D-25:** `study_duration_class` derivation deferred (requires duration classification lookup)

### Claude's Discretion
- Internal helper function organization
- Exact hashing algorithm for source_hash (SHA256 recommended)
- Test case selection beyond requirements
- Column ordering within mapping table
- Error message wording

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### ToxVal Schema (authoritative)
- ToxVal database: `C:/Users/sxthi/AppData/Roaming/R/data/R/ComptoxR/toxval.duckdb`
- Table: `toxval` (56 columns)
- Query: `SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'toxval'`

### Upstream Phases
- Phase 31.5: `R/unit_harmonizer.R` — `harmonize_units()` output structure
- Phase 30: `R/numeric_result_parser.R` — `parse_numeric_results()` output structure
- Phase 29: `inst/extdata/reference_cache/toxval_schema.rds` — current placeholder (to be expanded)

### Existing Patterns
- `R/cleaning_reference.R` — reference data loading pattern
- `R/consensus.R` — `enrich_candidates()` for adding metadata columns to tibbles
- `R/curation.R` — pipeline orchestration pattern

</canonical_refs>

<code_context>
## Existing Code Insights

### ToxVal Schema (56 columns)
From database query:
```
 1. dtxsid                         VARCHAR
 2. casrn                          VARCHAR
 3. name                           VARCHAR
 4. source                         VARCHAR
 5. sub_source                     VARCHAR
 6. toxval_type                    VARCHAR
 7. toxval_subtype                 VARCHAR
 8. toxval_type_supercategory      VARCHAR
 9. qualifier                      VARCHAR
10. toxval_numeric                 DOUBLE
11. toxval_units                   VARCHAR
12. risk_assessment_class          VARCHAR
13. study_type                     VARCHAR
14. study_duration_class           VARCHAR
15. study_duration_value           DOUBLE
16. study_duration_units           VARCHAR
17. species_common                 VARCHAR
18. strain                         VARCHAR
19. latin_name                     VARCHAR
20. species_supercategory          VARCHAR
21. sex                            VARCHAR
22. generation                     VARCHAR
23. lifestage                      VARCHAR
24. exposure_route                 VARCHAR
25. exposure_method                VARCHAR
26. exposure_form                  VARCHAR
27. media                          VARCHAR
28. toxicological_effect           VARCHAR
29. toxicological_effect_category  VARCHAR
30. experimental_record            VARCHAR
31. study_group                    VARCHAR
32. year                           DOUBLE
33. qc_category                    VARCHAR
34. qc_status                      VARCHAR
35. source_hash                    VARCHAR
36. source_url                     VARCHAR
37. subsource_url                  VARCHAR
38. toxval_type_original           VARCHAR
39. toxval_subtype_original        VARCHAR
40. toxval_numeric_original        DOUBLE
41. toxval_units_original          VARCHAR
42. study_type_original            VARCHAR
43. study_duration_class_original  VARCHAR
44. study_duration_value_original  DOUBLE
45. study_duration_units_original  VARCHAR
46. species_original               VARCHAR
47. strain_original                VARCHAR
48. sex_original                   VARCHAR
49. generation_original            VARCHAR
50. lifestage_original             VARCHAR
51. exposure_route_original        VARCHAR
52. exposure_method_original       VARCHAR
53. exposure_form_original         VARCHAR
54. media_original                 VARCHAR
55. toxicological_effect_original  VARCHAR
56. original_year                  DOUBLE
```

### Reusable Assets
- `digest::digest()` for SHA256 hashing
- `tibble::tibble()` with explicit column types
- Existing audit trail pattern from curation pipeline

### Files to Create/Modify
- `R/toxval_mapper.R` — (new) main mapper function
- `inst/extdata/reference_cache/toxval_schema.rds` — expand to 56 columns
- `tests/testthat/test-toxval-mapper.R` — (new) test file

</code_context>

<specifics>
## Specific Ideas

### Mapper Function Skeleton
```r
#' Map curated data to ToxVal schema
#'
#' Transforms ChemReg's curated and harmonized data into the 56-column
#' ToxVal-compatible format with typed NAs and *_original audit columns.
#'
#' @param curated_data Tibble from curation pipeline (dtxsid, casrn, name)
#' @param harmonized_data Tibble from harmonize_units() (harmonized_value, harmonized_unit)
#' @param source_name Dataset identifier (default: "user_upload")
#' @return Tibble with 56 ToxVal columns
#' @export
map_to_toxval_schema <- function(curated_data, harmonized_data, source_name = NULL) {
  # Load schema template
  schema <- load_toxval_schema()

  # Map columns from input to schema
  result <- tibble::tibble(
    dtxsid = curated_data$dtxsid %||% NA_character_,
    casrn = curated_data$casrn %||% NA_character_,
    # ... (all 56 columns)
  )

  # Generate source_hash
  result$source_hash <- generate_source_hash(result)

  # Verify typed NAs
  assert_typed_nas(result)

  result
}
```

### Schema Template Update
```r
# Expand toxval_schema.rds to full 56 columns with typed NAs
toxval_schema <- tibble::tibble(
  dtxsid = NA_character_,
  casrn = NA_character_,
  name = NA_character_,
  source = NA_character_,
  # ... all 56 columns with correct types
  original_year = NA_real_
)[0, ]  # Zero rows, typed columns
```

</specifics>

<deferred>
## Deferred Ideas

### Future Phases
- **Phase 33:** Extended column tagging UI will provide more input columns to map
- **Phase 34:** Harmonize tab will wire the mapper into the UI
- **Phase 35:** Parquet export will use mapper output

### v2+ Enhancements
- Supercategory derivation (toxval_type → toxval_type_supercategory)
- Species taxonomy lookup (species_common → latin_name, species_supercategory)
- Duration classification (study_duration_value → study_duration_class)
- Batch validation against ToxVal controlled vocabularies

</deferred>

---

*Phase: 32-toxval-schema-mapper*
*Context gathered: 2026-04-15*
