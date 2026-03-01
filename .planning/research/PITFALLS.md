# Pitfalls Research

**Domain:** Curation refinement features for existing chemical inventory app
**Researched:** 2026-03-01
**Confidence:** HIGH

## Critical Pitfalls

### Pitfall 1: DT Column Index Drift After Hiding Columns

**What goes wrong:**
When hiding columns via `columnDefs: list(visible = FALSE, targets = hidden_indices)`, JavaScript callbacks using `data-row` attributes refer to R-side row indices (1-based), but DT's internal column indices (0-based) shift when columns are hidden. If you hide dtxsid_* columns but formatStyle or JS callbacks assume original column positions, they target the wrong columns or fail silently.

**Why it happens:**
The DT package maintains separate R-side (1-based with all columns) and JS-side (0-based, visible columns only) indexing. When `escape=FALSE` is used with dynamically generated HTML (like resolution dropdowns), the `data-row` attribute captures the R row index, but if your JS callback tries to read column values using visible column positions, it gets misaligned data.

**How to avoid:**
1. Always use R-side row indices (from `seq_len(nrow(df))`) in `data-row` attributes
2. Never mix R row indices with DT column indices in the same callback
3. When hiding columns, compute `hidden_indices` as `which(names(df) %in% hidden_cols) - 1` (0-indexed for JS)
4. Test callbacks with both minimum (1 column hidden) and maximum (10+ columns hidden) scenarios
5. Use formatStyle's `target = 'row'` instead of column-specific styling when possible to avoid index issues

**Warning signs:**
- Resolution dropdown appears in the wrong column after hiding dtxsid_* columns
- `Shiny.setInputValue` receives row indices that don't match consensus_status values
- formatStyle applies to wrong column (e.g., consensus_status styling appears on consensus_dtxsid)
- Console errors like "cannot read property of undefined" in browser DevTools

**Phase to address:**
Phase 1 (Untagged Column Hiding) — validate that hiding columns doesn't break existing resolution dropdown indices

---

### Pitfall 2: Starts-With Search Precision Collapse

**What goes wrong:**
Moving starts-with to the end of the search chain (exact → CAS → starts-with) seems logical for prioritizing exact matches, but starts-with has no precision control — it returns all chemicals starting with the query string. For short queries like "Acet" or "Prop", this produces 100+ matches per query, and `slice_min(rank, n=1)` arbitrarily picks the top-ranked one, which may not be the user's intended chemical. This degrades match quality compared to exact-then-starts-with order.

**Why it happens:**
The CompTox API's starts-with search is "identifier substring search" and returns all matching substances with no fuzzy matching score. According to EPA documentation, exact searches are already implemented, but "fuzzy matching" to account for spelling differences is a future plan. The current starts-with implementation ranks results but doesn't filter by relevance beyond alphabetical/system ordering. When CAS search runs before starts-with, CAS failures (invalid format, no DTXSID mapping) fall through to starts-with, polluting results with unintended prefix matches.

**How to avoid:**
1. **Test match quality empirically** — run curation on sample data with both orders (exact → starts → CAS vs exact → CAS → starts) and compare consensus_status distributions
2. **Add starts-with filtering** — if moving to last-resort position, add length-based filtering (e.g., only use starts-with if query is 6+ characters) to reduce false positives
3. **Consider CAS-first only for CAS-tagged columns** — keep Name columns on exact → starts chain, use exact → CAS → starts only for CASRN-tagged columns
4. **Log tier attribution** — ensure `source_tier` column distinguishes exact, cas, starts_with so you can audit match quality post-curation
5. **Document the tradeoff** — exact → starts → CAS maximizes recall for typos; exact → CAS → starts maximizes precision for valid CAS numbers

**Warning signs:**
- Consensus rate drops after reordering (e.g., from 85% agree to 75% agree)
- Review Results shows chemicals with names completely different from uploaded data (e.g., uploaded "Acetone" matched to "Acetonitrile")
- Tier attribution shows unexpected starts_with dominance for columns tagged as CASRN
- User feedback: "The matches are wrong now"

**Phase to address:**
Phase 2 (Search Chain Reorder) — run comparative analysis on sample datasets before finalizing tier order

