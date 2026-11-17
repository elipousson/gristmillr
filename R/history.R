#' Inspect a document's history
#'
#' @description
#' Grist keeps a history of the changes made to a document, and takes
#' snapshots (backups) of it as it is edited.
#'
#' * `grist_doc_history()` lists the document's states, one per action in its
#'   history.
#' * `grist_snapshots()` lists snapshots of the document.
#' * `grist_doc_compare()` compares two states of a document and summarises
#'   what changed.
#'
#' These functions only read history. To read data as it was in a snapshot,
#' pass the snapshot's `doc_id` to [grist_doc()] with the same server, then use
#' the usual functions, e.g. `grist_doc(doc_id) |> grist_records("People")`.
#'
#' @inheritParams grist_records
#' @param raw If `TRUE`, include snapshots that are not in the snapshot
#'   inventory.
#' @param left,right Hashes of the states to compare, as listed in the `hash`
#'   column of `grist_doc_history()`. `NULL` means the current state.
#' @param max_rows Maximum number of changed rows Grist includes in the
#'   details it computes. Row counts in `changes` cover only those rows, so a
#'   small `max_rows` can undercount.
#' @returns
#' `grist_doc_history()` returns a data frame with columns `n` (the action
#' number) and `hash`, newest first.
#'
#' `grist_snapshots()` returns a data frame with columns `snapshot_id`,
#' `last_modified` (`POSIXct`, in UTC) and `doc_id`, newest first. The
#' newest snapshot may have the ID `"current"`.
#'
#' `grist_doc_compare()` returns a list with:
#' * `summary`: how the two states relate. `"same"`; `"left"` or `"right"` when
#'   only that side has additional actions; `"both"` when each side has
#'   changes the other lacks; or `"unrelated"`.
#' * `left`, `right` and `parent`: the compared states and their most recent
#'   common ancestor, each a list with `n` and `hash` (`parent` is `NULL` if
#'   there is none).
#' * `changes`: a data frame with one row per side (`"left"` or `"right"`,
#'   relative to the ancestor) and table, with columns `rows_added`,
#'   `rows_updated`, `rows_removed`, `columns_changed` and `internal`
#'   (`TRUE` for Grist's own `_grist_*` metadata tables, which change when the
#'   schema or layout changes).
#' @family history
#' @examplesIf FALSE
#' doc <- grist_doc("am2iHJ9Amvo7Ve3EE5emtu")
#'
#' history <- grist_doc_history(doc)
#' history
#'
#' # What changed since the first state?
#' comparison <- grist_doc_compare(doc, left = history$hash[nrow(history)])
#' comparison$summary
#' comparison$changes
#'
#' grist_snapshots(doc)
#' @export
grist_doc_history <- function(doc) {
  doc <- grist_doc(doc)

  body <- grist_request(doc, "states") |>
    grist_perform()

  states <- body$states
  new_tbl(
    list(
      n = map_int(states, function(x) as.integer(x$n)),
      hash = map_chr(states, function(x) x$h)
    ),
    n = length(states)
  )
}

#' @rdname grist_doc_history
#' @export
grist_snapshots <- function(doc, raw = FALSE) {
  doc <- grist_doc(doc)
  check_bool(raw)

  body <- grist_request(doc, "snapshots") |>
    httr2::req_url_query(raw = if (raw) "true") |>
    grist_perform()

  snapshots <- body$snapshots
  new_tbl(
    list(
      snapshot_id = field_vec(
        snapshots,
        "snapshotId",
        NA_character_,
        top = TRUE
      ),
      last_modified = as.POSIXct(
        field_vec(snapshots, "lastModified", NA_character_, top = TRUE),
        format = "%Y-%m-%dT%H:%M:%OSZ",
        tz = "UTC"
      ),
      doc_id = field_vec(snapshots, "docId", NA_character_, top = TRUE)
    ),
    n = length(snapshots)
  )
}

#' @rdname grist_doc_history
#' @export
grist_doc_compare <- function(doc, left = NULL, right = NULL, max_rows = NULL) {
  doc <- grist_doc(doc)
  check_string(left, allow_null = TRUE)
  check_string(right, allow_null = TRUE)
  check_number_whole(max_rows, min = 0, allow_null = TRUE)

  body <- grist_request(doc, "compare") |>
    httr2::req_url_query(left = left, right = right, maxRows = max_rows) |>
    grist_perform()

  list(
    summary = body$summary,
    left = as_state(body$left),
    right = as_state(body$right),
    parent = as_state(body$parent),
    changes = changes_to_df(body$details)
  )
}

as_state <- function(x) {
  if (is.null(x)) NULL else list(n = as.integer(x$n), hash = x$h)
}

changes_to_df <- function(details) {
  rows <- list()
  for (side in c("left", "right")) {
    deltas <- details[[paste0(side, "Changes")]]$tableDeltas
    for (table in names(deltas)) {
      delta <- deltas[[table]]
      rows[[length(rows) + 1]] <- list(
        side = side,
        table = table,
        rows_added = length(delta$addRows),
        rows_updated = length(delta$updateRows),
        rows_removed = length(delta$removeRows),
        columns_changed = length(delta$columnDeltas),
        internal = startsWith(table, "_grist_")
      )
    }
  }

  new_tbl(
    list(
      side = map_chr(rows, function(x) x$side),
      table = map_chr(rows, function(x) x$table),
      rows_added = map_int(rows, function(x) x$rows_added),
      rows_updated = map_int(rows, function(x) x$rows_updated),
      rows_removed = map_int(rows, function(x) x$rows_removed),
      columns_changed = map_int(rows, function(x) x$columns_changed),
      internal = map_lgl(rows, function(x) x$internal)
    ),
    n = length(rows)
  )
}
