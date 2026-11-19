test_that("grist_doc_history() lists states newest first", {
  local_grist_env()
  mock <- local_grist_mock(json_resp(
    '{"states":[{"n":3,"h":"ccc"},{"n":2,"h":"bbb"},{"n":1,"h":"aaa"}]}'
  ))

  out <- grist_doc_history(test_doc())

  expect_equal(out$n, 3:1)
  expect_equal(out$hash, c("ccc", "bbb", "aaa"))
  expect_match(mock$reqs[[1]]$url, "/docs/abc123/states$")
})

test_that("grist_doc_history() handles an empty history", {
  local_grist_env()
  local_grist_mock(json_resp('{"states":[]}'))
  out <- grist_doc_history(test_doc())
  expect_equal(nrow(out), 0)
  expect_named(out, c("n", "hash"))
})

test_that("grist_snapshots() lists snapshots", {
  local_grist_env()
  mock <- local_grist_mock(json_resp(
    '{"snapshots":[{"snapshotId":"s2","lastModified":"2024-05-01T10:30:00.000Z","docId":"abc123~v=2"},{"snapshotId":"s1","lastModified":"2024-04-01T00:00:00.000Z","docId":"abc123~v=1"}]}'
  ))

  out <- grist_snapshots(test_doc())

  expect_equal(out$snapshot_id, c("s2", "s1"))
  expect_equal(out$doc_id, c("abc123~v=2", "abc123~v=1"))
  expect_s3_class(out$last_modified, "POSIXct")
  expect_equal(
    format(out$last_modified[[1]], "%Y-%m-%d %H:%M"),
    "2024-05-01 10:30"
  )
  expect_match(mock$reqs[[1]]$url, "/snapshots$")
})

test_that("grist_snapshots(raw = TRUE) asks for all snapshots", {
  local_grist_env()
  mock <- local_grist_mock(json_resp('{"snapshots":[]}'))
  out <- grist_snapshots(test_doc(), raw = TRUE)
  expect_equal(nrow(out), 0)
  expect_match(mock$reqs[[1]]$url, "/snapshots\\?raw=true$")
})

compare_json <- paste0(
  '{"left":{"n":1,"h":"aaa"},"right":{"n":4,"h":"ddd"},"parent":{"n":1,"h":"aaa"},"summary":"right",',
  '"details":{"leftChanges":{"tableRenames":[],"tableDeltas":{}},',
  '"rightChanges":{"tableRenames":[[null,"T"]],"tableDeltas":{',
  '"T":{"updateRows":[1],"removeRows":[],"addRows":[1,2],"columnDeltas":{"x":{}},"columnRenames":[]},',
  '"_grist_Tables":{"updateRows":[],"removeRows":[3],"addRows":[],"columnDeltas":{"a":{},"b":{}},"columnRenames":[]}}}}}'
)

test_that("grist_doc_compare() summarises the changes", {
  local_grist_env()
  mock <- local_grist_mock(json_resp(compare_json))

  out <- grist_doc_compare(
    test_doc(),
    left = "aaa",
    right = "ddd",
    max_rows = 10
  )

  expect_equal(out$summary, "right")
  expect_equal(out$left, list(n = 1L, hash = "aaa"))
  expect_equal(out$right, list(n = 4L, hash = "ddd"))
  expect_equal(out$parent, list(n = 1L, hash = "aaa"))

  expect_equal(out$changes$side, c("right", "right"))
  expect_equal(out$changes$table, c("T", "_grist_Tables"))
  expect_equal(out$changes$rows_added, c(2L, 0L))
  expect_equal(out$changes$rows_updated, c(1L, 0L))
  expect_equal(out$changes$rows_removed, c(0L, 1L))
  expect_equal(out$changes$columns_changed, c(1L, 2L))
  expect_equal(out$changes$internal, c(FALSE, TRUE))

  url <- httr2::url_parse(mock$reqs[[1]]$url)
  expect_equal(url$query, list(left = "aaa", right = "ddd", maxRows = "10"))
})

test_that("grist_doc_compare() defaults to the current state", {
  local_grist_env()
  mock <- local_grist_mock(json_resp(
    '{"left":{"n":2,"h":"b"},"right":{"n":2,"h":"b"},"parent":null,"summary":"same"}'
  ))

  out <- grist_doc_compare(test_doc())

  expect_equal(out$summary, "same")
  expect_null(out$parent)
  expect_equal(nrow(out$changes), 0)
  expect_named(
    out$changes,
    c(
      "side",
      "table",
      "rows_added",
      "rows_updated",
      "rows_removed",
      "columns_changed",
      "internal"
    )
  )
  expect_equal(
    mock$reqs[[1]]$url,
    "https://example.getgrist.com/api/docs/abc123/compare"
  )
})

