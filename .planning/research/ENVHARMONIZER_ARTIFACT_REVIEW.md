# envharmonizer release artifact review

Reviewed 2026-09-10 against published v0.1.1 assets and Concert commit `003f958` on `fix/enable-wqx-evidence-selection`. This document records the external artifact contract, measured compatibility, and proposed integration work. No runtime changes are included in this review.

## Assessment

Adopt pinned release tables through Concert's existing bundled-reference workflow. Media is an extension of an existing integration; life stage and analytical methodology require new input roles and shared runtime steps. Preserve ontology identity separately from unit routing, and retain source data and release evidence through exports and replay. Manufacturer/model harmonization cannot be populated from this release.

## Recommended artifacts

Pin **v0.1.1**. For Concert's existing bundled-reference workflow, use selected tables from [envharmonizer-tables-0.1.1.tar.gz](https://github.com/seanthimons/envharmonizer-releases/releases/download/v0.1.1/envharmonizer-tables-0.1.1.tar.gz), keeping the included manifests, checksums, and attribution. The bundle contains 17 tables in CSV and Parquet. The separately attached life-stage files do not include AMOS tables. [Release v0.1.1](https://github.com/seanthimons/envharmonizer-releases/releases/tag/v0.1.1) adds September ECOTOX applicability while preserving June mapping evidence and AMOS tables.

