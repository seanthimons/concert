# Phase 7: UI Polish - Research

**Researched:** 2026-03-01
**Domain:** DT/Shiny table customization, column visibility, badge rendering, Excel export
**Confidence:** HIGH

## Summary

Phase 7 enhances the existing Review Results DT table with better column visibility defaults, a colvis toggle button, color-coded badges for match_type and consensus_status, richer resolution dropdown context, error row highlighting, and Excel export flagging. All changes operate on the existing `output$curation_table` renderDT block in app.R (lines ~1379-1541) and the `get_resolution_options()` function in R/consensus.R.

The existing codebase already uses DT Buttons extension (`extensions = 'Buttons'`), `formatStyle()` for row backgrounds and consensus badge styling, `filter = "top"` for column filters, and HTML-in-cells for the Resolution dropdown. All Phase 7 features are incremental extensions of these existing patterns -- no new libraries or architectural changes needed.

**Primary recommendation:** Implement as a single plan modifying app.R's curation_table renderer and consensus.R's get_resolution_options(), plus the Excel export handler. All features are self-contained within these ~200 lines.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Hide untagged data columns by default -- users don't need to see columns they didn't tag
- Keep internal pipeline columns visible (source_tier_*, rank_*, preferredName_* per tag) -- users need this info to make resolution decisions
- Add DT Buttons colvis toggle so users can show/hide untagged columns on demand
- Pipeline internal columns (source_tier_*, rank_*, searchName_*) stay permanently hidden from colvis -- not useful for decision-making
- Excel export includes ALL columns (untagged, tagged, consensus, pipeline internals) -- full data preservation
- Dropdown options show: `DTXSID -- preferredName` (no rank or QC level)
- Options sorted by rank (best match first, lowest rank number)
- Agree rows display static text (`DTXSID -- Name` with checkmark), no dropdown
- Disagree rows include a "None" option for cases where user doesn't trust any result
- "Error" defined strictly as No Match rows (all tiers failed)
- Visual indicator: light red/pink row background highlight in Review Results table
- Excel export: dedicated `needs_review` column (TRUE/FALSE) -- machine-readable, filterable
- Only No Match rows flagged in Excel -- disagree rows are not flagged
- match_type column gets DT column filter dropdown with choices: Exact Match, CAS Lookup, Starts-With, No Match
- match_type values displayed as color-coded badges: green (Exact), blue (CAS), yellow (Starts-With), red (No Match)
- consensus_status column also gets color-coded badges: green (agree), orange (disagree), gray (single)
- consensus_status column also gets DT column filter dropdown (agree/disagree/single)
- Both columns use consistent badge visual language

### Claude's Discretion
- Exact badge styling (border-radius, padding, font weight)
- DT filter implementation details (initComplete callback vs column-specific options)
- Row highlight CSS specificity and color values
- ColVis button placement and label text

### Deferred Ideas (OUT OF SCOPE)
- Match type dropdown filtering was noted during Phase 6 UAT -- now captured as part of this phase
- Future: allow filtering/sorting by multiple columns simultaneously (beyond single column filters)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| UIPX-01 | Untagged columns hidden from Review Results table (still in Excel export) | Column visibility defaults + colvis button pattern |
| UIPX-02 | User can toggle column visibility via colvis button | DT Buttons extension colvis configuration |
| UIPX-03 | Resolution dropdown shows preferredName, rank, and QC level | get_resolution_options() enhancement + HTML formatting |
| UIPX-04 | Unresolved error rows flagged in Excel export as "needs manual review" | needs_review column in export handler |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| DT | 0.33+ | DataTables for R with Buttons extension | Already in use, provides colvis, formatStyle, filter |
| writexl | 1.5+ | Excel export | Already in use for download handler |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| htmltools | 0.5+ | HTML tag generation | Already loaded via shiny, for badge HTML if needed |

### Alternatives Considered
None -- all features use existing stack. No new packages needed.

## Architecture Patterns

### Pattern 1: Three-Tier Column Visibility

The existing code hides columns via `columnDefs = list(list(visible = FALSE, targets = hidden_indices))`. Phase 7 introduces three tiers:

