# Pre- and Post-Curation Cleaning Pipeline Plan

This document maps functions from `clean_chems.py` to proposed R implementations in CONCERT,
identifying where `ComptoxR` (v1.4.0) provides direct replacements or improvements.

---

## 1. Architecture Overview

The current CONCERT pipeline has a gap between **file upload/detection** and **curation (tiered CompTox search)**. The Python script `clean_chems.py` fills that gap with a staged cleaning pipeline. This plan proposes integrating that cleaning as two new modules:

```
File Upload â†’ Detection â†’ Extract Clean Data
                                â†“
                    â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
                    â”‚  R/pre_curation.R     â”‚  â† NEW
                    â”‚  (cleaning + flagging) â”‚
                    â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
                                â†“
                    Column Tagging â†’ Curation Pipeline (existing R/curation.R)
                                â†“
                    â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”
                    â”‚  R/post_curation.R    â”‚  â† NEW
                    â”‚  (QC + audit export)  â”‚
                    â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜
                                â†“
                          Final Export
```

### New Files

| File | Purpose |
|------|---------|
| `R/pre_curation.R` | All pre-curation cleaning and flagging functions |
| `R/post_curation.R` | Post-curation QC checks and audit trail export |
| `R/cleaning_reference.R` | Reference data loaders (stop words, block lists, functional categories) |

---

## 2. Pre-Curation Functions

### 2.1 CASRN Cleaning

#### `extract_cas` â€” Extract CAS-RNs from text (CASRN or Name columns)

| | Python (`clean_chems.py`) | ComptoxR |
|---|---|---|
| **Function** | `casrn_split(x)` (line 7) | `ComptoxR::extract_cas(x)` |
| **Approach** | `re.findall("[1-9][0-9]{1,6}\-[0-9]{2}\-[0-9]")` | `str_extract_all` candidates â†’ `as_cas()` validation |
| **Returns** | List of matched strings (no validation) | List of validated CAS-RNs only |

**Recommendation: Use `ComptoxR::extract_cas()`.**
- It validates each candidate via checksum before returning, so you never get false-positive CAS patterns.
- The Python version just regex-matches and returns anything that looks like a CAS-RN, including invalid ones.
- Already used in `clean_chems.R:20`.

**Where it goes:** `R/pre_curation.R` â€” called early to rescue CAS-RNs from name columns and split multi-CAS cells.

---

#### `validate_cas` â€” CAS-RN checksum validation

| | Python | ComptoxR |
|---|---|---|
| **Function** | `checksum(x)` (line 67) | `ComptoxR::is_cas(x)` |
| **Approach** | Manual weighted-sum mod-10 | Same algorithm, vectorized via `vapply` |
| **Returns** | `TRUE`/`FALSE` | `TRUE`/`FALSE`/`NA` (handles NA input) |

**Recommendation: Use `ComptoxR::is_cas()`.**
- Already handles `NA` inputs gracefully (returns `NA` instead of `FALSE`).
- Also validates the format regex `^\d{2,7}-\d{2}-\d$` before computing checksum, catching structural invalidity the Python version misses.
- Already integrated in `R/curation.R:203`.

**Where it goes:** `R/pre_curation.R` â€” batch validation step with audit comment logging.

---

#### `normalize_cas` â€” CAS-RN normalization

| | Python | ComptoxR |
|---|---|---|
| **Function** | Manual `str.strip()` chain (lines 775-783) | `ComptoxR::as_cas(x)` |
| **Approach** | Strip whitespace, `...`, `#`, `*`, collapse spaces, remove spaces | Strip non-digits â†’ reformat as `NNN-NN-N` â†’ validate checksum |
| **Returns** | Cleaned string (may still be invalid) | Valid formatted CAS-RN or `NA` |

**Recommendation: Use `ComptoxR::as_cas()`.**
- Handles leading zeros (strips via `as.numeric()`), removes all non-digit characters, then reconstructs the canonical `NNN-NN-N` format.
- Only returns a value if the reconstructed CAS passes checksum â€” the Python version just strips characters without revalidating.
- Already used in `R/curation.R:202`.

**Where it goes:** `R/pre_curation.R` â€” first step in CASRN pipeline, before validation.

---

#### `rescue_cas_from_names` â€” Move CAS-RNs found in name columns to CASRN column

| | Python | ComptoxR |
|---|---|---|
| **Function** | `casrn_finder()` (line 739) | `ComptoxR::extract_cas()` + manual merge |

**Recommendation: Wrap `ComptoxR::extract_cas()` in a new helper.**
- The Python version does two things: (1) extracts CAS-RNs from name text, (2) merges them into the CASRN column with dedup. ComptoxR handles (1); we need a thin wrapper for (2).
- Benefit: the Python regex for removal (`\(CAS Reg. No. ...\)`) is narrow; we can generalize to strip any `extract_cas()` match from the name string.

**Where it goes:** `R/pre_curation.R` â€” after initial string canonicalization, before name cleaning.

---

#### `split_multi_cas` â€” Explode rows with multiple CAS-RNs

| | Python | ComptoxR |
|---|---|---|
| **Function** | `split_casrns()` (line 657) | No direct equivalent |

**Recommendation: New function in `R/pre_curation.R`.**
- Use `ComptoxR::extract_cas()` to find all CAS-RNs per cell, then `tidyr::unnest_longer()` to explode.
- Already prototyped in `clean_chems.R:23`.
- Logs an audit comment when multiple CAS-RNs are found on one row.

**Where it goes:** `R/pre_curation.R` â€” after `rescue_cas_from_names`, before checksum validation.

---

#### `filter_invalid_cas` â€” Remove strings in CASRN column that aren't CAS-RNs

| | Python | ComptoxR |
|---|---|---|
| **Function** | `string_not_casrn()` (line 641) | `ComptoxR::as_cas()` returning `NA` |

**Recommendation: Use `ComptoxR::as_cas()` â€” returns `NA` for non-CAS strings automatically.**
- The Python version uses a separate regex check; `as_cas()` subsumes this since it strips non-digits and checks length (5-10 digits) plus checksum.

**Where it goes:** `R/pre_curation.R` â€” implicit in the normalization step.

---

### 2.2 Chemical Name Cleaning

#### `detect_formula_names` â€” Flag names that are just molecular formulas

