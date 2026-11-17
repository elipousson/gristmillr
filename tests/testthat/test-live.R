test_that("document lifecycle works against a live server", {
  skip_if_no_grist()
  doc <- local_scratch_doc()

  expect_equal(grist_doc_info(doc)$name, "gristmillr-test-scratch")

  grist_doc_update(doc, name = "gristmillr-test-renamed", pinned = TRUE)
  info <- grist_doc_info(doc)
  expect_equal(info$name, "gristmillr-test-renamed")
  expect_true(info$is_pinned)

  grist_doc_delete(doc, confirm = TRUE)
  grist_doc_restore(doc)
  expect_equal(grist_doc_info(doc)$id, doc@doc_id)
})

test_that("records round-trip through a live server", {
  skip_if_no_grist()
  doc <- local_scratch_doc()

  grist_table_create(
    doc,
    "People",
    c(
      name = "Text",
      age = "Int",
      born = "Date",
      seen = "DateTime:America/New_York",
      tags = "ChoiceList"
    )
  )
  expect_true("People" %in% grist_tables(doc)$id)
  expect_equal(
    grist_columns(doc, "People")$type[[4]],
    "DateTime:America/New_York"
  )

  data <- data.frame(
    name = c("Ann", "Bob"),
    age = c(30L, NA),
    born = as.Date(c("1990-01-01", NA))
  )
  data$seen <- as.POSIXct(c("2023-11-14 22:13:20", NA), tz = "UTC")
  data$tags <- list(c("a", "b"), NULL)

  ids <- grist_records_add(doc, "People", data)
  expect_length(ids, 2)

  out <- grist_records(doc, "People")
  expect_equal(out$id, ids)
  expect_equal(out$name, data$name)
  expect_identical(out$age, data$age)
  expect_equal(out$born, data$born)
  expect_equal(as.numeric(out$seen), as.numeric(data$seen))
  expect_equal(out$tags, list(c("a", "b"), character()))

  expect_equal(
    grist_records(doc, "People", filter = list(name = "Bob"))$id,
    ids[[2]]
  )
  expect_equal(
    grist_records(doc, "People", sort = "-name", limit = 1)$name,
    "Bob"
  )

  grist_records_update(doc, "People", data.frame(id = ids[[1]], age = 31L))
  expect_equal(
    grist_sql(doc, "select age from People where name = ?", args = "Ann")$age,
    31L
  )
  expect_equal(grist_count(doc, "People"), 2L)

  grist_records_delete(doc, "People", ids[[2]])
  expect_equal(grist_count(doc, "People"), 1L)
})

test_that("large writes are chunked against a live server", {
  skip_if_no_grist()
  doc <- local_scratch_doc()
  grist_table_create(doc, "Rows", c(x = "Int"))

  ids <- grist_records_add(
    doc,
    "Rows",
    data.frame(x = 1:5),
    options = grist_write_options(chunk_size = 2)
  )
  expect_length(ids, 5)
  expect_equal(grist_records(doc, "Rows")$x, 1:5)
})

test_that("unknown columns are caught before writing", {
  skip_if_no_grist()
  doc <- local_scratch_doc()
  grist_table_create(doc, "Rows", c(x = "Int"))
  expect_error(
    grist_records_add(doc, "Rows", data.frame(nope = 1)),
    class = "gristmillr_unknown_cols"
  )
})

test_that("HTTP errors carry Grist's message", {
  skip_if_no_grist()
  doc <- local_scratch_doc()
  expect_error(grist_records(doc, "Missing"), class = "gristmillr_http_error")
})
