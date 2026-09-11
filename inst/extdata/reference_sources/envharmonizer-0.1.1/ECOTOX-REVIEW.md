# Experimental ECOTOX lifestage mapping

Version 0.1.1 adds explicit applicability to `ecotox_ascii_09_15_2026.zip`.
Its native 139 code-description pairs are byte-identical to the June archive,
and match the read-only source database after the existing import NA rules.
No new or removed description was found. September tables carry the same
103 mappings and 36 unresolved decisions; `mapping_evidence_release` records
June while `ecotox_release` records September applicability. June input files
and tables are unchanged. The exact provider identifier is retained even though
its date is later than the database build date. No independent review occurred.

Experimental mappings; not independently reviewed. Users must assess
suitability for their analysis.

This release preserves the ComptoxR mapping at commit 516dfd4. It selects
the first ranked resolved candidate for each ECOTOX source description.
Candidates without complete derivation remain in the review table. An
unresolved seed category does not become an output category. A missing
reproductive flag remains missing.

The lookup key is `org_lifestage`, the source description. Taxon context was
used during curation and routing. The result join is not taxon-specific.
The seven-category reduction and reproductive flag are author-derived
interpretations. A resolved ontology match does not establish independent
approval of either interpretation.

The source inventory, complete historical scripts, decisions, and frozen
outputs are retained in the evidence archive. The active source, curation,
and provenance directories retain their original CSV content. Historical
database scripts are evidence only; normal artifact generation does not
execute them. The original code remains traceable by source path and hash.

Curator identifiers are preserved verbatim, including `baseline_curation`.
No individual identity or date is inferred from that label. Independent
reviewers: none recorded. Independent review dates: none recorded.
Disagreements and exceptions are in the curation queue, semantic adjudication
and curated exceptions tables. Their terms such as `approved_same_semantics`
record the original internal decisions, not independent scientific review.

Coverage by source term is recorded in the manifest. Usage counts are retained
in the taxon intersection and curation priority evidence, where available.
Counts in different taxon contexts can overlap and must not be added as if
they were independent record counts. No new record-coverage percentage or
agreement rate is claimed.

Before an independent validation claim, domain reviewers must assess a fixed
input set and agreed criteria. Review must include the seven-category
reduction, reproductive semantics, taxon limits, forced choices, and unresolved
policy. Record reviewer identities, dates, disagreements, and decisions.
Software parity alone is not biological validation. AMOS CONCERT checks do
not validate this domain.
