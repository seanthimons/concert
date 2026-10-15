# Detect and repair CASRNs that a spreadsheet converted to dates

Excel and Google Sheets silently turn some CASRNs into dates on CSV
import (e.g. `103-02-6` -\> `0103-02-06`, `10-13-9` -\> `10-13-2009`).
Roughly 4.6% of DSSTox CASRNs are exposed. No real CASRN has a
zero-padded part or a multi-digit check digit, so these shapes are input
corruption. Values are repaired only when the reconstruction passes the
CAS checksum; otherwise they are flagged with an `NA` repair and the
source file must be re-exported with CASRN columns formatted as text.

## Usage

``` r
repair_cas_date_coercion(x)
```

## Arguments

- x:

  Character vector of CASRN-column values.

## Value

Tibble with `flagged` (logical) and `repair` (character, `NA` when not
flagged or not recoverable), one row per element of `x`.

## Details

Recognised shapes:

- year-month-day with a zero-padded day (Google Sheets display, xlsx
  date cells read by
  [`read_excel_robust()`](https://seanthimons.github.io/concert/reference/read_excel_robust.md)):
  `0103-02-06`, `1975-09-02`

- US month-day-year with a 4-digit 200x year (Google Sheets):
  `10-13-2009`

- slash dates such as `9/2/1975`: flagged only, the field order is
  locale-dependent so no repair is attempted
