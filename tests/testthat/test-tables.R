test_that("grist_tables() lists tables", {
  local_grist_env()
  local_grist_mock(json_resp(
    '{"tables":[{"id":"People","fields":{"tableRef":1,"onDemand":false}},{"id":"Places","fields":{"tableRef":2,"onDemand":true}}]}'
  ))

  out <- grist_tables(test_doc())

  expect_equal(out$id, c("People", "Places"))
  expect_equal(out$table_ref, 1:2)
  expect_equal(out$on_demand, c(FALSE, TRUE))
})

test_that("grist_tables() handles an empty document", {
  local_grist_env()
  local_grist_mock(json_resp('{"tables":[]}'))
  out <- grist_tables(test_doc())
  expect_equal(nrow(out), 0)
  expect_named(out, c("id", "table_ref", "on_demand"))
})

test_that("grist_table_create() posts the table definition", {
  local_grist_env()
  mock <- local_grist_mock(json_resp('{"tables":[{"id":"Pets"}]}'))

  id <- grist_table_create(test_doc(), "Pets", c(name = "Text"))

  expect_equal(id, "Pets")
  expect_equal(
    as.character(req_body(mock$reqs[[1]])),
    '{"tables":[{"id":"Pets","columns":[{"id":"name","fields":{"type":"Text"}}]}]}'
  )
})
