# Phase 19: Synonym Splitter Comma Protection - Context

**Gathered:** 2026-03-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix the synonym splitter so multi-locant IUPAC chemical names (e.g., "2,4,6-trichlorophenol") are not incorrectly split on their locant commas. Existing single-locant protection (e.g., "2,4-D") must continue to work. Plain non-locant commas (e.g., "acetone, purified") must still split correctly.

</domain>

<decisions>
## Implementation Decisions

### Regex strategy
- Use repeat-until-stable loop instead of replacing the existing regex
- The current `(\d+),(\d+)` regex stays; wrap it in a `repeat {}` loop that applies until no more replacements occur
- Wrap both letter-comma-letter (line 850) and digit-comma-digit (line 853) protections in the loop for consistency
- Add a safety cap of 10 iterations to prevent infinite loops on unexpected input

### Edge case scope
- Digit-only locants (`\d+`) are the baseline; researcher should scan real data files for mixed digit-letter locants (e.g., "3a,4b-") and decimal locants (e.g., "1.5,2-") before finalizing — expand regex only if data warrants it
- Expect locant chains up to 6 positions (covers common patterns through polychlorinated compounds)
- Protect locant commas everywhere in the name (mid-name, inside parentheses, etc.) — `str_replace_all` already applies globally
- Plain non-locant commas must still split: "acetone, purified" → two entries
- Inverted name + multi-locant combination (e.g., "butane, 2,4,6-trimethyl") must be tested — the `%%%` inverted name protection and `@@@` digit loop must coexist correctly

### Interaction between placeholder systems
- The %%% placeholder (inverted name comma) and @@@ placeholder (locant commas) already coexist in the code
- "butane, 2,2-dimethyl" already works (single digit pair, one pass sufficient)
- "butane, 2,4,6-trimethyl" is the critical new test case — the loop fix must protect all locant commas after the inverted name comma is protected
- "acetone, 2,4-dinitrophenylhydrazone" — the first comma should split (plain synonym separator), while the 2,4 locant stays protected

### Claude's Discretion
- Exact loop implementation style (repeat vs while)
- Whether to extract the protection logic into a helper function or keep inline
- Test case ordering and grouping

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` — SPLIT-01 (multi-locant protection) and SPLIT-02 (single-locant regression)

### Existing implementation
- `R/cleaning_pipeline.R` lines 821-928 — `split_synonyms()` function with current @@@ and %%% placeholder system
- `R/cleaning_pipeline.R` lines 848-868 — The three protection steps (letter-comma-letter, digit-comma-digit, inverted name) and restore logic

### Prior art
- `clean_chems.py` — Original Python cleaning script; has NO synonym splitting or IUPAC comma protection. All synonym/locant handling was built new in the R pipeline (v1.3/v1.4).

### Prior decisions
- `.planning/PROJECT.md` Key Decisions table — "Reuse @@@ placeholder for letter-comma-letter" (v1.4) and "IUPAC comma protection via placeholders" (v1.3)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `split_synonyms()` in `R/cleaning_pipeline.R:821` — The function to modify; already has the @@@ and %%% placeholder system
- Existing test suite in `tests/` — Has 42 assertions for cleaning pipeline; add multi-locant cases

### Established Patterns
- Placeholder-protect-then-restore pattern: protect special commas with @@@/%%%, split on remaining commas, restore placeholders
- `str_replace_all` for global regex application — already position-agnostic
- `purrr::safely()` error handling in detection ensemble (not needed here but shows error handling style)

### Integration Points
- `split_synonyms()` is called from `R/cleaning_pipeline.R:1489` (main pipeline) and `R/modules/mod_clean_data.R:223` (Shiny module)
- Audit trail entries use step = "split_synonyms" — no change needed to audit format

</code_context>

<specifics>
## Specific Ideas

- The bug: `str_replace_all` with `(\d+),(\d+)` on "2,4,6" only protects "2,4" in one pass, leaving ",6" exposed
- The fix is minimal: wrap existing regex in a repeat loop rather than rewriting the regex pattern
- The original Python script (`clean_chems.py`) had no synonym splitting at all — this is entirely R pipeline logic

</specifics>

<deferred>
## Deferred Ideas

- **Inverted name canonicalization** — Reorganize inverted IUPAC names (e.g., "butane, 2,2-dimethyl" → "2,2-dimethylbutane") so compounds are registered under their conventional name. Not every compound will be found by CompTox under the inverted form. Defer until good heuristics are developed for reliable inversion. Add to TODO for future milestone.
- **Mixed digit-letter locant patterns** — If researcher finds "3a,4b-" style locants in real data, extend the regex in a follow-up phase

</deferred>

---

*Phase: 19-synonym-splitter-comma-protection*
*Context gathered: 2026-03-19*
