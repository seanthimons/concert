# Feature Landscape: Data Curation Refinement

**Domain:** Chemical inventory data curation tools
**Researched:** 2026-03-01

## Table Stakes

Features users expect. Missing = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Error row filtering/isolation | Standard in data validation UX; users expect ability to focus on problems | Low | Filter by consensus status = "error" already exists in codebase |
| Column visibility toggle | Universal table feature; messy chemical data has many columns users don't care about | Low | DataTables built-in, R DT package supports via colvis extension |
| Manual identifier entry | Standard fallback when automated matching fails | Medium | Single-row input straightforward, bulk validation adds complexity |
| Inline edit for corrections | Expected in modern data grids; users fix typos without re-upload | Medium-High | DT editable cells via JS callback, Shiny reactive handling, validation loop |
| Error feedback specificity | Users expect to know WHY validation failed (bad format, no match, API error) | Low-Medium | Already have error status; need to expose error messages from CompToxR |
| Bulk validation | Avoid round-trip API calls for each manual entry | Medium | CompTox Batch Search supports up to thousands of identifiers at once |
| Subset retry | Industry standard for large datasets; re-run failed items without full reprocess | Medium | Filter → modify → re-run subset → merge back pattern |
| Persistent user preferences | Column visibility choices should survive tab switches within session | Low-Medium | Session-scoped reactive value, reset only on new file upload |

## Differentiators

Features that set product apart. Not expected, but valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Smart column hiding (auto-hide untagged) | Reduces cognitive load; most tools require manual toggle | Low | Single checkbox "Hide untagged columns" + reactive filter |
| Re-tag before retry | Unique workflow: realize column was mis-tagged, fix tag assignment, retry just errors | Medium | Tag changes normally cascade-reset curation; need subset-only invalidation |
| Retry with search tier override | Power user feature: force exact-only or skip CAS validation for specific rows | High | Requires per-row or per-batch search strategy parameter |
| Contextual resolution dropdown | Show preferredName + QC level + rank in dropdown, not just DTXSID | Low-Medium | Data already available from curation results; format for display |
| Validation preview before commit | Show what WILL happen with manual DTXSIDs before actually replacing consensus | Medium | Two-step UX: validate → preview changes → commit |
| Audit trail for manual overrides | Track which rows were manually curated vs auto-matched | Low | Add column to results: source = "auto" \| "manual" \| "retry" |

## Anti-Features

Features to explicitly NOT build.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Inline edit of every cell | Scope creep; this is curation not general spreadsheet editing | Only enable editing for identifier columns used in retry |
| Real-time validation during typing | Too many API calls; CompTox has rate limits | Validate on explicit button click or batch validation |
| Automatic retry on errors | Wastes API quota; many errors are unfixable (bad data, not in database) | User-initiated retry with optional re-tagging |
| Save partial work / session persistence | High complexity; Shiny session state management fragile across page refresh | Clear workflow expectation: one session = one file = one export |
| Unlimited undo/redo | Not a general editor; linear workflow with explicit re-run steps | Allow cascade-reset (re-tag invalidates curation) but not granular undo |
| Custom search tier configuration | Over-engineering; 99% of users fine with exact → CAS → starts-with order | Hard-code tier order based on research findings |
| Row-level search tier override | Too granular; adds UI complexity for edge case | Batch retry with re-tag covers use case (change column assignment) |

## Feature Dependencies

```
Error row filtering → Subset selection for retry
  ↓
Subset selection → Re-tag (optional) → Re-run curation → Merge back
  ↓
Merge back → Updated consensus → Resolution dropdown (if new conflicts)

Manual DTXSID entry → Bulk validation API call → Validation results display
  ↓
Validation results → User confirms → Update consensus (replace "error" rows)

Column visibility toggle → User preferences (session-scoped)
  ↓
Preferences persist across tab switches → Reset on new file upload

Contextual resolution dropdown → Richer display (preferredName, QC, rank)
  ↓
Still produces DTXSID selection → Consensus update (existing flow)
```

## MVP Recommendation

### Phase 1: Low-hanging fruit (already have primitives)
1. **Column visibility toggle** — DT extension, session reactive value
2. **Smart hide untagged** — Filter untagged columns from display table
3. **Error feedback specificity** — Expose CompToxR error messages in UI
4. **Contextual resolution dropdown** — Format existing data in dropdown

