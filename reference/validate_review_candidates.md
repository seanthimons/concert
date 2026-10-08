# Explicitly validate saved candidate IDs with an injected authority

This operation does not rerun name searches or download DSSTox. The
service must return structured outcomes, including exact requested
DTXSID. Errors and absent results mean unavailable, whereas an explicit
rejected result preserves definitive rejection. Validation establishes
membership, never correspondence.

## Usage

``` r
validate_review_candidates(
  candidates,
  validator,
  authority,
  version,
  cache = NULL,
  refresh = FALSE
)
```

## Arguments

- candidates:

  Normalized candidate data frame, or character IDs.

- validator:

  Function accepting one DTXSID and returning a data frame with dtxsid
  and outcome columns
  (valid/rejected/unavailable/unknown/invalid/ambiguous/conflicting/stale).

- authority, version:

  Nonempty authority and build/version identifiers.

- cache:

  Existing returned versioned cache, or NULL.

- refresh:

  Explicitly refresh even cached definitive results.

## Value

List with normalized validation and versioned cache. Unavailable results
are not cached as definitive outcomes and may be retried explicitly.