---

### Pitfall 3: Consensus Algorithm Breaks with Three Column Types

**What goes wrong:**
The consensus logic (`find_dtxsid_cols`) assumes all dtxsid_* columns are semantically equivalent (all from Name or CASRN tags). When "Other" columns become curation participants, you now have dtxsid_Name, dtxsid_CASRN, and dtxsid_Other columns. The consensus algorithm counts `k = length(dtxsid_cols)` for QC tier calculation but doesn't weight by tag type — a 2-name + 1-CAS agreement gets the same QC tier as a 3-name agreement, even though CAS is more reliable. Worse, if Other columns contain supplier codes or batch IDs that shouldn't participate in consensus, the algorithm treats them as equal voters.

**Why it happens:**
The original design assumed two tag types (Name, CASRN) and that all tagged columns should vote equally. Adding Other as a third type without revising consensus logic creates semantic ambiguity: should Other columns count toward `k`? Should they have lower weight? The current implementation has no tag-type awareness in `classify_consensus()`.

**How to avoid:**
1. **Decide Other's consensus role** — should Other columns:
   - Vote equally (current behavior, simple but potentially wrong)
   - Vote with reduced weight (requires consensus refactor)
   - Not vote (filter out dtxsid_Other before consensus, report separately)
2. **Update `find_dtxsid_cols` with tag awareness** — change signature to `find_dtxsid_cols(df, tag_map)` so it can filter by tag type
3. **Revise QC tier calculation** — if Other participates, consider tier = f(n_matched, n_name_cols, n_cas_cols, n_other_cols) instead of just n_total
4. **Add consensus mode parameter** — `classify_consensus(df, dtxsid_cols, mode = c("equal_vote", "name_cas_only", "weighted"))`
5. **Test with mixed tag scenarios** — 1 Name + 1 CAS + 1 Other, all agree; 1 Name + 1 CAS + 1 Other, Other disagrees; 2 Other + 1 Name

**Warning signs:**
- QC tiers look wrong (e.g., 1 Name + 1 Other agreement gets qc_tier=1 like 3-column full consensus)
- Consensus status "agree" for rows where Other column has garbage data but Name/CAS agree
- User confusion: "Why is my supplier code affecting chemical ID consensus?"
- Test failures when Other columns added to curation pipeline

**Phase to address:**
Phase 3 (Other Tag Curation) — refactor consensus logic before enabling Other search

---

### Pitfall 4: Retry Merge Loses Resolution State

**What goes wrong:**
The error row retry workflow subsets error rows, re-tags them, re-curates, then merges back via `left_join(original, retried, by = "row_id")` or similar. But `left_join` drops columns not present in the join key, and if the retry produces new dtxsid_* columns (e.g., user adds a new tag), the merge creates duplicated columns (dtxsid_Name.x, dtxsid_Name.y). Even if column names match, join operations don't preserve `.pinned` state or row order — retried rows may reappear at the end of the table, breaking the user's mental model.

**Why it happens:**
R's join functions (dplyr, base merge) are designed for relational data, not stateful UI objects. The `.pinned` attribute is a UI-layer concept stored in the resolution_state data frame. When you subset error rows, re-curate, and join back, you're merging two different "versions" of the same rows. Standard joins don't have semantics for "replace these rows in-place while preserving surrounding state".

**How to avoid:**
1. **Use row index-based replacement, not join** — instead of `left_join`, do:
   ```r
   retried_indices <- which(original$consensus_status == "error" & original$row_id %in% retried$row_id)
   original[retried_indices, updated_cols] <- retried[match(original$row_id[retried_indices], retried$row_id), updated_cols]
   ```
2. **Preserve .pinned explicitly** — before merge, save `.pinned` state, then restore:
   ```r
   pinned_state <- original$.pinned
   merged <- merge_retry_results(original, retried)
   merged$.pinned <- pinned_state
   ```
3. **Validate row count invariant** — `nrow(merged) == nrow(original)` must be TRUE (no row duplication)
4. **Validate column count** — after merge, no .x/.y suffixes in names(merged)
5. **Test with subset re-tagging** — retry 3 error rows, add 1 new tag (adds dtxsid_Other), verify original dtxsid_Name/CASRN preserved for non-retried rows

