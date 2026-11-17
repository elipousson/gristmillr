# Conversion between Grist cell values and R vectors ------------------------
#
# Grist returns cells as JSON. With `cellFormat = "normal"`:
#   * Date / DateTime cells are seconds since the epoch.
#   * Ref cells are integer row IDs (0 is empty).
#   * ChoiceList, RefList and Attachments cells are `["L", ...]`.
#   * Anything that does not match the column type may be a string or a tagged
#     list such as `["E", ...]`.

# Build a tibble-classed data frame without depending on the tibble package.
# Printing falls back to base data frame printing if tibble isn't installed.
new_tbl <- function(x, n = NULL) {
  if (!is.null(n)) {
    n <- as.integer(n)
  }
  vctrs::new_data_frame(x, n = n, class = c("tbl_df", "tbl"))
}

is_tagged <- function(x, tag) {
  is.list(x) && length(x) > 0 && identical(x[[1]], tag)
}

is_scalar_atomic <- function(x) {
  is.atomic(x) && length(x) == 1
}

# "basic" conversion --------------------------------------------------------

simplify_column <- function(cells) {
  # `list_unchop()` returns NULL for no cells, which would drop the column.
  if (length(cells) == 0) {
    return(logical())
  }
  if (any(map_lgl(cells, is.list))) {
    return(map(cells, simplify_list_cell))
  }
  cells[map_lgl(cells, is.null)] <- list(NA)
  tryCatch(
    vctrs::list_unchop(cells),
    vctrs_error_incompatible_type = function(cnd) cells
  )
}

simplify_list_cell <- function(x) {
  if (!is_tagged(x, "L")) {
    return(x)
  }
  values <- x[-1]
  if (length(values) == 0) {
    return(NULL)
  }
  if (all(map_lgl(values, is_scalar_atomic))) {
    return(unlist(values, use.names = FALSE))
  }
  values
}

# "auto" conversion ---------------------------------------------------------

split_type <- function(type) {
  list(
    base = sub(":.*$", "", type),
    arg = if (grepl(":", type, fixed = TRUE)) sub("^[^:]*:", "", type)
  )
}

# Returns `list(value, ok)`. `ok` is `FALSE` when cells did not match the
# column type and the column was returned in its basic form.
convert_column <- function(cells, type, tz = NULL) {
  type <- split_type(type %||% "Any")
  converter <- switch(
    type$base,
    Text = ,
    Choice = as_chr_column,
    Int = ,
    Id = as_int_column,
    Numeric = ,
    PositionNumber = ,
    ManualSortPos = as_dbl_column,
    Bool = as_lgl_column,
    Date = as_date_column,
    DateTime = function(cells) {
      as_datetime_column(cells, tz %||% type$arg %||% "UTC")
    },
    Ref = as_ref_column,
    ChoiceList = function(cells) as_list_column(cells, as.character),
    RefList = ,
    Attachments = function(cells) as_list_column(cells, as.integer),
    NULL
  )

  if (is.null(converter)) {
    return(list(value = simplify_column(cells), ok = TRUE))
  }
  value <- converter(cells)
  if (is.null(value)) {
    return(list(value = simplify_column(cells), ok = FALSE))
  }
  list(value = value, ok = TRUE)
}

# Replace `NULL` cells with `NA`; return `NULL` if any cell isn't a scalar
# satisfying `pred`.
scalar_cells <- function(cells, pred) {
  cells[map_lgl(cells, is.null)] <- list(NA)
  ok <- map_lgl(cells, function(x) {
    is_scalar_atomic(x) && (is.na(x) || pred(x))
  })
  if (!all(ok)) {
    return(NULL)
  }
  unlist(cells, use.names = FALSE) %||% logical()
}

is_whole <- function(x) {
  is.numeric(x) && x == trunc(x) && abs(x) < .Machine$integer.max
}

as_chr_column <- function(cells) {
  x <- scalar_cells(cells, is.character)
  if (is.null(x)) NULL else as.character(x)
}

as_int_column <- function(cells) {
  x <- scalar_cells(cells, is_whole)
  if (is.null(x)) as_dbl_column(cells) else as.integer(x)
}

as_dbl_column <- function(cells) {
  x <- scalar_cells(cells, is.numeric)
  if (is.null(x)) NULL else as.double(x)
}

as_lgl_column <- function(cells) {
  x <- scalar_cells(cells, is.logical)
  if (is.null(x)) NULL else as.logical(x)
}

as_ref_column <- function(cells) {
  x <- scalar_cells(cells, is_whole)
  if (is.null(x)) {
    return(NULL)
  }
  x <- as.integer(x)
  x[!is.na(x) & x == 0L] <- NA_integer_
  x
}

as_date_column <- function(cells) {
  x <- scalar_cells(cells, is.numeric)
  if (is.null(x)) {
    return(NULL)
  }
  as.Date(floor(as.double(x) / 86400), origin = "1970-01-01")
}

as_datetime_column <- function(cells, tz) {
  x <- scalar_cells(cells, is.numeric)
  if (is.null(x)) {
    return(NULL)
  }
  as.POSIXct(as.double(x), origin = "1970-01-01", tz = tz)
}

