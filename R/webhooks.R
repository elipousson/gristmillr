#' Manage webhooks
#'
#' @description
#' Webhooks make Grist send an HTTP POST to a URL when records in a table
#' change.
#'
#' * `grist_webhooks()` lists a document's webhooks with their delivery status.
#' * `grist_webhook_create()` creates a webhook.
#' * `grist_webhook_update()` changes a webhook.
#' * `grist_webhook_delete()` deletes a webhook permanently.
#' * `grist_webhook_queue_clear()` discards undelivered payloads, for one
#'   webhook or for the whole document. Use it when the queue has built up
#'   because an endpoint was unreachable.
#'
#' @section Deleting:
#' `grist_webhook_delete()` asks for confirmation in an interactive session
#' and refuses to run in a script unless `ask = FALSE`, like
#' [grist_doc_delete()].
#'
#' @inheritParams grist_records
#' @param id A webhook ID, as returned by `grist_webhook_create()` or listed by
#'   `grist_webhooks()`. For `grist_webhook_queue_clear()`, `NULL` clears the
#'   queues of all webhooks in the document.
#' @param url URL that receives the POST requests.
#' @param event_types Events that trigger the webhook: `"add"`, `"update"` or
#'   both.
#' @param name,memo Optional name and description. For
#'   `grist_webhook_update()`, `NULL` leaves the value unchanged and `NA`
#'   clears it.
#' @param enabled Whether the webhook is active.
#' @param is_ready_column Optional ID of a boolean column. When set, an event
#'   is only sent once the column is `TRUE`. For `grist_webhook_update()`, `NA`
#'   clears it.
#' @param ask Whether to prompt before running. `NULL` (the default) and
#'   `TRUE` prompt in an interactive session and error in a script. `FALSE`
#'   skips the prompt.
#' @returns `grist_webhooks()` returns a data frame with one row per webhook:
#'   `id`, `name`, `memo`, `url`, `enabled`, `table`, `event_types` (a
#'   list-column), `is_ready_column`, and delivery columns `num_waiting`,
#'   `status`, `last_success_time` and `last_failure_time` (`POSIXct` in
#'   UTC), `last_error_message` and `last_http_status`. The webhook's
#'   unsubscribe key is not included.
#'   `grist_webhook_create()` returns the new webhook ID, and the other
#'   functions return `doc`, all invisibly.
#' @family webhooks
#' @examplesIf FALSE
#' doc <- grist_doc("am2iHJ9Amvo7Ve3EE5emtu")
#'
#' id <- grist_webhook_create(
#'   doc,
#'   url = "https://example.com/hook",
#'   table = "Projects",
#'   name = "new-project"
#' )
#' grist_webhooks(doc)
#'
#' grist_webhook_update(doc, id, enabled = FALSE, memo = NA)
#' grist_webhook_queue_clear(doc, id)
#' grist_webhook_delete(doc, id)
#' @export
grist_webhooks <- function(doc) {
  doc <- grist_doc(doc)

  body <- grist_request(doc, "webhooks") |>
    grist_perform()

  webhooks_to_df(body$webhooks)
}

#' @rdname grist_webhooks
#' @export
grist_webhook_create <- function(
  doc,
  url,
  table,
  event_types = c("add", "update"),
  name = NULL,
  memo = NULL,
  enabled = TRUE,
  is_ready_column = NULL
) {
  doc <- grist_doc(doc)
  check_string(url)
  check_string(table)
  event_types <- arg_match(event_types, c("add", "update"), multiple = TRUE)
  check_string(name, allow_null = TRUE)
  check_string(memo, allow_null = TRUE)
  check_bool(enabled)
  check_string(is_ready_column, allow_null = TRUE)

  fields <- compact(list(
    name = name,
    memo = memo,
    url = url,
    enabled = enabled,
    eventTypes = as.list(event_types),
    isReadyColumn = is_ready_column,
    tableId = table
  ))

  body <- grist_request(doc, "webhooks") |>
    req_json_body(list(webhooks = list(list(fields = fields)))) |>
    grist_perform()
  invisible(body$webhooks[[1]]$id)
}

