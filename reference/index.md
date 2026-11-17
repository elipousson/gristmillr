# Package index

## Documents

Create handles for documents and manage them.

- [`grist_doc()`](https://elipousson.github.io/gristmillr/reference/grist_doc.md)
  : Create a handle for a Grist document
- [`grist_doc_create()`](https://elipousson.github.io/gristmillr/reference/grist_doc_create.md)
  [`grist_doc_info()`](https://elipousson.github.io/gristmillr/reference/grist_doc_create.md)
  [`grist_doc_update()`](https://elipousson.github.io/gristmillr/reference/grist_doc_create.md)
  [`grist_doc_move()`](https://elipousson.github.io/gristmillr/reference/grist_doc_create.md)
  [`grist_doc_delete()`](https://elipousson.github.io/gristmillr/reference/grist_doc_create.md)
  [`grist_doc_restore()`](https://elipousson.github.io/gristmillr/reference/grist_doc_create.md)
  : Create, describe, update, move and delete documents
- [`grist_doc_import()`](https://elipousson.github.io/gristmillr/reference/grist_doc_import.md)
  : Import a file as a new document
- [`grist_request()`](https://elipousson.github.io/gristmillr/reference/grist_request.md)
  : Build a request for the Grist API
- [`grist_doc_download()`](https://elipousson.github.io/gristmillr/reference/grist_doc_download.md)
  [`grist_table_schema()`](https://elipousson.github.io/gristmillr/reference/grist_doc_download.md)
  : Download a document or table to a file

## Records

- [`grist_records()`](https://elipousson.github.io/gristmillr/reference/grist_records.md)
  [`grist_records_add()`](https://elipousson.github.io/gristmillr/reference/grist_records.md)
  [`grist_records_update()`](https://elipousson.github.io/gristmillr/reference/grist_records.md)
  [`grist_records_upsert()`](https://elipousson.github.io/gristmillr/reference/grist_records.md)
  [`grist_records_delete()`](https://elipousson.github.io/gristmillr/reference/grist_records.md)
  : Read, add, update and delete records
- [`grist_sql()`](https://elipousson.github.io/gristmillr/reference/grist_sql.md)
  [`grist_count()`](https://elipousson.github.io/gristmillr/reference/grist_sql.md)
  : Run a SQL query against a document
- [`grist_resolve_refs()`](https://elipousson.github.io/gristmillr/reference/grist_resolve_refs.md)
  : Resolve reference columns to display values

## Schema

- [`grist_tables()`](https://elipousson.github.io/gristmillr/reference/grist_tables.md)
  [`grist_table_create()`](https://elipousson.github.io/gristmillr/reference/grist_tables.md)
  : List and create tables
- [`grist_columns()`](https://elipousson.github.io/gristmillr/reference/grist_columns.md)
  [`grist_columns_add()`](https://elipousson.github.io/gristmillr/reference/grist_columns.md)
  [`grist_columns_modify()`](https://elipousson.github.io/gristmillr/reference/grist_columns.md)
  : List, add and modify columns

## Attachments

- [`grist_attachments()`](https://elipousson.github.io/gristmillr/reference/grist_attachments.md)
  [`grist_attachment_info()`](https://elipousson.github.io/gristmillr/reference/grist_attachments.md)
  [`grist_attachments_upload()`](https://elipousson.github.io/gristmillr/reference/grist_attachments.md)
  [`grist_attachment_download()`](https://elipousson.github.io/gristmillr/reference/grist_attachments.md)
  : List, upload and download attachments

## Export and import

- [`grist_export()`](https://elipousson.github.io/gristmillr/reference/grist_export.md)
  : Export a document's tables to files and a data dictionary
- [`grist_import()`](https://elipousson.github.io/gristmillr/reference/grist_import.md)
  : Import tables from files and a data dictionary

## History

- [`grist_doc_history()`](https://elipousson.github.io/gristmillr/reference/grist_doc_history.md)
  [`grist_snapshots()`](https://elipousson.github.io/gristmillr/reference/grist_doc_history.md)
  [`grist_doc_compare()`](https://elipousson.github.io/gristmillr/reference/grist_doc_history.md)
  : Inspect a document's history
- [`grist_snapshot_restore()`](https://elipousson.github.io/gristmillr/reference/grist_snapshot_restore.md)
  [`grist_snapshots_remove()`](https://elipousson.github.io/gristmillr/reference/grist_snapshot_restore.md)
  [`grist_doc_history_truncate()`](https://elipousson.github.io/gristmillr/reference/grist_snapshot_restore.md)
  : Restore or remove document history

## Webhooks

- [`grist_webhooks()`](https://elipousson.github.io/gristmillr/reference/grist_webhooks.md)
  [`grist_webhook_create()`](https://elipousson.github.io/gristmillr/reference/grist_webhooks.md)
  [`grist_webhook_update()`](https://elipousson.github.io/gristmillr/reference/grist_webhooks.md)
  [`grist_webhook_delete()`](https://elipousson.github.io/gristmillr/reference/grist_webhooks.md)
  [`grist_webhook_queue_clear()`](https://elipousson.github.io/gristmillr/reference/grist_webhooks.md)
  : Manage webhooks

## Orgs and workspaces

- [`grist_orgs()`](https://elipousson.github.io/gristmillr/reference/grist_orgs.md)
  [`grist_workspaces()`](https://elipousson.github.io/gristmillr/reference/grist_orgs.md)
  [`grist_docs()`](https://elipousson.github.io/gristmillr/reference/grist_orgs.md)
  [`grist_workspace_create()`](https://elipousson.github.io/gristmillr/reference/grist_orgs.md)
  [`grist_workspace_delete()`](https://elipousson.github.io/gristmillr/reference/grist_orgs.md)
  [`grist_workspace_restore()`](https://elipousson.github.io/gristmillr/reference/grist_orgs.md)
  : List orgs, workspaces and documents; manage workspaces

## Options

- [`grist_request_options()`](https://elipousson.github.io/gristmillr/reference/grist-options.md)
  [`grist_read_options()`](https://elipousson.github.io/gristmillr/reference/grist-options.md)
  [`grist_write_options()`](https://elipousson.github.io/gristmillr/reference/grist-options.md)
  : Options for Grist requests, reads and writes
