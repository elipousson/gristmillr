info_json <- '{"id":"abc123","name":"Pets","access":"owners","isPinned":true,"urlId":null,"createdAt":"2020-01-01T00:00:00.000Z","updatedAt":"2021-02-03T04:05:06.789Z","workspace":{"id":12,"name":"Home","org":{"domain":"docs"}}}'

test_that("grist_doc_create() returns a handle for the new document", {
  local_grist_env()
  mock <- local_grist_mock(json_resp('"newdoc123"'))

  doc <- grist_doc_create(
    12,
    "Pets",
    pinned = TRUE,
    server = "https://x.getgrist.com"
  )

  expect_s3_class(doc, "gristmillr::grist_doc")
  expect_equal(doc@doc_id, "newdoc123")
  expect_equal(doc@server, "https://x.getgrist.com")
  expect_equal(
    mock$reqs[[1]]$url,
    "https://x.getgrist.com/api/workspaces/12/docs"
  )
  expect_equal(
    as.character(req_body(mock$reqs[[1]])),
    '{"name":"Pets","isPinned":true}'
  )
})

test_that("grist_doc_info() returns one row", {
  local_grist_env()
  local_grist_mock(json_resp(info_json))

  out <- grist_doc_info(test_doc())

  expect_equal(nrow(out), 1)
  expect_equal(out$name, "Pets")
  expect_equal(out$workspace_id, 12L)
  expect_equal(out$org_domain, "docs")
  expect_true(is.na(out$url_id))
  expect_s3_class(out$created_at, "POSIXct")
  expect_equal(format(out$created_at, "%Y-%m-%d"), "2020-01-01")
  expect_equal(
    format(out$updated_at, "%Y-%m-%d %H:%M:%S"),
    "2021-02-03 04:05:06"
  )
})

test_that("grist_doc_info() tolerates missing timestamps", {
  local_grist_env()
  local_grist_mock(json_resp(
    '{"id":"abc123","name":"Pets","workspace":{"id":1,"name":"H","org":{"domain":"docs"}}}'
  ))
  out <- grist_doc_info(test_doc())
  expect_s3_class(out$created_at, "POSIXct")
  expect_true(is.na(out$created_at))
})

test_that("grist_doc_update() patches name and pinned", {
  local_grist_env()
  mock <- local_grist_mock(json_resp(""))
  doc <- test_doc()

  expect_identical(grist_doc_update(doc, name = "New"), doc)
  grist_doc_update(doc, pinned = FALSE)

  expect_equal(httr2::req_get_method(mock$reqs[[1]]), "PATCH")
  expect_equal(as.character(req_body(mock$reqs[[1]])), '{"name":"New"}')
  expect_equal(as.character(req_body(mock$reqs[[2]])), '{"isPinned":false}')
  expect_snapshot(grist_doc_update(doc), error = TRUE)
})

test_that("grist_doc_move() patches the workspace", {
  local_grist_env()
  mock <- local_grist_mock(json_resp(""))
  grist_doc_move(test_doc(), 99)
  expect_match(mock$reqs[[1]]$url, "/docs/abc123/move$")
  expect_equal(as.character(req_body(mock$reqs[[1]])), '{"workspace":99}')
})

test_that("grist_doc_delete() trashes by default when confirmed", {
  local_grist_env()
  mock <- local_grist_mock(json_resp(""))
  doc <- test_doc()

  expect_identical(grist_doc_delete(doc, confirm = TRUE), doc)

  expect_length(mock$reqs, 1)
  expect_equal(httr2::req_get_method(mock$reqs[[1]]), "POST")
  expect_equal(
    mock$reqs[[1]]$url,
    "https://example.getgrist.com/api/docs/abc123/remove"
  )
})

test_that("grist_doc_delete(mode = 'permanent') sets the permanent flag", {
  local_grist_env()
  mock <- local_grist_mock(json_resp(""))
  grist_doc_delete(test_doc(), mode = "permanent", confirm = TRUE)
  expect_match(mock$reqs[[1]]$url, "/remove\\?permanent=true$")
})

