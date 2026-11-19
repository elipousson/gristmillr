# gristmillr

gristmillr is an [httr2](https://httr2.r-lib.org/)-based client for the
[Grist](https://www.getgrist.com/) REST API. Functions take a
lightweight document handle first and return data frames, so they
compose with pipes.

This is a development version; see `NEWS.md`.

## Setup

Set your API key (and, for a team or self-hosted site, the server) in
`.Renviron`:

``` R
GRIST_API_KEY=<your key>
GRIST_SERVER=https://myteam.getgrist.com
```

Or pass the key to `grist_doc(api_key = )`, as a string or as a function
such as `\() keyring::key_get("grist")`. Keys given as strings are never
saved with the object.

## Usage

``` r

library(gristmillr)

doc <- grist_doc("<doc id or URL>")
```

``` r

grist_tables(doc)
#> # A data frame: 2 × 3
#>   id     table_ref on_demand
#>   <chr>      <int> <lgl>    
#> 1 Table1         1 FALSE    
#> 2 People         2 FALSE

doc |>
  grist_records("People", filter = list(status = "active"), sort = "-age")
#> # A data frame: 2 × 4
#>      id name    age status
#>   <int> <chr> <int> <chr> 
#> 1     1 Ann      31 active
#> 2     3 Cy       28 active

data.frame(name = "Dee", age = 52L, status = "active") |>
  grist_records_add(doc, "People")

grist_sql(doc, "SELECT status, COUNT(*) AS n FROM People GROUP BY status")
#> # A data frame: 2 × 2
#>   status      n
#>   <chr>   <int>
#> 1 active      3
#> 2 pending     1
```

To move data in or out,
[`grist_export()`](https://elipousson.github.io/gristmillr/reference/grist_export.md)
writes tables to Parquet, CSV or JSON files with a
[data-dict](https://data-dict.tidyverse.org/) description of their
columns and references, and
[`grist_import()`](https://elipousson.github.io/gristmillr/reference/grist_import.md)
loads them into another document. See
[`vignette("migrating-data")`](https://elipousson.github.io/gristmillr/articles/migrating-data.md)
for moving data in from other tools.

See
[`vignette("gristmillr")`](https://elipousson.github.io/gristmillr/articles/gristmillr.md)
to get started and
[`vignette("joining-tables")`](https://elipousson.github.io/gristmillr/articles/joining-tables.md)
for working with reference columns.

## Coming from gristapi

The [gristapi](https://github.com/spyrales/gristapi) package is built
around an R6 object. gristmillr has no stateful objects: the document
handle holds only an ID, a server and request settings, and every
function takes and returns data frames.

| gristapi | gristmillr |
|----|----|
| `listtables()` | [`grist_tables()`](https://elipousson.github.io/gristmillr/reference/grist_tables.md) |
| `listcolumns()` | [`grist_columns()`](https://elipousson.github.io/gristmillr/reference/grist_columns.md) |
| `fetch_table()` | [`grist_records()`](https://elipousson.github.io/gristmillr/reference/grist_records.md) |
| `countrows()` | [`grist_count()`](https://elipousson.github.io/gristmillr/reference/grist_sql.md) |
| `add_records()` | [`grist_records_add()`](https://elipousson.github.io/gristmillr/reference/grist_records.md) |
| `update_records()` | [`grist_records_update()`](https://elipousson.github.io/gristmillr/reference/grist_records.md) |
| `delete_records()` | [`grist_records_delete()`](https://elipousson.github.io/gristmillr/reference/grist_records.md) |
| `sync_table()` | [`grist_records_upsert()`](https://elipousson.github.io/gristmillr/reference/grist_records.md) (`key_cols` is `by`) |

Other differences:

- Cell types are converted from column metadata by default, with
  `convert = "basic"` and `"raw"` as alternatives.
- Settings that rarely change live in
  [`grist_request_options()`](https://elipousson.github.io/gristmillr/reference/grist-options.md),
  [`grist_read_options()`](https://elipousson.github.io/gristmillr/reference/grist-options.md)
  and
  [`grist_write_options()`](https://elipousson.github.io/gristmillr/reference/grist-options.md).
- gristmillr also covers documents and workspaces, schema changes, SQL,
  downloads, attachments, webhooks and document history.
- It does not depend on dplyr, tidyr or sf.
