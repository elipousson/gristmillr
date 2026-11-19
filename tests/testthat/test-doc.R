test_that("grist_doc() accepts a bare ID", {
  withr::local_envvar(GRIST_SERVER = NA)
  doc <- grist_doc("abc123")
  expect_equal(doc@doc_id, "abc123")
  expect_equal(doc@server, "https://docs.getgrist.com")
})

test_that("grist_doc() uses GRIST_SERVER", {
  withr::local_envvar(GRIST_SERVER = "https://team.getgrist.com/")
  expect_equal(grist_doc("abc123")@server, "https://team.getgrist.com")
})

test_that("grist_doc() parses document URLs", {
  doc <- grist_doc("https://docs.getgrist.com/doc/am2iHJ9Amvo7Ve3EE5emtu")
  expect_equal(doc@doc_id, "am2iHJ9Amvo7Ve3EE5emtu")
  expect_equal(doc@server, "https://docs.getgrist.com")

  doc <- grist_doc("http://localhost:47478/o/docs/api/docs/abc123/tables")
  expect_equal(doc@doc_id, "abc123")
  expect_equal(doc@server, "http://localhost:47478/o/docs")

  doc <- grist_doc("https://team.getgrist.com/am2iHJ9Amvo7Ve3EE5emtu/My-Doc")
  expect_equal(doc@doc_id, "am2iHJ9Amvo7Ve3EE5emtu")
})

test_that("an explicit server overrides the URL", {
  doc <- grist_doc(
    "https://docs.getgrist.com/doc/abc",
    server = "http://x.test"
  )
  expect_equal(doc@server, "http://x.test")
})

test_that("server URLs are normalized", {
  expect_equal(
    grist_doc("a", server = "http://x.test/api/")@server,
    "http://x.test"
  )
})

test_that("grist_doc() returns existing handles unchanged", {
  doc <- test_doc()
  expect_identical(grist_doc(doc), doc)
})

test_that("grist_doc() warns about arguments ignored for existing handles", {
  doc <- grist_doc("abc", server = "https://a.getgrist.com")

  expect_snapshot(out <- grist_doc(doc, server = "https://b.getgrist.com"))
  expect_identical(out, doc)
  expect_warning(
    grist_doc(doc, api_key = "x", options = grist_request_options()),
    class = "gristmillr_warning_doc_args"
  )
  expect_no_warning(grist_doc(doc))
})

test_that("grist_doc() validates its input", {
  expect_snapshot(grist_doc("https://example.com/nothing"), error = TRUE)
  expect_snapshot(grist_doc(1), error = TRUE)
  expect_snapshot(grist_doc("a b"), error = TRUE)
  expect_snapshot(grist_doc("abc", server = "example.com"), error = TRUE)
})

test_that("grist_doc() has a print method", {
  expect_snapshot(print(test_doc()))
})
