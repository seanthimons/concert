# Compute similarity score for a single candidate against an input name

Score formula (per D-03): max(JW(input, preferredName, synonym_1, ...,
synonym_N)). If candidate rank \<= 3, add +0.05 bonus. Clamp final score
to `[0, 1]`. All synonym tiers treated equally (per D-04).

## Usage

``` r
score_one_candidate(input_name, preferred_name, synonyms_str, rank)
```

## Arguments

- input_name:

  Character scalar – user's original chemical name (per D-07)

- preferred_name:

  Character scalar – candidate's CompTox preferred name (NA allowed)

- synonyms_str:

  Character scalar – pipe-joined synonyms from enrichment cache (NA
  allowed)

- rank:

  Numeric scalar – candidate's rank value (NA allowed; bonus only if \<=
  3)

## Value

Numeric scalar in `[0, 1]`, or NA_real\_ if no valid comparison possible
