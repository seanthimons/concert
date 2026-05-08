# Phase 49: Conflict Scoring Engine - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-08
**Phase:** 49-conflict-scoring-engine
**Areas discussed:** Synonym data sourcing, Score formula design, Score column display, Scoring targets

---

## Synonym Data Sourcing

| Option | Description | Selected |
|--------|-------------|----------|
| Expand enrichment call | Add ct_chemical_synonym_search_bulk() inside enrich_candidates(). Same enrichment step, broader cache. Score reads cache only. | ✓ |
| preferredName + rank only | Score using only data already fetched. No synonym matching. Simpler but may miss synonym matches. | |
| Separate synonym fetch at enrichment time | Second API call during enrichment. Satisfies "no API at score time" but adds enrichment latency. | |

**User's choice:** Expand enrichment call. User noted ComptoxR has DSSTOX db access with synonyms built in. Investigation found `ct_chemical_synonym_search_bulk()` returns categorized synonyms (valid, good, other, beilstein, alternate). `dss_synonyms()` local function returned empty — API endpoint is the working path.

**Notes:** Coverage varies by DTXSID — Acetone returned 0 rows, Ethylbenzene returned full synonym set. Score function must handle missing synonyms gracefully.

---

## Score Formula Design

### Question 1: Score computation method

| Option | Description | Selected |
|--------|-------------|----------|
| Best synonym JW + rank bonus | Max JW across preferredName + all synonyms. +0.05 for rank ≤ 3. Clamped [0,1]. | ✓ |
| Weighted blend | 0.7 * best_jw + 0.3 * rank_score. More complex, harder to audit. | |
| Pure JW only | Just JW, ignore rank. Simplest but discards available rank signal. | |

**User's choice:** Best synonym JW + rank bonus.

### Question 2: Synonym tier weighting

| Option | Description | Selected |
|--------|-------------|----------|
| All synonyms equal | Max JW across all synonyms regardless of tier. Simple. | ✓ |
| Tier-weighted bonus | Bonus when best match comes from higher-quality tier. More nuanced. | |
| You decide | Claude picks. | |

**User's choice:** All synonyms equal.

---

## Score Column Display

### Question 1: Display format

| Option | Description | Selected |
|--------|-------------|----------|
| Decimal column, same as WQX Conf | "Sim. Score" column, 2-decimal, right-aligned, blank for non-disagree. Matches existing pattern. | ✓ |
| Color-coded decimal | Same decimal but with green/yellow/red background gradient. New pattern. | |
| Percentage format | "87%" instead of 0.87. More readable but inconsistent with WQX Conf. | |

**User's choice:** Decimal column matching WQX Conf pattern.

### Question 2: Which candidate's score in table

| Option | Description | Selected |
|--------|-------------|----------|
| Best candidate score | Show highest score among all candidates. Individual scores in modal. | ✓ |
| Per-candidate in modal only | No table column, scores only in comparison modal. | |
| Winning candidate score | Show consensus/selected candidate's score. Changes after resolution. | |

**User's choice:** Best candidate score in table column.

---

## Scoring Targets

### Question 1: What gets compared

| Option | Description | Selected |
|--------|-------------|----------|
| Input vs candidate synonyms | JW(user's raw name input, candidate's preferredName + synonyms). Answers "how likely does input refer to this chemical?" | ✓ |
| Cross-column comparison | Compare every tagged column's value against each candidate. More thorough but muddies signal. | |
| You decide | Claude picks. | |

**User's choice:** Input vs candidate synonyms.

### Question 2: CAS-sourced candidate scoring

**User clarification:** CAS-sourced candidates are scored the same as name-sourced — the CAS resolves to a preferredName, and the user's original chemical name is compared against that preferredName + synonyms. JW is never run on CAS number strings directly.

---

## Claude's Discretion

- Prototype script structure and test case selection
- Enrichment cache schema extension details
- Synonym fetch batching strategy
- Score function naming and file placement

## Deferred Ideas

None — discussion stayed within phase scope.
