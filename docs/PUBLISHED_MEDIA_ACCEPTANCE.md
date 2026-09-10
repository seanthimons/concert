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

- Automated shared-runtime and Shiny module parity checks cover the seven media,
  editor rendering, save, override, rerun, original preservation and routing.
- Workbook tests cover typed row records, empty versus missing originals,
  canonical identities, compact overrides, replay, and rejected version/hash
  mismatches.
- Fresh Shiny startup: HTTP 200 at port 3876, 2026-09-10.
- Manual browser acceptance: pending. The available browser automation tool
  reported no connected browser; automated module checks are not claimed as
  manual acceptance.
