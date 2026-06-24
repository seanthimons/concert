# Answers / recommendations: Section 15 open questions

These are recommendations, not decisions — each notes the trade-off so you can overrule.
Where the prototype already encodes a choice, that's marked **[prototype]**.

**Q1 — Should `positive_below_reporting_limit` count as `detected_binary = TRUE` by default?**
Yes, count it as detected **[prototype: detected_binary = TRUE]**, but keep
`reportable_detect_binary = FALSE`. The interval says there is a positive signal; calling it a
non-detect throws away real information and is the exact "false censoring" failure mode the PRD
warns about. The two-boolean split lets downstream users who only trust reportable values filter
on `reportable_detect_binary` instead. This is the cleanest reason to keep both booleans.

**Q2 — How should `threshold_ambiguous` count in simplified exports?**
Review-only, and in a forced binary, **non-detect** (conservative) — never silently a detect. It
is below RL on the point estimate with an interval that merely touches the limit; promoting it to
detect would overstate confidence. **[prototype: detected_binary = FALSE, detection_review_flag =
TRUE]**. Don't ship a simplified export that hides these without the review flag.

**Q3 — Should explicit `J` alter the detection class, or only add context flags?**
Only add context. `J` stays a source field; the classifier derives `qualifier_consistency_flag`
and never overwrites the lab class. Agreement is informative, disagreement is a review signal —
exactly as Section 8 argues. `J` has many non-uncertainty causes (matrix, blank, holding time),
so letting it move the detection class would conflate distinct meanings. **[prototype]**

**Q4 — Uncertainty present but coverage not stated as two-sigma?**
Assume two-sigma (your stated default) **and raise the review flag** on radiological rows so the
assumption is visible and auditable, rather than silently baked in. Capture coverage as a real
field (`two_sigma` / `one_sigma` / `unknown`) so a later per-lab default can override the
assumption without reprocessing. **[prototype: unknown coverage on rad rows → review flag]**

**Q5 — Are MDA, MDC, RL equivalent enough for a first pass?**
For first-pass classification, yes — treat them as one `reporting_limit_value` with the source
distinction preserved in `reporting_limit_type`. They are all reportability thresholds. Keep the
type column so you can diverge later (e.g. if MDA needs different review thresholds than a
contractual RL) without a schema change. Do **not** average or coalesce multiple limit columns
on one row silently — if a row carries both MDA and RL, that's a `review_required` candidate.

**Q6 — Do sources include a critical level (`LC`) distinct from MDA/RL?**
This needs a data answer from your real files, not a recommendation. If `LC` exists, it should
drive *detection* evidence (signal vs zero/critical level) while RL/MDA drive *reportability* —
which is the cleaner version of the whole detection-vs-reportability split. Until then, be explicit
in UI copy that `detected_binary` is reportability-derived, not a true critical-level test.
**Action: grep your real rad reports for an LC / decision-level column before v1 ships.**

**Q7 — Run the classifier for chemical rows with uncertainty, or rad-only in v1?**
Rad-only in v1 (smallest defensible slice, matches Section 16 MVP). The classifier accepts any
row, but gate invocation on `measurement_type %in% radiological*`. The reason is §3 of the review:
chemical rows rarely carry uncertainty, so running it broadly turns most chemical detects into
`indeterminate`. Open it to chemical rows in v2 once the missing-uncertainty fallback policy (Q
in review §3) is decided.

**Q8 — Should `relative_uncertainty` drive review thresholds?**
Yes, but as a v2 enhancement, not MVP. A high relative uncertainty (say > 0.5) on an
otherwise-robust detect is a real "estimated/unstable" signal and a good review trigger. Compute
and export it now **[prototype computes it]**, but don't wire it into a hard threshold until you've
looked at the distribution on real data — the cutoff should be empirical, not guessed.

**Q9 — Negative chemical vs negative radiological values?**
Treat them differently. Negative radiological results are physically meaningful
(background subtraction) → `negative_reported_non_detect` **[prototype]**. Negative chemical
results are almost always sign/parse errors → route to `review_required` / `indeterminate` rather
than silently classifying. The prototype does *not* yet special-case negative chemical values
(review §7); add a branch once you confirm the desired class.

**Q10 — Preserve multiple competing classifications (detection vs reportability vs export)?**
Yes — this is the most important "yes" in the set, and it's the architecture the rest depends on.
Keep three layers and never collapse them early:
1. `detection_event_class` — the rich derived class (primary internal representation).
2. `detected_binary` / `reportable_detect_binary` — secondary export conveniences.
3. `final_detection_event_class` — user override if present, else derived (per 11.4).
The PRD already leans this way; making it an explicit, named contract prevents a future "just give
me one boolean" request from quietly destroying the nuance.
