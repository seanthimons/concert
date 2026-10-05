# Regex for whitespace-flanked multi-analyte separators

Single source of truth shared by
[`precheck_multi_analyte()`](https://seanthimons.github.io/concert/reference/precheck_multi_analyte.md),
[`flag_multi_analyte()`](https://seanthimons.github.io/concert/reference/flag_multi_analyte.md),
and
[`suggest_multi_analyte_parts()`](https://seanthimons.github.io/concert/reference/suggest_multi_analyte_parts.md)
so the three stay in lockstep. Matches naked ` + ` (not in parens) and
` and ` anywhere, plus ` & ` and ` / ` only when the separator is not
inside a parenthetical group – so "endosulfan (alpha & beta)" is left
intact while "acetone & ethanol" and "toluene / benzene" split. All
separators require flanking whitespace, which excludes units and ratios
such as `mg/L`, `w/w`, and `1.5/1`.

## Usage

``` r
multi_analyte_separator_pattern()
```

## Value

Single Perl-compatible regex string.
