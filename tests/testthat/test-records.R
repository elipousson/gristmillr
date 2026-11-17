test_that("grist_records() converts using column metadata", {
  local_grist_env()
  mock <- local_grist_mock(json_resp(columns_json), json_resp(records_json))

  out <- grist_records(test_doc(), "People")

  expect_s3_class(out, "tbl_df")
  expect_equal(out$name, c("Ann", "Bob"))
  expect_s3_class(out$seen, "POSIXct")
  expect_length(mock$reqs, 2)
  expect_match(mock$reqs[[1]]$url, "tables/People/columns$")
  expect_match(mock$reqs[[2]]$url, "tables/People/records$")
})

test_that("grist_records() sends filter, sort, limit and options", {
  local_grist_env()
  mock <- local_grist_mock(json_resp(records_json))

  grist_records(
    test_doc(),
    "People",
    filter = list(name = c("Ann", "Bob"), age = 30),
    sort = c("name", "-age"),
    limit = 10,
    convert = "basic",
    options = grist_read_options(hidden = TRUE)
  )

  url <- httr2::url_parse(mock$reqs[[1]]$url)
  expect_equal(url$query$filter, '{"name":["Ann","Bob"],"age":[30]}')
  expect_equal(url$query$sort, "name,-age")
  expect_equal(url$query$limit, "10")
  expect_equal(url$query$hidden, "true")
  expect_null(url$query$cellFormat)
})

test_that("grist_records() omits unset query parameters", {
  local_grist_env()
  mock <- local_grist_mock(json_resp(records_json))
  grist_records(test_doc(), "People", convert = "raw")
  expect_equal(
    mock$reqs[[1]]$url,
    "https://example.getgrist.com/api/docs/abc123/tables/People/records"
  )
})

test_that("convert = 'basic' and 'raw' skip the column request", {
  local_grist_env()
  mock <- local_grist_mock(json_resp(records_json))

  basic <- grist_records(test_doc(), "People", convert = "basic")
  expect_length(mock$reqs, 1)
  expect_equal(basic$born, c(631152000L, NA))

  raw <- grist_records(test_doc(), "People", convert = "raw")
  expect_equal(raw$age, list(30L, NULL))
})

test_that("col_names = 'label' fetches column metadata", {
  local_grist_env()
  local_grist_mock(json_resp(columns_json), json_resp(records_json))
  out <- grist_records(
    test_doc(),
    "People",
    convert = "basic",
    options = grist_read_options(col_names = "label")
  )
  expect_named(out, c("id", "Name", "Age", "Born", "Seen", "Tags", "Boss"))
})

test_that("typed cell format requires raw conversion", {
  local_grist_env()
  options <- grist_read_options(cell_format = "typed")
  expect_snapshot(
    grist_records(test_doc(), "People", options = options),
    error = TRUE
  )

  mock <- local_grist_mock(json_resp(records_json))
  grist_records(test_doc(), "People", convert = "raw", options = options)
  expect_equal(httr2::url_parse(mock$reqs[[1]]$url)$query$cellFormat, "typed")
})

test_that("grist_records() validates its arguments", {
  local_grist_env()
  doc <- test_doc()
  expect_snapshot(grist_records(doc, "People", filter = c(a = 1)), error = TRUE)
  expect_snapshot(grist_records(doc, "People", filter = list(1)), error = TRUE)
  expect_snapshot(grist_records(doc, "People", convert = "typed"), error = TRUE)
  expect_snapshot(grist_records(doc, "People", limit = -1), error = TRUE)
})

test_that("grist_records_add() sends records and returns new IDs", {
  local_grist_env()
  mock <- local_grist_mock(
    json_resp('{"records":[{"id":7},{"id":8}]}')
  )

  ids <- grist_records_add(
    test_doc(),
    "People",
    data.frame(name = c("Ann", "Bob"), age = c(1L, NA)),
    convert = "basic"
  )

  expect_equal(ids, 7:8)
  expect_equal(httr2::req_get_method(mock$reqs[[1]]), "POST")
  expect_equal(
    as.character(req_body(mock$reqs[[1]])),
    '{"records":[{"fields":{"name":"Ann","age":1}},{"fields":{"name":"Bob","age":null}}]}'
  )
})

