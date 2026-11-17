#' Download a document or table to a file
#'
#' @description
#' `grist_doc_download()` saves a document, or one of its tables, to a file.
#' The file is written to a temporary location first and moved to `path` only
#' when the download succeeds, so a failed request never leaves a partial file.
#'
#' `grist_table_schema()` returns the schema of a table in the
#' [Table Schema](https://specs.frictionlessdata.io/table-schema/) format. The
#' column definitions are in `$schema$fields`.
#'
#' @inheritParams grist_records
#' @param path File to write.
#' @param format File format:
#'   * `"grist"`: the whole document as a SQLite file that Grist can open.
#'   * `"xlsx"`: the whole document, or one table if `table` is given, as an
#'     Excel workbook.
#'   * `"csv"`, `"tsv"` or `"dsv"`: one table as delimited text. `table` is
#'     required.
#' @param table Table ID. Required for `"csv"`, `"tsv"` and `"dsv"`, optional
#'   for `"xlsx"`, and not used for `"grist"`.
#' @param col_names Whether column headers use column IDs (`"id"`) or labels
#'   (`"label"`). Not used for `"grist"`.
#' @param no_history If `TRUE`, remove the document's history, which can
#'   significantly reduce file size. Only for `format = "grist"`.
#' @param template If `TRUE`, remove all data and history but keep the
#'   structure, so the file can be used as a template. Only for
#'   `format = "grist"`.
#' @param overwrite Whether to replace an existing file at `path`.
#' @returns `grist_doc_download()` returns `path` invisibly.
#'   `grist_table_schema()` returns a list.
#' @family docs
#' @examplesIf FALSE
#' doc <- grist_doc("am2iHJ9Amvo7Ve3EE5emtu")
#'
#' grist_doc_download(doc, "pets.grist")
#' grist_doc_download(doc, "pets.csv", format = "csv", table = "Pets")
#' grist_doc_download(doc, "pets.xlsx", format = "xlsx", col_names = "label")
#'
#' grist_table_schema(doc, "Pets")
#' @export
grist_doc_download <- function(
  doc,
  path,
  format = c("grist", "xlsx", "csv", "tsv", "dsv"),
  table = NULL,
  col_names = c("id", "label"),
  no_history = FALSE,
  template = FALSE,
  overwrite = FALSE
) {
  doc <- grist_doc(doc)
  check_string(path)
  format <- arg_match(format)
  check_string(table, allow_null = TRUE)
  col_names <- arg_match(col_names)
  check_bool(no_history)
  check_bool(template)
  check_bool(overwrite)

  if (format %in% c("csv", "tsv", "dsv") && is.null(table)) {
    cli::cli_abort(
      c(
        "{.arg table} is required when {.code format = {.val {format}}}.",
        i = 'Use {.code format = "xlsx"} or {.code "grist"} to download the whole document.'
      )
    )
  }
  if (format == "grist") {
    if (!is.null(table)) {
      cli::cli_abort(
        c(
          '{.arg table} can\'t be used with {.code format = "grist"}.',
          i = "The {.val grist} format always contains the whole document."
        )
      )
    }
  } else if (no_history || template) {
    cli::cli_abort(
      '{.arg no_history} and {.arg template} can only be used with {.code format = "grist"}.'
    )
  }
  if (file.exists(path) && !overwrite) {
    cli::cli_abort(
      c(
        "{.file {path}} already exists.",
        i = "Use {.code overwrite = TRUE} to replace it."
      ),
      class = "gristmillr_file_exists"
    )
  }

  req <- if (format == "grist") {
    grist_request(doc, "download") |>
      httr2::req_url_query(
        nohistory = if (no_history) "true",
        template = if (template) "true"
      )
  } else {
    grist_request(doc, "download", format) |>
      httr2::req_url_query(
        tableId = table,
        header = if (col_names == "label") "label" else "colId"
      )
  }

  tmp <- tempfile(fileext = paste0(".", format))
  on.exit(unlink(tmp), add = TRUE)
  resp <- perform_request(req, path = tmp)
  # Responses that arrive in memory (e.g. mocked ones) aren't streamed to disk.
  if (!file.exists(tmp)) {
    writeBin(httr2::resp_body_raw(resp), tmp)
  }

  if (!file.copy(tmp, path, overwrite = overwrite)) {
    cli::cli_abort("Can't write to {.file {path}}.")
  }
  invisible(path)
}

#' @rdname grist_doc_download
#' @export
grist_table_schema <- function(doc, table, col_names = c("id", "label")) {
  doc <- grist_doc(doc)
  check_string(table)
  col_names <- arg_match(col_names)

  grist_request(doc, "download", "table-schema") |>
    httr2::req_url_query(
      tableId = table,
      header = if (col_names == "label") "label" else "colId"
    ) |>
    grist_perform()
}
