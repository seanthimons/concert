# Review: Radiological Detection Event Classification PRD

**Reviewer pass date:** 2026-06-22
**Subject:** PRD dated 2026-06-08, "Radiological Detection Event Classification for Mixed Lab Datasets"
**Companion artifacts:** `R/detection_classifier.R`, `tests/testthat/test-detection-classifier.R`

This is a strong PRD. The core conceptual move — separating *detection evidence* from
*reportability confidence*, and refusing to collapse either into a single boolean — is the
right call and is what makes the rad data tractable alongside chemical data. The notes below
are about correctness, edge cases, and a few scope decisions, not about the overall direction.

---

## 1. Blocking issue: Section 7.1 priority order contradicts Section 14 acceptance criteria

The stated priority order lists **rule 5 (`positive_below_reporting_limit`, condition
`result < RL AND lower_2sigma > 0`) before rule 6 (`threshold_ambiguous`, condition
`result < RL AND upper_2sigma >= RL`)**. With "first match wins," the acceptance case

```
result = 0.20, uncertainty = 0.15, RL = 0.30   (lower = 0.05, upper = 0.35)
```

satisfies rule 5 first (`lower 0.05 > 0`), so the prose order yields
`positive_below_reporting_limit`. But Section 14 says this case must be
`threshold_ambiguous`. The two sections disagree.

**Cause:** rules 5, 6, 7 are written as overlapping conditions rather than a partition.
For the `result < RL` band, any interval whose lower bound is positive *and* whose upper
bound crosses RL matches both 5 and 6.

**Fix (implemented in the prototype):** evaluate the `result < RL` band as a clean partition,
ambiguous-first:

1. `upper_2sigma >= RL` → `threshold_ambiguous` (interval reaches the limit)
2. else `lower_2sigma > 0` → `positive_below_reporting_limit` (interval positive, entirely below RL)
3. else → `non_reportable` (interval reaches or crosses zero)

This passes all nine Section 14 cases (verified independently in Python). Recommend rewriting
Section 7.1 to state the partition explicitly and dropping the overlapping prose conditions.

## 2. `non_reportable` is under-defined and overlaps `positive_below_reporting_limit`

