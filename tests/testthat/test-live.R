test_that("document lifecycle works against a live server", {
  skip_if_no_grist()
  doc <- local_scratch_doc()

  expect_equal(grist_doc_info(doc)$name, "gristmillr-test-scratch")

  grist_doc_update(doc, name = "gristmillr-test-renamed", pinned = TRUE)
  info <- grist_doc_info(doc)
  expect_equal(info$name, "gristmillr-test-renamed")
  expect_true(info$is_pinned)

  grist_doc_delete(doc, ask = FALSE)
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

test_that("grist_records_upsert() updates, adds and skips by key", {
  skip_if_no_grist()
  doc <- local_scratch_doc()
  grist_table_create(
    doc,
    "People",
    c(email = "Text", age = "Int", joined = "Date")
  )
  grist_records_add(
    doc,
    "People",
    data.frame(
      email = c("a@x", "b@x"),
      age = c(1L, 2L),
      joined = as.Date(c("2020-01-01", "2020-02-01"))
    )
  )

  grist_records_upsert(
    doc,
    "People",
    data.frame(email = c("b@x", "c@x"), age = c(20L, 30L)),
    by = "email"
  )
  out <- grist_records(doc, "People")
  expect_equal(out$email, c("a@x", "b@x", "c@x"))
  expect_equal(out$age, c(1L, 20L, 30L))
  expect_equal(out$joined[[2]], as.Date("2020-02-01"))

  # A Date key matches the stored value.
  grist_records_upsert(
    doc,
    "People",
    data.frame(joined = as.Date("2020-01-01"), age = 11L),
    by = "joined"
  )
  expect_equal(grist_records(doc, "People")$age, c(11L, 20L, 30L))

  grist_records_upsert(
    doc,
    "People",
    data.frame(email = c("a@x", "d@x"), age = c(99L, 99L)),
    by = "email",
    mode = "update"
  )
  out <- grist_records(doc, "People")
  expect_equal(out$email, c("a@x", "b@x", "c@x"))
  expect_equal(out$age, c(99L, 20L, 30L))

  grist_records_upsert(
    doc,
    "People",
    data.frame(email = c("a@x", "e@x"), age = c(0L, 5L)),
    by = "email",
    mode = "insert"
  )
  out <- grist_records(doc, "People")
  expect_equal(out$email, c("a@x", "b@x", "c@x", "e@x"))
  expect_equal(out$age, c(99L, 20L, 30L, 5L))

  grist_records_add(doc, "People", data.frame(email = "b@x", age = 21L))
  grist_records_upsert(
    doc,
    "People",
    data.frame(email = "b@x", age = 7L),
    by = "email",
    onmany = "all"
  )
  expect_equal(
    grist_records(doc, "People", filter = list(email = "b@x"))$age,
    c(7L, 7L)
  )
})

test_that("grist_doc_import() creates documents from files", {
  skip_if_no_grist()
  workspace <- grist_workspaces()$id[[1]]
  dir <- withr::local_tempdir()

  csv <- file.path(dir, "pets.csv")
  writeLines(c("name,age,adopted", "Rex,3,2020-01-02", "Tom,5,2021-05-06"), csv)
  doc <- grist_doc_import(csv, workspace, name = "gristmillr import test")
  withr::defer(grist_doc_delete(doc, mode = "permanent", ask = FALSE))

  expect_s3_class(doc, "gristmillr::grist_doc")
  expect_equal(grist_doc_info(doc)$name, "gristmillr import test")
  expect_equal(grist_tables(doc)$id, "Pets")
  out <- grist_records(doc, "Pets")
  expect_equal(out$name, c("Rex", "Tom"))
  expect_equal(out$adopted, as.Date(c("2020-01-02", "2021-05-06")))

  json <- file.path(dir, "things.json")
  writeLines('[{"a":1,"b":"x"},{"a":2,"b":"y"}]', json)
  doc2 <- grist_doc_import(json, workspace)
  withr::defer(grist_doc_delete(doc2, mode = "permanent", ask = FALSE))
  expect_equal(grist_records(doc2, "Things")$b, c("x", "y"))
})
