# Package index

## Run the app

- [`run_app()`](https://seanthimons.github.io/concert/reference/run_app.md)
  : Launch the CONCERT Shiny Application

## Headless curation

Curate a file without the Shiny app, or drive it from an agent loop.

- [`curate_headless()`](https://seanthimons.github.io/concert/reference/curate_headless.md)
  : Run the full curation pipeline headlessly (without Shiny UI)
- [`curate_iterate()`](https://seanthimons.github.io/concert/reference/curate_iterate.md)
  : Run one iteration of the agent curation loop
- [`curate_decisions_template()`](https://seanthimons.github.io/concert/reference/curate_decisions_template.md)
  : Write a starter decisions.R for the agent curation loop
- [`stage_clean()`](https://seanthimons.github.io/concert/reference/stage_clean.md)
  : Stage 2: run the cleaning pipeline
- [`stage_curate()`](https://seanthimons.github.io/concert/reference/stage_curate.md)
  : Stage 3: run the CompTox curation search and optional candidate
  postprocessing
- [`stage_export()`](https://seanthimons.github.io/concert/reference/stage_export.md)
  : Stage 6: write outputs and build the result list
- [`stage_harmonize()`](https://seanthimons.github.io/concert/reference/stage_harmonize.md)
  : Stage 5: run numeric, unit, media, and ToxVal harmonization
- [`stage_ingest()`](https://seanthimons.github.io/concert/reference/stage_ingest.md)
  : Stage 1: read a file, detect frontmatter, and validate the tag map
- [`stage_review()`](https://seanthimons.github.io/concert/reference/stage_review.md)
  : Stage 4: apply Review Results edits
- [`run_curation_pipeline()`](https://seanthimons.github.io/concert/reference/run_curation_pipeline.md)
  : Orchestrate the full curation pipeline: dedup -\> search -\> map -\>
  consensus -\> resolution
- [`generate_concert_script()`](https://seanthimons.github.io/concert/reference/generate_concert_script.md)
  : Generate a CONCERT replay script
- [`write_curation_output()`](https://seanthimons.github.io/concert/reference/write_curation_output.md)
  : Write Curation Output in a Requested Format
- [`parse_concert_export()`](https://seanthimons.github.io/concert/reference/parse_concert_export.md)
  : Parse CONCERT Export

## Read files and detect frontmatter

- [`safely_read_file()`](https://seanthimons.github.io/concert/reference/safely_read_file.md)
  : Safely read a file with multiple fallback strategies
- [`validate_file()`](https://seanthimons.github.io/concert/reference/validate_file.md)
  : Validate uploaded file before processing
- [`validate_excel_size()`](https://seanthimons.github.io/concert/reference/validate_excel_size.md)
  : Validate Excel Size Limits
- [`detect_data_start()`](https://seanthimons.github.io/concert/reference/detect_data_start.md)
  : Main ensemble detection function combining all methods
- [`detect_data_start_heuristic()`](https://seanthimons.github.io/concert/reference/detect_data_start_heuristic.md)
  : Detect data start using heuristic fill ratio method
- [`detect_pattern_based()`](https://seanthimons.github.io/concert/reference/detect_pattern_based.md)
  : Detect data start using pattern matching for common header keywords
- [`detect_by_type_consistency()`](https://seanthimons.github.io/concert/reference/detect_by_type_consistency.md)
  : Detect data start by checking column type consistency
- [`extract_clean_data()`](https://seanthimons.github.io/concert/reference/extract_clean_data.md)
  : Extract clean data based on detection results
- [`handle_merged_cells()`](https://seanthimons.github.io/concert/reference/handle_merged_cells.md)
  : Handle merged cells by filling down first column
- [`calculate_smart_preview_rows()`](https://seanthimons.github.io/concert/reference/calculate_smart_preview_rows.md)
  : Calculate smart preview row count based on file size
- [`format_file_size()`](https://seanthimons.github.io/concert/reference/format_file_size.md)
  : Format file size for display

## Tag columns

- [`suggest_column_tags()`](https://seanthimons.github.io/concert/reference/suggest_column_tags.md)
  : Suggest Column Tags From Header Names
- [`classify_tags()`](https://seanthimons.github.io/concert/reference/classify_tags.md)
  : Classify Tags into Categories
- [`validate_tag_pairing()`](https://seanthimons.github.io/concert/reference/validate_tag_pairing.md)
  : Validate Tag Pairing Requirements
- [`has_required_chemical_tags()`](https://seanthimons.github.io/concert/reference/has_required_chemical_tags.md)
  : Check for Required Chemical Tags
- [`detect_tag_changes()`](https://seanthimons.github.io/concert/reference/detect_tag_changes.md)
  : Detect Changes Between Tag Sets
- [`find_dtxsid_cols()`](https://seanthimons.github.io/concert/reference/find_dtxsid_cols.md)
  : Auto-detect DTXSID columns by name pattern

## Clean names and identifiers

- [`run_cleaning_pipeline()`](https://seanthimons.github.io/concert/reference/run_cleaning_pipeline.md)
  : Run complete cleaning pipeline with audit trail tracking
- [`apply_value_corrections()`](https://seanthimons.github.io/concert/reference/apply_value_corrections.md)
  : Apply dataset-specific value corrections before cleaning
- [`build_audit_trail()`](https://seanthimons.github.io/concert/reference/build_audit_trail.md)
  : Build audit trail by comparing two dataframes
- [`clean_text_field()`](https://seanthimons.github.io/concert/reference/clean_text_field.md)
  : Clean text field by stripping whitespace and punctuation artifacts
- [`clean_unicode()`](https://seanthimons.github.io/concert/reference/clean_unicode.md)
  : Clean Unicode symbols in character strings
- [`perform_unicode_qc()`](https://seanthimons.github.io/concert/reference/perform_unicode_qc.md)
  : Perform post-curation Unicode QC (read-only detection)
- [`detect_non_ascii_chars()`](https://seanthimons.github.io/concert/reference/detect_non_ascii_chars.md)
  : Detect non-ASCII characters in a character vector
- [`strip_quality_adjectives()`](https://seanthimons.github.io/concert/reference/strip_quality_adjectives.md)
  : Strip quality adjectives from name fields
- [`strip_reference_terms()`](https://seanthimons.github.io/concert/reference/strip_reference_terms.md)
  : Strip user-defined reference terms from name fields
- [`strip_salt_references()`](https://seanthimons.github.io/concert/reference/strip_salt_references.md)
  : Strip salt references from name fields
- [`strip_terminal_enclosures()`](https://seanthimons.github.io/concert/reference/strip_terminal_enclosures.md)
  : Strip terminal enclosures (parentheticals and brackets) from name
  fields
- [`strip_terminal_unspecified()`](https://seanthimons.github.io/concert/reference/strip_terminal_unspecified.md)
  : Strip terminal "unspecified" suffixes from name fields
- [`normalize_cas_fields()`](https://seanthimons.github.io/concert/reference/normalize_cas_fields.md)
  : Normalize CAS fields using ComptoxR
- [`rescue_cas_from_text()`](https://seanthimons.github.io/concert/reference/rescue_cas_from_text.md)
  : Rescue CAS-RNs from non-CASRN text columns
- [`detect_multi_cas()`](https://seanthimons.github.io/concert/reference/detect_multi_cas.md)
  : Detect rows with multiple CAS-RNs
- [`detect_truncated_compound_names()`](https://seanthimons.github.io/concert/reference/detect_truncated_compound_names.md)
  : Detect likely truncated compound names
- [`detect_bare_formulas()`](https://seanthimons.github.io/concert/reference/detect_bare_formulas.md)
  : Detect bare molecular formulas
- [`expand_isotope_shortcodes()`](https://seanthimons.github.io/concert/reference/expand_isotope_shortcodes.md)
  : Expand isotope shortcodes to canonical Name-Mass format (vectorized)
- [`protect_chiral_designations()`](https://seanthimons.github.io/concert/reference/protect_chiral_designations.md)
  : Protect chiral designations from downstream stripping
- [`restore_chiral_designations()`](https://seanthimons.github.io/concert/reference/restore_chiral_designations.md)
  : Restore chiral designation placeholders to original markers
- [`split_synonyms()`](https://seanthimons.github.io/concert/reference/split_synonyms.md)
  : Split semicolon-separated synonyms in name fields
- [`extract_cas()`](https://seanthimons.github.io/concert/reference/extract_cas.md)
  : Extracts all valid CASRNs from a character vector
- [`extract_formulas()`](https://seanthimons.github.io/concert/reference/extract_formulas.md)
  : Extract molecular formulas from text
- [`extract_mixture()`](https://seanthimons.github.io/concert/reference/extract_mixture.md)
  : Detects chemical mixtures by name based on ratio patterns
- [`as_cas()`](https://seanthimons.github.io/concert/reference/as_cas.md)
  : Coerces and validates a string to a standard CASRN format
- [`is_cas()`](https://seanthimons.github.io/concert/reference/is_cas.md)
  : Checks if a string is a syntactically and algorithmically valid
  CASRN
- [`flag_reference_matches()`](https://seanthimons.github.io/concert/reference/flag_reference_matches.md)
  : Flag rows matching reference list entries
- [`dedup_step()`](https://seanthimons.github.io/concert/reference/dedup_step.md)
  : Deduplication wrapper for cleaning step functions
- [`get_dedup_preview()`](https://seanthimons.github.io/concert/reference/get_dedup_preview.md)
  : Get deduplication preview counts before running full pipeline
- [`remap_audit_to_parent()`](https://seanthimons.github.io/concert/reference/remap_audit_to_parent.md)
  : Remap audit trail row IDs from unique-string slice to parent dataset
- [`inject_row_lineage()`](https://seanthimons.github.io/concert/reference/inject_row_lineage.md)
  : Inject row lineage tracking

## Multi-analyte rows

- [`flag_multi_analyte()`](https://seanthimons.github.io/concert/reference/flag_multi_analyte.md)
  : Flag rows containing naked multi-analyte expressions
- [`suggest_multi_analyte_parts()`](https://seanthimons.github.io/concert/reference/suggest_multi_analyte_parts.md)
  : Suggest split parts for a multi-analyte value
- [`resolve_multi_analyte_row()`](https://seanthimons.github.io/concert/reference/resolve_multi_analyte_row.md)
  : Resolve one flagged multi-analyte row
- [`apply_multi_analyte_resolutions()`](https://seanthimons.github.io/concert/reference/apply_multi_analyte_resolutions.md)
  : Apply multiple multi-analyte resolutions
- [`is_multi_analyte_review_row()`](https://seanthimons.github.io/concert/reference/is_multi_analyte_review_row.md)
  : Identify rows still needing multi-analyte review

## Reference lists

- [`load_all_reference_lists()`](https://seanthimons.github.io/concert/reference/load_all_reference_lists.md)
  : Load all reference lists
- [`load_block_patterns()`](https://seanthimons.github.io/concert/reference/load_block_patterns.md)
  : Load block patterns list
- [`load_corrections()`](https://seanthimons.github.io/concert/reference/load_corrections.md)
  : Load one-off corrections table
- [`load_functional_categories()`](https://seanthimons.github.io/concert/reference/load_functional_categories.md)
  : Load functional use categories
- [`load_isotope_lookup()`](https://seanthimons.github.io/concert/reference/load_isotope_lookup.md)
  : Load isotope lookup table
- [`load_media_map()`](https://seanthimons.github.io/concert/reference/load_media_map.md)
  : Load merged media harmonization map (user edits + bundled defaults)
- [`load_or_fetch_reference()`](https://seanthimons.github.io/concert/reference/load_or_fetch_reference.md)
  : Generic cache-or-fetch function
- [`load_stop_words()`](https://seanthimons.github.io/concert/reference/load_stop_words.md)
  : Load stop words list
- [`load_strip_terms()`](https://seanthimons.github.io/concert/reference/load_strip_terms.md)
  : Load strip terms list
- [`load_toxval_schema()`](https://seanthimons.github.io/concert/reference/load_toxval_schema.md)
  : Load ToxVal schema manifest
- [`load_unit_map()`](https://seanthimons.github.io/concert/reference/load_unit_map.md)
  : Load unit conversion map
- [`load_unit_synonyms()`](https://seanthimons.github.io/concert/reference/load_unit_synonyms.md)
  : Load unit synonym normalization table
- [`load_user_reference_lists()`](https://seanthimons.github.io/concert/reference/load_user_reference_lists.md)
  : Load user reference list overrides
- [`load_wqx_dictionary()`](https://seanthimons.github.io/concert/reference/load_wqx_dictionary.md)
  : Load WQX dictionary lookup table
- [`merge_reference_lists()`](https://seanthimons.github.io/concert/reference/merge_reference_lists.md)
  : Merge Reference Lists
- [`save_user_reference_lists()`](https://seanthimons.github.io/concert/reference/save_user_reference_lists.md)
  : Save user reference list overrides
- [`update_user_reference_list()`](https://seanthimons.github.io/concert/reference/update_user_reference_list.md)
  : Update a user reference list override
- [`validate_reference_list_patterns()`](https://seanthimons.github.io/concert/reference/validate_reference_list_patterns.md)
  : Validate reference-list patterns
- [`reference_list_help_text()`](https://seanthimons.github.io/concert/reference/reference_list_help_text.md)
  : Reference-list help text
- [`refresh_isotope_cache()`](https://seanthimons.github.io/concert/reference/refresh_isotope_cache.md)
  : Refresh isotope lookup cache
- [`refresh_wqx_cache()`](https://seanthimons.github.io/concert/reference/refresh_wqx_cache.md)
  : Refresh WQX dictionary cache
- [`clear_starts_with_cache()`](https://seanthimons.github.io/concert/reference/clear_starts_with_cache.md)
  : Clear the starts-with cache

## Resolve identities

CompTox and WQX matching, consensus, and review.

- [`match_wqx()`](https://seanthimons.github.io/concert/reference/match_wqx.md)
  : Match chemical names against WQX Characteristic Name dictionary
- [`classify_consensus()`](https://seanthimons.github.io/concert/reference/classify_consensus.md)
  : Classify consensus across tagged columns for each row
- [`classify_auto_resolve()`](https://seanthimons.github.io/concert/reference/classify_auto_resolve.md)
  : Classify disagree rows as auto-resolved, suggested, or leave as
  disagree
- [`compute_similarity_scores()`](https://seanthimons.github.io/concert/reference/compute_similarity_scores.md)
  : Compute similarity scores for all disagree rows in resolution_state
- [`score_one_candidate()`](https://seanthimons.github.io/concert/reference/score_one_candidate.md)
  : Compute similarity score for a single candidate against an input
  name
- [`enrich_candidates()`](https://seanthimons.github.io/concert/reference/enrich_candidates.md)
  : Fetch CompTox chemical details for DTXSIDs and return structured
  cache
- [`enrich_synonyms()`](https://seanthimons.github.io/concert/reference/enrich_synonyms.md)
  : Fetch and cache CompTox synonym data for a set of DTXSIDs
- [`merge_retry_results()`](https://seanthimons.github.io/concert/reference/merge_retry_results.md)
  : Merge retry curation results back into original resolution state
- [`apply_priority_chain()`](https://seanthimons.github.io/concert/reference/apply_priority_chain.md)
  : Apply en masse column priority to resolve all non-pinned disagree
  rows
- [`compute_qc_tier()`](https://seanthimons.github.io/concert/reference/compute_qc_tier.md)
  : Compute numeric QC tier for a consensus classification
- [`init_resolution_state()`](https://seanthimons.github.io/concert/reference/init_resolution_state.md)
  : Initialize resolution state on a classified data frame
- [`get_resolution_options()`](https://seanthimons.github.io/concert/reference/get_resolution_options.md)
  : Get available resolution options for a disagree row
- [`resolve_row()`](https://seanthimons.github.io/concert/reference/resolve_row.md)
  : Resolve a single disagreement row by choosing a preferred column
- [`resolve_review_row()`](https://seanthimons.github.io/concert/reference/resolve_review_row.md)
  : Resolve one flagged review row (multi-analyte and/or multi-CAS)
- [`accept_all_suggestions()`](https://seanthimons.github.io/concert/reference/accept_all_suggestions.md)
  : Accept all suggested resolutions in bulk
- [`build_review_overrides()`](https://seanthimons.github.io/concert/reference/build_review_overrides.md)
  : Build content-matched review overrides
- [`apply_review_overrides()`](https://seanthimons.github.io/concert/reference/apply_review_overrides.md)
  : Apply review overrides to a replayed resolution state
- [`apply_review_resolutions()`](https://seanthimons.github.io/concert/reference/apply_review_resolutions.md)
  : Apply staged review decisions in one batch
- [`validate_manual_dtxsids()`](https://seanthimons.github.io/concert/reference/validate_manual_dtxsids.md)
  : Validate manually-entered DTXSIDs via CompTox bulk API
- [`set_row_flag()`](https://seanthimons.github.io/concert/reference/set_row_flag.md)
  : Set one row flag
- [`set_row_flags()`](https://seanthimons.github.io/concert/reference/set_row_flags.md)
  : Set row flags in bulk
- [`normalize_row_flag()`](https://seanthimons.github.io/concert/reference/normalize_row_flag.md)
  : Normalize a row flag value
- [`valid_row_flags()`](https://seanthimons.github.io/concert/reference/valid_row_flags.md)
  : Valid row flag values
- [`hydrate_session_state()`](https://seanthimons.github.io/concert/reference/hydrate_session_state.md)
  : Hydrate Session State

## Harmonize measurements

- [`parse_numeric_results()`](https://seanthimons.github.io/concert/reference/parse_numeric_results.md)
  : Parse messy numeric result strings into a structured tibble
- [`parse_dates()`](https://seanthimons.github.io/concert/reference/parse_dates.md)
  : Parse mixed-format date strings into structured ISO-8601 output
- [`harmonize_units()`](https://seanthimons.github.io/concert/reference/harmonize_units.md)
  : Harmonize unit values using a conversion table
- [`harmonize_media()`](https://seanthimons.github.io/concert/reference/harmonize_media.md)
  : Harmonize environmental media strings to canonical CONCERT media
  terms
- [`normalize_uncertainty_to_two_sigma()`](https://seanthimons.github.io/concert/reference/normalize_uncertainty_to_two_sigma.md)
  : Convert reported uncertainty to a two-sigma half-width
- [`classify_detection_events()`](https://seanthimons.github.io/concert/reference/classify_detection_events.md)
  : Classify row-level detection events
- [`classify_harmonized_detection()`](https://seanthimons.github.io/concert/reference/classify_harmonized_detection.md)
  : Classify harmonized tagged measurements
- [`map_to_toxval_schema()`](https://seanthimons.github.io/concert/reference/map_to_toxval_schema.md)
  : Map curated data to ToxVal schema
- [`build_export_sheets()`](https://seanthimons.github.io/concert/reference/build_export_sheets.md)
  : Build Export Sheets

## Dataset context and sites

- [`detect_site_columns()`](https://seanthimons.github.io/concert/reference/detect_site_columns.md)
  : Detect Site/Location Columns In A Dataset
- [`extract_site_candidates()`](https://seanthimons.github.io/concert/reference/extract_site_candidates.md)
  : Extract Site Candidates
- [`build_site_manifest()`](https://seanthimons.github.io/concert/reference/build_site_manifest.md)
  : Build A Deterministic Site Manifest
- [`build_chorus_site_manifest()`](https://seanthimons.github.io/concert/reference/build_chorus_site_manifest.md)
  : Build CHORUS Site Manifest Payload
- [`build_site_alias_map()`](https://seanthimons.github.io/concert/reference/build_site_alias_map.md)
  : Build A Deterministic Site Alias Map
- [`normalize_site_manifest()`](https://seanthimons.github.io/concert/reference/normalize_site_manifest.md)
  : Normalize A Site Manifest

## Shiny modules

- [`mod_clean_data_server()`](https://seanthimons.github.io/concert/reference/mod_clean_data_server.md)
  : Clean Data Module - Server
- [`mod_clean_data_ui()`](https://seanthimons.github.io/concert/reference/mod_clean_data_ui.md)
  : Clean Data Module - UI
- [`mod_data_preview_server()`](https://seanthimons.github.io/concert/reference/mod_data_preview_server.md)
  : Data Preview Module - Server
- [`mod_data_preview_ui()`](https://seanthimons.github.io/concert/reference/mod_data_preview_ui.md)
  : Data Preview Module - UI
- [`mod_dataset_context_server()`](https://seanthimons.github.io/concert/reference/mod_dataset_context_server.md)
  : Dataset Context Module - Server
- [`mod_dataset_context_ui()`](https://seanthimons.github.io/concert/reference/mod_dataset_context_ui.md)
  : Dataset Context Module - UI
- [`mod_detection_info_server()`](https://seanthimons.github.io/concert/reference/mod_detection_info_server.md)
  : Detection Info Module - Server
- [`mod_detection_info_ui()`](https://seanthimons.github.io/concert/reference/mod_detection_info_ui.md)
  : Detection Info Module - UI
- [`mod_file_upload_server()`](https://seanthimons.github.io/concert/reference/mod_file_upload_server.md)
  : File Upload Module - Server
- [`mod_file_upload_ui()`](https://seanthimons.github.io/concert/reference/mod_file_upload_ui.md)
  : File Upload Module - UI
- [`mod_harmonize_server()`](https://seanthimons.github.io/concert/reference/mod_harmonize_server.md)
  : Harmonize Module - Server
- [`mod_harmonize_ui()`](https://seanthimons.github.io/concert/reference/mod_harmonize_ui.md)
  : Harmonize Module - UI
- [`mod_raw_data_server()`](https://seanthimons.github.io/concert/reference/mod_raw_data_server.md)
  : Raw Data Module - Server
- [`mod_raw_data_ui()`](https://seanthimons.github.io/concert/reference/mod_raw_data_ui.md)
  : Raw Data Module - UI
- [`mod_review_results_server()`](https://seanthimons.github.io/concert/reference/mod_review_results_server.md)
  : Review Results Module - Server
- [`mod_review_results_ui()`](https://seanthimons.github.io/concert/reference/mod_review_results_ui.md)
  : Review Results Module - UI
- [`mod_run_curation_server()`](https://seanthimons.github.io/concert/reference/mod_run_curation_server.md)
  : Run Curation Module - Server
- [`mod_run_curation_ui()`](https://seanthimons.github.io/concert/reference/mod_run_curation_ui.md)
  : Run Curation Module - UI
- [`mod_tag_columns_server()`](https://seanthimons.github.io/concert/reference/mod_tag_columns_server.md)
  : Tag Columns Module - Server
- [`mod_tag_columns_ui()`](https://seanthimons.github.io/concert/reference/mod_tag_columns_ui.md)
  : Tag Columns Module - UI
- [`notify_user()`](https://seanthimons.github.io/concert/reference/notify_user.md)
  : Show a Shiny notification and mirror important messages to the
  console
- [`log_condition()`](https://seanthimons.github.io/concert/reference/log_condition.md)
  : Log a caught condition with structured console context
