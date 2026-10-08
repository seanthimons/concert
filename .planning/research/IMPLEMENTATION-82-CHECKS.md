# Issue #82 implementation and checks

Implementation follows ISSUE-82-WQX-IDENTIFIER-REVIEW.md and the shared review
evidence contract. Work is isolated in the delivery worktree; the original
fix/82-wqx-identifier-review branch and its existing files remain unchanged.

## Behavior

- Canonical WQX entries provide CAS evidence; aliases inherit their canonical
  entry's CAS. Missing, invalid and ambiguous values remain explicit. Equal best
  fuzzy matches across distinct canonical identities are never selected.
- Deduplicated canonical-CAS lookup retains all candidates and distinguishes
  no hits from unavailable/malformed responses. Candidate continuation retains
  both original and canonical name queries and their separate outcomes.
- WQX CAS/name candidates cannot vote in lookup consensus or establish source
  correspondence. Generic manual selection alone cannot accept a vocabulary
  candidate. Current, explicit source-scoped correspondence plus registry
  validation uses the existing acceptance contract.
- Unreviewed WQX rows remain pending, including no-CAS/no-hit rows. VERIFIED and
  explicitly reviewed name-only evidence may remain identifier-free. FOLLOW-UP
  and BAD preserve their flags, reasons and dispositions. Queue completion,
  evidence reconciliation and accepted identity remain separate.
- Pipeline-owned evidence is distinguished from raw similarly named input
  columns. Original source names, metadata, row lineage and decisions survive
  mapping, rerun, workbook export/import and generated replay.
- Candidate order/duplicates do not manufacture an evidence change. Chemical
  evidence changes reopen reconciliation; old acknowledgments do not cover them.
  Immutable captured records use lossless numeric serialization for replay and
  workbook session transport. New WQX distance evidence is stored as precise
  decimal text so XLSX rounding cannot invalidate a current decision.
- Shiny displays canonical CAS, provenance and candidate outcomes in both WQX
  Review and Override. Closing WQX Review is labelled Close. Long query records
  remain selectable rather than expanding every default table row. The human
  guide includes overlapping screenshots covering the full WQX dialog.

## Checks

- Full suite: 5,210 assertions passed (no failures/errors; five existing skips and
  sixteen existing fixture warnings).
- Expanded locked regression selection: 1,017 assertions passed with no
  failures, errors, warnings or skips before the final table-display adjustment.
- Final UI/helper selection after that adjustment: 244 assertions passed with
  no failures, errors, warnings or skips, including the real app's upload/tag/
  curate/scoped-decision/name-only-review/rerun workflow.
- Real XLSX hydration and executed generated replay: 70 assertions passed.
- R CMD check --no-manual: zero errors, zero warnings, two pre-existing notes
  (unused V8 import and visible-binding/global-function checks).
- Fresh-session actual-app cold boot: HTTP 200, connected Shiny browser session,
  no output errors. Browser upload/tag/curation, WQX evidence review and scoped
  source-decision save exercised with synthetic services.
- Complete pkgdown build passed, including reference pages, articles and NEWS.
  The illustrated source guide was rebuilt after adding WQX screenshots.
- Workflow YAML parsed. Locked CI now includes WQX and PubChem boundary suites;
  the manually dispatched OS matrix remains optional. NEWS headings now render
  in pkgdown; GitHub-only releases do not query CRAN release dates. The release
  workflow preserves that heading format when regenerating NEWS.

## Release and validation boundaries

Release run 37699744308 is cancelled. No v0.6.0 tag or release was created; release
publishing stays paused. PR #91 contains this follow-up to the already merged
#83–88 work. Synthetic deterministic services validate package behavior only;
no live pilot identifier validation, pilot rerun or assignment rewrite occurred.
No DSSTox download is performed. Local R is 4.6.1; locked CI uses R 4.5.1 and the
committed renv.lock. Existing exports keep their lookup-default compatibility;
accepted identity remains an explicit view/policy.
