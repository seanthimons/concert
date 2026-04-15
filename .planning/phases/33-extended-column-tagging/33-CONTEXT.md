# Phase 33: Extended Column Tagging - Context

**Gathered:** 2026-04-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Extend the Tag Columns UI to support numeric/regulatory data columns and wire tag dispatch so each column type routes to its appropriate pipeline.

**Scope:**
1. Add new tag options: Result, Unit, Qualifier, Duration, DurationUnit, Species, ExposureRoute (UITG-01)
2. Partition tags by type and dispatch to appropriate pipelines (UITG-02)
3. Implement independent cascade resets for each tag type (UITG-03)

**Not in scope:**
- Harmonize tab UI (Phase 34)
- User-editable unit table (Phase 34)
- Export changes (Phase 35)

</domain>

<decisions>
## Implementation Decisions

### Tag Organization
- **D-01:** Use optgroups in selectInput to group tags by category:
  - Chemical: Name, CASRN, Other
  - Numeric: Result, Unit, Qualifier
  - Study: Duration, DurationUnit, Species, ExposureRoute
- **D-02:** Optgroups provide visual separation for scanning 10+ options

### Dispatch Mechanism
- **D-03:** Tag dispatch logic lives in `mod_tag_columns.R` (single source of truth)
- **D-04:** Apply Tags button partitions `column_tags` into three named lists in data_store:
  - `chemical_tags` — columns for cleaning + curation pipeline
  - `numeric_tags` — columns for harmonization pipeline
  - `metadata_tags` — columns for pass-through to ToxVal mapping
- **D-05:** Downstream modules read only their relevant subset (e.g., curation reads `chemical_tags`)

### Tag Type Classification
- **D-06:** Chemical tags: Name, CASRN, Other
- **D-07:** Numeric tags: Result, Unit, Qualifier, Duration, DurationUnit
- **D-08:** Metadata tags: Species, ExposureRoute (pass-through, no transformation)

### Cascade Reset Rules
- **D-09:** Independent cascade resets by tag type:
  - Chemical tag change → reset `curation_results`, `curation_report`, `consensus_data`, `resolution_state`, `qc_results`
  - Numeric tag change → reset `harmonize_results`, `harmonize_audit`
  - Either type change → reset `toxval_output`
  - Re-upload → reset everything (existing behavior)
- **D-10:** Reset is triggered on Apply Tags if the tag subset changed from previous value
- **D-11:** Store previous tag state to detect changes (compare old vs new `chemical_tags`, `numeric_tags`)

### Tag Validation
- **D-12:** Warning-only validation for unpaired Result/Unit tags
- **D-13:** Show yellow notification if Result tagged without Unit (or vice versa) on Apply Tags
- **D-14:** Allow proceeding — some datasets have unitless values (pH, ratios, counts)
- **D-15:** No hard blocking on tag combinations

### Claude's Discretion
- Exact optgroup labels and ordering
- Warning message wording
- Internal helper function organization
- Test case selection beyond requirements

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Current Implementation
- `R/mod_tag_columns.R` — existing tag columns module (modify)
- `inst/app/app.R` lines 252-264 — current cascade reset pattern
- `R/mod_run_curation.R` — example of reading `data_store$column_tags`

### Upstream Phase Context
- `.planning/phases/32-toxval-schema-mapper/32-CONTEXT.md` — column tag → ToxVal mapping (D-04)

### Requirements
- `.planning/REQUIREMENTS.md` — UITG-01, UITG-02, UITG-03 definitions

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `selectInput()` with `choices` as named list supports optgroups natively in Shiny
- Existing cascade reset pattern in `app.R` lines 252-264 can be extended
- `showNotification()` with `type = "warning"` for validation warnings

### Established Patterns
- `data_store$column_tags` is a named list (column → tag)
- Tag application triggers `get_dedup_preview()` for curation pipeline
- Tab gating uses reactive outputs (`has_data`, `tags_applied`)

### Integration Points
- `mod_tag_columns_server()` returns reactive list — extend with new tag subsets
- `app.R` observes tag changes for cascade resets
- Future `mod_harmonize.R` (Phase 34) will read `data_store$numeric_tags`

### Files to Modify
- `R/mod_tag_columns.R` — add optgroups, dispatch logic, validation
- `inst/app/app.R` — extend cascade reset observer

</code_context>

<specifics>
## Specific Ideas

### Optgroup Structure
```r
choices = list(
  "Chemical" = c(
    "Chemical Name" = "Name",
    "CASRN" = "CASRN",
    "Other" = "Other"
  ),
  "Numeric" = c(
    "Result Value" = "Result",
    "Unit" = "Unit",
    "Qualifier" = "Qualifier"
  ),
  "Study" = c(
    "Duration" = "Duration",
    "Duration Unit" = "DurationUnit",
    "Species" = "Species",
    "Exposure Route" = "ExposureRoute"
  )
)
```

### Tag Dispatch in Apply Tags Handler
```r
# Classify tags by type
chemical_types <- c("Name", "CASRN", "Other")
numeric_types <- c("Result", "Unit", "Qualifier", "Duration", "DurationUnit")
metadata_types <- c("Species", "ExposureRoute")

data_store$chemical_tags <- tags[tags %in% chemical_types]
data_store$numeric_tags <- tags[tags %in% numeric_types]
data_store$metadata_tags <- tags[tags %in% metadata_types]
```

### Validation Warning
```r
has_result <- "Result" %in% unlist(tags)
has_unit <- "Unit" %in% unlist(tags)
if (has_result && !has_unit) {
  showNotification(
    "Result tagged without Unit — harmonization will produce NA units.",
    type = "warning",
    duration = 5
  )
}
```

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 33-extended-column-tagging*
*Context gathered: 2026-04-15*
