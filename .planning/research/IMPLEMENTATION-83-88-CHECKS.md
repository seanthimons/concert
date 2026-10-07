# Implementation verification

2026-10-07, branch fix/82-wqx-identifier-review. R 4.6.1 runs the R 4.5.1
lockfile dependency versions. `renv::restore()` attempted all 156 locked packages;
optional documentation/graphics packages failed for missing system headers
(fontconfig/freetype and libgit2 among them). A focused restore installed 141
runtime/development packages into the user library. pkgload, testthat, roxygen2,
ComptoxR and Shiny load successfully with `Rscript --vanilla`. Lockfile unchanged.
Use pkgload rather than devtools until optional dependencies are installed.

Focused baseline: consensus, curate-iterate, export-review, pubchem-fallback
passed (one expected pinned-row warning). Additive accepted policy: identity-review,
export-review, toxval-mapper, toxval-export-parity passed. No pilot identities
validated or assignments rewritten. No service requests or DSSTox download.

Compatibility decision: retain map_to_toxval_schema() lookup default; accepted
mode is explicit and preserves measurement rows with NA IDs when blocked.
Curated Data retains provisional consensus, adds derived policy fields; Accepted
Identities is an additive sheet/view. Queue completion is not identity acceptance.

The full package suite was attempted. Additive sheet-count fixtures were updated,
then export/import including the new safe sheet passed. Five unrelated failures
were reproduced on detached original research commit c689178: test-cas-pipeline
uses unavailable `expect_na()`, and media-artifacts/media-persistence reject the
pinned table-manifest.json hash. These are existing baseline limitations and are
not changed by this identity work. Several existing optional tests skip for
missing credentials, or known large-sheet memory limits. Full-suite green cannot
be claimed until those independent fixtures are repaired.

#88 focused package tests passed (154 assertions). #83 focused consensus,
iteration, export-review and review-resolution passed (351 expectations),
including actual generated replay and workbook reimport under deterministic
service/pipeline mocks. #83 and #88 made no Shiny changes.

## Integrated implementation

#84 and #85 share one immutable review_decision_evidence object, defined in
REVIEW-EVIDENCE-CONTRACT.md. The contract was committed before the separate
selected-identity and candidate-validation consumers. Decision revisions retain
actual automated/final evidence and normalized attributed candidates. Historical
flags report missing baselines. Acknowledgments bind revision, source/content
scope and evidence. Reconciliation does not select identities or clear flags.
Observed current source-validation results supersede supplied same-authority
history; audit timestamps are excluded and authority versions participate.

#87 adds recomputed acceptance blockers, the additive accepted view/sheet and
structured scoped decisions. Registered mixtures have positive mocked tests;
aggregate retention and component-CAS ambiguity stay provisional. Fingerprint v2
persists the reviewed source boundary and excludes enumerated harmonization
outputs; chemistry, source content and lineage changes remain material. Malformed
or stale decisions fail closed. Name/CAS flags can span rows; scoped acceptance
requires one uniquely identified source row. Existing clean-substance lookup
behavior and mapper defaults remain compatible. Explicit accepted-only ToxVal
mode retains measurements, gates identifiers, and survives replay, workbook
hydration and GUI refresh; unavailable/misaligned refresh blanks IDs.

#86 supplies explicit source-DTXSID evidence roles, separate membership and
correspondence outcomes, unused-column warnings and deliberate metadata ignores.
Raw identifier columns cannot vote via their names. Source-only manual selection
requires scoped correspondence; definitive invalidity and transport unavailability
are separate. Manual authoritative membership never chooses a ranked tie or a
mismatched returned identifier. No automatic DSSTox retrieval is introduced.

Headless stages, iteration, pending output and completion diagnostics now use the
shared reports. Replay reconstructs exact portable inputs. Typed workbook Session
State chunks preserve records and acknowledgments, while legacy imports remain
compatible. GUI flag decisions capture actual inspected evidence; source roles,
warnings, source validation and acceptance blockers are displayed. Structured
scope/correspondence acceptance was initially headless-only; the GUI follow-up
below closes that interface gap.

Deterministic focused tests cover all affected service boundaries, real generated
replay, actual XLSX export/read/hydration, candidate reassignment between source
rows, versioned validation caches, registered-mixture harmonization and safe
ToxVal refresh. The final mode/persistence integration suites passed; fingerprint
boundary regression has 53 passing expectations, including malformed record
versions. Full suite execution is documented below.

Fresh-session Shiny cold boot after the final UI/server changes:
Rscript --vanilla, pkgload::load_all(), concert::run_app(port=63318,
launch.browser=FALSE). HTTP 200, 63,316 bytes; reference caches loaded and no
startup errors. Process stopped after verification. Source UI regression tests
also use shiny::testServer. No pilot files or pre-existing untracked work changed.

