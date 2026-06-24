# Qualifier & chemical-path policy (decided 2026-06-22)

Decisions from the design conversation, as implemented in `R/detection_classifier.R`
and covered by `tests/testthat/test-detection-classifier.R`.

## Two paths, selected per row

The classifier picks a path by whether an **uncertainty value is present**, not by
measurement type — so it handles mixed files row-by-row:

- **Interval path** (uncertainty present, typically radiological): two-sigma interval vs RL.
- **Point path** (no uncertainty, typically chemical): result vs RL via a configurable operator.

The "missing uncertainty -> indeterminate" gate from the v1 prototype is removed: a
chemical row with a result and a reporting limit now classifies as detect/non-detect
instead of indeterminate. (Review §3 / open Q7 resolved in favor of running on chemicals.)

## Detection rule for chemicals

- Default operator is **`>`** (strict), per Sean's preference. `>=` is available via
  `detect_operator = ">="`. The two differ only at `result == RL` with no qualifier;
  that boundary is rare for real measurements and usually indicates a non-detect
  substituted at the limit, which is why strict `>` is the default. The pushback for
  `>=` (don't drop a genuine on-limit detect) is preserved by making it a one-arg switch.
- A **positive result below RL is a non-detect** (`result_flag = FALSE`). Chemicals carry
  no uncertainty interval to justify "positive signal," so below-RL is treated as
  not-reportable. (Open Q from the chem discussion.)

## Qualifier semantics

| Qualifier | Meaning | Effect on class | Effect on flags |
|---|---|---|---|
| U / ND / < / BDL / narrative | explicit non-detect | `explicit_non_detect` (or `review_required` if numeric result is at/above RL) | not reportable, not detected |
| **J** | identified, value is an estimate | downgrades a detect to `estimated_reportable_detect`; if below RL -> `review_required` (conflict) | reportable if at/above RL; consistency tracked |
| **RL** | reporting limit raised, presence/absence unverifiable | none (numeric decides) | `qualifier_reduced_sensitivity = TRUE`, review flag raised |
| **B** | <10x blank, presence suspect | none (kept as the numeric detect) | `qualifier_blank_suspect = TRUE`, `reportable_detect_binary = FALSE`, `result_flag = FALSE`, review flag raised |

Notes:
- `J` is the chemical analog of the radiological uncertainty interval: it supplies the
  "estimated" signal, so both paths converge on `estimated_reportable_detect`. `J` never
  censors.
- `B` keeps the detection visible (`detected_binary = TRUE`) but marks it suspect and not
  clean-reportable — "suspect, flag for follow-up," per the five B rows observed (one also J).
- The bare **`RL` qualifier token** is parsed distinctly from the reporting-limit *column*
  and from the "below RL" narrative phrase; it never registers as a non-detect or as a `B`.
- Combined codes (`UJ`, `BJ`, `B J`) are tokenized; multi-letter tokens (ND, RL, BDL) are
  matched before single letters so `RL` is not split into `R`+`L`.

## Output: result_flag

`result_flag` is an alias of `reportable_detect_binary` — the conservative "lab-standable
detection" boolean intended to replace the hand-coded column. The richer
`detection_event_class` and the broader `detected_binary` remain available underneath, so
estimated and suspect detections are never lost.

## Still open / not yet wired

- Not yet returning the pipeline's `list(cleaned_data, audit_trail)` shape, and does not
  append to the shared `flag` column. Needs deciding before it drops into the Section 11
  curation step.
- MDL column: if chemical files carry an MDL distinct from RL, the textbook three-tier
  (`>= RL` reportable / `MDL<=result<RL` estimated-J / `<MDL` non-detect) removes the
  below-RL ambiguity entirely. Not implemented (no confirmed MDL column yet).
- `detect_operator` is currently a function argument; if it should vary by lab/source it
  needs to move into config.
