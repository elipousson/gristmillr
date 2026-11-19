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

  out <- grist_records_add(
    data.frame(name = c("Ann", "Bob"), age = c(1L, NA)),
    test_doc(),
    "People",
    convert = "basic"
  )

  expect_equal(out$id, 7:8)
  expect_equal(names(out), c("id", "name", "age"))
  expect_equal(out$name, c("Ann", "Bob"))
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

  out <- grist_records_add(
    data.frame(x = 1:5),
    test_doc(),
    "People",
    convert = "basic",
    options = grist_write_options(chunk_size = 2)
  )

  expect_equal(out$id, 1:5)
  expect_length(mock$reqs, 3)
})

test_that("grist_records_add() with convert = 'auto' checks column names", {
  local_grist_env()
  local_grist_mock(json_resp(columns_json))
  expect_snapshot(
    grist_records_add(data.frame(name = "x", nope = 1), test_doc(), "People"),
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
    data.frame(name = "x", nope = 1),
    test_doc(),
    "People",
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
    data.frame(born = as.Date("1990-01-01")),
    test_doc(),
    "People",
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
    grist_records_add(data.frame(id = 1, x = 1), test_doc(), "People"),
    error = TRUE
  )
  expect_snapshot(
    grist_records_add(list(x = 1), test_doc(), "People"),
    error = TRUE
  )
})

test_that("grist_records_update() sends PATCH requests with IDs", {
  local_grist_env()
  mock <- local_grist_mock(json_resp(""))

  data <- data.frame(id = c(1L, 2L), age = c(5L, 6L))
  out <- grist_records_update(data, test_doc(), "People", convert = "basic")

  expect_identical(out, data)
  expect_equal(httr2::req_get_method(mock$reqs[[1]]), "PATCH")
  expect_equal(
    as.character(req_body(mock$reqs[[1]])),
    '{"records":[{"id":1,"fields":{"age":5}},{"id":2,"fields":{"age":6}}]}'
  )
})

test_that("grist_records_update() matches other columns with PUT", {
  local_grist_env()
  mock <- local_grist_mock(json_resp(""))

  data <- data.frame(name = c("Ann", "Bob"), age = c(5L, 6L))
  out <- grist_records_update(
    data,
    test_doc(),
    "People",
    by = "name",
    unmatched = "ignore",
    multiple = "all",
    convert = "basic"
  )

  expect_identical(out, data)
  expect_equal(httr2::req_get_method(mock$reqs[[1]]), "PUT")
  expect_match(mock$reqs[[1]]$url, "onmany=all")
  expect_match(mock$reqs[[1]]$url, "noadd=true")
  expect_no_match(mock$reqs[[1]]$url, "noupdate")
  expect_equal(
    as.character(req_body(mock$reqs[[1]])),
    paste0(
      '{"records":[{"require":{"name":"Ann"},"fields":{"age":5}},',
      '{"require":{"name":"Bob"},"fields":{"age":6}}]}'
    )
  )
})

test_that("grist_records_update() only supports the unmatched value Grist can", {
  local_grist_env()
  mock <- local_grist_mock(json_resp(""))
  data <- data.frame(id = 1L, name = "Ann")

  expect_error(
    grist_records_update(data, test_doc(), "People", unmatched = "ignore"),
    class = "gristmillr_unmatched"
  )
  expect_error(
    grist_records_update(data[-1], test_doc(), "People", by = "name"),
    class = "gristmillr_unmatched"
  )
  expect_snapshot(
    grist_records_update(data, test_doc(), "People", unmatched = "ignore"),
    error = TRUE
  )
  expect_snapshot(
    grist_records_update(data[-1], test_doc(), "People", by = "name"),
    error = TRUE
  )
  expect_snapshot(
    grist_records_update(data, test_doc(), "People", by = c("id", "name")),
    error = TRUE
  )
  expect_length(mock$reqs, 0)
})

test_that("grist_records_update() requires an id column", {
  local_grist_env()
  expect_snapshot(
    grist_records_update(data.frame(x = 1), test_doc(), "People"),
    error = TRUE
  )
})

test_that("grist_records_delete() accepts IDs or a data frame", {
  local_grist_env()
  mock <- local_grist_mock(json_resp(""))

  grist_records_delete(c(3, 4), test_doc(), "People")
  grist_records_delete(data.frame(id = 5L), test_doc(), "People")
  grist_records_delete(6L, test_doc(), "People")

  expect_match(mock$reqs[[1]]$url, "records/delete$")
  expect_equal(as.character(req_body(mock$reqs[[1]])), "[3,4]")
  expect_equal(as.character(req_body(mock$reqs[[2]])), "[5]")
  expect_equal(as.character(req_body(mock$reqs[[3]])), "[6]")
})

test_that("grist_records_add() keeps the class of data and can be piped", {
  local_grist_env()
  local_grist_mock(json_resp('{"records":[{"id":7},{"id":8}]}'))

  data <- new_tbl(list(name = c("Ann", "Bob")), n = 2L)
  out <- data |> grist_records_add(test_doc(), "People", convert = "basic")

  expect_s3_class(out, "tbl_df")
  expect_equal(out$id, 7:8)
  expect_equal(names(out), c("id", "name"))
})

