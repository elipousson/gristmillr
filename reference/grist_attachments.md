# List, upload and download attachments

Attachments are files stored inside a Grist document and referenced from
cells of `Attachments` columns.

- `grist_attachments()` lists the metadata of all attachments in a
  document.

- `grist_attachment_info()` returns the metadata of one attachment.

- `grist_attachments_upload()` uploads files and returns their
  attachment IDs.

- `grist_attachment_download()` saves an attachment to a file.

## Usage

``` r
grist_attachments(doc, filter = NULL, sort = NULL, limit = NULL)

grist_attachment_info(doc, id)

grist_attachments_upload(doc, path)

grist_attachment_download(doc, id, path, overwrite = FALSE)
```

## Arguments

- doc:

  A `grist_doc` object, document ID or document URL. See
  [`grist_doc()`](https://elipousson.github.io/gristmillr/reference/grist_doc.md).

- filter:

  A named list mapping column IDs to allowed values, e.g.
  `list(status = c("open", "new"))`. Rows must match every column.

- sort:

  Character vector of column IDs to sort by. Prefix a column with `-`
  for descending order, e.g. `c("status", "-priority")`. Use
  `"manualSort"` for the order set in the Grist interface.

- limit:

  Maximum number of rows to return. `NULL` returns all rows.

- id:

  An attachment ID.

- path:

  For `grist_attachments_upload()`, a character vector of files to
  upload, each uploaded in its own request. For
  `grist_attachment_download()`, the file to write, or an existing
  directory, in which case the attachment's original file name (reduced
  to its base name) is used.

- overwrite:

  Whether to replace an existing file.

## Value

`grist_attachments()` returns a data frame with columns `id`,
`file_name`, `file_size` (bytes) and `time_uploaded` (a `POSIXct` in
UTC). `grist_attachment_info()` returns the same columns for one
attachment. `grist_attachments_upload()` returns the new attachment IDs
and `grist_attachment_download()` returns the path written, both
invisibly.

## Attaching files to records

Uploading a file does not attach it to a record. Write the returned IDs
into an `Attachments` column as a list-column:

    ids <- grist_attachments_upload(doc, c("a.pdf", "b.pdf"))

    grist_records_update(
      doc, "Reports",
      data.frame(id = 1L, files = I(list(ids)))
    )

With `convert = "auto"`, `Attachments` columns are read back as
list-columns of attachment IDs, which you can pass to
`grist_attachment_download()`.

Attachments that are no longer referenced by any cell may still appear
in `grist_attachments()` for a while.

## Examples

``` r
if (FALSE) {
doc <- grist_doc("am2iHJ9Amvo7Ve3EE5emtu")

ids <- grist_attachments_upload(doc, "report.pdf")
grist_attachments(doc)
grist_attachment_info(doc, ids[[1]])
grist_attachment_download(doc, ids[[1]], tempdir())
}
```
