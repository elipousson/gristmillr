# Import a file as a new document

`grist_doc_import()` uploads a file and creates a new document from it
in a workspace. It's the quickest way to start from data you already
have in a file. To load several related tables with their types and
references, see
[`grist_import()`](https://elipousson.github.io/gristmillr/reference/grist_import.md).

## Usage

``` r
grist_doc_import(path, workspace, name = NULL, server = NULL, options = NULL)
```

## Arguments

- path:

  Path to the file to upload.

- workspace:

  A workspace ID, as listed by
  [`grist_workspaces()`](https://elipousson.github.io/gristmillr/reference/grist_orgs.md).

- name:

  Name for the new document. If `NULL`, Grist names it after the file.

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

## Value

A
[`grist_doc()`](https://elipousson.github.io/gristmillr/reference/grist_doc.md)
for the new document.

## File formats

Grist reads `.grist`, `.csv`, `.xlsx` and `.json` files. A `.grist` file
becomes a copy of that document. A CSV or JSON file becomes one table
named after the file, and an Excel workbook one table per sheet. Column
types are guessed from the values, so whole numbers arrive as `Numeric`
and not `Int`, and nothing links the tables. Use
[`grist_columns_modify()`](https://elipousson.github.io/gristmillr/reference/grist_columns.md)
to change types afterwards. A JSON file must hold an array of objects.

## See also

Other docs:
[`grist_doc()`](https://elipousson.github.io/gristmillr/reference/grist_doc.md),
[`grist_doc_create()`](https://elipousson.github.io/gristmillr/reference/grist_doc_create.md),
[`grist_doc_download()`](https://elipousson.github.io/gristmillr/reference/grist_doc_download.md),
[`grist_request()`](https://elipousson.github.io/gristmillr/reference/grist_request.md)

## Examples

``` r
if (FALSE) {
doc <- grist_doc_import("pets.csv", workspace = 1234, name = "Pets")
grist_tables(doc)
grist_records(doc, "Pets")
}
```