| | Python | ComptoxR |
|---|---|---|
| **Function** | `find_formula(x)` / `correct_formula()` (lines 30, 331) | `ComptoxR::extract_formulas()` |
| **Approach** | Complex regex matching element+digit patterns, special-cases NaCl | Internal extractor (uses `.ComptoxREnv$extractor`) |
| **Returns** | Boolean (name == formula) | List of extracted formula strings per input |

**Recommendation: Evaluate `ComptoxR::extract_formulas()` further.**
- In testing, `extract_formulas()` returned empty for `H2O`, `C2H6O`, `NaCl`, `H2SO4`, and `C2H5OH`. Source inspection reveals it only extracts formulas **inside parentheses or square brackets** (e.g., `"sodium chloride (NaCl)"` or `"[Pt(NH3)2Cl2]"`), and filters out oxidation states and carbon backbone ranges. It is designed for extracting embedded formulas from chemical names, not for detecting bare formula strings.
- **For the "is this name just a formula?" check**, `extract_formulas()` won't help â€” we need a different approach.
- **Improvement path:** ComptoxR also exports the `pt` (periodic table) dataset containing all element symbols. This could be used to build a proper formula validator that checks whether a string is composed entirely of valid element symbols + digits, replacing the Python regex hack that special-cases `NaCl`.
- **Fallback:** Port the Python regex to R as `detect_formula_name()`, which checks if the *entire string* is a formula (not extracting formulas from within text).

**Where it goes:** `R/pre_curation.R` â€” flag-only step (set name to `NA`, log original in comment).

---

#### `detect_mixture_names` â€” Flag names that indicate mixtures

| | Python | ComptoxR |
|---|---|---|
| **Function** | N/A (partially in `stops()`, `drop_stoppers()`) | `ComptoxR::extract_mixture()` |
| **Approach** | Stop-word matching for "blend", "mixture" | Regex for ratio patterns like `60:40`, `3/1 w/w` |

**Recommendation: Use both â€” they catch different things.**
- `extract_mixture()` detects numeric ratio patterns (e.g., `"60:40 w/w"`, `"3-1 v/v"`). In testing, it did NOT flag keyword-only mixtures like `"mixture of acids"` or `"blend of oils"`.
- The Python stop-word approach catches keyword-based ambiguity (`"blend"`, `"mixture"`, `"proprietary"`).
- Combine: `extract_mixture()` for ratio-based detection + stop-word list for keyword-based detection.

**Where it goes:** `R/pre_curation.R` â€” flag step, not removal. Let curator decide.

---

#### `strip_terminal_phrases` â€” Remove trailing parenthetical/bracket content

| | Python | ComptoxR |
|---|---|---|
| **Function** | `term_parenth()` / `term_bracket()` (lines 164, 205) | No equivalent |

**Recommendation: Port to R as a single function handling both `()` and `[]`.**
- The Python version has a smart heuristic: only strip if terminal, and keep if the parenthetical contains `"yl"` (likely a chemical name fragment like "methyl", "ethyl") unless it's a false positive ("density", "probably", etc.).
- This is domain-specific logic with no ComptoxR analog.

**Where it goes:** `R/pre_curation.R` â€” name canonicalization step.

---

#### `strip_unspecified` â€” Remove trailing ", unspecified" or "- unspecified"

| | Python | ComptoxR |
|---|---|---|
| **Function** | `terminal_unspecified()` (line 348) | No equivalent |

**Recommendation: Port to R.** Simple regex substitution.

**Where it goes:** `R/pre_curation.R` â€” name canonicalization step.

---

#### `strip_salt_references` â€” Remove "and its salts" suffix

| | Python | ComptoxR |
|---|---|---|
| **Function** | `drop_salts()` (line 557) | No equivalent |

**Recommendation: Port to R.** Pattern: `and its .* salts|and its salts`.

**Where it goes:** `R/pre_curation.R` â€” name canonicalization step, after terminal phrase stripping.

---

#### `strip_quality_adjectives` â€” Remove "pure", "tech grade", "chemical grade", etc.

| | Python | ComptoxR |
|---|---|---|
| **Function** | Part of `drop_text()` (lines 521-535) | No equivalent |

**Recommendation: Port to R.** Words: `pure`, `purif`, `tech`, `grade`, `chemical`.

**Where it goes:** `R/pre_curation.R` â€” name canonicalization step.

---

#### `strip_text_noise` â€” Remove "Part A:", trailing percentages, "modified" names

| | Python | ComptoxR |
|---|---|---|
| **Function** | `drop_text()` (line 495) | No equivalent |

**Recommendation: Port to R.** Three sub-patterns:
1. `"Part [a-z]:"` prefix â€” split on colon, keep the chemical name portion
2. Terminal `\d+%` â€” strip trailing percentage
3. `"modif"` anywhere â€” flag entire name as ambiguous (set to `NA`)

**Note:** The Python version has bugs on lines 512 and 539 (references global `data` instead of the `df` parameter). The R port should not reproduce these.

**Where it goes:** `R/pre_curation.R` â€” name canonicalization step.

---

### 2.3 Reference-Data Filters (Flag, Don't Remove)

These functions use reference lists to identify non-chemical names. In the Python pipeline, they *remove* names. In CONCERT, they should **flag** names for curator review rather than silently removing them.

#### `flag_functional_categories` â€” Flag names matching OECD/EPA functional use categories

| | Python | ComptoxR |
|---|---|---|
| **Function** | `drop_fcs()` / `function_categories()` / `fc_string()` (lines 246-425) | `ComptoxR::chemi_amos_functional_uses_for_dtxsid()` (post-curation only) |

**Recommendation: Port the reference CSV approach.**
- The Python version loads `ChemExpo_FC_2023-05-24.csv` and builds a regex of all functional category names + synonyms.
- ComptoxR's `chemi_amos_functional_uses_for_dtxsid()` requires a DTXSID (only available *after* curation), so it can't help pre-curation.
- **Data dependency:** Need to source or bundle the functional category list. Options:
  1. Bundle a static CSV in `data/` (simplest, requires periodic updates)
  2. Use `ComptoxR::chemi_amos_dtxsids_for_functional_use()` to build the list dynamically at app startup (API-dependent)
  3. Pull from EPA's ChemExpo download page on-demand

**Where it goes:** `R/cleaning_reference.R` for the data loader; `R/pre_curation.R` for the flagging logic.

---

#### `flag_food_names` â€” Flag names that are foods, not chemicals