**Warning signs:**
- `nrow(resolution_state)` increases after retry (row duplication)
- Column names contain .x or .y suffixes after merge
- Previously pinned rows become unpinned after retry
- Row order changes (error rows move to bottom)
- DT table shows duplicate rows or missing rows after retry merge

**Phase to address:**
Phase 5 (Error Row Retry) — design merge strategy before implementing retry workflow

---

### Pitfall 5: Manual DTXSID Entry Bypasses Validation

**What goes wrong:**
Users enter DTXSIDs manually (e.g., "DTXSID7020001" for acetone), but the UI doesn't validate against CompTox before storing. Invalid DTXSIDs (typos, wrong format, non-existent IDs) flow into consensus_dtxsid, breaking downstream assumptions that all DTXSIDs are valid. Bulk validation via CompTox API after entry can fail silently (API returns 404 for invalid IDs), leaving garbage data in the consensus column. Worse, if manual entry creates consensus_dtxsid without corresponding dtxsid_* columns, the consensus source becomes ambiguous ("manual" vs column name).

**Why it happens:**
The current pipeline assumes all DTXSIDs come from API lookups (search_exact, search_starts_with, validate_and_lookup_cas), which guarantee API-validated IDs. Manual entry is a new path that bypasses this validation. The consensus logic expects `consensus_source` to map to a column name (e.g., "Name" from "dtxsid_Name"), but manual entry has no originating column.

**How to avoid:**
1. **Validate before storing** — on manual DTXSID entry, call `ComptoxR::ct_get_dtxsid_details(dtxsid)` to verify ID exists
2. **Batch validation with progress** — for bulk manual entry (paste list of DTXSIDs), validate all at once with `withProgress()` feedback
3. **Store validation metadata** — add `consensus_source = "manual"` and `manual_validated = TRUE/FALSE` columns
4. **Provide instant feedback** — show green checkmark for valid DTXSID, red X for invalid, with preferredName preview
5. **Allow invalid-but-flagged** — don't block manual entry of invalid IDs (user may have external knowledge), but flag them clearly in Review Results
6. **Test edge cases**:
   - Valid DTXSID format but non-existent ID
   - Invalid format (missing "DTXSID", wrong length)
   - Case sensitivity (dtxsid7020001 vs DTXSID7020001)
   - Deprecated DTXSIDs (redirected to active ID)

**Warning signs:**
- Review Results shows rows with consensus_dtxsid but no corresponding preferredName
- Excel export contains DTXSIDs that don't resolve in CompTox Dashboard
- consensus_source column contains "NA" or empty strings for manually entered rows
- API rate limit errors from validation attempts on large manual entry batches

**Phase to address:**
Phase 4 (Manual DTXSID Entry) — implement validation before exposing manual entry UI

---

### Pitfall 6: Hidden Column Filter Breaks DT Filtering

**What goes wrong:**
When you hide untagged columns via `columnDefs: list(visible = FALSE)`, DT's `filter = "top"` still generates filter inputs for hidden columns. These invisible filters accumulate user state (if a user types in them before hiding or via browser autocomplete), causing mysterious empty table states where the user sees no data but can't understand why. Additionally, hiding columns doesn't remove them from CSV export (`buttons = c('csv')`) — users export "cleaned" data but get all original columns.

**Why it happens:**
DT's column hiding is CSS-based (`display: none`), not structural removal. Filter widgets are generated for all columns, then hidden columns have their headers hidden, but the filter inputs remain in the DOM and active in the filtering logic. Similarly, DataTables' export buttons operate on the underlying data structure, not the visible columns.

**How to avoid:**
1. **Remove hidden columns from display_df** — instead of hiding via columnDefs, remove them before passing to datatable():
   ```r
   display_df <- df[, !names(df) %in% hidden_cols, drop = FALSE]
   ```
2. **If using columnDefs, disable filtering on hidden columns**:
   ```r
   columnDefs = list(
     list(visible = FALSE, targets = hidden_indices),
     list(searchable = FALSE, targets = hidden_indices)
   )
   ```