Rule 7 as written (`result < RL AND upper_2sigma < RL`) overlaps rule 5 whenever
`0 < lower` and `upper < RL`. One of your own examples exposes this: `result=0.10, unc=0.05,
RL=0.30` gives `lower=0.05, upper=0.15` — both "below RL" *and* "positive interval." Under the
partition above, `non_reportable` effectively means **`upper < RL` AND `lower <= 0`** (the
interval includes or sits below zero). That matches your interpretation note ("not always the
same as proving no signal") and is the only non-overlapping definition. Worth making explicit
in the PRD so `non_reportable` vs `positive_below_reporting_limit` is unambiguous.

## 3. Missing-uncertainty rows above RL silently become `indeterminate`

A row with `result >= RL` but no uncertainty cannot be split into robust vs estimated, so the
prototype classifies it `indeterminate` (basis `missing_uncertainty`). That is defensible, but
note the consequence: **an obvious chemical detect with no uncertainty column reports as
indeterminate, not detected.** This is fine if the classifier is rad-only in v1 (see open Q7),
but if it runs on chemical rows you will flood the review queue. Recommend an explicit policy:
when uncertainty is absent, fall back to a point-estimate-only class
(`detected_point_estimate` / `non_detect_point_estimate`) rather than `indeterminate`. Flagged
rather than fixed, because it depends on the Q7 answer.

## 4. Equality / boundary semantics are unstated

The PRD uses `>=` in some places and `<` in others without saying so. Decisions baked into the
prototype, which the PRD should ratify:

- `above_reporting_limit` uses `result >= RL` (a result exactly at RL counts as at-limit).
- `robust` uses `lower_2sigma >= RL`; an interval whose lower bound is exactly RL is robust.
- `interval_above_zero` uses `lower > 0` (strict); a lower bound of exactly 0 is *not* positive,
  pushing the row to `non_reportable`. For background-subtracted rad data this is the safer default.

## 5. Explicit-censoring detection: scope of the `<` and `U` checks

The PRD lists trigger tokens but not matching rules. Prototype choices worth confirming:

- `U` / `ND` are matched as **exact, whole qualifier codes** (uppercased, trimmed) — not
  substrings — so "Uranium" in a name field never trips them. Good, but it means a qualifier
  like `"UJ"` would *not* match `U`. If combined qualifier codes occur (`UJ`, `U*`), the match
  needs to tokenize.
- `<` is matched **anywhere** in qualifier or raw text. This will catch `<=` too. Confirm there's
  no legitimate use of `<` in a raw result that isn't censoring (e.g. a free-text note).
- Narrative phrases use word-ish boundaries. "Below detection" matches; "below limit" alone does
  not (intentional — too ambiguous). Confirm the lab vocabulary.

## 6. `review_required` only fires on the explicit-ND-vs-above-RL conflict

Section 11.4 lists seven review-candidate conditions, but `detection_event_class` only has one
conflict value (`review_required`) tied to one of them. The prototype handles the rest via a
separate boolean `detection_review_flag` (true for `threshold_ambiguous`,
`positive_below_reporting_limit`, `indeterminate`, J-consistency mismatches, missing/unknown
coverage on rad rows). Recommend the PRD state clearly that **`detection_event_class` carries one
hard conflict state, while `detection_review_flag` is the general "a human should look" signal** —
otherwise reviewers will expect every 11.4 condition to have its own class.

## 7. Negative non-radiological values are unhandled (ties to open Q9)

Rule 2 only rescues negatives when `measurement_type` is radiological. A negative *chemical*
result currently falls through to the interval logic and will usually land in `non_reportable` or
`threshold_ambiguous` depending on the interval — it is never rejected, but it is also never
flagged as the anomaly it probably is. A negative chemical concentration is almost always a parse
or sign error, unlike a negative rad result. Recommend an explicit `review_required` /
`indeterminate` branch for `result < 0 AND not radiological`.

## 8. `signal_to_uncertainty_ratio` — confirm the divisor

Section 5.3 says divide by 2 only when computing a standard-uncertainty signal ratio. The
prototype computes `result / (uncertainty / 2)` (i.e. result over standard uncertainty, since the
column is 2-sigma). Verify that's the intended ratio and not `result / uncertainty`. They differ
by exactly 2x and someone will eventually threshold on this number.

## 9. Smaller notes

- **`relative_uncertainty`** uses `unc / abs(result)` and is `NA` when `result == 0`. The PRD
  doesn't define behavior at zero; division-by-zero needs a stated answer (NA is the prototype's).
- **Coverage handling.** The prototype rescales `one_sigma` to a 2-sigma half-width and treats
  unknown/blank coverage as 2-sigma *but raises the review flag* on rad rows. The PRD says assume
  2-sigma (Q4) but doesn't say to flag it; flagging is the auditable choice.
- **`aggregate_radiological_activity`** (Ra-226 + Ra-228) is treated identically to other rad
  types for negative handling. If aggregates have different uncertainty propagation, that's future
  work — fine for MVP, worth a non-goal note.
- **No `LC` / critical-level path** (open Q6). The PRD itself flags that RL is a reportability
  threshold, not a true detection threshold. Until an `LC` column exists, every "detection"
  statement here is really a *reportability* statement. Recommend saying so plainly in the review
  UI copy so users don't over-read `detected_binary`.

---

## What the prototype implements

`R/detection_classifier.R` — vectorized, Tidyverse/magrittr, no row loops, appends derived
fields and never mutates source columns (per 11.3). QA columns (RPD, %R, surrogate z) are not
parameters at all, so detection evidence *structurally cannot* depend on them (satisfies 14.2 by
construction, not just by test).

`tests/testthat/test-detection-classifier.R` — all nine Section 14 acceptance cases, plus
exclusion, mixed-dataset, append-not-overwrite, J-consistency, coverage scaling, and derived-field
tests.

All nine acceptance cases were verified independently in Python before the R tests were written;
the one discrepancy found was a bad fixture in the spec example for `non_reportable` (see §2).
