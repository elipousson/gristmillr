# Create, describe, update, move and delete documents

- `grist_doc_create()` creates an empty document in a workspace and
  returns a
  [`grist_doc()`](https://elipousson.github.io/gristmillr/reference/grist_doc.md)
  handle.

- `grist_doc_info()` describes a document.

- `grist_doc_update()` renames a document or pins and unpins it.

- `grist_doc_move()` moves a document to another workspace.

- `grist_doc_delete()` moves a document to the trash, or deletes it
  permanently.

- `grist_doc_restore()` restores a document from the trash.

## Usage

``` r
grist_doc_create(
  workspace,
  name,
  pinned = FALSE,
  server = NULL,
  options = NULL
)

grist_doc_info(doc)

grist_doc_update(doc, name = NULL, pinned = NULL)

grist_doc_move(doc, workspace)

grist_doc_delete(doc, mode = c("trash", "permanent"), confirm = NULL)

grist_doc_restore(doc)
```

## Arguments

- workspace:

  A workspace ID, as listed by
  [`grist_workspaces()`](https://elipousson.github.io/gristmillr/reference/grist_orgs.md).

- name:

  Document name.

- pinned:

  Whether the document is pinned. For `grist_doc_update()`, `NULL`
  leaves the setting unchanged.

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

- doc:

  A document ID, the URL of a document, or an existing `grist_doc`
  object.

- mode:

  `"trash"` moves the document to the trash, where it can be restored
  with `grist_doc_restore()`. `"permanent"` deletes it for good.

- confirm:

  `NULL` (the default) prompts in an interactive session and errors
  otherwise. `TRUE` skips the prompt. `FALSE` always errors.

## Value

`grist_doc_create()` returns a
[`grist_doc()`](https://elipousson.github.io/gristmillr/reference/grist_doc.md).
`grist_doc_info()` returns a one-row data frame with `id`, `name`,
`access`, `is_pinned`, `url_id`, `created_at` and `updated_at`
(`POSIXct`, in UTC), `workspace_id`, `workspace_name` and `org_domain`.
The others return a
[`grist_doc()`](https://elipousson.github.io/gristmillr/reference/grist_doc.md)
invisibly.

## Deleting

`grist_doc_delete()` asks for confirmation. In an interactive session it
prompts: a yes/no question for `mode = "trash"`, and typing the document
name for `mode = "permanent"`. In a script, it refuses to delete unless
`confirm = TRUE`.

## See also

Other docs:
[`grist_doc()`](https://elipousson.github.io/gristmillr/reference/grist_doc.md),
[`grist_doc_download()`](https://elipousson.github.io/gristmillr/reference/grist_doc_download.md),
[`grist_doc_import()`](https://elipousson.github.io/gristmillr/reference/grist_doc_import.md),
[`grist_request()`](https://elipousson.github.io/gristmillr/reference/grist_request.md)

## Examples

``` r
if (FALSE) {
doc <- grist_doc_create(workspace = 1234, name = "Pets")
grist_doc_info(doc)
doc |> grist_doc_update(name = "Pets 2026", pinned = TRUE)
doc |> grist_doc_delete()
doc |> grist_doc_restore()
}
```