3. **Customize export buttons** — use DT extensions to export only visible columns:
   ```r
   buttons = list(list(extend = 'csv', exportOptions = list(columns = ':visible')))
   ```
4. **Test filter state persistence** — hide columns, filter on a visible column, unhide columns, verify filters reset correctly
5. **Document export behavior** — if hidden columns ARE included in export (for Excel with full data), document this clearly in UI

**Warning signs:**
- Table appears empty but row count shows non-zero
- Clearing visible filters doesn't restore rows (hidden column filter is active)
- CSV export contains columns user thought were hidden
- Browser DevTools shows filter inputs with `display: none` but non-empty values

**Phase to address:**
Phase 1 (Untagged Column Hiding) — decide structural removal vs. CSS hiding before implementing

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Hiding columns via CSS instead of removing from data | Preserves data for Excel export, simpler implementation | Filter state bugs, export confusion, accessibility issues | Only if Excel export must include hidden columns AND filters disabled on hidden columns |
| Equal-weight consensus for all tag types | No refactor needed for Other tag | QC tiers meaningless when mixing reliable (CAS) and unreliable (Other) columns | Never — consensus quality is core value prop |
| Row-index-based retry merge instead of proper state management | Fast implementation, avoids join complexity | Fragile to future changes (add/remove rows), hard to test | MVP only — refactor to row_id-based merge in next phase |
| Skip validation on manual DTXSID entry | Faster UX, no API calls | Garbage data in consensus, user trust loss | Never — validation is essential for data quality |
| Hard-code search tier order instead of making it configurable | Avoids UI complexity | Can't A/B test tier order, harder to optimize per dataset | Acceptable until user feedback proves tier order needs tuning |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| CompTox API starts-with search | Assuming starts-with returns "best match" like fuzzy search | Starts-with returns all prefix matches ranked by system order; always filter by query length (6+ chars) or manually verify top result |
| DT datatable with escape=FALSE | Using R row indices in JS column lookups | Use `data-row` for R row index (1-based), never mix with DT column index (0-based, visible only) |
| Shiny reactiveValues merge | Using dplyr::left_join to merge retried subset back | Use index-based replacement `df[indices, cols] <- new_values` to preserve row order and attributes |
| ComptoxR bulk validation | Assuming failed API calls return empty results | `ct_chemical_search_equal_bulk` returns NULL on total failure, empty tibble on zero matches; wrap in tryCatch and check both |
| DT column hiding | Hiding columns after creating DT with `filter = "top"` | Disable filtering on hidden columns via `searchable = FALSE` in columnDefs or remove columns from display_df |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Bulk starts-with search on short queries | API timeout, 100+ results per query, UI freezes | Filter queries to length >= 6 characters before calling starts-with | 50+ chemicals with 2-3 letter names (e.g., "Pb", "Hg", "NaCl") |
| Re-rendering entire DT on every resolution | Table flashes, pagination resets, user loses scroll position | Use DT::replaceData() to update data without recreating table | 500+ row tables with frequent resolutions |
| Computing resolution options for all rows on every render | `get_resolution_options` called 1000+ times per render | Cache resolution options in a list column during classify_consensus | 200+ rows with 10+ tagged columns |
| Redundant consensus classification after merge | Classify original, classify retried subset, classify merged (3x work) | Only classify retried rows, then replace in original without re-classifying | Retry workflow with 100+ error rows |
| Hidden column iteration in renderDT | formatStyle loops over all columns including hidden ones | Apply formatStyle only to visible columns: `!names(df) %in% hidden_cols` | 20+ columns, 10+ hidden |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No visual diff between CAS-sourced and Name-sourced consensus | User can't assess match reliability | Add consensus_source badge in table (e.g., "CAS ✓", "Name ~") with color coding |
| Hiding untagged columns without explanation | User confused why columns disappeared | Add toggle "Show untagged columns" with default OFF and tooltip explanation |
| Manual DTXSID entry without format hints | User enters invalid format, sees error, gives up | Provide format example ("DTXSID7020001") and auto-uppercase + validate on blur |
| Error row retry with no success feedback | User re-tags errors, clicks retry, sees table refresh, unsure if it worked | Show notification: "3 rows re-curated: 2 resolved, 1 still error" with before/after counts |
| Dropdown context shows only DTXSID | User picks "DTXSID7020001" vs "DTXSID8021234" with no idea which is which | Include preferredName in dropdown: "DTXSID7020001 - Acetone (Rank 1, CAS tier)" |
| No undo for en masse resolution | User clicks wrong priority column, 100 rows resolved incorrectly, no undo | Add "Reset all unpinned" button or confirmation modal before mass resolution |
| Search tier reorder with no migration guide | User re-curates same data, gets different results, loses trust | Show warning on first run after upgrade: "Search order changed, results may differ. Re-run curation on all datasets." |

