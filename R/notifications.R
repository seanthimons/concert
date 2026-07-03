#' Show a Shiny notification and mirror important messages to the console
#'
#' @param ui Notification content passed to [shiny::showNotification()].
#' @param type Notification type passed to [shiny::showNotification()].
#' @param ... Additional arguments passed to [shiny::showNotification()].
#' @param log_context Optional short context label included in console output.
#'
#' @return The notification id returned by [shiny::showNotification()].
#' @export
notify_user <- function(ui, type = "message", ..., log_context = NULL) {
  result <- shiny::showNotification(ui, type = type, ...)

  log_type <- as.character(type)[1]
  if (log_type %in% c("warning", "error")) {
    text <- notification_plain_text(ui)
    context <- notification_log_context(log_context)
    message(sprintf("[concert %s] %s%s", log_type, context, text))
  }

  result
}

#' Log a caught condition with structured console context
#'
#' @param context Short label describing where the condition was caught.
#' @param condition A condition object.
#' @param level Log level label.
#'
#' @return The condition, invisibly.
#' @export
log_condition <- function(context, condition, level = "error") {
  log_level <- as.character(level)[1]
  condition_classes <- paste(class(condition), collapse = ",")

  message(sprintf(
    "[concert %s] context=%s message=%s class=%s",
    log_level,
    notification_plain_text(context),
    notification_plain_text(conditionMessage(condition)),
    condition_classes
  ))

  invisible(condition)
}

notification_log_context <- function(log_context) {
  if (is.null(log_context)) {
    return("")
  }

  context <- notification_plain_text(log_context)
  if (!nzchar(context)) {
    return("")
  }

  paste0(context, ": ")
}

notification_plain_text <- function(ui) {
  text <- tryCatch(
    {
      if (inherits(ui, c("shiny.tag", "shiny.tag.list", "html"))) {
        notification_html_to_text(htmltools::renderTags(ui)$html)
      } else if (is.character(ui)) {
        paste(ui, collapse = " ")
      } else {
        paste(utils::capture.output(print(ui)), collapse = " ")
      }
    },
    error = function(e) "<notification text unavailable>"
  )

  text <- gsub("[\r\n\t]+", " ", text)
  text <- gsub("\\s+", " ", text)
  text <- trimws(text)

  if (!nzchar(text)) {
    return("<empty notification>")
  }

  text
}

notification_html_to_text <- function(html) {
  text <- as.character(html)
  text <- gsub("<\\s*br\\s*/?\\s*>", " ", text, ignore.case = TRUE, perl = TRUE)
  text <- gsub("</\\s*(p|div|li|tr|h[1-6])\\s*>", " ", text, ignore.case = TRUE, perl = TRUE)
  text <- gsub("<[^>]+>", " ", text, perl = TRUE)
  notification_decode_entities(text)
}

notification_decode_entities <- function(text) {
  replacements <- c(
    "&nbsp;" = " ",
    "&amp;" = "&",
    "&lt;" = "<",
    "&gt;" = ">",
    "&quot;" = "\"",
    "&#39;" = "'",
    "&apos;" = "'"
  )

  for (entity in names(replacements)) {
    text <- gsub(entity, replacements[[entity]], text, fixed = TRUE)
  }

  text
}
