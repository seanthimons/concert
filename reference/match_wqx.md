# Match chemical names against WQX Characteristic Name dictionary

Runs a three-tier lookup: (1) exact canonical, (2) alias crosswalk, (3)
Jaro-Winkler fuzzy against canonical names only. Returns a tibble with
one row per input name.

## Usage

``` r
match_wqx(names, dictionary, threshold = 0.85, verbose = FALSE)
```

## Arguments

- names:

  Character vector of analyte names to match

- dictionary:

  Tibble from load_wqx_dictionary() with columns: name, canonical_name,
  type, and optionally cas_number. CAS evidence comes only from
  canonical entries.

- threshold:

  Numeric similarity threshold for fuzzy acceptance (default 0.85).
  Internally converted to JW distance cutoff: distance \<= (1 -
  threshold).

- verbose:

  Logical. If TRUE, emits per-name cli output (default FALSE).

## Value

Tibble with columns: input_name, wqx_name, match_tier, match_distance,
alias_type, wqx_cas, wqx_cas_status, wqx_cas_raw, and
wqx_cas_provenance. wqx_cas contains a single format/checksum-valid
canonical-entry CAS, never an accepted input identity. Status is valid,
missing, invalid, or ambiguous. Distinct nonempty raw canonical values
are retained in wqx_cas_raw, separated by `|`. Conflicting values yield
ambiguous status and missing wqx_cas. Provenance records `canonical:`
followed by the normalized canonical key. Unmatched inputs have missing
CAS status and no provenance.
