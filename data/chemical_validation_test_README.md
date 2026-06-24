# Chemical Validation Test Dataset

This dataset contains 172 chemical records for testing chemical name and CASRN validation logic,
including pre-curation cleaning pipeline evaluation.

## File Structure

**File:** `chemical_validation_test.csv`

**Columns:**
- `chemical_name`: Chemical name (common or IUPAC)
- `casrn`: CAS Registry Number
- `expected_validity`: Whether the record should validate as "valid" or "invalid"
- `issue_type`: Description of the validation issue (NA for valid records)

## Dataset Composition

### Original Records (104 total)

#### Valid Records (67 total)
- **25 basic chemicals**: Common laboratory chemicals with correct CAS numbers
- **18 inorganic salts and compounds**: Metals, salts, acids, bases
- **8 organic solvents**: Alcohols, ethers, chlorinated solvents
- **7 chemicals with qualifiers**: Names including concentration, grade, or notes in parentheses/brackets
- **9 additional common chemicals**: Including 2-Propanol, n-Hexane, acetonitrile, etc.

#### Invalid Records (37 total)

**CAS Number Format Issues (14 records)**
- **wrong_check_digit** (4): CAS numbers with incorrect check digit
- **missing_hyphens** (2): CAS numbers without proper hyphen separators
- **malformed_format** (1): Incorrect segment structure
- **wrong_separator** (1): Using periods instead of hyphens
- **invalid_characters** (2): Non-numeric characters in CAS
- **too_many_digits** (1): Wrong number of digits in final segment
- **wrong_segment_length** (1): Incorrect first or middle segment length
- **no_hyphens_invalid_format** (1): Completely wrong format
- **incomplete_format** (1): Missing final segment

**Name-CAS Mismatches (4 records)**
- Correct CAS format but wrong CAS for the chemical name

**Missing Data (3 records)**
- Missing CASRN, missing name, completely empty

**Name Quality Issues (10 records)**
- Typos, special characters, whitespace issues, problematic quotes, semicolons, pipes

**Guaranteed API Misses (3 records)**
- Fabricated names that should never resolve via CompTox lookup

---

### Supplemental Records — Pre-Curation Pipeline Testing (69 total)

All sourced from `data/uat/uncurated_chemicals_2023-05-16_12-43-41.csv` and
`data/uat/cleaned_chemicals_for_curation-Jul-03-2023.xlsx`.

#### Comma/Semicolon-Separated Synonyms (7 records)

| issue_type | Example | Source |
|---|---|---|
| `comma_separated_synonyms` | `"xylene, dimethylbenzene, xylol"` | row 600533 |
| `comma_separated_synonyms` | `"sodium hydroxide, caustic soda, lye"` | row 600588 |
| `comma_separated_synonyms` | `"butane, n-butane"` | row 600537 |
| `semicolon_separated_synonyms` | `"acetone; dimethyl ketone"` | row 600535 |
| `iupac_inverted_name` | `"butane, 2,2-dimethyl"` | row 600622 — comma is part of IUPAC, NOT a separator |
| `synonyms_with_parenthetical` | `"2-butoxyethanol (...), butyl cellosolve, ..."` | row 600478 |
| `semicolon_synonyms_with_stereo` | `"d-Allethrin;(Pynamin forte); ..."` | row 5545325 |

**Pipeline tests:** synonym splitting must NOT split IUPAC commas (`2,2-dimethyl`). Must handle mixed separators.

#### Hazard Warnings in Names (4 records)

| issue_type | Example | Source |
|---|---|---|
| `hazard_warning_in_name` | `"...lampblack (suspected human carcinogen by ACGIH)..."` | row 600480 |
| `hazard_warning_in_name` | `"ethylene oxide (suspected 2a human carcinogen by iarc...)"` | row 600585 |
| `hazard_warning_in_name` | `"dichloromethane (...) (suspected human carcinogen by ACGIH, NTP)"` | row 600705 |
| `hazard_warning_in_name` | `"silica dioxide, ... (suspected humancarcinogen by iarc, ntp)"` | row 600487 |

