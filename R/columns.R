#' List, add and modify columns
#'
#' @description
#' `grist_columns()` lists the columns of a table. `grist_columns_add()` and
#' `grist_columns_modify()` change a table's schema.
#'
#' @inheritParams grist_records
#' @param hidden If `TRUE`, include hidden columns such as `manualSort`.
#' @param columns Column definitions. One of:
#'   * A character vector of column IDs (new columns get type `"Any"`).
#'   * A named character vector, where names are column IDs and values are
#'     column types, e.g. `c(name = "Text", age = "Int")`.
#'   * A data frame with an `id` column and any of the columns `type`, `label`,
#'     `formula`, `is_formula`, `widget_options`, `visible_col`,
#'     `untie_col_id_from_label` and (for modifying only) `col_id`, which
#'     renames the column. `NA` values are not sent.
#' @returns `grist_columns()` returns a data frame with one row per column:
#'   `id`, `label`, `type`, `is_formula`, `formula`, `widget_options`,
#'   `visible_col` and `col_ref`. `grist_columns_add()` returns the IDs of the
#'   new columns, and `grist_columns_modify()` returns `doc`, both invisibly.
#' @family schema
#' @examplesIf FALSE
#' doc <- grist_doc("am2iHJ9Amvo7Ve3EE5emtu")
#' grist_columns(doc, "People")
#' grist_columns_add(doc, "People", c(city = "Text", age = "Int"))
#' @export
grist_columns <- function(doc, table, hidden = FALSE) {
  doc <- grist_doc(doc)
  check_string(table)
  check_bool(hidden)

  req <- grist_request(doc, "tables", table, "columns")
  if (hidden) {
    req <- httr2::req_url_query(req, hidden = "true")
  }
  body <- grist_perform(req)
  columns_to_df(body$columns)
}

#' @rdname grist_columns
#' @export
grist_columns_add <- function(doc, table, columns) {
  doc <- grist_doc(doc)
  check_string(table)

  body <- grist_request(doc, "tables", table, "columns") |>
    req_json_body(list(columns = columns_spec(columns))) |>
    grist_perform()
  invisible(map_chr(body$columns, function(x) x$id))
}

#' @rdname grist_columns
#' @export
grist_columns_modify <- function(doc, table, columns) {
  doc <- grist_doc(doc)
  check_string(table)
  if (!is.data.frame(columns)) {
    cli::cli_abort(
      "{.arg columns} must be a data frame with an {.field id} column, not {.obj_type_friendly {columns}}."
    )
  }

  grist_request(doc, "tables", table, "columns") |>
    httr2::req_method("PATCH") |>
    req_json_body(list(columns = columns_spec(columns))) |>
    grist_perform()
  invisible(doc)
}

columns_to_df <- function(columns) {
  new_tbl(
    list(
      id = field_vec(columns, "id", NA_character_, top = TRUE),
      label = field_vec(columns, "label", NA_character_),
      type = field_vec(columns, "type", NA_character_),
      is_formula = field_vec(columns, "isFormula", NA),
      formula = field_vec(columns, "formula", NA_character_),
      widget_options = field_vec(columns, "widgetOptions", NA_character_),
      visible_col = field_vec(columns, "visibleCol", NA_integer_),
      col_ref = field_vec(columns, "colRef", NA_integer_)
    ),
    n = length(columns)
  )
}

# Extract one property from a list of `list(id, fields)` items as a vector.
field_vec <- function(items, name, ptype, top = FALSE) {
  vapply(
    items,
    function(x) {
      value <- if (top) x[[name]] else x$fields[[name]]
      if (is.null(value)) ptype else vctrs::vec_cast(value, ptype)
    },
    ptype
  )
}

column_field_names <- c(
  type = "type",
  label = "label",
  formula = "formula",
  is_formula = "isFormula",
  widget_options = "widgetOptions",
  visible_col = "visibleCol",
  untie_col_id_from_label = "untieColIdFromLabel",
  col_id = "colId"
)

empty_object <- function() {
  structure(list(), names = character())
}

columns_spec <- function(columns, call = caller_env()) {
  if (is.character(columns) && is.null(names(columns))) {
    return(map(columns, function(id) list(id = id, fields = empty_object())))
  }

  if (is.character(columns)) {
    return(map(seq_along(columns), function(i) {
      list(id = names(columns)[[i]], fields = list(type = unname(columns[[i]])))
    }))
  }

  if (!is.data.frame(columns) || !"id" %in% names(columns)) {
    cli::cli_abort(
      c(
        "{.arg columns} must be a character vector or a data frame with an {.field id} column.",
        i = "Got {.obj_type_friendly {columns}}."
      ),
      call = call
    )
  }

  unknown <- setdiff(names(columns), c("id", names(column_field_names)))
  if (length(unknown) > 0) {
    cli::cli_abort(
      c(
        "{.arg columns} has unknown column{?s}: {.field {unknown}}.",
        i = "Allowed columns are {.field {c('id', names(column_field_names))}}."
      ),
      call = call
    )
  }

  map(seq_len(nrow(columns)), function(i) {
    fields <- list()
    for (nm in intersect(names(columns), names(column_field_names))) {
      value <- columns[[nm]][[i]]
      if (!is.null(value) && !is.na(value)) {
        fields[[column_field_names[[nm]]]] <- value
      }
    }
    list(id = columns$id[[i]], fields = fields %||% empty_object())
  })
}

map_chr <- function(.x, .f, ...) {
  vapply(.x, .f, character(1), ...)
}
