#' Import tables from Parquet files and a data dictionary
#'
#' @description
#' `grist_import()` creates tables in a document from a
#' [data-dict](https://data-dict.tidyverse.org/) `data-dict.yaml` file and the
#' Parquet files it points to, then loads the rows. It is the counterpart of
#' [grist_export()], and also suits data prepared elsewhere, such as lists
#' copied out of another low-code tool.
#'
#' @section Column types:
#' Grist types come from the dictionary and the data:
#'
#' | data-dict | Grist |
#' |---|---|
#' | `string` | `Text` |
#' | `number`, `number(id)` | `Int` if the data are integers, otherwise `Numeric` |
#' | `boolean` | `Bool` |
#' | `date` | `Date` |
#' | `datetime` | `DateTime`, in the column's `time_zone` (`UTC` if it is `naive` or missing) |
#' | `enum`, `list(enum)` | `Choice`, `ChoiceList`, with the `values` as choices |
#' | `list(string)` | `ChoiceList` |
#' | no type | `Any` |
#'
#' Only columns described in the dictionary are imported. `label` and
#' `description` are kept. A column named `id` isn't created (Grist has its
#' own row IDs), but is used as a key if other tables refer to it.
#' Other types, including `list(number(id))`, need an entry in `types`.
#'
#' @section References between tables:
#' A column with the `foreign_key` constraint that is part of a `relationships`
#' entry (`join: orders.person = people.id`) becomes a `Ref` column. The tables
#' are loaded first, and then each reference is rewritten from the source key
#' to the row ID Grist assigned, so tables can be loaded in any order and may
#' refer to themselves. The key column stays in the table as ordinary data.
#'
#' data-dict can't declare foreign keys on list columns, so use `types` for
#' `RefList` columns, e.g. `types = c("Orders.items" = "RefList:Items")`. The
#' target table must have a `primary_key` column, whose values the list holds.
#'
#' A `Ref` column shows its target's row ID unless you choose a column to show
#' with `display`.
#'
#' Requires the yaml12 and nanoparquet packages.
#'
#' @inheritParams grist_records
#' @param from Path to a `data-dict.yaml` file, or to a directory containing
#'   one. Parquet paths in the dictionary are relative to it.
#' @param tables Names of the dictionary's tables to import. `NULL` imports
#'   all of them.
#' @param types A named character vector that overrides Grist column types.
#'   Names are `"Table.column"`, values are Grist types such as `"Numeric"`,
#'   `"Ref:People"` or `"RefList:Items"`.
#' @param display A named character vector choosing the column a `Ref` or
#'   `RefList` column shows, e.g. `c("Orders.person" = "name")`.
#' @param orphans What to do with references to a key that doesn't exist in
#'   the target table: stop with an `"error"` before changing anything, or
#'   leave the reference `"empty"`.
#' @param if_exists What to do when a table already exists in the document:
#'   stop with an `"error"` before changing anything, or `"append"` rows to
#'   it. Existing tables keep their columns and types.
#' @param options A [grist_write_options()] object.
#' @returns A data frame with one row per imported table: `table`, `rows` and
#'   `columns`, invisibly. If a request fails part way, tables and rows
#'   already created remain in the document.
#' @family export
#' @examplesIf FALSE
#' doc <- grist_doc("<new doc id>")
#' grist_import(doc, "pets-export")
#'
#' grist_import(
#'   doc,
#'   "pets-export",
#'   types = c("Orders.buddies" = "RefList:People"),
#'   display = c("Orders.person" = "name")
#' )
#' @export
grist_import <- function(
  doc,
  from,
  tables = NULL,
  types = NULL,
  display = NULL,
  orphans = c("error", "empty"),
  if_exists = c("error", "append"),
  options = NULL
) {
  doc <- grist_doc(doc)
  check_string(from)
  check_character(tables, allow_null = TRUE)
  check_named_strings(types)
  check_named_strings(display)
  orphans <- arg_match(orphans)
  if_exists <- arg_match(if_exists)
  options <- as_write_options(options)
  check_nanoparquet()

  dict <- read_data_dict(from)
  plan <- import_plan(dict, tables, types, display)
  data <- map(plan$tables, read_import_data, dir = dict$dir)
  names(data) <- names(plan$tables)
  check_import_data(plan, data)

  existing <- grist_tables(doc)$id
  table_ids <- map(names(plan$tables), function(name) {
    existing[match(tolower(grist_table_id(name)), tolower(existing))]
  })
  names(table_ids) <- names(plan$tables)
  clash <- names(plan$tables)[!is.na(unlist(table_ids))]
  if (length(clash) > 0 && if_exists == "error") {
    cli::cli_abort(
      c(
        "{length(clash)} table{?s} already exist{?s/} in the document.",
        x = "Existing: {.val {clash}}.",
        i = 'Use {.code if_exists = "append"} to add rows to existing tables.'
      )
    )
  }
  keys <- import_keys(plan, data)
  check_orphans(plan, data, keys, orphans)

  # Create the tables. References are created as plain columns and typed once
  # every table exists, because they may point at tables created later.
  col_ids <- list()
  created <- character()
  for (name in names(plan$tables)) {
    spec <- plan$tables[[name]]
    if (is.na(table_ids[[name]])) {
      table_ids[[name]] <- grist_table_create(
        doc,
        name,
        import_columns(spec, data[[name]])
      )
      created <- c(created, name)
    }
    col_ids[[name]] <- match_column_ids(doc, table_ids[[name]], spec$columns)
  }
  for (name in created) {
    for (col in plan$tables[[name]]$fk_columns) {
      fk <- plan$fks[[paste(name, col, sep = ".")]]
      grist_columns_modify(
        doc,
        table_ids[[name]],
        data.frame(
          id = col_ids[[name]][[col]],
          type = paste0(fk$kind, ":", table_ids[[fk$target]])
        )
      )
    }
  }

  # Load rows, leaving references empty.
  new_ids <- list()
  for (name in names(plan$tables)) {
    spec <- plan$tables[[name]]
    rows <- data[[name]][setdiff(names(spec$columns), spec$fk_columns)]
    names(rows) <- col_ids[[name]][names(rows)]
    new_ids[[name]] <- grist_records_add(
      doc,
      table_ids[[name]],
      rows,
      options = options
    )
  }

  # Rewrite references from source keys to the new row IDs.
  maps <- map(names(plan$tables), function(name) {
    key <- keys[[name]]
    if (is.null(key)) {
      return(NULL)
    }
    stats::setNames(
      as.integer(new_ids[[name]]),
      as.character(data[[name]][[key]])
    )
  })
  names(maps) <- names(plan$tables)

  for (name in names(plan$tables)) {
    spec <- plan$tables[[name]]
    if (length(spec$fk_columns) == 0 || length(new_ids[[name]]) == 0) {
      next
    }
    refs <- data.frame(id = new_ids[[name]])
    for (col in spec$fk_columns) {
      target <- plan$fks[[paste(name, col, sep = ".")]]$target
      refs[[col_ids[[name]][[col]]]] <- map_references(
        data[[name]][[col]],
        maps[[target]]
      )
    }
    grist_records_update(doc, table_ids[[name]], refs, options = options)
  }

  set_display_columns(doc, plan, table_ids, col_ids, display)

  invisible(new_tbl(
    list(
      table = names(plan$tables),
      rows = unname(map_int(data, nrow)),
      columns = map_int(plan$tables, function(x) length(x$columns))
    ),
    n = length(plan$tables)
  ))
}

