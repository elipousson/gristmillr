file_resp <- function(body = "a,b\n1,2\n", type = "text/csv") {
  httr2::response(
    headers = list("Content-Type" = type),
    body = if (is.character(body)) charToRaw(body) else body
  )
}

test_that("grist_doc_download() writes a csv file", {
  local_grist_env()
  mock <- local_grist_mock(file_resp())
  path <- withr::local_tempfile(fileext = ".csv")

  out <- grist_doc_download(
    test_doc(),
    path,
    format = "csv",
    table = "People",
    col_names = "label"
  )

  expect_equal(out, path)
  expect_equal(readLines(path), c("a,b", "1,2"))
  url <- httr2::url_parse(mock$reqs[[1]]$url)
  expect_equal(url$path, "/api/docs/abc123/download/csv")
  expect_equal(url$query$tableId, "People")
  expect_equal(url$query$header, "label")
})

test_that("grist_doc_download() defaults to the grist format", {
  local_grist_env()
  mock <- local_grist_mock(file_resp(as.raw(1:5), "application/x-sqlite3"))
  path <- withr::local_tempfile(fileext = ".grist")

  grist_doc_download(test_doc(), path, no_history = TRUE, template = TRUE)

  expect_equal(readBin(path, "raw", 10), as.raw(1:5))
  url <- httr2::url_parse(mock$reqs[[1]]$url)
  expect_equal(url$path, "/api/docs/abc123/download")
  expect_equal(url$query$nohistory, "true")
  expect_equal(url$query$template, "true")
  expect_null(url$query$header)
})

test_that("xlsx downloads allow an optional table", {
  local_grist_env()
  mock <- local_grist_mock(file_resp(as.raw(1:3), "application/octet-stream"))
  path <- withr::local_tempfile(fileext = ".xlsx")

  grist_doc_download(test_doc(), path, format = "xlsx")
  url <- httr2::url_parse(mock$reqs[[1]]$url)
  expect_equal(url$path, "/api/docs/abc123/download/xlsx")
  expect_null(url$query$tableId)
  expect_equal(url$query$header, "colId")
})

test_that("argument combinations are validated", {
  local_grist_env()
  mock <- local_grist_mock(file_resp())
  path <- withr::local_tempfile()
  doc <- test_doc()

  expect_snapshot(grist_doc_download(doc, path, format = "csv"), error = TRUE)
  expect_snapshot(grist_doc_download(doc, path, table = "People"), error = TRUE)
  expect_snapshot(
    grist_doc_download(doc, path, format = "xlsx", template = TRUE),
    error = TRUE
  )
  expect_snapshot(grist_doc_download(doc, path, format = "pdf"), error = TRUE)
  expect_length(mock$reqs, 0)
})

test_that("existing files are only replaced with overwrite = TRUE", {
  local_grist_env()
  mock <- local_grist_mock(file_resp("new"))
  path <- withr::local_tempfile()
  writeLines("old", path)

  expect_snapshot(
    grist_doc_download(test_doc(), path, format = "xlsx"),
    error = TRUE,
    transform = function(x) gsub(path, "<path>", x, fixed = TRUE)
  )
  expect_error(
    grist_doc_download(test_doc(), path, format = "xlsx"),
    class = "gristmillr_file_exists"
  )
  expect_equal(readLines(path), "old")
  expect_length(mock$reqs, 0)

  grist_doc_download(test_doc(), path, format = "xlsx", overwrite = TRUE)
  expect_equal(readLines(path, warn = FALSE), "new")
})

test_that("a failed download leaves no file", {
  local_grist_env()
  local_grist_mock(json_resp('{"error":"Not found"}', status = 404L))
  path <- withr::local_tempfile()

  expect_error(
    grist_doc_download(test_doc(), path, format = "csv", table = "Nope"),
    class = "gristmillr_http_error"
  )
  expect_false(file.exists(path))
})

test_that("grist_table_schema() returns the parsed schema", {
  local_grist_env()
  mock <- local_grist_mock(json_resp(
    '{"name":"people","schema":{"fields":[{"name":"name","type":"string"}]}}'
  ))

  out <- grist_table_schema(test_doc(), "People", col_names = "label")

  expect_equal(out$name, "people")
  expect_equal(out$schema$fields[[1]]$type, "string")
  url <- httr2::url_parse(mock$reqs[[1]]$url)
  expect_equal(url$path, "/api/docs/abc123/download/table-schema")
  expect_equal(url$query$header, "label")
})

test_that("downloads work against a live server", {
  skip_if_no_grist()
  doc <- local_scratch_doc()
  grist_table_create(doc, "People", c(name = "Text", age = "Int"))
  grist_records_add(doc, "People", data.frame(name = "Ann", age = 30L))

  path <- withr::local_tempfile(fileext = ".csv")
  grist_doc_download(doc, path, format = "csv", table = "People")
  csv <- utils::read.csv(path)
  expect_equal(csv$name, "Ann")

  grist_doc_download(
    doc,
    path,
    format = "csv",
    table = "People",
    col_names = "label",
    overwrite = TRUE
  )
  expect_equal(names(utils::read.csv(path)), c("name", "age"))

  path <- withr::local_tempfile(fileext = ".grist")
  grist_doc_download(doc, path)
  expect_equal(rawToChar(readBin(path, "raw", 15)), "SQLite format 3")

  path <- withr::local_tempfile(fileext = ".xlsx")
  grist_doc_download(doc, path, format = "xlsx")
  expect_equal(rawToChar(readBin(path, "raw", 2)), "PK")

  schema <- grist_table_schema(doc, "People")
  expect_equal(
    vapply(schema$schema$fields, function(x) x$name, ""),
    c("name", "age")
  )
})
