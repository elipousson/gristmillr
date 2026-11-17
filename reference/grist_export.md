# Export a document's tables to files and a data dictionary

`grist_export()` writes each table of a document to a Parquet, CSV or
JSON file in a directory, and describes the tables in a `data-dict.yaml`
file following the [data-dict](https://data-dict.tidyverse.org/)
specification. The result can be read by other tools, or loaded into
another Grist document with
[`grist_import()`](https://elipousson.github.io/gristmillr/reference/grist_import.md).

Tables are read with `convert = "auto"`, so dates, integers and logicals
are typed. The dictionary records what Parquet files can't keep: column
labels and descriptions, time zones, the choices of `Choice` columns,
and how tables refer to each other.

## Usage

``` r
grist_export(
  doc,
  to = ".",
  tables = NULL,
  format = c("parquet", "csv", "json"),
  examples = c("sample", "none"),
  overwrite = FALSE
)
```

## Arguments

- doc:

  A `grist_doc` object, document ID or document URL. See
  [`grist_doc()`](https://elipousson.github.io/gristmillr/reference/grist_doc.md).

- to:

  Directory to write to. It is created if it doesn't exist.

- tables:

  Table IDs to export. `NULL` exports every table.

- format:

  File format for the tables: `"parquet"`, `"csv"` or `"json"`.

- examples:

  data-dict describes the values of each column. `"sample"` records up
  to five real example values (or the range of dates) from the data.
  `"none"` leaves them empty with a `todo`, so no data appears in the
  dictionary. Columns with no values are also left empty with a `todo`.

- overwrite:

  Whether to replace existing files.

## Value

A data frame with one row per exported table: `table`, `rows`, `columns`
and `path`, invisibly.

## What the dictionary contains

- Every table gets an `id` column, Grist's row ID, as its primary key.

- A `Ref` column is a `number(id)` foreign key to the `id` of the table
  it points at, with a `many-to-one` relationship. `RefList` and
  `Attachments` columns are lists of IDs. data-dict can't declare
  foreign keys on lists, so no relationship is recorded for them.

- `Int` and `Numeric` columns are both `number`. Formula columns are
  exported as values, not formulas.

- Columns of type `Any` are listed by name only.

## File formats

`"parquet"` keeps every type, including time zones and list columns, and
is the default. `"json"` keeps numbers, logicals, missing values and
list columns, and writes dates and date-times as ISO 8601 text
(date-times in UTC). `"csv"` is plain text: list columns are written as
JSON arrays, and an empty `Text` cell can't be told apart from a missing
one.

data-dict can only point at Parquet files with `source`, so for CSV and
JSON the dictionary has no `source`, and files are found by name
(`<table>.csv` or `<table>.json`) next to the dictionary.

Requires the yaml12 package, and the nanoparquet package for Parquet.

## See also

Other export:
[`grist_import()`](https://elipousson.github.io/gristmillr/reference/grist_import.md)

## Examples

``` r
if (FALSE) {
doc <- grist_doc("am2iHJ9Amvo7Ve3EE5emtu")
grist_export(doc, "pets-export")

# Load it into another document
grist_import(grist_doc("<new doc id>"), "pets-export")
}
```
