#' Run a SQL query against a document
#'
#' @description
#' `grist_sql()` runs a read-only `SELECT` query against the SQLite database
#' behind a Grist document. `grist_count()` counts the rows in a table.
#'
#' @inheritParams grist_records
#' @param query A single SQL `SELECT` statement without a trailing semicolon.
#'   Use `?` placeholders for values in `args`.
#' @param args A list or vector of values for the `?` placeholders in `query`.
#' @param timeout Query timeout in milliseconds. The server's default (1000)
#'   can only be reduced.
#' @param convert How to convert returned values: `"basic"` simplifies JSON
#'   values into vectors, and `"raw"` returns list-columns of the values
#'   exactly as the API does. SQL results carry no column types, so dates are
#'   returned as numbers.
#' @returns `grist_sql()` returns a data frame. `grist_count()` returns the
#'   number of rows as an integer.
#' @family records
#' @examplesIf FALSE
#' doc <- grist_doc("am2iHJ9Amvo7Ve3EE5emtu")
#' grist_sql(doc, "SELECT * FROM Pets WHERE popularity >= ?", args = 50)
#' grist_count(doc, "Pets")
#' @export
grist_sql <- function(
  doc,
  query,
  args = NULL,
  timeout = NULL,
  convert = c("basic", "raw")
) {
  doc <- grist_doc(doc)
  check_string(query)
  convert <- arg_match(convert)
  check_number_whole(timeout, min = 1, allow_null = TRUE)

  payload <- list(sql = query)
  if (length(args) > 0) {
    payload$args <- json_array(args)
  }
  payload <- compact(c(payload, list(timeout = timeout)))

  body <- grist_request(doc, "sql") |>
    req_json_body(payload) |>
    grist_perform()

  records <- map(body$records, function(x) x$fields)
  col_ids <- unique(unlist(map(records, names))) %||% character()
  cols <- map(set_names(col_ids), function(col) {
    cells <- map(records, function(x) x[[col]])
    if (convert == "raw") cells else simplify_column(cells)
  })
  new_tbl(cols, n = length(records))
}

#' @rdname grist_sql
#' @export
grist_count <- function(doc, table) {
  check_string(table)
  quoted <- paste0('"', gsub('"', '""', table, fixed = TRUE), '"')
  result <- grist_sql(doc, paste0("SELECT COUNT(*) AS n FROM ", quoted))
  as.integer(result$n)
}