---

## "Looks Done But Isn't" Checklist

- [ ] **Untagged column hiding:** Often missing filter state cleanup — verify hidden columns have `searchable: FALSE` and no active filters
- [ ] **Search tier reorder:** Often missing empirical validation — verify match quality doesn't degrade on sample datasets (exact → CAS → starts vs exact → starts → CAS)
- [ ] **Other tag curation:** Often missing consensus logic update — verify `k` calculation and QC tier still meaningful with three tag types
- [ ] **Manual DTXSID entry:** Often missing bulk validation — verify API validation works for 100+ manual entries without timeout
- [ ] **Error row retry:** Often missing row order preservation — verify retried rows stay in original position, not appended to end
- [ ] **Resolution dropdown context:** Often missing rank and tier info — verify dropdown shows preferredName, rank, and source_tier, not just DTXSID
- [ ] **DT column index mapping:** Often missing edge case tests — verify resolution dropdown works with 1 hidden column, 10 hidden columns, 0 hidden columns
- [ ] **Retry merge logic:** Often missing .pinned state preservation — verify manual resolutions before retry are not lost after merge
- [ ] **CompTox API error handling:** Often missing silent failure detection — verify NULL vs empty tibble distinction in tryCatch blocks
- [ ] **Consensus mode selection:** Often missing user documentation — verify SUMMARY.md explains when Other columns vote vs observe-only

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| DT column index drift | LOW | Add browser DevTools check, validate `data-row` matches consensus_status, adjust `hidden_indices` calculation |
| Starts-with precision collapse | MEDIUM | Revert search order to exact → starts → CAS, re-run curation on affected datasets, compare consensus rate |
| Consensus breaks with three types | HIGH | Refactor `classify_consensus` with tag-aware logic, re-classify all datasets with Other columns, update tests |
| Retry merge loses state | MEDIUM | Replace join with index-based update, restore `.pinned` from backup, re-apply any lost manual resolutions |
| Manual DTXSID bypasses validation | LOW | Add validation API call on blur, flag existing invalid DTXSIDs in Review Results with warning badge |
| Hidden column filter state | LOW | Clear all filters via `DT::clearSearch()`, remove columns from display_df instead of CSS hiding |
| Search tier order breaks existing data | MEDIUM | Provide migration script to re-curate old datasets with new tier order, document in CHANGELOG |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| DT column index drift | Phase 1 (Untagged Hiding) | Test resolution dropdown with 0, 1, 5, 10+ hidden columns; verify `data-row` matches expected row in data_store |
| Hidden column filter state | Phase 1 (Untagged Hiding) | Filter on visible column, hide/unhide columns, verify filters persist correctly and no ghost filters |
| Starts-with precision collapse | Phase 2 (Search Reorder) | Run curation on same dataset with both orders, compare consensus_status distribution (agree/disagree/error) |
| Search tier empirical validation | Phase 2 (Search Reorder) | Test with 100-row sample: 50 exact matches, 30 CAS-only, 20 typos; verify tier order maximizes agree rate |
| Consensus breaks with three types | Phase 3 (Other Tag) | Unit test: 1 Name + 1 CAS + 1 Other all agree → qc_tier=1; 1 Name + 1 Other agree, CAS NA → appropriate tier |
| Other tag consensus semantics | Phase 3 (Other Tag) | Document in SUMMARY.md: does Other vote equally, vote reduced, or observe-only? Test all three scenarios |
| Manual DTXSID validation | Phase 4 (Manual Entry) | Enter invalid DTXSID, verify red X and error message; enter valid DTXSID, verify green check and preferredName |
| Manual entry bulk validation | Phase 4 (Manual Entry) | Paste 100 DTXSIDs (90 valid, 10 invalid), verify validation completes in <10s and flags 10 invalid |
| Retry merge loses state | Phase 5 (Error Retry) | Pin 3 rows, retry 2 error rows, verify pinned state preserved and row order unchanged |
| Retry row order preservation | Phase 5 (Error Retry) | Retry error rows at indices 5, 10, 15; verify they remain at indices 5, 10, 15 after merge |
| Dropdown context clarity | Phase 6 (UX Polish) | Review Results with disagree rows → verify dropdown shows "DTXSID - PreferredName (Rank X, Tier)" |
| Column visibility UX | Phase 6 (UX Polish) | Add toggle to show/unhide untagged columns; verify toggle state persists within session |