as_list_column <- function(cells, coerce) {
  out <- vector("list", length(cells))
  for (i in seq_along(cells)) {
    cell <- cells[[i]]
    if (is.null(cell)) {
      out[[i]] <- coerce(NULL)
      next
    }
    if (!is_tagged(cell, "L") || !all(map_lgl(cell[-1], is_scalar_atomic))) {
      return(NULL)
    }
    out[[i]] <- coerce(unlist(cell[-1], use.names = FALSE))
  }
  out
}

# Records <-> data frames ---------------------------------------------------

records_to_df <- function(
  records,
  columns = NULL,
  convert = "auto",
  read_options = grist_read_options(),
  call = caller_env()
) {
  n <- length(records)
  ids <- map_int(records, function(x) as.integer(x$id))

  field_names <- unique(unlist(map(records, function(x) names(x$fields))))
  # Columns without any cells are still returned when metadata is available.
  col_ids <- union(columns$id, field_names)

  cols <- vector("list", length(col_ids))
  names(cols) <- col_ids
  failed <- character()

  for (col in col_ids) {
    cells <- map(records, function(x) x$fields[[col]])
    cols[[col]] <- switch(
      convert,
      raw = cells,
      basic = simplify_column(cells),
      auto = {
        type <- columns$type[match(col, columns$id)]
        res <- convert_column(
          cells,
          if (is.na(type)) NULL else type,
          read_options@tz
        )
        if (!res$ok) {
          failed <- c(failed, col)
        }
        res$value
      }
    )
  }

  if (length(failed) > 0) {
    cli::cli_warn(
      c(
        "Can't convert {length(failed)} column{?s} to the type declared in Grist.",
        i = "Returned {.field {failed}} without type conversion.",
        i = 'Use {.code convert = "basic"} to skip type conversion.'
      ),
      class = "gristmillr_warning_convert",
      call = call
    )
  }

  nms <- col_ids
  if (read_options@col_names == "label" && !is.null(columns)) {
    labels <- columns$label[match(col_ids, columns$id)]
    nms <- ifelse(is.na(labels), col_ids, labels)
  }
  out <- c(list(id = ids), cols)
  names(out) <- vctrs::vec_as_names(
    c("id", nms),
    repair = "unique",
    quiet = TRUE
  )
  new_tbl(out, n = n)
}

# Convert an R column to values Grist understands.
to_cells <- function(x) {
  if (is.factor(x)) {
    x <- as.character(x)
  }
  if (inherits(x, "Date")) {
    return(map(as.double(x) * 86400, na_to_null))
  }
  if (inherits(x, "POSIXt")) {
    return(map(as.double(as.POSIXct(x)), na_to_null))
  }
  if (is.list(x)) {
    return(map(x, list_cell))
  }
  map(x, na_to_null)
}

na_to_null <- function(x) {
  if (length(x) == 1 && is.na(x)) NULL else x
}

list_cell <- function(x) {
  if (is.null(x)) {
    return(NULL)
  }
  c(list("L"), as.list(x))
}

check_data_frame <- function(
  data,
  arg = caller_arg(data),
  call = caller_env()
) {
  if (!is.data.frame(data)) {
    cli::cli_abort(
      "{.arg {arg}} must be a data frame, not {.obj_type_friendly {data}}.",
      call = call
    )
  }
}

# Build the `records` payload from a data frame. When `with_id`, an `id` column
# is required and sent as the record ID.
df_to_records <- function(data, with_id = FALSE, convert = "auto") {
  n <- nrow(data)
  ids <- if (with_id) data$id
  fields <- data[setdiff(names(data), "id")]

  cells <- switch(
    convert,
    raw = map(fields, function(x) if (is.list(x)) x else as.list(x)),
    map(fields, to_cells)
  )

  map(seq_len(n), function(i) {
    # Index with `[` then `[[` so `NULL` cells stay explicit JSON nulls.
    fields <- lapply(cells, function(x) x[i][[1]])
    if (length(fields) == 0) {
      fields <- empty_object()
    }
    rec <- list(fields = fields)
    if (with_id) {
      rec <- c(list(id = as.integer(ids[[i]])), rec)
    }
    rec
  })
}

check_record_columns <- function(
  data,
  columns,
  write_options,
  call = caller_env()
) {
  unknown <- setdiff(setdiff(names(data), "id"), columns$id)
  if (length(unknown) == 0) {
    return(data)
  }
  if (write_options@unknown_cols == "drop") {
    return(data[setdiff(names(data), unknown)])
  }
  cli::cli_abort(
    c(
      "{.arg data} has {length(unknown)} column{?s} not in the Grist table.",
      x = "Unknown column{?s}: {.field {unknown}}.",
      i = 'Use {.code grist_write_options(unknown_cols = "drop")} to ignore unknown columns.'
    ),
    class = "gristmillr_unknown_cols",
    call = call
  )
}

map <- function(.x, .f, ...) {
  lapply(.x, .f, ...)
}

map_lgl <- function(.x, .f, ...) {
  vapply(.x, .f, logical(1), ...)
}

map_int <- function(.x, .f, ...) {
  vapply(.x, .f, integer(1), ...)
}

# Parse the ISO 8601 UTC timestamps Grist returns for documents, orgs and
# snapshots into POSIXct. Missing values stay NA.
as_grist_time <- function(x) {
  as.POSIXct(x, format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC")
}