| | Python | ComptoxR |
|---|---|---|
| **Function** | `drop_foods()` / `foods()` (lines 291-441) | No equivalent |

**Recommendation: Port to R.** Small static list: `yeast culture`, `food starch`, `sweet whey`, `salted fish`, `beverage`.

**Where it goes:** `R/cleaning_reference.R` for the list; `R/pre_curation.R` for flagging.

---

#### `flag_stop_words` â€” Flag ambiguous names (proprietary, blend, inert, etc.)

| | Python | ComptoxR |
|---|---|---|
| **Function** | `drop_stoppers()` / `stops()` (lines 114-491) | `ComptoxR::extract_mixture()` (partial overlap for ratio patterns only) |

**Recommendation: Port the stop-word list to R, combine with `extract_mixture()`.**
- Stop words: `proprietary`, `ingredient`, `hazard`, `blend`, `inert`, `stain`, `other`, `withheld`, `cas`, `secret`, `herbal`, `confidential`, `bacteri`, `treatment`, `contracept`, `emission`, `agent`, `eye`, `resin`, `citron`, `bio`, `smoke`, `fiber`, `adult`, `boy`, `girl`, `infant`, `child`, `other organosilane`, `material`
- Also catches: `polymer`, `polymers`, `wax`, `mixture`, `citron`, `compound`
- Uses `"yl"` exception (names containing "yl" are likely chemical and should not be flagged)

**Where it goes:** `R/cleaning_reference.R` for the list; `R/pre_curation.R` for flagging.

---

#### `flag_block_list` â€” Flag known non-chemical entries

| | Python | ComptoxR |
|---|---|---|
| **Function** | `drop_blocks()` / `block_list()` (lines 692-736) | No equivalent |

**Recommendation: Port to R.** Hard-coded list of ~40 known non-chemical strings (e.g., "alcohol", "PP", "Acrylic Polymer", "Aflatoxins", various drug classes).

**Where it goes:** `R/cleaning_reference.R` for the list; `R/pre_curation.R` for flagging.

---

### 2.4 Encoding / String Utilities

#### `fix_unicode` â€” Replace known Unicode code points with ASCII equivalents

| | Python | ComptoxR |
|---|---|---|
| **Function** | `fix_encodings()` / `known_encodings()` / `has_unicode()` (lines 93-616) | **`ComptoxR::clean_unicode()`** |
| **Approach** | 8 hard-coded mappings, manual loop | 100+ mappings via internal `unicode_map`, works on vectors or whole data frames |
| **Coverage** | `Î±`, `Ï‰`, `Â®`, `â€“`, `Â°`, `'`, `â€¦`, `'` | Full Greek alphabet, math symbols (Â±, â‰¥, â‰¤, Ã—, Ã·), sub/superscripts, accented Latin chars, smart quotes, dashes, scientific units (Âµ, Â°) |
| **Unhandled chars** | Silently ignored | Warns via internal `check_unhandled()` |

**Recommendation: Use `ComptoxR::clean_unicode()`.**
- Massively more comprehensive than the Python version (100+ vs 8 mappings).
- Can operate on an entire data frame at once (processes all character columns).
- Warns about Unicode it couldn't map, so nothing gets silently lost.
- The Python version has a bug on line 596 (`data.copy()` instead of `df.copy()`). Using ComptoxR avoids this entirely.
- No need for a separate `has_unicode()` check â€” `clean_unicode()` handles detection and replacement in one pass. For post-curation QC, `stringi::stri_enc_isascii()` can verify nothing remains.

**Where it goes:** `R/pre_curation.R` â€” very first step, before any regex matching.

---

#### `canonicalize_strings` â€” Strip leading/trailing whitespace and punctuation

| | Python | ComptoxR |
|---|---|---|
| **Function** | `string_cleaning()` (line 619) | No equivalent |

**Recommendation: Port to R.** Strips all punctuation except `()[]{}` from both ends, then trims whitespace.

**Where it goes:** `R/pre_curation.R` â€” applied at start and end of cleaning pipeline.

---

## 3. Post-Curation Functions

These run *after* the tiered CompTox search and consensus classification.

#### `post_validate_cas` â€” Re-validate resolved CAS-RNs

Use `ComptoxR::is_cas()` on `consensus_dtxsid`-associated CAS-RNs to catch any that slipped through.

**Where it goes:** `R/post_curation.R`

---

#### `post_detect_unicode` â€” Flag any remaining Unicode in final output

Use `stringi::stri_enc_isascii()` on final chemical names as a QC check.

**Where it goes:** `R/post_curation.R`

---

#### `post_functional_use_lookup` â€” Enrich resolved chemicals with functional use data

Now that DTXSIDs are known, use `ComptoxR::chemi_amos_functional_uses_for_dtxsid()` or `ComptoxR::chemi_functional_use()` to add functional use categories as metadata.

**Where it goes:** `R/post_curation.R`

---

#### `post_safety_flags` â€” Add safety flag metadata

Use `ComptoxR::chemi_resolver_safety_flags()` or `chemi_resolver_safety_flags_bulk()` on resolved DTXSIDs.

**Where it goes:** `R/post_curation.R`

---

## 4. Audit Trail Infrastructure

### `append_comment()` â€” Cross-cutting audit logging

| | Python | R |
|---|---|---|
| **Function** | `append_col()` (line 131) | New utility |

Every cleaning step should log *what* was changed and *why* in a comment column. The Python pattern uses pipe-separated entries like:

```
Unicode detected: swapped \u03b1 with .alpha. | Extraneous parenthesis: (EPA added) | Name is functional use: surfactant
```

**Recommendation:** Implement as `append_comment(existing, new_text, reason)` in `R/pre_curation.R`.
- Returns: `"reason: new_text"` if `existing` is `NA`; `"existing | reason: new_text"` otherwise.
- Used by every cleaning function to build a transparent audit trail.

---

## 5. Proposed Pipeline Order

Based on the Python pipeline (lines 800-832) and dependencies between steps:

### Pre-Curation Pipeline (`run_pre_curation(df)`)

