

# concert NEWS

## v0.3.1 (2026-07-21)

#### Bug fixes

- detect ’ & ’ and ’ / ’ multi-analyte separators (#54)
  ([2de8fd0](https://github.com/seanthimons/concert/tree/2de8fd0f050b163a9fb19407abc034f01ef2f98d))

#### Other changes

- bump version to 0.3.1
  ([33ecc81](https://github.com/seanthimons/concert/tree/33ecc812019d3a89d81adb1ceb5233f6377b9e71))

Full set of changes:
[`v0.3.0...v0.3.1`](https://github.com/seanthimons/concert/compare/v0.3.0...v0.3.1)

## v0.3.0 (2026-07-21)

#### New features

- fan one review decision to all rows sharing name + CAS
  ([4d0535a](https://github.com/seanthimons/concert/tree/4d0535a263decf66e5a062476c6a7214b505d4d6))

#### Bug fixes

- use ASCII in review pairing label for R CMD check
  ([1de0618](https://github.com/seanthimons/concert/tree/1de0618a9b30336743e0b206c479d8128b04c952))

#### Refactorings

- consolidate multi-analyte and multi-CAS review into one surface
  ([0c8df57](https://github.com/seanthimons/concert/tree/0c8df577e47c71bd21b74dc18dce88e2b8ee4c19))

#### Tests

- prove review fan-out is CAS-column-order independent
  ([5bb771e](https://github.com/seanthimons/concert/tree/5bb771e90687770cce7584ebb8a2dc26cfd4f3dc))

#### Docs

- update NEWS.md for v0.3.0 \[skip ci\]
  ([c215756](https://github.com/seanthimons/concert/tree/c215756dff1ece1caea5aadc83c25221816335fb))
- track review-resolution follow-up beans (#54, #55)
  ([347221b](https://github.com/seanthimons/concert/tree/347221b073fe431267b0ae2a076942ff91be200b))

#### Other changes

- bump version to 0.3.0 \[skip ci\]
  ([5b1937a](https://github.com/seanthimons/concert/tree/5b1937a47c3ca5fc44c8cc4a26f2c731ee4e89b3))

Full set of changes:
[`v0.2.0...v0.3.0`](https://github.com/seanthimons/concert/compare/v0.2.0...v0.3.0)

## v0.2.0 (2026-07-20)

#### New features

- split embedded units out of measurement values
  ([532c0ce](https://github.com/seanthimons/concert/tree/532c0cee6a7f42b992d4a5694d5556af13ebde25))
- rebuild numeric parse issues as editable bulk-reassign table
  ([8369d2f](https://github.com/seanthimons/concert/tree/8369d2fec2b2350bbcc6b3e38b9e28a6593032f4))
- add MFL fiber-concentration conversions to stable dictionary
  ([e6b9956](https://github.com/seanthimons/concert/tree/e6b99567674c32990265f03c83337ae90e9eaca2))

#### Bug fixes

- harmonize microfiber units to MFL
  ([84e6734](https://github.com/seanthimons/concert/tree/84e67346af7cf62ce2b2e0c7ab2ff4379df7405c))
- resolve blank-target unit mappings
  ([d215f96](https://github.com/seanthimons/concert/tree/d215f96988936bcbcbf56179e0a61060cbeb94af))
- apply searchable review filters on selectize changes
  ([300bd80](https://github.com/seanthimons/concert/tree/300bd80a654c1494a569b1d6b96a000518dab0ad))
- keep filter dropdowns above table
  ([e8edba9](https://github.com/seanthimons/concert/tree/e8edba9bfaa7495becab61672c5891a85e9a2468))

#### Refactorings

- reorder editor panels — unmatched under unit map, parse issues above
  corrections
  ([067ef89](https://github.com/seanthimons/concert/tree/067ef895b93a804e759eba098a155f77c87da640))

#### Build

- pin ComptoxR to v1.5.1
  ([690eaf6](https://github.com/seanthimons/concert/tree/690eaf6e79770f188900789247bf19fbbe7dab72))

#### CI

- add workflow to track ComptoxR releases and open pin-bump PRs
  ([28a5cf0](https://github.com/seanthimons/concert/tree/28a5cf018c149a7d981ce576de7c0e4ad8f7cd5e))

#### Docs

- update NEWS.md for v0.2.0 \[skip ci\]
  ([c840d1f](https://github.com/seanthimons/concert/tree/c840d1fbc7a6f6ec6ab4296c8738dc80b0d7fdcc))
- mark internal editor/split helpers @noRd
  ([700d324](https://github.com/seanthimons/concert/tree/700d324c4c9eb4c8fd3d1c146a97ce83120a920e))

#### Other changes

- bump version to 0.2.0 \[skip ci\]
  ([f91ff3c](https://github.com/seanthimons/concert/tree/f91ff3cce240533dd67f55602e800791272475c3))

Full set of changes:
[`v0.1.4...v0.2.0`](https://github.com/seanthimons/concert/compare/v0.1.4...v0.2.0)

## v0.1.4 (2026-07-14)

#### New features

- clarify canonical site identity
  ([bf40b42](https://github.com/seanthimons/concert/tree/bf40b42ad956b2c8b89a7f08b1065fdbe6944b62))
- add curated results dropdown filters
  ([4f6daaa](https://github.com/seanthimons/concert/tree/4f6daaa055b343c4af86245305d095b279c10c15))

#### Bug fixes

- advance the replay baseline to the harmonized stage
  ([bea4be7](https://github.com/seanthimons/concert/tree/bea4be79f4a1782f0cf2f00a8994be428469f6f0))
- reconstruct full replay when resuming a baseline-less workbook
  ([98a3eaa](https://github.com/seanthimons/concert/tree/98a3eaad47caaa91e17e69261fd833ef1171a887))

#### Performance

- snapshot harmonization maps as provenance-blind deltas
  ([99ebaa8](https://github.com/seanthimons/concert/tree/99ebaa89844dd8d008c128ab90ed67cbd56cb799))

#### CI

- align GitHub Actions across R package repos (#49)
  ([b7c329c](https://github.com/seanthimons/concert/tree/b7c329c9509f6c089e20804065df16d3097b42e7))

#### Docs

- update NEWS.md for v0.1.4 \[skip ci\]
  ([7dd3aba](https://github.com/seanthimons/concert/tree/7dd3aba08a6713763b805d1ddd539069c3083718))
- track resume-replay bug analysis and id-keying follow-up
  ([437b325](https://github.com/seanthimons/concert/tree/437b325548e7c6e097df997ee48b7085489fbb30))

#### Other changes

- bump version to 0.1.4 \[skip ci\]
  ([38d118f](https://github.com/seanthimons/concert/tree/38d118f8628e16f6e03b0f9527122674d1e5155f))
- log when a workbook is exported without a replay baseline
  ([cdb9b50](https://github.com/seanthimons/concert/tree/cdb9b508f8d25ba082d0c94c7ebac9261c97c3cc))
- add csm_curation_raw replay script
  ([fdf3692](https://github.com/seanthimons/concert/tree/fdf369290fb82add26283314036ca06c74bb51fb))

Full set of changes:
[`v0.1.3...v0.1.4`](https://github.com/seanthimons/concert/compare/v0.1.3...v0.1.4)

## v0.1.3 (2026-07-10)

#### Bug fixes

- harmonize environmental units
  ([9c304be](https://github.com/seanthimons/concert/tree/9c304bee42e3e3db571c007abd290a5d01eab9aa))

#### Other changes

- bump package version to 0.1.3 (#48)
  ([9154935](https://github.com/seanthimons/concert/tree/91549357fba7637fa662b064426090edc7bf9fcb))

Full set of changes:
[`v0.1.2...v0.1.3`](https://github.com/seanthimons/concert/compare/v0.1.2...v0.1.3)

## v0.1.2 (2026-07-09)

#### New features

- salvage SSWQS-style numeric strings, zero-digit values become
  narrative
  ([536416c](https://github.com/seanthimons/concert/tree/536416c6c6e4a3b21578e8c4a5554207e96cc452))

#### Bug fixes

- address PR #47 review feedback
  ([85ab9f6](https://github.com/seanthimons/concert/tree/85ab9f6f6a4a5c9bfa6cfa440fa37cad8e40cba8))

#### Tests

- pin SSWQS criterion-value corpus as parser regression fixture
  ([2499d5f](https://github.com/seanthimons/concert/tree/2499d5fa658416532be9faf792ef7807f11b2642))

#### Other changes

- bump package version to 0.1.2 (#47)
  ([666b2cc](https://github.com/seanthimons/concert/tree/666b2cc37b0ae98922b2ee19e92b5a9ecf980f6d))

Full set of changes:
[`v0.1.1...v0.1.2`](https://github.com/seanthimons/concert/compare/v0.1.1...v0.1.2)

## v0.1.1 (2026-07-09)

#### New features

- show package version in app header
  ([1a2e136](https://github.com/seanthimons/concert/tree/1a2e13632c2c2188f00d6d4d400020d4b67eb0ad))
- unify harmonization runtime and replay state
  ([4b3d5b4](https://github.com/seanthimons/concert/tree/4b3d5b4f3dcd00a3507f776652117ecb37854e67))
- add flat ToxVal CSV/Parquet export from the app via shared writer
  ([d429089](https://github.com/seanthimons/concert/tree/d4290895b0945a536e5ac70597e85e37abfc6c24))
- compound-keyed review replay with compact reference snapshot
  ([20b9ade](https://github.com/seanthimons/concert/tree/20b9ade1062eed3f4c26359926940271b206b050))
- rebuild isotope lookup cache from ComptoxR periodic table
  ([dfc1cb5](https://github.com/seanthimons/concert/tree/dfc1cb55b94c74ceab3ae8a51648b2e2419b6deb))
- carry resolved WQX name into ToxVal export as crosswalk key
  ([26c99e6](https://github.com/seanthimons/concert/tree/26c99e6fdc7db40d0bd6a446841788a6fd135b69))
- shape-aware replay code emission
  ([04560b2](https://github.com/seanthimons/concert/tree/04560b24059d1b4d2791feb005345f17e6b34e77))
- add bulk fill for site aliases
  ([7534299](https://github.com/seanthimons/concert/tree/7534299f679b97a1c728c397242d4e48402503fe))
- add site alias map dataset context
  ([500946b](https://github.com/seanthimons/concert/tree/500946baf33a70bd94a384126917d4910fede36d))
- add location curation preflight
  ([644da10](https://github.com/seanthimons/concert/tree/644da105ac7d3e2b9b4d24d9091c87043d7b8131))
- vendor CAS, unicode, formula, and mixture primitives from ComptoxR
  ([6513e9e](https://github.com/seanthimons/concert/tree/6513e9ee78e7be430714675b8f533dce5a4c32dd))
- add tag column suggestion controls
  ([46fc106](https://github.com/seanthimons/concert/tree/46fc1069c298ca87acf76af60ef19ffbb3c061a5))
- update review columns and benchmark generator
  ([c2c09f9](https://github.com/seanthimons/concert/tree/c2c09f9e65d887cdaeb7f8ad54de5502c35ee537))
- add CLAUDE.md, roxygen docs, and reference cache files
  ([b002173](https://github.com/seanthimons/concert/tree/b0021737ffd5d33aca9877f1ed3f0d550f5f1fe9))
- add dropdown filters for categorical columns in curation table
  ([44617c1](https://github.com/seanthimons/concert/tree/44617c1ea26760e0831e2665417baae88b8e5990))
- split curation tab into 3 separate tabs with full-width layout
  ([7ad5177](https://github.com/seanthimons/concert/tree/7ad51776b86cbe94c4ff971ed56329b38fa274e7))
- add chemical curation workflow with ComptoxR integration
  ([4aebefa](https://github.com/seanthimons/concert/tree/4aebefa4792386b0f5347403b23016f123606578))

#### Bug fixes

- persist replay baseline across session export and import
  ([fb8388b](https://github.com/seanthimons/concert/tree/fb8388b3ad112378684cb83fd42cb436042a12ce))
- added example replay script
  ([40b68a0](https://github.com/seanthimons/concert/tree/40b68a0f0b9fdf5df9477151b7c83ff31dbebb71))
- hide dataset context audit columns by default
  ([e25160c](https://github.com/seanthimons/concert/tree/e25160cc075ddb41cdee8494ef9e001cc64b0698))
- preserve dataset context table state on edit
  ([2d9268e](https://github.com/seanthimons/concert/tree/2d9268ecb32091c5dd7055cbb5436aadccdc81d3))
- polish concert review and tagging UI
  ([e62e3c1](https://github.com/seanthimons/concert/tree/e62e3c186cb4fd4c45371d1107c240b67e1c4123))
- require resolved media for unit routing
  ([9b1e730](https://github.com/seanthimons/concert/tree/9b1e730fae81ab8105727b5cf41b8be12e59e3c5))
- flag WQX evidence conflicts
  ([ae246b6](https://github.com/seanthimons/concert/tree/ae246b6540bda519290a6d7ae289befce9bebac5))
- align review display with consensus source
  ([884833a](https://github.com/seanthimons/concert/tree/884833a332ed493c008bfdece4625640a0fa4115))
- normalize WQX locant variants
  ([12d089e](https://github.com/seanthimons/concert/tree/12d089e6aaa0f0606fa3bd9c093c2a5dde3da8d0))
- keep unresolved isotope matches searchable
  ([8413050](https://github.com/seanthimons/concert/tree/84130501aa36e950ecbfcd2b5e7787d146093185))
- harmonize environmental radiological units
  ([79d43a1](https://github.com/seanthimons/concert/tree/79d43a1460a7fa21659230daea712c8019e58d8c))
- vectorize pinned-row filtering and deduplicate export join
  ([0c9d662](https://github.com/seanthimons/concert/tree/0c9d6624a65d11e1b586820d3f872fd69e57bb90))
- always recommend CAS normalization when CASRN columns are tagged
  ([d23a44d](https://github.com/seanthimons/concert/tree/d23a44d8d89aefdda2733ce64775ae632534fcd8))
- recalc consensus_summary after classify_auto_resolve
  ([e9c8f43](https://github.com/seanthimons/concert/tree/e9c8f439c8d362500ad090fdd872457a95d4a519))
- restore unname() on badge color lookups
  ([d6c2256](https://github.com/seanthimons/concert/tree/d6c22566fa735f9ae2a22ba18785e7e22846d013))
- regenerate NAMESPACE to export scoring functions
  ([4b488a3](https://github.com/seanthimons/concert/tree/4b488a36a1e9bf1d6042a1b01cd7e5842dd55a63))
- revise plans based on checker feedback
  ([2be698a](https://github.com/seanthimons/concert/tree/2be698a32fb587925103ecdca436116d3c9d5348))
- lint fix for outer_negation rule, clarify onFlushed comment
  ([4bc37dd](https://github.com/seanthimons/concert/tree/4bc37dd04cd0ab4497f9dfc37e5dd1f7a5342a60))
- defer selectize init via shinyjs::delay, unname badge lookups, lint
  fix
  ([659ef78](https://github.com/seanthimons/concert/tree/659ef78327ffaaacd73b1525b636e4de68b22bea))
- WQX results shadowed by NA-dtxsid CompTox exact rows
  ([4a51f89](https://github.com/seanthimons/concert/tree/4a51f890857f9fc10390731d75e0052edec298c9))
- apply ampersand normalization to hash table keys
  ([5b22388](https://github.com/seanthimons/concert/tree/5b2238844fc26adc22f455348817f718b0a97c0c))
- alias dedup priority and ampersand normalization
  ([039d26b](https://github.com/seanthimons/concert/tree/039d26b90e9b4c3c84269a89492e60e2e50440a4))
- revise plans based on checker feedback
  ([5622a09](https://github.com/seanthimons/concert/tree/5622a09667309bedb9a60227e45f41a1bdc90737))
- rename stale bench_files reference to bench_file
  ([4f3a71c](https://github.com/seanthimons/concert/tree/4f3a71c9be934d4b56f2a1808b61aed91ec86e90))
- add cas=CASRN to benchmark tag_map
  ([2a98d00](https://github.com/seanthimons/concert/tree/2a98d0015c6fb6eb011238561ec6f56ff10ac6d2))
- hardcode tag_map for detections.csv columns
  ([c4a79d9](https://github.com/seanthimons/concert/tree/c4a79d95142e301aa1145dc44c49877740a54783))
- handle list-type isotope_lookup in precheck_isotope_shortcodes
  ([cae335c](https://github.com/seanthimons/concert/tree/cae335c346e931f2985d11e4715eb627b3e656fc))
- hardcode detections.csv as benchmark input file
  ([9a9098b](https://github.com/seanthimons/concert/tree/9a9098b1a9afb679b344759897e9063ec413c08f))
- WR-02 add readxl guard to stopifnot block for standalone script safety
  ([3d7ee44](https://github.com/seanthimons/concert/tree/3d7ee44e7538ecefc1a3a9c36cf2830382526d5a))
- WR-01 use correct media string ‘solid’ instead of ‘soil’ in
  harmonization benchmark
  ([0b9ba06](https://github.com/seanthimons/concert/tree/0b9ba064fa49e8c5f571714c4ec6c841160473db))
- WR-03 invalidate toxval_output in cascade observers on edit
  ([33d0244](https://github.com/seanthimons/concert/tree/33d0244c445fb0db527be74560aacfeb9d461432))
- WR-02 use jsonlite::toJSON for robust JS string escaping in onclick
  ([e32f491](https://github.com/seanthimons/concert/tree/e32f4916344c85a8541ddba1550c95913eb9b1a2))
- WR-01 invalidate toxval_output after incremental harmonization
  ([b0c2a0d](https://github.com/seanthimons/concert/tree/b0c2a0d34afec13846c09cbb70d738c63c4a23c0))
- CR-01 expand curated_data rows to match harmonized rows via
  orig_row_id
  ([59a16b5](https://github.com/seanthimons/concert/tree/59a16b562891db0c6a1980e67477225803503192))
- add bottom margin to Run Harmonization button
  ([318aad1](https://github.com/seanthimons/concert/tree/318aad1bb631b731a4e4ef981ec424c88f2f4fd3))
- cache regression tests use correct env + exercise production code
  ([a0ae4f3](https://github.com/seanthimons/concert/tree/a0ae4f38cc9ce3bf42d4b3269657b0cb0a93699e))
- incremental harmonization + cache regressions from perf work
  ([3ff197f](https://github.com/seanthimons/concert/tree/3ff197f05be30ba1fdd8193151b5af1a6da32466))
- replace transient notification with blocking modal in tag columns
  ([a5a402a](https://github.com/seanthimons/concert/tree/a5a402a8e75364bd6ff59f5b551f172825698c05))
- revise plans based on checker feedback
  ([4de8035](https://github.com/seanthimons/concert/tree/4de8035a386b7c213c1bcfe7f1c2739a7853bedd))
- revise plans based on checker feedback
  ([d103f42](https://github.com/seanthimons/concert/tree/d103f4224b3d2859e81e8359921b2cca127c4a7f))
- revert tag_map validation - check keys (column names) not values (tag
  types)
  ([81f290f](https://github.com/seanthimons/concert/tree/81f290f826127891883c99fe0f23ad6b76b131fc))
- validate tag_map values (column names) not keys (semantic roles)
  ([0a07e5e](https://github.com/seanthimons/concert/tree/0a07e5e5471e0fb41168dc109cff4f00a387da2d))
- harden strip_reference_terms and add test coverage
  ([9332fdf](https://github.com/seanthimons/concert/tree/9332fdf5f6e1b216e32a3c396fafb9de42d94fb8))
- make dropdown filter choices data-driven
  ([d7a871f](https://github.com/seanthimons/concert/tree/d7a871f1960e1d8a8c5611c4cf8de4dea48a2b1b))
- revise plans based on checker feedback
  ([8c180b3](https://github.com/seanthimons/concert/tree/8c180b348be2fa3685392d2a86b4a2143f75418e))
- disable drifted ComptoxR functional use call, add TODO
  ([88a8aaf](https://github.com/seanthimons/concert/tree/88a8aaf4fc21131dc9981358bf5a5e7cae62bf0a))
- add missing rhandsontable to package dependencies
  ([893d3db](https://github.com/seanthimons/concert/tree/893d3dbfad50f7922a7ded01797527e758ec6c97))
- merge test task into implementation task for nyquist compliance
  ([d69a94b](https://github.com/seanthimons/concert/tree/d69a94b6e738f40666d8f00365525d926574464e))
- remove inaccurate tdd attribute from Plan 14-01 Task 1
  ([2938f71](https://github.com/seanthimons/concert/tree/2938f71984d9aba2d41b3146e41567bada487afe))
- replace nonexistent broom icon with magic/eraser
  ([85bd546](https://github.com/seanthimons/concert/tree/85bd546ac9c457b5631a100b78bde86b6a89a00f))
- replace modal actionButton with JS-triggered button
  ([3fe2c03](https://github.com/seanthimons/concert/tree/3fe2c031cb221468cf80687e929efabeb945a879))
- read modal inputs before removeModal, validate selected rows
  ([340f8ab](https://github.com/seanthimons/concert/tree/340f8ab173f58f3fd2be4e077ad7d191400106de))
- quote comma-containing chemical names in test CSV
  ([b93d84c](https://github.com/seanthimons/concert/tree/b93d84c420af8657b89e76e6a221bbb339de1e47))
- re-enable apply_retag button after re-curation completes
  ([38ec2e5](https://github.com/seanthimons/concert/tree/38ec2e5e930599bbbacf161df8e6d5ded33862c9))
- show Validate All button and prevent table refresh on cell edit
  ([45632ee](https://github.com/seanthimons/concert/tree/45632eeff1a2d2ee864236817577dd581b8e5d7f))
- move prototype_pipeline.R out of R/ to stop Shiny auto-sourcing
  ([68bb35b](https://github.com/seanthimons/concert/tree/68bb35b87a77b4f989f889fe47e2144b8075cead))
- replace all joins with direct vector indexing in map_results_to_rows
  ([dadd4ef](https://github.com/seanthimons/concert/tree/dadd4ef99959ac194551be4f65006ac87a38aaf3))
- eliminate many-to-many join in map_results_to_rows
  ([0296cae](https://github.com/seanthimons/concert/tree/0296cae391329795d7ad7cd6ca2044778edae9b0))
- prevent table re-render on cell edit, fix queued state handling
  ([cbf8fca](https://github.com/seanthimons/concert/tree/cbf8fcae6965fcd7611505cc36db7c866b4cb85e))
- fix table reset on cell edit and row duplication
  ([d7586a6](https://github.com/seanthimons/concert/tree/d7586a657c63b457189c3fca949fdd900cd2cbcd))
- fix app startup errors in Phase 8 code
  ([1ccbd54](https://github.com/seanthimons/concert/tree/1ccbd54a6083c6f292907847c72d56a3902ec926))
- revise plans to migrate functions into curation.R per user decision
  ([65a0a00](https://github.com/seanthimons/concert/tree/65a0a009fb5726903ac02e018b7a250ff35e4f52))
- restore tab titles and hide tabs on startup
  ([670286e](https://github.com/seanthimons/concert/tree/670286eeafcf65f6744b17e0f24e4bd84a53e9ea))
- improve CSV reading robustness for messy datasets
  ([8befb08](https://github.com/seanthimons/concert/tree/8befb088ea36fb0794d531679b8208352186aa44))
- adjusted layout of cards.
  ([d779a6f](https://github.com/seanthimons/concert/tree/d779a6f524f123d875547a82d47771c3649b6929))

#### Refactorings

- slim generated replay scripts
  ([9df9181](https://github.com/seanthimons/concert/tree/9df91817c7b6783801a75d4c21aef60cbef1367c))
- migrate all tables from DT to reactable + reactable.extras
  ([e7d3984](https://github.com/seanthimons/concert/tree/e7d3984b7a53dc142f228e5453f586447be5868a))

#### Performance

- finish replay export optimization
  ([0cdae77](https://github.com/seanthimons/concert/tree/0cdae77ff746e899b8d816c2f6a4c2ee6fae6b8f))
- vectorize review-override capture for replay export
  ([d461394](https://github.com/seanthimons/concert/tree/d461394b94db066e64e38027874bba1ed4f7af30))
- vectorize + deduplicate curation results table
  ([b55038a](https://github.com/seanthimons/concert/tree/b55038a08f2104e3a9d912173e400968d3580a9e))
- address Codex performance findings
  ([90bc6b7](https://github.com/seanthimons/concert/tree/90bc6b7e748c27d14b3771d8aa77e6dcfa275267))
- incremental harmonization + ppx O(k²) fix
  ([5479718](https://github.com/seanthimons/concert/tree/5479718d1ad97794ebe90cf019d8d48252ae3f14))
- fix O(n²) list-growth in deduplicate_tagged_columns
  ([c489885](https://github.com/seanthimons/concert/tree/c4898856c3f24434c2539f82ecb4757217a2f44c))

#### Tests

- add extracted problem cases
  ([ee19a16](https://github.com/seanthimons/concert/tree/ee19a16a4906d36ebbc405f42299fef7d79ea963))
- record pending human verification
  ([aeb3b54](https://github.com/seanthimons/concert/tree/aeb3b54c53662c11d173ac1b0736a572c668bedd))
- record UAT findings — 2 issues (duplicate confidence column, broken
  search)
  ([bd72021](https://github.com/seanthimons/concert/tree/bd720217fa325cdb276383446ff4d5e30f1f5f24))
- persist human verification items as UAT
  ([2e45aa0](https://github.com/seanthimons/concert/tree/2e45aa0cd73966d679cdc11b8a382997eb278a8d))
- complete UAT - 7 passed, 0 issues
  ([5e62a0d](https://github.com/seanthimons/concert/tree/5e62a0d0ceff433e00bc9ebac776b54aad0cc987))
- persist human verification items as UAT
  ([3e59bb5](https://github.com/seanthimons/concert/tree/3e59bb560dca740aa75cfa1cabae57561fd43518))
- phase verification — 4/4 must-haves pass, human UAT pending
  ([d07ef24](https://github.com/seanthimons/concert/tree/d07ef24ec63a9f328e859ae254544d9f3e8c7ef2))
- update HUMAN-UAT after gap closure — 5 items pending re-verification
  ([a2856f6](https://github.com/seanthimons/concert/tree/a2856f6d27d65296300a8bde398323cae9533a90))
- persist UAT findings — 6 gaps diagnosed
  ([e9150e4](https://github.com/seanthimons/concert/tree/e9150e4bc5ada61c39b3a052e0ea17d7ee5fd7b8))
- complete UAT - 7 passed, 0 issues
  ([35a59f4](https://github.com/seanthimons/concert/tree/35a59f40bdb2224117e814d211ec47e99b6ca7cc))
- persist human verification items as UAT
  ([9203475](https://github.com/seanthimons/concert/tree/92034753ee8d6edced0da071386d3e5cb4bdf42d))
- persist human verification items as UAT
  ([1f3680c](https://github.com/seanthimons/concert/tree/1f3680c568e16f2de0316b056399e6749002aa7e))
- mark HUMAN-UAT complete — benchmark verified with real data
  ([ca6171e](https://github.com/seanthimons/concert/tree/ca6171e2baaecb1e0820d86eb2cfc9f6defccd15))
- update human verification items after toggle wiring
  ([66e3439](https://github.com/seanthimons/concert/tree/66e3439607dbded4e9da56899092a8e4073a9dc4))
- complete UAT - 6 passed, 0 issues, 1 skipped
  ([9960501](https://github.com/seanthimons/concert/tree/99605016a36d85a8b4ddf2c4158a3d66e222856f))
- persist human verification items as UAT
  ([38cce9d](https://github.com/seanthimons/concert/tree/38cce9d2e5f7fb7592ac5347b7c506743de674c6))
- post-hotfix UAT complete - 14/14 passed
  ([b67f9dc](https://github.com/seanthimons/concert/tree/b67f9dcc82e48f1928271267a48c4210642d86a4))
- complete UAT - 12 passed, 1 issue
  ([90e0775](https://github.com/seanthimons/concert/tree/90e0775ea22c79ff3869212bc47d7f863e4f1e21))
- partial UAT - blocking issue found
  ([0498d33](https://github.com/seanthimons/concert/tree/0498d33558330edd049d87db32f203d26742272a))
- persist human verification items as UAT
  ([78b93a8](https://github.com/seanthimons/concert/tree/78b93a868f014f90d094a0639158c513af1b37fd))
- complete UAT - 5 passed, 0 issues
  ([1b5899d](https://github.com/seanthimons/concert/tree/1b5899d38a002d3f866669c96b2ee3b2ae2e63ed))
- complete UAT - 6 passed, 0 issues
  ([e0707bd](https://github.com/seanthimons/concert/tree/e0707bd64f1da0679670c875e97281bce6604b4c))
- add guaranteed-error rows for unresolvable status testing
  ([59f548f](https://github.com/seanthimons/concert/tree/59f548f1031fa1d71e1423b4753c5236b6344d5b))
- complete UAT - 12 passed, 0 issues
  ([4b755f3](https://github.com/seanthimons/concert/tree/4b755f3224eef528722b4bdfccf3aa9aafe250cf))

#### CI

- configure git user for release tags
  ([48676a4](https://github.com/seanthimons/concert/tree/48676a438ca81c84f04016e931c1ac124901eed5))
- align release tags with package versions
  ([8af5291](https://github.com/seanthimons/concert/tree/8af529125ae215f4b790a896757c17a29b270157))
- separate package build from release bump
  ([204f8ce](https://github.com/seanthimons/concert/tree/204f8ce46cff78a39da02001d852dbbf03eec686))
- keep routine checks on release R
  ([8e688e4](https://github.com/seanthimons/concert/tree/8e688e48453a61aa72141f642725a39ccffba2c8))
- skip CRAN-only checks in routine workflows
  ([e3a6269](https://github.com/seanthimons/concert/tree/e3a6269d77ed93215b81cc958e96bb057e78eb65))
- install ComptoxR for R workflows
  ([9db4ba5](https://github.com/seanthimons/concert/tree/9db4ba59f955978898c387081362a3cd1f493989))
- release package after merged pull requests
  ([484b92e](https://github.com/seanthimons/concert/tree/484b92e4d0f6a50b2ebc8cae1e5c686b3b58744d))
- add gitleaks secret scanning
  ([5249d9d](https://github.com/seanthimons/concert/tree/5249d9dc86568d068ff3e5c3297536d0cda66307))

#### Docs

- add auto-tag analyte id bean
  ([4aa21e2](https://github.com/seanthimons/concert/tree/4aa21e287d0d4e65bbba4e6d14386be44be0117a))
- add Concert hex sticker assets
  ([5a4a86c](https://github.com/seanthimons/concert/tree/5a4a86ccb20537d87429da4832922dddc6b8037c))
- summarize row flagging execution
  ([6f29258](https://github.com/seanthimons/concert/tree/6f292581a37999d2f75d591585e698408710c732))
- create phase plan
  ([417562a](https://github.com/seanthimons/concert/tree/417562a3a8573224510c27fe93a6b7c2f69eeb18))
- capture row flagging context
  ([d8cb4a2](https://github.com/seanthimons/concert/tree/d8cb4a2c35ad4ccef5ab3c8f3b0b3da7f04856dc))
- pattern map and state update for auto-resolve & suggest
  ([14c6e5f](https://github.com/seanthimons/concert/tree/14c6e5f8ab8ecd924ae9f740ba038976c94677fd))
- create phase plan
  ([5f03961](https://github.com/seanthimons/concert/tree/5f039612faa7ff242868b64aaeb51f750716939b))
- UI design contract
  ([a5c5a2f](https://github.com/seanthimons/concert/tree/a5c5a2f30548b417ac4334267cb6aa83f1015234))
- UI design contract for auto-resolve & suggest phase
  ([a1c68f1](https://github.com/seanthimons/concert/tree/a1c68f11a41758f14fb10f2a5aea2688065c2853))
- record phase 50 context session
  ([5c43871](https://github.com/seanthimons/concert/tree/5c43871573b7e6ab875d38c94f50af3c46c74cfa))
- capture phase context
  ([51a5331](https://github.com/seanthimons/concert/tree/51a53318cca9ad102f254e9e3ba1e02e3945325d))
- update verification after NAMESPACE fix
  ([cc4cbbf](https://github.com/seanthimons/concert/tree/cc4cbbf5e36a41dcede67dccc73a12faa8e4c2e8))
- add code review report
  ([5b2fc70](https://github.com/seanthimons/concert/tree/5b2fc7026175a681be05161b6f9960d3d4782692))
- create phase plan
  ([92d7bb3](https://github.com/seanthimons/concert/tree/92d7bb3c973145dbb1ea2d77d9aa2f021d198080))
- research conflict scoring engine phase
  ([45361da](https://github.com/seanthimons/concert/tree/45361da87a79272358c6ac4d9a032fdd650a9494))
- record phase 49 context session
  ([aa56d12](https://github.com/seanthimons/concert/tree/aa56d12e50b5c638c97c4fcb7a62e044d467a838))
- capture phase context
  ([d6275dc](https://github.com/seanthimons/concert/tree/d6275dc550596aee3e6ccae2b440595fada95e7a))
- create milestone v2.3 roadmap (4 phases)
  ([246624c](https://github.com/seanthimons/concert/tree/246624cbf02209c0e0cb416be3e9cad3b9ccf814))
- define milestone v2.3 requirements
  ([20a485c](https://github.com/seanthimons/concert/tree/20a485cf5590e5276743c991671549f89d3e1572))
- start milestone v2.3 Curation Intelligence
  ([cdaa724](https://github.com/seanthimons/concert/tree/cdaa72496f50b9e708d4a4f2736474d297ae0cdc))
- update state after gap closure planning (5 plans)
  ([dceca9a](https://github.com/seanthimons/concert/tree/dceca9abc9574de8748d15136742359a49bebda7))
- create UAT gap closure plan for duplicate column + broken search
  ([57505b0](https://github.com/seanthimons/concert/tree/57505b0602b3a9e99b85d1b0d4a19cff2c46a7f4))
- re-verification — all 5 must-haves verified, human testing needed
  ([1423b8e](https://github.com/seanthimons/concert/tree/1423b8ebf1a9d45cabfbb61c57352d7fe4258b82))
- add code review report
  ([8f8c135](https://github.com/seanthimons/concert/tree/8f8c135b4805e502c3a5cb33ef38ff201a42de32))
- add gap closure plan 04 for CR-01, WR-02, WR-01, IN-02
  ([98b0c0d](https://github.com/seanthimons/concert/tree/98b0c0dccec93a559c2581cd92ed8c779ab8fdd8))
- create gap closure plan 04 for CR-01, WR-02, WR-01, IN-02 fixes
  ([802ad09](https://github.com/seanthimons/concert/tree/802ad09afaef9b590c58e226f2c706872e95834e))
- re-verification — gaps found from code review findings
  ([7f49594](https://github.com/seanthimons/concert/tree/7f49594dedee138c76bc24633957dbbfc7a160b1))
- add code review report
  ([7dbf523](https://github.com/seanthimons/concert/tree/7dbf523f7b8ea92526eccd25f9fb95e85a4b77cd))
- create gap closure plan for wqx_confidence propagation
  ([f541eac](https://github.com/seanthimons/concert/tree/f541eacc979acdd26b5e62e7cc059c0831bb1eae))
- add verification report — gaps found
  ([221a16e](https://github.com/seanthimons/concert/tree/221a16ed450e26aff9c675be77983736beb2cc3c))
- add code review report
  ([7dca181](https://github.com/seanthimons/concert/tree/7dca181844adad281fa5fc22a87a2a6a1c6350fb))
- add pattern map and update state for planning
  ([306e43a](https://github.com/seanthimons/concert/tree/306e43a79050e50486c27905d93fec0fac03bbaf))
- create phase plan
  ([05a830f](https://github.com/seanthimons/concert/tree/05a830f7accb2774ae1c6b830b2332a9f78259cc))
- research phase domain
  ([8d014d9](https://github.com/seanthimons/concert/tree/8d014d9b69ef68278ff0fc18139ce2d5f59623c9))
- UI design contract
  ([8c7c4a5](https://github.com/seanthimons/concert/tree/8c7c4a5a17a7dc4b5fce8a4369327bae6a81cefc))
- UI design contract
  ([bb45565](https://github.com/seanthimons/concert/tree/bb45565c0a6a24858dab0f750d054eedf1202e06))
- record phase 48 context session
  ([ae97940](https://github.com/seanthimons/concert/tree/ae9794047d1b6f23eab4a19dc5de85acc74a55bf))
- capture phase context
  ([6ba1102](https://github.com/seanthimons/concert/tree/6ba11022e4ee21098eb25bb0854247b1ac4f1f66))
- complete UAT and transition to Phase 48
  ([90c82e9](https://github.com/seanthimons/concert/tree/90c82e936dd937e3cca213e3bf60b073390dcf24))
- add phase verification (human_needed)
  ([a5aaea1](https://github.com/seanthimons/concert/tree/a5aaea189e40030bf63217c90054c0421a03fe6e))
- add code review (clean)
  ([cfe8d89](https://github.com/seanthimons/concert/tree/cfe8d89c3c10ca2f0037c508a1e7bc99718af858))
- add research, validation, patterns, and plans
  ([e9052bd](https://github.com/seanthimons/concert/tree/e9052bde51f85116142505dc6df98e11398e14ae))
- create phase plan (2 plans, 2 waves)
  ([43e71b7](https://github.com/seanthimons/concert/tree/43e71b7ef68ef6a15c64ad6167fc40ca1d0ae2ce))
- research pipeline reorder, threshold control, starts-with toggle
  ([097d6a7](https://github.com/seanthimons/concert/tree/097d6a74c26a0ba2023711fb0a127a489e4894a4))
- record phase 47 context session
  ([36f65d4](https://github.com/seanthimons/concert/tree/36f65d4143b584b1236d7696384eb2c57d1e9a27))
- capture phase context
  ([856bf02](https://github.com/seanthimons/concert/tree/856bf02785b5f0c458c5d07ce3511ede752e8b9f))
- create milestone v2.2 roadmap (2 phases)
  ([39f9bba](https://github.com/seanthimons/concert/tree/39f9bbac608d203a27d1c7770cd6a2b8f4bcabe9))
- define milestone v2.2 requirements
  ([71e1ed6](https://github.com/seanthimons/concert/tree/71e1ed6eb43c3e5048350624bff9dae8a24bc3f3))
- start milestone v2.2 WQX Pipeline Refinement
  ([adbb927](https://github.com/seanthimons/concert/tree/adbb927d034664b55ad99aba48a7587dd27f3cde))
- add code review report
  ([12f4fc1](https://github.com/seanthimons/concert/tree/12f4fc1ca8be31e265967aa76a70f800aa80949d))
- create phase plan for WQX UI display fixes
  ([406f040](https://github.com/seanthimons/concert/tree/406f040e8d4ceee9a1a1310be6f19a93d27373a1))
- add gap closure phases 46-47
  ([5e4f292](https://github.com/seanthimons/concert/tree/5e4f292b8ebd814ad95fbdfe6ba8cc79b706f374))
- add code review report
  ([a206988](https://github.com/seanthimons/concert/tree/a2069884e6a474e53728ba25434e640328af8f5b))
- create phase plan
  ([759abab](https://github.com/seanthimons/concert/tree/759ababc8a7696a3e4f3a7d2f6a5dfce131682d2))
- record phase 45 context session
  ([a6062c8](https://github.com/seanthimons/concert/tree/a6062c8884b2fc1982fe839cd1afd801d886101d))
- capture phase context
  ([cd5bee5](https://github.com/seanthimons/concert/tree/cd5bee5e79295f021d05ec8edbaf16519924b78f))
- add phase verification report
  ([2b20990](https://github.com/seanthimons/concert/tree/2b209900104f0697d7227843fe0e6416121a3dc9))
- add code review report
  ([ac1a101](https://github.com/seanthimons/concert/tree/ac1a101f6207f09e3ed650f5f5117aca997a70fb))
- plan matching engine prototype phase
  ([e722592](https://github.com/seanthimons/concert/tree/e7225928747078e674581760863f1ea88f125fa7))
- create phase plan — 2 plans, 2 waves
  ([18ecdf1](https://github.com/seanthimons/concert/tree/18ecdf1e8b7316fa77a9a96a2356b1b5ae41c52c))
- record phase 44 context session
  ([4c069dd](https://github.com/seanthimons/concert/tree/4c069dde50556e4184bf112c450199eb7ab86579))
- capture phase context
  ([2ea1fb8](https://github.com/seanthimons/concert/tree/2ea1fb892286a7ec70920803f0900ae56b447cd6))
- create phase plan for WQX dictionary
  ([bf6cf29](https://github.com/seanthimons/concert/tree/bf6cf29725e51bb0a8751146aea947faafeff3e0))
- research wqx dictionary phase domain
  ([76164c6](https://github.com/seanthimons/concert/tree/76164c660a20f2bb31a22c02727994ba347ee3d9))
- record phase 43 context session
  ([71b2cf1](https://github.com/seanthimons/concert/tree/71b2cf1df045d92cdea3af2ada524f241844ea24))
- capture phase context
  ([0ca807a](https://github.com/seanthimons/concert/tree/0ca807a691ed3a92a1d3f80d6407777602130355))
- create milestone v2.1 roadmap (3 phases)
  ([9bc1705](https://github.com/seanthimons/concert/tree/9bc1705c334df9a137f73a61e33733cd854229d8))
- define milestone v2.1 requirements
  ([ec5279e](https://github.com/seanthimons/concert/tree/ec5279e21c164c75b003c52f54e09806ada36d03))
- start milestone v2.1 WQX Parameter Harmonization
  ([1a879d0](https://github.com/seanthimons/concert/tree/1a879d0bd33d03bdb9ceadb6cfe3f5c10d4a10b7))
- add code review report
  ([3476ad5](https://github.com/seanthimons/concert/tree/3476ad5dcf730f4e69b0d8cc43ef87d9181aa28d))
- update state after gap closure planning
  ([718ec32](https://github.com/seanthimons/concert/tree/718ec32ee06cfd8542ad086d648255ef4611562f))
- create gap closure plans for 6 UAT gaps
  ([3a5a496](https://github.com/seanthimons/concert/tree/3a5a496c42353e8e40643ed82675e7d5eb2a3037))
- add research, patterns, and validation artifacts
  ([53297aa](https://github.com/seanthimons/concert/tree/53297aa4c22a96657ff4720b834d7f6475aab610))
- create phase plan — pre-flight modal + media editor
  ([ebf6bb7](https://github.com/seanthimons/concert/tree/ebf6bb772fc454113b89eae2fd35335845d675ca))
- UI design contract
  ([bb10be3](https://github.com/seanthimons/concert/tree/bb10be33181ad843abb3338d1a58408cc4facfb3))
- record phase 42 context session
  ([5e88a46](https://github.com/seanthimons/concert/tree/5e88a46c8f78668a55f6e76bf6aa951d9def4fce))
- capture phase context
  ([cff70b6](https://github.com/seanthimons/concert/tree/cff70b66e9636fa4b83b66e48b2658c6382edebd))
- add post-gap-closure code review report
  ([d60c93c](https://github.com/seanthimons/concert/tree/d60c93c4e8d1fbdbd9a785fc50ab03140ae74d4d))
- update STATE.md after gap-closure planning
  ([5ac5890](https://github.com/seanthimons/concert/tree/5ac5890ba8a747a7f33cf23e3f92c09a7464541c))
- create gap closure plan for pipeline wiring fixes
  ([4012baf](https://github.com/seanthimons/concert/tree/4012bafe4c6870b6076d030dc25edc3682e7a0a7))
- add code review report
  ([92a8675](https://github.com/seanthimons/concert/tree/92a8675868e3d72eb757e11997160ecbe0e7df4f))
- complete phase planning with D-19 dedup_step fix
  ([fa0c57a](https://github.com/seanthimons/concert/tree/fa0c57abbe1c1df92a2c113745db086d6e67fc06))
- create phase plan
  ([f717952](https://github.com/seanthimons/concert/tree/f717952ca730e033545c885892091ed436169fb6))
- record phase 41 context session
  ([741e4a0](https://github.com/seanthimons/concert/tree/741e4a0457708c6a04a9ee702823bc4ddae8c812))
- capture phase context
  ([ba1d52d](https://github.com/seanthimons/concert/tree/ba1d52db3d8cc2eb8577afba881348785ce98806))
- add code review report
  ([e6e9092](https://github.com/seanthimons/concert/tree/e6e9092c2409ec3ace047ad9fa16e8178e5a15aa))
- create phase plan — date parser
  ([f66b1a2](https://github.com/seanthimons/concert/tree/f66b1a27acc30c85e3edcc54b0f21355ba86a7d7))
- add validation strategy
  ([4c5e289](https://github.com/seanthimons/concert/tree/4c5e2899628495ce678d1f2fc564018864a977bf))
- research phase domain — lubridate date parsing
  ([69e823d](https://github.com/seanthimons/concert/tree/69e823d663c9d3ee4ca357ae84882d66d8118da1))
- fix typography contract to declare exactly 2 weights
  ([c556930](https://github.com/seanthimons/concert/tree/c5569300173e33c68d162f926fd8b312cf18d2bb))
- UI design contract
  ([5ac418c](https://github.com/seanthimons/concert/tree/5ac418ced5acd46846628502135b37afa520200b))
- record phase 40 context session
  ([a7e3785](https://github.com/seanthimons/concert/tree/a7e3785416e76fa80e8a52e907098909cfd216ec))
- capture phase context
  ([7de8177](https://github.com/seanthimons/concert/tree/7de817729cd76b04e3e0cdcb85f678f15f82fafd))
- add code review report
  ([e2937fa](https://github.com/seanthimons/concert/tree/e2937fac1d1be60f3da67c0b19f713342f56f915))
- create phase plan for duration conversion
  ([ba614a1](https://github.com/seanthimons/concert/tree/ba614a1f56b0226bf0aaadeed5544664fb22e8d1))
- add pattern mapping for duration conversion
  ([5a84c14](https://github.com/seanthimons/concert/tree/5a84c14f8aa087f885929cb7ae912e1b6c299516))
- research phase domain for duration conversion
  ([66f8e14](https://github.com/seanthimons/concert/tree/66f8e145b5666f37a66e011fcca238e9e28f1027))
- record phase 39 context session
  ([2ad8af7](https://github.com/seanthimons/concert/tree/2ad8af751ea755ee7e7cca7db6e923cd0051ee1f))
- capture phase context
  ([358459a](https://github.com/seanthimons/concert/tree/358459a16ea616f07a11b823298ed55963dc7010))
- populate benchmark results with real timing data
  ([86a1f43](https://github.com/seanthimons/concert/tree/86a1f43ee4ace2f3d74f1d198b7fcdc4cbd85eea))
- update verification after use_dedup toggle wiring
  ([1890ce5](https://github.com/seanthimons/concert/tree/1890ce56a89cf7d7c6abe15a3da21532b4871d2c))
- add code review report
  ([dbfbfe5](https://github.com/seanthimons/concert/tree/dbfbfe534b0de68cc52b198ec2cbe0ae0aebbdec))
- update state after replan — 1 plan, ready to execute
  ([6734a28](https://github.com/seanthimons/concert/tree/6734a28042e638f8710a00eda5b6f830822fcb4e))
- replan phase – 1 plan to wire use_dedup toggle bypass
  ([b1c6a65](https://github.com/seanthimons/concert/tree/b1c6a65d23ff4316ef9eb8f8be761c312b7b3908))
- add code review fix report
  ([91df9a0](https://github.com/seanthimons/concert/tree/91df9a05f0614136398cd2153fcdd763f3f42beb))
- create phase plan – 2 plans in 2 waves
  ([812f4e6](https://github.com/seanthimons/concert/tree/812f4e6c82367e61011817efe2a25902f1f85bfd))
- record phase 38 context session
  ([81997a1](https://github.com/seanthimons/concert/tree/81997a1e12396282b787f0af2ade65e287fd9292))
- capture phase context
  ([1db06e0](https://github.com/seanthimons/concert/tree/1db06e0794157ac3a22e47599da8f8eff9ac8c44))
- add pattern map and update state to planned
  ([917d7ed](https://github.com/seanthimons/concert/tree/917d7eda3f6829931d3d244183d7b790614776f1))
- create phase plan — 4 plans in 3 waves
  ([11031b6](https://github.com/seanthimons/concert/tree/11031b6bb793dead8655336a5decefd50ce993a0))
- record phase 37 context session
  ([edb9822](https://github.com/seanthimons/concert/tree/edb98227f19bb26f17ca032ffe7af595b063ebdc))
- capture phase context
  ([ec43abf](https://github.com/seanthimons/concert/tree/ec43abf3dca6b47ac62fc85b57dee8acf321b98d))
- create milestone v2.0 roadmap (6 phases)
  ([7ff9c61](https://github.com/seanthimons/concert/tree/7ff9c6194a46b2669482ab863f90abb5b46899d5))
- define milestone v2.0 requirements
  ([2b6f244](https://github.com/seanthimons/concert/tree/2b6f2447371f5f596a07e56ae522fece09bcbcca))
- v2.0 research — stack, features, architecture, pitfalls, summary
  ([86e1a25](https://github.com/seanthimons/concert/tree/86e1a258c90114bc8891a0f927118148e62b2ade))
- start milestone v2.0 Pipeline Performance & Date/Media Harmonization
  ([9c1f0a0](https://github.com/seanthimons/concert/tree/9c1f0a0a3009ca7805c31749dabb0042c4b3ecb9))
- add code review fix report
  ([7956ee8](https://github.com/seanthimons/concert/tree/7956ee8e27a6df0f74be491aee7f576f9724f360))
- add code review report
  ([aad3c8a](https://github.com/seanthimons/concert/tree/aad3c8aad9ffc48f67dc8120836ba9ff88c4c003))
- plan phase — wire ToxVal schema in Shiny path
  ([4c2c23c](https://github.com/seanthimons/concert/tree/4c2c23c537927e229381f31db267f12429e17234))
- create phase plan — wire ToxVal schema in Shiny path
  ([4a43847](https://github.com/seanthimons/concert/tree/4a438472f06ca7692ecc7ceb7172ff822d619597))
- record phase 36 context session
  ([78c62d4](https://github.com/seanthimons/concert/tree/78c62d445ab739a0e9e9b696e3d0f3a87799a6a2))
- capture phase context
  ([b53660a](https://github.com/seanthimons/concert/tree/b53660acc50edda5d4f5524b9f55eb688b4ca7ce))
- add gap closure Phase 36 — Wire ToxVal Schema in Shiny Path
  ([54fe8d5](https://github.com/seanthimons/concert/tree/54fe8d5aa0e22b76d51128eb1e23bee0ceab6da2))
- record phase 35 completion
  ([cfcb1b6](https://github.com/seanthimons/concert/tree/cfcb1b6823e5a8a2d923e44a27cb8cc084a500ed))
- UI design contract
  ([c9d90c1](https://github.com/seanthimons/concert/tree/c9d90c1301355055d79741e55ef6dbf426448049))
- record phase 35 planning completion
  ([1a684ec](https://github.com/seanthimons/concert/tree/1a684ecc402bbeb8ce7256fd78ad6f3e70e17ff7))
- create phase plans for export extension + headless
  ([6744060](https://github.com/seanthimons/concert/tree/67440606eb9c8781f037fda884727296d4427757))
- record phase 35 context session
  ([98be15e](https://github.com/seanthimons/concert/tree/98be15e85a40ac76f6cfe120d76b14b87cf72a9e))
- capture phase context
  ([7160e55](https://github.com/seanthimons/concert/tree/7160e554c7be6d201a4dc389b641ba374ff679bf))
- add gap-closure plan for cascade reset UX + perf
  ([8b56805](https://github.com/seanthimons/concert/tree/8b5680595db764a28d8ebf906de7533cc1947de4))
- diagnose UAT gap - modal reverted in working tree
  ([29d4f6b](https://github.com/seanthimons/concert/tree/29d4f6ba71f0b928f0794de457156ffa094d50e8))
- add harmonize pattern map and boot-test note
  ([d90a3af](https://github.com/seanthimons/concert/tree/d90a3af5355388ed447eac0d29d31b0ecb26dcb4))
- create phase plan
  ([390186e](https://github.com/seanthimons/concert/tree/390186e738a6a61ef87c19d75faf8d2e4a8f918e))
- add validation strategy
  ([f556988](https://github.com/seanthimons/concert/tree/f55698842c501df97a1b865a1cf099dc3c13a972))
- research phase domain
  ([4acbdf9](https://github.com/seanthimons/concert/tree/4acbdf9d358b840480bce7cc7b491191c39e38f9))
- fix UI-SPEC checker blocks and flag
  ([b4ac44c](https://github.com/seanthimons/concert/tree/b4ac44cd4a249b92fd028b95e8ba799efd14dc9d))
- UI design contract for Harmonize Tab Module
  ([abcbf5f](https://github.com/seanthimons/concert/tree/abcbf5fbcf1de61cb487bb77de0eb1fc8c1d2614))
- commit outstanding phase 31.5 artifacts and plan updates
  ([fa39243](https://github.com/seanthimons/concert/tree/fa3924322dabef3c9ec90255b8f8cd0b033db238))
- record phase 34 context session
  ([c0f40af](https://github.com/seanthimons/concert/tree/c0f40af44037bbc4a57e3ccf1bf2d69852523c01))
- capture phase context
  ([9f252fa](https://github.com/seanthimons/concert/tree/9f252fad771bbcc4d0d634c2a4a196b6a8be77c9))
- record phase 33 context session
  ([524fc80](https://github.com/seanthimons/concert/tree/524fc806f1b23cdf713f69a49e2c43b4b56fed5d))
- capture phase context
  ([d1777a5](https://github.com/seanthimons/concert/tree/d1777a57047a73c0814cff16951814e92386b999))
- create unit harmonization engine plan
  ([103fe47](https://github.com/seanthimons/concert/tree/103fe477cd110cf96a0001fe3790bcf1f38bf0b3))
- record phase 31 context session
  ([13bc9b6](https://github.com/seanthimons/concert/tree/13bc9b6d301a505b05d63f3ac4ac02a5edcafc2d))
- capture phase context
  ([255c620](https://github.com/seanthimons/concert/tree/255c6200bde1796ae908e57cdb9d7763c9b80aa9))
- create phase plan for numeric result parser
  ([d5896e0](https://github.com/seanthimons/concert/tree/d5896e09de9fadc8a6353d2c67532b4d3c1eaa98))
- record phase 30 context session
  ([1d8bc2e](https://github.com/seanthimons/concert/tree/1d8bc2efba807f8b59ca30d5f335dcd3f48f32c9))
- capture phase context
  ([c3a758a](https://github.com/seanthimons/concert/tree/c3a758ac7f6ffdd350fa982207b90fc3e30d47dd))
- create phase plans for static data foundations
  ([83a451e](https://github.com/seanthimons/concert/tree/83a451e43a6cd1c9d9f0980f2779ac424b384df3))
- record phase 29 context session
  ([f641bb7](https://github.com/seanthimons/concert/tree/f641bb779c80d9cdf82dea4105b081d25dae55d1))
- capture phase context
  ([b23dd79](https://github.com/seanthimons/concert/tree/b23dd79268d501cf53bf8fab738a0c9fbe395c7e))
- complete project research
  ([39ba0c2](https://github.com/seanthimons/concert/tree/39ba0c22ea99305c191c33faf8d9e772ceff05de))
- start milestone v1.9 Number and Unit Coercion Harmonization
  ([2f74608](https://github.com/seanthimons/concert/tree/2f7460823dbe650ad4649cfba578de0565fed9fb))
- fix key-count to 5 keys, clarify empty \_snaps deletion
  ([6994227](https://github.com/seanthimons/concert/tree/6994227174b3d8564981e9946cd4bb83006b2575))
- create phase plan
  ([bdcc238](https://github.com/seanthimons/concert/tree/bdcc23831aa950840e4669765881f5795ab3b431))
- complete phase - all HDL requirements verified via human UAT
  ([91c24b3](https://github.com/seanthimons/concert/tree/91c24b3fe9f5f971e2c163516edcad6e9c0d4c81))
- create phase plan
  ([35b77a2](https://github.com/seanthimons/concert/tree/35b77a2188e093e38f96bed06071c89473f495e1))
- add validation strategy
  ([9e605fb](https://github.com/seanthimons/concert/tree/9e605fb5bf744fb7545e854fc0aeab83af747e5d))
- research headless pipeline phase
  ([671aa14](https://github.com/seanthimons/concert/tree/671aa14ea0c7feff42f89c6e209bf93e37c43f38))
- record phase 27 context session
  ([71b40a6](https://github.com/seanthimons/concert/tree/71b40a6fbbcc00ed4b0c95ec0255b699a135ef68))
- capture phase context
  ([9548f7a](https://github.com/seanthimons/concert/tree/9548f7afa103eae581738dda67f4e60f86ff743d))
- create phase plan for app relocation
  ([8f587e2](https://github.com/seanthimons/concert/tree/8f587e28681917edc0c05e7d196894003879ae1c))
- create source file cleanup phase plan
  ([489f7ae](https://github.com/seanthimons/concert/tree/489f7aebbbc546613181d0972c8e1e95d03e9fb2))
- record phase 25 context session
  ([366ddd2](https://github.com/seanthimons/concert/tree/366ddd2198e741c320116568fa633841692209ec))
- capture phase context
  ([5a1439b](https://github.com/seanthimons/concert/tree/5a1439b4037d82d15f8d7aeaef589ca7b6ce73d1))
- create phase plan
  ([bf74a57](https://github.com/seanthimons/concert/tree/bf74a57044005e53f1c8b50d28b09c35c70afe1a))
- research phase package-scaffolding
  ([06ee34b](https://github.com/seanthimons/concert/tree/06ee34bf352db641e86ebffaca0229b4ce069035))
- create milestone v1.8 roadmap (5 phases)
  ([743ec68](https://github.com/seanthimons/concert/tree/743ec68c3617ffe5ca8281d7adb7bb4cd3f22384))
- define milestone v1.8 requirements
  ([07ad905](https://github.com/seanthimons/concert/tree/07ad9058cc75003bf7f7e2d9f07b892acf52fe12))
- start milestone v1.8 R Package Migration
  ([b2df1da](https://github.com/seanthimons/concert/tree/b2df1dacdafdd48fe31dc17b074f6eb11953c5ab))
- v1.7 milestone audit — tech_debt status, 8/8 requirements satisfied
  ([8719db9](https://github.com/seanthimons/concert/tree/8719db9775ec94e07efd7527ec973f12a9fd3323))
- create phase plan — 2 plans for isotope cleaning, chiral protection,
  multi-analyte flagging
  ([d9c4035](https://github.com/seanthimons/concert/tree/d9c4035370e7ef18b91f6c8159d0a31a4a78dbf9))
- create phase plan
  ([e18c3bb](https://github.com/seanthimons/concert/tree/e18c3bb97465b7c554ddcba7f1622890452fc08d))
- UI design contract for Phase 22 UI Polish
  ([7e52983](https://github.com/seanthimons/concert/tree/7e5298331f26f40b6c966e3d35a2041a1ae56122))
- research phase domain
  ([5522652](https://github.com/seanthimons/concert/tree/55226522ceeffb0c5c8ae15c665eff82cdeefb94))
- record phase 22 context session
  ([fc404b1](https://github.com/seanthimons/concert/tree/fc404b133627c856e1055b158541d7d518a6cb12))
- capture phase context
  ([6d8ec2e](https://github.com/seanthimons/concert/tree/6d8ec2eddcde54defd321ee3a38a1bd31f188e8e))
- create milestone v1.7 roadmap (2 phases)
  ([34d7fdf](https://github.com/seanthimons/concert/tree/34d7fdf910b1f5871a094787ce5b378b19743bfa))
- define milestone v1.7 requirements
  ([f5feb36](https://github.com/seanthimons/concert/tree/f5feb364cc3be213cecf682399345fe78e3f63e4))
- start milestone v1.7 UI Polish & Isotope Cleaning
  ([53a7f02](https://github.com/seanthimons/concert/tree/53a7f0235ca63eb2bb4b20198ebab2bfedb452c8))
- update retrospective for v1.6
  ([2b70334](https://github.com/seanthimons/concert/tree/2b7033430fe47058a0e13515e19b902f0e63db8c))
- create phase plan
  ([259dacf](https://github.com/seanthimons/concert/tree/259dacfebde0e682779ae052886c3ed6a756889c))
- record phase 21 context session
  ([0c2d0d9](https://github.com/seanthimons/concert/tree/0c2d0d9958c3e11433f2230e0da461585055122e))
- capture phase context
  ([70fe6c5](https://github.com/seanthimons/concert/tree/70fe6c59e6ab56efa4aded49ad702bd97a4a175d))
- create phase plan for roman numeral handling
  ([e13dba9](https://github.com/seanthimons/concert/tree/e13dba9c7097882dfd7cbbad04e66cbd4a69945a))
- record phase 20 context session
  ([2f1fa5f](https://github.com/seanthimons/concert/tree/2f1fa5fbe046c8df2883ce9701dc502cb68af515))
- capture phase context
  ([dd09ac4](https://github.com/seanthimons/concert/tree/dd09ac404d0e4f9c15816b91a1124af4f21c5f18))
- create phase plan
  ([5bdc3eb](https://github.com/seanthimons/concert/tree/5bdc3eb7e8544ce169387b18db73d892c3b61806))
- record phase 19 context session
  ([63b4da9](https://github.com/seanthimons/concert/tree/63b4da9c3bdafa18918ce30e3fec436857599e54))
- capture phase context
  ([9ac0d5f](https://github.com/seanthimons/concert/tree/9ac0d5f2ef41617bf38b3937b0d09a03626cda49))
- create milestone v1.6 roadmap (3 phases)
  ([e7e3a3f](https://github.com/seanthimons/concert/tree/e7e3a3fdf219d24a2691322f77f0d0f2d6872c32))
- define milestone v1.6 requirements
  ([e9afbc6](https://github.com/seanthimons/concert/tree/e9afbc6aa28ecc4ba96d66d22335935ad343088c))
- start milestone v1.6 Cleaning Ruleset Fixes
  ([685e3da](https://github.com/seanthimons/concert/tree/685e3daf79c79ce0bc2d7f061c8b2e2494230bbf))
- create phase plan for comparison modal UI
  ([dc6a73d](https://github.com/seanthimons/concert/tree/dc6a73d152cb8001262fee8a8c26454cb6415bbb))
- capture phase context
  ([1b8d20d](https://github.com/seanthimons/concert/tree/1b8d20de071c423d7b30686a808ca73eb56ee382))
- create phase plan for enrichment pipeline
  ([ad6cd33](https://github.com/seanthimons/concert/tree/ad6cd330f7cc8407af20aa465246f63fd0bdae99))
- capture phase context
  ([9ca25fc](https://github.com/seanthimons/concert/tree/9ca25fcf3f004e36086b55e62a5d207e6b557fba))
- update retrospective for v1.4
  ([4943938](https://github.com/seanthimons/concert/tree/4943938f097f2f3a1ce0d29870fd75a2208c27a2))
- create phase plan for cleaning pipeline bug fixes
  ([481f837](https://github.com/seanthimons/concert/tree/481f8376710a811fbd559dfe9de3971d016a9d91))
- create milestone v1.4 roadmap (1 phase)
  ([34506b4](https://github.com/seanthimons/concert/tree/34506b4ae372f90e90e12ac9afb657351beaa37e))
- define milestone v1.4 requirements
  ([cfd87cb](https://github.com/seanthimons/concert/tree/cfd87cb1eef0b0f256762c56b24f64cd21f484bf))
- start milestone v1.4 Cleaning Pipeline Fixes
  ([8bcf1e4](https://github.com/seanthimons/concert/tree/8bcf1e4973795a72c861efb87eda1ade5dbc743f))
- close v1.3 milestone audit gaps
  ([1dd57a5](https://github.com/seanthimons/concert/tree/1dd57a5816b3dc676d752b53b9a2a5b223a7b48c))
- create gap closure plan for icon fix and POST-01 documentation
  ([dc3c1e0](https://github.com/seanthimons/concert/tree/dc3c1e0bf867df01a3926a1c7a3f9774abde027b))
- create phase plan for post-curation QC
  ([5a365b8](https://github.com/seanthimons/concert/tree/5a365b8bacb2e554a01d0f619b78a372c846b549))
- add research and validation strategy
  ([358e99e](https://github.com/seanthimons/concert/tree/358e99e64ad1bd403a97a89dbe8759b85c5a0e88))
- research phase domain
  ([581f634](https://github.com/seanthimons/concert/tree/581f634635f8428d5c14ad57e8533c77bc4ad34e))
- record phase 15 context session
  ([493153c](https://github.com/seanthimons/concert/tree/493153cfe4a7142c2eb599498ce329822dd53672))
- capture phase context
  ([dc2bb95](https://github.com/seanthimons/concert/tree/dc2bb950ef8bbe53c2fe3ab5a2910ec9ba87c777))
- add Phase 14 UAT findings to TODO
  ([8359f68](https://github.com/seanthimons/concert/tree/8359f681d7bd5e1c1da42a5db2215f8e13186686))
- create phase plan for multi-sheet export and re-import
  ([3b853d5](https://github.com/seanthimons/concert/tree/3b853d580093711b365d055358d176b475ea4a7f))
- research phase domain
  ([b42be48](https://github.com/seanthimons/concert/tree/b42be484725f1b14cfc415e397155ff3d175bc73))
- record phase 14 context session
  ([c02e507](https://github.com/seanthimons/concert/tree/c02e50727cc2a39970da09830fff81ae18231b97))
- capture phase context
  ([6515a45](https://github.com/seanthimons/concert/tree/6515a45fbd8e84fc145f804d6fc14f2a8a6ada35))
- create phase plan for reference filters and editable lists
  ([1b594f4](https://github.com/seanthimons/concert/tree/1b594f4b4c08de7e0a5079cc2e0f0aa7fc011cc6))
- research reference filters and editable lists
  ([eebefd6](https://github.com/seanthimons/concert/tree/eebefd65b76704569bb060ce724fb266a3af5eef))
- record phase 13 context session
  ([d23293a](https://github.com/seanthimons/concert/tree/d23293ad15af60a02edb4b717ade54ad3e3f9254))
- capture phase context
  ([30be772](https://github.com/seanthimons/concert/tree/30be7724cb0b71c20844dd7dd829288f18c85722))
- mark phase 12 complete, update state and roadmap
  ([ba5a955](https://github.com/seanthimons/concert/tree/ba5a955b5c6e612b1d5cc6c87b4a24723a31dd43))
- create phase plan for name cleaning
  ([995c644](https://github.com/seanthimons/concert/tree/995c6440d430327bd213424abf5a5977d57ed16b))
- add research and validation strategy for name cleaning
  ([90fdeb7](https://github.com/seanthimons/concert/tree/90fdeb74c7ba9c4c11701b389a38a42cc93688fb))
- research name cleaning domain
  ([56abb53](https://github.com/seanthimons/concert/tree/56abb53d990349d4692168c772d1bf3b40f1eda5))
- record phase 12 context session
  ([be3abcf](https://github.com/seanthimons/concert/tree/be3abcfb07bd27afd7c08c557bb2314db5159c4e))
- capture phase context for name cleaning
  ([f73a517](https://github.com/seanthimons/concert/tree/f73a51773bb85acbc9077d0f82cdb069420a39de))
- advance to Phase 12 after Phase 11 completion
  ([23b52b2](https://github.com/seanthimons/concert/tree/23b52b29de7e5ea9408a7e992636375611ff4d0b))
- create phase plan for CAS pipeline
  ([059b935](https://github.com/seanthimons/concert/tree/059b9355a41a5aaad41ce7e9a92a4c84f006733c))
- add research and validation strategy for CAS pipeline
  ([0688e24](https://github.com/seanthimons/concert/tree/0688e245b32e32da5b1b860b96a48718dcfb63f8))
- research CAS pipeline domain
  ([140506f](https://github.com/seanthimons/concert/tree/140506f8e63c6378333d6e89aed9c8b2740a18a0))
- update state after context gathering
  ([920a4b4](https://github.com/seanthimons/concert/tree/920a4b484c17a4bf1fa05d1a84fb8d1f3a15d63c))
- capture phase context for CAS pipeline
  ([214aeb0](https://github.com/seanthimons/concert/tree/214aeb059f8a3e70387d23a89ec575c6790793c3))
- create phase plan for foundation and clean data tab
  ([8e3ed45](https://github.com/seanthimons/concert/tree/8e3ed4533727725809c6f9f7b23023db0f5dc839))
- record phase 10 context session
  ([b9893a9](https://github.com/seanthimons/concert/tree/b9893a9082527c0c1f267e5d5b54474d5198719a))
- capture phase context
  ([59f185d](https://github.com/seanthimons/concert/tree/59f185d028f4d99d206e2a9e5e315874bf3b15b4))
- create phase plan
  ([71756e2](https://github.com/seanthimons/concert/tree/71756e285a947906b1024b1d73a7ecbac2168c2b))
- research phase domain
  ([950ac7b](https://github.com/seanthimons/concert/tree/950ac7bd968e09f34cca980d4d463cf896815023))
- capture phase context
  ([5bdf463](https://github.com/seanthimons/concert/tree/5bdf463698413d094be1008f021c4aa7f5d37208))
- create milestone v1.3 roadmap (7 phases, 30 requirements)
  ([d7fbfca](https://github.com/seanthimons/concert/tree/d7fbfca28ddad17946953acf2b2724451da58e4c))
- define milestone v1.3 requirements (30 requirements)
  ([5e4942d](https://github.com/seanthimons/concert/tree/5e4942d6b1d9c71ca0f3e82e77cdd40950242c2b))
- complete project research
  ([2299190](https://github.com/seanthimons/concert/tree/22991908114a051af3c5ac868df27a3ea7b51028))
- start milestone v1.3 Data Cleaning Pipeline
  ([4351e9c](https://github.com/seanthimons/concert/tree/4351e9c11d12850710ec8ec4c9a2b6f32e4dcca4))
- complete UAT — all 10 tests passed
  ([ca076a2](https://github.com/seanthimons/concert/tree/ca076a24c375cd3a2b3c0c0633d0761c55e72e5c))
- complete phase research and planning
  ([e16336e](https://github.com/seanthimons/concert/tree/e16336ed23cf0cc0bb36427d7b49dce0b78ef8ca))
- create phase plan
  ([16a131f](https://github.com/seanthimons/concert/tree/16a131f82458264c0a687985f8d1042dab84fb10))
- research phase domain
  ([12c93b9](https://github.com/seanthimons/concert/tree/12c93b9ef81decc77acd06f8c9aa0a661568b583))
- complete phase execution and verification
  ([3648c09](https://github.com/seanthimons/concert/tree/3648c095c0443fd21e63799eee95f55a25710610))
- create phase plan
  ([f40ba70](https://github.com/seanthimons/concert/tree/f40ba70b9f056f4e7a4ad3e7c75876aa3b2fc445))
- research phase domain
  ([999cecd](https://github.com/seanthimons/concert/tree/999cecde935b73d34622e582ad0923dd61df74ab))
- capture phase context
  ([cda5e6a](https://github.com/seanthimons/concert/tree/cda5e6a48ae646fd2a4f005e7113f80a96067fec))
- complete Phase 6 → Phase 7 transition
  ([8ca03b9](https://github.com/seanthimons/concert/tree/8ca03b96b79769a05461251f498c39455eb02bf4))
- create phase plan
  ([3a8c401](https://github.com/seanthimons/concert/tree/3a8c40118f13688c63b8f5a3778cb87e83c792e2))
- research search pipeline refinement
  ([e513c84](https://github.com/seanthimons/concert/tree/e513c843bdf1bcb40fbbda4a573ae19e87cbd2c5))
- capture phase context
  ([04104b6](https://github.com/seanthimons/concert/tree/04104b677c7e0cc536322dc8e835bda80b4e03c3))
- create milestone v1.2 roadmap (3 phases)
  ([330299f](https://github.com/seanthimons/concert/tree/330299f537be82737f13d4534b436457cbc27062))
- define milestone v1.2 requirements
  ([baaffc3](https://github.com/seanthimons/concert/tree/baaffc36078df2bf96d5ed827472b2535eaf89c1))
- complete v1.2 project research
  ([c381fea](https://github.com/seanthimons/concert/tree/c381fea3d6534b93810aa8219d925b952b3e6ea6))
- start milestone v1.2 Curation Refinement
  ([5bbb42d](https://github.com/seanthimons/concert/tree/5bbb42d31349c510c2781d9c77e8bf62167da66c))
- capture todos - table column visibility and resolution dropdown
  context
  ([23c8798](https://github.com/seanthimons/concert/tree/23c8798764e4c28183162225187e3e950d22af5c))
- create phase 5 shiny integration plans
  ([c3aecc8](https://github.com/seanthimons/concert/tree/c3aecc89af333941c624dc9a54b38a075e408bbc))
- capture phase context
  ([1d457c8](https://github.com/seanthimons/concert/tree/1d457c8b11eb16e93aa2e32731e634ffecfe1bb2))
- create phase plans for consensus logic
  ([67d23f4](https://github.com/seanthimons/concert/tree/67d23f4a00fbff0fe95a80deede37e6fddd827e7))
- capture phase context
  ([487eff8](https://github.com/seanthimons/concert/tree/487eff8b0d06c8cd39592d58faa1880d7c70a430))
- create phase plan
  ([bb00658](https://github.com/seanthimons/concert/tree/bb0065882c396b4b448c316f287986f8d6f5662e))
- capture phase context
  ([da75334](https://github.com/seanthimons/concert/tree/da75334dd523192fac048547eebb6b116048f793))
- create milestone v1.1 roadmap (3 phases)
  ([e092e87](https://github.com/seanthimons/concert/tree/e092e875ca1fd1c4fcbad22f2aa85874eff99e33))
- define milestone v1.1 requirements
  ([e76966e](https://github.com/seanthimons/concert/tree/e76966e13600991737858564a5c807c01d630b9b))
- start milestone v1.1 Curation Process Update
  ([086af8c](https://github.com/seanthimons/concert/tree/086af8c488a7482a18773e8ed541da46053ef9e5))
- create phase plan for gated navigation
  ([a0f2bd6](https://github.com/seanthimons/concert/tree/a0f2bd608e15c7c2d83f5cb182f1fd9a20ad0a51))
- research phase domain
  ([8f926fb](https://github.com/seanthimons/concert/tree/8f926fb848e0f8cdcaa8e12b4609f847f0e00395))
- record phase 2 context session
  ([a1e192e](https://github.com/seanthimons/concert/tree/a1e192e6541c76b52939ef25512a34c7fb446c0e))
- capture phase context
  ([89b0f0c](https://github.com/seanthimons/concert/tree/89b0f0cef3f68a3f5696713e0e27614626e03a74))
- record phase 1 context session
  ([d5ef9e4](https://github.com/seanthimons/concert/tree/d5ef9e407bd6394ec072ee60598335841421bf7b))
- capture phase context
  ([53d2826](https://github.com/seanthimons/concert/tree/53d2826f557b3d26a9636cd24cc4da4350ca7b44))
- complete project research
  ([f248694](https://github.com/seanthimons/concert/tree/f248694b073978118acd78d8e456d2aa9fd6fb0a))

#### Style

- apply air formatting and jarl fixes to review module
  ([259f5fa](https://github.com/seanthimons/concert/tree/259f5fa45118e79e0d19de02792a8cb065882a74))

#### Other changes

- remove dead replay helper functions
  ([d21de62](https://github.com/seanthimons/concert/tree/d21de62b3a6b20d6d174629ec5256a0cba80c9d6))
- record current repository state
  ([aac8267](https://github.com/seanthimons/concert/tree/aac826792b9fb5b360630d1760d8d4dc161d9c46))
- merge executor worktree (worktree-agent-a3db1caf)
  ([bc66f49](https://github.com/seanthimons/concert/tree/bc66f49291e86380f4a005dd54ac400838a7ac2b))
- complete v2.2 milestone close
  ([8aa90df](https://github.com/seanthimons/concert/tree/8aa90df807b5b134b9d99fd3c943de3446477891))
- archive v2.2 milestone files
  ([01c4ba4](https://github.com/seanthimons/concert/tree/01c4ba4812157c68eaf5fcb96f91b384457d9ab8))
- remove REQUIREMENTS.md for v2.1 milestone
  ([5fc413f](https://github.com/seanthimons/concert/tree/5fc413fcbb4418f614634f35ffe45c535e38259c))
- archive v2.1 milestone files
  ([c760ae9](https://github.com/seanthimons/concert/tree/c760ae94a3fb43de29ed0da9dee5cadb20eb930b))
- merge executor worktree (worktree-agent-a6008678)
  ([f681ff2](https://github.com/seanthimons/concert/tree/f681ff242f39462c8f9f94f16008c2ed25fbebe4))
- archive v2.0 phase directories to milestones/
  ([eeb0b26](https://github.com/seanthimons/concert/tree/eeb0b261c73b3dd391044946d84760b85715bc9c))
- remove REQUIREMENTS.md for v2.0 milestone
  ([8d542e2](https://github.com/seanthimons/concert/tree/8d542e2262f5edb82fc229990e77dbf5849e7de5))
- archive v2.0 milestone files
  ([d8d01e1](https://github.com/seanthimons/concert/tree/d8d01e1847c281276b9da93c2520c59f62418f7b))
- merge plan 42-05 gap closure (pre-flight progress + completion
  summary)
  ([5f2a0d2](https://github.com/seanthimons/concert/tree/5f2a0d27ae6777cacccdd5914bb07e9f8cfb3c97))
- merge executor worktree (worktree-agent-a96aa76b)
  ([ac21f75](https://github.com/seanthimons/concert/tree/ac21f752218b7c028003fe66785d99419a8a7d0e))
- merge executor worktree (worktree-agent-ad6dd37b)
  ([0f3cb58](https://github.com/seanthimons/concert/tree/0f3cb5817e78e58dcc34cef191d75ebe24f6bf7a))
- merge executor worktree (worktree-agent-a9523e93)
  ([1dc8c59](https://github.com/seanthimons/concert/tree/1dc8c595f31ec2295f307694fb75adecead27fda))
- remove embedded curation repo and add to gitignore
  ([5195e9f](https://github.com/seanthimons/concert/tree/5195e9f97db1b3132f7f612b72bae5d4aa89a1b5))
- merge Phase 37 worktree (Plans 02-04) into main
  ([9e8c8cb](https://github.com/seanthimons/concert/tree/9e8c8cbfc8cf5a53d1470e1fec812bc2e378a877))
- merge executor worktree (worktree-agent-ace47a41)
  ([e1cd70a](https://github.com/seanthimons/concert/tree/e1cd70a8c01c89ec111f53fb3f001a68640b96b7))
- track .beans/ files in git
  ([eb72a07](https://github.com/seanthimons/concert/tree/eb72a0765b61b6eda88acd766699523af257db2f))
- migrate TODO.md to beans + GitHub Issues
  ([cef9e60](https://github.com/seanthimons/concert/tree/cef9e60b1947fb37d4feac77f4c6e090c2ba0e5a))
- add planning docs, test data, and update gitignore
  ([e5bc4b8](https://github.com/seanthimons/concert/tree/e5bc4b841029ff42ec36526c2afddbf191f1a22a))
- archive v1.8 R Package Migration milestone
  ([d531bcd](https://github.com/seanthimons/concert/tree/d531bcd785e8fcbd0146f6cfeaa8a758d52be56f))
- archive v1.7 phase directories to milestones/v1.7-phases/
  ([0f999b4](https://github.com/seanthimons/concert/tree/0f999b4c0671b906edcc4c0efb8adf5d8711b1dc))
- archive v1.7 milestone — UI Polish & Isotope Cleaning
  ([8525b72](https://github.com/seanthimons/concert/tree/8525b72dc4443efe342f1f2e8b2c1c5c4432d023))
- complete v1.6 milestone
  ([cca3b71](https://github.com/seanthimons/concert/tree/cca3b7188d99ecbe51dd6a6e6d74ee936c1f4ef6))
- complete v1.5 milestone — archive and cleanup
  ([be7e3d2](https://github.com/seanthimons/concert/tree/be7e3d28999b9dd222967ff2a088bf2b2c29baf8))
- complete v1.4 milestone — archive and cleanup
  ([0db15ad](https://github.com/seanthimons/concert/tree/0db15ada6bcdf9be4992cc9a9e946731a83cb09b))
- archive v1.3 phase directories to milestones/
  ([abfb745](https://github.com/seanthimons/concert/tree/abfb745c5de451ecd6a47d75db1bbd5fdf64bb8d))
- complete v1.3 Data Cleaning Pipeline milestone
  ([c45765e](https://github.com/seanthimons/concert/tree/c45765ed15be147d822eba92e8f2e13d8f10c0dc))
- complete v1.2 milestone
  ([a1bbc28](https://github.com/seanthimons/concert/tree/a1bbc28e0d4fdfa32dece4303752dcc1b287fedd))
- complete v1.1 milestone — archive and retrospective
  ([fcde8a2](https://github.com/seanthimons/concert/tree/fcde8a206a75ae9c7dc9ca9250a944ef70e0bc7b))
- complete v1.0 milestone
  ([6d2cbba](https://github.com/seanthimons/concert/tree/6d2cbbac10c01e482b411c0f5769275f8dd2eee8))

Full set of changes:
[`48a0046...v0.1.1`](https://github.com/seanthimons/concert/compare/48a0046...v0.1.1)