---

## Sources

### DT Datatable and Shiny Integration
- [Using DT in Shiny](https://rstudio.github.io/DT/shiny.html) — Official DT documentation on Shiny integration
- [DT, formatters and hidden columns](https://groups.google.com/g/shiny-discuss/c/TcztuHs-GBQ) — Community discussion on column hiding bugs
- [Intro to Shiny: Packages II](https://psrc.github.io/intro-shiny-guide/packages_ii.html) — DT column indexing (0-based vs 1-based)
- [columnDefs - visible false not working — DataTables forums](https://datatables.net/forums/discussion/24035/columndefs-visible-false-not-working) — Known issues with hidden columns

### Shiny Reactive State Management
- [Subsetting dataframe and storing in reactiveValues() seems inconsistant · Issue #958 · rstudio/shiny](https://github.com/rstudio/shiny/issues/958) — Subset behavior quirks
- [reactiveValues inconsistent/unclear behaviour in regards to order of items · Issue #2629 · rstudio/shiny](https://github.com/rstudio/shiny/issues/2629) — Row order preservation issues
- [Chapter 15 Reactive building blocks | Mastering Shiny](https://mastering-shiny.org/reactivity-objects.html) — Reference semantics of reactiveValues

### CompTox API and Search Strategies
- [Chemicals Dashboard Help: Basic Search | US EPA](https://www.epa.gov/comptox-tools/chemicals-dashboard-help-basic-search) — Exact vs substring search behavior
- [Chemicals Dashboard Help: Batch Search | US EPA](https://www.epa.gov/comptox-tools/chemicals-dashboard-help-batch-search) — Batch search limitations (exact matches only)
- [Enabling High-Throughput Searches for Multiple Chemical Data using the US-EPA CompTox Chemicals Dashboard - PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC8630643/) — Current search limitations and future fuzzy matching plans
- [Sourcing data on chemical properties and hazard data from the US-EPA CompTox Chemicals Dashboard: A practical guide for human risk assessment](https://www.sciencedirect.com/science/article/pii/S0160412021001914) — Identifier search exact match requirement, spelling issues

### dplyr Joins and Data Merging
- [Mutating joins — mutate-joins • dplyr](https://dplyr.tidyverse.org/reference/mutate-joins.html) — Official join documentation
- [How to merge data in R using R merge, dplyr, or data.table | InfoWorld](https://www.infoworld.com/article/2264570/how-to-merge-data-in-r-using-r-merge-dplyr-or-datatable.html) — Join mechanics (no attribute preservation guarantees)

### Codebase-Specific Knowledge
- `R/consensus.R` — `find_dtxsid_cols` uses `grep("^dtxsid_", names(df))` pattern matching (HIGH confidence, source code)
- `R/curation.R` — Current tier order: exact → starts-with → CAS (lines 470-540) (HIGH confidence, source code)
- `app.R` — DT table with `escape=FALSE` and `data-row` JS callback (lines 1398, 1564) (HIGH confidence, source code)
- `app.R` — Hidden columns via `columnDefs: list(visible = FALSE, targets = hidden_indices)` (line 1437) (HIGH confidence, source code)

---

*Pitfalls research for: ChemReg v1.2 Curation Refinement*
*Researched: 2026-03-01*
*Confidence: HIGH (codebase analysis) / MEDIUM (CompTox API behavior) / LOW (empirical tier order comparison)*
