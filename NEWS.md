# gristmillr 0.0.0.9000

* Initial development version with document handles (`grist_doc()`), options
  objects and `grist_request()` for building authenticated requests.
* `grist_tables()`, `grist_table_create()`, `grist_columns()`,
  `grist_columns_add()` and `grist_columns_modify()` read and change a
  document's schema.
* `grist_records()`, `grist_records_add()`, `grist_records_update()`,
  `grist_records_upsert()` and `grist_records_delete()` read and write records with a `convert` enum
  (`"auto"`, `"basic"` or `"raw"`). `grist_sql()` and `grist_count()` run SQL
  queries.
* `grist_doc_create()`, `grist_doc_info()`, `grist_doc_update()`,
  `grist_doc_move()`, `grist_doc_delete()` and `grist_doc_restore()` manage
  documents, and `grist_orgs()`, `grist_workspaces()`, `grist_docs()` and
  `grist_workspace_*()` list and manage orgs and workspaces. Deleting takes
  `mode = "trash"` or `"permanent"` and asks for confirmation.
* `grist_doc_download()` saves a document or table as `.grist`, Excel, CSV,
  TSV or DSV, and `grist_table_schema()` returns a table's Table Schema.
* `grist_resolve_refs()` looks up display values for `Ref` and `RefList`
  columns, and `vignette("joining-tables")` shows how to join tables.
* `grist_attachments()`, `grist_attachment_info()`,
  `grist_attachments_upload()` and `grist_attachment_download()` list, upload
  and download attachments.
* `grist_webhooks()`, `grist_webhook_create()`, `grist_webhook_update()`,
  `grist_webhook_delete()` and `grist_webhook_queue_clear()` manage webhooks.
* `grist_columns()` returns column descriptions, and `grist_columns_add()`,
  `grist_columns_modify()` and `grist_table_create()` can set them.
* `grist_doc_history()`, `grist_snapshots()` and `grist_doc_compare()` read a
  document's action history, snapshots and changes between states.
* `grist_snapshot_restore()`, `grist_snapshots_remove()` and
  `grist_doc_history_truncate()` restore a snapshot and remove snapshots or old
  history, after confirmation.
* `grist_doc()` and `grist_request_options()` gain an `api_key` argument, a
  string or a function returning one. String keys are held in session memory
  and never serialised with the object.
* `grist_doc_info()` returns `created_at` and `updated_at`. `grist_orgs()` now
  returns its timestamps as `POSIXct` in UTC rather than strings.
* `vignette("gristmillr")` is a getting-started guide.
* `grist_records_upsert()` updates and adds records by matching on key columns
  (`by`), with `mode` and `onmany` enums. It never deletes records.
