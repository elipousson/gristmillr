list_json <- paste0(
  '{"records":[',
  '{"id":1,"fields":{"fileName":"a.txt","fileSize":12,"timeUploaded":"2020-02-13T12:17:19.000Z"}},',
  '{"id":2,"fields":{"fileName":"b.png","fileSize":3456,"timeUploaded":"2021-03-01T00:00:00.000Z"}}',
  "]}"
)
info_json <- '{"fileName":"a.txt","fileSize":12,"timeUploaded":"2020-02-13T12:17:19.000Z"}'

test_that("grist_attachments() lists metadata", {
  local_grist_env()
  mock <- local_grist_mock(json_resp(list_json))

  out <- grist_attachments(
    test_doc(),
    filter = list(fileName = "a.txt"),
    limit = 5
  )

  expect_equal(out$id, 1:2)
  expect_equal(out$file_name, c("a.txt", "b.png"))
  expect_equal(out$file_size, c(12, 3456))
  expect_s3_class(out$time_uploaded, "POSIXct")
  expect_equal(
    format(out$time_uploaded[[1]], "%Y-%m-%d %H:%M:%S"),
    "2020-02-13 12:17:19"
  )
  url <- httr2::url_parse(mock$reqs[[1]]$url)
  expect_equal(url$path, "/api/docs/abc123/attachments")
  expect_equal(url$query$filter, '{"fileName":["a.txt"]}')
  expect_equal(url$query$limit, "5")
})

test_that("grist_attachments() handles no attachments", {
  local_grist_env()
  local_grist_mock(json_resp('{"records":[]}'))
  out <- grist_attachments(test_doc())
  expect_equal(nrow(out), 0)
  expect_named(out, c("id", "file_name", "file_size", "time_uploaded"))
})

test_that("grist_attachment_info() returns one row", {
  local_grist_env()
  mock <- local_grist_mock(json_resp(info_json))

  out <- grist_attachment_info(test_doc(), 7)

  expect_equal(out$id, 7L)
  expect_equal(out$file_name, "a.txt")
  expect_match(mock$reqs[[1]]$url, "/attachments/7$")
})

test_that("grist_attachments_upload() posts each file as multipart", {
  local_grist_env()
  mock <- local_grist_mock(json_resp("[10]"), json_resp("[11]"))
  files <- c(
    withr::local_tempfile(fileext = ".txt"),
    withr::local_tempfile(fileext = ".txt")
  )
  writeLines("one", files[[1]])
  writeLines("two", files[[2]])

  ids <- grist_attachments_upload(test_doc(), files)

  expect_equal(ids, c(10L, 11L))
  expect_length(mock$reqs, 2)
  expect_equal(mock$reqs[[1]]$body$type, "multipart")
  expect_named(mock$reqs[[1]]$body$data, "upload")
  expect_match(mock$reqs[[1]]$url, "/attachments$")
})

test_that("grist_attachments_upload() checks that files exist", {
  local_grist_env()
  mock <- local_grist_mock(json_resp("[1]"))
  expect_snapshot(
    grist_attachments_upload(test_doc(), c("missing-1.txt", "missing-2.txt")),
    error = TRUE
  )
  expect_snapshot(
    grist_attachments_upload(test_doc(), tempdir()),
    error = TRUE,
    transform = function(x) gsub(tempdir(), "<tmp>", x, fixed = TRUE)
  )
  expect_length(mock$reqs, 0)
})

test_that("grist_attachment_download() writes to a file path", {
  local_grist_env()
  mock <- local_grist_mock(httr2::response(body = charToRaw("hello")))
  path <- withr::local_tempfile(fileext = ".txt")

  out <- grist_attachment_download(test_doc(), 3, path)

  expect_equal(out, path)
  expect_equal(readLines(path, warn = FALSE), "hello")
  expect_match(mock$reqs[[1]]$url, "/attachments/3/download$")
})

test_that("a directory path uses the attachment's file name", {
  local_grist_env()
  mock <- local_grist_mock(
    json_resp(
      '{"fileName":"../../evil.txt","fileSize":5,"timeUploaded":"2020-01-01T00:00:00.000Z"}'
    ),
    httr2::response(body = charToRaw("hello"))
  )
  dir <- withr::local_tempdir()

  out <- grist_attachment_download(test_doc(), 3, dir)

  expect_equal(out, file.path(dir, "evil.txt"))
  expect_true(file.exists(file.path(dir, "evil.txt")))
  expect_length(mock$reqs, 2)
})

test_that("existing files are protected unless overwrite = TRUE", {
  local_grist_env()
  mock <- local_grist_mock(httr2::response(body = charToRaw("new")))
  path <- withr::local_tempfile()
  writeLines("old", path)

  expect_error(
    grist_attachment_download(test_doc(), 3, path),
    class = "gristmillr_file_exists"
  )
  expect_length(mock$reqs, 0)

  grist_attachment_download(test_doc(), 3, path, overwrite = TRUE)
  expect_equal(readLines(path, warn = FALSE), "new")
})

test_that("attachments round-trip against a live server", {
  skip_if_no_grist()
  doc <- local_scratch_doc()
  grist_table_create(doc, "Reports", c(title = "Text", files = "Attachments"))

  file <- withr::local_tempfile(fileext = ".txt")
  writeLines("hello attachments", file)

  ids <- grist_attachments_upload(doc, file)
  expect_length(ids, 1)

  listed <- grist_attachments(doc)
  expect_equal(listed$id, ids)
  expect_equal(listed$file_name, basename(file))
  expect_equal(grist_attachment_info(doc, ids)$file_size, file.size(file))

  rid <- grist_records_add(
    data.frame(title = "Q1", files = I(list(ids))),
    doc,
    "Reports"
  )
  report <- grist_records(doc, "Reports")
  expect_equal(report$files, list(ids))

  dir <- withr::local_tempdir()
  out <- grist_attachment_download(doc, report$files[[1]][[1]], dir)
  expect_equal(basename(out), basename(file))
  expect_equal(readLines(out), "hello attachments")
})