check_named_strings <- function(x, arg = caller_arg(x), call = caller_env()) {
  if (is.null(x)) {
    return(invisible())
  }
  if (!is.character(x) || is.null(names(x)) || !all(nzchar(names(x)))) {
    cli::cli_abort(
      "{.arg {arg}} must be a named character vector, like {.code c(\"Table.column\" = \"value\")}.",
      call = call
    )
  }
  bad <- names(x)[!grepl("^[^.]+\\.[^.]+$", names(x))]
  if (length(bad) > 0) {
    cli::cli_abort(
      c(
        "Names in {.arg {arg}} must have the form {.code Table.column}.",
        x = "Can't use {.val {bad}}."
      ),
      call = call
    )
  }
  invisible()
}

# Planning ----------------------------------------------------------------

# Turn a dictionary into a list of tables with Grist column types and a map of
# foreign keys.
import_plan <- function(dict, tables, types, display, call = caller_env()) {
  specs <- dict$tables
  names(specs) <- map_chr(specs, function(x) x$name)

  tables <- tables %||% names(specs)
  unknown <- setdiff(tables, names(specs))
  if (length(unknown) > 0) {
    cli::cli_abort(
      c(
        "The dictionary has no table{?s} {.val {unknown}}.",
        i = "Tables: {.val {names(specs)}}."
      ),
      call = call
    )
  }

  columns_of <- function(table) {
    cols <- specs[[table]]$columns
    names(cols) <- map_chr(cols, function(x) x$name)
    cols
  }
  pk_of <- function(table) {
    cols <- columns_of(table)
    pks <- names(cols)[map_lgl(cols, function(x) {
      "primary_key" %in% unlist(x$constraints)
    })]
    pks
  }

  # Foreign keys from the dictionary's relationships.
  fks <- list()
  for (rel in as_seq(dict$relationships)) {
    join <- parse_join(rel$join)
    if (is.null(join)) {
      next
    }
    for (side in list(c("left", "right"), c("right", "left"))) {
      from <- join[[side[[1]]]]
      to <- join[[side[[2]]]]
      if (!from$table %in% names(specs) || !to$table %in% names(specs)) {
        next
      }
      from_col <- columns_of(from$table)[[from$column]]
      is_fk <- !is.null(from_col) &&
        "foreign_key" %in% unlist(from_col$constraints)
      if (is_fk && to$column %in% pk_of(to$table)) {
        fks[[paste(from$table, from$column, sep = ".")]] <- list(
          table = from$table,
          column = from$column,
          target = to$table,
          kind = "Ref"
        )
      }
    }
  }

  # Overrides.
  override <- as.list(types)
  for (nm in names(override)) {
    parts <- strsplit(nm, ".", fixed = TRUE)[[1]]
    if (
      !parts[[1]] %in% names(specs) ||
        !parts[[2]] %in% names(columns_of(parts[[1]]))
    ) {
      cli::cli_abort(
        "{.arg types} names a column that isn't in the dictionary: {.val {nm}}.",
        call = call
      )
    }
    ref <- split_type(override[[nm]])
    if (ref$base %in% c("Ref", "RefList")) {
      if (is.null(ref$arg) || !ref$arg %in% names(specs)) {
        cli::cli_abort(
          "{.arg types} entry {.val {nm}} refers to a table that isn't in the dictionary.",
          call = call
        )
      }
      fks[[nm]] <- list(
        table = parts[[1]],
        column = parts[[2]],
        target = ref$arg,
        kind = ref$base
      )
    } else {
      fks[[nm]] <- NULL
    }
  }

  fks <- fks[map_lgl(fks, function(fk) fk$table %in% tables)]
  missing_targets <- unique(map_chr(fks, function(fk) fk$target))
  missing_targets <- setdiff(missing_targets, tables)
  if (length(missing_targets) > 0) {
    cli::cli_abort(
      c(
        "Can't import references to {.val {missing_targets}} without importing it.",
        i = "Add {.val {missing_targets}} to {.arg tables}."
      ),
      call = call
    )
  }

  plan_tables <- map(tables, function(table) {
    cols <- columns_of(table)
    cols <- cols[names(cols) != "id"]
    described <- map(names(cols), function(col) {
      key <- paste(table, col, sep = ".")
      grist_type <- if (key %in% names(override)) {
        override[[key]]
      } else if (!is.null(fks[[key]])) {
        paste0(fks[[key]]$kind, ":", fks[[key]]$target)
      } else {
        NULL
      }
      c(cols[[col]], list(grist_type = grist_type))
    })
    names(described) <- names(cols)
    list(
      name = table,
      source = specs[[table]]$source$parquet,
      columns = described,
      fk_columns = names(cols)[
        paste(table, names(cols), sep = ".") %in% names(fks)
      ],
      key = {
        pk <- pk_of(table)
        if (length(pk) == 1) pk else NULL
      }
    )
  })
  names(plan_tables) <- tables

  list(tables = plan_tables, fks = fks)
}