test_that("grist_doc_delete() refuses to run unconfirmed in scripts", {
  local_grist_env()
  local_interactive(FALSE)
  mock <- local_grist_mock(json_resp(""))

  expect_snapshot(grist_doc_delete(test_doc()), error = TRUE)
  expect_error(
    grist_doc_delete(test_doc()),
    class = "gristmillr_confirm_required"
  )
  expect_error(
    grist_doc_delete(test_doc(), confirm = FALSE),
    class = "gristmillr_confirm_required"
  )
  expect_length(mock$reqs, 0)
})

test_that("grist_doc_delete() validates confirm", {
  local_grist_env()
  expect_snapshot(grist_doc_delete(test_doc(), confirm = "yes"), error = TRUE)
})

test_that("grist_doc_delete() prompts interactively before trashing", {
  local_grist_env()
  local_interactive(TRUE)
  prompts <- character()
  local_mocked_bindings(ask_yes_no = function(msg) {
    prompts <<- c(prompts, msg)
    TRUE
  })
  mock <- local_grist_mock(json_resp(info_json), json_resp(""))

  grist_doc_delete(test_doc())

  expect_equal(prompts, 'Move document "Pets" to the trash?')
  expect_length(mock$reqs, 2)
  expect_match(mock$reqs[[2]]$url, "/remove$")
})

test_that("declining the prompt cancels the deletion", {
  local_grist_env()
  local_interactive(TRUE)
  local_mocked_bindings(ask_yes_no = function(msg) FALSE)
  mock <- local_grist_mock(json_resp(info_json), json_resp(""))

  expect_error(grist_doc_delete(test_doc()), class = "gristmillr_cancelled")
  expect_length(mock$reqs, 1)
})

test_that("permanent deletion requires typing the document name", {
  local_grist_env()
  local_interactive(TRUE)

  local_mocked_bindings(ask_text = function(msg) "wrong")
  local_grist_mock(json_resp(info_json), json_resp(""))
  expect_error(
    grist_doc_delete(test_doc(), mode = "permanent"),
    class = "gristmillr_cancelled"
  )

  local_mocked_bindings(ask_text = function(msg) "Pets")
  mock <- local_grist_mock(json_resp(info_json), json_resp(""))
  grist_doc_delete(test_doc(), mode = "permanent")
  expect_match(mock$reqs[[2]]$url, "permanent=true")
})

test_that("grist_doc_restore() posts to unremove", {
  local_grist_env()
  mock <- local_grist_mock(json_resp(""))
  grist_doc_restore(test_doc())
  expect_match(mock$reqs[[1]]$url, "/docs/abc123/unremove$")
  expect_equal(httr2::req_get_method(mock$reqs[[1]]), "POST")
})

test_that("grist_doc_import() uploads the file and returns a handle", {
  local_grist_env()
  mock <- local_grist_mock(json_resp('{"title":"pets","id":"newdoc123"}'))
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("a,b", "1,2"), path)

  doc <- grist_doc_import(path, workspace = 12, name = "Pets")

  expect_s3_class(doc, "gristmillr::grist_doc")
  expect_equal(doc@doc_id, "newdoc123")
  expect_equal(
    mock$reqs[[1]]$url,
    "https://docs.getgrist.com/api/workspaces/12/import"
  )
  expect_equal(mock$reqs[[1]]$body$type, "multipart")
  expect_named(mock$reqs[[1]]$body$data, c("upload", "documentName"))
})

test_that("grist_doc_import() omits the name when it isn't given", {
  local_grist_env()
  mock <- local_grist_mock(json_resp('{"title":"pets","id":"newdoc123"}'))
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("a,b", "1,2"), path)

  grist_doc_import(path, workspace = 12)

  expect_named(mock$reqs[[1]]$body$data, "upload")
})

test_that("grist_doc_import() validates its arguments", {
  local_grist_env()
  expect_snapshot(grist_doc_import("missing.csv", workspace = 1), error = TRUE)
  expect_error(
    grist_doc_import(tempdir(), workspace = 1),
    "must be an existing file"
  )
  expect_snapshot(grist_doc_import("a.csv", workspace = "x"), error = TRUE)
})