test_that("grist_records_delete() returns its input unchanged", {
  local_grist_env()
  local_grist_mock(json_resp(""))

  ids <- c(3, 4)
  expect_identical(grist_records_delete(ids, test_doc(), "People"), ids)
  expect_false(withVisible(grist_records_delete(ids, test_doc(), "People"))$visible)

  data <- data.frame(id = 5L, name = "x")
  expect_identical(grist_records_delete(data, test_doc(), "People"), data)
})

test_that("grist_records_delete() validates ids", {
  local_grist_env()
  expect_snapshot(grist_records_delete("a", test_doc(), "People"), error = TRUE)
  expect_snapshot(
    grist_records_delete(data.frame(x = 1), test_doc(), "People"),
    error = TRUE
  )
})

test_that("as_row_ids() accepts only lossless integer conversions", {
  expect_equal(as_row_ids(c(1, 2L)), c(1L, 2L))
  expect_equal(as_row_ids(c("3", "4")), c(3L, 4L))
  expect_equal(as_row_ids(integer()), integer())

  expect_error(as_row_ids(1.5), class = "gristmillr_invalid_ids")
  expect_error(as_row_ids("1.5"), class = "gristmillr_invalid_ids")
  expect_error(as_row_ids("1e2"), class = "gristmillr_invalid_ids")
  expect_error(as_row_ids(NA_integer_), class = "gristmillr_invalid_ids")
  expect_error(as_row_ids(c(1, NA)), class = "gristmillr_invalid_ids")
  expect_error(as_row_ids("a"), class = "gristmillr_invalid_ids")
  expect_error(as_row_ids(TRUE), class = "gristmillr_invalid_ids")
  expect_error(as_row_ids(factor("1")), class = "gristmillr_invalid_ids")
})

test_that("grist_records_update() validates and converts ids", {
  local_grist_env()
  mock <- local_grist_mock(json_resp("{}"))

  grist_records_update(
    data.frame(id = c(1, 2), age = 3:4),
    test_doc(),
    "People",
    convert = "basic"
  )
  expect_equal(
    req_body_sent(mock$reqs[[1]]),
    '{"records":[{"id":1,"fields":{"age":3}},{"id":2,"fields":{"age":4}}]}'
  )

  expect_snapshot(
    grist_records_update(
      data.frame(id = c(1, 1.5), age = 3:4),
      test_doc(),
      "People",
      convert = "basic"
    ),
    error = TRUE
  )
  expect_length(mock$reqs, 1)
})

test_that("grist_records_delete() rejects ids that would be truncated", {
  local_grist_env()
  mock <- local_grist_mock(json_resp(""))
  expect_error(
    grist_records_delete(1.5, test_doc(), "People"),
    class = "gristmillr_invalid_ids"
  )
  expect_length(mock$reqs, 0)
})

test_that("empty writes make no requests", {
  local_grist_env()
  mock <- local_grist_mock(json_resp("{}"))
  expect_equal(
    grist_records_add(
      data.frame(name = character()),
      test_doc(),
      "People",
      convert = "basic"
    )$id,
    integer()
  )
  expect_length(mock$reqs, 0)
})

test_that("grist_records_upsert() sends PUT requests with require and fields", {
  local_grist_env()
  mock <- local_grist_mock(json_resp(""))

  data <- data.frame(name = c("Ann", "Bob"), age = c(5L, 6L))
  out <- grist_records_upsert(
    data,
    test_doc(),
    "People",
    by = "name",
    convert = "basic"
  )

  expect_identical(out, data)
  expect_equal(httr2::req_get_method(mock$reqs[[1]]), "PUT")
  expect_equal(
    as.character(req_body(mock$reqs[[1]])),
    paste0(
      '{"records":[{"require":{"name":"Ann"},"fields":{"age":5}},',
      '{"require":{"name":"Bob"},"fields":{"age":6}}]}'
    )
  )
  expect_equal(httr2::url_parse(mock$reqs[[1]]$url)$query, NULL)
})

test_that("upsert and insert send the query parameters for their mode", {
  local_grist_env()
  mock <- local_grist_mock(json_resp(""), json_resp(""), json_resp(""))
  data <- data.frame(name = "Ann", age = 5L)

  out <- grist_records_upsert(
    data,
    test_doc(),
    "People",
    "name",
    multiple = "all",
    convert = "basic"
  )
  expect_identical(out, data)
  grist_records_upsert(data, test_doc(), "People", "name", convert = "basic")
  out <- grist_records_insert(data, test_doc(), "People", "name", convert = "basic")
  expect_identical(out, data)

  query <- function(i) httr2::url_parse(mock$reqs[[i]]$url)$query
  expect_equal(query(1), list(onmany = "all"))
  expect_null(query(2))
  expect_equal(query(3), list(noupdate = "true"))
  expect_equal(httr2::req_get_method(mock$reqs[[3]]), "PUT")
})