read_import_data <- function(spec, dir, call = caller_env()) {
  if (is.null(spec$source)) {
    cli::cli_abort(
      "Table {.val {spec$name}} has no {.field source} with a Parquet file.",
      call = call
    )
  }
  path <- file.path(dir, spec$source)
  if (!file.exists(path)) {
    cli::cli_abort(
      "Can't find the Parquet file for table {.val {spec$name}}: {.path {path}}.",
      call = call
    )
  }
  data <- as.data.frame(nanoparquet::read_parquet(path))
  for (nm in names(data)) {
    if (is.factor(data[[nm]])) {
      data[[nm]] <- as.character(data[[nm]])
    }
  }
  data
}

check_import_data <- function(plan, data, call = caller_env()) {
  for (name in names(plan$tables)) {
    wanted <- names(plan$tables[[name]]$columns)
    missing <- setdiff(wanted, names(data[[name]]))
    if (length(missing) > 0) {
      cli::cli_abort(
        c(
          "The data for table {.val {name}} is missing {length(missing)} column{?s} from the dictionary.",
          x = "Missing: {.field {missing}}."
        ),
        call = call
      )
    }
  }
}

# The key column of each table that other tables refer to.
import_keys <- function(plan, data, call = caller_env()) {
  keys <- list()
  for (fk in plan$fks) {
    target <- plan$tables[[fk$target]]
    if (is.null(target$key)) {
      cli::cli_abort(
        c(
          "Can't resolve references to table {.val {fk$target}}.",
          i = "It needs a single {.code primary_key} column in the dictionary."
        ),
        call = call
      )
    }
    if (!target$key %in% names(data[[fk$target]])) {
      cli::cli_abort(
        "The data for table {.val {fk$target}} has no key column {.field {target$key}}.",
        call = call
      )
    }
    if (anyDuplicated(data[[fk$target]][[target$key]])) {
      cli::cli_abort(
        "The key {.field {fk$target}.{target$key}} has duplicated values, so references to it are ambiguous.",
        call = call
      )
    }
    keys[[fk$target]] <- target$key
  }
  keys
}