**Pipeline tests:** strip hazard parentheticals, preserve chemical name and other parentheticals (e.g., "(methylene chloride)").

#### Functional Use Categories as Names (7 records)

| issue_type | Example | Source |
|---|---|---|
| `functional_use_as_name` | `Fragrance (Irritating to eyes)` | row 5543890 |
| `functional_use_as_name` | `PARFUM/FRAGRANCE` | row 5543892 |
| `functional_use_as_name` | `Flavor` | row 5436712 |
| `functional_use_with_trade_secret` | `fragrance` (CAS: `trade secret`) | row 5515583 |
| `functional_use_as_name` | `Surfactant` (CAS: `Proprietary`) | row 5436630 |
| `functional_use_as_name` | `Non-Hazardous Ingredient` | row 5542078 |
| `functional_use_as_name` | `non ionic surfactant` (CAS: `blend`) | row 6946 |

**Pipeline tests:** flag as non-chemical. "Fragrance (Irritating to eyes)" should strip hazard warning AND flag as functional use.

#### Stereochemistry Prefixes (5 records)

| issue_type | Example | Source |
|---|---|---|
| `stereochemistry_prefix` | `(dl)-amphetamine` | row 5436472 |
| `stereochemistry_prefix` | `(d)-amphetamine` | row 5436473 |
| `stereochemistry_prefix` | `(+/-)-mdma` | row 5436480 |
| `stereochemistry_prefix` | `"1r,2s (-)-norephedrine"` | row 5436488 |
| `stereochemistry_prefix` | `d-Limonene` | row 5523904 |

**Pipeline tests:** stereochemistry notation MUST be preserved. These are valid chemical identifiers.

#### Carbon Chain Ranges (5 records)

| issue_type | Example | Source |
|---|---|---|
| `carbon_chain_range` | `"Hydrocarbons, C12-C16, isoalkanes,cyclic <2% aromatics"` | row 5545326 |
| `carbon_chain_range` | `"Hydrocarbons, C11-C13, isoalkanes, <2% aromatics"` | row 5545327 |
| `carbon_chain_range` | `"naphtha petroleum, heavy alkylate c9-c12 boiling pt"` | row 600578 |
| `carbon_chain_range` | `C11-15 Alkane/Cycloalkane` | row 5523866 |
| `carbon_chain_range` | `"alcohols, c12-18, ethoxylated"` | row 5515585 |

**Pipeline tests:** preserve carbon range notation. Should not be misidentified as formulas.

#### Formulas as Names (4 records)

| issue_type | Example | Source |
|---|---|---|
| `formula_as_name` | `C9H20` (CAS: 111-84-2) | row 5436369 |
| `formula_as_name` | `C10H22` (CAS: 124-18-5) | row 5436370 |
| `formula_as_name` | `NaCl` (CAS: 7647-14-5) | row 5436349 |
| `formula_as_name` | `CaCl2` (CAS: 10043-52-3) | row 5436348 |

**Pipeline tests:** flag name as formula-only. Preserve CAS-RN. Python pipeline set name to NA with comment "Name only formula: C9H20".

#### Abbreviations as Names (2 records)

| issue_type | Example | Source |
|---|---|---|
| `abbreviation_as_name` | `DEHP` (CAS: 117-81-7) | row 5436346 |
| `abbreviation_as_name` | `PFOA` (no CAS) | row 5436789 |

**Pipeline tests:** abbreviations are valid search terms. Should NOT be flagged as formulas.

#### CAS-RN as Dash Only (1 record)

| issue_type | Example | Source |
|---|---|---|
| `formula_with_dash_cas` | `C37H76` (CAS: `-`) | row 5436397 |

**Pipeline tests:** `-` in CAS should be treated as missing (set to NA). Formula name should be flagged.