```
Step  Function                      Comment Column    ComptoxR?
â”€â”€â”€â”€  â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€  â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€  â”€â”€â”€â”€â”€â”€â”€â”€â”€
 1    fix_unicode()                 name_comment      clean_unicode()
 2    canonicalize_strings(name)    â€”                 No
 3    canonicalize_strings(cas)     â€”                 No
 4    normalize_cas()               casrn_comment     as_cas()
 5    rescue_cas_from_names()       name_comment      extract_cas()
 6    detect_formula_names()        name_comment      extract_formulas() (needs eval)
 7    strip_terminal_phrases()      name_comment      No
 8    flag_functional_categories()  name_comment      No (pre-curation)
 9    flag_food_names()             name_comment      No
10    flag_stop_words()             name_comment      extract_mixture() (partial)
11    strip_quality_adjectives()    name_comment      No
12    strip_text_noise()            name_comment      No
13    strip_unspecified()           name_comment      No
14    strip_salt_references()       name_comment      No
15    strip_terminal_phrases()      name_comment      No (second pass)
16    canonicalize_strings(name)    â€”                 No (final pass)
17    split_multi_cas()             casrn_comment     extract_cas()
18    validate_cas()                casrn_comment     is_cas()
19    canonicalize_strings(cas)     â€”                 No (final pass)
20    flag_block_list()             name_comment      No
21    drop_all_null_rows()          â€”                 No
```

### Post-Curation Pipeline (`run_post_curation(df)`)

```
Step  Function                       ComptoxR?
â”€â”€â”€â”€  â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€  â”€â”€â”€â”€â”€â”€â”€â”€â”€
 1    post_validate_cas()            is_cas()
 2    post_detect_unicode()          No (stringi)
 3    post_functional_use_lookup()   chemi_functional_use() or chemi_amos_functional_uses_for_dtxsid()
 4    post_safety_flags()            chemi_resolver_safety_flags_bulk()
 5    export_with_audit_trail()      No
```

---

## 6. ComptoxR Function Mapping Summary

| Python Function | ComptoxR Replacement | Benefit |
|---|---|---|
| `casrn_split()` | `extract_cas()` | Validates before returning; no false positives |
| `checksum()` | `is_cas()` | Format + checksum validation; NA-safe |
| `string_not_casrn()` | `as_cas()` returns `NA` | Implicit; no separate step needed |
| `find_formula()` | `extract_formulas()` (partial) + `pt` data | `extract_formulas()` handles embedded formulas in parens/brackets; `pt` dataset enables building a proper element-aware validator for bare formula strings |
| (none) | `extract_mixture()` | Detects ratio-based mixtures (`60:40 w/w`) â€” new capability |
| `fix_encodings()` + `known_encodings()` + `has_unicode()` | **`clean_unicode()`** | 100+ mappings vs 8; works on whole data frames; warns on unhandled chars |
| `casrn_finder()` | `extract_cas()` + wrapper | Validates extracted CAS-RNs automatically |
| Manual CAS normalization | `as_cas()` | Strips noise, reformats, validates in one call |
| (none â€” post-curation) | `chemi_functional_use()` | OECD functional use enrichment via DTXSID |
| (none â€” post-curation) | `chemi_resolver_safety_flags_bulk()` | Safety flag enrichment via DTXSID |
| (none â€” post-curation) | `chemi_resolver_lookup_bulk()` | Batch chemical resolution |

---

## 7. UI Integration Points

The pre-curation pipeline should integrate into the existing Shiny app flow:

1. **New tab or panel** between "Data Preview" and curation showing cleaning results
2. **Audit trail viewer** â€” expandable per-row comment history showing each transformation
3. **Toggle switches** â€” let user enable/disable individual cleaning steps
4. **Summary cards** â€” counts of: CAS-RNs rescued from names, invalid CAS-RNs removed, formulas detected, functional categories flagged, stop words flagged, block list entries removed
5. **Flagged rows table** â€” rows flagged (not removed) for curator review before curation begins

---

## 8. Data Dependencies

| Resource | Source | Status |
|---|---|---|
| Functional category list (OECD/EPA) | `ChemExpo_FC_2023-05-24.csv` | **Not in repo** â€” needs sourcing |
| Stop-word list | Hard-coded in Python | Port to `R/cleaning_reference.R` |
| Block list | Hard-coded in Python | Port to `R/cleaning_reference.R` |
| Food list | Hard-coded in Python | Port to `R/cleaning_reference.R` |
| Unicode mapping table | Internal to `ComptoxR::clean_unicode()` | **No porting needed** â€” 100+ mappings built in |
| Periodic table (`pt`) | `data(pt, package = "ComptoxR")` | Available for formula validation |
| ComptoxR (v1.4.0) | `seanthimons/ComptoxR` | Installed |

---

## 9. Open Questions

1. **`extract_formulas()` scope:** Confirmed it only extracts formulas inside parentheses/brackets (by design). For detecting bare formula-as-name strings, we need a new `detect_formula_name()` function. The `pt` periodic table dataset from ComptoxR can power a proper element-aware validator instead of the Python regex hack.

2. **Flag vs. Remove:** The Python script removes entries outright. CONCERT should flag for review (more conservative). Should flagged entries still flow into the curation pipeline, or be held back?

3. **Functional category data source:** Bundle static CSV, or pull dynamically from CompTox API at startup? Static is simpler but stales; dynamic requires API key at startup.

4. **Pipeline configurability:** Should individual steps be togglable in the UI, or run as a fixed sequence?

5. **`extract_mixture()` scope:** Currently only detects ratio patterns. Should we expand it with keyword matching ("blend", "mixture", etc.) directly in ComptoxR, or keep that as CONCERT-specific logic?

---

## 10. Real Data Analysis â€” `data/uat/uncurated_chemicals_2023-05-16_12-43-41.csv`

12,144 rows, 4 columns: `id`, `raw_cas`, `raw_chem_name`, `datagroup_id`.

### Issue Frequency in Live Data

| Issue | Est. Rows | % | Example |
|-------|-----------|---|---------|
| Empty CAS, name present | ~1,750 | 14.4% | `,,methylparaben` |
| Multiple synonyms (comma-separated) | ~1,000+ | 8%+ | `"xylene, dimethylbenzene, xylol"` |
| Functional use as name | ~307 | 2.5% | `Flavor`, `PARFUM/FRAGRANCE` |
| "No CAS" placeholders in CAS field | ~296 | 2.4% | `no cas` in raw_cas |
| Proprietary/trade secret/ambiguous | ~265 | 2.2% | `trade secret`, `Proprietary` |
| Stereochemistry prefixes | ~169 | 1.4% | `(dl)-amphetamine`, `(+/-)-mdma` |
| Carbon chain ranges | ~129 | 1.1% | `C12-C16, isoalkanes` |
| Inline percentage/concentration | ~61 | 0.5% | `octinoxate 7500%`, `potassium hydroxide, 45%` |
| Hazard/carcinogen warnings in names | ~35 | 0.3% | `(suspected human carcinogen by ACGIH)` |
| Extraction artifacts (underscores) | ~35 | 0.3% | `aerothane tt_` |
| Semicolon-separated synonyms | Low | <0.1% | `acetone; dimethyl ketone` |

