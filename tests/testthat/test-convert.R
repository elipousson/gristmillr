cells <- function(...) list(...)

test_that("simplify_column() builds vectors from scalar cells", {
  expect_equal(simplify_column(cells(1L, NULL, 3L)), c(1L, NA, 3L))
  expect_equal(simplify_column(cells("a", "b")), c("a", "b"))
  expect_equal(simplify_column(cells(NULL, NULL)), c(NA, NA))
})

test_that("simplify_column() keeps mixed types as a list", {
  expect_equal(simplify_column(cells(1L, "a")), cells(1L, "a"))
})

test_that("simplify_column() turns tagged lists into list-columns", {
  out <- simplify_column(cells(list("L", "a", "b"), NULL, list("L", "c")))
  expect_equal(out, list(c("a", "b"), NULL, "c"))
})

test_that("convert_column() converts by type", {
  expect_equal(convert_column(cells("a", NULL), "Text")$value, c("a", NA))
  expect_equal(convert_column(cells("a"), "Choice")$value, "a")
  expect_identical(convert_column(cells(1, 2), "Int")$value, 1:2)
  expect_identical(
    convert_column(cells(1.5, NULL), "Numeric")$value,
    c(1.5, NA)
  )
  expect_identical(
    convert_column(cells(TRUE, FALSE), "Bool")$value,
    c(TRUE, FALSE)
  )
})

test_that("Int columns fall back to double for non-whole numbers", {
  expect_identical(convert_column(cells(1.5, 2), "Int")$value, c(1.5, 2))
})

test_that("convert_column() converts dates and date-times", {
  expect_equal(
    convert_column(cells(631152000, NULL), "Date")$value,
    as.Date(c("1990-01-01", NA))
  )

  dt <- convert_column(cells(1700000000), "DateTime:America/New_York")$value
  expect_s3_class(dt, "POSIXct")
  expect_equal(attr(dt, "tzone"), "America/New_York")
  expect_equal(format(dt, "%H:%M"), "17:13")

  dt <- convert_column(
    cells(1700000000),
    "DateTime:America/New_York",
    tz = "UTC"
  )$value
  expect_equal(format(dt, "%H:%M"), "22:13")

  expect_equal(
    attr(convert_column(cells(0), "DateTime")$value, "tzone"),
    "UTC"
  )
})

test_that("Ref columns become integers with 0 as NA", {
  expect_identical(convert_column(cells(0, 5), "Ref:People")$value, c(NA, 5L))
})

test_that("list types become typed list-columns", {
  out <- convert_column(
    cells(list("L", "a", "b"), NULL),
    "ChoiceList"
  )$value
  expect_equal(out, list(c("a", "b"), character()))

  out <- convert_column(cells(list("L", 1, 2), NULL), "RefList:People")$value
  expect_equal(out, list(1:2, integer()))
})

test_that("cells that don't match the type fall back with ok = FALSE", {
  res <- convert_column(cells(1, "oops"), "Numeric")
  expect_false(res$ok)
  expect_equal(res$value, cells(1, "oops"))

  res <- convert_column(cells(list("E", "#ERR")), "ChoiceList")
  expect_false(res$ok)
})

test_that("unknown and Any types are simplified", {
  expect_equal(convert_column(cells(1, 2), "Any")$value, c(1, 2))
  expect_equal(convert_column(cells(1, 2), NULL)$value, c(1, 2))
})

test_that("records_to_df() builds a data frame with metadata", {
  records <- jsonlite::fromJSON(records_json, simplifyVector = FALSE)$records
  columns <- columns_to_df(
    jsonlite::fromJSON(columns_json, simplifyVector = FALSE)$columns
  )

  out <- records_to_df(records, columns)
  expect_s3_class(out, "tbl_df")
  expect_named(out, c("id", "name", "age", "born", "seen", "tags", "boss"))
  expect_identical(out$id, 1:2)
  expect_identical(out$age, c(30L, NA))
  expect_s3_class(out$born, "Date")
  expect_equal(out$tags, list(c("a", "b"), character()))
  expect_identical(out$boss, c(NA, 1L))

  labelled <- records_to_df(
    records,
    columns,
    read_options = grist_read_options(col_names = "label")
  )
  expect_named(labelled, c("id", "Name", "Age", "Born", "Seen", "Tags", "Boss"))
})

test_that("records_to_df() warns once about unconvertible columns", {
  records <- list(list(id = 1L, fields = list(a = "x", b = 1)))
  columns <- new_tbl(
    list(id = c("a", "b"), label = c("a", "b"), type = c("Numeric", "Int")),
    n = 2
  )
  expect_snapshot(out <- records_to_df(records, columns))
  expect_equal(out$a, "x")
  expect_identical(out$b, 1L)
})

test_that("records_to_df() returns typed empty columns for no records", {
  columns <- new_tbl(
    list(id = "a", label = "a", type = "Int"),
    n = 1
  )
  out <- records_to_df(list(), columns)
  expect_equal(nrow(out), 0)
  expect_named(out, c("id", "a"))
})

test_that("raw conversion keeps list-columns", {
  records <- list(
    list(id = 1L, fields = list(a = 1)),
    list(id = 2L, fields = list(a = NULL))
  )
  out <- records_to_df(records, convert = "raw")
  expect_equal(out$a, list(1, NULL))
})

test_that("to_cells() converts R classes for Grist", {
  expect_equal(to_cells(as.Date("1990-01-01")), list(631152000))
  expect_equal(to_cells(as.POSIXct(1700000000, tz = "UTC")), list(1700000000))
  expect_equal(to_cells(factor("a")), list("a"))
  expect_equal(to_cells(c(1L, NA)), list(1L, NULL))
  expect_equal(
    to_cells(list(c("a", "b"), NULL)),
    list(list("L", "a", "b"), NULL)
  )
})

test_that("df_to_records() builds the JSON payload", {
  data <- data.frame(id = 1:2, x = c("a", NA))
  data$tags <- list(c("p", "q"), NULL)

  rec <- df_to_records(data, with_id = TRUE)
  expect_equal(rec[[1]]$id, 1L)
  expect_equal(rec[[1]]$fields$x, "a")
  expect_null(rec[[2]]$fields$x)
  expect_named(rec[[2]]$fields, c("x", "tags"))

  json <- jsonlite::toJSON(
    list(records = rec[2]),
    auto_unbox = TRUE,
    null = "null"
  )
  expect_equal(
    as.character(json),
    '{"records":[{"id":2,"fields":{"x":null,"tags":null}}]}'
  )

  expect_named(df_to_records(data[c("x")], with_id = FALSE)[[1]], "fields")
})

test_that("unknown columns are rejected or dropped", {
  columns <- new_tbl(list(id = "a"), n = 1)
  data <- data.frame(a = 1, b = 2)

  expect_snapshot(
    check_record_columns(data, columns, grist_write_options()),
    error = TRUE
  )
  expect_named(
    check_record_columns(
      data,
      columns,
      grist_write_options(unknown_cols = "drop")
    ),
    "a"
  )
})
