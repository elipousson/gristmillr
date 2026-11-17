#' Read, add, update and delete records
#'
#' @description
#' `grist_records()` reads records from a table into a data frame. The other
#' functions write data frames back to Grist. Large writes are split into
#' several requests (see [grist_write_options()]).
#'
#' @section Type conversion:
#' The `convert` argument controls how cell values are translated between
#' Grist and R:
#'
#' * `"auto"` (the default) fetches the table's column types with
#'   [grist_columns()] and converts every column: `Int` to integer, `Numeric`
#'   to double, `Bool` to logical, `Date` to [Date], `DateTime` to [POSIXct],
#'   `Text` and `Choice` to character, `Ref` to integer row IDs, and
#'   `ChoiceList`, `RefList` and `Attachments` to list-columns of vectors.
#'   Columns whose cells don't match their declared type are returned
#'   unconverted with a warning.
#' * `"basic"` does not fetch column types. Scalar values are simplified and
#'   `["L", ...]` lists become list-columns, but dates stay numeric (seconds
#'   since the epoch) and references stay integer IDs. When writing, R dates,
#'   date-times and factors are still converted.
#' * `"raw"` returns or sends cell values exactly as the API does, as
#'   list-columns.
#'
#' @section Empty values:
#' Grist stores an empty `Bool` cell as `FALSE`, so an `NA` written to a `Bool`
#' column is read back as `FALSE`. Empty `Int`, `Numeric`, `Date` and
#' `DateTime` cells are read back as `NA`.
#'
#' @param doc A `grist_doc` object, document ID or document URL. See
#'   [grist_doc()].
#' @param table Table ID, as listed by [grist_tables()].
#' @param filter A named list mapping column IDs to allowed values, e.g.
#'   `list(status = c("open", "new"))`. Rows must match every column.
#' @param sort Character vector of column IDs to sort by. Prefix a column with
#'   `-` for descending order, e.g. `c("status", "-priority")`. Use
#'   `"manualSort"` for the order set in the Grist interface.
#' @param limit Maximum number of rows to return. `NULL` returns all rows.
#' @param convert How to convert cell values: `"auto"`, `"basic"` or `"raw"`.
#'   See the section "Type conversion".
#' @param options A [grist_read_options()] object (or [grist_write_options()]
#'   for the writing functions). If `NULL`, the default set with
#'   `options(gristmillr.read_options = )` or
#'   `options(gristmillr.write_options = )` is used.
#' @param data A data frame of records. For `grist_records_add()`, each column
#'   must be a column of the Grist table. For `grist_records_update()`, `data`
#'   must also have an integer `id` column.
#' @param ids Row IDs to delete, either an integer vector or a data frame with
#'   an `id` column (such as the result of [grist_records()]).
#' @returns `grist_records()` returns a data frame whose first column `id` is
#'   the row ID. `grist_records_add()` returns the new row IDs,
#'   `grist_records_update()` and `grist_records_delete()` return `doc`, all
#'   invisibly.
#' @family records
#' @examplesIf FALSE
#' doc <- grist_doc("am2iHJ9Amvo7Ve3EE5emtu")
#'
#' grist_records(doc, "Pets")
#' grist_records(doc, "Pets", filter = list(pet = "cat"), sort = "-popularity")
#'
#' new <- data.frame(pet = c("cat", "dog"), popularity = c(67L, 95L))
#' ids <- grist_records_add(doc, "Pets", new)
#'
#' grist_records_update(doc, "Pets", data.frame(id = ids, popularity = 1L))
#' grist_records_delete(doc, "Pets", ids)
#' @export
grist_records <- function(
  doc,
  table,
  filter = NULL,
  sort = NULL,
  limit = NULL,
  convert = c("auto", "basic", "raw"),
  options = NULL
) {
  doc <- grist_doc(doc)
  check_string(table)
  convert <- arg_match(convert)
  options <- as_read_options(options)
  check_filter(filter)
  check_character(sort, allow_null = TRUE)
  check_number_whole(limit, min = 0, allow_null = TRUE)

  if (options@cell_format == "typed" && convert != "raw") {
    cli::cli_abort(
      c(
        '{.code cell_format = "typed"} requires {.code convert = "raw"}.',
        i = "Typed cells are self-describing, so no conversion is applied."
      )
    )
  }

  req <- grist_request(doc, "tables", table, "records") |>
    httr2::req_url_query(
      filter = if (length(filter) > 0) {
        as.character(jsonlite::toJSON(filter, auto_unbox = FALSE))
      },
      sort = if (length(sort) > 0) paste(sort, collapse = ","),
      limit = limit,
      hidden = if (options@hidden) "true",
      cellFormat = if (options@cell_format == "typed") "typed"
    )

  columns <- if (convert == "auto" || options@col_names == "label") {
    grist_columns(doc, table, hidden = options@hidden)
  }
  body <- grist_perform(req)
  records_to_df(body$records, columns, convert, options)
}

