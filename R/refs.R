#' Resolve reference columns to display values
#'
#' @description
#' Grist returns `Ref` and `RefList` columns as row IDs of the referenced
#' table, while the Grist interface shows the values of a *display column*
#' (such as a person's name). `grist_resolve_refs()` looks up those display
#' values for data you have already read with [grist_records()].
#'
#' Each referenced table is fetched once, even if several columns refer to
#' it. For other kinds of joins, see `vignette("joining-tables")`.
#'
#' @param data A data frame from [grist_records()] for `table`. Use
#'   `convert = "auto"` or `"basic"` so that references are integer IDs.
#' @inheritParams grist_records
#' @param table The table `data` was read from.
#' @param columns Character vector of `Ref` or `RefList` column IDs to
#'   resolve. If `NULL`, every reference column of `table` found in `data` is
#'   resolved.
#' @param how `"add"` keeps the reference column and adds the display values
#'   in a new column next to it. `"replace"` replaces the IDs with the display
#'   values.
#' @param suffix Suffix for the new column names when `how = "add"`.
#' @returns `data` with display values for the reference columns. `Ref`
#'   columns resolve to a vector (with `NA` for empty references) and
#'   `RefList` columns resolve to a list-column of vectors.
#' @family records
#' @examplesIf FALSE
#' doc <- grist_doc("am2iHJ9Amvo7Ve3EE5emtu")
#'
#' grist_records(doc, "Orders") |>
#'   grist_resolve_refs(doc, "Orders")
#'
#' grist_records(doc, "Orders") |>
#'   grist_resolve_refs(doc, "Orders", columns = "person", how = "replace")
#' @export
grist_resolve_refs <- function(
  data,
  doc,
  table,
  columns = NULL,
  how = c("add", "replace"),
  suffix = "_display"
) {
  check_data_frame(data)
  doc <- grist_doc(doc)
  check_string(table)
  check_character(columns, allow_null = TRUE)
  how <- arg_match(how)
  check_string(suffix)

  meta <- grist_columns(doc, table, hidden = TRUE)
  refs <- vctrs::vec_slice(meta, grepl("^Ref(List)?:", meta$type))

  if (is.null(columns)) {
    found <- refs$id %in% names(data) | refs$label %in% names(data)
    refs <- vctrs::vec_slice(refs, found)
  } else {
    unknown <- setdiff(columns, refs$id)
    if (length(unknown) > 0) {
      cli::cli_abort(
        c(
          "{.arg columns} must be reference columns of table {.val {table}}.",
          x = "Not reference columns: {.field {unknown}}."
        )
      )
    }
    refs <- vctrs::vec_slice(refs, match(columns, refs$id))
  }

  cache <- new_environment()
  skipped <- character()

  for (i in seq_len(nrow(refs))) {
    id <- refs$id[[i]]
    name <- if (id %in% names(data)) id else refs$label[[i]]
    if (!name %in% names(data)) {
      cli::cli_abort("{.arg data} has no column {.field {id}}.")
    }

    lookup <- ref_lookup(
      doc,
      sub("^Ref(List)?:", "", refs$type[[i]]),
      refs$visible_col[[i]],
      cache
    )
    if (is.null(lookup)) {
      skipped <- c(skipped, id)
      next
    }

    ids <- data[[name]]
    values <- if (is.list(ids)) {
      map(ids, function(x) lookup$values[match(x, lookup$ids)])
    } else {
      lookup$values[match(ids, lookup$ids)]
    }

    if (how == "replace") {
      data[name] <- list(values)
    } else {
      new <- paste0(name, suffix)
      data[new] <- list(values)
      nms <- names(data)
      data <- data[append(setdiff(nms, new), new, after = match(name, nms))]
    }
  }

  if (length(skipped) > 0) {
    cli::cli_warn(
      c(
        "Can't resolve {length(skipped)} reference column{?s}: {.field {skipped}}.",
        i = "No display column is set in Grist, so only row IDs are available."
      ),
      class = "gristmillr_warning_refs"
    )
  }
  data
}

# Fetch the row IDs and display values of a referenced table, once per
# table and display column. Returns `NULL` if there is no display column.
ref_lookup <- function(doc, ref_table, visible_col, cache) {
  if (is.na(visible_col) || visible_col == 0) {
    return(NULL)
  }
  key <- paste(ref_table, visible_col)
  if (!is.null(cache[[key]])) {
    return(cache[[key]])
  }

  ref_meta <- grist_columns(doc, ref_table, hidden = TRUE)
  display <- ref_meta$id[match(visible_col, ref_meta$col_ref)]
  if (is.na(display)) {
    return(NULL)
  }

  records <- grist_records(
    doc,
    ref_table,
    options = grist_read_options(hidden = TRUE, col_names = "id")
  )
  cache[[key]] <- list(ids = records$id, values = records[[display]])
  cache[[key]]
}
