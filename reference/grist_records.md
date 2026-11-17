# Read, add, update and delete records

`grist_records()` reads records from a table into a data frame. The
other functions write data frames back to Grist. Large writes are split
into several requests (see
[`grist_write_options()`](https://elipousson.github.io/gristmillr/reference/grist-options.md)).

## Usage

``` r
grist_records(
  doc,
  table,
  filter = NULL,
  sort = NULL,
  limit = NULL,
  convert = c("auto", "basic", "raw"),
  options = NULL
)

grist_records_add(
  doc,
  table,
  data,
  convert = c("auto", "basic", "raw"),
  options = NULL
)

grist_records_update(
  doc,
  table,
  data,
  convert = c("auto", "basic", "raw"),
  options = NULL
)

grist_records_upsert(
  doc,
  table,
  data,
  by,
  mode = c("upsert", "update", "insert"),
  onmany = c("first", "all", "none"),
  convert = c("auto", "basic", "raw"),
  options = NULL
)

grist_records_delete(doc, table, ids, options = NULL)
```

## Arguments

- doc:

  A `grist_doc` object, document ID or document URL. See
  [`grist_doc()`](https://elipousson.github.io/gristmillr/reference/grist_doc.md).

- table:

  Table ID, as listed by
  [`grist_tables()`](https://elipousson.github.io/gristmillr/reference/grist_tables.md).

- filter:

  A named list mapping column IDs to allowed values, e.g.
  `list(status = c("open", "new"))`. Rows must match every column.

- sort:

  Character vector of column IDs to sort by. Prefix a column with `-`
  for descending order, e.g. `c("status", "-priority")`. Use
  `"manualSort"` for the order set in the Grist interface.

- limit:

  Maximum number of rows to return. `NULL` returns all rows.

- convert:

  How to convert cell values: `"auto"`, `"basic"` or `"raw"`. See the
  section "Type conversion".

- options:

  A
  [`grist_read_options()`](https://elipousson.github.io/gristmillr/reference/grist-options.md)
  object (or
  [`grist_write_options()`](https://elipousson.github.io/gristmillr/reference/grist-options.md)
  for the writing functions). If `NULL`, the default set with
  `options(gristmillr.read_options = )` or
  `options(gristmillr.write_options = )` is used.

- data:

  A data frame of records. For `grist_records_add()`, each column must
  be a column of the Grist table. For `grist_records_update()`, `data`
  must also have an integer `id` column.

- by:

  Character vector of columns that identify a record, such as `"email"`.
  Each row of `data` is matched against the table on these columns.
  `data` must contain them, with no missing values and no duplicated
  combinations.

- mode:

  What to do with each row of `data`: `"upsert"` updates the record with
  matching `by` values and adds a record if there is none. `"update"`
  only updates matching records and skips rows that match nothing.
  `"insert"` only adds records and skips rows that already match. Grist
  does not report which rows were skipped.

- onmany:

  What to do when several records in the table match one row of `data`:
  update the `"first"` one, update `"all"` of them, or update `"none"`
  of them.

- ids:

  Row IDs to delete, either an integer vector or a data frame with an
  `id` column (such as the result of `grist_records()`).

## Value

`grist_records()` returns a data frame whose first column `id` is the
row ID. `grist_records_add()` returns the new row IDs.
`grist_records_update()`, `grist_records_upsert()` and
`grist_records_delete()` return `doc`. All but `grist_records()` return
invisibly.

## Type conversion

The `convert` argument controls how cell values are translated between
Grist and R:

- `"auto"` (the default) fetches the table's column types with
  [`grist_columns()`](https://elipousson.github.io/gristmillr/reference/grist_columns.md)
  and converts every column: `Int` to integer, `Numeric` to double,
  `Bool` to logical, `Date` to
  [Date](https://rdrr.io/r/base/Dates.html), `DateTime` to
  [POSIXct](https://rdrr.io/r/base/DateTimeClasses.html), `Text` and
  `Choice` to character, `Ref` to integer row IDs, and `ChoiceList`,
  `RefList` and `Attachments` to list-columns of vectors. Columns whose
  cells don't match their declared type are returned unconverted with a
  warning.

- `"basic"` does not fetch column types. Scalar values are simplified
  and `["L", ...]` lists become list-columns, but dates stay numeric
  (seconds since the epoch) and references stay integer IDs. When
  writing, R dates, date-times and factors are still converted.

- `"raw"` returns or sends cell values exactly as the API does, as
  list-columns.

## Empty values

Grist stores an empty `Bool` cell as `FALSE`, so an `NA` written to a
`Bool` column is read back as `FALSE`. Empty `Int`, `Numeric`, `Date`
and `DateTime` cells are read back as `NA`.

## See also

Other records:
[`grist_resolve_refs()`](https://elipousson.github.io/gristmillr/reference/grist_resolve_refs.md),
[`grist_sql()`](https://elipousson.github.io/gristmillr/reference/grist_sql.md)

## Examples

``` r
if (FALSE) {
doc <- grist_doc("am2iHJ9Amvo7Ve3EE5emtu")

grist_records(doc, "Pets")
grist_records(doc, "Pets", filter = list(pet = "cat"), sort = "-popularity")

new <- data.frame(pet = c("cat", "dog"), popularity = c(67L, 95L))
ids <- grist_records_add(doc, "Pets", new)

grist_records_update(doc, "Pets", data.frame(id = ids, popularity = 1L))

# Match on a column instead of the row ID: update cats, add rabbits
pets <- data.frame(pet = c("cat", "rabbit"), popularity = c(70L, 40L))
grist_records_upsert(doc, "Pets", pets, by = "pet")
grist_records_delete(doc, "Pets", ids)
}
```