### Phase 2: Core value adds
5. **Manual DTXSID entry** — Single input field for error rows
6. **Bulk validation** — CompTox Batch Search API for multiple manual entries
7. **Validation preview** — Show proposed changes before commit

### Phase 3: Advanced workflows
8. **Subset retry** — Filter errors → re-run → merge back
9. **Re-tag before retry** — Invalidate only selected rows, not full cascade
10. **Audit trail** — Track manual vs auto curation source

Defer:
- **Inline editing** — High complexity, marginal value over manual entry + retry
- **Retry with search tier override** — Power user feature, defer until demand proven
- **Persistent preferences across sessions** — Complexity not justified by value

## Implementation Notes

### Column Visibility (Table Stakes)

**Standard pattern:** Checkbox list or dropdown menu toggles column display.

**Best practice:** User preferences override defaults and persist within session (not across page refresh).

**DT/DataTables support:** Built-in `colvis` extension provides button + modal with column checkboxes.

**ChemReg context:** Already use DT package; add `extensions = 'ColVis'` to `DT::datatable()` options.

**Complexity:** LOW — framework primitive + reactive preference storage.

### Smart Hide Untagged (Differentiator)

**Pattern:** Automatically hide columns user hasn't marked as relevant.

**ChemReg context:** Users tag columns as "Name", "CASRN", or "Other". Untagged columns are irrelevant to curation (e.g., storage location, quantity).

**Implementation:** Single checkbox "Hide untagged columns" → reactive filter on column list → update DT visible columns.

**Edge case:** If ALL columns untagged, show all (empty table confusing).

**Complexity:** LOW — boolean filter + DT column visibility API.

### Manual DTXSID Entry (Table Stakes)

**Standard pattern:** Inline edit or modal dialog for single value entry.

**Bulk variant:** CSV paste, multi-line textarea, or file upload for many identifiers.

**Validation requirement:** Check format (DTXSID + 9 digits) + verify exists in CompTox.

**ChemReg context:** Error rows have no valid DTXSID. User knows correct identifier (from external source, manual lookup).

**UI options:**
1. **Modal dialog** — Click error row → modal with input field → validate → update
2. **Inline edit** — Click cell → editable → validate on blur
3. **Bulk paste** — Textarea accepts multiple DTXSIDs (one per line or comma-separated)

**Recommendation:** Start with modal (simpler state management), add bulk paste for scale.

**Complexity:** MEDIUM — UI straightforward, validation API + reactivity adds complexity.

### Bulk Validation (Table Stakes)

**Why necessary:** CompTox API has rate limits. Validating 100 manual entries one-by-one = slow + wasteful.

**CompTox support:** Batch Search accepts up to thousands of identifiers (DTXSID, CASRN, InChIKey, chemical name).

**Response format:** Returns matched records with DTXSID, preferredName, CASRN, molecular formula, etc.

**Validation logic:**
- Valid format? (DTXSID = `DTXSID[0-9]{9}`)
- Exists in CompTox? (Batch Search returns match)
- If no match → error, user must correct

**ChemReg context:** User enters multiple DTXSIDs (via bulk paste or repeated modal entries). Before committing, validate all against CompTox in single API call.

**Complexity:** MEDIUM — API call batching + error handling.

### Subset Retry (Table Stakes)

**Pattern:** Filter failed rows → modify inputs → re-run processing → merge results back.

**Industry standard:** AWS DMS, Databricks CDC pipelines, ETL tools all support partial retry.

**Key requirements:**
1. **Idempotency** — Retry doesn't duplicate data
2. **Merge safety** — Results replace original rows, not append
3. **Validation** — Ensure row identifiers match (avoid wrong-row updates)

**ChemReg context:** User filters to error rows → optionally re-tags columns → re-runs curation on subset → results merge back (replace consensus for those rows).

**Merge strategy:** Use row index or unique key (e.g., original row number from uploaded file).

**Complexity:** MEDIUM — Filter + run curation subset straightforward; merge-back logic needs careful testing.

### Re-tag Before Retry (Differentiator)

**Use case:** User realizes "Compound Name" column was mis-tagged as "Other". Errors occurred because name column wasn't searched. Fix tag → retry just the errors.

**Current behavior:** Tag change cascade-resets ALL curation results (conservative, prevents stale state).

**Desired behavior:** Tag change invalidates only SELECTED rows for retry, preserves rest.

