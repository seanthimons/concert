# Wraps a single-name stub the way ComptoxR >= 4.0.8 wraps ct_chemical_search_equal(): one call
# takes the whole vector, a request that fails is dropped with a "Request for <name> failed: <why>"
# warning and named in the "failed" attribute, and a call-level error stops the call.
fanout_stub <- function(single) {
  function(words) {
    failed <- character()
    drop <- function(word, why) {
      warning(sprintf("Request for %s failed: %s", word, why), call. = FALSE)
      failed[[word]] <<- why
      NULL
    }
    rows <- lapply(words, function(word) {
      tryCatch(
        withCallingHandlers(single(word), warning = function(w) {
          why <- sub("^Request for .* failed: ", "", conditionMessage(w))
          if (!identical(why, conditionMessage(w))) {
            failed[[word]] <<- why
          }
        }),
        specmill_call_error = function(e) stop(e),
        error = function(e) drop(word, conditionMessage(e))
      )
    })
    # ComptoxR types the combined table once; concert's binder stands in for that.
    out <- do.call(bind_lookup_rows, rows)
    if (length(failed)) attr(out, "failed") <- failed
    out
  }
}
