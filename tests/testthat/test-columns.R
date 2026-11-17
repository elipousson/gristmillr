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

test_that("grist_columns() returns descriptions, with NA for none", {
  local_grist_env()
  local_grist_mock(json_resp(
    '{"columns":[{"id":"a","fields":{"description":"Primary key"}},{"id":"b","fields":{"description":""}},{"id":"c","fields":{}}]}'
  ))

  out <- grist_columns(test_doc(), "People")

  expect_equal(out$description, c("Primary key", NA, NA))
  expect_equal(names(out)[1:3], c("id", "label", "description"))
})

test_that("columns_spec() sends descriptions, including empty ones", {
  spec <- columns_spec(data.frame(
    id = c("a", "b", "c"),
    description = c("Note", "", NA)
  ))
  expect_equal(spec[[1]]$fields, list(description = "Note"))
  expect_equal(spec[[2]]$fields, list(description = ""))
  expect_equal(unname(spec[[3]]$fields), list())
})

test_that("grist_columns_modify() can set and clear descriptions", {
  local_grist_env()
  mock <- local_grist_mock(json_resp(""))

  grist_columns_modify(
    test_doc(),
    "People",
    data.frame(id = c("a", "b"), description = c("New note", ""))
  )

  expect_equal(
    as.character(req_body(mock$reqs[[1]])),
    '{"columns":[{"id":"a","fields":{"description":"New note"}},{"id":"b","fields":{"description":""}}]}'
  )
})

test_that("grist_columns_add() sets descriptions in a second request", {
  local_grist_env()
  mock <- local_grist_mock(
    json_resp('{"columns":[{"id":"a"},{"id":"b"},{"id":"c"}]}'),
    json_resp("")
  )

  ids <- grist_columns_add(
    test_doc(),
    "People",
    data.frame(
      id = c("a", "b", "c"),
      type = "Text",
      description = c("Note A", NA, "Note C")
    )
  )

  expect_equal(ids, c("a", "b", "c"))
  expect_length(mock$reqs, 2)
  expect_equal(httr2::req_get_method(mock$reqs[[1]]), "POST")
  expect_equal(httr2::req_get_method(mock$reqs[[2]]), "PATCH")
  expect_equal(
    as.character(req_body(mock$reqs[[2]])),
    '{"columns":[{"id":"a","fields":{"description":"Note A"}},{"id":"c","fields":{"description":"Note C"}}]}'
  )
})

test_that("grist_columns_add() makes one request without descriptions", {
  local_grist_env()
  mock <- local_grist_mock(json_resp('{"columns":[{"id":"a"}]}'))

  grist_columns_add(
    test_doc(),
    "People",
    data.frame(id = "a", description = NA_character_)
  )
  grist_columns_add(test_doc(), "People", c(b = "Int"))

  expect_length(mock$reqs, 2)
})

test_that("column descriptions round-trip against a live server", {
  skip_if_no_grist()
  doc <- local_scratch_doc()

  grist_table_create(
    doc,
    "People",
    data.frame(id = "name", type = "Text", description = "Full name")
  )
  expect_equal(grist_columns(doc, "People")$description, "Full name")

  grist_columns_add(
    doc,
    "People",
    data.frame(
      id = c("age", "email"),
      type = c("Int", "Text"),
      description = c("In years", NA)
    )
  )
  cols <- grist_columns(doc, "People")
  expect_equal(
    cols$description[match(c("name", "age", "email"), cols$id)],
    c("Full name", "In years", NA)
  )

  grist_columns_modify(
    doc,
    "People",
    data.frame(id = c("age", "name"), description = c("Age in years", ""))
  )
  cols <- grist_columns(doc, "People")
  expect_equal(
    cols$description[match(c("name", "age"), cols$id)],
    c(NA, "Age in years")
  )
})