# Column specs and mapping ----------------------------------------------------

# The Grist type and widget options for a dictionary column.
import_column_type <- function(col, x) {
  if (!is.null(col$grist_type)) {
    return(list(type = col$grist_type))
  }
  type <- col$type
  if (is.null(type)) {
    return(list(type = "Any"))
  }
  base <- sub("^list\\((.*)\\)$", "\\1", type)
  is_list <- grepl("^list\\(", type)
  choices <- if (!is.null(col$values)) {
    as.character(names(col$values) %||% unlist(col$values))
  }
  options <- if (length(choices) > 0) {
    as.character(jsonlite::toJSON(
      list(choices = as.list(choices)),
      auto_unbox = TRUE
    ))
  }

  if (is_list) {
    if (base %in% c("enum", "string")) {
      return(list(type = "ChoiceList", widget_options = options))
    }
    return(NULL)
  }
  switch(
    sub("\\(.*$", "", base),
    string = list(type = "Text"),
    number = list(type = if (is.integer(x)) "Int" else "Numeric"),
    boolean = list(type = "Bool"),
    date = list(type = "Date"),
    datetime = {
      tz <- col$time_zone %||% "UTC"
      list(
        type = paste0("DateTime:", if (identical(tz, "naive")) "UTC" else tz)
      )
    },
    enum = list(type = "Choice", widget_options = options),
    NULL
  )
}

