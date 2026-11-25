#!/usr/bin/env Rscript
# One iteration of the CONCERT agent curation loop.
#
#   Rscript curate_loop.R --template <input.csv> <out_dir> [--harmonize]
#       writes <out_dir>/decisions.R and exits.
#   Rscript curate_loop.R <out_dir>/decisions.R
#       runs one iteration; exit 0 when done, 2 when rows are still pending.
#       Add --out-dir <dir> and --output <workbook.xlsx> for a trial run that
#       leaves the outputs beside decisions.R alone.
#   Rscript curate_loop.R check <decisions.R> [--out-dir <dir>]
#       runs nothing; exit 0 when the last run is done and nothing it read has
#       changed since, 3 when a re-run is needed.
#   Rscript curate_loop.R record <decisions.R> <batch.csv> --by <who>
#       appends the identity decisions in <batch.csv> to the ledger.
#   Rscript curate_loop.R reconfirm <decisions.R> --expect <n> --note <why> --by <who> [--rows 3,7]
#       keeps drifted identity decisions on their current evidence.
#   Rscript curate_loop.R migrate <decisions.R>
#       moves list-form identity decisions into a ledger file, once.
#
# Between runs, edit decisions.R using status.md and pending.csv in <out_dir>.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 0) {
  stop("usage: curate_loop.R --template <input> <out_dir> [--harmonize] | curate_loop.R <decisions.R>")
}

# Always run the latest GitHub release; pak is a no-op when already current.
# Set CONCERT_SKIP_INSTALL=1 to use the installed concert as-is. Install
# failures (e.g. read-only site library under --vanilla) fall back the same way.
if (!nzchar(Sys.getenv("CONCERT_SKIP_INSTALL"))) {
  tryCatch(
    {
      if (!requireNamespace("pak", quietly = TRUE)) {
        install.packages("pak")
      }
      pak::pak("seanthimons/concert@*release", ask = FALSE)
    },
    error = function(e) {
      message("[curate_loop] release install failed, using installed concert: ", conditionMessage(e))
    }
  )
}
suppressPackageStartupMessages(library(concert))

if (args[1] == "--template") {
  if (length(args) < 3) {
    stop("usage: curate_loop.R --template <input> <out_dir> [--harmonize]")
  }
  path <- curate_decisions_template(args[2], args[3], harmonize = "--harmonize" %in% args)
  cat("decisions written:", path, "\n")
  quit(status = 0)
}

flag <- function(name) {
  i <- match(name, args)
  if (is.na(i) || i == length(args)) stop("missing ", name, call. = FALSE)
  args[i + 1]
}
if (args[1] == "record") {
  record_identity_decision(args[2], read_decision_table(args[3]), recorded_by = flag("--by"))
  quit(status = 0)
}
if (args[1] == "reconfirm") {
  reconfirm_identity_decisions(args[2], note = flag("--note"), expected = as.integer(flag("--expect")),
    recorded_by = flag("--by"),
    rows = if ("--rows" %in% args) as.integer(strsplit(flag("--rows"), ",")[[1]]))
  quit(status = 0)
}
if (args[1] == "migrate") {
  migrate_identity_ledger(args[2])
  quit(status = 0)
}

opt <- function(name, default = NULL) if (name %in% args) flag(name) else default
if (args[1] == "check") {
  lock <- curate_iterate(args[2], out_dir = opt("--out-dir", dirname(args[2])), check_lock = TRUE)
  quit(status = if (lock$current && lock$done) 0 else 3)
}

out_dir <- opt("--out-dir", dirname(args[1]))
result <- curate_iterate(args[1], out_dir = out_dir, verbose = TRUE, output_path = opt("--output"))
cat(readLines(file.path(out_dir, "status.md")), sep = "\n")
quit(status = if (result$done) 0 else 2)