The initial environment limitations included optional documentation/graphics
headers (resolved in the follow-up below) and an R version differing from the
lockfile. Fresh
chemical registry validation and pilot identity decisions remain outside these
mocked package checks. #82 WQX research boundaries are retained, including reviewed
name-only evidence without inventing accepted IDs. No PRs were created.


## Final full suite

Fresh vanilla-session `testthat::test_local(reporter = "summary",
stop_on_failure = FALSE)` ran all 1,281 test cases: 4,755 passing expectations,
13 skips, 16 existing test warnings, one failing expectation and four errors.
Those five failures are exactly the original c689178 baseline failures described
above: unavailable expect_na in test-cas-pipeline, two media-artifacts cases and
two media-persistence cases involving the pinned manifest hash. No new runtime
or regression failures remain. The twelve new evidence/acceptance test files
alone have 462 passing expectations, no failures/errors/warnings/skips. Existing
affected consensus, PubChem, replay, iteration, export/import, harmonization and
UI module tests also pass in this full ordered run.

An initial integrated run exposed test-only mock leakage: default on.exit file
cleanup overwrote deferred validator restoration. Replacing it with withr::defer
fixed both leaks; the ordered 364-expectation reproduction passed and the final
full suite confirmed isolation. Full-suite green remains blocked by the five
independent baseline failures; they were not hidden or rewritten. Runtime
implementation and tested integration increments are committed separately.


## Dependency follow-up

At the user's request, installed the missing Fedora development libraries and
Pandoc locally under /home/sxthi/.local/share/concert-r-sysdeps. System-wide
installation required a sudo password unavailable to this session; no system RPM
database changes were made. Downloaded from Fedora/updates, extracted 61 x86_64
and noarch RPM payloads, repaired local pkg-config paths and linked existing
runtime libraries. The local prefix includes packages.sha256 provenance,
Makevars with runtime library paths, and env.sh for future native builds:

    source /home/sxthi/.local/share/concert-r-sysdeps/env.sh

Pandoc is available through /home/sxthi/.local/bin/pandoc. Full renv restore into
the project library succeeded: all 156 locked package versions match. Previously
missing devtools, pkgdown, git2r, systemfonts, textshaping, ragg, quarto and
autonewsmd load successfully. The lockfile and repository configuration remain
unchanged. Ordinary Rscript startup now activates the restored project without
requiring --vanilla or bootstrap installation.

Verification in ordinary Rscript sessions: 910 fonts discovered, text shaping
succeeded, ragg rendered a 2,028-byte PNG, devtools::load_all() succeeded, and
164 focused identity-review/PubChem/workbook-persistence expectations passed.
Fresh Shiny cold boot on port 63319 served HTTP 200 (63,316 bytes), with no startup
errors, then was stopped. renv::status() reports only the preserved R version
difference (lockfile R 4.5.1; installed R 4.6.1). Fedora's site startup also loads
CoprManager before renv, causing an informational namespace warning. These notices
do not indicate missing locked packages; they were not silenced.


## Scoped acceptance GUI follow-up

Commit 65ae124 connects both Expert Override and Compare Candidates dialogs to
the existing acceptance backend. The form records one explicit source target,
scope, conflict, ID, correspondence, reason and evidence reference. Grouped rows
require an explicit target; stale/ambiguous context, invalid/unavailable registry
membership and unavailable source validation fail without modifying the store.
Keep unresolved retains candidate evidence. Existing flags/reasons, source
content and lineage remain intact. Successful decisions capture actual automated
and final evidence in immutable review-history revisions.

Scoped decisions own their ID changes rather than ordinary compound-wide
overrides. A bounded lookup projection reconstructs the inspected state for the
exact source row before fingerprint verification. Source/candidate/validation
columns cannot be projected. Repeated revisions, source reorder, standalone
generated replay and actual XLSX export/read/hydration are regression-tested.
The new GUI test file passes 46 expectations; the focused integration suites
passed without new warnings. The fresh ordinary-R full suite passes 4,826
expectations, with five skips and the same five original baseline failures
(one failing expectation, four errors), plus 16 existing warnings.

Fresh full-app cold boot on port 63321: HTTP 200, 63,316 bytes, no startup errors.
A lightweight development demo in inst/examples/identity-review-demo.R uses the
actual Review Results module, four synthetic rows, mocked membership and disabled
discovery. Collaborative-browser checks exercised native widget events and the
save button: registered mixture accepted for only one of two grouped source
rows; unavailable source promotion rejected with dialog still open; FOLLOW-UP
preserved after correspondence with identity remaining provisional. No Shiny
output errors occurred. Demo state is synthetic and session-local. The demo
can be launched from the package root with source() then run_identity_review_demo().
No user data, pilot assignments or pre-existing untracked files were changed.