#' @rdname grist_webhooks
#' @export
grist_webhook_update <- function(
  doc,
  id,
  url = NULL,
  table = NULL,
  event_types = NULL,
  name = NULL,
  memo = NULL,
  enabled = NULL,
  is_ready_column = NULL
) {
  doc <- grist_doc(doc)
  check_string(id)
  check_string(url, allow_null = TRUE)
  check_string(table, allow_null = TRUE)
  if (!is.null(event_types)) {
    event_types <- arg_match(event_types, c("add", "update"), multiple = TRUE)
  }
  check_string(name, allow_null = TRUE, allow_na = TRUE)
  check_string(memo, allow_null = TRUE, allow_na = TRUE)
  check_bool(enabled, allow_null = TRUE)
  check_string(is_ready_column, allow_null = TRUE, allow_na = TRUE)

  fields <- compact(list(
    url = url,
    tableId = table,
    eventTypes = if (!is.null(event_types)) as.list(event_types),
    name = name,
    memo = memo,
    enabled = enabled,
    isReadyColumn = is_ready_column
  ))
  if (length(fields) == 0) {
    cli::cli_abort("Must supply at least one setting to change.")
  }
  # `NA` clears a setting, which Grist expects as an explicit JSON null.
  is_cleared <- map_lgl(fields, function(x) length(x) == 1 && is.na(x))
  fields[is_cleared] <- list(NULL)

  grist_request(doc, "webhooks", id) |>
    httr2::req_method("PATCH") |>
    req_json_body(fields) |>
    grist_perform()
  invisible(doc)
}

#' @rdname grist_webhooks
#' @export
grist_webhook_delete <- function(doc, id, ask = NULL) {
  doc <- grist_doc(doc)
  check_string(id)

  error_call <- current_env()
  check_ask(
    "webhook",
    function() {
      webhooks <- grist_webhooks(doc)
      row <- match(id, webhooks$id)
      if (is.na(row)) {
        cli::cli_abort(
          "Can't find a webhook with ID {.val {id}}.",
          call = error_call
        )
      }
      if (is.na(webhooks$name[[row]])) {
        webhooks$url[[row]]
      } else {
        webhooks$name[[row]]
      }
    },
    "delete",
    ask
  )

  grist_request(doc, "webhooks", id) |>
    httr2::req_method("DELETE") |>
    grist_perform()
  invisible(doc)
}

#' @rdname grist_webhooks
#' @export
grist_webhook_queue_clear <- function(doc, id = NULL) {
  doc <- grist_doc(doc)
  check_string(id, allow_null = TRUE)

  req <- if (is.null(id)) {
    grist_request(doc, "webhooks", "queue")
  } else {
    grist_request(doc, "webhooks", "queue", id)
  }
  req |>
    httr2::req_method("DELETE") |>
    grist_perform()
  invisible(doc)
}

webhooks_to_df <- function(webhooks) {
  usage <- function(name, ptype) {
    vapply(
      webhooks,
      function(x) {
        value <- x$usage[[name]]
        if (is.null(value)) ptype else vctrs::vec_cast(value, ptype)
      },
      ptype
    )
  }
  from_ms <- function(x) {
    as.POSIXct(x / 1000, origin = "1970-01-01", tz = "UTC")
  }

  new_tbl(
    list(
      id = field_vec(webhooks, "id", NA_character_, top = TRUE),
      name = field_vec(webhooks, "name", NA_character_),
      memo = field_vec(webhooks, "memo", NA_character_),
      url = field_vec(webhooks, "url", NA_character_),
      enabled = field_vec(webhooks, "enabled", NA),
      table = field_vec(webhooks, "tableId", NA_character_),
      event_types = map(webhooks, function(x) {
        as.character(unlist(x$fields$eventTypes))
      }),
      is_ready_column = field_vec(webhooks, "isReadyColumn", NA_character_),
      num_waiting = usage("numWaiting", NA_integer_),
      status = usage("status", NA_character_),
      last_success_time = from_ms(usage("lastSuccessTime", NA_real_)),
      last_failure_time = from_ms(usage("lastFailureTime", NA_real_)),
      last_error_message = usage("lastErrorMessage", NA_character_),
      last_http_status = usage("lastHttpStatus", NA_integer_)
    ),
    n = length(webhooks)
  )
}
