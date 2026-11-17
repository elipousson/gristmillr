#' Export a document's tables to files and a data dictionary
#'
#' @description
#' `grist_export()` writes each table of a document to a Parquet, CSV or JSON
#' file in a directory, and describes the tables in a `data-dict.yaml` file following the
#' [data-dict](https://data-dict.tidyverse.org/) specification. The result can
#' be read by other tools, or loaded into another Grist document with
#' [grist_import()].
#'
#' Tables are read with `convert = "auto"`, so dates, integers and logicals
#' are typed. The dictionary records what Parquet files can't keep: column
#' labels and descriptions, time zones, the choices of `Choice` columns, and
#' how tables refer to each other.
#'
#' @section What the dictionary contains:
#' * Every table gets an `id` column, Grist's row ID, as its primary key.
#' * A `Ref` column is a `number(id)` foreign key to the `id` of the table it
#'   points at, with a `many-to-one` relationship. `RefList` and `Attachments`
#'   columns are lists of IDs. data-dict can't declare foreign keys on lists,
#'   so no relationship is recorded for them.
#' * `Int` and `Numeric` columns are both `number`. Formula columns are
#'   exported as values, not formulas.
#' * Columns of type `Any` are listed by name only.
#'
#' @section File formats:
#' `"parquet"` keeps every type, including time zones and list columns, and is
#' the default. `"json"` keeps numbers, logicals, missing values and list
#' columns, and writes dates and date-times as ISO 8601 text (date-times in
#' UTC). `"csv"` is plain text: list columns are written as JSON arrays,
#' and an empty `Text` cell can't be told apart from a missing one.
#'
#' data-dict can only point at Parquet files with `source`, so for CSV and
#' JSON the dictionary has no `source`, and files are found by name
#' (`<table>.csv` or `<table>.json`) next to the dictionary.
#'
#' Requires the yaml12 package, and the nanoparquet package for Parquet.
#'
#' @inheritParams grist_records
#' @param to Directory to write to. It is created if it doesn't exist.
#' @param tables Table IDs to export. `NULL` exports every table.
#' @param format File format for the tables: `"parquet"`, `"csv"` or `"json"`.
#' @param examples data-dict describes the values of each column. `"sample"`
#'   records up to five real example values (or the range of dates) from the
#'   data. `"none"` leaves them empty with a `todo`, so no data appears in the
#'   dictionary. Columns with no values are also left empty with a `todo`.
#' @param overwrite Whether to replace existing files.
#' @returns A data frame with one row per exported table: `table`, `rows`,
#'   `columns` and `path`, invisibly.
#' @family export
#' @examplesIf FALSE
#' doc <- grist_doc("am2iHJ9Amvo7Ve3EE5emtu")
#' grist_export(doc, "pets-export")
#'
#' # Load it into another document
#' grist_import(grist_doc("<new doc id>"), "pets-export")
#' @export
grist_export <- function(
  doc,
  to = ".",
  tables = NULL,
  format = c("parquet", "csv", "json"),
  examples = c("sample", "none"),
  overwrite = FALSE
) {
  doc <- grist_doc(doc)
  check_string(to)
  check_character(tables, allow_null = TRUE)
  format <- arg_match(format)
  examples <- arg_match(examples)
  check_bool(overwrite)
  check_yaml12()
  if (format == "parquet") {
    check_nanoparquet()
  }

  available <- grist_tables(doc)$id
  available <- available[!startsWith(available, "GristSummary_")]
  tables <- tables %||% available
  unknown <- setdiff(tables, available)
  if (length(unknown) > 0) {
    cli::cli_abort(
      c(
        "Can't find {length(unknown)} table{?s} in the document.",
        x = "Unknown table{?s}: {.val {unknown}}.",
        i = "Use {.fn grist_tables} to list the tables."
      )
    )
  }

  files <- file.path(to, c(paste0(tables, ".", format), "data-dict.yaml"))
  existing <- files[file.exists(files)]
  if (length(existing) > 0 && !overwrite) {
    cli::cli_abort(
      c(
        "Files already exist.",
        x = "Existing: {.path {existing}}.",
        i = "Use {.code overwrite = TRUE} to replace them."
      ),
      class = "gristmillr_file_exists"
    )
  }
  dir.create(to, recursive = TRUE, showWarnings = FALSE)

  read_options <- grist_read_options(col_names = "id")
  dict_tables <- list()
  relationships <- list()
  summary <- list()
  for (table in tables) {
    columns <- grist_columns(doc, table)
    data <- grist_records(doc, table, options = read_options)

    path <- file.path(to, paste0(table, ".", format))
    write_table_file(data, path, format)

    described <- dict_table(table, columns, data, tables, examples, format)
    dict_tables[[length(dict_tables) + 1]] <- described$table
    relationships <- c(relationships, described$relationships)
    summary[[length(summary) + 1]] <- list(
      table = table,
      rows = nrow(data),
      columns = ncol(data) - 1L,
      path = path
    )
  }

  info <- grist_doc_info(doc)
  dict <- list(
    `$version` = data_dict_version,
    `$learn_more` = "https://data-dict.tidyverse.org/",
    label = info$name,
    description = "Exported from Grist with gristmillr::grist_export().",
    tables = dict_tables,
    relationships = relationships
  )
  version <- tryCatch(grist_doc_history(doc)$hash[[1]], error = function(cnd) {
    NULL
  })
  if (!is.null(version)) {
    dict <- c(dict[1:2], list(version = list(hash = version)), dict[-(1:2)])
  }
  if (length(relationships) == 0) {
    dict$relationships <- NULL
  }
  write_data_dict(dict, file.path(to, "data-dict.yaml"))

  invisible(new_tbl(
    list(
      table = map_chr(summary, function(x) x$table),
      rows = map_int(summary, function(x) as.integer(x$rows)),
      columns = map_int(summary, function(x) as.integer(x$columns)),
      path = map_chr(summary, function(x) x$path)
    ),
    n = length(summary)
  ))
}