#### CAS Placeholder Text (8 records)

| issue_type | Example | Source |
|---|---|---|
| `cas_placeholder` | CAS: `no cas` | synthetic |
| `cas_placeholder` | CAS: `none` | synthetic |
| `cas_placeholder` | CAS: `n/a` | synthetic |
| `cas_placeholder` | CAS: `-` | row 5436397 |
| `cas_placeholder_proprietary` | CAS: `proprietary` | row 5546751 |
| `cas_placeholder_proprietary` | CAS: `proprietary` | row 6330 |
| `cas_placeholder_text` | CAS: `Blanding` | row 5514980 |
| `cas_placeholder_withheld` | CAS: `Withheld` | row 5514242 |

**Pipeline tests:** all should be detected as non-CAS and set to NA. Comment should log original value.

#### Unicode Characters in Names (3 records)

| issue_type | Example | Source |
|---|---|---|
| `unicode_in_name` | `Palygorskite fibers (> 5µm in length)` — micro sign | row 5541668 |
| `unicode_in_name` | `TRIM® VX` — registered trademark | row 5541845 |
| `unicode_in_name` | `Vertasil®  Trisiloxanyl-cannabidiol` — registered trademark + double space | row 5545839 |

**Pipeline tests:** `µ` → `u` or `micro`, `®` → `(registered trademark)` or stripped. `clean_unicode()` should handle these.

#### Percentage/Concentration in Names (4 records)

| issue_type | Example | Source |
|---|---|---|
| `trailing_percentage` | `octinoxate 7500%` | row 3833521 |
| `trailing_percentage` | `oxybenzone 4000%` | row 3833522 |
| `inline_percentage` | `"potassium hydroxide, 45%<=conc<50%, aqueous solutions"` | row 5524489 |
| `inline_percentage` | `"alkyl (68% c12, 32% c14) dimethyl ethylbenzyl ammonium chloride"` | row 5524477 |

**Pipeline tests:** trailing percentages should be stripped. Inline percentages should be preserved (they are part of the chemical description).

#### Mixture Ratios / Stoichiometry (3 records)

| issue_type | Example | Source |
|---|---|---|
| `mixture_ratio` | `"Ethanol, water (1:1)"` | synthetic |
| `stoichiometric_ratio` | `"aluminum silicate (2:1)"` | row 600486 |
| `stoichiometric_ratio` | `"chromium (iii) oxide (2:3), cr2-o3, chromium oxide"` | row 600574 |

**Pipeline tests:** `extract_mixture()` should flag `(1:1)`. Stoichiometric ratios like `(2:1)` are part of compound identity — should NOT be stripped. This is a key distinction.

#### Extraction Artifacts (2 records)

| issue_type | Example | Source |
|---|---|---|
| `extraction_artifact_underscore` | `"...aerothane tt_, chlorothene"` — trailing underscore | row 600491 |
| `extraction_artifact_mixed` | `"...glycol eb *97-3*"` — asterisks around number | row 600717 |

**Pipeline tests:** strip trailing underscores and asterisks during string canonicalization.

#### Modified Names (1 record)

| issue_type | Example | Source |
|---|---|---|
| `modified_name` | `corn starch modified` | row 4794182 |

**Pipeline tests:** Python pipeline sets name to NA with comment "Unknown modification". The R pipeline should flag this.

#### Ambiguous/Generic Names (7 records)

| issue_type | Example | Source |
|---|---|---|
| `ambiguous_proprietary` | `"Natural Fruit Extracts (Vapour's proprietary natural perfume blend)"` | row 5546778 |
| `ambiguous_block_list` | `alcohol` (CAS: 64-17-5) | row 4792213 |
| `ambiguous_generic` | `Organic Solvent` | row 5413657 |
| `ambiguous_generic` | `Lithium Salt` | row 5413658 |
| `ambiguous_generic` | `lead compounds` | row 5436802 |
| `ambiguous_with_mixture_cas` | `rust inhibitor` (CAS: `mixture`) | row 5521881 |
| `ambiguous_herbal_blend` | `"Herbal blend [(Olea Europaea), (Ginkgo Biloba)]"` | row 3931862 |
| `ambiguous_herbal_blend` | `100% pure certified natural herbal fragrance from essential oils` | row 3943491 |

