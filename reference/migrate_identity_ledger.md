# Move list-form identity decisions into a ledger file

One-time conversion for a `decisions.R` that defines
`identity_decisions` as an R list. Writes each decision as one line of a
JSON Lines ledger next to `decisions.R`. It does not edit `decisions.R`:
afterwards, replace the list there with
`identity_decisions <- "identity_decisions.jsonl"`.

## Usage

``` r
migrate_identity_ledger(decisions_path, ledger = "identity_decisions.jsonl")
```

## Arguments

- decisions_path:

  Path to `decisions.R`.

- ledger:

  Ledger file name, relative to the decisions file directory.

## Value

Invisibly, the ledger path.
