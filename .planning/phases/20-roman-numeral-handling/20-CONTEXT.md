# Phase 20: Roman Numeral Handling - Context

**Gathered:** 2026-03-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Chemical names containing roman numeral oxidation states (e.g., "chromium (III)", "Iron(III) chloride") must survive the cleaning pipeline intact. The `strip_terminal_enclosures()` function currently strips terminal "(III)" because its protection logic only checks for "yl" content — roman numerals are not recognized as chemical identity markers. The formula_extract column must receive only genuine stripped content, not oxidation state indicators.

</domain>

<decisions>
## Implementation Decisions

### Protection scope
- Protect parenthesized roman numerals only — space-separated forms like "chromium III" already survive (no parens to strip)
- Support roman numerals I through XII (covers all real oxidation states with margin)
- Case-insensitive matching: protect (III), (iii), (Iii) etc. — real data has both uppercase and lowercase
- Also protect element symbol + roman numeral patterns: (Cr III), (Fe II), (Cu I)
- Only protect when the ENTIRE parenthetical content is a roman numeral (optionally with element symbol) — mixed content like (Fe2O3, III) is not protected

### Fix location
- Add a `has_roman` check to the existing `should_strip` logic in `strip_terminal_enclosures()` (line 388)
- New condition: `should_strip <- (!has_yl || has_exception) && !has_percentage && !has_roman`
- Apply the check to BOTH parenthetical and bracket enclosure logic (parallel code blocks)
- This single change fixes both pass 1 (step 6a, line 1447) and pass 2 (step 6d3, line 1490) automatically
- Define the roman numeral regex as a module-level constant at the top of `cleaning_pipeline.R`
- Protect roman numerals everywhere in the name, not just terminal positions — defensive against future pipeline changes

### Edge case handling
- "chromium (iii) oxide (2:3), cr2-o3, chromium oxide": protect (iii), strip (2:3), synonym split handles commas — each pipeline step does its job
- Non-terminal (iii) in "chromium (iii) oxide" already survives current logic, but the protection applies everywhere as defense-in-depth
- Stoichiometric ratios like (2:3) continue to be stripped — they don't match the roman numeral pattern

### Test coverage
- Add roman numeral rows to `data/chemical_validation_test.csv` (end-to-end validation)
- Add unit tests to `tests/test_name_cleaning.R` for `strip_terminal_enclosures` specifically
- Four categories of test cases from real data:
  1. Terminal roman numeral: "chromium (III)" — the actual bug (uppercase + lowercase variants)
  2. Non-terminal roman numeral: "Iron(III) chloride", "Antimony(III) ethoxide" — regression proof
  3. Complex multi-synonym: "chromium (iii) oxide (2:3), cr2-o3, chromium oxide" — interaction test
  4. Element+numeral form: "Chromium (Cr III) complex of..." — extended pattern
- Include negative regression tests: confirm "Acetone (ACS reagent)" and similar non-roman parentheticals STILL get stripped

### Claude's Discretion
- Exact roman numeral regex implementation (character class vs alternation vs whitelist)
- Whether the element symbol pattern uses a full element list or a simple `[A-Z][a-z]?` heuristic
- Test assertion style and grouping within test files
- Exact set of CAS numbers for new CSV test rows

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` — ROMAN-01 (retain roman numerals in name) and ROMAN-02 (no misrouting to formula column)

### Existing implementation
- `R/cleaning_pipeline.R` lines 344-477 — `strip_terminal_enclosures()` function with the `should_strip` logic that needs the roman numeral check
- `R/cleaning_pipeline.R` line 388 — The exact `should_strip` conditional to modify (parenthetical path)
- `R/cleaning_pipeline.R` line 417 — The parallel `should_strip` conditional for bracket path
- `R/cleaning_pipeline.R` lines 1446-1492 — Pipeline steps 6a and 6d3 where enclosure stripping runs (both passes)
- `R/cleaning_pipeline.R` lines 969-1079 — `detect_bare_formulas()` for context on formula column routing (not the bug, but related)

### Test files
- `tests/test_name_cleaning.R` — Existing name cleaning tests; add roman numeral unit tests here
- `tests/test_cleaning_pipeline_validation.R` — End-to-end validation tests using chemical_validation_test.csv
- `data/chemical_validation_test.csv` — Validation dataset; add roman numeral rows

### Real data reference
- `uncurated_chemicals_2023-05-16_12-43-41.csv` — Production dataset with real roman numeral entries (rows 18, 10575, 10643, 10897, 10898, 10915, 10971, 10972, 11739, 11960, 11977)

### Prior decisions
- `.planning/PROJECT.md` Key Decisions table — "Two-pass enclosure stripping" (v1.3) and "Consecutive-lowercase heuristic for formula detection" (v1.4)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `strip_terminal_enclosures()` in `R/cleaning_pipeline.R:344` — The function to modify; has parallel paren/bracket logic with shared `should_strip` pattern
- Existing "yl" protection and exception word list — Established pattern for content-based strip decisions
- `data/chemical_validation_test.csv` — Structured validation dataset with category tags (e.g., "stoichiometric_ratio") for systematic testing

### Established Patterns
- Content-based should_strip gating: check content characteristics (has_yl, has_exception, has_percentage) to decide whether to strip — roman numeral check follows the same pattern
- Module-level constants at top of cleaning_pipeline.R — Where the roman numeral regex should live
- Two-pass enclosure stripping (step 6a + step 6d3) — both passes use the same function, so the fix automatically applies to both

### Integration Points
- `strip_terminal_enclosures()` is called at lines 1447 and 1490 in the pipeline orchestrator
- The `formula_extract_` column receives stripped content — with the fix, roman numerals stay in the name column instead of being routed there
- No changes needed to `detect_bare_formulas()` — "chromium" alone wouldn't trigger formula detection (has consecutive lowercase)

</code_context>

<specifics>
## Specific Ideas

- The root cause is clear: `strip_terminal_enclosures()` line 388 — `should_strip` is TRUE for "(III)" because it has no "yl", no exception words, and no percentage
- The fix is a single additional condition: `&& !has_roman` in the `should_strip` expression
- Real production data confirms both uppercase "(III)" and lowercase "(iii)" forms exist
- The "Cr III" element+numeral form appears in production data but is always non-terminal — protection is defense-in-depth

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 20-roman-numeral-handling*
*Context gathered: 2026-03-19*