test_that("grist_doc_compare() validates its arguments", {
  local_grist_env()
  expect_snapshot(grist_doc_compare(test_doc(), left = 1), error = TRUE)
  expect_snapshot(grist_doc_compare(test_doc(), max_rows = -1), error = TRUE)
})

test_that("history works against a live server", {
  skip_if_no_grist()
  doc <- local_scratch_doc()
  before <- nrow(grist_doc_history(doc))

  grist_table_create(doc, "T", c(x = "Text"))
  grist_records_add(data.frame(x = c("a", "b")), doc, "T")

  history <- grist_doc_history(doc)
  expect_gt(nrow(history), before)
  expect_equal(history$n, sort(history$n, decreasing = TRUE))

  snapshots <- grist_snapshots(doc)
  expect_gte(nrow(snapshots), 1)
  expect_s3_class(snapshots$last_modified, "POSIXct")

  out <- grist_doc_compare(doc, left = history$hash[[nrow(history)]])
  expect_equal(out$summary, "right")
  added <- subset(out$changes, table == "T" & side == "right")
  expect_equal(added$rows_added, 2L)
  expect_false(added$internal)
  expect_true(any(out$changes$internal))

  expect_equal(grist_doc_compare(doc)$summary, "same")
})

test_that("grist_snapshot_restore() posts the snapshot ID", {
  local_grist_env()
  mock <- local_grist_mock(json_resp(""))
  doc <- test_doc()

  expect_identical(grist_snapshot_restore(doc, "s1", ask = FALSE), doc)

  expect_match(mock$reqs[[1]]$url, "/docs/abc123/replace$")
  expect_equal(as.character(req_body(mock$reqs[[1]])), '{"snapshotId":"s1"}')
})

test_that("grist_snapshots_remove() posts the snapshot IDs", {
  local_grist_env()
  mock <- local_grist_mock(json_resp('{"snapshotIds":["a"]}'))

  grist_snapshots_remove(test_doc(), "a", ask = FALSE)

  expect_match(mock$reqs[[1]]$url, "/snapshots/remove$")
  expect_equal(
    as.character(req_body(mock$reqs[[1]])),
    '{"snapshotIds":["a"]}'
  )
})

test_that("grist_doc_history_truncate() posts how many actions to keep", {
  local_grist_env()
  mock <- local_grist_mock(json_resp(""))

  grist_doc_history_truncate(test_doc(), keep = 5, ask = FALSE)

  expect_match(mock$reqs[[1]]$url, "/states/remove$")
  expect_equal(as.character(req_body(mock$reqs[[1]])), '{"keep":5}')
})

test_that("history changes refuse to run without ask = FALSE in scripts", {
  local_grist_env()
  local_interactive(FALSE)
  expect_snapshot(grist_snapshot_restore(test_doc(), "s1"), error = TRUE)
  expect_snapshot(grist_snapshots_remove(test_doc(), "s1"), error = TRUE)
  expect_snapshot(grist_doc_history_truncate(test_doc(), 1), error = TRUE)
})

test_that("history changes validate their arguments", {
  local_grist_env()
  expect_snapshot(grist_snapshot_restore(test_doc(), 1), error = TRUE)
  expect_snapshot(grist_snapshots_remove(test_doc(), character()), error = TRUE)
  expect_snapshot(grist_doc_history_truncate(test_doc(), -1), error = TRUE)
})

test_that("grist_snapshot_restore() prompts interactively", {
  local_grist_env()
  local_interactive(TRUE)
  prompts <- character()
  local_mocked_bindings(ask_yes_no = function(msg) {
    prompts <<- c(prompts, msg)
    FALSE
  })
  mock <- local_grist_mock(json_resp(
    '{"id":"abc123","name":"Pets","workspace":{"id":1,"name":"H","org":{"domain":"docs"}}}'
  ))

  expect_error(
    grist_snapshot_restore(test_doc(), "s1"),
    class = "gristmillr_cancelled"
  )
  expect_match(prompts, "Replace the current contents of the document")
  expect_length(mock$reqs, 1)
})

test_that("truncating history works against a live server", {
  skip_if_no_grist()
  doc <- local_scratch_doc()
  grist_table_create(doc, "T", c(x = "Text"))
  grist_records_add(data.frame(x = c("a", "b")), doc, "T")

  expect_identical(
    grist_doc_history_truncate(doc, keep = 2, ask = FALSE),
    doc
  )
  expect_lte(nrow(grist_doc_history(doc)), 3)
  expect_equal(grist_records(doc, "T")$x, c("a", "b"))
})

test_that("grist_snapshots_remove() sends names-free snapshot IDs", {
  local_grist_env()
  mock <- local_grist_mock(json_resp("{}"))

  grist_snapshots_remove(test_doc(), c(a = "s1", b = "s2"), ask = FALSE)

  expect_equal(
    req_body_sent(mock$reqs[[1]]),
    '{"snapshotIds":["s1","s2"]}'
  )
})