**Implementation challenge:** Reactive cascade currently all-or-nothing. Need subset-scoped invalidation.

**Alternative approach:** Copy error rows to separate "retry workspace" → re-tag columns in workspace → run curation → merge back. Avoids partial invalidation complexity.

**Complexity:** MEDIUM (subset invalidation) or LOW (workspace copy pattern).

**Recommendation:** Workspace copy pattern simpler, clearer UX.

### Validation Preview (Differentiator)

**Pattern:** Two-step commit — show what WILL change, user confirms before applying.

**Why valuable:** Manual override is risky (wrong DTXSID = corrupted data). Preview prevents mistakes.

**ChemReg context:** User enters DTXSIDs for error rows → validate → show table of proposed changes → user reviews → clicks "Apply" to commit.

**Preview table columns:**
- Row identifier (e.g., row number, chemical name from original data)
- Current consensus status ("error")
- Proposed DTXSID (user-entered)
- Validation status (valid / invalid / not found)
- CompTox metadata (preferredName, CASRN for verification)

**Complexity:** MEDIUM — Requires temporary state (proposed changes not yet committed) + UI for review.

### Contextual Resolution Dropdown (Differentiator)

**Current state:** Dropdown shows raw DTXSIDs (e.g., "DTXSID1020001", "DTXSID5023847").

**Problem:** Users can't tell which is correct without external lookup.

**Solution:** Show preferredName + QC level + rank in dropdown label, value still DTXSID.

**Example label:** `Acetone (DTXSID1020001) [QC: STANDARD, Rank: 1]`

**Data availability:** All metadata already in curation results from CompToxR.

**Implementation:** Format dropdown choices in `build_resolution_dropdown()` function.

**Complexity:** LOW-MEDIUM — String formatting + ensure all fields available.

### Audit Trail (Differentiator)

**Why valuable:** Track provenance — was this row auto-matched or manually curated?

**Implementation:** Add `curation_source` column to results:
- `"auto"` — Matched via tiered search
- `"manual"` — User entered DTXSID
- `"retry"` — Re-run after tag change or error resolution
- `"resolved"` — User selected from resolution dropdown

**Display:** Include in exported Excel for downstream analysis.

**Complexity:** LOW — Simple string column, set during curation/manual entry.

### Column Visibility Best Practices

**From research:**
- Priority-based defaults (data-priority 1-6, auto-hide low priority on narrow screens)
- User override via checkbox menu or column picker modal
- Preferences persist within session (until page refresh)
- Clear visual indicator when columns hidden (e.g., "5 columns hidden" badge)

**DT/DataTables pattern:**
- `columns.visible` option controls initial visibility
- `colvis` extension adds button + modal with checkboxes
- User clicks checkbox → column shows/hides immediately
- Preferences stored in browser localStorage (optional)

**ChemReg needs:**
- Many untagged columns (storage location, batch number, etc.)
- Only Name, CASRN, Other tagged columns relevant to curation review
- Auto-hide untagged = reduce clutter
- User can still show/hide individual columns via colvis

**Recommended approach:**
1. Default visibility: show all tagged columns, hide untagged
2. Checkbox: "Show untagged columns" (off by default)
3. ColVis extension for granular per-column control
4. Session-scoped preference (reset on new file upload)

### Error Recovery Workflow Best Practices