### Gaps Not Covered by `clean_chems.py` or Current ComptoxR

1. **Comma-separated synonym splitting** â€” The biggest cleaning gap. Over 1,000 rows have `"name1, name2, name3"` packed into one field. Neither `clean_chems.py` nor ComptoxR handles this. Tricky because commas also appear inside IUPAC names (e.g., `"2,2-dimethylpropane"`).
2. **Semicolon-separated synonyms** â€” Less common but same splitting problem.
3. **Hazard warning stripping** â€” `term_parenth()` catches some terminal parentheticals, but embedded warnings like `"(suspected human carcinogen by ACGIH, NTP)"` need explicit handling.
4. **Extraction artifact cleanup** â€” Trailing underscores, asterisks around numbers (`*97-3*`).
5. **"No CAS" placeholder detection** â€” Text like `no cas`, `none`, `n/a` in the CAS column.

---

## 11. Prioritized Roadmap

Priority is based on (a) how many rows in the live dataset are affected, (b) how much it blocks downstream curation accuracy, and (c) implementation complexity.

### Phase 1 â€” Foundation (Blocks Everything Else)

**P1.1: Audit trail infrastructure** `R/pre_curation.R`
> Port `append_comment()`. Every subsequent function depends on this.

- Port from: `clean_chems.py:append_col()` (line 131)
- Spec: `append_comment(existing, new_text, reason, sep = " | ")`
  - `existing = NA`, `new_text = "foo"`, `reason = "bar"` â†’ `"bar: foo"`
  - `existing = "prev"`, `new_text = "foo"`, `reason = "bar"` â†’ `"prev | bar: foo"`
  - `new_text = NA` â†’ return `existing` unchanged
- Tests:
  - [x] NA existing + non-NA text â†’ creates new comment
  - [x] Existing comment + non-NA text â†’ appends with separator
  - [x] NA new_text â†’ returns existing unchanged
  - [x] Both NA â†’ returns NA
  - [x] Vectorized over a column

**P1.2: Unicode cleaning** â€” Use `ComptoxR::clean_unicode()`
> Already built. Just wire it into the pipeline.

- No ComptoxR changes needed.
- Wire: `df <- ComptoxR::clean_unicode(df)` on name and CAS columns.
- Log: Diff before/after to populate `name_comment`.
- Tests:
  - [x] Greek letters â†’ `.alpha.` etc.
  - [x] Smart quotes â†’ ASCII quotes
  - [x] Unhandled chars trigger warning

**P1.3: String canonicalization** `R/pre_curation.R`
> Port `string_cleaning()` from Python. Needed before any regex matching.

- Port from: `clean_chems.py:string_cleaning()` (line 619)
- Spec: Strip leading/trailing punctuation (except `()[]{}`) and whitespace. Collapse multiple internal spaces.
- Also handle: trailing underscores (`aerothane tt_`), asterisks (`*97-3*`)
- Tests:
  - [x] `"  Acetone  "` â†’ `"Acetone"`
  - [x] `"#Toluene#"` â†’ `"Toluene"`
  - [x] `"aerothane tt_"` â†’ `"aerothane tt"`
  - [x] `"Sodium  chloride"` â†’ `"Sodium chloride"`
  - [x] Preserves internal parentheses: `"Iron(III) chloride"` unchanged

---

### Phase 2 â€” CAS-RN Pipeline (14.4% + 2.4% of rows)

**P2.1: CAS placeholder detection** `R/pre_curation.R`
> New function â€” not in `clean_chems.py`. Handles ~296 "no cas" rows.

- Spec: `detect_cas_placeholders(cas_vector)` returns logical vector
- Match patterns: `no cas`, `none`, `n/a`, `not available`, `not applicable`, `-`, `unknown`, `confidential`, case-insensitive
- Log to `casrn_comment`, set CAS to `NA`
- Tests:
  - [x] `"no cas"` â†’ TRUE
  - [x] `"N/A"` â†’ TRUE
  - [x] `"7732-18-5"` â†’ FALSE
  - [x] `""` â†’ TRUE
  - [x] `"-"` â†’ TRUE

**P2.2: CAS normalization** â€” Use `ComptoxR::as_cas()`
> Already built. Handles leading zeros, strips non-digit chars, reformats, validates checksum.

- No ComptoxR changes needed.
- Tests: covered by existing ComptoxR tests.

**P2.3: CAS extraction from names** â€” Use `ComptoxR::extract_cas()`
> Already built. Wire into pipeline with audit logging.

- Wrapper needed: `rescue_cas_from_names(df, name_col, cas_col, comment_col)`
  - Calls `extract_cas()` on name column
  - Merges found CAS-RNs into CAS column (dedup with existing)
  - Strips matched CAS patterns from name string
  - Logs to comment
- Tests:
  - [x] `"ethanol (CAS 64-17-5)"` â†’ name becomes `"ethanol"`, CAS becomes `"64-17-5"`
  - [x] Name with no CAS â†’ unchanged
  - [x] CAS already in CAS column â†’ no duplicate

**P2.4: Multi-CAS splitting** `R/pre_curation.R`
> Use `ComptoxR::extract_cas()` + `tidyr::unnest_longer()`

- Spec: `split_multi_cas(df, cas_col, comment_col)`
- Log original multi-CAS string to comment before exploding
- Tests:
  - [x] Single CAS â†’ 1 row
  - [x] Two CAS-RNs â†’ 2 rows, comment logged
  - [x] NA CAS â†’ 1 row, unchanged

**P2.5: CAS checksum validation** â€” Use `ComptoxR::is_cas()`
> Already built. Flag invalid CAS-RNs.

- No ComptoxR changes needed.
- Log failed checksums to `casrn_comment`, set to `NA`.

---

### Phase 3 â€” Name Cleaning Core (8%+ of rows â€” synonym splitting)

**P3.1: Hazard warning stripping** `R/pre_curation.R`
> New function â€” critical because warnings poison synonym splitting and curation lookups.

