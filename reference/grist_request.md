# Build a request for the Grist API

`grist_request()` returns an
[httr2](https://httr2.r-lib.org/reference/httr2-package.html) request
for a document, with authentication, a user agent, a timeout, retries
and Grist-aware error messages already set. Use it to call endpoints
that gristmillr does not wrap yet:

    grist_request(doc, "tables") |>
      httr2::req_perform() |>
      httr2::resp_body_json()

## Usage

``` r
grist_request(doc, ...)
```

## Arguments

- doc:

  A document ID, the URL of a document, or an existing `grist_doc`
  object. An existing object is returned as it is, with a warning if
  `server`, `options` or `api_key` are also supplied.

- ...:

  Path components appended to the document URL, such as `"tables"` or
  `c("tables", "People", "records")`.

## Value

An `httr2_request` object.

## See also

Other docs:
[`grist_doc()`](https://elipousson.github.io/gristmillr/reference/grist_doc.md),
[`grist_doc_create()`](https://elipousson.github.io/gristmillr/reference/grist_doc_create.md),
[`grist_doc_download()`](https://elipousson.github.io/gristmillr/reference/grist_doc_download.md),
[`grist_doc_import()`](https://elipousson.github.io/gristmillr/reference/grist_doc_import.md)

## Examples

``` r
doc <- grist_doc("am2iHJ9Amvo7Ve3EE5emtu", server = "https://docs.getgrist.com")
withr::with_envvar(
  c(GRIST_API_KEY = "example"),
  httr2::req_dry_run(grist_request(doc, "tables"))
)
#> Error in httr2::req_dry_run(grist_request(doc, "tables")): The package "httpuv" is required.
```
