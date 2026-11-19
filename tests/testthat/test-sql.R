sql_json <- '{"statement":"select","records":[{"fields":{"id":1,"pet":"cat"}},{"fields":{"id":2,"pet":null}}]}'

test_that("grist_sql() posts the query and returns a data frame", {
  local_grist_env()
  mock <- local_grist_mock(json_resp(sql_json))

  out <- grist_sql(
    test_doc(),
    "select * from Pets where popularity > ?",
    args = 50,
    timeout = 500
  )

  expect_equal(out$id, 1:2)
  expect_equal(out$pet, c("cat", NA))
  expect_match(mock$reqs[[1]]$url, "/docs/abc123/sql$")
  expect_equal(
    as.character(req_body(mock$reqs[[1]])),
    '{"sql":"select * from Pets where popularity > ?","args":[50],"timeout":500}'
  )
})

test_that("grist_sql() can return raw cells", {
  local_grist_env()
  local_grist_mock(json_resp(sql_json))
  out <- grist_sql(test_doc(), "select 1", convert = "raw")
  expect_equal(out$pet, list("cat", NULL))
})

test_that("grist_sql() handles empty results", {
  local_grist_env()
  local_grist_mock(json_resp('{"statement":"x","records":[]}'))
  expect_equal(nrow(grist_sql(test_doc(), "select 1")), 0)
})

test_that("grist_count() counts rows and quotes the table name", {
  local_grist_env()
  mock <- local_grist_mock(json_resp(
    '{"statement":"x","records":[{"fields":{"n":42}}]}'
  ))

  expect_identical(grist_count(test_doc(), 'We"ird'), 42L)
  expect_match(
    as.character(req_body(mock$reqs[[1]])),
    'FROM \\\\"We\\\\"\\\\"ird\\\\"'
  )
})

test_that("named args are sent as a JSON array", {
  local_grist_env()
  mock <- local_grist_mock(json_resp('{"records":[]}'))

  grist_sql(test_doc(), "select ?, ?", args = c(a = 1, b = 2))
  grist_sql(test_doc(), "select ?", args = list(x = "y"))

  expect_equal(
    req_body_sent(mock$reqs[[1]]),
    '{"sql":"select ?, ?","args":[1,2]}'
  )
  expect_equal(
    req_body_sent(mock$reqs[[2]]),
    '{"sql":"select ?","args":["y"]}'
  )
})
