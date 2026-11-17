# List and create tables

List and create tables

## Usage

``` r
grist_tables(doc)

grist_table_create(doc, table, columns = character())
```

## Arguments

- doc:

  A `grist_doc` object, document ID or document URL. See
  [`grist_doc()`](https://elipousson.github.io/gristmillr/reference/grist_doc.md).

- table:

  Table ID, as listed by `grist_tables()`.

- columns:

  Columns for the new table, in any form accepted by
  [`grist_columns_add()`](https://elipousson.github.io/gristmillr/reference/grist_columns.md),
  including column descriptions.

## Value

`grist_tables()` returns a data frame with one row per table and columns
`id`, `table_ref` and `on_demand`. `grist_table_create()` returns the ID
of the new table invisibly.

## See also

Other schema:
[`grist_columns()`](https://elipousson.github.io/gristmillr/reference/grist_columns.md)

## Examples

``` r
if (FALSE) {
doc <- grist_doc("am2iHJ9Amvo7Ve3EE5emtu")
grist_tables(doc)
grist_table_create(doc, "Pets", c(name = "Text", popularity = "Int"))
}
```