- Spec: `strip_hazard_warnings(df, name_col, comment_col)`
- Patterns to strip (case-insensitive):
  - `(suspected ... carcinogen ...)`
  - `(confirmed ... carcinogen ...)`
  - `(Irritating to ...)`
  - Generalized: `\((?:suspected|confirmed|known|possible|probable)\s+.*?(?:carcinogen|mutagen|teratogen|irritant).*?\)`
- Must run BEFORE terminal phrase stripping and synonym splitting
- Tests:
  - [x] `"ethylene oxide (suspected 2a human carcinogen by iarc)"` â†’ `"ethylene oxide"`
  - [x] `"carbon black (suspected human carcinogen by ACGIH)"` â†’ `"carbon black"`
  - [x] `"Iron(III) chloride"` â†’ unchanged (not a warning)
  - [x] Comment logs stripped warning text

**P3.2: Terminal phrase stripping** `R/pre_curation.R`
> Port `term_parenth()` and `term_bracket()` as one function.

- Port from: `clean_chems.py` lines 164-242
- Spec: `strip_terminal_enclosures(name, type = c("parens", "brackets", "both"))`
- Key logic: keep if parenthetical contains `"yl"` (chemical name fragment), unless it's a false positive word (`density`, `probably`, `average`, `combination`)
- Tests:
  - [x] `"Acetone (ACS reagent)"` â†’ `"Acetone"`, comment: `"ACS reagent"`
  - [x] `"dimethyl (methyl)"` â†’ unchanged (contains "yl")
  - [x] `"compound (high density)"` â†’ `"compound"` (false positive "yl" in "density")

**P3.3: Synonym splitting** `R/pre_curation.R`
> **NEW â€” not in `clean_chems.py`.** Biggest gap for the live dataset.

- Spec: `split_synonyms(name_string)` â†’ returns primary name + vector of synonyms
- Strategy (ordered):
  1. Split on semicolons first (least ambiguous): `"acetone; dimethyl ketone"` â†’ `["acetone", "dimethyl ketone"]`
  2. Split on commas, but protect IUPAC commas by not splitting inside:
     - Digit-comma-digit patterns: `2,2-dimethyl`, `1,4-dioxane`
     - Parenthesized content: `(1R,3R;1R,3S)`
  3. First element is primary name; rest are synonyms
- **Critical edge cases from live data:**
  - `"2-butoxyethanol (ethyleneglycol monobutyl ether), butyl cellosolve"` â€” comma after parenthetical closes the first synonym
  - `"butane, 2,2-dimethyl"` â€” this is ONE name (IUPAC inverted form), not two
  - `"Hydrocarbons, C12-C16, isoalkanes, cyclic <2% aromatics"` â€” classification descriptor, not synonyms
- This is the hardest function. May need iterative refinement.
- Tests:
  - [x] `"xylene, dimethylbenzene, xylol"` â†’ 3 names
  - [x] `"butane, 2,2-dimethyl"` â†’ 1 name (IUPAC inverted)
  - [x] `"acetone; dimethyl ketone"` â†’ 2 names
  - [x] `"1,4-Dioxane"` â†’ 1 name (comma inside number)
  - [x] Simple name with no separators â†’ 1 name

---

### Phase 4 â€” Reference Data Filters (2.5% + 2.2% of rows)

**P4.1: Functional category flagging** `R/pre_curation.R` + `R/cleaning_reference.R`
> Port from Python. Flags "Flavor", "Fragrance", "surfactant", etc.

- Data needed: Functional category list (static CSV or API-derived)
- For now, build a combined keyword list from the Python extra_fcs + common ones found in data: `fragrance`, `parfum`, `flavor`, `colorant`, `dye`, `detergent`, `additive`, `anti-`, `protectant`, `thermoplastic`, `dispersion`, `plast`, `enzyme`, `thick`, `inhib`, `surfactant`, `emulsifier`, `preservative`, `solvent` (generic), `pigment`
- Tests:
  - [x] `"Flavor"` â†’ flagged
  - [x] `"PARFUM/FRAGRANCE"` â†’ flagged
  - [x] `"yellow colorant"` â†’ flagged
  - [x] `"sodium chloride"` â†’ not flagged
  - [x] `"methylparaben"` â†’ not flagged (contains chemical suffix)

**P4.2: Ambiguous name flagging** `R/pre_curation.R` + `R/cleaning_reference.R`
> Port stop-word list + `extract_mixture()` integration.

- Combine: Python `stops()` + `"trade secret"`, `"confidential"`, `"not established"`, `"no cas"` name-side equivalents
- Keep the `"yl"` exception from Python
- Use `ComptoxR::extract_mixture()` for ratio-pattern detection
- Tests:
  - [x] `"proprietary blend"` â†’ flagged (stop word)
  - [x] `"trade secret"` â†’ flagged
  - [x] `"polymer"` â†’ flagged
  - [x] `"methyl ethyl ketone"` â†’ NOT flagged (`"yl"` exception)
  - [x] `"Ethanol, water (1:1)"` â†’ flagged by `extract_mixture()`

**P4.3: Block list flagging** `R/pre_curation.R` + `R/cleaning_reference.R`
> Port block_list() from Python + add entries found in live data.

- Tests:
  - [x] `"alcohol"` â†’ flagged
  - [x] `"Acrylic Polymer"` â†’ flagged
  - [x] `"acetone"` â†’ NOT flagged

---

### Phase 5 â€” Name Cleaning Detail (Smaller issue counts but improves curation hit rate)

**P5.1: Quality adjective stripping** `R/pre_curation.R`
> Port from `clean_chems.py:drop_text()` lines 521-535.

- Words: `pure`, `purif`, `tech`, `grade`, `chemical`
- Tests:
  - [x] `"Acetone (99.5%)"` â†’ after P3.2 strips parens; this strips remaining "grade" text
  - [x] `"technical grade ethanol"` â†’ `"ethanol"`, comment logs `"technical grade"`

**P5.2: "Unspecified" and salt reference stripping** `R/pre_curation.R`
> Port `terminal_unspecified()` and `drop_salts()`.

- Tests:
  - [x] `"acid, unspecified"` â†’ `"acid"`, comment logged
  - [x] `"lead and its salts"` â†’ `"lead"`, comment logged

**P5.3: Formula-as-name detection** `R/pre_curation.R`
> Uses `ComptoxR::pt` data to validate elements.

