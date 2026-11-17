# Import tables from files and a data dictionary

`grist_import()` creates tables in a document from a
[data-dict](https://data-dict.tidyverse.org/) `data-dict.yaml` file and
the Parquet, CSV or JSON files that hold the data, then loads the rows.
It is the counterpart of
[`grist_export()`](https://elipousson.github.io/gristmillr/reference/grist_export.md),
and also suits data prepared elsewhere, such as lists copied out of
another low-code tool.

## Usage

``` r
grist_import(
  doc,
  from,
  tables = NULL,
  types = NULL,
  display = NULL,
  format = c("auto", "parquet", "csv", "json"),
  orphans = c("error", "empty"),
  if_exists = c("error", "append"),
  options = NULL
)
```

## Arguments

- doc:

  A `grist_doc` object, document ID or document URL. See
  [`grist_doc()`](https://elipousson.github.io/gristmillr/reference/grist_doc.md).

- from:

  Path to a `data-dict.yaml` file, or to a directory containing one.
  Parquet paths in the dictionary are relative to it.

- tables:

  Names of the dictionary's tables to import. `NULL` imports all of
  them.

- types:

  A named character vector that overrides Grist column types. Names are
  `"Table.column"`, values are Grist types such as `"Numeric"`,
  `"Ref:People"` or `"RefList:Items"`.

- display:

  A named character vector choosing the column a `Ref` or `RefList`
  column shows, e.g. `c("Orders.person" = "name")`.

- format:

  The format of the data files: `"auto"` uses whichever is found, or
  `"parquet"`, `"csv"` or `"json"` to choose.

- orphans:

  What to do with references to a key that doesn't exist in the target
  table: stop with an `"error"` before changing anything, or leave the
  reference `"empty"`.

- if_exists:

  What to do when a table already exists in the document: stop with an
  `"error"` before changing anything, or `"append"` rows to it. Existing
  tables keep their columns and types.

- options:

  A
  [`grist_write_options()`](https://elipousson.github.io/gristmillr/reference/grist-options.md)
  object.

## Value

A data frame with one row per imported table: `table`, `rows` and
`columns`, invisibly. If a request fails part way, tables and rows
already created remain in the document.

## Column types

Grist types come from the dictionary and the data:

|  |  |
|----|----|
| data-dict | Grist |
| `string` | `Text` |
| `number`, `number(id)` | `Int` if the data are integers, otherwise `Numeric` |
| `boolean` | `Bool` |
| `date` | `Date` |
| `datetime` | `DateTime`, in the column's `time_zone` (`UTC` if it is `naive` or missing) |
| `enum`, `list(enum)` | `Choice`, `ChoiceList`, with the `values` as choices |
| `list(string)` | `ChoiceList` |
| no type | `Any` |

Only columns described in the dictionary are imported. `label` and
`description` are kept. A column named `id` isn't created (Grist has its
own row IDs), but is used as a key if other tables refer to it. Other
types, including `list(number(id))`, need an entry in `types`.

## References between tables

A column with the `foreign_key` constraint that is part of a
`relationships` entry (`join: orders.person = people.id`) becomes a
`Ref` column. The tables are loaded first, and then each reference is
rewritten from the source key to the row ID Grist assigned, so tables
can be loaded in any order and may refer to themselves. The key column
stays in the table as ordinary data.

data-dict can't declare foreign keys on list columns, so use `types` for
`RefList` columns, e.g. `types = c("Orders.items" = "RefList:Items")`.
The target table must have a `primary_key` column, whose values the list
holds.

A `Ref` column shows its target's row ID unless you choose a column to
show with `display`.

## Data files

A table's data is read from the Parquet file named by its `source` in
the dictionary. Tables without a `source`, such as those from
[`grist_export()`](https://elipousson.github.io/gristmillr/reference/grist_export.md)
with `format = "csv"` or `"json"`, are read from `<table>.parquet`,
`<table>.csv` or `<table>.json` next to the dictionary, in that order,
or the one `format` names.

Text files have no types of their own, so values are converted to the
types in the dictionary (dates as `YYYY-MM-DD`, date-times as ISO 8601
in UTC, list columns as JSON arrays). A `number` column becomes `Int`
when all of its values are whole, so a `Numeric` column of whole numbers
needs `types = c("Table.column" = "Numeric")`.

Requires the yaml12 package, and the nanoparquet package for Parquet
files.

## See also

Other export:
[`grist_export()`](https://elipousson.github.io/gristmillr/reference/grist_export.md)

## Examples

``` r
if (FALSE) {
doc <- grist_doc("<new doc id>")
grist_import(doc, "pets-export")

grist_import(
  doc,
  "pets-export",
  types = c("Orders.buddies" = "RefList:People"),
  display = c("Orders.person" = "name")
)
}
```
