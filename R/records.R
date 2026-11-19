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
#' @param data A data frame of records, which comes first so that it can be
#'   piped in. Each column must be a column of the Grist table. For
#'   `grist_records_update()`, `data` must also have an integer `id` column. For
#'   `grist_records_delete()`, `data` is a data frame with an `id` column (such
#'   as the result of [grist_records()]) or a vector of row IDs.
#' @param by Columns that identify a record. For `grist_records_update()` the
#'   default, `"id"`, updates the rows whose row IDs are in `data$id`. Otherwise
#'   `by` is a character vector of columns, such as `"email"`, and each row of
#'   `data` is matched against the table on these columns. `data` must contain
#'   them, with no missing values and no duplicated combinations, and no `id`
#'   column.
#' @param unmatched What to do with a row of `data` that matches no record in
#'   the table. Grist's two ways to update records support one value each:
#'   `"error"` when `by = "id"`, because Grist errors on a row ID that doesn't
#'   exist, and `"ignore"` when `by` is another column, because Grist skips
#'   rows with no match and doesn't report which. A call that asks for the
#'   other value is an error, so key-based updates need `unmatched = "ignore"`.
#' @param multiple What to do when several records in the table match one row of
#'   `data`: update the `"first"` one, update `"all"` of them, or update
#'   `"none"` of them. Only used when `by` is not `"id"`.
#' @param mode What to do with each row of `data`: `"upsert"` updates the
#'   record with matching `by` values and adds a record if there is none.
#'   `"update"` only updates matching records and skips rows that match
#'   nothing. `"insert"` only adds records and skips rows that already match.
#'   Grist does not report which rows were skipped.
#' @param onmany What to do when several records in the table match one row
#'   of `data`: update the `"first"` one, update `"all"` of them, or update
#'   `"none"` of them.
#' @returns `grist_records()` returns a data frame whose first column `id` is
#'   the row ID. `grist_records_add()` returns `data` with a new first column
#'   `id` holding the row IDs Grist assigned. `grist_records_delete()` returns
#'   `data` unchanged. `grist_records_update()` and `grist_records_upsert()`
#'   return `doc`. All but `grist_records()` return invisibly.
#' @family records
#' @examplesIf FALSE
#' doc <- grist_doc("am2iHJ9Amvo7Ve3EE5emtu")
#'
#' grist_records(doc, "Pets")
#' grist_records(doc, "Pets", filter = list(pet = "cat"), sort = "-popularity")
#'
#' # Data comes first, so it can be piped in. The result has the new row IDs.
#' new <- data.frame(pet = c("cat", "dog"), popularity = c(67L, 95L))
#' added <- new |> grist_records_add(doc, "Pets")
#'
#' data.frame(id = added$id, popularity = 1L) |>
#'   grist_records_update(doc, "Pets")
#'
#' # Match on a column. Grist skips rows that match nothing.
#' data.frame(pet = "cat", popularity = 70L) |>
#'   grist_records_update(doc, "Pets", by = "pet", unmatched = "ignore")
#'
#' # Match on a column instead of the row ID: update cats, add rabbits
#' pets <- data.frame(pet = c("cat", "rabbit"), popularity = c(70L, 40L))
#' grist_records_upsert(doc, "Pets", pets, by = "pet")
#'
#' added |> grist_records_delete(doc, "Pets")
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
  check_list_query(filter, sort, limit)

  if (options@cell_format == "typed" && convert != "raw") {
    cli::cli_abort(
      c(
        '{.code cell_format = "typed"} requires {.code convert = "raw"}.',
        i = "Typed cells are self-describing, so no conversion is applied."
      )
    )
  }

  req <- grist_request(doc, "tables", table, "records") |>
    req_list_query(filter, sort, limit) |>
    httr2::req_url_query(
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
  data,
  doc,
  table,
  convert = c("auto", "basic", "raw"),
  options = NULL
) {
  check_data_frame(data)
  doc <- grist_doc(doc)
  check_string(table)
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

  records <- prepare_write_data(doc, table, data, convert, options) |>
    df_to_records(with_id = FALSE, convert = convert)

  ids <- integer()
  for (chunk in chunk_rows(length(records), options@chunk_size)) {
    body <- grist_request(doc, "tables", table, "records") |>
      req_noparse(options) |>
      req_json_body(list(records = records[chunk])) |>
      grist_perform()
    ids <- c(ids, map_int(body$records, function(x) as.integer(x$id)))
  }

  data$id <- ids
  invisible(data[c("id", setdiff(names(data), "id"))])
}

