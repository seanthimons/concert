# Capture current row evidence for a scoped identity decision

This fingerprint binds an explicit decision to source content, lineage,
candidates and lookup outcomes. Flags and derived acceptance fields are
not evidence. Capture it after inspecting the row; a changed fingerprint
requires another explicit review. Version 2 records retain the source
columns actually reviewed and detect new chemical evidence. Unrelated
new nonchemical columns and enumerated harmonization outputs do not
invalidate that decision.

## Usage

``` r
identity_evidence_fingerprint(df, row)
```

## Arguments

- df:

  Current resolution data.

- row:

  Integer row position.

## Value

A versioned evidence fingerprint.
