webhooks_json <- paste0(
  '{"webhooks":[',
  '{"id":"w1","fields":{"name":"new-project","memo":"Email","url":"https://example.com/a","enabled":true,',
  '"unsubscribeKey":"secret","eventTypes":["add","update"],"isReadyColumn":null,"tableId":"Projects"},',
  '"usage":{"numWaiting":2,"status":"idle","updatedTime":1700000000000,"lastSuccessTime":1700000000000,',
  '"lastFailureTime":null,"lastErrorMessage":null,"lastHttpStatus":200}},',
  '{"id":"w2","fields":{"name":null,"memo":null,"url":"https://example.com/b","enabled":false,',
  '"unsubscribeKey":"secret2","eventTypes":["add"],"isReadyColumn":"Ready","tableId":"Tasks"},"usage":null}',
  "]}"
)

test_that("grist_webhooks() lists webhooks without the unsubscribe key", {
  local_grist_env()
  mock <- local_grist_mock(json_resp(webhooks_json))

  out <- grist_webhooks(test_doc())

  expect_equal(out$id, c("w1", "w2"))
  expect_equal(out$name, c("new-project", NA))
  expect_equal(out$table, c("Projects", "Tasks"))
  expect_equal(out$enabled, c(TRUE, FALSE))
  expect_equal(out$event_types, list(c("add", "update"), "add"))
  expect_equal(out$is_ready_column, c(NA, "Ready"))
  expect_equal(out$num_waiting, c(2L, NA))
  expect_equal(out$status, c("idle", NA))
  expect_equal(out$last_http_status, c(200L, NA))
  expect_s3_class(out$last_success_time, "POSIXct")
  expect_equal(as.numeric(out$last_success_time), c(1700000000, NA))
  expect_true(is.na(out$last_failure_time[[1]]))
  expect_false("unsubscribe_key" %in% names(out))
  expect_match(mock$reqs[[1]]$url, "/docs/abc123/webhooks$")
})

test_that("grist_webhooks() handles no webhooks", {
  local_grist_env()
  local_grist_mock(json_resp('{"webhooks":[]}'))
  out <- grist_webhooks(test_doc())
  expect_equal(nrow(out), 0)
  expect_s3_class(out$last_success_time, "POSIXct")
})

test_that("grist_webhook_create() posts the settings and returns the ID", {
  local_grist_env()
  mock <- local_grist_mock(json_resp('{"webhooks":[{"id":"new-id"}]}'))

  id <- grist_webhook_create(
    test_doc(),
    url = "https://example.com/hook",
    table = "Projects",
    event_types = "add",
    name = "hook"
  )

  expect_equal(id, "new-id")
  expect_equal(
    as.character(req_body(mock$reqs[[1]])),
    '{"webhooks":[{"fields":{"name":"hook","url":"https://example.com/hook","enabled":true,"eventTypes":["add"],"tableId":"Projects"}}]}'
  )
})

test_that("grist_webhook_create() defaults to all event types", {
  local_grist_env()
  mock <- local_grist_mock(json_resp('{"webhooks":[{"id":"x"}]}'))
  grist_webhook_create(test_doc(), "https://example.com", "T")
  expect_match(
    as.character(req_body(mock$reqs[[1]])),
    '"eventTypes":["add","update"]',
    fixed = TRUE
  )
})

test_that("grist_webhook_create() validates input", {
  local_grist_env()
  expect_snapshot(
    grist_webhook_create(
      test_doc(),
      "https://example.com",
      "T",
      event_types = "delete"
    ),
    error = TRUE
  )
  expect_snapshot(grist_webhook_create(test_doc(), 1, "T"), error = TRUE)
})

test_that("grist_webhook_update() only sends supplied settings", {
  local_grist_env()
  mock <- local_grist_mock(json_resp(""))
  doc <- test_doc()

  expect_identical(grist_webhook_update(doc, "w1", enabled = FALSE), doc)
  expect_equal(httr2::req_get_method(mock$reqs[[1]]), "PATCH")
  expect_match(mock$reqs[[1]]$url, "/webhooks/w1$")
  expect_equal(as.character(req_body(mock$reqs[[1]])), '{"enabled":false}')
})

test_that("grist_webhook_update() clears settings with NA", {
  local_grist_env()
  mock <- local_grist_mock(json_resp(""))
  grist_webhook_update(
    test_doc(),
    "w1",
    memo = NA,
    is_ready_column = NA,
    event_types = "update"
  )
  expect_equal(
    as.character(req_body(mock$reqs[[1]])),
    '{"eventTypes":["update"],"memo":null,"isReadyColumn":null}'
  )
})