1. **Always visible**: Original tagged columns, consensus_dtxsid, consensus_status, match_type, Resolution
2. **Hidden by default, colvis-toggleable**: Untagged original data columns (user's uploaded columns that weren't tagged)
3. **Permanently hidden**: Pipeline internals (source_tier_*, searchName_*, .pinned) -- excluded from colvis via `columns` parameter

**Implementation:**
```r
# Categorize columns
always_hidden <- c(
  grep("^source_tier_", names(df), value = TRUE),
  grep("^searchName_", names(df), value = TRUE),
  ".pinned"
)

# Untagged columns: original columns minus tagged ones
tagged_col_names <- names(data_store$column_tags)
untagged_cols <- setdiff(
  names(data_store$clean)[names(data_store$clean) %in% names(df)],
  tagged_col_names
)

# Colvis shows only toggleable columns (untagged data columns)
always_hidden_idx <- which(names(df) %in% always_hidden) - 1
untagged_idx <- which(names(df) %in% untagged_cols) - 1
all_hidden_idx <- c(always_hidden_idx, untagged_idx)

# Buttons config with colvis limited to toggleable columns
buttons = list(
  'copy', 'csv',
  list(
    extend = 'colvis',
    text = 'Toggle Columns',
    columns = untagged_idx  # Only untagged cols appear in colvis menu
  )
)

# columnDefs hides both permanently hidden and default-hidden
columnDefs = list(
  list(visible = FALSE, targets = as.list(all_hidden_idx))
)
```

### Pattern 2: Badge Rendering via JavaScript columnDefs

DT's `formatStyle()` applies CSS to cells but can't render HTML badges with background colors and text styling like `<span class="badge">`. Use `columnDefs` with a `render` callback instead:

```r
# In datatable options:
columnDefs = list(
  # Match type badges
  list(
    targets = match_type_col_idx,
    render = JS("function(data, type, row, meta) {
      if (type !== 'display') return data;
      var colors = {
        'Exact Match': '#28a745',
        'CAS Lookup': '#007bff',
        'Starts-With': '#ffc107',
        'No Match': '#dc3545'
      };
      var textColors = {
        'Starts-With': '#212529'
      };
      var bg = colors[data] || '#6c757d';
      var fg = textColors[data] || '#fff';
      return '<span style=\"background:' + bg + ';color:' + fg +
        ';padding:2px 8px;border-radius:4px;font-weight:600;font-size:0.85em;\">' +
        data + '</span>';
    }")
  )
)
```

**Why JS render instead of formatStyle:** `formatStyle()` sets CSS on the `<td>` element. It can set backgroundColor on the cell but can't create an inline badge element. JS render callbacks produce actual HTML content, giving proper badge appearance with rounded corners and padding.

**Alternative:** Pre-render badge HTML in R using `sapply()`, similar to how the Resolution column is built. This avoids JS but requires `escape = FALSE` on those columns. Since we already use `escape = FALSE`, this is also viable.

**Recommendation:** Use R-side HTML generation (sapply) for consistency with existing Resolution column pattern. Simpler to maintain.

### Pattern 3: DT Column Filters with factor columns

DT's `filter = "top"` auto-generates filter widgets. For factor columns, it creates a dropdown select. To get dropdown filters on match_type and consensus_status:

```r
# Convert to factor BEFORE passing to datatable()
df$match_type <- factor(df$match_type, levels = c("Exact Match", "CAS Lookup", "Starts-With", "No Match"))
df$consensus_status <- factor(df$consensus_status, levels = c("agree", "agree_caveat", "single", "disagree", "error"))
```

DT automatically renders factor columns as dropdown select filters. Already partially done for consensus_status (line 1386-1388). Just need to add match_type as factor.

### Pattern 4: Resolution Dropdown Enhancement

Current `get_resolution_options()` returns `list(col_name = dtxsid_value)`. The dropdown rendering in app.R (line 1447-1458) formats as `col_name: DTXSID`.

Enhancement: Include preferredName in display. The data already has `preferredName_*` columns in the resolution_state df:

