# Load all reference lists

Convenience wrapper that loads stop words, block patterns, and
functional categories in one call. Returns a named list.

## Usage

``` r
load_all_reference_lists(cache_dir = NULL)
```

## Arguments

- cache_dir:

  Directory for cache files (e.g., "data/reference_cache")

## Value

List with keys: stop_words, block_patterns, functional_categories,
strip_terms, corrections, isotope_lookup, unit_map, unit_synonyms,
toxval_schema, media_map

## Examples

``` r
cache_dir <- system.file("extdata", "reference_cache", package = "concert")
refs <- load_all_reference_lists(cache_dir)
#> Loading stop words from cache: /home/runner/work/_temp/Library/concert/extdata/reference_cache/stop_words.rds
#> Loading block patterns from cache: /home/runner/work/_temp/Library/concert/extdata/reference_cache/block_patterns.rds
#> Loading functional categories from cache: /home/runner/work/_temp/Library/concert/extdata/reference_cache/functional_categories.rds
#> Loading strip terms from cache: /home/runner/work/_temp/Library/concert/extdata/reference_cache/strip_terms.rds
#> Loading one-off corrections from cache: /home/runner/work/_temp/Library/concert/extdata/reference_cache/corrections.rds
#> Loading isotope lookup from cache: /home/runner/work/_temp/Library/concert/extdata/reference_cache/isotope_lookup.rds
#> Loading unit conversion map from cache: /home/runner/work/_temp/Library/concert/extdata/reference_cache/unit_conversion.rds
#> Loading unit synonyms from cache: /home/runner/work/_temp/Library/concert/extdata/reference_cache/unit_synonyms.rds
#> Loading ToxVal schema from cache: /home/runner/work/_temp/Library/concert/extdata/reference_cache/toxval_schema.rds
refs$stop_words
#> # A tibble: 50 × 6
#>    term          pattern       match_mode   source        active notes
#>    <chr>         <chr>         <chr>        <chr>         <lgl>  <chr>
#>  1 not provided  not provided  literal_word legacy_seed   TRUE   NA   
#>  2 unknown       unknown       literal_word legacy_seed   TRUE   NA   
#>  3 unavailable   unavailable   literal_word legacy_seed   TRUE   NA   
#>  4 undisclosed   undisclosed   literal_word legacy_seed   TRUE   NA   
#>  5 no reportable no reportable literal_word legacy_seed   TRUE   NA   
#>  6 none          none          literal_word legacy_seed   TRUE   NA   
#>  7 na            na            literal_word legacy_seed   TRUE   NA   
#>  8 ingredient    ingredient    literal_word legacy_review FALSE  NA   
#>  9 hazard        hazard        literal_word legacy_review FALSE  NA   
#> 10 blend         blend         literal_word legacy_review FALSE  NA   
#> # ℹ 40 more rows
refs$block_patterns
#> # A tibble: 50 × 6
#>    term          pattern       match_mode source      active notes
#>    <chr>         <chr>         <chr>      <chr>       <lgl>  <chr>
#>  1 propriet      propriet      regex      legacy_seed TRUE   NA   
#>  2 proprietary   proprietary   regex      legacy_seed TRUE   NA   
#>  3 confid        confid        regex      legacy_seed TRUE   NA   
#>  4 confidential  confidential  regex      legacy_seed TRUE   NA   
#>  5 cbi           cbi           regex      legacy_seed TRUE   NA   
#>  6 conf bus info conf bus info regex      legacy_seed TRUE   NA   
#>  7 secret        secret        regex      legacy_seed TRUE   NA   
#>  8 trade secret  trade secret  regex      legacy_seed TRUE   NA   
#>  9 tradesecret   tradesecret   regex      legacy_seed TRUE   NA   
#> 10 withheld      withheld      regex      legacy_seed TRUE   NA   
#> # ℹ 40 more rows
refs$functional_categories
#> # A tibble: 140 × 6
#>    term                           pattern         match_mode source active notes
#>    <chr>                          <chr>           <chr>      <chr>  <lgl>  <chr>
#>  1 Abrasive                       Abrasive        literal_w… Compt… TRUE   NA   
#>  2 Absorbent                      Absorbent       literal_w… Compt… TRUE   NA   
#>  3 Adhesion/cohesion promoter     Adhesion/cohes… literal_w… Compt… TRUE   NA   
#>  4 Adsorbent                      Adsorbent       literal_w… Compt… TRUE   NA   
#>  5 Aerating and deaerating agents Aerating and d… literal_w… Compt… TRUE   NA   
#>  6 Alloying element               Alloying eleme… literal_w… Compt… TRUE   NA   
#>  7 Anti-adhesive/cohesive         Anti-adhesive/… literal_w… Compt… TRUE   NA   
#>  8 Anti-caking agent              Anti-caking ag… literal_w… Compt… TRUE   NA   
#>  9 Anti-condensation agent        Anti-condensat… literal_w… Compt… TRUE   NA   
#> 10 Anti-dandruff                  Anti-dandruff   literal_w… Compt… TRUE   NA   
#> # ℹ 130 more rows
refs$strip_terms
#> # A tibble: 11 × 6
#>    term                 pattern              match_mode   source    active notes
#>    <chr>                <chr>                <chr>        <chr>     <lgl>  <chr>
#>  1 "modified"           "modified"           literal_word legacy_r… FALSE  NA   
#>  2 "\\d+%$"             "\\d+%$"             regex        legacy_r… FALSE  NA   
#>  3 "part [a-z]:"        "part [a-z]:"        regex        legacy_r… FALSE  NA   
#>  4 "pure"               "pure"               literal_word app_defa… TRUE   NA   
#>  5 "purified"           "purified"           literal_word app_defa… TRUE   NA   
#>  6 "technical"          "technical"          literal_word app_defa… TRUE   NA   
#>  7 "grade"              "grade"              literal_word app_defa… TRUE   NA   
#>  8 "chemical"           "chemical"           literal_word app_defa… TRUE   NA   
#>  9 "and its salts"      "and its salts"      literal_word app_defa… TRUE   NA   
#> 10 "and its \\w+ salts" "and its \\w+ salts" regex        app_defa… TRUE   NA   
#> 11 "unspecified"        "unspecified"        literal_word app_defa… TRUE   NA   
refs$corrections
#> # A tibble: 0 × 2
#> # ℹ 2 variables: pattern <chr>, replacement <chr>
refs$isotope_lookup
#> $lookup
#> # A tibble: 656 × 7
#>    symbol mass  element_name shortcode canonical    dtxsid         source       
#>    <chr>  <chr> <chr>        <chr>     <chr>        <chr>          <chr>        
#>  1 Ac     225   Actinium     ac225     Actinium-225 DTXSID50931577 comptox_pt   
#>  2 Ac     226   Actinium     ac226     Actinium-226 DTXSID00942537 comptox_pt   
#>  3 Ac     227   Actinium     ac227     Actinium-227 DTXSID30873981 comptox_pt   
#>  4 Ac     228   Actinium     ac228     Actinium-228 DTXSID90873982 wqx_radioche…
#>  5 Ag     105   Silver       ag105     Silver-105   DTXSID80933605 comptox_pt   
#>  6 Ag     106   Silver       ag106     Silver-106   DTXSID40931824 comptox_pt   
#>  7 Ag     107   Silver       ag107     Silver-107   DTXSID10162542 comptox_pt   
#>  8 Ag     108   Silver       ag108     Silver-108   DTXSID80891776 comptox_pt   
#>  9 Ag     109   Silver       ag109     Silver-109   DTXSID70162543 comptox_pt   
#> 10 Ag     110   Silver       ag110     Silver-110   DTXSID60891779 comptox_pt   
#> # ℹ 646 more rows
#> 
#> $elem_alt_names
#>      cesium    aluminum      sulfur 
#>   "Caesium" "Aluminium"   "Sulphur" 
#> 
refs$unit_map
#> # A tibble: 1,561 × 8
#>    from_unit to_unit  multiplier category      confidence source          offset
#>    <chr>     <chr>         <dbl> <chr>         <chr>      <chr>            <dbl>
#>  1 %         %                 1 dimensionless HIGH       concert_enviro…      0
#>  2 % vol     % v/v             1 dimensionless HIGH       concert_enviro…      0
#>  3 % WSF     % WSF             1 domain_unit   HIGH       concert_enviro…      0
#>  4 % sat     % sat             1 domain_unit   HIGH       concert_enviro…      0
#>  5 pH        pH                1 domain_unit   HIGH       concert_enviro…      0
#>  6 v/v       v/v               1 dimensionless HIGH       concert_enviro…      0
#>  7 % v/w     % v/w             1 dimensionless HIGH       concert_enviro…      0
#>  8 g% w/v    mg/L          10000 concentration HIGH       concert_enviro…      0
#>  9 no/eu     count/eu          1 count         HIGH       concert_enviro…      0
#> 10 mg%       mg/L             10 concentration MEDIUM     concert_enviro…      0
#> # ℹ 1,551 more rows
#> # ℹ 1 more variable: conversion_type <chr>
refs$unit_synonyms
#> # A tibble: 28 × 4
#>    input_pattern        normalized_unit is_regex notes                
#>    <chr>                <chr>           <lgl>    <chr>                
#>  1 mg/kg bw/day         mg/kg/d         FALSE    body weight qualifier
#>  2 ug/kg bw/day         ug/kg/d         FALSE    body weight qualifier
#>  3 parts/billion (ppb)  ppb             FALSE    SSWQS ppb label      
#>  4 parts per billion    ppb             FALSE    SSWQS ppb label      
#>  5 ug/l                 ug/L            FALSE    SSWQS case           
#>  6 micrograms/l         ug/L            FALSE    SSWQS micro variant  
#>  7 micrograms per liter ug/L            FALSE    SSWQS micro variant  
#>  8 ng/l                 ng/L            FALSE    SSWQS case           
#>  9 pg/l                 pg/L            FALSE    SSWQS case           
#> 10 fg/l                 fg/L            FALSE    SSWQS case           
#> # ℹ 18 more rows
refs$toxval_schema
#> # A tibble: 0 × 56
#> # ℹ 56 variables: dtxsid <chr>, casrn <chr>, name <chr>, source <chr>,
#> #   sub_source <chr>, toxval_type <chr>, toxval_subtype <chr>,
#> #   toxval_type_supercategory <chr>, qualifier <chr>, toxval_numeric <dbl>,
#> #   toxval_units <chr>, risk_assessment_class <chr>, study_type <chr>,
#> #   study_duration_class <chr>, study_duration_value <dbl>,
#> #   study_duration_units <chr>, species_common <chr>, strain <chr>,
#> #   latin_name <chr>, species_supercategory <chr>, sex <chr>, …
refs$media_map
#> # A tibble: 267 × 25
#>    term   canonical_media canonical_term term_id parent_id preferred_label rank 
#>    <chr>  <chr>           <chr>          <chr>   <chr>     <chr>           <chr>
#>  1 absin… absinthe        absinthe       FOODON… FOODON:0… absinthe        cano…
#>  2 aceto… acetone         acetone        AMH:00… AMH:0000… acetone         cano…
#>  3 aeros… aerosol         aerosol        AMH:00… ENVO:000… aerosol         cano…
#>  4 air    air             air            ENVO:0… ENVO:010… air             cano…
#>  5 ambie… ambient air     ambient air    ENVO:0… ENVO:010… air             cano…
#>  6 anima… feed            feed           AMH:00… ENVO:000… food            alias
#>  7 anima… tissue          tissue         AMH:00… AMH:0000… tissue          alias
#>  8 anima… tissue          tissue         AMH:00… AMH:0000… tissue          alias
#>  9 apples apple           apple          FOODON… FOODON:0… apple           alias
#> 10 aqueo… aqueous         aqueous        ENVO:0… ENVO:010… liquid water    cano…
#> # ℹ 257 more rows
#> # ℹ 18 more variables: definition <chr>, envo_id <chr>, physical_phase <chr>,
#> #   physical_state <chr>, is_water_based <lgl>, concert_unit_route <chr>,
#> #   media_category <chr>, source <chr>, assertion_mode <chr>,
#> #   confidence_tier <chr>, confidence <chr>, active <lgl>, canonical <chr>,
#> #   ontology_node_id <chr>, artifact_version <chr>, parent <chr>,
#> #   fetch_timestamp <chr>, ontology_path <chr>
```
