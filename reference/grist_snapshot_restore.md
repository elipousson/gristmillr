# Restore or remove document history

These functions change a document's history and can't be undone, so they
ask for confirmation like
[`grist_doc_delete()`](https://elipousson.github.io/gristmillr/reference/grist_doc_create.md).

- `grist_snapshot_restore()` replaces the document's current contents
  with those of a snapshot.

- `grist_snapshots_remove()` deletes snapshots.

- `grist_doc_history_truncate()` discards all but the most recent
  actions in the document's action history.

In an interactive session they prompt with a yes/no question. In a
script they refuse to run unless `confirm = TRUE`.

## Usage

``` r
grist_snapshot_restore(doc, snapshot_id, confirm = NULL)

grist_snapshots_remove(doc, snapshot_ids, confirm = NULL)

grist_doc_history_truncate(doc, keep, confirm = NULL)
```

## Arguments

- doc:

  A `grist_doc` object, document ID or document URL. See
  [`grist_doc()`](https://elipousson.github.io/gristmillr/reference/grist_doc.md).

- snapshot_id, snapshot_ids:

  Snapshot ID(s), as listed in the `snapshot_id` column of
  [`grist_snapshots()`](https://elipousson.github.io/gristmillr/reference/grist_doc_history.md).

- confirm:

  `NULL` (the default) prompts in an interactive session and errors
  otherwise. `TRUE` skips the prompt. `FALSE` always errors.

- keep:

  Number of the most recent actions to keep.

## Value

The
[`grist_doc()`](https://elipousson.github.io/gristmillr/reference/grist_doc.md)
handle, invisibly.

## See also

Other history:
[`grist_doc_history()`](https://elipousson.github.io/gristmillr/reference/grist_doc_history.md)

## Examples

``` r
if (FALSE) {
doc <- grist_doc("am2iHJ9Amvo7Ve3EE5emtu")
snapshots <- grist_snapshots(doc)

grist_snapshot_restore(doc, snapshots$snapshot_id[[2]])
grist_snapshots_remove(doc, snapshots$snapshot_id[-1])
grist_doc_history_truncate(doc, keep = 100)
}
```
