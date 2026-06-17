# PRD: Human-Navigable Replay Code for Large Review Edits

## Problem Statement

CONCERT generates replay code so a curator can reproduce a Review Results session after manual edits. The generated replay must be explicit enough for a human to inspect and modify, because replay scripts are both an audit artifact and a recovery path.

The current direction intentionally moved away from override tables because large sessions can produce a huge table of differences that is difficult to interpret. The generated `case_when()` replay is better because it expresses edits as executable R code grouped by the field being changed. However, when a real dataset has hundreds of chemicals and many measurement, unit, media, species, or review edits, even workflow-grouped `case_when()` blocks can become long and hard to navigate.

The user needs replay code that remains human-readable at large scale without regressing to an opaque override table or scattered row-by-row assignment script. The generated code should make it easy to answer questions like:

- Which `Result` values were manually corrected?
- Which `Unit` values changed?
- Which Review Results flags or WQX overrides were applied?
- What stable row context caused a branch to match?
- Can I safely edit one generated branch without understanding the entire replay engine?

At the same time, replay matching must remain durable and deterministic. Measurement values such as `Result` must not become generic row-matching evidence when those same fields may be replay targets. If a row cannot be identified using stable evidence, CONCERT should fail with an ambiguity error rather than generating fragile code.

## Solution

Keep the generated replay as explicit R code using workflow-grouped, per-column `case_when()` assignments, but improve the generated code layout so large edit sets are navigable.

The generated replay should:

1. Keep one replay function that is passed into headless curation.
2. Keep one `mutate()` block per replay workflow.
3. Keep one `case_when()` assignment per changed target column.
4. Add clear workflow section headers before each workflow block.
5. Add per-column subheaders or inline comments showing how many corrections are in that target column.
6. Add a concise branch comment before each generated branch when it improves human readability.
7. Keep branch predicates on stable row evidence only.
8. Prefer semantically readable stable predicates over shortest-possible predicates when both are deterministic.
9. Preserve deterministic ordering so regenerated replay code is stable across runs.
10. Continue failing on ambiguous rows instead of using row position or edited mutable fields.

For example, a large generated replay should be organized conceptually as:

- Review Results overrides
- Measurement tag overrides
  - Result corrections
  - Unit corrections
  - Qualifier corrections
- Study tag overrides
  - Media corrections
  - StudyDate corrections
- Metadata tag overrides
  - Species corrections
  - ExposureRoute corrections
- Chemical tag overrides
  - Name corrections
  - CASRN corrections
  - Other corrections

The result will still be long for 400 chemicals and many edited values. That length is unavoidable if the replay artifact is meant to explicitly encode hundreds of human decisions. The goal is for the script to be long in a structured, searchable, and locally editable way.

## User Stories

1. As a data curator, I want replay code grouped by workflow, so that I can quickly find Review Results edits separately from measurement, study, metadata, and chemical-tag edits.
2. As a data curator, I want all `Result` corrections grouped under the `Result` assignment, so that I can review numeric result changes without scanning unrelated fields.
3. As a data curator, I want all `Unit` corrections grouped under the `Unit` assignment, so that I can audit unit fixes separately from result-value fixes.
4. As a data curator, I want generated replay code to include readable section headers, so that a long replay script can be navigated with search and editor folding.
5. As a data curator, I want each changed target column to show a correction count, so that I can sanity-check whether the generated script reflects the scale of my edits.
6. As a data curator, I want each branch to include concise row context, so that I can tell which real-world row the predicate refers to before editing it.
7. As a data curator, I want branch comments to be clearly non-semantic, so that I understand comments are for review only and do not affect replay matching.
8. As a data curator, I want replay predicates to avoid edited measurement fields such as `Result`, so that changed values do not become brittle row-matching evidence.
9. As a data curator, I want replay predicates to prefer meaningful identity and context columns, so that generated conditions read like real row descriptions rather than arbitrary minimal keys.
10. As a data curator, I want replay generation to fail when rows cannot be uniquely identified, so that I am warned about ambiguous edits instead of receiving code that silently targets the wrong row.
11. As a data curator, I want generated replay code to remain valid R, so that I can run it without hand-cleaning formatting artifacts.
12. As a data curator, I want generated replay code to remain manually editable, so that I can adjust one branch or value without rebuilding the whole session.
13. As a data curator, I want generated replay code to be deterministic across repeated exports of the same state, so that diffs are meaningful during review.
14. As a reviewer, I want replay generation behavior to be covered by targeted tests, so that changes to formatting do not accidentally weaken replay matching semantics.
15. As a developer, I want the readability logic separated from matching logic, so that future formatting changes do not disturb ambiguity detection or replay application.
16. As a developer, I want legacy replay override inputs to keep working, so that existing replay scripts and tests are not broken by a formatting-focused change.
17. As a reviewer, I want large synthetic replay scenarios tested, so that the output shape is validated against realistic high-volume edit cases.
18. As a curator handling large datasets, I want the generated script to be searchable by workflow, column name, chemical name, and stable context, so that I can review hundreds of edits efficiently.

## Implementation Decisions

