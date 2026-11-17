# TODO

What is left from the original scope and the follow-up requests. The core
design is built: handle and options, records, schema, SQL, documents and
workspaces, downloads, reference resolution, attachments, webhooks, column
descriptions, history, export and import.

## Before publishing

- [ ] Add `URL` and `BugReports` to `DESCRIPTION` after moving the package to
  GitHub, then set the pkgdown site URL, run `pkgdown::check_pkgdown()` and
  deploy the site.
- [ ] Rotate the Grist API key that was pasted into the development session.
- [ ] Run `jarl check .` and `ry check`, which haven't been run.
- [ ] If submitting to CRAN, do a pass with the `r-cran-extrachecks` skill.
- [ ] Choose which Grist-dependent examples run on a hosted site, if any.

## Not verified against a live server

- [ ] `grist_webhook_create()`, `grist_webhook_update()` and
  `grist_webhook_delete()`. The local server rejects every webhook URL, so the
  live test skips. Set `ALLOWED_WEBHOOK_DOMAINS` on a test server to run it.
- [ ] `grist_snapshot_restore()` and `grist_snapshots_remove()`. The local
  server only has a `"current"` snapshot.
- [ ] How the Grist interface renders a reference column after `display` (or
  `visible_col`) sets its display column through the REST API. `grist_resolve_refs()`
  reads it correctly, but the interface wasn't checked.
- [ ] The naming rule in `grist_table_id()` (used by `grist_import()` to match
  existing tables) covers capitalisation and invalid characters only.

## Features not built

- [ ] A DBI target for `grist_export()`, for DuckDB, SQLite or Postgres files
  (list columns as JSON).
- [ ] `grist_import()` from a named list of data frames, without a dictionary
  on disk. Needs a way to declare keys.
- [ ] Attachments in `grist_export()` and `grist_import()`.
- [ ] Verify a migration by translating data-dict assertions to SQL and running
  them with `grist_sql()` (untested whether Grist's SQLite accepts the output).
- [ ] A `gristapi` migration vignette. The README has a short function table.
  `grist_records_upsert()` is the equivalent of `sync_table()`.

## Out of scope

These stay reachable through `grist_request()`: SCIM and user admin, access
rules, proposals, `POST /docs/{id}/apply` (raw user actions), archive
attachment endpoints, document recovery and force-reload, and copying a
document (`sourceDocumentId`, `asTemplate`).

## Known limitations

- An empty `Bool` cell reads back as `FALSE` (Grist behaviour). It's documented.
- `grist_resolve_refs()` makes one extra request per referenced table.
- Formula columns are exported as values, not formulas.
- `grist_import()` leaves created tables and rows in place if a request fails
  part way.
- `grist_doc(api_key = 1)` errors, but the message names
  `grist_request_options()` rather than `grist_doc()`.

## Dependencies to watch

- S7 is pre-1.0 (developed against 0.2.2.9000), and the minimum R is 4.2.
- data-dict is at spec version 0.1.0. It doesn't allow extension keys and
  forbids foreign keys on list columns, which is why `grist_import()` takes a
  `types` argument. Revisit if the spec changes.
