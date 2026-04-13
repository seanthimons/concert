# Phase 23: Isotope Cleaning - Context

**Gathered:** 2026-04-02
**Status:** Ready for planning

<domain>
## Phase Boundary

Add isotope shortcode expansion, chiral designation protection, and multi-analyte flagging to the pre-curation cleaning pipeline. Three new cleaning steps that run on name columns before bare formula detection.

**Expanded scope from original requirements:** ISOT-01/02/03 (isotope expansion) plus two additional cleaning rules discovered during discussion: chiral designation protect+flag, and naked `+`/`and` multi-analyte flagging.

</domain>

<decisions>
## Implementation Decisions

### Isotope Expansion (ISOT-01, ISOT-02, ISOT-03)

- **D-01: Data source** — Use `ComptoxR::pt$isotope` directly (3,390 rows; columns: Z, element, Name, smiles, DTXSID). Shortcode = `paste0(Z, element)`. No custom mapping tables.

- **D-02: Expand naked shortcodes only** — Expand standalone isotope shortcodes (entire cell value or standalone token). `u234` → `Uranium-234`, `pb210` → `Lead-210`. Do NOT expand isotope prefixes in compound names — `14C-glucose` stays as-is (CCD convention: `[5'-13C]thymidine` keeps compact form).

- **D-03: Normalize all readable forms too** — Also normalize already-readable forms to consistent `Name-Mass` hyphenated format:
  - `radium 226` → `Radium-226`
  - `strontium 90` → `Strontium-90`
  - `cesium-137` → `Cesium-137` (capitalize)
  - `iodine 131` → `Iodine-131`

- **D-04: Greedy element matching** — Match longest element symbol first (`Pb` before `P`) to avoid misparse. `pb210` = Pb + 210 (Lead), not P + b210.

- **D-05: Only element+digits patterns** — Only match shortcodes where suffix is numeric. Non-numeric suffixes like `unat` are not expanded.

- **D-06: unat handling** — Flag `unat` as no-match/unresolvable. It's natural uranium (a mixture), and the data already contains the component isotopes (u234, u235, u238) as separate rows. One-off edge case, not worth special logic.

- **D-07: <5 char element code restriction** — Per ISOT-02, only shortcodes where the element symbol is <5 characters (all standard element symbols are 1-2 chars, so this is effectively all elements). Longer ambiguous codes left unchanged.

### Chiral Designation Protection (new scope)

- **D-08: Protect + flag** — Detect `(+)`, `(-)`, `(±)` chiral designations in chemical names. Both:
  1. **Protect** them from downstream stripping (prevent enclosure stripping from removing `(+)` from `(+)-catechin`)
  2. **Flag** with a WARNING annotation: identifies isomers, enantiomers, and racemic mixtures

- **D-09: Regex-based detection** — Use regex pattern to identify chiral markers: `(+)`, `(-)`, `(±)`, `(R)`, `(S)`, `(R,S)`, `(d)`, `(l)`, `(dl)` and similar stereochemistry designations in parentheses.

- **D-10: Pipeline position** — Chiral detection/protection runs BEFORE enclosure stripping (Step 6a) so markers are already protected when stripping runs. Uses placeholder pattern (consistent with existing IUPAC comma protection approach).

### Multi-Analyte Flagging (new scope)

- **D-11: Flag only, no auto-split** — Flag rows containing naked ` + ` or ` and ` between analyte-like tokens as "potential multi-analyte" WARNING. Do NOT auto-split. Reason: `nitrate + nitrite` is a legitimate single WQ parameter that would be destroyed by splitting.

- **D-12: Audit trail visibility** — Flagged rows appear in the audit trail so the user can review during post-curation QC or export.

### Pipeline Ordering

- **D-13: Three new steps before bare formula detection** — All three steps run on name columns, ordered:
  1. Chiral designation protection (must be before enclosure stripping)
  2. Isotope expansion + normalization (must be before bare formula detection)
  3. Multi-analyte flagging (informational, can run anytime but grouped with the others)

### Claude's Discretion
- Exact regex patterns for chiral designation matching
- Whether to build the isotope lookup table once at pipeline init or per-invocation
- Test case selection beyond the real-world examples from `uncurated_sswqs.csv`
- Audit trail reason text wording

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Data source
- `ComptoxR::pt$isotope` — The isotope tibble (Z, element, Name, smiles, DTXSID). Build shortcodes via `paste0(Z, element)`.