#' @rdname grist_records
#' @export
grist_records_add <- function(
  doc,
  table,
  data,
  convert = c("auto", "basic", "raw"),
  options = NULL
) {
  doc <- grist_doc(doc)
  check_string(table)
  check_data_frame(data)
  convert <- arg_match(convert)
  options <- as_write_options(options)

  if ("id" %in% names(data)) {
    cli::cli_abort(
      c(
        "{.arg data} can't have an {.field id} column when adding records.",
        i = "Use {.fn grist_records_update} to change existing rows."
      )
    )
  }

  data <- prepare_write_data(doc, table, data, convert, options)
  records <- df_to_records(data, with_id = FALSE, convert = convert)

  ids <- integer()
  for (chunk in chunk_rows(length(records), options@chunk_size)) {
    body <- grist_request(doc, "tables", table, "records") |>
      req_json_body(list(records = records[chunk])) |>
      grist_perform()
    ids <- c(ids, map_int(body$records, function(x) as.integer(x$id)))
  }
  invisible(ids)
}

#' @rdname grist_records
#' @export
grist_records_update <- function(
  doc,
  table,
  data,
  convert = c("auto", "basic", "raw"),
  options = NULL
) {
  doc <- grist_doc(doc)
  check_string(table)
  check_data_frame(data)
  convert <- arg_match(convert)
  options <- as_write_options(options)

  if (!"id" %in% names(data)) {
    cli::cli_abort(
      "{.arg data} must have an {.field id} column to update records."
    )
  }

  data <- prepare_write_data(doc, table, data, convert, options)
  records <- df_to_records(data, with_id = TRUE, convert = convert)

  for (chunk in chunk_rows(length(records), options@chunk_size)) {
    grist_request(doc, "tables", table, "records") |>
      httr2::req_method("PATCH") |>
      req_json_body(list(records = records[chunk])) |>
      grist_perform()
  }
  invisible(doc)
}

#' @rdname grist_records
#' @export
grist_records_delete <- function(doc, table, ids, options = NULL) {
  doc <- grist_doc(doc)
  check_string(table)
  options <- as_write_options(options)

  if (is.data.frame(ids)) {
    if (!"id" %in% names(ids)) {
      cli::cli_abort("{.arg ids} must have an {.field id} column.")
    }
    ids <- ids$id
  }
  if (!is.numeric(ids) || anyNA(ids)) {
    cli::cli_abort(
      "{.arg ids} must be a numeric vector without missing values, not {.obj_type_friendly {ids}}."
    )
  }
  ids <- as.integer(ids)

  for (chunk in chunk_rows(length(ids), options@chunk_size)) {
    grist_request(doc, "tables", table, "records", "delete") |>
      httr2::req_method("POST") |>
      req_json_body(json_array(ids[chunk])) |>
      grist_perform()
  }
  invisible(doc)
}

prepare_write_data <- function(
  doc,
  table,
  data,
  convert,
  options,
  call = caller_env()
) {
  if (convert != "auto") {
    return(data)
  }
  columns <- grist_columns(doc, table, hidden = TRUE)
  check_record_columns(data, columns, options, call = call)
}

chunk_rows <- function(n, size) {
  if (n == 0) {
    return(list())
  }
  unname(split(seq_len(n), ceiling(seq_len(n) / size)))
}

check_filter <- function(
  filter,
  arg = caller_arg(filter),
  call = caller_env()
) {
  if (is.null(filter)) {
    return(invisible())
  }
  ok <- is.list(filter) &&
    (length(filter) == 0 ||
      !is.null(names(filter)) && all(nzchar(names(filter)))) &&
    all(map_lgl(filter, function(x) is.atomic(x) && !is.null(x)))
  if (!ok) {
    cli::cli_abort(
      c(
        "{.arg {arg}} must be a named list of vectors.",
        i = "For example: {.code list(status = c(\"open\", \"new\"))}."
      ),
      call = call
    )
  }
}
