# Changelog

## gristmillr 0.0.0.9000

- [`grist_workspaces()`](https://elipousson.github.io/gristmillr/reference/grist_orgs.md),
  [`grist_docs()`](https://elipousson.github.io/gristmillr/reference/grist_orgs.md)
  and
  [`grist_workspace_create()`](https://elipousson.github.io/gristmillr/reference/grist_orgs.md)
  use your only org when the server has no “current” org, as with Grist
  Desktop.

- Functions that delete or overwrite things
  ([`grist_doc_delete()`](https://elipousson.github.io/gristmillr/reference/grist_doc_create.md),
  [`grist_workspace_delete()`](https://elipousson.github.io/gristmillr/reference/grist_orgs.md),
  [`grist_webhook_delete()`](https://elipousson.github.io/gristmillr/reference/grist_webhooks.md),
  [`grist_snapshot_restore()`](https://elipousson.github.io/gristmillr/reference/grist_snapshot_restore.md),
  [`grist_snapshots_remove()`](https://elipousson.github.io/gristmillr/reference/grist_snapshot_restore.md)
  and
  [`grist_doc_history_truncate()`](https://elipousson.github.io/gristmillr/reference/grist_snapshot_restore.md))
  take `ask`. `ask = FALSE` skips the prompt; the default prompts when
  interactive and errors in a script.

- Initial development version with document handles
  ([`grist_doc()`](https://elipousson.github.io/gristmillr/reference/grist_doc.md)),
  options objects and
  [`grist_request()`](https://elipousson.github.io/gristmillr/reference/grist_request.md)
  for building authenticated requests.

- [`grist_tables()`](https://elipousson.github.io/gristmillr/reference/grist_tables.md),
  [`grist_table_create()`](https://elipousson.github.io/gristmillr/reference/grist_tables.md),
  [`grist_columns()`](https://elipousson.github.io/gristmillr/reference/grist_columns.md),
  [`grist_columns_add()`](https://elipousson.github.io/gristmillr/reference/grist_columns.md)
  and
  [`grist_columns_modify()`](https://elipousson.github.io/gristmillr/reference/grist_columns.md)
  read and change a document’s schema.

- [`grist_records()`](https://elipousson.github.io/gristmillr/reference/grist_records.md),
  [`grist_records_add()`](https://elipousson.github.io/gristmillr/reference/grist_records.md),
  [`grist_records_update()`](https://elipousson.github.io/gristmillr/reference/grist_records.md),
  [`grist_records_upsert()`](https://elipousson.github.io/gristmillr/reference/grist_records.md)
  and
  [`grist_records_delete()`](https://elipousson.github.io/gristmillr/reference/grist_records.md)
  read and write records with a `convert` enum (`"auto"`, `"basic"` or
  `"raw"`).
  [`grist_sql()`](https://elipousson.github.io/gristmillr/reference/grist_sql.md)
  and
  [`grist_count()`](https://elipousson.github.io/gristmillr/reference/grist_sql.md)
  run SQL queries.

- [`grist_doc_create()`](https://elipousson.github.io/gristmillr/reference/grist_doc_create.md),
  [`grist_doc_info()`](https://elipousson.github.io/gristmillr/reference/grist_doc_create.md),
  [`grist_doc_update()`](https://elipousson.github.io/gristmillr/reference/grist_doc_create.md),
  [`grist_doc_move()`](https://elipousson.github.io/gristmillr/reference/grist_doc_create.md),
  [`grist_doc_delete()`](https://elipousson.github.io/gristmillr/reference/grist_doc_create.md)
  and
  [`grist_doc_restore()`](https://elipousson.github.io/gristmillr/reference/grist_doc_create.md)
  manage documents, and
  [`grist_orgs()`](https://elipousson.github.io/gristmillr/reference/grist_orgs.md),
  [`grist_workspaces()`](https://elipousson.github.io/gristmillr/reference/grist_orgs.md),
  [`grist_docs()`](https://elipousson.github.io/gristmillr/reference/grist_orgs.md)
  and `grist_workspace_*()` list and manage orgs and workspaces.
  Deleting takes `mode = "trash"` or `"permanent"` and asks before
  deleting (`ask = NULL`, the default; `ask = FALSE` skips the prompt).

- [`grist_doc_download()`](https://elipousson.github.io/gristmillr/reference/grist_doc_download.md)
  saves a document or table as `.grist`, Excel, CSV, TSV or DSV, and
  [`grist_table_schema()`](https://elipousson.github.io/gristmillr/reference/grist_doc_download.md)
  returns a table’s Table Schema.

- [`grist_resolve_refs()`](https://elipousson.github.io/gristmillr/reference/grist_resolve_refs.md)
  looks up display values for `Ref` and `RefList` columns, and
  [`vignette("joining-tables")`](https://elipousson.github.io/gristmillr/articles/joining-tables.md)
  shows how to join tables.

- [`grist_attachments()`](https://elipousson.github.io/gristmillr/reference/grist_attachments.md),
  [`grist_attachment_info()`](https://elipousson.github.io/gristmillr/reference/grist_attachments.md),
  [`grist_attachments_upload()`](https://elipousson.github.io/gristmillr/reference/grist_attachments.md)
  and
  [`grist_attachment_download()`](https://elipousson.github.io/gristmillr/reference/grist_attachments.md)
  list, upload and download attachments.

- [`grist_webhooks()`](https://elipousson.github.io/gristmillr/reference/grist_webhooks.md),
  [`grist_webhook_create()`](https://elipousson.github.io/gristmillr/reference/grist_webhooks.md),
  [`grist_webhook_update()`](https://elipousson.github.io/gristmillr/reference/grist_webhooks.md),
  [`grist_webhook_delete()`](https://elipousson.github.io/gristmillr/reference/grist_webhooks.md)
  and
  [`grist_webhook_queue_clear()`](https://elipousson.github.io/gristmillr/reference/grist_webhooks.md)
  manage webhooks.

- [`grist_columns()`](https://elipousson.github.io/gristmillr/reference/grist_columns.md)
  returns column descriptions, and
  [`grist_columns_add()`](https://elipousson.github.io/gristmillr/reference/grist_columns.md),
  [`grist_columns_modify()`](https://elipousson.github.io/gristmillr/reference/grist_columns.md)
  and
  [`grist_table_create()`](https://elipousson.github.io/gristmillr/reference/grist_tables.md)
  can set them.

- [`grist_doc_history()`](https://elipousson.github.io/gristmillr/reference/grist_doc_history.md),
  [`grist_snapshots()`](https://elipousson.github.io/gristmillr/reference/grist_doc_history.md)
  and
  [`grist_doc_compare()`](https://elipousson.github.io/gristmillr/reference/grist_doc_history.md)
  read a document’s action history, snapshots and changes between
  states.

- [`grist_snapshot_restore()`](https://elipousson.github.io/gristmillr/reference/grist_snapshot_restore.md),
  [`grist_snapshots_remove()`](https://elipousson.github.io/gristmillr/reference/grist_snapshot_restore.md)
  and
  [`grist_doc_history_truncate()`](https://elipousson.github.io/gristmillr/reference/grist_snapshot_restore.md)
  restore a snapshot and remove snapshots or old history, after
  confirmation.

- [`grist_doc()`](https://elipousson.github.io/gristmillr/reference/grist_doc.md)
  and
  [`grist_request_options()`](https://elipousson.github.io/gristmillr/reference/grist-options.md)
  gain an `api_key` argument, a string or a function returning one.
  String keys are held in session memory and never serialised with the
  object.

- [`grist_doc_info()`](https://elipousson.github.io/gristmillr/reference/grist_doc_create.md)
  returns `created_at` and `updated_at`.
  [`grist_orgs()`](https://elipousson.github.io/gristmillr/reference/grist_orgs.md)
  now returns its timestamps as `POSIXct` in UTC rather than strings.

- [`vignette("gristmillr")`](https://elipousson.github.io/gristmillr/articles/gristmillr.md)
  is a getting-started guide.

- [`grist_records_upsert()`](https://elipousson.github.io/gristmillr/reference/grist_records.md)
  updates and adds records by matching on key columns (`by`), with
  `mode` and `onmany` enums. It never deletes records.

- [`grist_records()`](https://elipousson.github.io/gristmillr/reference/grist_records.md)
  no longer fails on an empty table with untyped (`Any`) columns.

- [`grist_export()`](https://elipousson.github.io/gristmillr/reference/grist_export.md)
  writes a document’s tables to Parquet, CSV or JSON files and a
  [data-dict](https://data-dict.tidyverse.org/) `data-dict.yaml` that
  records column types, descriptions and references.
  [`grist_import()`](https://elipousson.github.io/gristmillr/reference/grist_import.md)
  creates tables from such a dictionary and its data files, converting
  foreign keys to `Ref` columns, and can load data prepared outside
  Grist. Both need the yaml12 package, and nanoparquet for Parquet
  files.

- [`vignette("migrating-data")`](https://elipousson.github.io/gristmillr/articles/migrating-data.md)
  explains how to move tables in and out of Grist with
  [`grist_export()`](https://elipousson.github.io/gristmillr/reference/grist_export.md)
  and
  [`grist_import()`](https://elipousson.github.io/gristmillr/reference/grist_import.md).

- [`grist_doc_import()`](https://elipousson.github.io/gristmillr/reference/grist_doc_import.md)
  creates a document from a `.grist`, `.csv`, `.xlsx` or `.json` file.
