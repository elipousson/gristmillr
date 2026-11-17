test_that("grist_columns() returns one row per column", {
  local_grist_env()
  mock <- local_grist_mock(json_resp(columns_json))

  out <- grist_columns(test_doc(), "People")

  expect_equal(out$id, c("name", "age", "born", "seen", "tags", "boss"))
  expect_equal(out$type[[4]], "DateTime:America/New_York")
  expect_equal(out$label[[1]], "Name")
  expect_equal(out$is_formula[[1]], FALSE)
  expect_true(is.na(out$formula[[1]]))
  expect_equal(
    mock$reqs[[1]]$url,
    "https://example.getgrist.com/api/docs/abc123/tables/People/columns"
  )
})

test_that("grist_columns() can include hidden columns", {
  local_grist_env()
  mock <- local_grist_mock(json_resp('{"columns":[]}'))
  out <- grist_columns(test_doc(), "People", hidden = TRUE)
  expect_equal(nrow(out), 0)
  expect_match(mock$reqs[[1]]$url, "hidden=true$")
})

test_that("columns_spec() accepts IDs, named types and data frames", {
  expect_equal(columns_spec("a")[[1]]$id, "a")
  expect_equal(
    columns_spec(c(a = "Int"))[[1]],
    list(id = "a", fields = list(type = "Int"))
  )

  spec <- columns_spec(data.frame(
    id = c("a", "b"),
    type = c("Int", NA),
    is_formula = c(NA, TRUE),
    formula = c(NA, "$a + 1")
  ))
  expect_equal(spec[[1]]$fields, list(type = "Int"))
  expect_equal(spec[[2]]$fields, list(isFormula = TRUE, formula = "$a + 1"))
})

test_that("columns_spec() serializes empty fields as an object", {
  json <- jsonlite::toJSON(columns_spec("a"), auto_unbox = TRUE)
  expect_equal(as.character(json), '[{"id":"a","fields":{}}]')
})

test_that("columns_spec() validates input", {
  expect_snapshot(columns_spec(1), error = TRUE)
  expect_snapshot(columns_spec(data.frame(x = 1)), error = TRUE)
  expect_snapshot(columns_spec(data.frame(id = "a", nope = 1)), error = TRUE)
})

test_that("grist_columns_add() posts column definitions", {
  local_grist_env()
  mock <- local_grist_mock(json_resp('{"columns":[{"id":"a"},{"id":"b"}]}'))

  ids <- grist_columns_add(test_doc(), "People", c(a = "Text", b = "Int"))

  expect_equal(ids, c("a", "b"))
  expect_equal(
    as.character(req_body(mock$reqs[[1]])),
    '{"columns":[{"id":"a","fields":{"type":"Text"}},{"id":"b","fields":{"type":"Int"}}]}'
  )
})

test_that("grist_columns_modify() patches columns", {
  local_grist_env()
  mock <- local_grist_mock(json_resp(""))
  doc <- test_doc()

  out <- grist_columns_modify(
    doc,
    "People",
    data.frame(id = "a", col_id = "z", label = "Z")
  )

  expect_identical(out, doc)
  expect_equal(httr2::req_get_method(mock$reqs[[1]]), "PATCH")
  expect_equal(
    as.character(req_body(mock$reqs[[1]])),
    '{"columns":[{"id":"a","fields":{"colId":"z","label":"Z"}}]}'
  )
  expect_snapshot(
    grist_columns_modify(doc, "People", c(a = "Int")),
    error = TRUE
  )
})
