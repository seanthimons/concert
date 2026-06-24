#' @importFrom bslib card card_body card_header layout_columns value_box
#' @importFrom shiny HTML NS actionButton actionLink checkboxGroupInput checkboxInput conditionalPanel div downloadButton downloadHandler fileInput h4 h5 hr icon incProgress isolate modalButton modalDialog moduleServer numericInput observe observeEvent outputOptions p radioButtons reactive reactiveVal removeModal removeNotification renderTable renderText renderUI req selectInput selectizeInput showModal showNotification sliderInput span strong tagList tags textAreaInput textInput textOutput uiOutput updateActionButton updateCheckboxGroupInput updateNumericInput updateRadioButtons updateSelectInput updateSelectizeInput updateSliderInput updateTextAreaInput updateTextInput withProgress
#' @importFrom stats na.omit sd
#' @importFrom tidyselect all_of
#' @importFrom utils head read.csv
#' @keywords internal
NULL

if (getRversion() >= "2.15.1") {
  utils::globalVariables(c(
    ".lower_name",
    "Alias Name",
    "Alias Type Name",
    "CAS Number",
    "Characteristic Name",
    "Column",
    "Description",
    "Group Name",
    "Name",
    "Type",
    "active",
    "alias_type",
    "canonical_name",
    "cas_number",
    "column_name",
    "consensus_status",
    "dedup_key",
    "description",
    "dtxsid",
    "fill_ratio",
    "filled_cells",
    "group_name",
    "key",
    "looked_up_dtxsid",
    "looked_up_name",
    "looked_up_rank",
    "match_mode",
    "match_type",
    "name",
    "needs_review",
    "notes",
    "orig_unit",
    "pattern",
    "preferredName",
    "qc_flag",
    "record_type",
    "row_num",
    "searchValue",
    "term",
    "type",
    "unique_ratio",
    "validated_cas",
    "value"
  ))
}
