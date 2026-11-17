#' Options for Grist requests, reads and writes
#'
#' @description
#' These constructors group settings that rarely change so that functions such
#' as [grist_records()] keep short signatures. Pass an options object to the
#' `options` argument of a function, or set a package-wide default with
#' `options(gristmillr.request_options = ...)`,
#' `options(gristmillr.read_options = ...)` or
#' `options(gristmillr.write_options = ...)`.
#'
#' @param timeout Request timeout in seconds.
#' @param max_tries Maximum number of attempts for a request that fails with a
#'   transient error (HTTP 429 or 503).
#' @param user_agent User agent string sent with each request. Defaults to
#'   a string identifying gristmillr.
#' @param hidden If `TRUE`, include hidden columns such as `manualSort`.
#' @param cell_format Format of cell values returned by Grist. `"normal"` uses
#'   compact values whose meaning depends on the column type. `"typed"` returns
#'   self-describing tagged values and can only be used with `convert = "raw"`.
#' @param tz Time zone used for `DateTime` columns. If `NULL`, the time zone
#'   stored in the column type is used, falling back to `"UTC"`.
#' @param col_names Whether to name columns of the returned data frame using
#'   Grist column IDs (`"id"`) or column labels (`"label"`).
#' @param chunk_size Maximum number of rows sent in a single write request.
#' @param unknown_cols What to do when data has columns that do not exist in
#'   the Grist table: `"error"` or silently `"drop"` them. Only checked when
#'   `convert = "auto"`, because other modes do not fetch column metadata.
#' @returns An S7 object holding validated settings.
#' @examples
#' grist_request_options(timeout = 60)
#' grist_read_options(col_names = "label")
#' grist_write_options(chunk_size = 250)
#' @name grist-options
NULL

#' @rdname grist-options
#' @export
grist_request_options <- new_class(
  "grist_request_options",
  properties = list(
    timeout = class_numeric,
    max_tries = class_numeric,
    user_agent = class_character
  ),
  constructor = function(timeout = 30, max_tries = 3, user_agent = NULL) {
    new_object(
      S7_object(),
      timeout = timeout,
      max_tries = max_tries,
      user_agent = user_agent %||% default_user_agent()
    )
  },
  validator = function(self) {
    if (!is_scalar_number(self@timeout) || self@timeout <= 0) {
      return("@timeout must be a single positive number.")
    }
    if (!is_scalar_number(self@max_tries) || self@max_tries < 1) {
      return("@max_tries must be a single number >= 1.")
    }
    if (!is_string(self@user_agent)) {
      return("@user_agent must be a single string.")
    }
    NULL
  }
)

#' @rdname grist-options
#' @export
grist_read_options <- new_class(
  "grist_read_options",
  properties = list(
    hidden = class_logical,
    cell_format = class_character,
    tz = S7::new_union(NULL, class_character),
    col_names = class_character
  ),
  constructor = function(
    hidden = FALSE,
    cell_format = c("normal", "typed"),
    tz = NULL,
    col_names = c("id", "label")
  ) {
    new_object(
      S7_object(),
      hidden = hidden,
      cell_format = arg_match(cell_format),
      tz = tz,
      col_names = arg_match(col_names)
    )
  },
  validator = function(self) {
    if (!is_bool(self@hidden)) {
      return("@hidden must be `TRUE` or `FALSE`.")
    }
    if (!is_string(self@cell_format, c("normal", "typed"))) {
      return('@cell_format must be "normal" or "typed".')
    }
    if (!is.null(self@tz) && !is_string(self@tz)) {
      return("@tz must be `NULL` or a single string.")
    }
    if (!is_string(self@col_names, c("id", "label"))) {
      return('@col_names must be "id" or "label".')
    }
    NULL
  }
)

#' @rdname grist-options
#' @export
grist_write_options <- new_class(
  "grist_write_options",
  properties = list(
    chunk_size = class_numeric,
    unknown_cols = class_character
  ),
  constructor = function(chunk_size = 500, unknown_cols = c("error", "drop")) {
    new_object(
      S7_object(),
      chunk_size = chunk_size,
      unknown_cols = arg_match(unknown_cols)
    )
  },
  validator = function(self) {
    if (!is_scalar_number(self@chunk_size) || self@chunk_size < 1) {
      return("@chunk_size must be a single number >= 1.")
    }
    if (!is_string(self@unknown_cols, c("error", "drop"))) {
      return('@unknown_cols must be "error" or "drop".')
    }
    NULL
  }
)

default_user_agent <- function() {
  paste0("gristmillr/", utils::packageVersion("gristmillr"))
}

# Resolve an `options` argument: use the object if supplied, otherwise a
# package-wide default set with `options()`, otherwise the constructor default.
resolve_options <- function(
  x,
  class,
  constructor,
  option,
  arg = caller_arg(x),
  call = caller_env()
) {
  x <- x %||% getOption(option)
  if (is.null(x)) {
    return(constructor())
  }
  if (!S7::S7_inherits(x, class)) {
    cli::cli_abort(
      "{.arg {arg}} must be a {.cls {class@name}} object, not {.obj_type_friendly {x}}.",
      call = call
    )
  }
  x
}

as_request_options <- function(x, arg = caller_arg(x), call = caller_env()) {
  resolve_options(
    x,
    grist_request_options,
    grist_request_options,
    "gristmillr.request_options",
    arg,
    call
  )
}

as_read_options <- function(x, arg = caller_arg(x), call = caller_env()) {
  resolve_options(
    x,
    grist_read_options,
    grist_read_options,
    "gristmillr.read_options",
    arg,
    call
  )
}

as_write_options <- function(x, arg = caller_arg(x), call = caller_env()) {
  resolve_options(
    x,
    grist_write_options,
    grist_write_options,
    "gristmillr.write_options",
    arg,
    call
  )
}

is_scalar_number <- function(x) {
  is.numeric(x) && length(x) == 1 && !is.na(x)
}

is_bool <- function(x) {
  is.logical(x) && length(x) == 1 && !is.na(x)
}

is_string <- function(x, values = NULL) {
  ok <- is.character(x) && length(x) == 1 && !is.na(x) && nzchar(x)
  ok && (is.null(values) || x %in% values)
}