- Keep `case_when()` as the generated replay primitive. Do not return to an override table as the primary replay format.
- Keep replay grouped by workflow. Workflows are Review Results, measurement tags, study tags, metadata tags, and chemical tags.
- Keep replay grouped by changed target column inside each workflow. Each target column receives its own `case_when()` assignment.
- Add a rendering layer for replay comments and section labels. This should be separate from the matching layer that determines which rows are safe to replay.
- Add a stable display-context builder for branch comments. Display context may include useful row descriptors such as chemical identity and stable sample/site context, but comments must not affect replay semantics.
- Keep the replay predicate builder responsible for executable row matching. Comments and labels are review aids only.
- Prefer readable stable signatures over shortest-possible signatures when both uniquely identify the target row. Chemical identity and stable contextual identifiers should generally be preferred over arbitrary single-column keys.
- Never use row index, display index, Review Results override fields, the target column itself, or mutable peer columns from the same workflow as replay predicates.
- For Review Results edits, do not use measurement-tagged fields as predicates.
- For tagged-column edits, do not use mutable peer columns in the same workflow as predicates.
- If two rows can only be distinguished by excluded mutable fields, replay generation must error as ambiguous.
- Preserve replay compatibility with function-style overrides and legacy positional overrides.
- Preserve generated script validity. Formatting additions must not produce unparsable R.
- Keep generated code deterministic. Workflow order, target-column order, and branch order should be stable and covered by tests.
- Avoid introducing UI configuration for replay formatting in this PRD. The default generated code should become more navigable without adding new controls.
- Avoid inferring bulk transformation rules from repeated corrections. If 200 unit values were edited, replay should encode the explicit corrections rather than invent a generalized conversion rule.

## Testing Decisions

Good tests should verify external replay behavior and generated script properties, not internal implementation details. Tests should focus on whether generated code is deterministic, parseable, readable in the expected structure, and semantically safe.

Modules to test:

- The override builder that detects changed Review Results and tagged columns.
- The stable-signature selection logic that determines safe replay predicates.
- The replay formatting layer that renders workflow sections, target-column groups, branch comments, and `case_when()` assignments.
- The replay application path that applies generated or spec-style overrides to a replayed resolution state.
- The Review Results replay-code path that threads the combined tag map into replay generation.

Test cases:

1. Review-only edit: generated replay includes a Review Results section and no tagged workflow sections.
2. Measurement-only edit: generated replay includes a Measurement tags section and a target-column group for `Result`.
3. Mixed edit: generated replay includes Review Results, Measurement tags, Study tags, and Metadata tags in deterministic order.
4. Large edit: a synthetic dataset with hundreds of chemical rows and many `Result` and `Unit` edits produces parseable generated R with grouped sections and stable branch order.
5. Branch comments: generated replay includes concise row-context comments, and the script still parses.
6. Comment semantics: changing or removing comments does not affect replay behavior.
7. Predicate safety: review flag edits do not use tagged `Result` values as predicates.
8. Predicate safety: measurement edits do not use `Result`, `Unit`, `Qualifier`, `Duration`, or `DurationUnit` peer columns as predicates.
9. Ambiguous duplicate: if two rows can only be distinguished by edited or excluded measurement fields, replay generation errors.
10. Stable duplicate: if duplicate chemicals can be distinguished by stable sample or site context, replay generation succeeds and uses that stable context.
11. Readable signature preference: when multiple stable signatures are valid, generated predicates prefer meaningful chemical/context fields over arbitrary shortest keys.
12. Legacy compatibility: existing legacy positional override tests continue to pass.
13. Function override compatibility: existing function override tests continue to pass.
14. Determinism: regenerating replay code from the same baseline and final state produces identical text.
15. No-change session: replay code omits the override function when no edits exist.

Prior art:

- Existing code-generation tests already cover replay settings, content-matched overrides, row reordering, duplicate ambiguity, typed `NA` values, legacy overrides, and targeted replay through headless curation.
- Existing tests for workflow-tagged replay provide a base for adding formatting and large-output assertions.

## Out of Scope

- Replacing `case_when()` with override tables.
- Replacing `case_when()` with hundreds of named row selectors and direct assignments.
- Adding replay-code UI preferences or formatting toggles.
- Adding a visual diff viewer.
- Adding a custom replay DSL.
- Inferring generalized transformation rules from repeated edits.
- Supporting ambiguous replay by falling back to row position.
- Changing the semantics of headless curation.
- Changing the export format.
- Reworking Review Results editing controls.
- Solving old replay scripts generated before this change.

## Further Notes

This PRD assumes the current replay direction is correct: explicit generated R is preferable to an opaque override table because it can be inspected and modified by a curator or reviewer.

The main risk is over-optimizing for formatting and accidentally weakening replay correctness. The matching layer should stay strict. Readability improvements should be layered on top of existing deterministic matching and ambiguity checks.

The second risk is making predicates too minimal to be human-readable. A predicate such as a single `sample_id` may be technically unique, but a curator reviewing hundreds of edits will usually benefit from seeing chemical identity and stable sample context together. This PRD favors a "minimum readable signature" over a purely shortest signature, as long as excluded mutable fields are still avoided.

Questions for Claude review:

- Does this preserve the right balance between explicit generated code and large-output readability?
- Should branch comments include old-to-new values, or should old-to-new information appear only in the `case_when()` target value?
- Should readable signature preference replace shortest-signature minimization, or should it only affect branch comments?
- Are workflow section headers and target-column counts enough, or should the generator also include per-workflow summaries at the top of the function?
- Is there any situation where chemical-tag edits should run before other workflows despite the risk of changing identity predicates used later?