**Pipeline tests:** flag as ambiguous. "alcohol" is on the block list. "Organic Solvent" and "Lithium Salt" are functional categories. "mixture" in CAS field is a placeholder.

#### Salt References (3 records)

| issue_type | Example | Source |
|---|---|---|
| `salt_reference` | `Benzidine [and its salts]` | row 5541051 |
| `salt_reference` | `Perfluorooctane sulfonic acid (PFOS) and its salts and transformation and degradation precursors` | row 5541681 |
| `salt_reference` | `o-Phenylenediamine and its salts` | row 5541694 |

**Pipeline tests:** strip "and its salts" suffix. Preserve base compound name.

#### Unusual Notation (2 records)

| issue_type | Example | Source |
|---|---|---|
| `unusual_notation` | `"Trans+cis,decahydronaphthalene"` — plus sign for isomers | row 5436362 |
| `unusual_notation` | `1.3 dimethoxy-2-propanol` — period instead of comma in position | row 5436363 |

**Pipeline tests:** preserve as-is. These are valid (if unconventional) chemical notation.

---

## CAS Number Format Rules

Valid CAS numbers follow the format: `NNNNN-NN-N` where:
- First segment: 2-7 digits
- Second segment: 2 digits
- Third segment: 1 check digit
- Segments separated by hyphens

**Check Digit Calculation:**
1. Take all digits from right to left (excluding hyphens and check digit)
2. Multiply each by its position (1, 2, 3, ...)
3. Sum the products
4. Take modulo 10

Example for 67-64-1:
```
From right to left before check digit: 4, 6, 7, 6
1×4 + 2×6 + 3×7 + 4×6 = 4 + 12 + 21 + 24 = 61
61 % 10 = 1 ✓
```

## Test Coverage Summary

| Category | Count | Tests |
|---|---|---|
| Valid basic chemicals | 25 | CAS format + checksum |
| Valid inorganic compounds | 18 | CAS format + checksum |
| Valid organic solvents | 8 | CAS format + checksum |
| Valid with qualifiers | 7 | Preserve parenthetical info |
| Valid additional chemicals | 9 | CAS format + checksum |
| CAS format errors | 14 | Detect invalid formats |
| Name-CAS mismatches | 4 | Cross-validation |
| Missing data | 3 | Handle empty fields |
| Name quality issues | 10 | String cleaning |
| Guaranteed API misses | 3 | CompTox miss handling |
| **Comma/semicolon synonyms** | **7** | **Synonym splitting** |
| **Hazard warnings** | **4** | **Warning extraction** |
| **Functional use names** | **7** | **FC flagging** |
| **Stereochemistry** | **5** | **Preserve notation** |
| **Carbon chain ranges** | **5** | **Preserve notation** |
| **Formulas as names** | **4** | **Formula detection** |
| **Abbreviations** | **2** | **Not flagged as formula** |
| **CAS placeholders** | **8** | **Placeholder detection** |
| **Unicode** | **3** | **clean_unicode()** |
| **Percentages** | **4** | **Strip trailing, preserve inline** |
| **Mixture/stoichiometric ratios** | **3** | **extract_mixture()** |
| **Extraction artifacts** | **2** | **String canonicalization** |
| **Modified names** | **1** | **Flag modification** |
| **Ambiguous/generic names** | **8** | **Stop word + block list** |
| **Salt references** | **3** | **Strip salt suffix** |
| **Unusual notation** | **2** | **Preserve as-is** |
| **Dash-only CAS** | **1** | **Treat as missing** |
| **TOTAL** | **172** | |
