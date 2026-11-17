# List orgs, workspaces and documents; manage workspaces

Orgs are the team sites (or personal areas) you can access. Each org has
workspaces, and each workspace holds documents.

- `grist_orgs()` lists the orgs you can access.

- `grist_workspaces()` lists the workspaces in an org.

- `grist_docs()` lists the documents in an org, with their workspace.

- `grist_workspace_create()` creates a workspace.

- `grist_workspace_delete()` and `grist_workspace_restore()` move a
  workspace to the trash or delete it permanently, and restore it. As
  with
  [`grist_doc_delete()`](https://elipousson.github.io/gristmillr/reference/grist_doc_create.md),
  deleting asks for confirmation.

## Usage

``` r
grist_orgs(server = NULL, options = NULL)

grist_workspaces(org = "current", server = NULL, options = NULL)

grist_docs(org = "current", server = NULL, options = NULL)

grist_workspace_create(name, org = "current", server = NULL, options = NULL)

grist_workspace_delete(
  workspace,
  mode = c("trash", "permanent"),
  confirm = NULL,
  server = NULL,
  options = NULL
)

grist_workspace_restore(workspace, server = NULL, options = NULL)
```

## Arguments

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

- org:

  An org ID or domain. `"current"` is the org that matches the server
  URL.

- name:

  Document name.

- workspace:

  A workspace ID.

- mode:

  `"trash"` moves the document to the trash, where it can be restored
  with
  [`grist_doc_restore()`](https://elipousson.github.io/gristmillr/reference/grist_doc_create.md).
  `"permanent"` deletes it for good.

- confirm:

  `NULL` (the default) prompts in an interactive session and errors
  otherwise. `TRUE` skips the prompt. `FALSE` always errors.

## Value

A data frame for the listing functions. `grist_workspace_create()`
returns the new workspace ID invisibly. `grist_workspace_delete()` and
`grist_workspace_restore()` return the workspace ID invisibly.

## Examples

``` r
if (FALSE) {
grist_orgs()
grist_workspaces()
grist_docs()
id <- grist_workspace_create(name = "Pets")
grist_workspace_delete(id, confirm = TRUE)
}
```