import_columns <- function(spec, data) {
  rows <- map(names(spec$columns), function(name) {
    col <- spec$columns[[name]]
    resolved <- if (name %in% spec$fk_columns) {
      list(type = "Any")
    } else {
      import_column_type(col, data[[name]])
    }
    if (is.null(resolved)) {
      cli::cli_abort(
        c(
          "Can't import column {.field {spec$name}.{name}} of type {.val {col$type}}.",
          i = "Set its Grist type with {.arg types}, e.g. {.code types = c(\"{spec$name}.{name}\" = \"Any\")}."
        ),
        call = NULL
      )
    }
    data.frame(
      id = name,
      type = resolved$type,
      label = name,
      description = as.character(col$description %||% NA_character_),
      widget_options = as.character(resolved$widget_options %||% NA_character_)
    )
  })
  do.call(rbind, rows)
}

# Names of Grist columns, matched by the label each column was created with.
match_column_ids <- function(doc, table_id, columns) {
  existing <- grist_columns(doc, table_id)
  ids <- existing$id[match(names(columns), existing$label)]
  ids[is.na(ids)] <- existing$id[match(names(columns), existing$id)][is.na(ids)]
  names(ids) <- names(columns)
  if (anyNA(ids)) {
    cli::cli_abort(
      "The table {.val {table_id}} has no column for {.field {names(columns)[is.na(ids)]}}."
    )
  }
  ids
}

# References ------------------------------------------------------------------

check_orphans <- function(plan, data, keys, orphans, call = caller_env()) {
  if (orphans != "error") {
    return(invisible())
  }
  for (fk in plan$fks) {
    values <- unlist(data[[fk$table]][[fk$column]], use.names = FALSE)
    known <- data[[fk$target]][[keys[[fk$target]]]]
    bad <- unique(values[!is.na(values) & !values %in% known])
    if (length(bad) > 0) {
      shown <- utils::head(bad, 5)
      cli::cli_abort(
        c(
          "Column {.field {fk$table}.{fk$column}} refers to {length(bad)} key{?s} that {?is/are} not in {.val {fk$target}}.",
          x = "Missing keys: {.val {shown}}{if (length(bad) > 5) ', ...'}.",
          i = 'Use {.code orphans = "empty"} to leave them empty.'
        ),
        call = call
      )
    }
  }
}

# Map source keys to row IDs. Scalars give an integer vector (0 when empty),
# list cells give a list of integer vectors.
map_references <- function(x, lookup) {
  lookup_one <- function(k) {
    ids <- unname(lookup[as.character(k)])
    ids[is.na(ids)] <- 0L
    ids
  }
  if (is.list(x)) {
    return(map(x, function(cell) {
      cell <- cell[!is.na(cell)]
      ids <- lookup_one(cell)
      ids[ids != 0L]
    }))
  }
  out <- lookup_one(x)
  out[is.na(x)] <- 0L
  out
}

set_display_columns <- function(doc, plan, table_ids, col_ids, display) {
  if (length(display) == 0) {
    return(invisible())
  }
  for (nm in names(display)) {
    parts <- strsplit(nm, ".", fixed = TRUE)[[1]]
    fk <- plan$fks[[nm]]
    if (is.null(fk)) {
      cli::cli_abort(
        "{.arg display} names {.val {nm}}, which is not a reference column."
      )
    }
    target_columns <- grist_columns(doc, table_ids[[fk$target]])
    show <- display[[nm]]
    ref <- target_columns$col_ref[match(show, target_columns$label)]
    if (is.na(ref)) {
      ref <- target_columns$col_ref[match(show, target_columns$id)]
    }
    if (is.na(ref)) {
      cli::cli_abort(
        "Table {.val {fk$target}} has no column {.field {show}} to display for {.val {nm}}."
      )
    }
    grist_columns_modify(
      doc,
      table_ids[[parts[[1]]]],
      data.frame(id = col_ids[[parts[[1]]]][[parts[[2]]]], visible_col = ref)
    )
  }
  invisible()
}

# The ID Grist gives a table created with `name`: invalid characters become
# underscores and the first letter is capitalised.
grist_table_id <- function(name) {
  id <- gsub("[^A-Za-z0-9_]", "_", name)
  paste0(toupper(substr(id, 1, 1)), substring(id, 2))
}
