# List, add and modify columns

`grist_columns()` lists the columns of a table. `grist_columns_add()`
and `grist_columns_modify()` change a table's schema.

## Usage

``` r
grist_columns(doc, table, hidden = FALSE)

grist_columns_add(doc, table, columns)

grist_columns_modify(doc, table, columns)
```

## Arguments

- doc:

  A `grist_doc` object, document ID or document URL. See
  [`grist_doc()`](https://elipousson.github.io/gristmillr/reference/grist_doc.md).

- table:

  Table ID, as listed by
  [`grist_tables()`](https://elipousson.github.io/gristmillr/reference/grist_tables.md).

- hidden:

  If `TRUE`, include hidden columns such as `manualSort`.

- columns:

  Column definitions. One of:

  - A character vector of column IDs (new columns get type `"Any"`).

  - A named character vector, where names are column IDs and values are
    column types, e.g. `c(name = "Text", age = "Int")`.

  - A data frame with an `id` column and any of the columns `type`,
    `label`, `description`, `formula`, `is_formula`, `widget_options`,
    `visible_col`, `untie_col_id_from_label` and (for modifying only)
    `col_id`, which renames the column. `NA` values are not sent. Use
    `description = ""` to clear a description.

## Value

`grist_columns()` returns a data frame with one row per column: `id`,
`label`, `description`, `type`, `is_formula`, `formula`,
`widget_options`, `visible_col` and `col_ref`. `grist_columns_add()`
returns the IDs of the new columns, and `grist_columns_modify()` returns
`doc`, both invisibly.

## Descriptions

Grist ignores a column `description` when a column is created. When
`columns` includes descriptions, `grist_columns_add()` (and
[`grist_table_create()`](https://elipousson.github.io/gristmillr/reference/grist_tables.md))
therefore make a second request to set them. `grist_columns()` returns
`NA` for columns that have no description.

## See also

Other schema:
[`grist_tables()`](https://elipousson.github.io/gristmillr/reference/grist_tables.md)

## Examples

``` r
if (FALSE) {
doc <- grist_doc("am2iHJ9Amvo7Ve3EE5emtu")
grist_columns(doc, "People")
grist_columns_add(doc, "People", c(city = "Text", age = "Int"))

grist_columns_add(
  doc,
  "People",
  data.frame(id = "email", type = "Text", description = "Work address")
)
grist_columns_modify(
  doc,
  "People",
  data.frame(id = "email", description = "Primary work email")
)
}
```
