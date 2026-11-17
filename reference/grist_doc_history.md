# Inspect a document's history

Grist keeps a history of the changes made to a document, and takes
snapshots (backups) of it as it is edited.

- `grist_doc_history()` lists the document's states, one per action in
  its history.

- `grist_snapshots()` lists snapshots of the document.

- `grist_doc_compare()` compares two states of a document and summarises
  what changed.

These functions only read history. To read data as it was in a snapshot,
pass the snapshot's `doc_id` to
[`grist_doc()`](https://elipousson.github.io/gristmillr/reference/grist_doc.md)
with the same server, then use the usual functions, e.g.
`grist_doc(doc_id) |> grist_records("People")`.

## Usage

``` r
grist_doc_history(doc)

grist_snapshots(doc, raw = FALSE)

grist_doc_compare(doc, left = NULL, right = NULL, max_rows = NULL)
```

## Arguments

- doc:

  A `grist_doc` object, document ID or document URL. See
  [`grist_doc()`](https://elipousson.github.io/gristmillr/reference/grist_doc.md).

- raw:

  If `TRUE`, include snapshots that are not in the snapshot inventory.

- left, right:

  Hashes of the states to compare, as listed in the `hash` column of
  `grist_doc_history()`. `NULL` means the current state.

- max_rows:

  Maximum number of changed rows Grist includes in the details it
  computes. Row counts in `changes` cover only those rows, so a small
  `max_rows` can undercount.

## Value

`grist_doc_history()` returns a data frame with columns `n` (the action
number) and `hash`, newest first.

`grist_snapshots()` returns a data frame with columns `snapshot_id`,
`last_modified` (`POSIXct`, in UTC) and `doc_id`, newest first. The
newest snapshot may have the ID `"current"`.

`grist_doc_compare()` returns a list with:

- `summary`: how the two states relate. `"same"`; `"left"` or `"right"`
  when only that side has additional actions; `"both"` when each side
  has changes the other lacks; or `"unrelated"`.

- `left`, `right` and `parent`: the compared states and their most
  recent common ancestor, each a list with `n` and `hash` (`parent` is
  `NULL` if there is none).

- `changes`: a data frame with one row per side (`"left"` or `"right"`,
  relative to the ancestor) and table, with columns `rows_added`,
  `rows_updated`, `rows_removed`, `columns_changed` and `internal`
  (`TRUE` for Grist's own `_grist_*` metadata tables, which change when
  the schema or layout changes).

## See also

Other history:
[`grist_snapshot_restore()`](https://elipousson.github.io/gristmillr/reference/grist_snapshot_restore.md)

## Examples

``` r
if (FALSE) {
doc <- grist_doc("am2iHJ9Amvo7Ve3EE5emtu")

history <- grist_doc_history(doc)
history

# What changed since the first state?
comparison <- grist_doc_compare(doc, left = history$hash[nrow(history)])
comparison$summary
comparison$changes

grist_snapshots(doc)
}
```
