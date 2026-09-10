# ECOTOX lifestage attribution and terms

Checked on 2026-09-07. These terms apply to the ECOTOX lifestage domain;
they do not change the separate AMOS licence record.

Version 0.1.1 adds applicability to EPA `ecotox_ascii_09_15_2026.zip` using
unchanged June mapping evidence. Native code files are identical. The September
archive, database, appendix and code-file hashes are in `comparison.json` and
the September manifest. No ontology input was refreshed. Cite Thimons, S.
(2026), envharmonizer 0.1.1, ECOTOX artifact ecotox-v0.1.1, with the June mapping
evidence release and the selected September source release.

| Included source | Attribution | Verified terms |
|---|---|---|
| S11 | British Oceanographic Data Centre, BODC parameter semantic model biological entity development stage terms. The NERC Vocabulary Server, National Oceanography Centre - British Oceanographic Data Centre. | [S11 collection](https://vocab.nerc.ac.uk/collection/S11/current/) and [NVS terms](https://vocab.nerc.ac.uk/about): CC BY 4.0. |
| UBERON | Uberon multi-species anatomy ontology contributors; Chris Mungall and collaborators. | [OBO registry](https://obofoundry.org/ontology/uberon.html): CC BY 3.0. |
| PO | Plant Ontology Consortium and Planteome contributors. | [OBO registry](https://obofoundry.org/ontology/po.html): CC BY 4.0. |
| FOODON | FoodOn contributors; Damion Dooley and collaborators. | [OBO registry](https://obofoundry.org/ontology/foodon.html): CC BY 4.0. |
| AMPHX | Amphioxus Development and Anatomy Ontology contributors; Hector Escriva and collaborators, CORBEL project. | [OBO registry](https://obofoundry.org/ontology/amphx.html): CC BY 3.0. |
| DpseDv | Bgee curators and developmental-stage-ontologies contributors. | [Life Stages release header](https://raw.githubusercontent.com/obophenotype/developmental-stage-ontologies/master/life-stages.obo): CC BY 4.0. The [component source](https://raw.githubusercontent.com/obophenotype/developmental-stage-ontologies/master/src/ontology/components/dpsedv.obo) identifies Bgee curation. |
| ECOTOX descriptions and usage counts | U.S. Environmental Protection Agency, ECOTOX Knowledgebase, `ecotox_ascii_06_11_2026.zip`. | [EPA terms](https://www.epa.gov/web-policies-and-procedures/epa-disclaimers) permit non-commercial scientific and educational distribution of documents and note that individual materials can have other terms. This artifact contains vocabulary labels and aggregate facts, not study full texts. No blanket licence is asserted for the source studies. |

The source snapshots are the committed CSV evidence, with source identifiers
and SHA-256 values in the manifest. A source release value of `current` is
preserved as received. It is not a claim that the original remote ontology
release can be identified more precisely. The source services were not refreshed.

The published tables select source terms and add author-derived seven-category
and reproductive fields. Those additions are adaptations, not source ontology
assertions. Existing source text and identifiers remain attributed under their
source licences. New mapping contributions are available under CC BY 4.0.
The source licences permit sharing and adaptation with attribution; this is
not a claim of endorsement by a source provider.

Code authorship: Sean Thimons, as recorded in the package DESCRIPTION and
ComptoxR history. Curation labels such as `baseline_curation` remain as supplied;
the individual reviewer identity and review date are unknown where not recorded.

Cite: Thimons, S. (2026). envharmonizer 0.1.0, ECOTOX artifact ecotox-v0.1.0,
legacy mapping baseline from ComptoxR commit 516dfd4. Cite the source ontologies
above and retain the exact manifest and artifact checksums with the analysis.

Experimental mappings; not independently reviewed. Users must assess
suitability for their analysis.
