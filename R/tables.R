#' List and create tables
#'
#' @inheritParams grist_records
#' @param columns Columns for the new table, in any form accepted by
#'   [grist_columns_add()], including column descriptions.
#' @returns `grist_tables()` returns a data frame with one row per table and
#'   columns `id`, `table_ref` and `on_demand`. `grist_table_create()` returns
#'   the ID of the new table invisibly.
#' @family schema
#' @examplesIf FALSE
#' doc <- grist_doc("am2iHJ9Amvo7Ve3EE5emtu")
#' grist_tables(doc)
#' grist_table_create(doc, "Pets", c(name = "Text", popularity = "Int"))
#' @export
grist_tables <- function(doc) {
  doc <- grist_doc(doc)

  body <- grist_request(doc, "tables") |>
    grist_perform()

  tables <- body$tables
  new_tbl(
    list(
      id = field_vec(tables, "id", NA_character_, top = TRUE),
      table_ref = field_vec(tables, "tableRef", NA_integer_),
      on_demand = field_vec(tables, "onDemand", NA)
    ),
    n = length(tables)
  )
}

#' @rdname grist_tables
#' @export
grist_table_create <- function(doc, table, columns = character()) {
  doc <- grist_doc(doc)
  check_string(table)

  spec <- list(id = table, columns = columns_spec(columns))
  body <- grist_request(doc, "tables") |>
    req_json_body(list(tables = list(spec))) |>
    grist_perform()

  table_id <- body$tables[[1]]$id
  set_column_descriptions(doc, table_id, columns, columns_spec_ids(columns))
  invisible(table_id)
}

columns_spec_ids <- function(columns) {
  if (is.data.frame(columns)) {
    columns$id
  } else if (is.null(names(columns))) {
    columns
  } else {
    names(columns)
  }
}
