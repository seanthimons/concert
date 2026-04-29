# Phase 37: Performance Architecture - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md -- this log preserves the alternatives considered.

**Date:** 2026-04-24
**Phase:** 37-performance-architecture
**Areas discussed:** Dedup eligibility, Pre-check behavior, Harmonization dedup, Migration sequence

---

## Dedup Eligibility

| Option | Description | Selected |
|--------|-------------|----------|
| All string-in/string-out steps | Dedup every step that takes a character vector and returns same-length vector. Excludes synonym splitting, CAS rescue, multi-CAS detection. Maximum speedup. | ✓ |
| Only column-agnostic steps | Dedup only steps operating on ALL character columns (unicode, whitespace). Skip tag-dependent steps. Safer but less speedup. | |
| Conservative -- top 3 | Identify 3 highest-volume steps and dedup only those. Minimal risk, partial speedup. | |

**User's choice:** All string-in/string-out steps
**Notes:** None

### Follow-up: Tagged column scope

| Option | Description | Selected |
|--------|-------------|----------|
| Only tagged columns | CAS steps dedup CAS-tagged, Name steps dedup Name-tagged. Matches how steps already work. | ✓ |
| All character columns always | Extract distinct across all columns regardless of tags. Simpler but wastes overhead on untagged columns. | |

**User's choice:** Only tagged columns
**User clarification:** Other tagged columns should also be evaluated when they are harmonizing the data. Rule is "any column a step actually processes gets deduped."

### Follow-up: Red-team and uniqueness bypass

Red-teamed the "dedup any processed column" decision. Identified three risks:
1. Cross-column steps (CAS rescue, multi-CAS) break per-column dedup -- excluded from dedup
2. High-uniqueness columns waste overhead -- led to uniqueness threshold decision
3. Steps that change dataframe shape need exclusion

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-bypass above 50% unique | dedup_step() checks n_distinct/n_total, bypasses if >0.5. Avoids overhead on high-uniqueness columns. | ✓ |
| Always dedup | Always extract distinct regardless of ratio. Simpler but pays overhead when it doesn't help. | |
| You decide | Claude picks. | |

**User's choice:** Auto-bypass above 50% unique

---

## Pre-check Behavior

### Audit trail for skipped steps

| Option | Description | Selected |
|--------|-------------|----------|
| Empty typed row | Zero-row tibble with correct 6 columns. Consistent with SKIP-02. | |
| Single summary row | One audit row per skipped step with reason. Visible in export. | |
| Both -- empty typed + log message | Empty typed tibble for code + message() log for debugging. | ✓ |

**User's choice:** Both -- empty typed + log message

### Pre-check thoroughness

| Option | Description | Selected |
|--------|-------------|----------|
| Cheap column scan | Full column vectorized test. O(n) but fast. FALSE guarantees no work. | ✓ |
| Sampled check | Sample first 1000 rows. Faster but can miss rare occurrences. | |
| Full scan + estimated count | Scan whole column AND count approximate matches. Dual-purpose for Phase 42 modal. | |

**User's choice:** Cheap full-column scan using stringr/stringi primitives
**Notes:** User noted stringr/stringi already have detect functions (e.g., `stringi::stri_enc_isascii()`)

### Pre-check return type

| Option | Description | Selected |
|--------|-------------|----------|
| Just TRUE/FALSE | Simple predicates. Phase 42 adds counts later. | |
| list(should_run, est_changes) | Richer return with boolean + estimated change count. Front-loads Phase 42 needs. | ✓ |
| You decide | Claude picks. | |

**User's choice:** list(should_run, est_changes)

---

## Harmonization Dedup

Initial question rejected -- user asked for clarification on harmonize_units() function behavior.

After reviewing the actual code (3 conversion paths: standard table lookup, ppx media routing, molarity MW-dependent), user confirmed "double dedup" intuition:
- Level 1: unit-key dedup (where the savings are -- lookup/classification logic)
- Level 2: value dedup (not needed -- multiplication is O(1) vectorized)

| Option | Description | Selected |
|--------|-------------|----------|
| Unit-key dedup | Dedup on distinct unit combo per conversion path. Broadcast multiply to all rows. | ✓ |
| Full (value, unit) pair dedup | Dedup on distinct pairs. Minimal additional savings beyond unit-key. | |
| You decide | Claude picks. | |

**User's choice:** Unit-key dedup

---

## Migration Sequence

### Overall order

| Option | Description | Selected |
|--------|-------------|----------|
| Simple-first | unicode -> whitespace -> name chain -> harmonization. Prove wrapper first. | |
| Impact-first | Name chain first for maximum early speedup. Higher risk. | |
| Parallel tracks | Cleaning simple-first + harmonization simultaneously. Independent codepaths. | ✓ |

**User's choice:** Parallel tracks

### Name chain migration approach

Initial options red-teamed at user's request. Key finding: **synonym splitting is inside the name chain and changes row count**, making "entire chain as one dedup" impossible. This structural constraint led to a fourth option.

Red-team findings:
- Option 1 (individual): 8 dedup cycles with overhead; distinct set shifts between steps
- Option 2 (dependency clusters): Natural pairs don't actually cluster well; boundary is subjective
- Option 3 (entire chain): BROKEN -- synonym split is embedded in the chain, breaks remap

| Option | Description | Selected |
|--------|-------------|----------|
| Two dedup passes at synonym boundary | Pre-synonym steps share one dedup pass. Synonym split runs without dedup. Post-synonym steps share second pass. 2 cycles instead of 8. | ✓ |
| Individually per sub-step | Each sub-step gets own dedup cycle except synonym split. 8 cycles. Maximum isolation. | |
| Individual first, consolidate later | Start individual, refactor to two-pass once proven. Safety first. | |

**User's choice:** Two dedup passes at synonym boundary

---

## Claude's Discretion

- dedup_step() wrapper and remap_audit_to_parent() internals
- Pre-check predicate function signatures and naming
- SKIP-03 false-negative companion test structure
- Uniqueness threshold bypass implementation details

## Deferred Ideas

None -- discussion stayed within phase scope