### Pipeline
- `R/cleaning_pipeline.R` lines 1398-1536 — `run_cleaning_pipeline()` orchestrator; new steps insert before bare formula detection
- `R/cleaning_pipeline.R` lines 1452-1520 — Name column cleaning steps (6a-6f); chiral protection inserts before Step 6a
- `R/cleaning_pipeline.R` lines 976-1073 — `detect_bare_formulas()` function; isotope expansion must run before this

### Existing patterns
- `R/cleaning_pipeline.R` lines 55-100 — `build_audit_trail()` helper; all new steps must produce audit trail entries
- `R/cleaning_pipeline.R` lines 860-950 — `split_synonyms()` with IUPAC comma placeholder pattern; chiral protection should use similar placeholder approach

### Reference list pattern
- `R/cleaning_reference.R` — Provenance-tracked reference lists with (term, source, active) tibble format; relevant if isotope list needs caching

### Real-world test data
- `uncurated_sswqs.csv` — Contains real isotope patterns: naked shortcodes (u234, pb210, ra226, th232, po210, pa234), spelled-out forms (radium 226, strontium 90, iodine 131), hyphenated forms (cesium-137, plutonium-238), combined expressions (pb206 + pb207 + pb208), and edge case (unat)

### Requirements
- `.planning/REQUIREMENTS.md` — ISOT-01 (new pipeline step), ISOT-02 (ComptoxR isotope list, <5 char codes), ISOT-03 (carbon backbone + deuterium d-prefix exclusions)

### Prior decisions
- `.planning/PROJECT.md` Key Decisions — "ComptoxR direct usage" (v1.3): use ComptoxR data directly
- Phase 21 CONTEXT.md — Established pattern of test alignment with ComptoxR output format

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ComptoxR::pt$isotope` — 3,390-row isotope lookup table with element symbols and full names
- `build_audit_trail()` — Standard audit trail builder used by all cleaning steps
- Placeholder pattern (e.g., `@@@` for IUPAC commas) — Reusable for chiral designation protection
- `detect_bare_formulas()` — Existing bare formula detection that isotope expansion feeds into

### Established Patterns
- Each cleaning step returns `list(cleaned_data, audit_trail, new_tags)` or `list(cleaned_data, audit_trail)`
- Steps operate on name columns identified via `tag_map`
- WARNING flags annotate but don't block; BLOCK flags prevent curation
- Placeholder-based protection: protect patterns before destructive steps, restore after

### Integration Points
- New steps insert into `run_cleaning_pipeline()` between existing Step 6 name cleaning and bare formula detection
- Chiral protection must wire into enclosure stripping (Step 6a) to prevent `(+)` removal
- Multi-analyte flags visible in audit trail and export

</code_context>

<specifics>
## Specific Ideas

### Real data patterns from uncurated_sswqs.csv
- Naked shortcodes: `u234`, `u235`, `u238`, `pb206`, `pb207`, `pb208`, `pb210`, `pb212`, `ra226`, `th232`, `th234`, `pa234`, `po210`
- Spelled out: `radium 226`, `strontium 90`, `iodine 131`, `cesium 134`, `americium 241`
- Hyphenated: `cesium-137`, `plutonium-238`
- Combined: `pb206 + pb207 + pb208`, `plutonium 239 and 240`, `thorium 230 and 232`, `radium 226 and 228 combined`
- Edge case: `unat` (natural uranium mixture) — flag as no-match
- Already common name: `tritium` — leave as-is (already expanded)

### Carbon backbone exclusion examples (ISOT-03)
- `C12H22O11` (sucrose formula) — the `C12` here is NOT Carbon-12 isotope
- Plain `C` prefixes in organic chemistry notation

### Deuterium d-prefix exclusion (ISOT-03)
- `d-glucose` — the `d` is a stereochemistry prefix, not deuterium

</specifics>

<deferred>
## Deferred Ideas

- **Auto-splitting on naked `+` / `and`** — Currently flag-only. Could be promoted to auto-split in a future phase with a reference list of protected combined parameters.
- **Stereochemistry normalization** — Phase 23 protects and flags chiral designations but doesn't normalize them (e.g., `(+)` vs `(d)` equivalence). Could be its own phase.

</deferred>

---

*Phase: 23-isotope-cleaning*
*Context gathered: 2026-04-02*
