


## concert 0.6.10 (2026-11-11)

#### Bug fixes

- retry unresolved CAS aliases with ComptoxR 4.0.3 (#145)
  ([001bd17](https://github.com/seanthimons/concert/tree/001bd17f4ed569f138ea5dcb4b8faf3e1c9c91c1))

#### Other changes

- bump version to 0.6.10 \[skip ci\]
  ([ade995f](https://github.com/seanthimons/concert/tree/ade995f02915ea6ec3796c527ad7762932fa2c01))

Full set of changes:
[`v0.6.9...v0.6.10`](https://github.com/seanthimons/concert/compare/v0.6.9...v0.6.10)

## concert 0.6.9 (2026-11-05)

#### Bug fixes

- handle environmental unit gaps (#142)
  ([83bd19c](https://github.com/seanthimons/concert/tree/83bd19c672b3ea5177bf385fdd44eaf75625fe03))

#### Docs

- update NEWS.md for v0.6.9 \[skip ci\]
  ([ef90987](https://github.com/seanthimons/concert/tree/ef90987724c7986a706b27f1d5d6954a41ae155b))
- index new synonym and bulk-audit helpers
  ([60fe748](https://github.com/seanthimons/concert/tree/60fe748b6a07edce026f5fbe1f2d7e96116ab2dd))

#### Other changes

- bump version to 0.6.9 \[skip ci\]
  ([1320cbc](https://github.com/seanthimons/concert/tree/1320cbcd412b13773594fc43123e5ff18e3c4378))

Full set of changes:
[`v0.6.8...v0.6.9`](https://github.com/seanthimons/concert/compare/v0.6.8...v0.6.9)

## concert 0.6.8 (2026-11-04)

#### New features

- add Synonym tag for per-row synonym-list evidence
  ([bc6e86b](https://github.com/seanthimons/concert/tree/bc6e86bd4d7b0e18a028477851615535c307acd7))
- audit bulk-accepted pins against current identity holds
  ([b96b05e](https://github.com/seanthimons/concert/tree/b96b05e0a0f3ab3e2ba84f9d3fc771f9a9c6f1af))

#### Bug fixes

- stop fuzzy tier crossing isomers and compounds
  ([d191339](https://github.com/seanthimons/concert/tree/d191339ead570edd21ce0ae5db67d52ff8841055))

#### Tests

- validate expanded re-tag choices across line breaks
  ([6ecc81e](https://github.com/seanthimons/concert/tree/6ecc81e70119b54d56d2cbc72dd936434a98892f))

#### CI

- update R actions for current Ubuntu sudo
  ([2eaaa36](https://github.com/seanthimons/concert/tree/2eaaa36c81981036494f971bede03d3d38775ef3))

#### Docs

- update NEWS.md for v0.6.8 \[skip ci\]
  ([1bf6c4d](https://github.com/seanthimons/concert/tree/1bf6c4d6ec5622d146b13d957d27f68e2ef40433))

#### Other changes

- bump version to 0.6.8 \[skip ci\]
  ([95ef07a](https://github.com/seanthimons/concert/tree/95ef07a310d3f299b245e79dfc5b22fb0dc19b55))

Full set of changes:
[`v0.6.7...v0.6.8`](https://github.com/seanthimons/concert/compare/v0.6.7...v0.6.8)

## concert 0.6.7 (2026-10-30)

#### New features

- flag measurement qualifiers and hold fraction-qualified nutrients
  ([f2c8ba1](https://github.com/seanthimons/concert/tree/f2c8ba1bd3ca271822c1b47c4ab96f166f8c3077))

#### Bug fixes

- use standard Comptox detail projection
  ([7a3ebaf](https://github.com/seanthimons/concert/tree/7a3ebafab7f8bfcce031fe048118256076374ced))
- gate the priority chain and normalise consensus_source
  ([646f08e](https://github.com/seanthimons/concert/tree/646f08e8dc35be367e347aefae3df07675ae973e))
- priority chain skips rows held by classify_auto_resolve
  ([337e029](https://github.com/seanthimons/concert/tree/337e029965a4e256cebfa191f8c39bf52eeb7ab3))
- clear stale “held:” resolution reasons
  ([1f168cf](https://github.com/seanthimons/concert/tree/1f168cf2660e09bf5d9d829c3b3faaf8240af46a))
- score the unsuffixed dtxsid column on its own preferredName and rank
  ([319316b](https://github.com/seanthimons/concert/tree/319316b1cd24f60339b4e01d3a23dfe767ca61ef))
- hold WQX-conflict and name-drift rows in classify_auto_resolve
  ([6a6f0a5](https://github.com/seanthimons/concert/tree/6a6f0a56f689f42c91f3e10bdb045883de625731))

#### Tests

- cover v4 fields and projection override
  ([89ccd7f](https://github.com/seanthimons/concert/tree/89ccd7f067aa0929bdebfbbcb934d2ae9138c9a0))

#### CI

- restore locked-review from the lockfile snapshot, not public RSPM
  ([46d5598](https://github.com/seanthimons/concert/tree/46d5598e660f150bcab3774374db4a6071f096e8))

#### Docs

- update replacement v0.6.7 release notes \[skip ci\]
  ([7e9673c](https://github.com/seanthimons/concert/tree/7e9673c3b4daef17b1648a50d2de08f7d8a17b9e))
- update NEWS.md for v0.6.7 \[skip ci\]
  ([585f088](https://github.com/seanthimons/concert/tree/585f088ef1324147aa8218a5822f40b8becbf836))
- add harmonize_methodology to pkgdown reference index
  ([268f838](https://github.com/seanthimons/concert/tree/268f83898e99ca8be62e4844f5952daaa30e61b7))

#### Other changes

- remove retired planning and development artifacts \[skip ci\]
  ([18ee6fc](https://github.com/seanthimons/concert/tree/18ee6fcd79e3ff08f52fedf6a5355a72412ea656))
- migrate API calls to v4
  ([9242b55](https://github.com/seanthimons/concert/tree/9242b557ae43a7f763a4c15969a8e2fce09809eb))
- bump version to 0.6.7 \[skip ci\]
  ([3efcc62](https://github.com/seanthimons/concert/tree/3efcc62f56401d0b44200c7c8ea2bc5bc807e092))

Full set of changes:
[`v0.6.6...v0.6.7`](https://github.com/seanthimons/concert/compare/v0.6.6...v0.6.7)

## concert 0.6.6 (2026-10-16)

#### Docs

- update NEWS.md for v0.6.6 \[skip ci\]
  ([2b99609](https://github.com/seanthimons/concert/tree/2b996096077b85ef7857da1948c46254a0786151))
- document ComptoxR pin, API key setup and deployment security
  ([c2f6205](https://github.com/seanthimons/concert/tree/c2f6205ad029232d44993c751f6711faaa0d63db))

#### Other changes

- bump version to 0.6.6 \[skip ci\]
  ([22fa4cd](https://github.com/seanthimons/concert/tree/22fa4cd5d23875a9912e27c17749536b3afeb93e))

Full set of changes:
[`v0.6.5...v0.6.6`](https://github.com/seanthimons/concert/compare/v0.6.5...v0.6.6)

## concert 0.6.5 (2026-10-16)

#### Bug fixes

- scan full sheets when guessing column types
  ([7820c4b](https://github.com/seanthimons/concert/tree/7820c4b5e106efeef034024d778f69650a58a0a5))

#### Docs

- update NEWS.md for v0.6.5 \[skip ci\]
  ([535f5fa](https://github.com/seanthimons/concert/tree/535f5fa7916fa3badfe7c5d7c937f5e735bdb442))

#### Other changes

- bump version to 0.6.5 \[skip ci\]
  ([80db5d4](https://github.com/seanthimons/concert/tree/80db5d4b61d5db32165af68d0f353378d97662b2))

Full set of changes:
[`v0.6.4...v0.6.5`](https://github.com/seanthimons/concert/compare/v0.6.4...v0.6.5)

## concert 0.6.4 (2026-10-15)

#### New features

- harmonize analytical methods
  ([dbe736c](https://github.com/seanthimons/concert/tree/dbe736c0b2e0431ad7350331dc5b976f8fb3f1e8))
- download pinned envharmonizer tables at startup
  ([eeb3fb6](https://github.com/seanthimons/concert/tree/eeb3fb682310dfeb9b75803c6e4625e7a71a6714))

#### Bug fixes

- validate inputs and correct media hit counts
  ([c87ca5e](https://github.com/seanthimons/concert/tree/c87ca5e0730b4fdb6db9f992f35e7730059cd325))

#### Docs

- update NEWS.md for v0.6.4 \[skip ci\]
  ([cb7a3d6](https://github.com/seanthimons/concert/tree/cb7a3d6a333bd4a4906b07a859efe84d2041a2dc))

#### Other changes

- bump version to 0.6.4 \[skip ci\]
  ([0d492e6](https://github.com/seanthimons/concert/tree/0d492e6af52b289e8b352a6de2d9d0e89f23880a))

Full set of changes:
[`v0.6.3...v0.6.4`](https://github.com/seanthimons/concert/compare/v0.6.3...v0.6.4)

## concert 0.6.3 (2026-10-15)

#### New features

- expose header detection thresholds and document tie-break (#12, #18,
  #14)
  ([731f477](https://github.com/seanthimons/concert/tree/731f477aca2eb1e2e69d2f5e9813de877db98221))
- detect and repair CASRNs converted to dates by spreadsheets (#35)
  ([48df247](https://github.com/seanthimons/concert/tree/48df2473eebf29a3aa152eaa225be1fbbf5c0a21))

#### Bug fixes

- detect CSV encoding and delimiter up front; add upload edge-case tests
  (#7)
  ([723a4a3](https://github.com/seanthimons/concert/tree/723a4a3924226ebd40a81adda636f7770aea64dc))
- keep all columns when a CSV has a short title line above the header
  (#7)
  ([0da5682](https://github.com/seanthimons/concert/tree/0da5682a05a70cbb0bf3cbf9071f014a0b2d267b))
- validate manual header row for 0, negative and NA (#99)
  ([b4a6ccc](https://github.com/seanthimons/concert/tree/b4a6cccc2933b03d2c4d91699b97ead590fff060))

#### Performance

- vectorize is_cas, as_cas and extract_cas
  ([2c4fe7c](https://github.com/seanthimons/concert/tree/2c4fe7c393157d34f3ead303d8fbf94f97cc06ba))

#### Docs

- update NEWS.md for v0.6.3 \[skip ci\]
  ([5e0b838](https://github.com/seanthimons/concert/tree/5e0b838495a2cf56f2afe1def764fe7e50169937))

#### Other changes

- bump version to 0.6.3 \[skip ci\]
  ([a7d63b3](https://github.com/seanthimons/concert/tree/a7d63b3a608e25faebacbf9d50e46f7b8a2c3da5))

Full set of changes:
[`v0.6.2...v0.6.3`](https://github.com/seanthimons/concert/compare/v0.6.2...v0.6.3)

## concert 0.6.2 (2026-10-13)

#### Bug fixes

- limit roman oxidation-state protection to real states and QC-flag
  lowercase
  ([fa2ec68](https://github.com/seanthimons/concert/tree/fa2ec685001195c9b55c348637bfd8c7291b07a3))

#### Tests

- add extracted cleaning reference cases
  ([419bf83](https://github.com/seanthimons/concert/tree/419bf83e1bab1f1dbc29cac6540b1d1c3b49d05a))
- cover column selection, detection-mode reprocessing and tag
  persistence
  ([3c28746](https://github.com/seanthimons/concert/tree/3c28746432fbf028c49ac81df3b6b63f02d4006e))
- run toxval_schema tests against the shipped cache and fix stale
  assertions
  ([b638e12](https://github.com/seanthimons/concert/tree/b638e1220c9ba7f872865617976f74002b611e19))

#### Docs

- update NEWS.md for v0.6.2 \[skip ci\]
  ([91ab9b2](https://github.com/seanthimons/concert/tree/91ab9b2c43f3cf7870db32fbaf1dbc8126c0886c))

#### Other changes

- bump version to 0.6.2 \[skip ci\]
  ([484e08f](https://github.com/seanthimons/concert/tree/484e08f88a5fb6a64b3ac66a79c605039a71d680))
- ignore testthat \_problems reproductions
  ([f421899](https://github.com/seanthimons/concert/tree/f421899cf7be82e17393896ae1ce692174e12a18))

Full set of changes:
[`v0.6.1...v0.6.2`](https://github.com/seanthimons/concert/compare/v0.6.1...v0.6.2)

## concert 0.6.1 (2026-10-08)

#### New features

- bulk staging and aligned editor for Rows Needing Review (#46)
  ([e8184f5](https://github.com/seanthimons/concert/tree/e8184f5147b3bc51b051dcddab3cacd7a0fb5876))

#### Bug fixes

- record repeated source CAS on scripted multi-analyte splits (#95)
  ([82a8665](https://github.com/seanthimons/concert/tree/82a86651dbd3485bfc270362378d56f4e40e8dcd))
- compare exact-match ties as unordered sets in review evidence (#93)
  ([e97e246](https://github.com/seanthimons/concert/tree/e97e246dade99e8613caaae434314b96bf88c05f))
- surface scope blockers on VERIFIED rows in pending review (#110)
  ([cbc5f2b](https://github.com/seanthimons/concert/tree/cbc5f2b4f33c757ba5d5642b3c973313e11d1330))
- keep accepted suggestions out of the verified_unresolved queue (#92)
  ([b4c6277](https://github.com/seanthimons/concert/tree/b4c6277c0801fa2a333e1053b32cbe5d5eb15cda))

#### CI

- push release commit and tag atomically with a scoped token
  ([7b7dd37](https://github.com/seanthimons/concert/tree/7b7dd370ee40e3c1f643c1622dc4aedbe4aa0782))
- stop ignoring .github so zizmor can collect workflows
  ([29b23c3](https://github.com/seanthimons/concert/tree/29b23c3246690d48b151e82ffd33d4067fc7626a))
- silence intentional SC2016 in the ComptoxR bump PR body
  ([d3a705f](https://github.com/seanthimons/concert/tree/d3a705f1c1bebc2b3ef5407e98857e028fbdd494))
- make release.yaml version comments exact for zizmor
  ([c17b273](https://github.com/seanthimons/concert/tree/c17b27326003559386266e88e0cb2b9cc1e33938))
- serialize and scope tokens in track-comptoxr-release
  ([e0fbe40](https://github.com/seanthimons/concert/tree/e0fbe4046431d68bcc186e839cb23442f1540887))
- call baseline R CMD check and harden locked-review
  ([37e7e45](https://github.com/seanthimons/concert/tree/37e7e4548c319deeb09d8353ccfa0a7953bc608d))
- call baseline gitleaks, commit-lint, lint-workflows and build-package
  ([ab67434](https://github.com/seanthimons/concert/tree/ab67434fb5b2b265ee101022a11cdf14f9c58a43))
- skip automatic releases for tests- and tooling-only merges
  ([bd3b00a](https://github.com/seanthimons/concert/tree/bd3b00a16b3626df7eceab4fc2ad24cb0dc9886b))
- cut a patch release on merges to main except docs, site and CI changes
  ([aaac0c0](https://github.com/seanthimons/concert/tree/aaac0c07c0dc7c6111daf16646014e85b47992ad))

#### Docs

- update NEWS.md for v0.6.1 \[skip ci\]
  ([dc6c708](https://github.com/seanthimons/concert/tree/dc6c708e0b25fbfbf17b8a7e6c89b5315d2f4fd3))

#### Other changes

- bump version to 0.6.1 \[skip ci\]
  ([d6f1ba0](https://github.com/seanthimons/concert/tree/d6f1ba0eae2c75c79723ee2f7ec8e0f64ca26ff9))

Full set of changes:
[`v0.6.1...v0.6.1`](https://github.com/seanthimons/concert/compare/v0.6.1...v0.6.1)

## concert 0.6.0 (2026-10-08)

#### New features

- add scoped chemical identity review and acceptance
  ([399b6de](https://github.com/seanthimons/concert/tree/399b6de7ff94e11ebec796b7f7d5472f68ab95e2))

#### Bug fixes

- leave conflicting WQX aliases unresolved
  ([3597efc](https://github.com/seanthimons/concert/tree/3597efc74e2a55d7f3331f34db00b35fc6d04c6b))
- keep raw WQX metadata out of candidate queries
  ([51882a9](https://github.com/seanthimons/concert/tree/51882a940a694642faa5d542f597510850904721))
- keep detailed query records optional in the review table
  ([ced8ea2](https://github.com/seanthimons/concert/tree/ced8ea2fa3fbe75611b479b2bacc843e3a1e100a))
- require WQX review and preserve scoped evidence across replay
  ([29dbca0](https://github.com/seanthimons/concert/tree/29dbca08fe8d2efa757adb01983dd20de69c8e0a))
- continue original and canonical WQX candidate queries
  ([86e5b18](https://github.com/seanthimons/concert/tree/86e5b187168ce683a9e79e5f57a11ad3b3b8e5b5))
- continue WQX CAS lookup as attributed review candidates
  ([e8d82ed](https://github.com/seanthimons/concert/tree/e8d82edee6e785aeea8306ec52fba8ae84632c7a))
- retain canonical WQX CAS evidence without choosing ties
  ([06be01e](https://github.com/seanthimons/concert/tree/06be01e520b999e1afd7e144f74104641be6e644))
- make review UI strings and release archive portable
  ([78c9c61](https://github.com/seanthimons/concert/tree/78c9c614fd658a3fb697ea36b79daae35cbf14d5))
- preserve pinned manifest bytes and repair CAS assertion
  ([2947812](https://github.com/seanthimons/concert/tree/2947812802d98e90ba70c28bbbd9f71faee1bcff))

#### Tests

- cover WQX candidate boundaries in locked CI
  ([bf9e725](https://github.com/seanthimons/concert/tree/bf9e725669c261585117b695efce107a17d616ca))
- exercise WQX source decisions in the actual app
  ([23bcbcd](https://github.com/seanthimons/concert/tree/23bcbcd8d27a687bc55b31d94f7c564cfa7be2b3))

#### CI

- restore locked packages directly on disposable runners
  ([372ff4a](https://github.com/seanthimons/concert/tree/372ff4a9041cf6365c8a6e1ddd2eb7746344cfe4))
- make cross-platform package checks opt-in
  ([90629b2](https://github.com/seanthimons/concert/tree/90629b260a26602674505e4a2c520d98dc620331))

#### Docs

- update NEWS.md for v0.6.0 \[skip ci\]
  ([f359cac](https://github.com/seanthimons/concert/tree/f359cac1aabd9fefa87ecb45c9c9d929d6939aa9))
- record audit regressions and crash recovery
  ([5109c72](https://github.com/seanthimons/concert/tree/5109c72b159fee60daae6c6e06b8ea49e9a10597))
- record WQX implementation checks and release pause
  ([bfca9d5](https://github.com/seanthimons/concert/tree/bfca9d522d2e7c2bac05fa43b43947a175de053d))
- illustrate WQX evidence review and repair NEWS publishing
  ([e2aa2f7](https://github.com/seanthimons/concert/tree/e2aa2f73dd70fd7acdb40f08de72cff4b32c1bda))
- index identity review APIs for pkgdown
  ([d4b684d](https://github.com/seanthimons/concert/tree/d4b684d4ffc75d80d56a871d41e4a9845dce0fad))

#### Other changes

- bump version to 0.6.0 \[skip ci\]
  ([1a68cd1](https://github.com/seanthimons/concert/tree/1a68cd1b4203e0a42ceaec48187ec872a388267d))

Full set of changes:
[`v0.5.3...v0.6.0`](https://github.com/seanthimons/concert/compare/v0.5.3...v0.6.0)

## concert 0.5.3 (2026-10-06)

#### Bug fixes

- stop reading alkyl chain lengths as carbon isotopes
  ([3493970](https://github.com/seanthimons/concert/tree/34939706d6ed6caee4c3ba220317cba2f5215e61))
- keep CAS-only rows through name cleaning
  ([8755264](https://github.com/seanthimons/concert/tree/87552648f8bd8bb21429435e4c368e39b5355736))
- refresh harmonize DTXSID count and ToxVal identifiers after curation
  (#79)
  ([ab04b6d](https://github.com/seanthimons/concert/tree/ab04b6d2ee00535aa7c846ef62eed011f1fc90f2))

#### Docs

- update NEWS.md for v0.5.3 \[skip ci\]
  ([890efdb](https://github.com/seanthimons/concert/tree/890efdb01dbb10f0bbd1c14a15b5f52d13c4db66))
- app walkthrough article and README installation cleanup (#80)
  ([d8a32ef](https://github.com/seanthimons/concert/tree/d8a32ef30c2307a4318853c0f9f707e8683d93d4))
- merge pkgdown site and usage vignettes (#65)
  ([4306b81](https://github.com/seanthimons/concert/tree/4306b81136cc9d1210d1435923f25b4ac875b85f))

#### Other changes

- bump version to 0.5.3 \[skip ci\]
  ([872415c](https://github.com/seanthimons/concert/tree/872415ce589f1834a52a168a93d2168f17390c71))

Full set of changes:
[`v0.5.2...v0.5.3`](https://github.com/seanthimons/concert/compare/v0.5.2...v0.5.3)

## concert 0.5.2 (2026-10-05)

#### New features

- merge v0.5.2 curation fixes (#78)
  ([a2639cd](https://github.com/seanthimons/concert/tree/a2639cd323e9ef0a3601c61ea8e69e4376e9acfa))
- opt-in DSSTox download and desalt_workflows in scripts and decisions
  ([209773e](https://github.com/seanthimons/concert/tree/209773eabfadbdc4f804040f78450782ce4d8de6))
- chemi resolver fallback for names CTX leaves unresolved
  ([c108e7c](https://github.com/seanthimons/concert/tree/c108e7c8d34652c61783f7039344f9edea5711ab))
- point isotope-labelled records to their unlabelled parent
  ([11ff44c](https://github.com/seanthimons/concert/tree/11ff44c10820aba85828577109e54beed3658736))
- add structure-based parent columns via chemi standardizer
  ([5b7635c](https://github.com/seanthimons/concert/tree/5b7635c564243fc9a023fa3f580a57fbe8209b02))

#### Bug fixes

- send tied exact-name hits to review instead of a batch-dependent pick
  ([43b952d](https://github.com/seanthimons/concert/tree/43b952de49ad2d9973a3b5f15a47fa0e2b37ea7e))
- keep DUPLICATE resolver hits, drop structure-parsed ones; flag Markush
  ([dbae93a](https://github.com/seanthimons/concert/tree/dbae93a363b41d51bd7048bf8801f8a6ec089736))
- still strip glued acronyms and plural markers from names
  ([9642bdc](https://github.com/seanthimons/concert/tree/9642bdc9ea12b61fa1d5b0bb3fdf905ecd79446d))
- block WQX fuzzy matches that bridge isotope labels or congener codes
  ([6a056d5](https://github.com/seanthimons/concert/tree/6a056d5a892b3644c9090642cb24f7754fec80b5))
- keep name-attached enclosures during terminal stripping
  ([3ff20a0](https://github.com/seanthimons/concert/tree/3ff20a09908434fa3ffa54f48a94d57a6e42aaf2))

#### Docs

- update NEWS.md for v0.5.2 \[skip ci\]
  ([76ee087](https://github.com/seanthimons/concert/tree/76ee087098db3a627c96ed7ae9ad53adb0d620bb))

#### Other changes

- bump version to 0.5.2 \[skip ci\]
  ([3738c6c](https://github.com/seanthimons/concert/tree/3738c6c2e4c5761f8e9eb1aa3f617a8119fa7eb9))

Full set of changes:
[`v0.5.1...v0.5.2`](https://github.com/seanthimons/concert/compare/v0.5.1...v0.5.2)

## concert 0.5.1 (2026-10-04)

#### Bug fixes

- merge WQX review flags and chemical identity qualifier fixes
  ([ff8718b](https://github.com/seanthimons/concert/tree/ff8718b65388769c5b41936abaae1ac19ea7b62c))
- preserve enclosed chemical qualifiers and audit lineage
  ([7cbb4af](https://github.com/seanthimons/concert/tree/7cbb4af4c31426702dab44eb170a139aceec4af0))
- preserve bounded identity qualifier tokens (#73)
  ([215dab7](https://github.com/seanthimons/concert/tree/215dab7f1b9b0722021daf646f1f37cf74fa1a5e))
- preserve 13C6 identity enclosures (#73)
  ([dce9f35](https://github.com/seanthimons/concert/tree/dce9f3502cf7776fed37702202249237caa015a7))
- flag unverified WQX identities for review (#72)
  ([12ee869](https://github.com/seanthimons/concert/tree/12ee869fde818f23580ee5ed6b973edb647221cd))

#### Tests

- cover identity qualifiers through full cleaning pipeline (#73)
  ([064794e](https://github.com/seanthimons/concert/tree/064794ee62468a441a8aa00f824bf2addfce123b))

#### Docs

- update NEWS.md for v0.5.1 \[skip ci\]
  ([e2348fe](https://github.com/seanthimons/concert/tree/e2348fec89d40d44d98475d2b4320c5c17cb1bb0))

#### Other changes

- bump version to 0.5.1 \[skip ci\]
  ([3487db3](https://github.com/seanthimons/concert/tree/3487db37c6261b945b8bbdb500b1bf34efa69f7f))

Full set of changes:
[`v0.5.0...v0.5.1`](https://github.com/seanthimons/concert/compare/v0.5.0...v0.5.1)

## concert 0.5.0 (2026-09-28)

#### New features

- add PubChem and salt parent candidates
  ([912a452](https://github.com/seanthimons/concert/tree/912a452ff957dfca56a2d081ad14885008c44cde))

#### Docs

- update NEWS.md for v0.5.0 \[skip ci\]
  ([c74ffd4](https://github.com/seanthimons/concert/tree/c74ffd47fe20e17ed868fd618418b17ae1802387))

#### Other changes

- bump version to 0.5.0 \[skip ci\]
  ([4b4e106](https://github.com/seanthimons/concert/tree/4b4e1069e34d9857494d89fcb2a650f0b8e7c4b5))

Full set of changes:
[`v0.4.4...v0.5.0`](https://github.com/seanthimons/concert/compare/v0.4.4...v0.5.0)

## concert 0.4.4 (2026-09-22)

#### Bug fixes

- merge semicolon-only synonym split and original_row_id keyed
  resolutions (v0.4.4)
  ([0767bf0](https://github.com/seanthimons/concert/tree/0767bf02dec17f1f9003ef4d82539d423e24a59a))
- split synonyms on semicolons only and key resolutions by
  original_row_id
  ([49df31a](https://github.com/seanthimons/concert/tree/49df31a79c75e4560ba76c3d04c9195e09569f51))

#### Docs

- update NEWS.md for v0.4.4 \[skip ci\]
  ([c8bf9d4](https://github.com/seanthimons/concert/tree/c8bf9d42f1aac8843b7ad0f882f8b9e8de017dbe))
- document row_index keying and value_corrections ordering
  ([4bb9a97](https://github.com/seanthimons/concert/tree/4bb9a97c11314758f710446097bfab5cd545a3fb))

#### Other changes

- bump version to 0.4.4
  ([9743a63](https://github.com/seanthimons/concert/tree/9743a634aba7569e7456eecfb95dc7efa2c7b3c3))

Full set of changes:
[`v0.4.4...v0.4.4`](https://github.com/seanthimons/concert/compare/v0.4.4...v0.4.4)

## concert 0.4.3 (2026-09-22)

#### Bug fixes

- merge split_synonyms CAS gate and synonyms step switch
  ([e849419](https://github.com/seanthimons/concert/tree/e8494192427f689050572e0d89546054c9bb0d06))
- stop split_synonyms breaking IUPAC and registry names on commas
  ([daa7bfb](https://github.com/seanthimons/concert/tree/daa7bfb9ad8bfbe3e58c6bdee9f9d2f1aced2569))

#### Docs

- update NEWS.md for v0.4.3 \[skip ci\]
  ([446f12b](https://github.com/seanthimons/concert/tree/446f12b72a566d3b998666ec14636d3b5c4666ce))
- add pkgdown site and usage vignettes
  ([06c8396](https://github.com/seanthimons/concert/tree/06c83961516fcbba389a6183f06d8c95558cbce1))

#### Other changes

- bump version to 0.4.3 \[skip ci\]
  ([1398a4d](https://github.com/seanthimons/concert/tree/1398a4d2745c970c13ff1b4e5a54c171af71153f))

Full set of changes:
[`v0.4.2...v0.4.3`](https://github.com/seanthimons/concert/compare/v0.4.2...v0.4.3)

## concert 0.4.2 (2026-09-15)

#### Docs

- update NEWS.md for v0.4.2 \[skip ci\]
  ([3ef373e](https://github.com/seanthimons/concert/tree/3ef373e52f6e2330814c8326734bc85138db86e1))

#### Other changes

- bump version to 0.4.2 \[skip ci\]
  ([200f8b9](https://github.com/seanthimons/concert/tree/200f8b993f4ed31ebbc6cd7d5110ee71b1758093))

Full set of changes:
[`v0.4.1...v0.4.2`](https://github.com/seanthimons/concert/compare/v0.4.1...v0.4.2)

## concert 0.4.1 (2026-09-15)

#### New features

- runner installs latest release before each run
  ([0776f63](https://github.com/seanthimons/concert/tree/0776f634fac3ef104eed3f2a9543cce64e82be2b))
- ship curate_loop.R runner and concert-curate agent skill
  ([bfcfa56](https://github.com/seanthimons/concert/tree/bfcfa563ef0748106085d941c7d70eedac6d25c6))
- add curate_iterate agent loop with decisions template and search cache
  ([23c7e15](https://github.com/seanthimons/concert/tree/23c7e15550a5beeff083166e116a47e08a082588))
- add value_corrections and cleaning_steps replay inputs
  ([7afb533](https://github.com/seanthimons/concert/tree/7afb533aa476d0919368efa31e31d95887d96d59))

#### Bug fixes

- runner survives failed release install and status.md flags
  low-similarity matches
  ([31c0f3a](https://github.com/seanthimons/concert/tree/31c0f3a2b72a7fc688d955f23efc6f3e8aed5158))
- integrate Unicode cleanup with review performance
  ([0285d71](https://github.com/seanthimons/concert/tree/0285d718cf4f80b3d190c0db9464be0018e8e71d))
- protect primed locants from synonym splitting
  ([ce8b63d](https://github.com/seanthimons/concert/tree/ce8b63d6e8e01ec664aefcde28b6b97865cf5b1c))
- distinguish unmapped Unicode in QC
  ([bbd3925](https://github.com/seanthimons/concert/tree/bbd3925cdd47537456b18b2aae409449b756dcc8))
- normalize hyphen and zero-width space
  ([c283936](https://github.com/seanthimons/concert/tree/c283936075bc2b1ba8ecbcaafb3f4eef39886b80))

#### Refactorings

- split curate_headless into composable stage functions
  ([1882a83](https://github.com/seanthimons/concert/tree/1882a836eb2f73e598a669a35dab5dc4cd76f3d9))

#### Performance

- paginate review results and lock project dependencies
  ([cf749af](https://github.com/seanthimons/concert/tree/cf749af8ed84edf98b2b7c7f1fdd612a631dd0d5))

#### Build

- pin renv lock to dated PPM snapshot for binary restore
  ([9ebd68f](https://github.com/seanthimons/concert/tree/9ebd68f317c2f91efc73404662fab8279c79672a))

#### Docs

- update NEWS.md for v0.4.1 \[skip ci\]
  ([326c3ca](https://github.com/seanthimons/concert/tree/326c3ca3abb44ea527b68a64bdd30d959f740696))
- document mask argument of run_cleaning_pipeline
  ([cb1ed52](https://github.com/seanthimons/concert/tree/cb1ed52f9dbd745edb2ac0611269a30e85d94236))
- update NEWS.md for v0.4.1 \[skip ci\]
  ([d82c4cf](https://github.com/seanthimons/concert/tree/d82c4cf40793eb1c9cbdf3ed09c6aeb98804adf2))

#### Other changes

- bump version to 0.4.1 \[skip ci\]
  ([acc48f3](https://github.com/seanthimons/concert/tree/acc48f3cb6ca1749ac9984b3ce81117470340651))

Full set of changes:
[`v0.4.0...v0.4.1`](https://github.com/seanthimons/concert/compare/v0.4.0...v0.4.1)

## concert 0.4.0 (2026-09-11)

#### Breaking changes

- integrate published media curation and compact replays (#61)
  ([c4ab218](https://github.com/seanthimons/concert/tree/c4ab218d94145903f3fde0d0ece6f45c09f4d0f4))
- pin workbook and script replay to media artifacts
  ([1ee4b71](https://github.com/seanthimons/concert/tree/1ee4b7114e598169499105023117523fab432425))
- export canonical labels and preserve original input
  ([cbb4b18](https://github.com/seanthimons/concert/tree/cbb4b18610d6542a137a58278fc767e63499da9c))

#### New features

- expose published ontology context in the editor
  ([c0fb676](https://github.com/seanthimons/concert/tree/c0fb6765e09cbef22ca03f24fa0aa180d17ad1bc))
- separate published identities from conversion routes
  ([764d23b](https://github.com/seanthimons/concert/tree/764d23b08226a6656e8afc2be9f4a4ace6f3acb3))
- import pinned published media artifacts
  ([0c00ade](https://github.com/seanthimons/concert/tree/0c00adebb624f33082b2b545b34782380f2be3c8))

#### Bug fixes

- omit reconstructible metadata from media replay snapshots
  ([414031d](https://github.com/seanthimons/concert/tree/414031d0e9d83ebb6e0fd87df05148a7f036451a))
- exclude bundled reference settings from replay overrides
  ([d20a845](https://github.com/seanthimons/concert/tree/d20a845525a2c5fdea3ac23693e2689668aae14a))
- make replay deterministic across locales and unit edits
  ([012c78b](https://github.com/seanthimons/concert/tree/012c78baf2440ec9425ff6ae052b47122f53124e))
- allow selecting WQX evidence candidates
  ([0d1c855](https://github.com/seanthimons/concert/tree/0d1c855477d50ff88fc1d23b4a5429cf2f27c2ed))

#### Build

- bump ComptoxR pin to v1.7.1
  ([6daa5c4](https://github.com/seanthimons/concert/tree/6daa5c48cc989bcbca2d630784c6ad323482832d))

#### Docs

- update NEWS.md for v0.4.0 \[skip ci\]
  ([ab35c45](https://github.com/seanthimons/concert/tree/ab35c45ff88506ceb1fbd91cf75175b8fcd845b4))
- record user acceptance for review
  ([442b76e](https://github.com/seanthimons/concert/tree/442b76e965e0ca4b6643385cbfa7f089838a5ed6))
- link integration epic to review PR
  ([3e3f391](https://github.com/seanthimons/concert/tree/3e3f391d9f925f5ff0672b9a57b86ccec1ab50f4))
- record validation and remaining manual acceptance
  ([80f0377](https://github.com/seanthimons/concert/tree/80f03776e545925a1419b92ba37e6d909929d45d))
- assess environmental harmonization integration
  ([6b4ec6a](https://github.com/seanthimons/concert/tree/6b4ec6a7d9fbe168d1c715d557e932efedd4801f))

#### Other changes

- bump version to 0.4.0 \[skip ci\]
  ([04355a0](https://github.com/seanthimons/concert/tree/04355a0f88f71356a2cf926f462d2962a5f93ec6))
- track published media integration and follow-ups
  ([f14ff3f](https://github.com/seanthimons/concert/tree/f14ff3f78d616c3a65ad548399379d6945b63f23))
- integrate current main
  ([3c34587](https://github.com/seanthimons/concert/tree/3c345874c96cf18ae33d1535f8470b43faec40c8))

Full set of changes:
[`v0.3.2...v0.4.0`](https://github.com/seanthimons/concert/compare/v0.3.2...v0.4.0)

## concert 0.3.2 (2026-08-12)

#### Bug fixes

- correct harmonizer failure handling
  ([3bea7e2](https://github.com/seanthimons/concert/tree/3bea7e221ebd45fd202226b1e6d68741bb5d93ad))

#### Docs

- update NEWS.md for v0.3.2 \[skip ci\]
  ([0b878ca](https://github.com/seanthimons/concert/tree/0b878ca56554fcee8214e9cd492ab9b118ab375a))

#### Other changes

- bump version to 0.3.2 \[skip ci\]
  ([3d0797b](https://github.com/seanthimons/concert/tree/3d0797ba24e975f1a929d39aabd5e23c1685661d))

Full set of changes:
[`v0.3.1...v0.3.2`](https://github.com/seanthimons/concert/compare/v0.3.1...v0.3.2)

## concert 0.3.1 (2026-07-21)

#### Bug fixes

- detect ’ & ’ and ’ / ’ multi-analyte separators (#54)
  ([dff9b54](https://github.com/seanthimons/concert/tree/dff9b545efb5649e062de07d78241d051d24cf4d))

#### Docs

- update NEWS.md for v0.3.1 \[skip ci\]
  ([3ff24f2](https://github.com/seanthimons/concert/tree/3ff24f2f1bfa110c7f374a73eb6d230d0d67270c))

#### Other changes

- bump version to 0.3.1
  ([7b75317](https://github.com/seanthimons/concert/tree/7b75317e29880e88dad76f95e768a8007cfdffa6))

Full set of changes:
[`v0.3.0...v0.3.1`](https://github.com/seanthimons/concert/compare/v0.3.0...v0.3.1)

## concert 0.3.0 (2026-07-21)

#### New features

- fan one review decision to all rows sharing name + CAS
  ([9216087](https://github.com/seanthimons/concert/tree/92160871617bc5da5b3ba8aed6407434df6f59ab))

#### Bug fixes

- use ASCII in review pairing label for R CMD check
  ([0ca7f62](https://github.com/seanthimons/concert/tree/0ca7f62e3d58286dc38cd3fdf608d5ccfde92084))

#### Refactorings

- consolidate multi-analyte and multi-CAS review into one surface
  ([1587323](https://github.com/seanthimons/concert/tree/158732313cad4d49dbcd21488194d3c3e2fc1a5a))

#### Tests

- prove review fan-out is CAS-column-order independent
  ([62dae53](https://github.com/seanthimons/concert/tree/62dae5377a71d6399a7845a40646ef02cc22cd48))

#### Docs

- update NEWS.md for v0.3.0 \[skip ci\]
  ([4a49fb5](https://github.com/seanthimons/concert/tree/4a49fb57ebfe86d76c7f21cc828583fd57407ee3))
- track review-resolution follow-up beans (#54, #55)
  ([72205dc](https://github.com/seanthimons/concert/tree/72205dc0c615c34152fa85eefb3c1bc51d325576))

#### Other changes

- bump version to 0.3.0 \[skip ci\]
  ([124d961](https://github.com/seanthimons/concert/tree/124d9612a7d943d589b3e9b39c7373950f6e5ba8))

Full set of changes:
[`v0.2.0...v0.3.0`](https://github.com/seanthimons/concert/compare/v0.2.0...v0.3.0)

## concert 0.2.0 (2026-07-20)

#### New features

- split embedded units out of measurement values
  ([4f4b2dd](https://github.com/seanthimons/concert/tree/4f4b2ddf5c8a40f7d569d268ccab7b910ac125f6))
- rebuild numeric parse issues as editable bulk-reassign table
  ([f68d941](https://github.com/seanthimons/concert/tree/f68d941052f91bf39f07796058ac87a48776096b))
- add MFL fiber-concentration conversions to stable dictionary
  ([20342d9](https://github.com/seanthimons/concert/tree/20342d9b52a24308cec87161a981a22afeef310c))

#### Bug fixes

- harmonize microfiber units to MFL
  ([324841d](https://github.com/seanthimons/concert/tree/324841d999bfaa110b4483fc3ce4be5bf46ca0cb))
- resolve blank-target unit mappings
  ([44f3b69](https://github.com/seanthimons/concert/tree/44f3b69292a2695d31f9c6561c97297e9a89b9e3))
- apply searchable review filters on selectize changes
  ([bf6979f](https://github.com/seanthimons/concert/tree/bf6979fe08369064495e25fcc42c62ab22982ad1))
- keep filter dropdowns above table
  ([17d90cc](https://github.com/seanthimons/concert/tree/17d90cc8a8b7dbe65aafe6876f98bb6cee59c0e7))

#### Refactorings

- reorder editor panels — unmatched under unit map, parse issues above
  corrections
  ([820ab41](https://github.com/seanthimons/concert/tree/820ab419c8fb7a0af2e51a10525e6a0c0494c0f1))

#### Build

- pin ComptoxR to v1.5.1
  ([3978909](https://github.com/seanthimons/concert/tree/3978909a08a92c440b8088a02553f97035dfa7cb))

#### CI

- add workflow to track ComptoxR releases and open pin-bump PRs
  ([9e94f7a](https://github.com/seanthimons/concert/tree/9e94f7ac51be5bab7b783c5c7d7c9e551e9db2e7))

#### Docs

- update NEWS.md for v0.2.0 \[skip ci\]
  ([d4010d3](https://github.com/seanthimons/concert/tree/d4010d329ae5d55a654b13ba9d27225c6fef9cfd))
- mark internal editor/split helpers @noRd
  ([abfa3dd](https://github.com/seanthimons/concert/tree/abfa3dd4cc2450141fb8c697416e2d0fe7dcfe8e))

#### Other changes

- bump version to 0.2.0 \[skip ci\]
  ([c6648d3](https://github.com/seanthimons/concert/tree/c6648d3a1087c6f2108b86afe78683509c48d110))

Full set of changes:
[`v0.1.4...v0.2.0`](https://github.com/seanthimons/concert/compare/v0.1.4...v0.2.0)

## concert 0.1.4 (2026-07-14)

#### New features

- clarify canonical site identity
  ([f0658bd](https://github.com/seanthimons/concert/tree/f0658bd45ceaf9a818934a8aaa3990b4bd6c6cfb))
- add curated results dropdown filters
  ([c96f26c](https://github.com/seanthimons/concert/tree/c96f26c6453645599d73b5bf03dccbf7bf3b5fb9))

#### Bug fixes

- advance the replay baseline to the harmonized stage
  ([be17b01](https://github.com/seanthimons/concert/tree/be17b011eb8f2d0444df015a42019ef956c8c427))
- reconstruct full replay when resuming a baseline-less workbook
  ([7eeff1b](https://github.com/seanthimons/concert/tree/7eeff1be7cb2a5af6587c8aaf5bafae0a2958c0c))

#### Performance

- snapshot harmonization maps as provenance-blind deltas
  ([654f610](https://github.com/seanthimons/concert/tree/654f610c57429f62c7fcaf679212cf99b170cbf2))

#### CI

- align GitHub Actions across R package repos (#49)
  ([2ed41da](https://github.com/seanthimons/concert/tree/2ed41da0f5ff3503055c02ac87bc622a2150e678))

#### Docs

- update NEWS.md for v0.1.4 \[skip ci\]
  ([eba7181](https://github.com/seanthimons/concert/tree/eba71818f52d21d70976b224152302e840d0559d))
- track resume-replay bug analysis and id-keying follow-up
  ([4cc0a18](https://github.com/seanthimons/concert/tree/4cc0a18761377d6bef689067715c45ca06ced70d))

#### Other changes

- bump version to 0.1.4 \[skip ci\]
  ([b6f690b](https://github.com/seanthimons/concert/tree/b6f690bd5d64659846a2be40918badac75d004f9))
- log when a workbook is exported without a replay baseline
  ([0e0e281](https://github.com/seanthimons/concert/tree/0e0e2816cbd4301e0b1992c8b22464cffd863d10))
- add csm_curation_raw replay script
  ([e394e19](https://github.com/seanthimons/concert/tree/e394e191d7f104a7e7033988c3a1f3f5c2ad2dff))

Full set of changes:
[`v0.1.3...v0.1.4`](https://github.com/seanthimons/concert/compare/v0.1.3...v0.1.4)

## concert 0.1.3 (2026-07-10)

#### Bug fixes

- harmonize environmental units
  ([9e5452d](https://github.com/seanthimons/concert/tree/9e5452d5ae3254e474aa234a557de6f4586654eb))

#### Other changes

- bump package version to 0.1.3 (#48)
  ([d915473](https://github.com/seanthimons/concert/tree/d9154732685ec2037afe29efd763e6d22acf4817))

Full set of changes:
[`v0.1.2...v0.1.3`](https://github.com/seanthimons/concert/compare/v0.1.2...v0.1.3)

## concert 0.1.2 (2026-07-09)

#### New features

- salvage SSWQS-style numeric strings, zero-digit values become
  narrative
  ([7bc2bbf](https://github.com/seanthimons/concert/tree/7bc2bbfffab4f477a086e8532aa57ef81ca5a5e0))

#### Bug fixes

- address PR #47 review feedback
  ([bd39d73](https://github.com/seanthimons/concert/tree/bd39d73854e0d8b55d272a50886f4e43b35f9b4b))

#### Tests

- pin SSWQS criterion-value corpus as parser regression fixture
  ([85a2069](https://github.com/seanthimons/concert/tree/85a20693745b3ce30c94550abf62c993fc647f4f))

#### Other changes

- bump package version to 0.1.2 (#47)
  ([c202cdc](https://github.com/seanthimons/concert/tree/c202cdcda09a6b0dc57605d994ffcceba85b1b5f))

Full set of changes:
[`v0.1.1...v0.1.2`](https://github.com/seanthimons/concert/compare/v0.1.1...v0.1.2)

## concert 0.1.1 (2026-07-09)

#### New features

- show package version in app header
  ([0a20b73](https://github.com/seanthimons/concert/tree/0a20b7345bd7f5099fa9db65082e68c2e3589124))
- unify harmonization runtime and replay state
  ([edfdfc2](https://github.com/seanthimons/concert/tree/edfdfc225212d0c735dc7707a7e8ffa770493d64))
- add flat ToxVal CSV/Parquet export from the app via shared writer
  ([2ba705a](https://github.com/seanthimons/concert/tree/2ba705a441bf80fcbf558e733bff8a866ec6a29c))
- compound-keyed review replay with compact reference snapshot
  ([1b0b5ed](https://github.com/seanthimons/concert/tree/1b0b5ed8da9b3c6b3fb9a1d77125347dd45d9f34))
- rebuild isotope lookup cache from ComptoxR periodic table
  ([badb460](https://github.com/seanthimons/concert/tree/badb460177cd1a10d80b852dc4cc929defc9badf))
- carry resolved WQX name into ToxVal export as crosswalk key
  ([7c59bca](https://github.com/seanthimons/concert/tree/7c59bcacc7d3e550c92e918b7b82da7735323099))
- shape-aware replay code emission
  ([bd1a019](https://github.com/seanthimons/concert/tree/bd1a019b5e329db73dda6722e566a1beaf6f106f))
- add bulk fill for site aliases
  ([4185601](https://github.com/seanthimons/concert/tree/41856017eb92b4456f21f9fd6f208a5192139759))
- add site alias map dataset context
  ([8afec4f](https://github.com/seanthimons/concert/tree/8afec4f497e0a0ca4039736468890ca9bf078a4a))
- add location curation preflight
  ([baa7ac8](https://github.com/seanthimons/concert/tree/baa7ac8760fd6489abd27072b381db2c688237bc))
- vendor CAS, unicode, formula, and mixture primitives from ComptoxR
  ([251c4c0](https://github.com/seanthimons/concert/tree/251c4c019ac498f812d490c4ac017bd1de56e1c6))
- add tag column suggestion controls
  ([dca2e45](https://github.com/seanthimons/concert/tree/dca2e457234d571cd7f25501c0ce491577212647))
- update review columns and benchmark generator
  ([d21fb18](https://github.com/seanthimons/concert/tree/d21fb18eb79d747f3ebe4bab9bab1bb954a3f2b6))
- add CLAUDE.md, roxygen docs, and reference cache files
  ([42458bc](https://github.com/seanthimons/concert/tree/42458bcc1b0e3dade5baf4ba73721d7586a7f028))
- add dropdown filters for categorical columns in curation table
  ([1c4b7bf](https://github.com/seanthimons/concert/tree/1c4b7bfa93e2ae7f54847424064ddb955f3c565d))
- split curation tab into 3 separate tabs with full-width layout
  ([7ad5177](https://github.com/seanthimons/concert/tree/7ad51776b86cbe94c4ff971ed56329b38fa274e7))
- add chemical curation workflow with ComptoxR integration
  ([4aebefa](https://github.com/seanthimons/concert/tree/4aebefa4792386b0f5347403b23016f123606578))

#### Bug fixes

- persist replay baseline across session export and import
  ([28aa0e5](https://github.com/seanthimons/concert/tree/28aa0e54b806eb059d13e0adf41cdf6b787b7996))
- added example replay script
  ([bf2928c](https://github.com/seanthimons/concert/tree/bf2928cd57a6b6cf7d299cd632829d9924bb4f3c))
- hide dataset context audit columns by default
  ([221a1b3](https://github.com/seanthimons/concert/tree/221a1b34908744734fcf9624e602462eca7c65cd))
- preserve dataset context table state on edit
  ([01ec787](https://github.com/seanthimons/concert/tree/01ec787eb53edb987fd591d8b7f4614e2516f624))
- polish concert review and tagging UI
  ([1db6682](https://github.com/seanthimons/concert/tree/1db6682fc646268a34f0d9ef0b16bfae47f0813b))
- require resolved media for unit routing
  ([4a96aad](https://github.com/seanthimons/concert/tree/4a96aad9d6bb85b828640eea2ec7da4eb49105a4))
- flag WQX evidence conflicts
  ([d47ab66](https://github.com/seanthimons/concert/tree/d47ab661dca42a80cbba4d5ab7ae857b9c167be7))
- align review display with consensus source
  ([6e3214f](https://github.com/seanthimons/concert/tree/6e3214fb49c035f720a56d8a54461439f655b251))
- normalize WQX locant variants
  ([2408f1f](https://github.com/seanthimons/concert/tree/2408f1fedda62ce823dc797800e541eaf3dab486))
- keep unresolved isotope matches searchable
  ([ca251d4](https://github.com/seanthimons/concert/tree/ca251d496cfa8dada36bc4a67766a4204252207a))
- harmonize environmental radiological units
  ([13056bc](https://github.com/seanthimons/concert/tree/13056bc76b10cb1d05b4f8819e103129bcffad01))
- vectorize pinned-row filtering and deduplicate export join
  ([1563334](https://github.com/seanthimons/concert/tree/1563334673ac2f5cec8ffaf989a80f1cb6ff45ac))
- always recommend CAS normalization when CASRN columns are tagged
  ([e228d60](https://github.com/seanthimons/concert/tree/e228d602cb008040bd05d9aede3e18e5e5d5a3b4))
- recalc consensus_summary after classify_auto_resolve
  ([ead343a](https://github.com/seanthimons/concert/tree/ead343a0e10bd27800cb615ee2186186c90d8601))
- restore unname() on badge color lookups
  ([f858ef6](https://github.com/seanthimons/concert/tree/f858ef6e20c028b80cada5972da16843ce426f6d))
- regenerate NAMESPACE to export scoring functions
  ([6b536b3](https://github.com/seanthimons/concert/tree/6b536b33620bf1362cd79f92845df90317ec3eeb))
- revise plans based on checker feedback
  ([e7e49c9](https://github.com/seanthimons/concert/tree/e7e49c9e24e626de9361568390c20b80efc36162))
- lint fix for outer_negation rule, clarify onFlushed comment
  ([98716a5](https://github.com/seanthimons/concert/tree/98716a5dc9bb10bc07acd825f7da7fd6161e6a47))
- defer selectize init via shinyjs::delay, unname badge lookups, lint
  fix
  ([c5d4a5c](https://github.com/seanthimons/concert/tree/c5d4a5c09279c46e77a8eaabb74ddccd691c0000))
- WQX results shadowed by NA-dtxsid CompTox exact rows
  ([1cbbeb6](https://github.com/seanthimons/concert/tree/1cbbeb6efc0c50e1a4dd70e7a8344f98e5e5ae61))
- apply ampersand normalization to hash table keys
  ([47ca8fe](https://github.com/seanthimons/concert/tree/47ca8fe73ef88a6af4d0c5433d947c1413bc8dff))
- alias dedup priority and ampersand normalization
  ([d47716d](https://github.com/seanthimons/concert/tree/d47716d3cd818df9b1315398cc75eb8d841a1016))
- revise plans based on checker feedback
  ([65333b1](https://github.com/seanthimons/concert/tree/65333b116af5f8c6f4b9ccc01758cb0290953387))
- rename stale bench_files reference to bench_file
  ([84c32b4](https://github.com/seanthimons/concert/tree/84c32b41b68467d37ea9f0d86e2c5d9c9e0ddb9b))
- add cas=CASRN to benchmark tag_map
  ([f066db3](https://github.com/seanthimons/concert/tree/f066db383cee13cc5b28eeee327e1d73882ccdf0))
- hardcode tag_map for detections.csv columns
  ([eccc324](https://github.com/seanthimons/concert/tree/eccc324184ab210787ad10288303a257a60b15a6))
- handle list-type isotope_lookup in precheck_isotope_shortcodes
  ([9d36e66](https://github.com/seanthimons/concert/tree/9d36e660e9bc1ea0ef6942971eee19019fbec2f9))
- hardcode detections.csv as benchmark input file
  ([0d6aa0d](https://github.com/seanthimons/concert/tree/0d6aa0d323ce1560ce0a1bf726ad409258b21093))
- WR-02 add readxl guard to stopifnot block for standalone script safety
  ([9fd116c](https://github.com/seanthimons/concert/tree/9fd116cbb6566a7832a97bf2ecad507e61387b77))
- WR-01 use correct media string ‘solid’ instead of ‘soil’ in
  harmonization benchmark
  ([f4361b4](https://github.com/seanthimons/concert/tree/f4361b4374072f1945f4688e9ae0cdfcd13ccbea))
- WR-03 invalidate toxval_output in cascade observers on edit
  ([8c9ade6](https://github.com/seanthimons/concert/tree/8c9ade6a69f715e4614fb10ba6633be8ba22d19d))
- WR-02 use jsonlite::toJSON for robust JS string escaping in onclick
  ([40ab68a](https://github.com/seanthimons/concert/tree/40ab68adc13fca23c8e4481d9b85cfdd332e49e2))
- WR-01 invalidate toxval_output after incremental harmonization
  ([8b57109](https://github.com/seanthimons/concert/tree/8b57109486f03528bb8698ba0866c73badd9de66))
- CR-01 expand curated_data rows to match harmonized rows via
  orig_row_id
  ([4804ff4](https://github.com/seanthimons/concert/tree/4804ff4f53bde3a9f311ea19770eb5bd3b6895a7))
- add bottom margin to Run Harmonization button
  ([64103d1](https://github.com/seanthimons/concert/tree/64103d12f93caf3484a7af72401b396eed580d78))
- cache regression tests use correct env + exercise production code
  ([2d6f087](https://github.com/seanthimons/concert/tree/2d6f087877f2f3651975aab35e0c300bfdd5825b))
- incremental harmonization + cache regressions from perf work
  ([37c8daa](https://github.com/seanthimons/concert/tree/37c8daaf0c0bd95a15c2cf7933955fc0353ea56d))
- replace transient notification with blocking modal in tag columns
  ([598d2e9](https://github.com/seanthimons/concert/tree/598d2e98bf6b2baa82afe8ffae3290b1eeb7541e))
- revise plans based on checker feedback
  ([a056a1e](https://github.com/seanthimons/concert/tree/a056a1eec0186400f7235b966ad0ebb8d980f026))
- revise plans based on checker feedback
  ([03078a1](https://github.com/seanthimons/concert/tree/03078a140c8272d2b85da61d10027905f0337f3c))
- revert tag_map validation - check keys (column names) not values (tag
  types)
  ([0d4e793](https://github.com/seanthimons/concert/tree/0d4e793c0918f88aa30191a61b6684b291230285))
- validate tag_map values (column names) not keys (semantic roles)
  ([c89a83d](https://github.com/seanthimons/concert/tree/c89a83d3509ac7a6c49713812d7d18c185d517f5))
- harden strip_reference_terms and add test coverage
  ([4739f37](https://github.com/seanthimons/concert/tree/4739f374491fac7c29a7bdd7fce1bb6a39372d3d))
- make dropdown filter choices data-driven
  ([67aa1e4](https://github.com/seanthimons/concert/tree/67aa1e46af53591bd07c309343eb64eb86a835cc))
- revise plans based on checker feedback
  ([50543c1](https://github.com/seanthimons/concert/tree/50543c10c1ed8b57a4ee0fbf9a4e5cf4548b0ca5))
- disable drifted ComptoxR functional use call, add TODO
  ([0199d9b](https://github.com/seanthimons/concert/tree/0199d9bab40042a25de8578f668178fdfe606944))
- add missing rhandsontable to package dependencies
  ([443ae4a](https://github.com/seanthimons/concert/tree/443ae4afae14a9f49eafc976e16bc7f0a336a71d))
- merge test task into implementation task for nyquist compliance
  ([ee105fe](https://github.com/seanthimons/concert/tree/ee105fe2a23a2663db46e2176fcd52f9bec25f22))
- remove inaccurate tdd attribute from Plan 14-01 Task 1
  ([6f04f95](https://github.com/seanthimons/concert/tree/6f04f95fd2154a62f773eb32526a955926e5bb24))
- replace nonexistent broom icon with magic/eraser
  ([fbb6b03](https://github.com/seanthimons/concert/tree/fbb6b03a0a98b1efd924b456a628bd9139116405))
- replace modal actionButton with JS-triggered button
  ([185e31f](https://github.com/seanthimons/concert/tree/185e31f55d4ee9b1b50d265e33a4a95e04ee21d1))
- read modal inputs before removeModal, validate selected rows
  ([65a3a1f](https://github.com/seanthimons/concert/tree/65a3a1f575715b32252919f71c9e49791b269b15))
- quote comma-containing chemical names in test CSV
  ([bdd9fd4](https://github.com/seanthimons/concert/tree/bdd9fd40c211067cea086eacc62674ee65b2caeb))
- re-enable apply_retag button after re-curation completes
  ([a1e1d2f](https://github.com/seanthimons/concert/tree/a1e1d2f1feb2223c94037dd76f161f52c4a7d7c9))
- show Validate All button and prevent table refresh on cell edit
  ([ebfbc81](https://github.com/seanthimons/concert/tree/ebfbc81622bf31965738c1ce59eeb73866f53edb))
- move prototype_pipeline.R out of R/ to stop Shiny auto-sourcing
  ([c15afc0](https://github.com/seanthimons/concert/tree/c15afc0d64f5019d5bc5c785dc3a1c5ba4bc49ce))
- replace all joins with direct vector indexing in map_results_to_rows
  ([acf2379](https://github.com/seanthimons/concert/tree/acf23799c5159551c17fcaf71407191c7325109e))
- eliminate many-to-many join in map_results_to_rows
  ([1abd8d9](https://github.com/seanthimons/concert/tree/1abd8d9cf081554ea0b0ca2884b8e7135d3c51b6))
- prevent table re-render on cell edit, fix queued state handling
  ([88994a9](https://github.com/seanthimons/concert/tree/88994a9b24305651f59b053f0e8dc2e88e7499a8))
- fix table reset on cell edit and row duplication
  ([ef8b4de](https://github.com/seanthimons/concert/tree/ef8b4defa814d2030e0f8dacfd1c139d4c0f5e21))
- fix app startup errors in Phase 8 code
  ([b644f52](https://github.com/seanthimons/concert/tree/b644f5251e0c02da978d15240c6026d3e4dced09))
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
  ([637ef6a](https://github.com/seanthimons/concert/tree/637ef6a82f06d794b9dabc5d1f8850d17098974e))
- migrate all tables from DT to reactable + reactable.extras
  ([1617577](https://github.com/seanthimons/concert/tree/1617577ff11b48a46f879f04e2803c8d7534f1bc))

#### Performance

- finish replay export optimization
  ([78be50f](https://github.com/seanthimons/concert/tree/78be50f090fce6c04c1da3e9697df1aed473691f))
- vectorize review-override capture for replay export
  ([f509692](https://github.com/seanthimons/concert/tree/f50969245c737e018126c92d46830bd7e966c410))
- vectorize + deduplicate curation results table
  ([5b64b30](https://github.com/seanthimons/concert/tree/5b64b3003dd6d2824f0c6e81d3c8b41d9f637f2f))
- address Codex performance findings
  ([c481d39](https://github.com/seanthimons/concert/tree/c481d39240f0538427d2a6ca5925ec5fb1e903e2))
- incremental harmonization + ppx O(k²) fix
  ([eb6155d](https://github.com/seanthimons/concert/tree/eb6155d7cc3dd49bfd5ab1085275a2fbb9fb809b))
- fix O(n²) list-growth in deduplicate_tagged_columns
  ([0874ece](https://github.com/seanthimons/concert/tree/0874ecee4e7d16a87c90e46b4ba1a03abfd2fd79))

#### Tests

- add extracted problem cases
  ([90cb32c](https://github.com/seanthimons/concert/tree/90cb32c3abb972ed95bcf2de7532a435249ca41d))
- record pending human verification
  ([7bda3ca](https://github.com/seanthimons/concert/tree/7bda3ca883b2a6560dca959e025c206e5e216c3b))
- record UAT findings — 2 issues (duplicate confidence column, broken
  search)
  ([4d176fc](https://github.com/seanthimons/concert/tree/4d176fc8b152eb70d31b3e145226c3737df6fbbf))
- persist human verification items as UAT
  ([7d9d18e](https://github.com/seanthimons/concert/tree/7d9d18e04def8a6dd91274f7ff6416be626aa103))
- complete UAT - 7 passed, 0 issues
  ([12dc12d](https://github.com/seanthimons/concert/tree/12dc12d48a614263ea62e724856142ce463cad69))
- persist human verification items as UAT
  ([a32f7a0](https://github.com/seanthimons/concert/tree/a32f7a049458476cc74b15c6e8c31b4457873f53))
- phase verification — 4/4 must-haves pass, human UAT pending
  ([bd19bb4](https://github.com/seanthimons/concert/tree/bd19bb43938de7a8608dd9e8b305704e829810f3))
- update HUMAN-UAT after gap closure — 5 items pending re-verification
  ([443fdf1](https://github.com/seanthimons/concert/tree/443fdf191378cee7e0bd2cc4e360a685db28a8c8))
- persist UAT findings — 6 gaps diagnosed
  ([341ff3d](https://github.com/seanthimons/concert/tree/341ff3dd8011efd141107753dda6ac35c35ccccb))
- complete UAT - 7 passed, 0 issues
  ([d3b74d3](https://github.com/seanthimons/concert/tree/d3b74d3ca14b18b6fbb4e94e6af6bc45a0a6cf72))
- persist human verification items as UAT
  ([c1d25bc](https://github.com/seanthimons/concert/tree/c1d25bc05d9bb000774c3f7815f3c0e47702802c))
- persist human verification items as UAT
  ([30ae2d5](https://github.com/seanthimons/concert/tree/30ae2d56781cd23814e46246d8c77a3097603c32))
- mark HUMAN-UAT complete — benchmark verified with real data
  ([1f15f48](https://github.com/seanthimons/concert/tree/1f15f48221b70c819aab8e3f9a51917968f11149))
- update human verification items after toggle wiring
  ([32b442d](https://github.com/seanthimons/concert/tree/32b442de6bfcae392d76a47b150950f226e637ce))
- complete UAT - 6 passed, 0 issues, 1 skipped
  ([fc62b5e](https://github.com/seanthimons/concert/tree/fc62b5eee449585ad203b06d7cbce3f334a104c2))
- persist human verification items as UAT
  ([be21a71](https://github.com/seanthimons/concert/tree/be21a714a75280d65ccb0def0aefd487b0091aae))
- post-hotfix UAT complete - 14/14 passed
  ([95be57b](https://github.com/seanthimons/concert/tree/95be57b266b1572573719a246d76c47a0152b9d5))
- complete UAT - 12 passed, 1 issue
  ([0a8e82e](https://github.com/seanthimons/concert/tree/0a8e82eb9f068d1523918e6509215240cc3325d7))
- partial UAT - blocking issue found
  ([a65be72](https://github.com/seanthimons/concert/tree/a65be725017471c4d13bf698a5823407ae646813))
- persist human verification items as UAT
  ([1e0cdb6](https://github.com/seanthimons/concert/tree/1e0cdb61aeb957050a3b36e5e0a3aa04a0f78fa5))
- complete UAT - 5 passed, 0 issues
  ([b07929d](https://github.com/seanthimons/concert/tree/b07929d3b21eca3a5e6bd41238a22b265fb13cbc))
- complete UAT - 6 passed, 0 issues
  ([6a3e057](https://github.com/seanthimons/concert/tree/6a3e05775cd6dd5c389772e9eef22d137cf08ddb))
- add guaranteed-error rows for unresolvable status testing
  ([8ba4879](https://github.com/seanthimons/concert/tree/8ba4879242529d03a710c52f2c9dbc850db2e4ea))
- complete UAT - 12 passed, 0 issues
  ([14e4813](https://github.com/seanthimons/concert/tree/14e48138ae2f8c531254ac0f2465c5859c05053d))

#### CI

- configure git user for release tags
  ([63f0472](https://github.com/seanthimons/concert/tree/63f04720abaf1d50f53bff0b955d2088a469ea56))
- align release tags with package versions
  ([07ed556](https://github.com/seanthimons/concert/tree/07ed55624a9c21fa0e99b8f3e38d90bf422a64b6))
- separate package build from release bump
  ([2525eee](https://github.com/seanthimons/concert/tree/2525eee8a3f730bb6ddee84cfcd5627df8447413))
- keep routine checks on release R
  ([d1de299](https://github.com/seanthimons/concert/tree/d1de2996afe25b5c5a72c84f0a673ec96a18f35d))
- skip CRAN-only checks in routine workflows
  ([1955892](https://github.com/seanthimons/concert/tree/19558928d8b12416633c7de1e167a98ed391e230))
- install ComptoxR for R workflows
  ([dd227d7](https://github.com/seanthimons/concert/tree/dd227d7ef44d6b53be419b61af97494dd1bdf1f7))
- release package after merged pull requests
  ([31dd683](https://github.com/seanthimons/concert/tree/31dd683938454afda0e08a91e5f3d405ebe52dbb))
- add gitleaks secret scanning
  ([16b5fa5](https://github.com/seanthimons/concert/tree/16b5fa58abe68dc375494eb622b09103da083ebe))

#### Docs

- add auto-tag analyte id bean
  ([172dd04](https://github.com/seanthimons/concert/tree/172dd044b1c298cd1c5b1ce7e69417b608470517))
- add Concert hex sticker assets
  ([884b8a3](https://github.com/seanthimons/concert/tree/884b8a36730ccd4f76834f4d3a9763bd23777ace))
- summarize row flagging execution
  ([07ae965](https://github.com/seanthimons/concert/tree/07ae96573d9a67079132a351f6025531edaf6ca2))
- create phase plan
  ([5fc0154](https://github.com/seanthimons/concert/tree/5fc0154aa1bd536de42d4da7eb9d161106954e5c))
- capture row flagging context
  ([af3e44b](https://github.com/seanthimons/concert/tree/af3e44b50e2b02b6e7d37e8b6c41f239ee247522))
- pattern map and state update for auto-resolve & suggest
  ([8f1f56b](https://github.com/seanthimons/concert/tree/8f1f56b4e50a405efa7af3fe56d99e7863c43f5c))
- create phase plan
  ([1e13bbf](https://github.com/seanthimons/concert/tree/1e13bbf15be609d37c83f16fd5960c6bdda61339))
- UI design contract
  ([ebe1fda](https://github.com/seanthimons/concert/tree/ebe1fda843b7157ccfedcd355de579dac39fd617))
- UI design contract for auto-resolve & suggest phase
  ([e57157d](https://github.com/seanthimons/concert/tree/e57157d08a85bb9113363ad73028b3293dafc617))
- record phase 50 context session
  ([64ca52b](https://github.com/seanthimons/concert/tree/64ca52bacd6f8bf59e6a5403160917d95f7fac7e))
- capture phase context
  ([3e4b93c](https://github.com/seanthimons/concert/tree/3e4b93cbb2899696ce7d26ee959275cca9240023))
- update verification after NAMESPACE fix
  ([2fba889](https://github.com/seanthimons/concert/tree/2fba889dd3da59e73e6d94dab16d8bc4492f52e5))
- add code review report
  ([3a21fb7](https://github.com/seanthimons/concert/tree/3a21fb7549738515789c0bd5b8039c89e82aabde))
- create phase plan
  ([3862d5c](https://github.com/seanthimons/concert/tree/3862d5c5333d684a04a574e2be7bfa84c9c6c311))
- research conflict scoring engine phase
  ([b34a3e6](https://github.com/seanthimons/concert/tree/b34a3e6d05f59380cf08166acec58df67145fe99))
- record phase 49 context session
  ([4f68c58](https://github.com/seanthimons/concert/tree/4f68c58c070f77fb58288b8e31782d1491287561))
- capture phase context
  ([3546bba](https://github.com/seanthimons/concert/tree/3546bba7db18fe2d276227949ad0dbf0e95be1ce))
- create milestone v2.3 roadmap (4 phases)
  ([4468232](https://github.com/seanthimons/concert/tree/44682323652f8fa888cad93149e59abdb59ae721))
- define milestone v2.3 requirements
  ([cdaba4c](https://github.com/seanthimons/concert/tree/cdaba4cb11297e72bd7497143f0733f25d422e02))
- start milestone v2.3 Curation Intelligence
  ([47a1eb8](https://github.com/seanthimons/concert/tree/47a1eb8ff3c1642d060a7b1f79b28132cef0bd3b))
- update state after gap closure planning (5 plans)
  ([4b1df18](https://github.com/seanthimons/concert/tree/4b1df181600ab42f1cffe65c70b35e39fac28fd3))
- create UAT gap closure plan for duplicate column + broken search
  ([71dfd6f](https://github.com/seanthimons/concert/tree/71dfd6f2b723cc42b0f6c00a6bf1cc2e1e0b63a7))
- re-verification — all 5 must-haves verified, human testing needed
  ([f9cb409](https://github.com/seanthimons/concert/tree/f9cb40900e43a5e62cfc591a8fe02795f233a811))
- add code review report
  ([546d306](https://github.com/seanthimons/concert/tree/546d306c1aa181a2b492de9bedabd5a034db5abb))
- add gap closure plan 04 for CR-01, WR-02, WR-01, IN-02
  ([d8f383c](https://github.com/seanthimons/concert/tree/d8f383c1e08c2b34a836e5d0ba6193cbb8db8ade))
- create gap closure plan 04 for CR-01, WR-02, WR-01, IN-02 fixes
  ([9173ef2](https://github.com/seanthimons/concert/tree/9173ef2843e0ccbc509e8239ec3481a4e4faed55))
- re-verification — gaps found from code review findings
  ([ce792f3](https://github.com/seanthimons/concert/tree/ce792f336215b1dda9c7532c38d954ba5127fe50))
- add code review report
  ([c2de254](https://github.com/seanthimons/concert/tree/c2de254db71477e06e25fccc46f0610c838004de))
- create gap closure plan for wqx_confidence propagation
  ([6ad2330](https://github.com/seanthimons/concert/tree/6ad2330ec271dc77572a864847db013c7f31ea73))
- add verification report — gaps found
  ([29a3995](https://github.com/seanthimons/concert/tree/29a399558b943228be771758e7b1e584386458e2))
- add code review report
  ([29681df](https://github.com/seanthimons/concert/tree/29681df9b1365aef045681fa65b5a41325629824))
- add pattern map and update state for planning
  ([d3efb98](https://github.com/seanthimons/concert/tree/d3efb98f739625614189fff36ef62b4e7e62c4d3))
- create phase plan
  ([f543933](https://github.com/seanthimons/concert/tree/f543933c6f15970d75d3593f7af82396b93a2191))
- research phase domain
  ([dd3040a](https://github.com/seanthimons/concert/tree/dd3040a16fdb8005bab00533e2d0c8d4ec821a07))
- UI design contract
  ([513ed4a](https://github.com/seanthimons/concert/tree/513ed4ad93fb6f91aeeb78e459a3df33a1c22996))
- UI design contract
  ([d6f7bee](https://github.com/seanthimons/concert/tree/d6f7bee5d675cd69d8e492175a1f8b156c264f99))
- record phase 48 context session
  ([409fb8b](https://github.com/seanthimons/concert/tree/409fb8b43a6d465abd083f126d8567ae7f36cd86))
- capture phase context
  ([02830c7](https://github.com/seanthimons/concert/tree/02830c7176bba95f97fbcc758d7c36f0ab61e96d))
- complete UAT and transition to Phase 48
  ([04703b9](https://github.com/seanthimons/concert/tree/04703b979485375c28c034a3b4608c3d6d23528b))
- add phase verification (human_needed)
  ([db6bb9b](https://github.com/seanthimons/concert/tree/db6bb9b30060d7df9bb8a3a8cdb8cc3a3aaf622f))
- add code review (clean)
  ([19d593a](https://github.com/seanthimons/concert/tree/19d593a55216c485415f0564f0bee7630e53af32))
- add research, validation, patterns, and plans
  ([665cb4a](https://github.com/seanthimons/concert/tree/665cb4a4340e11f7352c42f8879911e8125635b5))
- create phase plan (2 plans, 2 waves)
  ([af49064](https://github.com/seanthimons/concert/tree/af49064f3c458424c4b48b882c29a993327ca503))
- research pipeline reorder, threshold control, starts-with toggle
  ([cc80fed](https://github.com/seanthimons/concert/tree/cc80fede20348ea8e438b43f24734cb4265e3cd6))
- record phase 47 context session
  ([d8e579f](https://github.com/seanthimons/concert/tree/d8e579f4909a3015fed7625f2029e3736a3ac806))
- capture phase context
  ([637534a](https://github.com/seanthimons/concert/tree/637534a1dc6e307a6e716735758cdeddce10bd97))
- create milestone v2.2 roadmap (2 phases)
  ([3e390a3](https://github.com/seanthimons/concert/tree/3e390a36f9afe7c79dbd4a0adf40fe301ca49111))
- define milestone v2.2 requirements
  ([3e260a7](https://github.com/seanthimons/concert/tree/3e260a75ef78c0adb82d22dbd99db12a2728bbc8))
- start milestone v2.2 WQX Pipeline Refinement
  ([cb021f7](https://github.com/seanthimons/concert/tree/cb021f7946cf73fbcf2398e74f93eb3728c9a756))
- add code review report
  ([296f038](https://github.com/seanthimons/concert/tree/296f038ed03190f2621073aee0a20e779fbd7429))
- create phase plan for WQX UI display fixes
  ([ca22d8b](https://github.com/seanthimons/concert/tree/ca22d8b017f7271fd521c18b8387ddc960b9912a))
- add gap closure phases 46-47
  ([441a71a](https://github.com/seanthimons/concert/tree/441a71a6b8fefe354c707befaf2827da94dd6579))
- add code review report
  ([09acee1](https://github.com/seanthimons/concert/tree/09acee1bf946c8722a0bece34d0c05cb5c949526))
- create phase plan
  ([bc5fda3](https://github.com/seanthimons/concert/tree/bc5fda394b6d0b28f8ce36c3e4033c2bc9d05c58))
- record phase 45 context session
  ([5aa101e](https://github.com/seanthimons/concert/tree/5aa101ee13cae178b9af18c09d1011e8073a1963))
- capture phase context
  ([60b8981](https://github.com/seanthimons/concert/tree/60b898190208d4c241596a3aff2285d9a129a968))
- add phase verification report
  ([efef705](https://github.com/seanthimons/concert/tree/efef705e7680749074192f5fd204d5fd56ce39b4))
- add code review report
  ([bf0b8a4](https://github.com/seanthimons/concert/tree/bf0b8a48adb9246c3a5915cf66181a26ac4a5d35))
- plan matching engine prototype phase
  ([57ea2e7](https://github.com/seanthimons/concert/tree/57ea2e769604bce3ab1496b6c4a4b050d1cf446f))
- create phase plan — 2 plans, 2 waves
  ([b2cacda](https://github.com/seanthimons/concert/tree/b2cacdaaed9d2e2847070bed5953964843f9e7a0))
- record phase 44 context session
  ([93076d1](https://github.com/seanthimons/concert/tree/93076d15196b21881b19b2ea014f71fbcd0fdb99))
- capture phase context
  ([ffd0685](https://github.com/seanthimons/concert/tree/ffd0685a6fe0f90261e32661880ae01c41e4abbc))
- create phase plan for WQX dictionary
  ([7f60880](https://github.com/seanthimons/concert/tree/7f60880e06893f452e7fe71034bd340ad5acc014))
- research wqx dictionary phase domain
  ([fc1a7c7](https://github.com/seanthimons/concert/tree/fc1a7c721087c4b230e84af9bc4fe91caf3ce108))
- record phase 43 context session
  ([3467cca](https://github.com/seanthimons/concert/tree/3467cca494ef07ff58c2b2bfdf2b7d5dd8b22354))
- capture phase context
  ([63f3d78](https://github.com/seanthimons/concert/tree/63f3d788e664034b9a620a6f7ecf64783eabcd47))
- create milestone v2.1 roadmap (3 phases)
  ([603739a](https://github.com/seanthimons/concert/tree/603739a76cd070ed7a9c972dda250c8d6b702816))
- define milestone v2.1 requirements
  ([516914d](https://github.com/seanthimons/concert/tree/516914d22b74b4044f14d5907ade5425f7d007cd))
- start milestone v2.1 WQX Parameter Harmonization
  ([eb4ed27](https://github.com/seanthimons/concert/tree/eb4ed2750fd3f742ca28ef50c39926d6be18f398))
- add code review report
  ([1eb3c37](https://github.com/seanthimons/concert/tree/1eb3c37355c6b55f90755f19593027558fa55859))
- update state after gap closure planning
  ([5064599](https://github.com/seanthimons/concert/tree/506459956524375e43a68f1225d1bad53bded9eb))
- create gap closure plans for 6 UAT gaps
  ([fa090e8](https://github.com/seanthimons/concert/tree/fa090e8e8c1c7e0839053a0ee85f8474ddc1ce08))
- add research, patterns, and validation artifacts
  ([8b47928](https://github.com/seanthimons/concert/tree/8b47928d5c1a4eb2772fbc60b5ee71d67c0491c4))
- create phase plan — pre-flight modal + media editor
  ([fbd4809](https://github.com/seanthimons/concert/tree/fbd4809000fecd2f00c33ac26b1e61b14d20c659))
- UI design contract
  ([1d4982e](https://github.com/seanthimons/concert/tree/1d4982ee91d498532742f89d5e31210bbc7b6e8d))
- record phase 42 context session
  ([0fd55d5](https://github.com/seanthimons/concert/tree/0fd55d54e41cc51a6a5cc2a52eee01af1e143a81))
- capture phase context
  ([74d3833](https://github.com/seanthimons/concert/tree/74d383322c6f516e33227234953c6877d1341292))
- add post-gap-closure code review report
  ([bab859d](https://github.com/seanthimons/concert/tree/bab859da28fa415e45eae5974268960e2ce26a33))
- update STATE.md after gap-closure planning
  ([9dc04a8](https://github.com/seanthimons/concert/tree/9dc04a8cdc9172a079422888e5b3085a50f0afe9))
- create gap closure plan for pipeline wiring fixes
  ([1b0a845](https://github.com/seanthimons/concert/tree/1b0a845cb67090fa1dcdb6eef3a90ab54e87e429))
- add code review report
  ([db735e5](https://github.com/seanthimons/concert/tree/db735e5ffa003c108fb18f28b3685a1f26e15732))
- complete phase planning with D-19 dedup_step fix
  ([829d159](https://github.com/seanthimons/concert/tree/829d159c36933d438fefc909e3a4d26732fb2d35))
- create phase plan
  ([bebfd60](https://github.com/seanthimons/concert/tree/bebfd607b3305fc4759d22689f4ad2fc9ee29631))
- record phase 41 context session
  ([24308cf](https://github.com/seanthimons/concert/tree/24308cf530bbe258d4b466f7d13dd5db12e52bae))
- capture phase context
  ([256f203](https://github.com/seanthimons/concert/tree/256f203c811b6b4eb1cee340363677b22affa084))
- add code review report
  ([d6aadf3](https://github.com/seanthimons/concert/tree/d6aadf3803612eddab2f687bb4d53664bec15169))
- create phase plan — date parser
  ([ef3ced4](https://github.com/seanthimons/concert/tree/ef3ced4849a49729370aa504d8d5f6d02b3bd96c))
- add validation strategy
  ([2ed198d](https://github.com/seanthimons/concert/tree/2ed198d71d4a5d0c2a4430e7b6fe6c8dac4935cb))
- research phase domain — lubridate date parsing
  ([ecb7287](https://github.com/seanthimons/concert/tree/ecb728753e9fb8378cc7e2dc77b25c0e78fcf78d))
- fix typography contract to declare exactly 2 weights
  ([bc585bd](https://github.com/seanthimons/concert/tree/bc585bdf1267c6e147bf52b440466f6b24bb89fe))
- UI design contract
  ([0fe6600](https://github.com/seanthimons/concert/tree/0fe660019859811186f60f1a5d3bf32d5358f5c6))
- record phase 40 context session
  ([216152f](https://github.com/seanthimons/concert/tree/216152f36c211351c27d88b9f104b514035ddda0))
- capture phase context
  ([931d051](https://github.com/seanthimons/concert/tree/931d05160f0559a4ecf88cdc3c997861bd4a34e6))
- add code review report
  ([065fe09](https://github.com/seanthimons/concert/tree/065fe090d091351ea023059fff2ca15f26934af0))
- create phase plan for duration conversion
  ([a2beec0](https://github.com/seanthimons/concert/tree/a2beec030d6624d58e990034c5ba1743fa17a82f))
- add pattern mapping for duration conversion
  ([f57a7c3](https://github.com/seanthimons/concert/tree/f57a7c3288fbd026e77701e2845b94df83756a79))
- research phase domain for duration conversion
  ([f239cea](https://github.com/seanthimons/concert/tree/f239cea2f6e9171ea6e30d861e2e9b426087adf9))
- record phase 39 context session
  ([b0332a0](https://github.com/seanthimons/concert/tree/b0332a05c2b039d682a1841d6e71f811e38992a5))
- capture phase context
  ([2444ab3](https://github.com/seanthimons/concert/tree/2444ab39713593bb6d16d4f2165323a27cbacef8))
- populate benchmark results with real timing data
  ([d627af4](https://github.com/seanthimons/concert/tree/d627af4c79d8c16863c5b5e4903d964060b48920))
- update verification after use_dedup toggle wiring
  ([cf82b82](https://github.com/seanthimons/concert/tree/cf82b824356b755e193982bc5e46363590a8ce5a))
- add code review report
  ([0db0d8a](https://github.com/seanthimons/concert/tree/0db0d8a5e505053c5fa34b812f3c76bcbc669625))
- update state after replan — 1 plan, ready to execute
  ([9d0b4bf](https://github.com/seanthimons/concert/tree/9d0b4bffc7d477a1fbecd3f5376056d944e31842))
- replan phase – 1 plan to wire use_dedup toggle bypass
  ([8e28cd2](https://github.com/seanthimons/concert/tree/8e28cd26d60ea3aa2112d3bd70ec69319bf38015))
- add code review fix report
  ([bb1a9e9](https://github.com/seanthimons/concert/tree/bb1a9e989ae742c9fe09fec89e77b0fa024ef422))
- create phase plan – 2 plans in 2 waves
  ([c554eed](https://github.com/seanthimons/concert/tree/c554eedb0c82f0b219235313bf424a4c7d5f0203))
- record phase 38 context session
  ([2650222](https://github.com/seanthimons/concert/tree/2650222f90ce59338ddd693cec1969b470a3eb09))
- capture phase context
  ([039723b](https://github.com/seanthimons/concert/tree/039723b0eeceae466d23baabd0ec55e1384aba1b))
- add pattern map and update state to planned
  ([1e4a0bf](https://github.com/seanthimons/concert/tree/1e4a0bfb0fc37bf132721e6fb0e544eb51d3e8be))
- create phase plan — 4 plans in 3 waves
  ([ea433e8](https://github.com/seanthimons/concert/tree/ea433e868bd9969067323068ff249cd97c909b86))
- record phase 37 context session
  ([6ba7762](https://github.com/seanthimons/concert/tree/6ba7762c10b6f72e8d852132e4734cb2053d8e22))
- capture phase context
  ([e675992](https://github.com/seanthimons/concert/tree/e67599265ba351f1694acf9afee1c9f3d2f4cc94))
- create milestone v2.0 roadmap (6 phases)
  ([c0cc624](https://github.com/seanthimons/concert/tree/c0cc6240ac9f4efd3d99bc169f5e56c0dc8140bd))
- define milestone v2.0 requirements
  ([3c49887](https://github.com/seanthimons/concert/tree/3c49887981408d6955d2b852665b4bb36b6e8451))
- v2.0 research — stack, features, architecture, pitfalls, summary
  ([4e99fc1](https://github.com/seanthimons/concert/tree/4e99fc1b398692459d6c0a70c0a448fae86b5bb1))
- start milestone v2.0 Pipeline Performance & Date/Media Harmonization
  ([231dc28](https://github.com/seanthimons/concert/tree/231dc28542f5bd59757f987a4a0376487d85137c))
- add code review fix report
  ([28fd11b](https://github.com/seanthimons/concert/tree/28fd11bd1bfd952c52ce9f3d35450642ea6986ea))
- add code review report
  ([802b5ba](https://github.com/seanthimons/concert/tree/802b5baa649b2857fa1d67cf22e5958d66bfb7c5))
- plan phase — wire ToxVal schema in Shiny path
  ([578a523](https://github.com/seanthimons/concert/tree/578a523a1a774ef3cec1245c4940c720facbc47e))
- create phase plan — wire ToxVal schema in Shiny path
  ([167ee91](https://github.com/seanthimons/concert/tree/167ee91efe4c21102a3c1f8b7468927f27be6d93))
- record phase 36 context session
  ([75fab25](https://github.com/seanthimons/concert/tree/75fab25d6f29fd6f577f608c66226815f6e85f19))
- capture phase context
  ([ac7a1ba](https://github.com/seanthimons/concert/tree/ac7a1ba823169de9467bcdf5f0fb57561a1969c5))
- add gap closure Phase 36 — Wire ToxVal Schema in Shiny Path
  ([9928c65](https://github.com/seanthimons/concert/tree/9928c656444cc7cb9db92d2be6548f5f8b2fa808))
- record phase 35 completion
  ([0b23d75](https://github.com/seanthimons/concert/tree/0b23d7538d366d2dac803f15f68ac5ff7e424a09))
- UI design contract
  ([2792916](https://github.com/seanthimons/concert/tree/27929163719d407638a78f3d840da04d062fe3e0))
- record phase 35 planning completion
  ([0a5a216](https://github.com/seanthimons/concert/tree/0a5a21610bfc116d77f895d212fb9483e86660bc))
- create phase plans for export extension + headless
  ([7ce1826](https://github.com/seanthimons/concert/tree/7ce18267bc916c538ab5125dc269ac95ce29d6e0))
- record phase 35 context session
  ([92331c6](https://github.com/seanthimons/concert/tree/92331c68955234f4b8323b264c0e921ce815cb5f))
- capture phase context
  ([a71edc8](https://github.com/seanthimons/concert/tree/a71edc8cfa635861c41cce7c9e952c4a7250a8b3))
- add gap-closure plan for cascade reset UX + perf
  ([0c6dce9](https://github.com/seanthimons/concert/tree/0c6dce9a764b8f9539500f59900b018ebfa6127c))
- diagnose UAT gap - modal reverted in working tree
  ([9e326c7](https://github.com/seanthimons/concert/tree/9e326c72b4176591194109c77f24f554f80cd3cc))
- add harmonize pattern map and boot-test note
  ([0211e86](https://github.com/seanthimons/concert/tree/0211e866bc499a7d14914c868e637f027ab2a9b6))
- create phase plan
  ([d8465e8](https://github.com/seanthimons/concert/tree/d8465e8a3120ff36d0c97a9b772d53ab2cd9cdc2))
- add validation strategy
  ([b5610dd](https://github.com/seanthimons/concert/tree/b5610dd84359e9067c837d05294c4d5642c3f10e))
- research phase domain
  ([1025c7d](https://github.com/seanthimons/concert/tree/1025c7ddab6505c86b635402095bb876a4dfc8d7))
- fix UI-SPEC checker blocks and flag
  ([be25e03](https://github.com/seanthimons/concert/tree/be25e0391107411448a194eaed8a5d51301f06a4))
- UI design contract for Harmonize Tab Module
  ([7965e29](https://github.com/seanthimons/concert/tree/7965e29456b880cb95139954afe98a79ef6a3ee5))
- commit outstanding phase 31.5 artifacts and plan updates
  ([4e9718d](https://github.com/seanthimons/concert/tree/4e9718d6a40fdaa2662d55244b45aa90e664e01c))
- record phase 34 context session
  ([5a91ffb](https://github.com/seanthimons/concert/tree/5a91ffb05f229b1b0f2c8b339ba18c2d369345af))
- capture phase context
  ([09f8a66](https://github.com/seanthimons/concert/tree/09f8a666b6dd62d4ad1c622415c879c5ee5c73ed))
- record phase 33 context session
  ([d9f23f3](https://github.com/seanthimons/concert/tree/d9f23f3752767a90797a9db10d03dcc00d6bba98))
- capture phase context
  ([57e5e6b](https://github.com/seanthimons/concert/tree/57e5e6b4052d8201be3c93e9ef0b5eb4147cea31))
- create unit harmonization engine plan
  ([4939862](https://github.com/seanthimons/concert/tree/49398620dd0052bb63cfbca8af9ef1b75945c297))
- record phase 31 context session
  ([2c9604f](https://github.com/seanthimons/concert/tree/2c9604f6c0c9380409b8622a35deea1fcfa27581))
- capture phase context
  ([759d8d3](https://github.com/seanthimons/concert/tree/759d8d3bda39e967479298677000c426de20cb9e))
- create phase plan for numeric result parser
  ([4eb57c2](https://github.com/seanthimons/concert/tree/4eb57c218c4d05892a350266dfd23385d6053bde))
- record phase 30 context session
  ([85c2ac7](https://github.com/seanthimons/concert/tree/85c2ac740e10cfb7babd170dfcfdbaa02494f0e3))
- capture phase context
  ([c1d005f](https://github.com/seanthimons/concert/tree/c1d005f0dd18bc1ed6ed18c2d1575168eabe665b))
- create phase plans for static data foundations
  ([c20e8c3](https://github.com/seanthimons/concert/tree/c20e8c3f5eacf66f7e59789e0c015de6bcb35e01))
- record phase 29 context session
  ([46a0e18](https://github.com/seanthimons/concert/tree/46a0e18d03f389b150bd20e451898f86df6fe050))
- capture phase context
  ([bc711fc](https://github.com/seanthimons/concert/tree/bc711fc917782b7f0cfc1f534a9133c1743ebecb))
- complete project research
  ([b387ebb](https://github.com/seanthimons/concert/tree/b387ebb78f3dd2d064b8e3fbbac97b7f9fc6cd0f))
- start milestone v1.9 Number and Unit Coercion Harmonization
  ([4ad50c3](https://github.com/seanthimons/concert/tree/4ad50c3f6f4f1bef13314901c1100ed79e4a3429))
- fix key-count to 5 keys, clarify empty \_snaps deletion
  ([e2aaf08](https://github.com/seanthimons/concert/tree/e2aaf0888af70831814078d06467bc9d41291f87))
- create phase plan
  ([f40bbee](https://github.com/seanthimons/concert/tree/f40bbee0e8dbd4db0fcfa8856f9a4cc2e8c51785))
- complete phase - all HDL requirements verified via human UAT
  ([100dbdf](https://github.com/seanthimons/concert/tree/100dbdfddfce375e96425eb04f9bfb781820c0cc))
- create phase plan
  ([45a7282](https://github.com/seanthimons/concert/tree/45a7282915acbce68864836da71d70b9c2f88da9))
- add validation strategy
  ([d72aec9](https://github.com/seanthimons/concert/tree/d72aec9aedcd7aa60140a9e373565a005f15c11e))
- research headless pipeline phase
  ([ecd65f8](https://github.com/seanthimons/concert/tree/ecd65f82913fd9137b38771b4f578de3bdec8ea4))
- record phase 27 context session
  ([d02b83d](https://github.com/seanthimons/concert/tree/d02b83d867a2506e25db1eed69330a6a62b73e4f))
- capture phase context
  ([e649cb8](https://github.com/seanthimons/concert/tree/e649cb8490fcc2f95814de34710c4aa14c087b42))
- create phase plan for app relocation
  ([2eb1fb3](https://github.com/seanthimons/concert/tree/2eb1fb32ecf8372b9b88c00d9f8d04aa0176e229))
- create source file cleanup phase plan
  ([5e6e54f](https://github.com/seanthimons/concert/tree/5e6e54f3af4f47d12d8a74be3bef9f94d99558c5))
- record phase 25 context session
  ([4b089a2](https://github.com/seanthimons/concert/tree/4b089a2cccbdfa283bd555e5650dbf6583d06e73))
- capture phase context
  ([f1f62c5](https://github.com/seanthimons/concert/tree/f1f62c52474c699fb0495d3d0d0102f1b4d9a187))
- create phase plan
  ([8aefa89](https://github.com/seanthimons/concert/tree/8aefa89ff2d2a4fe159048758832db44756e4334))
- research phase package-scaffolding
  ([1911feb](https://github.com/seanthimons/concert/tree/1911febc1dc4401db4976a7cc423c1a47d8aec86))
- create milestone v1.8 roadmap (5 phases)
  ([fc2ee49](https://github.com/seanthimons/concert/tree/fc2ee490c85b3627c8c295d6aa8d1a615c5189fb))
- define milestone v1.8 requirements
  ([dce51ce](https://github.com/seanthimons/concert/tree/dce51ce994ea1c6da2fcb5d08fd29aaca580c6af))
- start milestone v1.8 R Package Migration
  ([bad61dc](https://github.com/seanthimons/concert/tree/bad61dc391b90beabd9f877182395e5c64f60e9e))
- v1.7 milestone audit — tech_debt status, 8/8 requirements satisfied
  ([b221e6b](https://github.com/seanthimons/concert/tree/b221e6b37bf33575f0646a2d4a955a0a81d9aa57))
- create phase plan — 2 plans for isotope cleaning, chiral protection,
  multi-analyte flagging
  ([4ff34cf](https://github.com/seanthimons/concert/tree/4ff34cf79074de10ec5bf6a0103821c50805334a))
- create phase plan
  ([ca5eb1c](https://github.com/seanthimons/concert/tree/ca5eb1c42d1d69bd125da0d300e97a9afd6c8ffa))
- UI design contract for Phase 22 UI Polish
  ([40fbe53](https://github.com/seanthimons/concert/tree/40fbe530977112434c1785e2d69f38ee5b50718d))
- research phase domain
  ([b506f67](https://github.com/seanthimons/concert/tree/b506f6741b3a8af1ad27dfdb40c5c614a4268511))
- record phase 22 context session
  ([79aa7a4](https://github.com/seanthimons/concert/tree/79aa7a40d5d741599e942ab6f7624ca4b25b1362))
- capture phase context
  ([5d2a1ab](https://github.com/seanthimons/concert/tree/5d2a1ab8a7b23cb599fb076b37f197568cde5a3a))
- create milestone v1.7 roadmap (2 phases)
  ([24ebf35](https://github.com/seanthimons/concert/tree/24ebf35e195e57453c8f75c0d6f7d8ec80ca14b9))
- define milestone v1.7 requirements
  ([57e0fbc](https://github.com/seanthimons/concert/tree/57e0fbca64c1aa4230ae64ed19dfd5e214c6de33))
- start milestone v1.7 UI Polish & Isotope Cleaning
  ([26a0b52](https://github.com/seanthimons/concert/tree/26a0b524aba877444788057393a1813fdeab787d))
- update retrospective for v1.6
  ([86b1134](https://github.com/seanthimons/concert/tree/86b11341a5fd92973d14a8dd6942c915887db2b2))
- create phase plan
  ([6748909](https://github.com/seanthimons/concert/tree/674890925952a26d0d53c9a1c13d932787cd101b))
- record phase 21 context session
  ([4c57592](https://github.com/seanthimons/concert/tree/4c57592be808f0986c6e86e273bf0f987a580e82))
- capture phase context
  ([34cf218](https://github.com/seanthimons/concert/tree/34cf218e3e6e62b175a3c33c0597f5c933ee68c5))
- create phase plan for roman numeral handling
  ([abc78c8](https://github.com/seanthimons/concert/tree/abc78c8608de3172d0bf59488228b18fb02526a6))
- record phase 20 context session
  ([5dc7a3f](https://github.com/seanthimons/concert/tree/5dc7a3f485736e392a71ffb81e345a6510551c9a))
- capture phase context
  ([6b13e56](https://github.com/seanthimons/concert/tree/6b13e5640b4de26780a59e4c9c7230817dc9adbf))
- create phase plan
  ([1f8f0b1](https://github.com/seanthimons/concert/tree/1f8f0b119702a5e824dcf1e9d9a053b45b8c9ead))
- record phase 19 context session
  ([26b82b4](https://github.com/seanthimons/concert/tree/26b82b487e05b91d21914ae2bb7be7c8fef817c8))
- capture phase context
  ([8201910](https://github.com/seanthimons/concert/tree/820191096df1bee91e9157bf882795dab8e02c36))
- create milestone v1.6 roadmap (3 phases)
  ([228b9cf](https://github.com/seanthimons/concert/tree/228b9cfc2968a3370aa929c575526eca24fb2359))
- define milestone v1.6 requirements
  ([2ab76a8](https://github.com/seanthimons/concert/tree/2ab76a8ce80ce4f1ff989d032ece44e421f33af1))
- start milestone v1.6 Cleaning Ruleset Fixes
  ([1f2628a](https://github.com/seanthimons/concert/tree/1f2628a16baa427b52d609b9d9ce14338c742bbe))
- create phase plan for comparison modal UI
  ([6091e30](https://github.com/seanthimons/concert/tree/6091e306a5445370e15acb27768db6fa885a23e0))
- capture phase context
  ([d5ce50d](https://github.com/seanthimons/concert/tree/d5ce50d2dd3abed9c72585ab7302d1221aea9e06))
- create phase plan for enrichment pipeline
  ([9160af5](https://github.com/seanthimons/concert/tree/9160af5cdb9ab6005b5b46c8a37cca2418a381be))
- capture phase context
  ([63405f4](https://github.com/seanthimons/concert/tree/63405f429a036f8f124d2d200f5240426a65d8f9))
- update retrospective for v1.4
  ([95f522c](https://github.com/seanthimons/concert/tree/95f522c0641a5243183ff5eab71e8d4361a67272))
- create phase plan for cleaning pipeline bug fixes
  ([19f0705](https://github.com/seanthimons/concert/tree/19f0705ed72f7f019870edbfbf4fe2811fe3419b))
- create milestone v1.4 roadmap (1 phase)
  ([74f8151](https://github.com/seanthimons/concert/tree/74f8151b31e02919153de545b441c2d51da42d76))
- define milestone v1.4 requirements
  ([ce7d9b9](https://github.com/seanthimons/concert/tree/ce7d9b9fec35cdd3a18af6f61e0f63ff0744d356))
- start milestone v1.4 Cleaning Pipeline Fixes
  ([bcc7398](https://github.com/seanthimons/concert/tree/bcc73982dc20906008267ca551413b87be248e0c))
- close v1.3 milestone audit gaps
  ([2368988](https://github.com/seanthimons/concert/tree/2368988f9106a0213112dca77094163da53c041d))
- create gap closure plan for icon fix and POST-01 documentation
  ([54df334](https://github.com/seanthimons/concert/tree/54df3349544b0056c6294e5332d971cf1a555e50))
- create phase plan for post-curation QC
  ([219fa38](https://github.com/seanthimons/concert/tree/219fa386d1bc17dd42e2f67f6204c3a1b24ab97f))
- add research and validation strategy
  ([dcfe8d9](https://github.com/seanthimons/concert/tree/dcfe8d9bfceaaf6e874a4c54b68eab6c101183cf))
- research phase domain
  ([922cadf](https://github.com/seanthimons/concert/tree/922cadfec10dac7b36245f1293fd9efc6ad38ec8))
- record phase 15 context session
  ([576580f](https://github.com/seanthimons/concert/tree/576580f771bdf50d81c7b45ab2812a3a926c8e70))
- capture phase context
  ([6b25911](https://github.com/seanthimons/concert/tree/6b259118fd5a29534a5fcb6ac2194af1e9846775))
- add Phase 14 UAT findings to TODO
  ([864e728](https://github.com/seanthimons/concert/tree/864e728b16e0b703b83cb0baa1c9b18263b7f347))
- create phase plan for multi-sheet export and re-import
  ([c5f85ed](https://github.com/seanthimons/concert/tree/c5f85edd7c8541e5564bc6a689a0f25dc4cf4bea))
- research phase domain
  ([10d165d](https://github.com/seanthimons/concert/tree/10d165dc27f1152c220752f19982d5926c0dc610))
- record phase 14 context session
  ([b5e7a3c](https://github.com/seanthimons/concert/tree/b5e7a3cd518d10b9c12e4862fe13c08ea8310405))
- capture phase context
  ([0065097](https://github.com/seanthimons/concert/tree/006509753a5960a00af72aaa8e26405f4780835c))
- create phase plan for reference filters and editable lists
  ([866a590](https://github.com/seanthimons/concert/tree/866a5908a5f29d719d83a860ef9c15e1928815d8))
- research reference filters and editable lists
  ([ab5d14c](https://github.com/seanthimons/concert/tree/ab5d14cf2472171388960403687185b39b1056ba))
- record phase 13 context session
  ([99127ce](https://github.com/seanthimons/concert/tree/99127ce0265f13d9494c48c08b2b7f51d0215165))
- capture phase context
  ([837665b](https://github.com/seanthimons/concert/tree/837665bcafef4868d3bfc5bfc460e05bd0b7627e))
- mark phase 12 complete, update state and roadmap
  ([47fbea0](https://github.com/seanthimons/concert/tree/47fbea00ab9097cf23041ab8ca21f3979ee84aae))
- create phase plan for name cleaning
  ([3299627](https://github.com/seanthimons/concert/tree/32996270b402a1d088a501a1ccb812b96aa11ac7))
- add research and validation strategy for name cleaning
  ([addb919](https://github.com/seanthimons/concert/tree/addb919574cf4fb69a3cfa273243150ff5491276))
- research name cleaning domain
  ([ad1eba2](https://github.com/seanthimons/concert/tree/ad1eba2fa885853609317b17bc41ffab3040adec))
- record phase 12 context session
  ([eafb816](https://github.com/seanthimons/concert/tree/eafb816168038801df114048d0bb8c8c245db378))
- capture phase context for name cleaning
  ([d9d243d](https://github.com/seanthimons/concert/tree/d9d243d28ddde0e500d83debced97b0924f5f593))
- advance to Phase 12 after Phase 11 completion
  ([4619ed2](https://github.com/seanthimons/concert/tree/4619ed2a7baf8f76cb002d2a5369f684d70bb025))
- create phase plan for CAS pipeline
  ([141da06](https://github.com/seanthimons/concert/tree/141da06458f31048f023086ed70ee615199487d6))
- add research and validation strategy for CAS pipeline
  ([e1993a6](https://github.com/seanthimons/concert/tree/e1993a624ac2c92dbc0e3786bc48bcfb4edf7be3))
- research CAS pipeline domain
  ([6fd0adc](https://github.com/seanthimons/concert/tree/6fd0adce13ddca3697f5ed4acdcea71c21b622b2))
- update state after context gathering
  ([425a3c1](https://github.com/seanthimons/concert/tree/425a3c15535b5b3ae858f93134b454e1c35f2996))
- capture phase context for CAS pipeline
  ([a92da32](https://github.com/seanthimons/concert/tree/a92da329732070af5a86c0030d11633ea06b5ad3))
- create phase plan for foundation and clean data tab
  ([3d1f7c3](https://github.com/seanthimons/concert/tree/3d1f7c3ecbe7b6f1b2f69592e5be0efd4f896ca7))
- record phase 10 context session
  ([0cc2189](https://github.com/seanthimons/concert/tree/0cc21899201b70f552f549c9204e8d81952b6753))
- capture phase context
  ([cf7286b](https://github.com/seanthimons/concert/tree/cf7286bb8829daf391300b6e3ba4949fa44c3746))
- create phase plan
  ([7ede830](https://github.com/seanthimons/concert/tree/7ede830d347e325b6d6772dc8da3a25d6829ffde))
- research phase domain
  ([a336f1c](https://github.com/seanthimons/concert/tree/a336f1c7a25821eb7ab466553f30d0603814f0e0))
- capture phase context
  ([18e1429](https://github.com/seanthimons/concert/tree/18e14292db0fcb86cc9e5f79039a6a959b04753b))
- create milestone v1.3 roadmap (7 phases, 30 requirements)
  ([5e7f4b5](https://github.com/seanthimons/concert/tree/5e7f4b51d66bd48615e03aa18578b8746c8e8146))
- define milestone v1.3 requirements (30 requirements)
  ([ea224da](https://github.com/seanthimons/concert/tree/ea224daa9910c76c9a7316f8d5d2ac4f1baf03c5))
- complete project research
  ([93c3e1c](https://github.com/seanthimons/concert/tree/93c3e1cf9a374063484599535eaec090b9423497))
- start milestone v1.3 Data Cleaning Pipeline
  ([28ef419](https://github.com/seanthimons/concert/tree/28ef419d0546126e53b305003f02d5fbf9e99061))
- complete UAT — all 10 tests passed
  ([22616de](https://github.com/seanthimons/concert/tree/22616de5643e5d227350a1e56c14e911e4fb9a5a))
- complete phase research and planning
  ([f0e4b15](https://github.com/seanthimons/concert/tree/f0e4b15fe14e8fbc4aa2e5cd4b5a442c64c63b7b))
- create phase plan
  ([26a6221](https://github.com/seanthimons/concert/tree/26a622147ecb5173ab360482ecad83322bf2407b))
- research phase domain
  ([4aa9b1c](https://github.com/seanthimons/concert/tree/4aa9b1c715e7aacf5bf157fd8e4c2c6833d31ec1))
- complete phase execution and verification
  ([d0d204e](https://github.com/seanthimons/concert/tree/d0d204e9e62c4ceb68def677d7621c6aaca1de64))
- create phase plan
  ([849a6bd](https://github.com/seanthimons/concert/tree/849a6bd4df6387799afd9224d3b166f2dd100fd8))
- research phase domain
  ([b09df6d](https://github.com/seanthimons/concert/tree/b09df6dfd25935aa9b537d8df5b3ea8f2e8ab72c))
- capture phase context
  ([ff95c2f](https://github.com/seanthimons/concert/tree/ff95c2fc76fd62013c94511d7a8d007bb6162278))
- complete Phase 6 → Phase 7 transition
  ([421aab4](https://github.com/seanthimons/concert/tree/421aab4fc90ea38202b9d3f648a16d15283ee08d))
- create phase plan
  ([5ada13d](https://github.com/seanthimons/concert/tree/5ada13de5e448174c8a28e9530020edbae73e366))
- research search pipeline refinement
  ([a7d1aa2](https://github.com/seanthimons/concert/tree/a7d1aa27955f89dec15ec6ffaec54c53f30f71c4))
- capture phase context
  ([9636752](https://github.com/seanthimons/concert/tree/9636752ee7c8ae57dece67b06c84a30d1cfc28e4))
- create milestone v1.2 roadmap (3 phases)
  ([02f534f](https://github.com/seanthimons/concert/tree/02f534fcc298e72107a71e28a3724a1cc0ca3b36))
- define milestone v1.2 requirements
  ([c7e7140](https://github.com/seanthimons/concert/tree/c7e71409012fd510ab4a134df5463dad1c456516))
- complete v1.2 project research
  ([9ad68fd](https://github.com/seanthimons/concert/tree/9ad68fd2c08465eec5e5bd1a7428c00cf0fcfb33))
- start milestone v1.2 Curation Refinement
  ([006821a](https://github.com/seanthimons/concert/tree/006821a8e54720f9715c17cfa130124c6e437d61))
- capture todos - table column visibility and resolution dropdown
  context
  ([520636b](https://github.com/seanthimons/concert/tree/520636bee1c62972692ef732a073d22d1a7e204b))
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
  ([e9ea3bc](https://github.com/seanthimons/concert/tree/e9ea3bc4057785f1b8a0151fe0c73163daedddd2))

#### Other changes

- remove dead replay helper functions
  ([f136176](https://github.com/seanthimons/concert/tree/f136176b1fc77d5e2c0577d01cb5f7cbc0fc1330))
- record current repository state
  ([5bd3c57](https://github.com/seanthimons/concert/tree/5bd3c574738110e8469c605e3bb97c59123e5b3b))
- merge executor worktree (worktree-agent-a3db1caf)
  ([2468d62](https://github.com/seanthimons/concert/tree/2468d62e4f9db8bce785beedb43b77a556675c3d))
- complete v2.2 milestone close
  ([a711df0](https://github.com/seanthimons/concert/tree/a711df0213c04cb7b4b389dc9dfe3f898053c6d9))
- archive v2.2 milestone files
  ([da53df6](https://github.com/seanthimons/concert/tree/da53df6d6dfdbf637068cbe44fcf7926ebeb127e))
- remove REQUIREMENTS.md for v2.1 milestone
  ([a1d1bf8](https://github.com/seanthimons/concert/tree/a1d1bf818164477d39f6dee8fe68be003e67b89e))
- archive v2.1 milestone files
  ([dacb45f](https://github.com/seanthimons/concert/tree/dacb45f3d624b0d6cafcb4ab7577b1e83bfec154))
- merge executor worktree (worktree-agent-a6008678)
  ([4762825](https://github.com/seanthimons/concert/tree/47628258d2d4102d9dc6a1d0223b83b693eb26ac))
- archive v2.0 phase directories to milestones/
  ([c2d11ed](https://github.com/seanthimons/concert/tree/c2d11ed8046f20d19fd3f14aba3ab6a9f25f2fa3))
- remove REQUIREMENTS.md for v2.0 milestone
  ([a5900af](https://github.com/seanthimons/concert/tree/a5900afdc6c912aa6a7cdea42e5ecde72dd7bbac))
- archive v2.0 milestone files
  ([82e6163](https://github.com/seanthimons/concert/tree/82e6163005e56676be8a2bafb38a904dfeec4896))
- merge plan 42-05 gap closure (pre-flight progress + completion
  summary)
  ([297911b](https://github.com/seanthimons/concert/tree/297911b375f47b2b1a9ea79bcf8794198541e809))
- merge executor worktree (worktree-agent-a96aa76b)
  ([1309a60](https://github.com/seanthimons/concert/tree/1309a609cf8dff38497617753312d5210332cd2b))
- merge executor worktree (worktree-agent-ad6dd37b)
  ([66f3b5f](https://github.com/seanthimons/concert/tree/66f3b5fa3975236f320a99b12a8ff473e98cd625))
- merge executor worktree (worktree-agent-a9523e93)
  ([246e513](https://github.com/seanthimons/concert/tree/246e5137a9ff9502125dd70aea4ae2fad49592c6))
- remove embedded curation repo and add to gitignore
  ([e68ee8d](https://github.com/seanthimons/concert/tree/e68ee8de9b5af352c17675440830924e56fb841c))
- merge Phase 37 worktree (Plans 02-04) into main
  ([7c04bab](https://github.com/seanthimons/concert/tree/7c04babb5b4b8fec175ab31b44b609c7ed94ed96))
- merge executor worktree (worktree-agent-ace47a41)
  ([01f1228](https://github.com/seanthimons/concert/tree/01f12285b6a04e648c21109043e9e981142bb6ad))
- track .beans/ files in git
  ([1e83d70](https://github.com/seanthimons/concert/tree/1e83d700a709663f4d3507d137ff0a328d9327fd))
- migrate TODO.md to beans + GitHub Issues
  ([7925e33](https://github.com/seanthimons/concert/tree/7925e337a6e0702cd892eb4f85289315f8d77f7a))
- add planning docs, test data, and update gitignore
  ([98b779d](https://github.com/seanthimons/concert/tree/98b779d496441f6af04da2d2c2bf34699dae586a))
- archive v1.8 R Package Migration milestone
  ([a4480f4](https://github.com/seanthimons/concert/tree/a4480f4178ab0429ec87918ac3d957b38b9de910))
- archive v1.7 phase directories to milestones/v1.7-phases/
  ([2d68cd6](https://github.com/seanthimons/concert/tree/2d68cd6d05bd920358dae3e45b0db959471eb52b))
- archive v1.7 milestone — UI Polish & Isotope Cleaning
  ([f82e2bc](https://github.com/seanthimons/concert/tree/f82e2bc1c01e59d1957dbf1af00b0dbd30e5e041))
- complete v1.6 milestone
  ([f46287b](https://github.com/seanthimons/concert/tree/f46287b3fffb1fa5cdf48b99394dcc4cb4e690a9))
- complete v1.5 milestone — archive and cleanup
  ([659ab67](https://github.com/seanthimons/concert/tree/659ab670606c5b6b2f37b0aab7f033f706513697))
- complete v1.4 milestone — archive and cleanup
  ([b63f840](https://github.com/seanthimons/concert/tree/b63f840f72553a7327157949c2b5b9533406dbb3))
- archive v1.3 phase directories to milestones/
  ([38f67b7](https://github.com/seanthimons/concert/tree/38f67b757fa3eb366e21ddd14e92c57dc77ec453))
- complete v1.3 Data Cleaning Pipeline milestone
  ([2c03a63](https://github.com/seanthimons/concert/tree/2c03a63769ea06fe94323f436470f85b2c32ae13))
- complete v1.2 milestone
  ([6991f06](https://github.com/seanthimons/concert/tree/6991f066b1748438ddffcd23e69dc5f27eda576f))
- complete v1.1 milestone — archive and retrospective
  ([8cb37b0](https://github.com/seanthimons/concert/tree/8cb37b0a085823d2d705bacad88938fd57890d19))
- complete v1.0 milestone
  ([6d2cbba](https://github.com/seanthimons/concert/tree/6d2cbbac10c01e482b411c0f5769275f8dd2eee8))

Full set of changes:
[`48a0046...v0.1.1`](https://github.com/seanthimons/concert/compare/48a0046...v0.1.1)