test_that("grist_records_add() splits large writes into chunks", {
  local_grist_env()
  mock <- local_grist_mock(
    json_resp('{"records":[{"id":1},{"id":2}]}'),
    json_resp('{"records":[{"id":3},{"id":4}]}'),
    json_resp('{"records":[{"id":5}]}')
  )

  ids <- grist_records_add(
    test_doc(),
    "People",
    data.frame(x = 1:5),
    convert = "basic",
    options = grist_write_options(chunk_size = 2)
  )

  expect_equal(ids, 1:5)
  expect_length(mock$reqs, 3)
})

test_that("grist_records_add() with convert = 'auto' checks column names", {
  local_grist_env()
  local_grist_mock(json_resp(columns_json))
  expect_snapshot(
    grist_records_add(test_doc(), "People", data.frame(name = "x", nope = 1)),
    error = TRUE
  )
})

test_that("grist_records_add() can drop unknown columns", {
  local_grist_env()
  mock <- local_grist_mock(
    json_resp(columns_json),
    json_resp('{"records":[{"id":1}]}')
  )
  grist_records_add(
    test_doc(),
    "People",
    data.frame(name = "x", nope = 1),
    options = grist_write_options(unknown_cols = "drop")
  )
  expect_equal(
    as.character(req_body(mock$reqs[[2]])),
    '{"records":[{"fields":{"name":"x"}}]}'
  )
})

test_that("grist_records_add() converts dates for Grist", {
  local_grist_env()
  mock <- local_grist_mock(json_resp('{"records":[{"id":1}]}'))
  grist_records_add(
    test_doc(),
    "People",
    data.frame(born = as.Date("1990-01-01")),
    convert = "basic"
  )
  expect_equal(
    as.character(req_body(mock$reqs[[1]])),
    '{"records":[{"fields":{"born":631152000}}]}'
  )
})

test_that("grist_records_add() rejects an id column", {
  local_grist_env()
  expect_snapshot(
    grist_records_add(test_doc(), "People", data.frame(id = 1, x = 1)),
    error = TRUE
  )
  expect_snapshot(
    grist_records_add(test_doc(), "People", list(x = 1)),
    error = TRUE
  )
})

test_that("grist_records_update() sends PATCH requests with IDs", {
  local_grist_env()
  mock <- local_grist_mock(json_resp(""))

  doc <- test_doc()
  out <- grist_records_update(
    doc,
    "People",
    data.frame(id = c(1L, 2L), age = c(5L, 6L)),
    convert = "basic"
  )

  expect_identical(out, doc)
  expect_equal(httr2::req_get_method(mock$reqs[[1]]), "PATCH")
  expect_equal(
    as.character(req_body(mock$reqs[[1]])),
    '{"records":[{"id":1,"fields":{"age":5}},{"id":2,"fields":{"age":6}}]}'
  )
})

test_that("grist_records_update() requires an id column", {
  local_grist_env()
  expect_snapshot(
    grist_records_update(test_doc(), "People", data.frame(x = 1)),
    error = TRUE
  )
})

test_that("grist_records_delete() accepts IDs or a data frame", {
  local_grist_env()
  mock <- local_grist_mock(json_resp(""))

  grist_records_delete(test_doc(), "People", c(3, 4))
  grist_records_delete(test_doc(), "People", data.frame(id = 5L))
  grist_records_delete(test_doc(), "People", 6L)

  expect_match(mock$reqs[[1]]$url, "records/delete$")
  expect_equal(as.character(req_body(mock$reqs[[1]])), "[3,4]")
  expect_equal(as.character(req_body(mock$reqs[[2]])), "[5]")
  expect_equal(as.character(req_body(mock$reqs[[3]])), "[6]")
})

test_that("grist_records_delete() validates ids", {
  local_grist_env()
  expect_snapshot(grist_records_delete(test_doc(), "People", "a"), error = TRUE)
  expect_snapshot(
    grist_records_delete(test_doc(), "People", data.frame(x = 1)),
    error = TRUE
  )
})

test_that("empty writes make no requests", {
  local_grist_env()
  mock <- local_grist_mock(json_resp("{}"))
  expect_equal(
    grist_records_add(
      test_doc(),
      "People",
      data.frame(name = character()),
      convert = "basic"
    ),
    integer()
  )
  expect_length(mock$reqs, 0)
})
