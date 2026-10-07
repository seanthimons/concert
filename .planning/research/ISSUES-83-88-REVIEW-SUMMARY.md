# Issues 83 through 88 findings and implementation order

Six sub-agents reviewed one issue each in isolation against the v0.5.3 runtime
on branch `fix/82-wqx-identifier-review`. Each plan identifies implementation
boundaries, identity safeguards, regression cases and verification limits.
These findings support package changes; they do not validate or authorize new
chemical assignments in the pilot.

## Findings and plans

| Issue | Finding | Proposed fix |
| --- | --- | --- |
| [83](https://github.com/seanthimons/concert/issues/83) | VERIFIED plus unresolved/blank identity is excluded from pending despite export review requirements. | Add a contradiction predicate and dedicated pending/status diagnostics; preserve flags, tie evidence, intentional dispositions and valid reviewed WQX name-only evidence. [Plan](ISSUE-83-REVIEW-PLAN.md) |
| [84](https://github.com/seanthimons/concert/issues/84) | FOLLOW-UP remains after selected identity changes; no decision-time evidence exists to identify stale decisions reliably. | Persist reviewed evidence and scoped acknowledgments; report changed evidence and legacy missing baselines without clearing flags. [Plan](ISSUE-84-REVIEW-PLAN.md) |
| [85](https://github.com/seanthimons/concert/issues/85) | Candidate discovery works on flagged unresolved rows, but candidates do not reopen review; unavailable validation is distinct from rejection. | Compare reviewed candidate evidence, expose actionable validation work, retain unchanged rejection/defer decisions and support explicit revalidation. [Plan](ISSUE-85-REVIEW-PLAN.md) |
| [86](https://github.com/seanthimons/concert/issues/86) | Untagged source IDs remain unused metadata; no dedicated DTXSID evidence role exists. Raw input with a `dtxsid_*` prefix can enter generic consensus without validation. | Add explicit source-ID evidence and unused-column diagnostics, authoritative validation and scope gates, explicit metadata ignore, and generated-evidence ownership. [Plan](ISSUE-86-REVIEW-PLAN.md) |
| [87](https://github.com/seanthimons/concert/issues/87) | One CAS lookup can produce `single` despite unresolved scope; FOLLOW-UP does not remove its consensus ID. Unspaced slash lists evade the current separator heuristic. | Add an accepted-identity policy/view distinct from lookup consensus, structured scope decisions, safe component CAS handling and guarded exports. [Plan](ISSUE-87-REVIEW-PLAN.md) |
| [88](https://github.com/seanthimons/concert/issues/88) | Zero matching synonyms emit `":"`; missing or malformed CID components can also emit invalid pairs. | Validate complete CID/DTXSID pairs before formatting; preserve successful CID lookup and NA when no valid pair exists. [Plan](ISSUE-88-REVIEW-PLAN.md) |

The agents independently reproduced the source mechanisms with offline R
fixtures. Some checks substituted only tibble output constructors in memory
because dependencies are absent; those are isolated logic checks, not package
tests. The #88 agent executed the actual sourced candidate function with
injected services. Agents for #83–87 also independently checked the pinned
saved CSV groups. Saved counts overlap and must not be summed. No live registry
validation or full pilot replay was performed.

## Recommended order

1. Restore the declared R development/test environment. Full testthat, replay,
   export/import and Shiny checks cannot run with the current missing packages.
2. Implement #88 as a small independent fix, with complete-pair and empty-result
   regressions. Candidate comparison for #85 must also defensively ignore legacy
   malformed strings; a producer fix does not repair previously saved evidence.
3. Implement #83 as a bounded guard. It requires no historical snapshot to
   detect a current VERIFIED/unresolved contradiction. Coordinate its WQX
   exception with #82; never pick the first exact tie automatically.
4. Define one shared reviewed-evidence schema and comparator for #84/#85, then
   deliver selected-identity reconciliation and candidate validation as distinct
   consumers. Use one persistence/acknowledgment mechanism rather than adopting
   both independently proposed schemas or duplicating reports with divergent
   semantics. Keep original dispositions immutable until an explicit revision.
5. Introduce the additive accepted-identity helper/view in #87 before promoting
   source IDs in #86. Complete #87 scope decisions and component-CAS safeguards
   in increments. Source-ID warnings and review evidence in #86 can proceed
   independently; assignment must obey the shared acceptance policy.
6. Run deterministic targeted suites for each increment, then relevant package
   and replay checks. Any UI/server/reactive implementation requires the
   repository's fresh-session Shiny cold boot. Review pilot chemistry separately
   against authoritative identity and source-scope evidence.

## Shared design decisions to resolve before implementation

- **Historical evidence:** capture what was actually reviewed, not the latest
  rerun or same-run pre-review baseline. Legacy flags lack that history; report
  `baseline_missing`/unknown rather than parsing free-text reasons or asserting
  a proven transition. Adoption of a present-time baseline must be explicit.
- **Decision scope:** name/CAS selectors can affect multiple source rows.
  Acknowledgments and scope-sensitive acceptance need content/source lineage and
  ambiguity checks; transient row position alone is insufficient.
- **Validation outcomes:** distinguish no hit, candidate discovered, membership
  unavailable, definitive rejection, and accepted source identity. Membership
  and agreement among sources do not prove chemical equivalence. Never auto
  download DSSTox or persist an outage as a rejection.
- **Completion:** preserve the existing meaning of `done` as queue disposition
  where compatible, while new actionable contradiction/validation items block
  that queue. Add explicit reconciliation and identity-review completion
  diagnostics. An intentionally dispositioned FOLLOW-UP may remain unaccepted
  and exported as needing review; acknowledgment does not clear its flag.
- **Cache and replay:** candidate/public-membership results are cached. Provide
  explicit evidence refresh/revalidation and include relevant policy/authority
  versions in new cache contracts. Persist review evidence and acknowledgments
  through supported replay/resume paths without silently rebasing history.
- **Compatibility:** preserve audit consensus fields and add an explicit safe
  accepted-identity view. Review any ToxVal default change as a migration rather
  than silently dropping measurements or allowing fallback IDs to bypass gates.

This commit contains research and plans only. Runtime implementation remains
the next phase; none of the six issues is claimed fixed.
