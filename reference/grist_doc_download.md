# Download a document or table to a file

`grist_doc_download()` saves a document, or one of its tables, to a
file. The file is written to a temporary location first and moved to
`path` only when the download succeeds, so a failed request never leaves
a partial file.

`grist_table_schema()` returns the schema of a table in the [Table
Schema](https://specs.frictionlessdata.io/table-schema/) format. The
column definitions are in `$schema$fields`.

## Usage

``` r
grist_doc_download(
  doc,
  path,
  format = c("grist", "xlsx", "csv", "tsv", "dsv"),
  table = NULL,
  col_names = c("id", "label"),
  no_history = FALSE,
  template = FALSE,
  overwrite = FALSE
)

grist_table_schema(doc, table, col_names = c("id", "label"))
```

## Arguments

- doc:

  A `grist_doc` object, document ID or document URL. See
  [`grist_doc()`](https://elipousson.github.io/gristmillr/reference/grist_doc.md).

- path:

  File to write.

- format:

  File format:

  - `"grist"`: the whole document as a SQLite file that Grist can open.

  - `"xlsx"`: the whole document, or one table if `table` is given, as
    an Excel workbook.

  - `"csv"`, `"tsv"` or `"dsv"`: one table as delimited text. `table` is
    required.

- table:

  Table ID. Required for `"csv"`, `"tsv"` and `"dsv"`, optional for
  `"xlsx"`, and not used for `"grist"`.

- col_names:

  Whether column headers use column IDs (`"id"`) or labels (`"label"`).
  Not used for `"grist"`.

- no_history:

  If `TRUE`, remove the document's history, which can significantly
  reduce file size. Only for `format = "grist"`.

- template:

  If `TRUE`, remove all data and history but keep the structure, so the
  file can be used as a template. Only for `format = "grist"`.

- overwrite:

  Whether to replace an existing file at `path`.

## Value

`grist_doc_download()` returns `path` invisibly. `grist_table_schema()`
returns a list.

## See also

Other docs:
[`grist_doc()`](https://elipousson.github.io/gristmillr/reference/grist_doc.md),
[`grist_doc_create()`](https://elipousson.github.io/gristmillr/reference/grist_doc_create.md),
[`grist_doc_import()`](https://elipousson.github.io/gristmillr/reference/grist_doc_import.md),
[`grist_request()`](https://elipousson.github.io/gristmillr/reference/grist_request.md)

## Examples

``` r
if (FALSE) {
doc <- grist_doc("am2iHJ9Amvo7Ve3EE5emtu")

grist_doc_download(doc, "pets.grist")
grist_doc_download(doc, "pets.csv", format = "csv", table = "Pets")
grist_doc_download(doc, "pets.xlsx", format = "xlsx", col_names = "label")

grist_table_schema(doc, "Pets")
}
```