```r
# In the dropdown rendering section of curation_table:
options <- get_resolution_options(df, i, dtxsid_cols)
if (length(options) > 0) {
  # Build options with preferredName context
  options_html <- sapply(names(options), function(col) {
    dtxsid <- options[[col]]
    # Get corresponding preferredName
    pref_col <- sub("^dtxsid_", "preferredName_", col)
    pref_name <- if (pref_col %in% names(df)) df[[pref_col]][i] else NA
    # Get rank
    rank_col <- sub("^dtxsid_", "rank_", col)
    rank_val <- if (rank_col %in% names(df)) df[[rank_col]][i] else NA

    label <- if (!is.na(pref_name)) {
      paste0(dtxsid, " \U2014 ", pref_name)
    } else {
      dtxsid
    }
    paste0('<option value="', col, '">', label, '</option>')
  })

  # Sort by rank (lowest first = best match)
  # ... rank sorting logic
}
```

### Anti-Patterns to Avoid
- **Don't use initComplete for filters:** DT's `filter = "top"` handles filter creation automatically. Using `initComplete` JS callbacks to manually build filters is fragile and duplicates DT's built-in feature.
- **Don't hide columns by removing them from the dataframe:** Use `columnDefs` visibility. Removing columns breaks `escape = FALSE` column index calculations and the Resolution dropdown's `data-row` indexing.
- **Don't use `escape = TRUE` with badge HTML:** The existing table uses `escape = FALSE` to render the Resolution dropdown. Badge HTML in match_type/consensus_status cells requires the same. Use per-column escape if needed: `escape = which(names(df) != "Resolution")` -- but since we're adding more HTML columns, just keep `escape = FALSE` globally and sanitize user data.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Column filter dropdowns | Custom JS filter widgets | DT `filter = "top"` + factor columns | DT generates dropdowns for factors automatically |
| Column visibility UI | Custom checkbox panel | DT Buttons `colvis` button | Standard DataTables feature, well-tested |
| Badge styling | Custom CSS framework | Inline styles in badge HTML | Keeps styling self-contained in the render, no external CSS dependencies |

## Common Pitfalls

### Pitfall 1: ColVis Shows All Columns Including Hidden Internals
**What goes wrong:** The `colvis` button by default shows ALL columns including `.pinned`, `source_tier_*`, etc.
**Why it happens:** ColVis defaults to listing every column in the table.
**How to avoid:** Use `columns` parameter in colvis button config to restrict which columns appear in the toggle menu.
**Warning signs:** Users see `.pinned` or `source_tier_exact_name` in the toggle dropdown.

### Pitfall 2: escape = FALSE with User Data
**What goes wrong:** Chemical names containing `<`, `>`, or `&` could break HTML or cause XSS.
**Why it happens:** `escape = FALSE` disables HTML escaping for ALL columns.
**How to avoid:** Use `htmltools::htmlEscape()` on user-provided data before embedding in HTML strings. Only Resolution/badge columns need raw HTML.
**Warning signs:** Table breaks when chemical name contains angle brackets.

### Pitfall 3: Column Index Mismatch Between R and JavaScript
**What goes wrong:** R uses 1-based indexing, DataTables JavaScript uses 0-based. Off-by-one errors in `columnDefs targets`.
**Why it happens:** `which()` returns 1-based, `targets` expects 0-based.
**How to avoid:** Always subtract 1: `which(names(df) %in% cols) - 1`. Already done in existing code (line 1480).
**Warning signs:** Wrong column gets hidden/styled.

### Pitfall 4: formatStyle Overriding Badge Cell Styles
**What goes wrong:** The existing `formatStyle('consensus_status', ...)` on line 1521-1538 sets cell-level backgroundColor. If we also render HTML badges inside the cell, the cell background fights with the badge background.
**Why it happens:** formatStyle applies to the `<td>`, badge HTML creates an inner `<span>` with its own background.
**How to avoid:** Remove the existing `formatStyle` for consensus_status cell background and rely solely on the badge HTML rendering. Keep the row-level formatStyle for row backgrounds.
**Warning signs:** Colored rectangle behind a colored badge creates visual noise.

