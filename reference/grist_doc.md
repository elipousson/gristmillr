# Create a handle for a Grist document

`grist_doc()` creates a lightweight handle that identifies a Grist
document and the server it lives on. The handle is passed as the first
argument to most gristmillr functions so it works in pipelines:

    grist_doc("<doc id>") |>
      grist_records("People")

## Usage

``` r
grist_doc(doc, server = NULL, options = NULL, api_key = NULL)
```

## Arguments

- doc:

  A document ID, the URL of a document, or an existing `grist_doc`
  object.

- server:

  URL of the Grist server, such as `"https://docs.getgrist.com"` or
  `"https://myteam.getgrist.com"`. For a self-hosted server, include the
  team path if needed, e.g. `"http://localhost:8484/o/docs"`. Defaults
  to the server in `doc` if `doc` is a URL, then the `GRIST_SERVER`
  environment variable, then `"https://docs.getgrist.com"`.

- options:

  A
  [`grist_request_options()`](https://elipousson.github.io/gristmillr/reference/grist-options.md)
  object. If `NULL`, the default from
  `getOption("gristmillr.request_options")` or
  [`grist_request_options()`](https://elipousson.github.io/gristmillr/reference/grist-options.md)
  is used.

- api_key:

  A Grist API key, as a string or a function that returns one. Overrides
  any key in `options`. See the Authentication section.

## Value

A `grist_doc` object with properties `doc_id`, `server` and `options`.

## Authentication

Requests are authenticated with a Grist API key, found in this order:

1.  The `api_key` argument of `grist_doc()` or
    [`grist_request_options()`](https://elipousson.github.io/gristmillr/reference/grist-options.md),
    either a string or a function with no arguments that returns one.

2.  The `GRIST_API_KEY` environment variable.

A key supplied as a string is held in memory for the current session
only, not stored in the object, so saving a handle with
[`saveRDS()`](https://rdrr.io/r/base/readRDS.html) (or as a
[targets](https://docs.ropensci.org/targets/) target) never writes the
key to disk. A handle read back in a new session errors until you supply
the key again. To make a handle that works across sessions, pass a
function such as `api_key = \() keyring::key_get("grist")` or
`\() Sys.getenv("MY_KEY")`. To keep a key encrypted on disk yourself,
see
[`httr2::secret_write_rds()`](https://httr2.r-lib.org/reference/secrets.html).

Avoid typing keys into scripts you share or commit.

## See also

Other docs:
[`grist_doc_create()`](https://elipousson.github.io/gristmillr/reference/grist_doc_create.md),
[`grist_doc_download()`](https://elipousson.github.io/gristmillr/reference/grist_doc_download.md),
[`grist_doc_import()`](https://elipousson.github.io/gristmillr/reference/grist_doc_import.md),
[`grist_request()`](https://elipousson.github.io/gristmillr/reference/grist_request.md)

## Examples

``` r
grist_doc("am2iHJ9Amvo7Ve3EE5emtu")
#> <grist_doc> "am2iHJ9Amvo7Ve3EE5emtu"
#> Server: <https://docs.getgrist.com>
grist_doc("https://docs.getgrist.com/doc/am2iHJ9Amvo7Ve3EE5emtu")
#> <grist_doc> "am2iHJ9Amvo7Ve3EE5emtu"
#> Server: <https://docs.getgrist.com>
```
