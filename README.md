
<!-- README.md is generated from README.Rmd. Edit README.Rmd, then knit it
against a Grist server, e.g.
GRIST_API_KEY=... GRIST_SERVER=... Rscript -e 'rmarkdown::render("README.Rmd")'
The output is pre-computed because it needs a live Grist server. -->

# gristmillr

gristmillr is an [httr2](https://httr2.r-lib.org/)-based client for the
[Grist](https://www.getgrist.com/) REST API. Functions take a
lightweight document handle first and return data frames, so they
compose with pipes.

This is a development version; see `NEWS.md`.

## Setup

Set your API key (and, for a team or self-hosted site, the server) in
`.Renviron`:

    GRIST_API_KEY=<your key>
    GRIST_SERVER=https://myteam.getgrist.com

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
#>       id table_ref on_demand
#> 1 Table1         1     FALSE
#> 2 People         2     FALSE

doc |>
  grist_records("People", filter = list(status = "active"), sort = "-age")
#>   id name age status
#> 1  1  Ann  31 active
#> 2  3   Cy  28 active

doc |>
  grist_records_add("People", data.frame(name = "Dee", age = 52L, status = "active"))

grist_sql(doc, "SELECT status, COUNT(*) AS n FROM People GROUP BY status")
#>    status n
#> 1  active 3
#> 2 pending 1
```

To move data in or out, `grist_export()` writes tables to Parquet, CSV
or JSON files with a [data-dict](https://data-dict.tidyverse.org/)
description of their columns and references, and `grist_import()` loads
them into another document. See `vignette("migrating-data")` for moving
data in from other tools.

See `vignette("gristmillr")` to get started and
`vignette("joining-tables")` for working with reference columns.

## Coming from gristapi

The [gristapi](https://github.com/spyrales/gristapi) package is built
around an R6 object. gristmillr has no stateful objects: the document
handle holds only an ID, a server and request settings, and every
function takes and returns data frames.

| gristapi           | gristmillr                                    |
|--------------------|-----------------------------------------------|
| `listtables()`     | `grist_tables()`                              |
| `listcolumns()`    | `grist_columns()`                             |
| `fetch_table()`    | `grist_records()`                             |
| `countrows()`      | `grist_count()`                               |
| `add_records()`    | `grist_records_add()`                         |
| `update_records()` | `grist_records_update()`                      |
| `delete_records()` | `grist_records_delete()`                      |
| `sync_table()`     | `grist_records_upsert()` (`key_cols` is `by`) |

Other differences:

- Cell types are converted from column metadata by default, with
  `convert = "basic"` and `"raw"` as alternatives.
- Settings that rarely change live in `grist_request_options()`,
  `grist_read_options()` and `grist_write_options()`.
- gristmillr also covers documents and workspaces, schema changes, SQL,
  downloads, attachments, webhooks and document history.
- It does not depend on dplyr, tidyr or sf.
