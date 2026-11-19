# Options for Grist requests, reads and writes

These constructors group settings that rarely change so that functions
such as
[`grist_records()`](https://elipousson.github.io/gristmillr/reference/grist_records.md)
keep short signatures. Pass an options object to the `options` argument
of a function, or set a package-wide default with
`options(gristmillr.request_options = ...)`,
`options(gristmillr.read_options = ...)` or
`options(gristmillr.write_options = ...)`.

## Usage

``` r
grist_request_options(
  timeout = 30,
  max_tries = 3,
  user_agent = NULL,
  api_key = NULL
)

grist_read_options(
  hidden = FALSE,
  cell_format = c("normal", "typed"),
  tz = NULL,
  col_names = c("id", "label")
)

grist_write_options(
  chunk_size = 500,
  unknown_cols = c("error", "drop"),
  parse = TRUE
)
```

## Arguments

- timeout:

  Request timeout in seconds.

- max_tries:

  Maximum number of attempts for a request that fails with a transient
  error (HTTP 429 or 503).

- user_agent:

  User agent string sent with each request. Defaults to a string
  identifying gristmillr.

- api_key:

  A Grist API key: a string, or a function with no arguments that
  returns one (e.g. `\() keyring::key_get("grist")`). If `NULL`, the
  `GRIST_API_KEY` environment variable is used. See the Authentication
  section of
  [`grist_doc()`](https://elipousson.github.io/gristmillr/reference/grist_doc.md).

- hidden:

  If `TRUE`, include hidden columns such as `manualSort`.

- cell_format:

  Format of cell values returned by Grist. `"normal"` uses compact
  values whose meaning depends on the column type. `"typed"` returns
  self-describing tagged values and can only be used with
  `convert = "raw"`.

- tz:

  Time zone used for `DateTime` columns. If `NULL`, the time zone stored
  in the column type is used, falling back to `"UTC"`.

- col_names:

  Whether to name columns of the returned data frame using Grist column
  IDs (`"id"`) or column labels (`"label"`).

- chunk_size:

  Maximum number of rows sent in a single write request.

- unknown_cols:

  What to do when data has columns that do not exist in the Grist table:
  `"error"` or silently `"drop"` them. Only checked when
  `convert = "auto"`, because other modes do not fetch column metadata.

- parse:

  If `TRUE` (the default), Grist parses string values to match the type
  of each column, e.g. `"123"` becomes `123` in a numeric column. If
  `FALSE`, values are stored as sent (`noparse=true`). Values that don't
  fit a column's type are never rejected: Grist stores them as-is and
  flags them as invalid.

## Value

An S7 object holding validated settings.

## Examples

``` r
grist_request_options(timeout = 60)
#> <grist_request_options>
#>   timeout: 60
#>   max_tries: 3
#>   user_agent: gristmillr/0.0.0.9000
#>   api_key: `GRIST_API_KEY`
grist_read_options(col_names = "label")
#> <gristmillr::grist_read_options>
#>  @ hidden     : logi FALSE
#>  @ cell_format: chr "normal"
#>  @ tz         : NULL
#>  @ col_names  : chr "label"
grist_write_options(chunk_size = 250)
#> <gristmillr::grist_write_options>
#>  @ chunk_size  : num 250
#>  @ unknown_cols: chr "error"
#>  @ parse       : logi TRUE
```
