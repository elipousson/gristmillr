test_that("option constructors have sensible defaults", {
  expect_equal(grist_request_options()@timeout, 30)
  expect_equal(grist_read_options()@col_names, "id")
  expect_equal(grist_write_options()@unknown_cols, "error")
  expect_true(grist_write_options()@parse)
})

test_that("option enums are validated", {
  expect_snapshot(grist_read_options(col_names = "name"), error = TRUE)
  expect_snapshot(grist_write_options(unknown_cols = "ignore"), error = TRUE)
})

test_that("option values are validated", {
  expect_snapshot(grist_request_options(timeout = -1), error = TRUE)
  expect_snapshot(grist_write_options(chunk_size = 0), error = TRUE)
  expect_snapshot(grist_read_options(hidden = NA), error = TRUE)
  expect_snapshot(grist_write_options(parse = NA), error = TRUE)
})

test_that("package-wide defaults are used when `options` is NULL", {
  withr::local_options(
    gristmillr.read_options = grist_read_options(col_names = "label")
  )
  expect_equal(as_read_options(NULL)@col_names, "label")
  expect_equal(
    as_read_options(grist_read_options(col_names = "id"))@col_names,
    "id"
  )
})

test_that("options of the wrong class are rejected", {
  expect_snapshot(as_read_options(grist_write_options()), error = TRUE)
})