- Spec: `is_formula_name(name_string)` â†’ logical
- Build regex from `pt$symbol`: string must be composed entirely of `(Element)(Digits?)+`
- Handle: `H2O`, `NaCl`, `C2H5OH`, `CuSO4`
- Do NOT flag: `"water"`, `"Acetone"`, mixed text+formula
- Tests:
  - [x] `"H2O"` â†’ TRUE
  - [x] `"NaCl"` â†’ TRUE
  - [x] `"C2H5OH"` â†’ TRUE
  - [x] `"water"` â†’ FALSE
  - [x] `"H2O and stuff"` â†’ FALSE (not bare formula)

**P5.4: Food name flagging** `R/cleaning_reference.R`
> Port `foods()` list.

- Small list, low priority. Quick port.

---

### Phase 6 â€” Post-Curation QC

**P6.1: Post-validation CAS check** â€” `ComptoxR::is_cas()`
**P6.2: Remaining Unicode check** â€” `stringi::stri_enc_isascii()`
**P6.3: Functional use enrichment** â€” `ComptoxR::chemi_functional_use()`
**P6.4: Safety flag enrichment** â€” `ComptoxR::chemi_resolver_safety_flags_bulk()`

---

## 12. ComptoxR Adjustments Needed

### 12.1 `extract_mixture()` â€” Expand to keyword detection

**Current behavior:** Only detects ratio patterns like `(1:1)`, `3:1 w/w`.
**Problem:** Misses keyword-based mixtures: `"mixture of acids"`, `"blend of oils"`, `"proprietary blend"`.
**Live data impact:** ~200 rows with keyword mixtures that ratio detection misses.

**Proposed change:** Add optional `keywords` parameter.

```r
extract_mixture <- function(name_vector, include_keywords = FALSE) {
  # ... existing ratio detection ...
  ratio_hit <- stringr::str_detect(name_vector, pattern)

  if (include_keywords) {
    kw <- "\\b(mixture|blend|combination|formulation|compound(?:ed)?|composition)\\b"
    keyword_hit <- stringr::str_detect(name_vector, stringr::regex(kw, ignore_case = TRUE))
    return(ratio_hit | keyword_hit)
  }
  ratio_hit
}
```

- **Backward compatible:** Default `include_keywords = FALSE` preserves current behavior.
- Tests:
  - [x] `"Ethanol, water (1:1)"` â†’ TRUE (ratio, same as before)
  - [x] `"mixture of acids"` â†’ FALSE with default, TRUE with `include_keywords = TRUE`
  - [x] `"sodium chloride"` â†’ FALSE in both modes
  - [x] `"compounded rubber"` â†’ TRUE with keywords (word boundary prevents matching "compound" inside chemical names like "organic compound")

### 12.2 `extract_formulas()` â€” No changes needed

**Current behavior:** Extracts formulas from within parentheses/brackets only.
**Assessment:** This is the correct design for its purpose (extracting embedded formulas from name strings like `"Water (H2O)"`). The bare-formula-as-name detection is a different use case better served by a new `is_formula_name()` function.

### 12.3 `clean_unicode()` â€” Evaluate for chemical-specific additions

**Action:** Test against the live dataset to see if `check_unhandled()` flags any unmapped characters. If so, add mappings to the internal `unicode_map`.

### 12.4 `as_cas()` â€” Evaluate stricter non-CAS detection

**Current behavior:** Strips non-digits, reformats, validates.
**Potential issue:** Strings like `"no cas"` contain digits? No â€” `"no cas"` has no digits so `as_cas()` already returns `NA`. But strings like `"CAS: 7732-18-5"` will correctly extract `7732-18-5`. Current behavior is correct.

**No changes needed.**

---

## 13. New ComptoxR Function: `is_formula_name()`

### Requirements

Detect whether a string is *entirely* a molecular formula (not embedded in other text).

### Spec

```r
#' Test whether a string is a bare molecular formula
#'
#' Uses the periodic table to validate that a string consists only of
#' element symbols and stoichiometric numbers. Does not match formulas
#' embedded in larger text â€” use extract_formulas() for that.
#'
#' @param x Character vector of strings to test
#' @return Logical vector: TRUE if the string is a bare formula, FALSE otherwise, NA for NA input
#' @export
is_formula_name <- function(x) { ... }
```

### Implementation approach

1. Load element symbols from `ComptoxR::pt` (or the internal `elements_list` already in `extract_mol_formula.R`)
2. Build regex: `^(Element)(\\d*))+$` where Element is the alternation of all symbols, ordered longest-first to avoid partial matches (`Na` before `N`)
3. Also allow: hydrate notation (`Â·`, `.`), charge notation (`+`, `-`), grouped substructures with parentheses
4. Reject: strings shorter than 2 chars, strings with spaces (those are names, not formulas), strings that are just numbers

### Testable outcomes

| Input | Expected | Reason |
|-------|----------|--------|
| `"H2O"` | TRUE | Simple formula |
| `"NaCl"` | TRUE | Ionic compound, no digits needed |
| `"C2H5OH"` | TRUE | Organic formula |
| `"CuSO4"` | TRUE | Inorganic formula |
| `"Ca(OH)2"` | TRUE | Grouped substructure |
| `"water"` | FALSE | English word, lowercase `w` is not tungsten in context |
| `"Acetone"` | FALSE | Has lowercase letters not matching elements |
| `"H2O and more"` | FALSE | Contains spaces/extra text |
| `NA` | NA | NA passthrough |
| `""` | FALSE | Empty string |
| `"123"` | FALSE | Just digits |
| `"CO"` | TRUE | Carbon monoxide (ambiguous with Colorado abbreviation, but chemically valid) |
| `"Iron"` | FALSE | Element name, not symbol |

### Edge cases to document

- `"CO"` vs `"Co"`: `CO` = carbon + oxygen (formula); `Co` = cobalt (element symbol). Both are technically valid formulas. This is acceptable.
- Single-element symbols like `"S"`, `"P"`, `"I"` are technically valid formulas but may cause false positives on single-character strings. Consider requiring `nchar(x) >= 2`.

---

## 14. New ComptoxR Function: `extract_hazard_warnings()`

### Requirements

Extract and return hazard/carcinogen warning parentheticals from chemical name strings. This is thematically correct for ComptoxR since it relates to chemical safety classification.

### Spec

