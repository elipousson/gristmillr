# Manage webhooks

Webhooks make Grist send an HTTP POST to a URL when records in a table
change.

- `grist_webhooks()` lists a document's webhooks with their delivery
  status.

- `grist_webhook_create()` creates a webhook.

- `grist_webhook_update()` changes a webhook.

- `grist_webhook_delete()` deletes a webhook permanently.

- `grist_webhook_queue_clear()` discards undelivered payloads, for one
  webhook or for the whole document. Use it when the queue has built up
  because an endpoint was unreachable.

## Usage

``` r
grist_webhooks(doc)

grist_webhook_create(
  doc,
  url,
  table,
  event_types = c("add", "update"),
  name = NULL,
  memo = NULL,
  enabled = TRUE,
  is_ready_column = NULL
)

grist_webhook_update(
  doc,
  id,
  url = NULL,
  table = NULL,
  event_types = NULL,
  name = NULL,
  memo = NULL,
  enabled = NULL,
  is_ready_column = NULL
)

grist_webhook_delete(doc, id, ask = NULL)

grist_webhook_queue_clear(doc, id = NULL)
```

## Arguments

- doc:

  A `grist_doc` object, document ID or document URL. See
  [`grist_doc()`](https://elipousson.github.io/gristmillr/reference/grist_doc.md).

- url:

  URL that receives the POST requests.

- table:

  Table ID, as listed by
  [`grist_tables()`](https://elipousson.github.io/gristmillr/reference/grist_tables.md).

- event_types:

  Events that trigger the webhook: `"add"`, `"update"` or both.

- name, memo:

  Optional name and description. For `grist_webhook_update()`, `NULL`
  leaves the value unchanged and `NA` clears it.

- enabled:

  Whether the webhook is active.

- is_ready_column:

  Optional ID of a boolean column. When set, an event is only sent once
  the column is `TRUE`. For `grist_webhook_update()`, `NA` clears it.

- id:

  A webhook ID, as returned by `grist_webhook_create()` or listed by
  `grist_webhooks()`. For `grist_webhook_queue_clear()`, `NULL` clears
  the queues of all webhooks in the document.

- ask:

  Whether to prompt before running. `NULL` (the default) and `TRUE`
  prompt in an interactive session and error in a script. `FALSE` skips
  the prompt.

## Value

`grist_webhooks()` returns a data frame with one row per webhook: `id`,
`name`, `memo`, `url`, `enabled`, `table`, `event_types` (a
list-column), `is_ready_column`, and delivery columns `num_waiting`,
`status`, `last_success_time` and `last_failure_time` (`POSIXct` in
UTC), `last_error_message` and `last_http_status`. The webhook's
unsubscribe key is not included. `grist_webhook_create()` returns the
new webhook ID, and the other functions return `doc`, all invisibly.

## Deleting

`grist_webhook_delete()` asks for confirmation in an interactive session
and refuses to run in a script unless `ask = FALSE`, like
[`grist_doc_delete()`](https://elipousson.github.io/gristmillr/reference/grist_doc_create.md).

## Examples

``` r
if (FALSE) {
doc <- grist_doc("am2iHJ9Amvo7Ve3EE5emtu")

id <- grist_webhook_create(
  doc,
  url = "https://example.com/hook",
  table = "Projects",
  name = "new-project"
)
grist_webhooks(doc)

grist_webhook_update(doc, id, enabled = FALSE, memo = NA)
grist_webhook_queue_clear(doc, id)
grist_webhook_delete(doc, id)
}
```
