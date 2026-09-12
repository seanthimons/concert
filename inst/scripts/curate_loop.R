#!/usr/bin/env Rscript
# One iteration of the CONCERT agent curation loop.
#
#   Rscript curate_loop.R --template <input.csv> <out_dir> [--harmonize]
#       writes <out_dir>/decisions.R and exits.
#   Rscript curate_loop.R <out_dir>/decisions.R
#       runs one iteration; exit 0 when done, 2 when rows are still pending.
#
# Between runs, edit decisions.R using status.md and pending.csv in <out_dir>.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 0) {
  stop("usage: curate_loop.R --template <input> <out_dir> [--harmonize] | curate_loop.R <decisions.R>")
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

result <- curate_iterate(args[1], verbose = TRUE)
cat(readLines(file.path(dirname(args[1]), "status.md")), sep = "\n")
quit(status = if (result$done) 0 else 2)