```r
#' Extract hazard warning parentheticals from chemical names
#'
#' Finds and extracts parenthetical phrases containing hazard classification
#' language (carcinogen, mutagen, teratogen, irritant) from chemical name strings.
#'
#' @param name_vector Character vector of chemical names
#' @return A list of character vectors (one per input). Each contains the
#'   warning text found, or character(0) if none.
#' @export
extract_hazard_warnings <- function(name_vector) { ... }
```

### Implementation approach

Pattern (case-insensitive):
```r
"\\(([^)]*(?:carcinogen|mutagen|teratogen|irritant|hazard|toxic)[^)]*)\\)"
```

### Testable outcomes

| Input | Expected |
|-------|----------|
| `"ethylene oxide (suspected 2a human carcinogen by iarc)"` | `"suspected 2a human carcinogen by iarc"` |
| `"lampblack (suspected human carcinogen by ACGIH)"` | `"suspected human carcinogen by ACGIH"` |
| `"Fragrance (Irritating to eyes)"` | `"Irritating to eyes"` |
| `"Iron(III) chloride"` | `character(0)` â€” oxidation state, not warning |
| `"acetone"` | `character(0)` |
| `"compound (toxic to aquatic life)"` | `"toxic to aquatic life"` |

---

## 15. Functions to Port to CONCERT (Not Thematically Correct for ComptoxR)

These are application-specific cleaning operations that belong in `R/pre_curation.R` or `R/cleaning_reference.R`, not in a reusable chemistry package.

### 15.1 `append_comment()` â€” Audit trail helper

See P1.1 above. CONCERT-specific infrastructure.

### 15.2 `canonicalize_strings()` â€” Generic string cleanup

See P1.3 above. Too generic for a chemistry package.

### 15.3 `detect_cas_placeholders()` â€” "No CAS" detection

See P2.1 above. Application-specific (handles data entry conventions, not chemistry).

### 15.4 `split_synonyms()` â€” Comma/semicolon synonym splitting

See P3.3 above. Highly context-dependent heuristic, not generalizable.

### 15.5 `strip_quality_adjectives()` â€” Remove "tech grade", "pure", etc.

See P5.1 above. Domain-specific text munging.

### 15.6 `strip_unspecified()` â€” Remove trailing ", unspecified"

See P5.2 above. Trivial regex, app-specific.

### 15.7 `strip_salt_references()` â€” Remove "and its salts"

See P5.2 above. Narrow regex, app-specific.

### 15.8 Reference data lists â€” Stop words, block list, food names, functional categories

See Phase 4. These are curated lists that live in `R/cleaning_reference.R`:

```r
# R/cleaning_reference.R

cleaning_stop_words <- function() {
  c("proprietary", "ingredient", "hazard", "blend", "inert", "stain",
    "other", "withheld", "secret", "herbal", "confidential", "bacteri",
    "treatment", "contracept", "emission", "agent", "eye", "resin",
    "citron", "bio", "smoke", "fiber", "adult", "boy", "girl",
    "infant", "child", "other organosilane", "material",
    "trade secret", "not established", "not available")
}

cleaning_block_list <- function() {
  c("alcohol", "Bly", "Polyester", "Alkanes", "alkanes", "red 4, 33",
    "rose", "PP", "Amine soap", "Free Amines", "Acrylic Polymer",
    "Acrylic Polymers", "Urethane Polymer", "Caustic Salt", "",
    "Aflatoxins", "Aminoglycosides", "Anabolic steroids",
    "Analgesic mixtures containing Phenacetin", "Aristolochic acids",
    "Barbiturates", "Benzodiazepines", "Conjugated estrogens",
    "Dibenzanthracenes", "Estrogens, steroidal",
    "Estrogen-progestogen (combined) used as menopausal therapy",
    "Etoposide in combination with cisplatin and bleomycin",
    "Cyanide salts that readily dissociate in solution (expressed as cyanide)f",
    "Organic electrolyte principally involves ester carbonate",
    "Organic Solvent", "Lithium Salt")
}

cleaning_food_names <- function() {
  c("yeast culture", "food starch", "sweet whey", "salted fish", "beverage")
}

cleaning_functional_categories <- function() {
  # Core keywords â€” expandable. Does NOT require ChemExpo CSV.
  c("fragrance", "parfum", "flavor", "colorant", "dye", "detergent",
    "additive", "anti-", "protectant", "thermoplastic", "dispersion",
    "plast", "enzyme", "thick", "inhib", "surfactant", "emulsifier",
    "preservative", "pigment", "solvent", "lubricant", "stabilizer",
    "filler", "binder", "catalyst", "propellant", "defoamer",
    "dispersant", "sequestrant", "chelat")
}
```

### 15.9 `strip_terminal_enclosures()` â€” Remove trailing `(...)` or `[...]`

See P3.2 above. The `"yl"` heuristic is CONCERT-specific domain knowledge, not generalizable.

---

## 16. Test Dataset Coverage Assessment

The existing `data/chemical_validation_test.csv` (103 rows) covers:

| Issue | Covered? | Gap |
|-------|----------|-----|
| CAS format validation | Yes (13 records) | â€” |
| CAS checksum | Yes (4 records) | â€” |
| Name-CAS mismatch | Yes (4 records) | â€” |
| Missing data | Yes (3 records) | â€” |
| Typos in names | Yes (3 records) | â€” |
| Special chars in names | Yes (2 records) | â€” |
| Whitespace issues | Yes (2 records) | â€” |
| Quotes/semicolons/pipes | Yes (3 records) | â€” |
| Names with qualifiers | Yes (7 records) | â€” |
| **Comma-separated synonyms** | **No** | Need 5+ records |
| **Hazard warnings in names** | **No** | Need 3+ records |
| **Functional use as name** | **No** | Need 5+ records |
| **Stereochemistry prefixes** | **No** | Need 3+ records |
| **Carbon chain ranges** | **No** | Need 3+ records |
| **Formulas as names** | **No** | Need 3+ records |
| **"No CAS" placeholders** | **No** | Need 3+ records |
| **Unicode characters** | **No** | Need 3+ records |
| **Mixture ratios** | **No** | Need 2+ records |
| **Extraction artifacts** | **No** | Need 2+ records |
| **Ambiguous/proprietary names** | **No** | Need 3+ records |
| **Guaranteed API misses** | Yes (3 records) | â€” |

**Recommendation:** Extend test dataset with ~40 additional records covering the gaps before implementing the pipeline. This ensures every cleaning function can be validated against known test cases.