test_that("grist_records_insert() validates its input like upsert", {
  local_grist_env()
  data <- data.frame(name = c("a", "a"))
  expect_error(grist_records_insert(data, test_doc(), "T", by = "name"))
  expect_error(grist_records_insert(data, test_doc(), "T"), class = "rlang_error")
  expect_error(
    grist_records_insert(data.frame(id = 1L, a = 1), test_doc(), "T", by = "a")
  )
})

test_that("grist_records_upsert() converts keys like other values", {
  local_grist_env()
  mock <- local_grist_mock(json_resp(""))
  grist_records_upsert(
    data.frame(day = as.Date("2020-01-02"), n = 1L),
    test_doc(),
    "People",
    by = "day",
    convert = "basic"
  )
  expect_equal(
    as.character(req_body(mock$reqs[[1]])),
    '{"records":[{"require":{"day":1577923200},"fields":{"n":1}}]}'
  )
})

test_that("grist_records_upsert() allows data with only key columns", {
  local_grist_env()
  mock <- local_grist_mock(json_resp(""))
  grist_records_upsert(
    data.frame(name = "Ann"),
    test_doc(),
    "People",
    by = "name",
    convert = "basic"
  )
  expect_equal(
    as.character(req_body(mock$reqs[[1]])),
    '{"records":[{"require":{"name":"Ann"},"fields":{}}]}'
  )
})

test_that("grist_records_upsert() validates by and data", {
  local_grist_env()
  data <- data.frame(name = c("Ann", "Ann", NA), age = 1:3)
  expect_snapshot(grist_records_upsert(data, test_doc(), "T"), error = TRUE)
  expect_snapshot(
    grist_records_upsert(data, test_doc(), "T", by = 1),
    error = TRUE
  )
  expect_snapshot(
    grist_records_upsert(data, test_doc(), "T", by = "x"),
    error = TRUE
  )
  expect_snapshot(
    grist_records_upsert(data, test_doc(), "T", by = "name"),
    error = TRUE
  )
  expect_snapshot(
    grist_records_upsert(data[c(1, 2), ], test_doc(), "T", by = "name"),
    error = TRUE
  )
  expect_snapshot(
    grist_records_upsert(data.frame(id = 1L, a = 1), test_doc(), "T", by = "a"),
    error = TRUE
  )
})

test_that("grist_records_upsert() splits large writes into chunks", {
  local_grist_env()
  mock <- local_grist_mock(json_resp(""), json_resp(""), json_resp(""))
  grist_records_upsert(
    data.frame(k = 1:5, v = 1:5),
    test_doc(),
    "People",
    by = "k",
    convert = "basic",
    options = grist_write_options(chunk_size = 2)
  )
  expect_length(mock$reqs, 3)
})

test_that("grist_records() keeps untyped columns of an empty table", {
  local_grist_env()
  local_grist_mock(
    json_resp(
      '{"columns":[{"id":"A","fields":{"type":"Any"}},{"id":"B","fields":{"type":"Text"}}]}'
    ),
    json_resp('{"records":[]}'),
    json_resp('{"records":[]}')
  )

  out <- grist_records(test_doc(), "T")
  expect_named(out, c("id", "A", "B"))
  expect_equal(nrow(out), 0)

  out <- grist_records(test_doc(), "T", convert = "basic")
  expect_equal(nrow(out), 0)
})

test_that("write options `parse = FALSE` sends noparse", {
  local_grist_env()
  mock <- local_grist_mock(
    json_resp('{"records":[{"id":1}]}'),
    json_resp('{"records":[{"id":1}]}'),
    json_resp("{}"),
    json_resp("{}")
  )
  opts <- grist_write_options(parse = FALSE)
  data <- data.frame(name = "Ann")

  grist_records_add(data, test_doc(), "People", convert = "basic")
  grist_records_add(data, test_doc(), "People", convert = "basic", options = opts)
  grist_records_update(
    data.frame(id = 1L, name = "Ann"),
    test_doc(),
    "People",
    convert = "basic",
    options = opts
  )
  grist_records_upsert(
    data,
    test_doc(),
    "People",
    by = "name",
    convert = "basic",
    options = opts
  )

  noparse <- function(i) httr2::url_parse(mock$reqs[[i]]$url)$query$noparse
  expect_null(noparse(1))
  expect_equal(noparse(2), "true")
  expect_equal(noparse(3), "true")
  expect_equal(noparse(4), "true")
})

test_that("convert = 'raw' sends missing values as null", {
  local_grist_env()
  mock <- local_grist_mock(json_resp('{"records":[{"id":1},{"id":2}]}'))

  grist_records_add(
    data.frame(age = c(1, NA)),
    test_doc(),
    "People",
    convert = "raw"
  )

  expect_equal(
    req_body_sent(mock$reqs[[1]]),
    '{"records":[{"fields":{"age":1}},{"fields":{"age":null}}]}'
  )
})
