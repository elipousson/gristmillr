test_that("grist_request() builds an authenticated request", {
  local_grist_env()
  req <- grist_request(test_doc(), "tables", "People", "records")

  expect_equal(
    req$url,
    "https://example.getgrist.com/api/docs/abc123/tables/People/records"
  )
  expect_equal(
    httr2::req_get_headers(req, redacted = "reveal")$Authorization,
    "Bearer test-key"
  )
  expect_match(req$options$useragent, "^gristmillr/")
})

test_that("grist_request() accepts a document ID", {
  local_grist_env()
  req <- grist_request("abc123")
  expect_equal(req$url, "https://docs.getgrist.com/api/docs/abc123")
})

test_that("a missing API key is an informative error", {
  withr::local_envvar(GRIST_API_KEY = NA)
  expect_snapshot(grist_request(test_doc()), error = TRUE)
  expect_error(grist_request(test_doc()), class = "gristmillr_no_api_key")
})

test_that("request options are applied", {
  local_grist_env()
  doc <- grist_doc(
    "abc",
    options = grist_request_options(timeout = 5, user_agent = "me")
  )
  req <- grist_request(doc)
  expect_equal(req$options$timeout_ms, 5000)
  expect_equal(req$options$useragent, "me")
})

test_that("HTTP errors include Grist's message and a gristmillr class", {
  local_grist_env()
  local_grist_mock(
    json_resp('{"error":"Table not found: \\"Nope\\""}', status = 404L)
  )

  expect_error(
    grist_tables(test_doc()),
    class = "gristmillr_http_error"
  )
  expect_snapshot(grist_tables(test_doc()), error = TRUE)
})
