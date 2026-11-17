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

test_that("api_key in grist_doc() is used for requests", {
  withr::local_envvar(GRIST_API_KEY = "from-env")
  doc <- grist_doc("abc123", api_key = "from-arg")
  expect_equal(
    httr2::req_get_headers(
      grist_request(doc, "tables"),
      "reveal"
    )$Authorization,
    "Bearer from-arg"
  )
})

test_that("api_key in grist_request_options() is used and beats the env var", {
  withr::local_envvar(GRIST_API_KEY = "from-env")
  opts <- grist_request_options(api_key = "from-options")
  doc <- grist_doc("abc123", options = opts)
  expect_equal(
    httr2::req_get_headers(grist_request(doc), "reveal")$Authorization,
    "Bearer from-options"
  )
  doc2 <- grist_doc("abc123", options = opts, api_key = "explicit")
  expect_equal(
    httr2::req_get_headers(grist_request(doc2), "reveal")$Authorization,
    "Bearer explicit"
  )
  expect_equal(doc2@options@timeout, opts@timeout)
})

test_that("api_key can be a function evaluated per request", {
  withr::local_envvar(GRIST_API_KEY = NA)
  n <- 0
  doc <- grist_doc("abc123", api_key = function() {
    n <<- n + 1
    paste0("key", n)
  })
  auth <- \() httr2::req_get_headers(grist_request(doc), "reveal")$Authorization
  expect_equal(auth(), "Bearer key1")
  expect_equal(auth(), "Bearer key2")
})

test_that("string keys are not serialised with the object", {
  withr::local_envvar(GRIST_API_KEY = NA)
  doc <- grist_doc("abc123", api_key = "super-secret-key")

  bytes <- serialize(doc, NULL)
  expect_false(grepl(
    "super-secret-key",
    rawToChar(bytes[bytes > 0 & bytes < 128])
  ))

  # Simulate a new session by dropping the registry entry.
  rm(list = ls(key_registry), envir = key_registry)
  expect_snapshot(grist_request(doc), error = TRUE)
  expect_error(grist_request(doc), class = "gristmillr_no_api_key")
})

test_that("function keys survive serialisation", {
  withr::local_envvar(GRIST_API_KEY = NA, MY_KEY = "abc")
  doc <- grist_doc("abc123", api_key = function() Sys.getenv("MY_KEY"))
  doc2 <- unserialize(serialize(doc, NULL))
  expect_equal(
    httr2::req_get_headers(grist_request(doc2), "reveal")$Authorization,
    "Bearer abc"
  )
})

test_that("api_key is validated", {
  expect_snapshot(grist_doc("abc123", api_key = 1), error = TRUE)
  doc <- grist_doc("abc123", api_key = function() 1)
  expect_snapshot(grist_request(doc), error = TRUE)
})

test_that("printing options never shows the key", {
  opts <- grist_request_options(api_key = "super-secret-key")
  out <- cli::cli_fmt(print(opts))
  expect_false(any(grepl("super-secret-key", out)))
  expect_match(paste(out, collapse = "\n"), "REDACTED")
})