#' @rdname grist_records
#' @export
grist_records_update <- function(
  data,
  doc,
  table,
  by = "id",
  unmatched = c("error", "ignore"),
  multiple = c("first", "all", "none"),
  convert = c("auto", "basic", "raw"),
  options = NULL
) {
  check_data_frame(data)
  doc <- grist_doc(doc)
  check_string(table)
  check_by(by)
  unmatched <- arg_match(unmatched)
  multiple <- arg_match(multiple)
  convert <- arg_match(convert)
  options <- as_write_options(options)

  if (!identical(by, "id")) {
    check_unmatched(unmatched, "ignore", by)
    check_upsert_by(data, by)
    put_records(
      data,
      doc,
      table,
      by,
      mode = "update",
      multiple = multiple,
      convert = convert,
      options = options
    )
    return(invisible(data))
  }

  check_unmatched(unmatched, "error", by)
  if (!"id" %in% names(data)) {
    cli::cli_abort(
      "{.arg data} must have an {.field id} column to update records."
    )
  }

  data_with_ids <- data
  data_with_ids$id <- as_row_ids(data$id, arg = "data$id")
  records <- prepare_write_data(doc, table, data_with_ids, convert, options) |>
    df_to_records(with_id = TRUE, convert = convert)

  for (chunk in chunk_rows(length(records), options@chunk_size)) {
    grist_request(doc, "tables", table, "records") |>
      httr2::req_method("PATCH") |>
      req_noparse(options) |>
      req_json_body(list(records = records[chunk])) |>
      grist_perform()
  }
  invisible(data)
}

#' @rdname grist_records
#' @export
grist_records_upsert <- function(
  doc,
  table,
  data,
  by,
  mode = c("upsert", "update", "insert"),
  onmany = c("first", "all", "none"),
  convert = c("auto", "basic", "raw"),
  options = NULL
) {
  doc <- grist_doc(doc)
  check_string(table)
  check_data_frame(data)
  check_required(by)
  mode <- arg_match(mode)
  onmany <- arg_match(onmany)
  convert <- arg_match(convert)
  options <- as_write_options(options)
  check_upsert_by(data, by)

  data <- prepare_write_data(doc, table, data, convert, options)
  records <- df_to_records(data, with_id = FALSE, convert = convert) |>
    map(function(rec) {
      list(
        require = rec$fields[by],
        fields = rec$fields[setdiff(names(rec$fields), by)]
      )
    })

  for (chunk in chunk_rows(length(records), options@chunk_size)) {
    grist_request(doc, "tables", table, "records") |>
      httr2::req_method("PUT") |>
      httr2::req_url_query(
        onmany = if (onmany != "first") onmany,
        noadd = if (mode == "update") "true",
        noupdate = if (mode == "insert") "true",
        noparse = if (!options@parse) "true"
      ) |>
      req_json_body(list(records = records[chunk])) |>
      grist_perform()
  }
  invisible(doc)
}

# Send records to the endpoint that matches rows on the `by` columns. `mode`
# is `"upsert"`, `"update"` (skip rows with no match) or `"insert"` (skip rows
# that match). Grist doesn't report which rows were skipped.
put_records <- function(
  data,
  doc,
  table,
  by,
  mode,
  multiple = "first",
  convert,
  options,
  call = caller_env()
) {
  records <- prepare_write_data(doc, table, data, convert, options, call) |>
    df_to_records(with_id = FALSE, convert = convert) |>
    map(function(rec) {
      list(
        require = rec$fields[by],
        fields = rec$fields[setdiff(names(rec$fields), by)]
      )
    })

  for (chunk in chunk_rows(length(records), options@chunk_size)) {
    grist_request(doc, "tables", table, "records") |>
      httr2::req_method("PUT") |>
      req_noparse(options) |>
      httr2::req_url_query(
        onmany = if (multiple != "first") multiple,
        noadd = if (mode == "update") "true",
        noupdate = if (mode == "insert") "true"
      ) |>
      req_json_body(list(records = records[chunk])) |>
      grist_perform()
  }
  invisible()
}

# Grist updates rows by ID with `PATCH`, which errors on a row that doesn't
# exist, and matches other columns with `PUT`, which skips rows with no match
# without saying which. Each endpoint supports one value of `unmatched`.
check_unmatched <- function(unmatched, allowed, by, call = caller_env()) {
  if (unmatched == allowed) {
    return(invisible())
  }
  if (allowed == "error") {
    cli::cli_abort(
      c(
        'Can\'t use {.code unmatched = "ignore"} when {.code by = "id"}.',
        i = "Grist errors when a row ID doesn't exist.",
        i = "Set {.arg by} to a key column to skip rows with no match."
      ),
      class = "gristmillr_unmatched",
      call = call
    )
  }
  cli::cli_abort(
    c(
      'Can\'t use {.code unmatched = "error"} when {.arg by} is not {.val id}.',
      i = "Grist skips rows with no match, and doesn't say which.",
      i = 'Use {.code unmatched = "ignore"}.'
    ),
    class = "gristmillr_unmatched",
    call = call
  )
}

