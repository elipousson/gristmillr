# Helpers shared by grist_export() and grist_import(), which describe tables
# with a data-dict.yaml file (https://data-dict.tidyverse.org/).

data_dict_version <- "0.1.0"

check_yaml12 <- function(call = caller_env()) {
  check_installed("yaml12", "to read and write data dictionaries.", call = call)
}

check_nanoparquet <- function(call = caller_env()) {
  check_installed(
    "nanoparquet",
    "to read and write Parquet files.",
    call = call
  )
}

# Grist column type -> data-dict -------------------------------------------

# Parse the `choices` out of a column's widget options JSON.
column_choices <- function(widget_options) {
  if (is.na(widget_options) || !nzchar(widget_options)) {
    return(character())
  }
  opts <- tryCatch(
    jsonlite::fromJSON(widget_options, simplifyVector = FALSE),
    error = function(cnd) list()
  )
  as.character(unlist(opts$choices, use.names = FALSE))
}

# The data-dict type of a Grist column, plus the properties that come with it.
# Returns a list with `type` (NULL when the column can't be described),
# `values` (for enums), `time_zone` and `ref` (the target table of a
# reference).
dict_type <- function(grist_type, choices = character()) {
  parts <- split_type(grist_type)
  switch(
    parts$base,
    Text = list(type = "string"),
    Int = ,
    Numeric = list(type = "number"),
    Bool = list(type = "boolean"),
    Date = list(type = "date"),
    DateTime = list(type = "datetime", time_zone = parts$arg %||% "UTC"),
    Choice = if (length(choices) > 0) {
      list(type = "enum", values = choices)
    } else {
      list(type = "string")
    },
    ChoiceList = if (length(choices) > 0) {
      list(type = "list(enum)", values = choices)
    } else {
      list(type = "list(string)")
    },
    Ref = list(type = "number(id)", ref = parts$arg),
    RefList = list(type = "list(number(id))", ref = parts$arg),
    Attachments = list(type = "list(number(id))"),
    list(type = NULL)
  )
}

# Representative values -----------------------------------------------------

# Up to `n` values spread evenly across the sorted unique values.
sample_values <- function(x, n = 5) {
  x <- unique(sort(x[!is.na(x)]))
  if (length(x) <= n) {
    return(x)
  }
  x[unique(round(seq(1, length(x), length.out = n)))]
}

iso_date <- function(x) format(x, "%Y-%m-%d")

iso_datetime <- function(x, tz) format(x, "%Y-%m-%dT%H:%M:%S", tz = tz)

# The properties data-dict requires to describe a column's values: `examples`,
# `range` or `values`, depending on the type. Returns a named list; a `todo`
# when there is nothing to describe or `examples = "none"`.
dict_values <- function(x, dtype, examples) {
  base <- sub("^list\\((.*)\\)$", "\\1", dtype$type)
  if (!is.null(dtype$values)) {
    return(list(values = as.list(dtype$values)))
  }
  if (base == "boolean") {
    return(list())
  }

  if (is.list(x)) {
    x <- unlist(x, use.names = FALSE)
  }
  if (is.character(x)) {
    x[!nzchar(x)] <- NA
  }

  # data-dict requires a description of the values. With nothing to sample,
  # say so with an empty list (or an open range) and a todo.
  if (examples == "none" || length(x[!is.na(x)]) == 0) {
    todo <- if (examples == "none") {
      "Add representative values."
    } else {
      "No values to sample. Add representative values."
    }
    empty <- if (base %in% c("date", "datetime")) {
      list(range = list(-Inf, Inf))
    } else {
      list(examples = list())
    }
    return(c(empty, list(todo = todo)))
  }

  if (base == "date") {
    return(list(
      range = list(
        iso_date(min(x, na.rm = TRUE)),
        iso_date(max(x, na.rm = TRUE))
      )
    ))
  }
  if (base == "datetime") {
    tz <- dtype$time_zone %||% "UTC"
    return(list(
      range = list(
        iso_datetime(min(x, na.rm = TRUE), tz),
        iso_datetime(max(x, na.rm = TRUE), tz)
      )
    ))
  }
  if (base %in% c("number", "number(id)")) {
    return(list(examples = as.list(unname(sample_values(as.numeric(x))))))
  }
  list(examples = as.list(sample_values(as.character(x))))
}

# Reading a dictionary --------------------------------------------------------

# Read a data-dict.yaml. `path` is a file or a directory holding one. Returns
# the parsed dictionary with the directory it came from in `dir`.
read_data_dict <- function(path, call = caller_env()) {
  check_yaml12(call)
  check_string(path, call = call)
  file <- if (dir.exists(path)) file.path(path, "data-dict.yaml") else path
  if (!file.exists(file)) {
    cli::cli_abort(
      "Can't find a data dictionary at {.path {file}}.",
      call = call
    )
  }
  dict <- yaml12::read_yaml(file)
  if (!is.list(dict) || is.null(dict$tables)) {
    cli::cli_abort(
      "{.path {file}} is not a data dictionary: it has no {.field tables}.",
      call = call
    )
  }
  dict$dir <- dirname(normalizePath(file))
  dict
}

# YAML collapses sequences of one value into a scalar, so normalise.
as_seq <- function(x) {
  if (is.null(x)) list() else as.list(x)
}

# Parse "orders.person = people.id" into its two sides, or NULL.
parse_join <- function(join) {
  m <- regmatches(
    join,
    regexec("^\\s*(\\w+)\\.(\\w+)\\s*=\\s*(\\w+)\\.(\\w+)\\s*$", join)
  )[[1]]
  if (length(m) == 0) {
    return(NULL)
  }
  list(
    left = list(table = m[[2]], column = m[[3]]),
    right = list(table = m[[4]], column = m[[5]])
  )
}

# yaml12 writes infinite numbers as `inf`, which YAML 1.2 reads as a string.
# data-dict uses `.inf` for open ranges.
write_data_dict <- function(dict, file) {
  yaml <- yaml12::format_yaml(dict)
  yaml <- gsub("(?m)^(\\s+- )(-?)inf$", "\\1\\2.inf", yaml, perl = TRUE)
  writeLines(yaml, file)
}
