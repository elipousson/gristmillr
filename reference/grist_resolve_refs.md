# Resolve reference columns to display values

Grist returns `Ref` and `RefList` columns as row IDs of the referenced
table, while the Grist interface shows the values of a *display column*
(such as a person's name). `grist_resolve_refs()` looks up those display
values for data you have already read with
[`grist_records()`](https://elipousson.github.io/gristmillr/reference/grist_records.md).

Each referenced table is fetched once, even if several columns refer to
it. For other kinds of joins, see
[`vignette("joining-tables")`](https://elipousson.github.io/gristmillr/articles/joining-tables.md).

## Usage

``` r
grist_resolve_refs(
  data,
  doc,
  table,
  columns = NULL,
  how = c("add", "replace"),
  suffix = "_display"
)
```

## Arguments

- data:

  A data frame from
  [`grist_records()`](https://elipousson.github.io/gristmillr/reference/grist_records.md)
  for `table`. Use `convert = "auto"` or `"basic"` so that references
  are integer IDs.

- doc:

  A `grist_doc` object, document ID or document URL. See
  [`grist_doc()`](https://elipousson.github.io/gristmillr/reference/grist_doc.md).

- table:

  The table `data` was read from.

- columns:

  Character vector of `Ref` or `RefList` column IDs to resolve. If
  `NULL`, every reference column of `table` found in `data` is resolved.

- how:

  `"add"` keeps the reference column and adds the display values in a
  new column next to it. `"replace"` replaces the IDs with the display
  values.

- suffix:

  Suffix for the new column names when `how = "add"`.

## Value

`data` with display values for the reference columns. `Ref` columns
resolve to a vector (with `NA` for empty references) and `RefList`
columns resolve to a list-column of vectors.

## See also

Other records:
[`grist_records()`](https://elipousson.github.io/gristmillr/reference/grist_records.md),
[`grist_sql()`](https://elipousson.github.io/gristmillr/reference/grist_sql.md)

## Examples

``` r
if (FALSE) {
doc <- grist_doc("am2iHJ9Amvo7Ve3EE5emtu")

grist_records(doc, "Orders") |>
  grist_resolve_refs(doc, "Orders")

grist_records(doc, "Orders") |>
  grist_resolve_refs(doc, "Orders", columns = "person", how = "replace")
}
```