test_that("grist_webhook_update() needs something to change", {
  local_grist_env()
  expect_snapshot(grist_webhook_update(test_doc(), "w1"), error = TRUE)
})

test_that("grist_webhook_delete() follows the ask rules", {
  local_grist_env()
  mock <- local_grist_mock(json_resp('{"success":true}'))

  grist_webhook_delete(test_doc(), "w1", ask = FALSE)
  expect_equal(httr2::req_get_method(mock$reqs[[1]]), "DELETE")
  expect_match(mock$reqs[[1]]$url, "/webhooks/w1$")

  local_interactive(FALSE)
  expect_error(
    grist_webhook_delete(test_doc(), "w1"),
    class = "gristmillr_ask_required"
  )
  expect_length(mock$reqs, 1)
})

test_that("grist_webhook_delete() prompts with the webhook name or URL", {
  local_grist_env()
  local_interactive(TRUE)
  prompts <- character()
  local_mocked_bindings(ask_yes_no = function(msg) {
    prompts <<- c(prompts, msg)
    TRUE
  })
  mock <- local_grist_mock(
    json_resp(webhooks_json),
    json_resp('{"success":true}')
  )

  grist_webhook_delete(test_doc(), "w1")
  mock <- local_grist_mock(
    json_resp(webhooks_json),
    json_resp('{"success":true}')
  )
  grist_webhook_delete(test_doc(), "w2")

  expect_equal(
    prompts,
    c(
      'Delete webhook "new-project"? This can\'t be undone.',
      'Delete webhook "https://example.com/b"? This can\'t be undone.'
    )
  )
})

test_that("declining the prompt or an unknown ID deletes nothing", {
  local_grist_env()
  local_interactive(TRUE)
  local_mocked_bindings(ask_yes_no = function(msg) FALSE)
  mock <- local_grist_mock(json_resp(webhooks_json))

  expect_error(
    grist_webhook_delete(test_doc(), "w1"),
    class = "gristmillr_cancelled"
  )
  expect_snapshot(grist_webhook_delete(test_doc(), "nope"), error = TRUE)
  expect_equal(
    unique(vapply(mock$reqs, httr2::req_get_method, "")),
    "GET"
  )
})

test_that("grist_webhook_queue_clear() clears one queue or all", {
  local_grist_env()
  mock <- local_grist_mock(json_resp(""))
  doc <- test_doc()

  expect_identical(grist_webhook_queue_clear(doc), doc)
  grist_webhook_queue_clear(doc, "w1")

  expect_match(mock$reqs[[1]]$url, "/webhooks/queue$")
  expect_match(mock$reqs[[2]]$url, "/webhooks/queue/w1$")
  expect_equal(httr2::req_get_method(mock$reqs[[2]]), "DELETE")
})

test_that("webhooks work against a live server", {
  skip_if_no_grist()
  doc <- local_scratch_doc()
  grist_table_create(doc, "Projects", c(name = "Text", ready = "Bool"))

  expect_equal(nrow(grist_webhooks(doc)), 0)
  expect_no_error(grist_webhook_queue_clear(doc))

  id <- tryCatch(
    grist_webhook_create(
      doc,
      url = "https://example.com/gristmillr-test",
      table = "Projects",
      event_types = "add",
      name = "test-hook",
      memo = "temporary"
    ),
    gristmillr_http_error = function(cnd) {
      if (httr2::resp_status(cnd$parent$resp) == 403) {
        # Grist only accepts webhook URLs on domains listed in the server's
        # ALLOWED_WEBHOOK_DOMAINS setting.
        skip("The server does not allow webhooks to example.com.")
      }
      stop(cnd)
    }
  )
  expect_type(id, "character")

  hooks <- grist_webhooks(doc)
  expect_equal(hooks$id, id)
  expect_equal(hooks$name, "test-hook")
  expect_equal(hooks$event_types, list("add"))
  expect_true(hooks$enabled)

  grist_webhook_update(
    doc,
    id,
    enabled = FALSE,
    memo = NA,
    event_types = c("add", "update"),
    is_ready_column = "ready"
  )
  hooks <- grist_webhooks(doc)
  expect_false(hooks$enabled)
  expect_true(is.na(hooks$memo))
  expect_equal(hooks$event_types, list(c("add", "update")))
  expect_equal(hooks$is_ready_column, "ready")

  grist_webhook_queue_clear(doc, id)
  grist_webhook_delete(doc, id, ask = FALSE)
  expect_equal(nrow(grist_webhooks(doc)), 0)
})
