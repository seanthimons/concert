# Published media curation acceptance

Use `tests/testthat/data/media-curation-acceptance.csv` in a fresh app.
The implementation session started the app at http://127.0.0.1:3876.

1. Upload the CSV, use its first row as headers, and tag `chemical_name` as Name,
   `casrn` as CASRN, `result` as Result, `unit` as Unit, and `media` as Media.
2. Before harmonization, open Media Classification. Published mappings should
   already be present, with amosharmonizer provenance. Inspect acetone: it has
   an ontology ID, definition and liquid phase, with routing unavailable.
3. Run harmonization. Expect canonical drinking water, soil, air, acetone,
   lake water, runoff, and an unresolved unknown. Drinking water must retain
   `Drinking WATER` as its original. There must still be seven measurement rows.
4. Edit the unknown mapping to canonical `soil`, save, and rerun. Its route is
   solid. Drinking water, lake and runoff use aqueous; acetone has no route.
   Air retains the existing molecular-weight safeguards (no guessed conversion).
5. Export the workbook and replay script. Reopen the workbook and resume its
   session. Inspect Media Classification and rerun. All originals and overrides
   must survive. Run the generated replay against the original CSV and compare
   media fields and routes in the resulting workbook.

## Evidence

- 2026-09-10, R 4.5.1 on Windows: the media, Shiny, code generation, workbook,
  ToxVal, unit and WQX regression group passed **1,400 assertions**, with no
  failures or test warnings and two pre-existing memory-limit skips.
- Additional consensus, Shiny, headless and generated replay checks passed
  **427 assertions**. One existing consensus test emits a pinned-row warning.
  These groups overlap; their counts are not additive.
- Coverage includes the seven media, editor rendering/inspection/save/rerun,
  shared-runtime parity, unit edits, typed workbook round trips, exact empty/NA/
  whitespace originals, execution of a generated replay script, and rejected
  schema/artifact/hash mismatches. The replay integration mocks chemical lookup;
  it exercises the actual media pipeline without an external service.
- Offline artifact import/rebuild: archive and table SHA-256 validation passed;
  267 terms and all 33 original keys are present. Repeated builds have identical
  bytes; baseline hashes also match across C and Windows English locales.
- `R CMD check --no-manual` on a clean tracked-file archive: **0 errors,
  0 warnings, 1 note**. The note lists existing global-variable bindings in
  isotope helpers, baseline-cell export and WQX alias extraction. Package
  installation, namespace, exported documentation/contracts and examples pass.
  The repo intentionally excludes tests from its source package; the targeted
  tests above were run separately. Local installed ComptoxR is 1.6.0.9000;
  the branch retains main's v1.7.1 remote pin.
- The first package check was interrupted by an inherited unsupported C.UTF-8
  locale. Setting the check subprocess locale to Windows UTF-8 resolved it.
  The devtools wrapper also emits an unrelated Quarto version-probe warning
  after check completion; the package's own `00check.log` reports only the note.
- Fresh Shiny startup: HTTP 200 at port 3876, 2026-09-10.
- User acceptance, 2026-09-11: the user confirmed that the app runs and
  harmonizes and that the new media types are available, then authorized pushing
  the work. The user also exercised the unknown-to-soil override and inspected
  acetone phase/routing and published ontology entries. This acceptance clears
  the draft gate. A complete manual export/reopen/replay walkthrough was not
  explicitly confirmed; those paths have automated coverage recorded above.
- The acceptance-only unknown-to-soil mapping remains local and is not committed.

To rerun the regressions interactively:

```r
source("scripts/validate_published_media.R")
validate_published_media()
```
