# Shared review evidence contract (schema 1)

`review_decision_evidence` is the single authoritative portable object. It is an
R list with `schema_version = 1L`, append-only `decisions`, and append-only
`acknowledgments`. No sidecar or free-text reason supplies an alternate baseline.
Existing flags without a captured record produce `baseline_missing`.

`capture_review_decision()` is an explicit reviewer operation. Each record stores
stable decision ID, monotonically increasing revision, source/content scope,
automated evidence, final reviewed evidence, normalized attributed candidates,
validation outcomes, structured disposition, flag, reason, audit time and
fingerprints. Revisions preserve older records. Fingerprint integrity detects
modification; this is an application integrity check, not a cryptographic signature.
Never invoke capture merely because a flag is reapplied on a rerun.

`review_evidence_scope(df, row_indices, columns)` requires explicit immutable
source/content columns: source names, CAS, input source IDs, source file/lineage,
and split-part identity when present. Consumers must exclude transient positions
and output-derived state. Scope sorts rows and columns for reorder stability,
retains duplicate multiplicity and rejects indistinguishable duplicates at
explicit capture/acknowledgment. An explicit multirecord scope may represent a
group review, but **identity acceptance must separately reject materially
different source scopes**. A changed source/CAS/name/part invalidates the scope.
Original row numbers may be reported separately; they are not default identity keys.

`review_evidence_snapshot(automated, final, row_indices, validation)` separates
pre-override lookup evidence from final manual decisions. Candidate normalization
retains resolver/PubChem/source/parent/tie attribution, query, and complete PubChem
CID:DTXSID pairs. Malformed/empty pairs never become candidates. Parent candidates
remain suggestions; source IDs remain metadata. Candidate order and duplicates
normalize. Audit timestamps are excluded from comparison.

Validation outcomes are `valid`, `rejected`, `unavailable`, `unknown`, `invalid`,
`ambiguous`, `conflicting`, or `stale`, with authority/version/reason. Definitive
rejection differs from unavailable validation; neither membership nor source
agreement proves source-identity correspondence. Helpers do not contact services
or download DSSTox. Consumers may treat repeated unavailable checks as an
informational limitation; never convert an outage to rejection or new usable
identity evidence.

`compare_review_decision()` returns `baseline_missing`, `scope_changed`,
`unchanged`, `changed`, or `acknowledged`, plus the latest immutable decision.
`acknowledge_review_evidence()` binds an acknowledgment to the exact decision
revision, source/content fingerprint and current evidence fingerprint. A later
revision, source change, or evidence change cannot inherit the acknowledgment.
Acknowledgment does not clear FOLLOW-UP, validate chemistry, or accept an ID.

Completion consumers must distinguish queue disposition (`queue_complete`, legacy
`done`), reconciliation completion, and accepted identity/review completion. A
retained FOLLOW-UP can be queue-dispositioned or acknowledged while its identity
remains unaccepted. Historical missing baselines remain visible; never infer a
prior no-hit/rejection from prose.

Persistence consumers must embed this exact object in replay and supported
workbook session state, retain schema/revision/time, and validate integrity on
import. `dput`/`dget` and RDS are deterministic tested round trips. This foundational
increment does not yet wire stage, iteration, workbook or UI consumers.

## Selected-identity consumer (#84)

`build_review_reconciliation()` is a read-only consumer. It expands each applied
flag selector to its matched source rows and compares one explicit scoped decision
against current automated/final evidence. `row_flags$decision_id` can supply a
stable explicit ID; otherwise `review_decision_key(name, casrn)` provides a stable
selector ID suitable for explicit capture. A supplied CAS without a CAS-tagged
column is a scope diagnostic, never a name-only acknowledgment fallback.

The flat report preserves flags/reasons and exposes baseline_missing,
legacy_flag_with_selected_identity, no_identity_to_selected,
selected_identity_changed, candidate_evidence_changed,
validation_or_lookup_changed, scope_changed and target_missing. Unchanged or
exactly acknowledged evidence is nonactionable. Legacy baselines remain actionable
reconciliation work without claiming a historical no-hit transition. The consumer
does not alter ordinary pending rows or identity fields.

Snapshot `scope_cols` binds source content to each evidence row. Callers must
supply the same source/content columns used by scope construction. Reordering rows
then leaves the fingerprint stable, while swapping IDs between distinct source
rows changes it. Stage/iteration/persistence integration remains owned by the
orchestrator; this consumer alone does not deliver those entry points.