# Describe one table: its data-dict entry and the relationships it declares.
dict_table <- function(table, columns, data, exported, examples, format) {
  id_column <- c(
    list(
      name = "id",
      label = "Row ID",
      type = "number(id)",
      constraints = list("primary_key"),
      description = "Grist row ID."
    ),
    dict_values(data$id, list(type = "number(id)"), examples)
  )

  relationships <- list()
  cols <- map(seq_len(nrow(columns)), function(i) {
    id <- columns$id[[i]]
    choices <- column_choices(columns$widget_options[[i]])
    dtype <- dict_type(columns$type[[i]], choices)
    col <- list(name = id)
    if (!is.na(columns$label[[i]]) && columns$label[[i]] != id) {
      col$label <- columns$label[[i]]
    }
    if (!is.na(columns$description[[i]])) {
      col$description <- columns$description[[i]]
    }
    if (is.null(dtype$type)) {
      return(col)
    }

    col$type <- dtype$type
    if (identical(dtype$type, "number(id)") && dtype$ref %in% exported) {
      col$constraints <- list("foreign_key")
      relationships[[length(relationships) + 1]] <<- list(
        join = paste0(table, ".", id, " = ", dtype$ref, ".id"),
        cardinality = "many-to-one"
      )
    }
    if (dtype$type == "datetime") {
      col$time_zone <- dtype$time_zone
    }
    c(col, dict_values(data[[id]], dtype, examples))
  })

  # data-dict can only point at Parquet sources. Other formats are found by
  # file name, `<table>.<format>`, next to the dictionary.
  described <- list(name = table)
  if (format == "parquet") {
    described$source <- list(parquet = paste0(table, ".parquet"))
  }
  described$columns <- c(list(id_column), cols)

  list(table = described, relationships = relationships)
}
