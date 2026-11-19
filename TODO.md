# TODO

What is left from the original scope and the follow-up requests. The core
design is built: handle and options, records, schema, SQL, documents and
workspaces, downloads, reference resolution, attachments, webhooks, column
descriptions, history, export and import.

## Before publishing

- [x] `URL` and `BugReports` are set and `pkgdown::check_pkgdown()` passes.
- [ ] Rotate the Grist API key that was pasted into the development session.
- [ ] Run `ry check`. It isn't installed here. `jarl check .` passes.
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
- [ ] Ask the data-dict maintainers to allow CSV and JSON in `source`. Until
  then those dictionaries have no `source`, so `data-dict validate-data` can't
  check the files.
- [ ] `grist_import()` from a named list of data frames, without a dictionary
  on disk. Needs a way to declare keys.
- [ ] Attachments in `grist_export()` and `grist_import()`.
- [ ] Verify a migration by translating data-dict assertions to SQL and running
  them with `grist_sql()` (untested whether Grist's SQLite accepts the output).
- [ ] A `gristapi` migration vignette. The README has a short function table.
  `grist_records_upsert()` is the equivalent of `sync_table()`.

## Records API redesign

Make the record writes data-first and type-stable, modelled on dplyr's
`rows_*()`: the first argument is the thing the function returns, so a data
frame can be piped in and comes back. `grist_resolve_refs()` already works this
way. Schema, read and document functions stay doc-first. Do this as one pass
that also updates the README, vignettes, examples and tests, and run the live
tests.

- [ ] `grist_records_add(data, doc, table, ...)` returns `data` with the new
  `id` column filled in, invisibly.
- [ ] `grist_records_insert(data, doc, table, by, ...)` adds rows whose `by`
  key isn't in the table and skips the rest (`rows_insert(conflict = "ignore")`,
  `PUT` with `noupdate`). Grist doesn't report which rows were skipped.
- [ ] `grist_records_update(data, doc, table, by = "id", unmatched = c("error",
  "ignore"), multiple, ...)`. `by = "id"` uses `PATCH`, where Grist errors on a
  missing row. Other `by` columns use `PUT` with `noadd`, which can only
  `"ignore"` unmatched rows, so `unmatched = "error"` isn't allowed there.
  Document this rather than pre-reading the table, which would be an extra
  request and racy.
- [ ] `grist_records_upsert(data, doc, table, by, multiple, ...)`.
- [ ] `grist_records_delete(data, doc, table, ...)`: `data` is a data frame
  with an `id` column or a vector of IDs, returned unchanged, invisibly.
  Deletes by row ID only.
- [ ] Rename `onmany` to `multiple` (`"first"`, `"all"`, `"none"`), after
  `left_join(multiple = )`.
- [ ] Drop `mode` from `grist_records_upsert()`, which `grist_records_insert()`
  and the `unmatched` argument of `grist_records_update()` replace.
- [ ] Decide return values for the schema and document functions in the same
  pass. They should follow the same rule, and `grist_workspace_*()` return an
  ID where `grist_doc_*()` return a handle.

## Booleans to review

Prefer an enum to a flag
([design guide](https://design.tidyverse.org/boolean-strategies.html)) when an
argument can plausibly take more values or only makes sense with another
argument.

- [ ] `no_history` and `template` in `grist_doc_download()` are two flags that
  only apply to `format = "grist"`, and `template` implies no history. A single
  enum such as `content = c("full", "no_history", "template")` fits better.
- `overwrite` and `parse` are probably fine as logicals. `hidden`, `raw`,
  `pinned` and `enabled` are plain on/off switches.

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