check_by <- function(by, call = caller_env()) {
  if (!is.character(by) || length(by) == 0 || anyNA(by) || anyDuplicated(by)) {
    cli::cli_abort(
      "{.arg by} must be a character vector of column names, not {.obj_type_friendly {by}}.",
      call = call
    )
  }
  if (length(by) > 1 && "id" %in% by) {
    cli::cli_abort(
      c(
        "{.arg by} can't combine {.val id} with other columns.",
        i = 'Use {.code by = "id"} on its own to match row IDs.'
      ),
      call = call
    )
  }
}

req_noparse <- function(req, options) {
  httr2::req_url_query(req, noparse = if (!options@parse) "true")
}

check_upsert_by <- function(data, by, call = caller_env()) {
  if (!is.character(by) || length(by) == 0 || anyNA(by) || anyDuplicated(by)) {
    cli::cli_abort(
      "{.arg by} must be a character vector of column names, not {.obj_type_friendly {by}}.",
      call = call
    )
  }
  if ("id" %in% names(data)) {
    cli::cli_abort(
      c(
        "{.arg data} can't have an {.field id} column when upserting.",
        i = "Use {.fn grist_records_update} to change rows by ID."
      ),
      call = call
    )
  }
  missing <- setdiff(by, names(data))
  if (length(missing) > 0) {
    cli::cli_abort(
      c(
        "Every column in {.arg by} must be in {.arg data}.",
        x = "Missing from {.arg data}: {.field {missing}}."
      ),
      call = call
    )
  }

  keys <- data[by]
  if (anyNA(keys)) {
    cli::cli_abort(
      c(
        "{.arg by} columns can't have missing values.",
        x = "Rows with missing keys: {which(!stats::complete.cases(keys))}."
      ),
      call = call
    )
  }
  dups <- which(duplicated(keys) | duplicated(keys, fromLast = TRUE))
  if (length(dups) > 0) {
    cli::cli_abort(
      c(
        "{.arg by} must identify each row of {.arg data} uniquely.",
        x = "Rows with duplicated keys: {dups}."
      ),
      call = call
    )
  }
  invisible()
}

#' @rdname grist_records
#' @export
grist_records_delete <- function(data, doc, table, options = NULL) {
  doc <- grist_doc(doc)
  check_string(table)
  options <- as_write_options(options)

  ids <- if (is.data.frame(data)) {
    if (!"id" %in% names(data)) {
      cli::cli_abort("{.arg data} must have an {.field id} column.")
    }
    as_row_ids(data$id, arg = "data$id")
  } else {
    as_row_ids(data)
  }

  for (chunk in chunk_rows(length(ids), options@chunk_size)) {
    grist_request(doc, "tables", table, "records", "delete") |>
      httr2::req_method("POST") |>
      req_json_body(json_array(ids[chunk])) |>
      grist_perform()
  }
  invisible(data)
}

# Row IDs as integers. Numbers and strings are accepted if they convert to an
# integer without loss, so `1`, `1L` and `"1"` pass but `1.5`, `"1.5"`, `NA`
# and `"a"` don't.
as_row_ids <- function(x, arg = caller_arg(x), call = caller_env()) {
  ids <- if (is.character(x)) {
    ids <- suppressWarnings(as.integer(x))
    ids[!is.na(ids) & as.character(ids) != x] <- NA_integer_
    ids
  } else if (is.numeric(x)) {
    try_fetch(
      vctrs::vec_cast(x, integer()),
      vctrs_error_cast = function(cnd) rep(NA_integer_, length(x))
    )
  }

  if (is.null(ids) || anyNA(ids)) {
    cli::cli_abort(
      c(
        "{.arg {arg}} must be whole numbers without missing values.",
        i = "Got {.obj_type_friendly {x}}."
      ),
      class = "gristmillr_invalid_ids",
      call = call
    )
  }
  ids
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

# Query parameters shared by the endpoints that list rows.
check_list_query <- function(filter, sort, limit, call = caller_env()) {
  check_filter(filter, call = call)
  check_character(sort, allow_null = TRUE, call = call)
  check_number_whole(limit, min = 0, allow_null = TRUE, call = call)
}

req_list_query <- function(req, filter = NULL, sort = NULL, limit = NULL) {
  httr2::req_url_query(
    req,
    filter = if (length(filter) > 0) {
      as.character(jsonlite::toJSON(filter, auto_unbox = FALSE))
    },
    sort = if (length(sort) > 0) paste(sort, collapse = ","),
    limit = limit
  )
}