The [source package](https://github.com/seanthimons/envharmonizer-releases/releases/download/v0.1.1/envharmonizer_0.1.1.tar.gz) embeds corresponding RDS files and checked accessor/harmonization functions. These are another import option, but a runtime dependency brings imports including Arrow, DuckDB, and pdftools. The public repository's automatically generated source archives are not the attached R source package. The recommendations below are based on inspection of the attached package's `DESCRIPTION`, `R/`, tests, and embedded tables, plus the table bundle's `README.md` and manifests.

Verified SHA-256:

| Payload | SHA-256 |
|---|---|
| Table bundle | `56da987c0fb72e08915df5b7ecf1d099fdb03c5828fa1cc85debcceefe61daca` |
| R source package | `b5d0b717980d13712ddee3250edecfab43abafb91d93818dbb66e27925b3b71d` |

CSV import must use `na = '__ENVHARMONIZER_MISSING__'`, manifest column types, and `trim_ws = FALSE`. Empty strings are distinct from missing values, and identifiers must remain character. All 17 CSV tables matched the embedded RDS values and types with these settings. Parquet file hashes were verified, but its contents were not independently decoded in this review. The table manifest's export hashes are authoritative for this bundle: the preserved release manifest has original CSV hashes that differ because export encoding changed. The original manifest's top-level `version` remains `0.1.0`; the export manifest and source package identify `0.1.1`.

## AMOS media

The [table bundle](https://github.com/seanthimons/envharmonizer-releases/releases/download/v0.1.1/envharmonizer-tables-0.1.1.tar.gz) supplies the following distinct structures:

| Table | Rows × columns | Key and purpose |
|---|---:|---|
| `concert_media_map` | 267 × 19 | Unique `term`; compatibility vocabulary for pinned Concert imports |
| `matrix_terms` | 1,201 × 8 | Unique `term_id`; ontology metadata and reviewed routing annotations |
| `matrix_edges` | 1,425 × 8 | `child_id`, `parent_id`, `relation`; multiple parents are allowed |
| `matrix_synonyms` | 559 × 6 | Labels and normalized aliases joined by `term_id` |
| `methods` | 7,474 × 16 | Unique character `amos_method_id`; source method records |
| `method_matrices` | 7,701 × 15 | Method-to-matrix assertions; 5,656 distinct methods |

`concert_media_map` columns are `term`, `canonical_media`, `canonical_term`, `term_id`, `parent_id`, `preferred_label`, `rank`, `definition`, `envo_id`, `physical_phase`, `physical_state`, `is_water_based`, `concert_unit_route`, `media_category`, `source`, `assertion_mode`, `confidence_tier`, `confidence`, `active`. The fields `is_water_based` and `active` are logical; all other columns are character. There are 171 canonical rows and 96 aliases, all active, with no duplicate input terms.

The map has 12 gas, 94 liquid, and 161 solid rows. Routing is 12 `air`, 65 `aqueous`, 161 `solid`, and **29 missing**. The missing routes are deliberate nonaqueous liquids, including acetone, DMSO, ethanol, oils, fuel, emulsion, and vehicle. Their phase is known and `is_water_based` is false. Do not derive an aqueous route merely from liquid state, or replace a missing route with solid. A known term and a known conversion route are different facts.

The larger ontology contains 682 ENVO, 473 FOODON, and 46 reviewed local `AMH:` terms. Its 1,425 edges include 234 additional-parent rows beyond one parent per child. The compatibility map's single `parent_id` cannot represent that full graph. Ontology `term_id` also differs from Concert's local `media.*` identifier scheme; `envo_id` is legitimately missing for FOODON and AMH terms. The full `matrix_terms` table has 671 terms without a physical-phase annotation and 1,032 without a conversion route, so importing every ontology term as a trusted routing target would be incorrect.

The package's `harmonize_matrix()` returns long-form assertions with `input_id`, raw input, ontology label/ID, phase/routing, match type, assertion mode, confidence tier, and status. It may produce multiple rows for compound inputs such as `soil and water`, or ambiguous matches. It only targets terms with a nonmissing reviewed phase annotation. Therefore it cannot replace a row-preserving Concert lookup without explicitly handling cardinality. `method_matrices` contains promoted assertions only; its 7,701 rows do not cover all 7,474 methods. Never treat absence of an assertion as evidence of absence of a medium. [Source package, `R/harmonize-matrix.R` and `R/accessors.R`](https://github.com/seanthimons/envharmonizer-releases/releases/download/v0.1.1/envharmonizer_0.1.1.tar.gz).

## Analytical methods and instrumentation

The published instrumentation domain is primarily **analytical technique and detector harmonization**, with manufacturer/model evidence kept separately. Actual table counts from the [bundle](https://github.com/seanthimons/envharmonizer-releases/releases/download/v0.1.1/envharmonizer-tables-0.1.1.tar.gz):

| Table | Rows × columns | Purpose |
|---|---:|---|
| `analytical_terms` | 2,923 × 5 | `term_id`, `preferred_label`, `definition`, `source_ontology`, `analytical_role` |
| `analytical_edges` | 2,817 × 3 | `child_id`, `parent_id`, `relation` |
| `analytical_synonyms` | 9,138 × 10 | Exact labels/aliases, role, component order, provenance |
| `method_analytical_assertions` | 10,249 × 10 | 7,244 distinct methods; promoted analytical assertions |
| `instrument_mentions` | **0 × 7** | Evidence-only manufacturer/model text; no released observations |
| `method_methodologies_raw` | 7,895 × 5 | Original methodology assertions |
| `method_functional_classes_raw` | 118,736 × 5 | Original functional-class assertions |

There are 2,919 CHMO terms and four AMH terms. Most ontology terms (2,886) have `unclassified` roles. The promoted method assertions contain 5,506 `overall_method`, 2,164 `separation`, 2,043 `detection`, and 536 `unclassified` rows; none are `instrument_class` assertions. Do not describe this release as a populated instrument manufacturer/model catalog.

`method_analytical_assertions` columns are `amos_method_id`, `raw_index`, `raw_value`, `term_id`, `analytical_role`, `component_order`, `match_type`, `assertion_mode`, `confidence_tier`, `status`. Index/order fields are integer; other fields are character. Join to `methods` by `amos_method_id`, not `method_number`: the snapshot has 94 duplicate method-number rows beyond the first occurrence. There are 2,083 methods with multiple analytical assertions and 1,279 with multiple matrix assertions; joining both tables to method records without aggregation creates a cross product.

`instrument_mentions` defines `amos_method_id`, `raw_mention`, `manufacturer_raw`, `model_raw`, integer `page`, `section`, and `document_checksum`; it has no canonical `term_id`. `harmonize_methodology()` returns a long-form result, preferring exact composite CHMO methods. For example, its published tests specify `GC/MS` → `CHMO:0000497` with role `overall_method`, while `GC/FID` yields three ordered overall-method/separation/detection components. Arbitrary slash strings remain queued. A future Concert integration must preserve components and roles rather than keep the first match. [Source package, `R/harmonize-analytical.R` and `tests/testthat/test-analytical-harmonization.R`](https://github.com/seanthimons/envharmonizer-releases/releases/download/v0.1.1/envharmonizer_0.1.1.tar.gz).

## ECOTOX life stage

Choose tables by the **actual database source-release identifier**:

| Exact ECOTOX release | Dictionary | Review table |
|---|---|---|
| `ecotox_ascii_06_11_2026.zip` | `lifestage_dictionary`, 103 × 13 | `lifestage_review`, 36 × 9 |
| `ecotox_ascii_09_15_2026.zip` | `lifestage_dictionary_09_15_2026`, 103 × 14 | `lifestage_review_09_15_2026`, 36 × 10 |

The September tables add `mapping_evidence_release`, whose value remains `ecotox_ascii_06_11_2026.zip`. September applicability follows exact native code-description parity across 139 entries; it is not a new set of biological mapping decisions. The provider's exact September identifier is intentional even though its date is later than the release publication date. [Published review record](https://github.com/seanthimons/envharmonizer-releases/releases/download/v0.1.1/REVIEW.md), [comparison](https://github.com/seanthimons/envharmonizer-releases/releases/download/v0.1.1/comparison.json).

The dictionary key is exact, case-sensitive `org_lifestage` **description text**, not the native code, taxon, or a generic ToxVal life-stage field. Its columns are `org_lifestage`, `source_ontology`, `source_term_id`, `source_term_label`, `source_term_definition`, `source_provider`, `source_match_method`, `source_match_status`, `source_release`, `ecotox_release`, `harmonized_life_stage`, logical `reproductive_stage`, `derivation_source`, plus September's `mapping_evidence_release`. Dictionary keys are unique; unresolved descriptions are separate review rows.

Observed seven-category mapping counts: Adult 30; Egg/Embryo 15; Juvenile 22; Larva 25; Other/Unknown 1; Senescent/Dormant 8; Subadult 2. The 103 dictionary rows have 94 false and nine true reproductive flags. The other 36 source descriptions must keep missing derived values; arbitrary unknown values must also stay missing. These are vocabulary counts, not toxicity-result coverage estimates. The ontology sources are S11, PO, UBERON, FOODON, AMPHX, and DpseDv. The category reduction and reproductive flag are author-derived, experimental mappings without independent review. [Dictionary and review tables in the bundle](https://github.com/seanthimons/envharmonizer-releases/releases/download/v0.1.1/envharmonizer-tables-0.1.1.tar.gz), [review record](https://github.com/seanthimons/envharmonizer-releases/releases/download/v0.1.1/REVIEW.md).

`harmonize_lifestage(x, ecotox_release)` preserves input rows, order, and source columns; accepts a character/factor `org_lifestage`; rejects duplicate column names and preexisting derived/provenance output columns; and rejects unlisted releases. It appends exactly:

- `harmonized_life_stage`
- `reproductive_stage`
- `lifestage_match_status`: `matched`, `unresolved`, `unmatched`, or `missing`
- `lifestage_artifact_version`: `ecotox-v0.1.0` for June or `ecotox-v0.1.1` for September
- `lifestage_review_status`: `not_independently_reviewed`

It does **not** append the full dictionary evidence or selected `ecotox_release`/`mapping_evidence_release`; persist these separately if Concert relies on the function. No provider request or database mutation is needed. A replacement for removed ECOTOX harmonization must consume native descriptions and retain the database's source release, rather than fabricate or guess either. [Source package, `R/lifestage.R`](https://github.com/seanthimons/envharmonizer-releases/releases/download/v0.1.1/envharmonizer_0.1.1.tar.gz).

## Provenance and validation

The AMOS snapshot records 7,474 records fetched 2026-08-20 via the development AMOS endpoint with ComptoxR `1.6.0.9000`. ENVO is pinned to `releases/2026-06-26`; CHMO to `releases/2026-05-28`; FOODON has a content hash but no populated release identifier. The AMOS validation gate is scoped to `concert_v0.1`; broad precision/recall is not supplied. Do not infer production refresh equivalence or broader validation from the compatibility gate. See `release-manifest.json` inside the [table bundle](https://github.com/seanthimons/envharmonizer-releases/releases/download/v0.1.1/envharmonizer-tables-0.1.1.tar.gz).

Retain domain-specific attribution: the package's MIT code license does not replace the released tables' attribution terms. `DATA_LICENSE.md`, `AMOS-ATTRIBUTION.md`, `ECOTOX-ATTRIBUTION.md`, and `ECOTOX-REVIEW.md` are included in the bundle. AMOS ontology-derived tables are CC BY 4.0; ENVO content is CC0, and ECOTOX source ontologies have their own listed terms. These files belong with any redistributed table subset.

Validation performed locally: both archive hashes matched; all 34 CSV/Parquet table hashes matched `table-manifest.json`; all 17 CSV tables matched embedded RDS values/types after explicit import configuration; R inspection confirmed table dimensions, key uniqueness, statuses, routing nulls, and relationship multiplicity. No Concert application tests were run for this artifact-only portion. Downloaded source, tables, and sourceable `review.R` / `check-exports.R` are in `C:/Users/sxthi/AppData/Local/Temp/concert-envharmonizer-review-20260910/`; `check-exports.R` is the successful final parity check. The initial inspection script's stricter identity check failed before the CSV whitespace import setting was corrected.

## Concert comparison

### Media: compatible vocabulary, incompatible metadata and display assumptions

Concert currently builds `amos_media.rds` from 29 canonical rows, seven aliases, and 54 single-parent ontology nodes. The resulting cache has **33 rows and 14 columns**. Its schema is `term`, `canonical`, `canonical_term`, `envo_id`, `parent`, `media_category`, `ontology_node_id`, `ontology_path`, `physical_state`, `source`, `fetch_timestamp`, `assertion_mode`, `confidence`, `active`. See [builder](../../scripts/build_amos_media.R), [source tables](../../inst/extdata/reference_sources), and [media engine](../../R/media_harmonizer.R).

Running the existing `harmonize_media()` against all 33 old keys with each map produced:

| Check | Observed result |
|---|---|
| Existing keys retained | 33 of 33 |
| Additional keys | 234 |
| Previously resolved keys lost | 0 |
| Changed canonical/category outputs | `lake`: unmatched to `lake water` / `aqueous`; `runoff`: unmatched to `runoff` / `aqueous` |

This demonstrates compatibility for the existing exact vocabulary, not arbitrary compound inputs. A direct cache replacement still has these defects:

1. `normalize_media_map_for_display()` reconstructs a fixed 14-column tibble, discarding ten upstream fields including `term_id`, `parent_id`, `definition`, `is_water_based`, and `concert_unit_route`. The old ontology ID/path fields become missing. Map `term_id` into a preserved ontology-ID field without lowercasing CURIEs; retain the upstream routing and evidence fields. Do not reinterpret upstream parent IDs as the old `parent` label lookup, or force a multi-parent graph into the old tree validator.
2. `build_media_editor_rows()` admits active `concert`/`user` rows and unresolved `amos` rows. Published rows use `source = 'amosharmonizer'`; the unmodified editor returns **zero rows** for the published map before input is processed. The UI badge also renders that source as `other`. Recognize published defaults explicitly while preserving actual provenance and user override precedence. See [editor implementation](../../R/mod_harmonize.R).
3. `is_resolved_media_row()` requires both a canonical term and a route. Consequently published acetone and DMSO identities still return `media_unmatched`. Separate identity-match status from conversion eligibility. Keep their route missing; the existing [unit engine](../../R/unit_harmonizer.R) already refuses unknown ppb/ppm routes.
4. [The shared runtime](../../R/harmonization_runtime.R) assigns `updated_data$media` from the route, not the canonical term. [The ToxVal mapper](../../R/toxval_mapper.R) then reads that field. With input column `media = 'drinking water'` and no prior `media_original`, both exported `media` and `media_original` become `aqueous`. Preserve raw media before mutation and keep canonical media/ontology identity distinct from the internal routing category. Exporting canonical labels through `media` would change the existing output contract and must be documented and tested explicitly; keeping the current flat field requires another persisted field for canonical identity.

The simplest migration uses the compatibility map for row-level harmonization and the published term/edge tables where ontology context is needed. Rebuilding the entire 1,201-node ontology into Concert's 54-node tree shape is unnecessary and lossy.

### Life stage: add an explicit mapping stage

There is no current Concert call to `eco_results()`, `lifestage_details`, or a ComptoxR life-stage harmonizer under `R/`. Concert's only operational life-stage handling is the mapper's pass-through `lifestage` and `lifestage_original` fields. An incoming `org_lifestage` or `harmonized_life_stage` column is not automatically wired to them. The tag taxonomy, header suggestions, shared runtime, and UI have no life-stage role.

[ComptoxR's v2.0.0 migration](https://github.com/seanthimons/ComptoxR/commit/1f61423b4469ff7de39bb6f9459d33d8806f771b) removes `harmonized_life_stage`, `reproductive_stage`, and `lifestage_details` from ECOTOX results/calls while retaining `organism_lifestage` and `org_lifestage`. Thus this is new Concert wiring to restore the derived data contract, rather than replacing an existing Concert API call.

Add a `LifeStage` input role for the native description and explicit ECOTOX source-release metadata. Use the matching published dictionary/review tables with exact matching, preserving row order, source code/description, statuses, reproductive flag, artifact version, evidence release, and review status. Populate the existing ToxVal `lifestage` from the derived value and `lifestage_original` from the untouched source description. Unresolved or unknown descriptions must not silently become harmonized values. Generic uploaded life-stage labels without ECOTOX provenance should remain pass-through until a separate mapping is specified.

Current `harmonize_lifestage()` rejects already-derived columns, so a reusable pipeline must recompute from preserved raw input and deliberately replace only its own generated fields. Do not let a second harmonization run destroy originals or fail because the first run added its outputs.

### Instrumentation: introduce analytical methodology with long-form results

Concert has no analytical method/instrument tag, lookup, result object, or ToxVal field. Add an `AnalyticalMethod` role whose input is technique/methodology text. Match against the released terms and synonyms using the upstream normalization, curated precedence, exact composite preference, and explicit component ordering. Resolve distinct input values once before joining results back to source row IDs.

Store analytical results separately, keyed by source row and component order, with term ID, role, label, match/status, confidence, and source evidence. This permits multiple components without multiplying measurement/ToxVal rows. AMOS method-number lookups are a different input contract: use `amos_method_id` for method assertions and do not assume every user method string is a unique AMOS method number. Keep technique classification separate from claims about the physical instrument used.

Retain analytical results in returned headless objects and workbook/sidecar exports. Concert's flat 56-column ToxVal schema has no instrument slot; overloading `exposure_method` would conflate different concepts. A manufacturer/model feature must wait for populated evidence or a separate source.

## Proposed implementation sequence on this branch

These are recommendations, not changes already implemented.

1. **Import the pinned tables.** Extend or replace the media build script with a sourceable import function that verifies archive/table hashes and schema/key contracts, preserves explicit missing values/types, and writes only the required bundled tables plus manifests/attribution. Replace competing media defaults with the published snapshot; preserve user overrides. No runtime network fetch or new ontology inference is needed.
2. **Complete the media adapter.** Update `R/media_harmonizer.R`, `R/cleaning_reference.R`, `R/harmonization_runtime.R`, and `R/mod_harmonize.R` for IDs, source handling, nullable routing, original values, and canonical results. Decide and document the flat `media` export semantics in `R/toxval_mapper.R`. Regenerate only the directly affected bundled cache/docs.
3. **Wire life stage end to end.** Extend `R/tag_helpers.R`, `R/auto_tag_columns.R`, `R/mod_tag_columns.R`, and the shared runtime/reference loading with the description tag, release metadata, and mapping results. Update UI run eligibility and both step-mask definitions: `R/mod_harmonize.R` currently shadows the shared mask helpers. Pass metadata through `R/curate_headless.R`; retain originals and map the existing ToxVal fields.
4. **Wire analytical methodology end to end.** Reuse the same tag/runtime entry points with a separate long-form result. Add the necessary result display, source-row linkage, and export/import preservation. Do not add a manufacturer/model editor around an empty table.
5. **Preserve replay and resume.** Update `R/code_generation.R`, `R/export_helpers.R`, `R/config_import.R`, and app state/reset handling in `inst/app/app.R` for the new tags, release metadata, and sidecars. Extend the existing snapshot machinery only where needed. Current keyed-map replay warns on baseline-hash drift and then applies overrides over current defaults; it does not reproduce an old default map. Pin artifact identity and preserve the needed historical snapshot, or explicitly reject incompatible replays, before promising deterministic cross-release replay.
6. **Validate, then update the PR.** Run targeted contracts below and a fresh Shiny startup for implementation changes. Keep the media change, life-stage addition, and methodology addition in coherent commits. Review ComptoxR dependency changes separately from the reference-data adapter: this checkout pins `v1.5.1`, upstream [v3.0.0](https://github.com/seanthimons/ComptoxR/releases/tag/v3.0.0) has additional API changes, and the local test environment contains `1.6.0.9000`.

## Validation evidence and acceptance checks

Baseline command, run from the Concert root through a sourceable temporary R script:

```r
devtools::test(
  filter = '^(media-(harmonizer|ontology|persistence|pipeline-wiring)|toxval-mapper)$',
  stop_on_failure = TRUE
)
```

Result: **308 assertions passed, zero failures, zero skips**, with 13 locale/encoding warnings from `janitor`/`snakecase` in a media headless test. R startup also warned that `C.UTF-8` was unavailable; testthat was built under R 4.5.3 while the local runtime is R 4.5.1. These checks validate the existing baseline, not the unimplemented adapters or compatibility with ComptoxR v3.0.0. No full suite or Shiny cold boot was run because application code was not changed.

Additional sourceable checks in the temporary review directory: `compare_concert.R` reproduces all 33 media-key comparisons and schema losses; `check_runtime.R` reproduces the raw-media export overwrite and zero-row editor. Both passed their assertions. For durable regression tests during implementation, require:

- All 33 old media keys, the two intended newly resolved keys, preserved user overrides, nonaqueous known identities with missing routes, and no row multiplication from mixed media.
- Raw versus canonical versus route separation; original values survive repeated runs and export/import.
- Exact June/September life-stage selection, rejected unsupported releases, mapped/unresolved/unknown/missing descriptions, case sensitivity, empty input, duplicated source rows, and reproductive `NA` distinct from false.
- Analytical composite and component cases (`GC/MS`, `GC/FID`), unknown input, stable component ordering, and unchanged measurement row counts.
- New-role-only datasets, Shiny/headless parity, step toggles/reset, replay across artifact versions, and workbook/sidecar round trips.

GitHub state at review time: `fix/enable-wqx-evidence-selection` exists remotely at `003f958`, but `gh pr view` found no associated PR. Recent PR #59 (ComptoxR v1.7.1 pin) is already merged; no PR was changed or merged during this assessment. Existing untracked `.beans` files and `CONTEXT.md` were left untouched.
