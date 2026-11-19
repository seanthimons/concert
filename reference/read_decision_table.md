# Read a decision table

Reads a decision table from CSV, either the text block a replay script
carries or a file. Every column is read as text, so names and CASRNs
arrive exactly as written. Stops when a `casrn` or `cas_value` value is
not CAS-shaped, which is what a spreadsheet leaves behind after
rewriting a CASRN as a date (`103-02-6` becomes `0103-02-06`). Also
stops when a line does not have the header's number of fields, which is
what an unquoted comma in a hand-edited value leaves behind: write
`"1,2-Dichloroethane"`, quotes included.

## Usage

``` r
read_decision_table(path = NULL, text = NULL)
```

## Arguments

- path:

  Path to a decision table CSV.

- text:

  CSV text to read instead of a file. One leading newline is dropped, so
  the header can start on its own line.

## Value

A tibble of character columns.