**From research (AWS DMS, Databricks):**
- Retry with delay (exponential backoff for transient failures)
- Idempotent merge (upsert based on unique key, not append)
- Validation before retry (don't retry guaranteed failures)
- Status tracking (pending → retry → success/fail)

**ChemReg context:**
- No transient failures (CompTox API either finds match or doesn't)
- Retry motivation: user fixed input (re-tagged column, manual DTXSID entry)
- Validation: ensure manual DTXSIDs valid before retry
- Merge: replace consensus for retried rows, preserve others

**Error categories:**
1. **Fixable via re-tag** — Column mis-assigned, correct data in different column
2. **Fixable via manual entry** — Chemical not in CompTox or name too ambiguous
3. **Unfixable** — Bad data (typo, non-chemical text), missing entirely

**Workflow:**
1. User reviews error rows
2. Identifies category (re-tag vs manual entry vs ignore)
3. Takes action (re-tag + retry OR manual DTXSID entry OR skip)
4. Results merge back, consensus updated

### Bulk Validation API Details

**CompTox Batch Search capabilities:**
- Input formats: Chemical name, CASRN, DTXSID, InChIKey, molecular formula
- Batch size: Hundreds to thousands (exact limit not documented, test recommended)
- Output: Matched records with full metadata (DTXSID, preferredName, CASRN, formula, etc.)
- Error handling: Invalid identifiers flagged, "No Hits" indicated

**Validation checks:**
1. **Format validation** (client-side, before API call)
   - DTXSID: `DTXSID[0-9]{9}` (27 char InChIKey variant also exists)
   - CASRN: `[0-9]{2,7}-[0-9]{2}-[0-9]` with checksum validation
   - InChIKey: 27 chars, uppercase letters, hyphens at positions 15 and 26
2. **Existence validation** (API call)
   - CompTox Batch Search returns matches
   - No match = identifier not in database
3. **Conflict detection** (optional, for CASRN)
   - Multiple CASRNs can map to same InChIKey
   - CompTox flags deleted/alternate CASRNs, routes to active

**ChemReg implementation:**
- User enters DTXSIDs (bulk paste or repeated modal entry)
- Client-side regex validation (instant feedback on format errors)
- Batch API call via ComptoxR (verify existence)
- Display validation results (valid / invalid / not found)
- User confirms → apply valid entries, reject invalid

**Error messaging:**
- Invalid format: "DTXSID123 is not a valid DTXSID format (expected DTXSID + 9 digits)"
- Not found: "DTXSID1234567890 not found in CompTox database"
- API error: "CompTox API error: [message]"

### Inline Edit vs Modal Entry Trade-offs

**Inline edit (table cell editing):**
- **Pros:** Feels immediate, minimal clicks, familiar spreadsheet UX
- **Cons:** Complex state management (which cells editable?), validation timing (on blur? on enter?), error display (where to show validation error for a cell?)
- **Complexity:** HIGH — DT editable extension + Shiny reactivity + validation loop

**Modal entry:**
- **Pros:** Clear workflow (click row → modal → enter → validate → save), error messages easy to display in modal, simpler state (modal open/closed)
- **Cons:** Extra click, context switch (row to modal and back)
- **Complexity:** MEDIUM — Modal UI + validation + update reactive value

**Bulk paste (textarea in modal):**
- **Pros:** Efficient for many entries, supports copy-paste from external source
- **Cons:** Parsing input (one per line? comma-separated? with row identifiers?), error display for multi-line input
- **Complexity:** MEDIUM-HIGH — Input parsing + validation + mapping to rows

**Recommendation for ChemReg:**
- **Start with modal entry** for single row (simpler, good enough for small error counts)
- **Add bulk paste** if users regularly have 20+ errors (efficiency gain justifies complexity)
- **Defer inline edit** unless user feedback strongly requests it

## Complexity Summary

| Feature | Complexity | Rationale |
|---------|-----------|-----------|
| Column visibility toggle | LOW | DT built-in extension + reactive preference |
| Smart hide untagged | LOW | Boolean filter + DT API |
| Error feedback specificity | LOW-MEDIUM | Expose existing CompToxR messages |
| Contextual resolution dropdown | LOW-MEDIUM | Format existing data |
| Audit trail | LOW | Add string column, set during curation |
| Manual DTXSID entry (modal) | MEDIUM | UI + validation API + reactivity |
| Bulk validation | MEDIUM | API batching + error handling |
| Validation preview | MEDIUM | Temporary state + review UI |
| Subset retry | MEDIUM | Filter + run + merge logic |
| Re-tag before retry (workspace) | MEDIUM | Copy subset + re-tag + merge |
| Re-tag before retry (invalidation) | MEDIUM-HIGH | Partial reactive invalidation |
| Inline edit | HIGH | Editable cells + validation loop + state management |
| Retry with tier override | HIGH | Per-row search strategy + UI complexity |

## Dependencies on Existing Features

| New Feature | Depends On (Existing) |
|-------------|----------------------|
| Error row filtering | Consensus classification (agree/disagree/error) — v1.1 |
| Manual DTXSID entry | CompToxR API integration — v1.1 |
| Bulk validation | CompToxR Batch Search — available in API |
| Subset retry | Tiered curation search pipeline — v1.1 |
| Re-tag before retry | Column tagging system — v1.0 |
| Contextual resolution dropdown | Resolution UI (per-row + en masse) — v1.1 |
| Smart hide untagged | Column tagging (Name, CASRN, Other) — v1.0 |
| Column visibility toggle | DT datatable display — existing |
| Audit trail | Curation results data structure — v1.1 |

## Research Confidence

| Area | Confidence | Notes |
|------|-----------|-------|
| Column visibility patterns | HIGH | DT/DataTables official docs, multiple UI framework examples |
| Bulk validation (general) | HIGH | Industry standard pattern, well-documented in ETL/data validation tools |
| CompTox Batch Search | MEDIUM | Official EPA docs confirm capability, exact limits untested |
| Subset retry patterns | HIGH | Databricks, AWS DMS official docs, common in CDC pipelines |
| Inline edit complexity | HIGH | Multiple framework docs (Telerik, Syncfusion, AG Grid) |
| Chemical identifier validation | HIGH | CompTox official docs, IUPAC InChI standards |
| Manual entry UX | MEDIUM | General data validation UX, not chemical-specific sources |

## Sources

**Data Curation and Error Recovery:**
- [Data Curation in 2026: Key Concepts and Best Practices](https://research.aimultiple.com/data-curation/)
- [Emerging Trends in Data Curation - Secoda](https://www.secoda.co/glossary/emerging-trends-in-data-curation)
- [Error handling in distributed systems - Temporal](https://temporal.io/blog/error-handling-in-distributed-systems)

**Bulk Validation and Manual Entry:**
- [Bulk action UX: 8 design guidelines - Eleken](https://www.eleken.co/blog-posts/bulk-actions-ux)
- [Designing for Enterprise — Better UX for Bulk Upload - Medium](https://manitesharma.medium.com/designing-for-enterprise-better-ux-for-bulk-upload-961e9fd1b80d)
- [Data Validation in ETL - 2026 Guide - Integrate.io](https://www.integrate.io/blog/data-validation-etl/)

**Retry and Merge-Back Patterns:**
- [Retry and Failure Handling Strategy for CDC Merge Pipeline - Microsoft Q&A](https://learn.microsoft.com/en-us/answers/questions/2284154/retry-and-failure-handling-strategy-for-cdc-merge)
- [AWS DMS data validation - AWS Documentation](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Validating.html)
- [How to Handle Late Arriving Dimensions - Databricks Blog](https://www.databricks.com/blog/2020/12/15/handling-late-arriving-dimensions-using-a-reconciliation-pattern.html)

**Column Visibility and Table UX:**
- [DataTables: Show / hide columns dynamically](https://datatables.net/examples/api/show_hide.html)
- [Column-Toggle Table Widget - jQuery Mobile](https://api.jquerymobile.com/table-columntoggle/)
- [Data Grid - Column visibility - MUI X](https://mui.com/x/react-data-grid/column-visibility/)
- [12 Best Data Catalog Tools in 2026 - Atlan](https://atlan.com/data-catalog-tools/)

**Inline Editing Patterns:**
- [Simplify Data Entry with Built-In Grid Editing - ComponentSource](https://www.componentsource.com/news/2026/01/20/simplify-data-entry-built-grid-editing)
- [AG Grid Validations - Cupcake Design System](https://cupcake-design-system.github.io/patterns/ag-grid-validations/)
- [CRUD Beyond Grids: Modern UI Patterns 2026](https://copyprogramming.com/howto/what-is-the-best-ux-to-let-user-perform-crud-operations)

**CompTox and Chemical Identifiers:**
- [Cheminformatics Modules Manual - US EPA](https://www.epa.gov/comptox-tools/cheminformatics-modules-manual)
- [The CompTox Chemistry Dashboard - Journal of Cheminformatics](https://jcheminf.biomedcentral.com/articles/10.1186/s13321-017-0247-6)
- [Chemicals Dashboard Help: Batch Search - US EPA](https://www.epa.gov/comptox-tools/chemicals-dashboard-help-batch-search)
- [CompTox Dashboard Data through APIs - TAME 2.0](https://uncsrp.github.io/TAME2/comptox-dashboard-data-through-apis.html)
- [5 Chemical Identifiers - Chemistry LibreTexts](https://chem.libretexts.org/Courses/University_of_Arkansas_Little_Rock/ChemInformatics_(2015):_Chem_4399_5399/Text/5_Chemical_Identifiers)
- [Using InChI and InChIKey - IUPAC FAIR Chemistry Cookbook](https://iupac.github.io/WFChemCookbook/manipulations/using_inchi.html)