### Pitfall 5: Factor Level Mismatch in Filters
**What goes wrong:** DT filter dropdown shows wrong options or filters don't work.
**Why it happens:** Factor levels don't match actual data values.
**How to avoid:** Ensure factor levels list ALL possible values, and values in data match levels exactly (case-sensitive).
**Warning signs:** Selecting a filter value shows no results.

## Code Examples

### ColVis Button with Column Restrictions
```r
datatable(
  df,
  extensions = 'Buttons',
  options = list(
    dom = 'Bfrtip',
    buttons = list(
      'copy', 'csv',
      list(
        extend = 'colvis',
        text = 'Toggle Columns',
        columns = c(2, 5, 8)  # 0-indexed: only these cols appear in toggle
      )
    ),
    columnDefs = list(
      list(visible = FALSE, targets = c(2, 5, 8))  # hidden by default
    )
  )
)
```
Source: https://datatables.net/reference/button/colvis

### Badge HTML Generation in R
```r
# Render match_type as colored badge
badge_html <- function(text, bg_color, text_color = "#fff") {
  sprintf(
    '<span style="background:%s;color:%s;padding:2px 8px;border-radius:4px;font-weight:600;font-size:0.85em;">%s</span>',
    bg_color, text_color, htmltools::htmlEscape(text)
  )
}

df$match_type_display <- sapply(df$match_type, function(mt) {
  switch(mt,
    "Exact Match" = badge_html(mt, "#28a745"),
    "CAS Lookup" = badge_html(mt, "#007bff"),
    "Starts-With" = badge_html(mt, "#ffc107", "#212529"),
    "No Match" = badge_html(mt, "#dc3545"),
    badge_html(mt, "#6c757d")
  )
})
```

### Enhanced Resolution Dropdown with preferredName
```r
# For agree rows: static display with checkmark
if (df$consensus_status[i] == "agree" || df$consensus_status[i] == "agree_caveat") {
  dtxsid <- df$consensus_dtxsid[i]
  # Find preferredName from any matching column
  pref_cols <- grep("^preferredName_", names(df), value = TRUE)
  pref_name <- NA
  for (pc in pref_cols) {
    if (!is.na(df[[pc]][i])) { pref_name <- df[[pc]][i]; break }
  }
  if (!is.na(pref_name)) {
    paste0("\U2705 ", htmltools::htmlEscape(dtxsid), " \U2014 ", htmltools::htmlEscape(pref_name))
  } else {
    paste0("\U2705 ", htmltools::htmlEscape(dtxsid))
  }
}
```

### Excel Export with needs_review Column
```r
export_data <- data_store$resolution_state %>%
  dplyr::mutate(
    needs_review = consensus_status == "error"
  ) %>%
  dplyr::select(-tidyselect::any_of(".pinned"))
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| ColVis extension | Buttons extension with colvis | DataTables 1.10+ (2015) | ColVis deprecated, use Buttons |
| Manual filter widgets | DT filter = "top" with factors | DT 0.4+ | Auto-generates appropriate filter UI |

## Open Questions

1. **Should "None" option in disagree dropdown set consensus_dtxsid to NA or a sentinel value?**
   - What we know: Current resolve_row() expects a valid column name
   - What's unclear: How to handle "None" selection in the existing resolution pipeline
   - Recommendation: Use a special sentinel value like `"__none__"` that resolve_row() recognizes, or add a separate handler in the input observer

## Sources

### Primary (HIGH confidence)
- Existing codebase: app.R lines 1379-1541 (curation_table renderDT), R/consensus.R (get_resolution_options)
- https://datatables.net/reference/button/colvis - ColVis button configuration
- https://rstudio.github.io/DT/extensions.html - DT Buttons extension
- https://rstudio.github.io/DT/options.html - DT options and formatting

### Secondary (MEDIUM confidence)
- https://datatables.net/extensions/buttons/examples/column_visibility/simple.html - Column visibility examples

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Already using DT with Buttons extension, no new libraries
- Architecture: HIGH - All patterns extend existing code in well-understood ways
- Pitfalls: HIGH - Based on direct codebase analysis of existing escape/formatting patterns

**Research date:** 2026-03-01
**Valid until:** 2026-04-01 (stable domain, DT API rarely changes)
