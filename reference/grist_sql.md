# Run a SQL query against a document

`grist_sql()` runs a read-only `SELECT` query against the SQLite
database behind a Grist document. `grist_count()` counts the rows in a
table.

## Usage

``` r
grist_sql(doc, query, args = NULL, timeout = NULL, convert = c("basic", "raw"))

grist_count(doc, table)
```

## Arguments

- doc:

  A `grist_doc` object, document ID or document URL. See
  [`grist_doc()`](https://elipousson.github.io/gristmillr/reference/grist_doc.md).

- query:

  A single SQL `SELECT` statement without a trailing semicolon. Use `?`
  placeholders for values in `args`.

- args:

  A list or vector of values for the `?` placeholders in `query`.

- timeout:

  Query timeout in milliseconds. The server's default (1000) can only be
  reduced.

- convert:

  How to convert returned values: `"basic"` simplifies JSON values into
  vectors, and `"raw"` returns list-columns of the values exactly as the
  API does. SQL results carry no column types, so dates are returned as
  numbers.

- table:

  Table ID, as listed by
  [`grist_tables()`](https://elipousson.github.io/gristmillr/reference/grist_tables.md).

## Value

`grist_sql()` returns a data frame. `grist_count()` returns the number
of rows as an integer.

## See also

Other records:
[`grist_records()`](https://elipousson.github.io/gristmillr/reference/grist_records.md),
[`grist_resolve_refs()`](https://elipousson.github.io/gristmillr/reference/grist_resolve_refs.md)

## Examples

``` r
if (FALSE) {
doc <- grist_doc("am2iHJ9Amvo7Ve3EE5emtu")
grist_sql(doc, "SELECT * FROM Pets WHERE popularity >= ?", args = 50)
grist_count(doc, "Pets")
}
```
