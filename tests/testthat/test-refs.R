orders_columns <- paste0(
  '{"columns":[',
  '{"id":"item","fields":{"label":"Item","type":"Text"}},',
  '{"id":"person","fields":{"label":"Person","type":"Ref:People","visibleCol":2}},',
  '{"id":"team","fields":{"label":"Team","type":"RefList:People","visibleCol":2}},',
  '{"id":"orphan","fields":{"label":"Orphan","type":"Ref:People","visibleCol":0}}',
  "]}"
)
people_columns <- paste0(
  '{"columns":[',
  '{"id":"name","fields":{"label":"Name","type":"Text","colRef":2}},',
  '{"id":"age","fields":{"label":"Age","type":"Int","colRef":3}}',
  "]}"
)
people_records <- paste0(
  '{"records":[',
  '{"id":1,"fields":{"name":"Ann","age":30}},',
  '{"id":2,"fields":{"name":"Bob","age":40}}',
  "]}"
)

mock_refs <- function(.env = parent.frame()) {
  local_grist_mock(
    function(req) {
      url <- req$url
      body <- if (grepl("Orders/columns", url)) {
        orders_columns
      } else if (grepl("People/columns", url)) {
        people_columns
      } else if (grepl("People/records", url)) {
        people_records
      } else {
        stop("Unexpected request: ", url)
      }
      json_resp(body)
    },
    .env = .env
  )
}

orders <- function() {
  out <- new_tbl(
    list(
      id = 1:4,
      item = c("pen", "ink", "pad", "cap"),
      person = c(1L, 1L, 2L, NA),
      team = list(1:2, integer(), 2L, NULL)
    ),
    n = 4L
  )
  out
}

test_that("grist_resolve_refs() adds display columns next to the IDs", {
  local_grist_env()
  mock_refs()

  out <- grist_resolve_refs(orders(), test_doc(), "Orders", columns = "person")

  expect_named(out, c("id", "item", "person", "person_display", "team"))
  expect_equal(out$person_display, c("Ann", "Ann", "Bob", NA))
  expect_equal(out$person, c(1L, 1L, 2L, NA))
})

test_that("grist_resolve_refs() resolves RefList columns to list-columns", {
  local_grist_env()
  mock_refs()

  out <- grist_resolve_refs(orders(), test_doc(), "Orders", columns = "team")

  expect_equal(
    out$team_display,
    list(c("Ann", "Bob"), character(), "Bob", character())
  )
})

test_that("how = 'replace' swaps values in place", {
  local_grist_env()
  mock_refs()

  out <- grist_resolve_refs(
    orders(),
    test_doc(),
    "Orders",
    columns = "person",
    how = "replace"
  )

  expect_named(out, c("id", "item", "person", "team"))
  expect_equal(out$person, c("Ann", "Ann", "Bob", NA))
})

test_that("the suffix is configurable", {
  local_grist_env()
  mock_refs()
  out <- grist_resolve_refs(
    orders(),
    test_doc(),
    "Orders",
    columns = "person",
    suffix = "_name"
  )
  expect_true("person_name" %in% names(out))
})

test_that("referenced tables are fetched once", {
  local_grist_env()
  mock <- mock_refs()

  data <- orders()
  data$orphan <- NA_integer_
  suppressWarnings(
    grist_resolve_refs(
      data,
      test_doc(),
      "Orders",
      columns = c("person", "team")
    )
  )

  urls <- vapply(mock$reqs, function(x) x$url, "")
  expect_equal(sum(grepl("People/records", urls)), 1)
})

test_that("all reference columns present in data are resolved by default", {
  local_grist_env()
  mock_refs()
  data <- orders()
  data$orphan <- 1L

  expect_warning(
    out <- grist_resolve_refs(data, test_doc(), "Orders"),
    class = "gristmillr_warning_refs"
  )
  expect_true(all(c("person_display", "team_display") %in% names(out)))
  expect_false("orphan_display" %in% names(out))
})

test_that("columns without a display column warn and are left alone", {
  local_grist_env()
  mock_refs()
  data <- orders()
  data$orphan <- 1L

  expect_snapshot(
    out <- grist_resolve_refs(data, test_doc(), "Orders", columns = "orphan")
  )
  expect_identical(out, data)
})

test_that("labelled column names are matched", {
  local_grist_env()
  mock_refs()
  data <- orders()
  names(data)[names(data) == "person"] <- "Person"

  out <- grist_resolve_refs(data, test_doc(), "Orders", columns = "person")
  expect_equal(out$Person_display, c("Ann", "Ann", "Bob", NA))
})

test_that("grist_resolve_refs() validates its input", {
  local_grist_env()
  mock_refs()
  expect_snapshot(
    grist_resolve_refs(orders(), test_doc(), "Orders", columns = "item"),
    error = TRUE
  )
  expect_snapshot(
    grist_resolve_refs(
      orders()[c("id", "item")],
      test_doc(),
      "Orders",
      columns = "person"
    ),
    error = TRUE
  )
  expect_snapshot(
    grist_resolve_refs(list(), test_doc(), "Orders"),
    error = TRUE
  )
})

test_that("references resolve against a live server", {
  skip_if_no_grist()
  doc <- local_scratch_doc()

  grist_table_create(doc, "People", c(name = "Text"))
  grist_table_create(doc, "Orders", c(item = "Text", person = "Ref:People"))
  people <- grist_records_add(doc, "People", data.frame(name = c("Ann", "Bob")))
  grist_records_add(
    doc,
    "Orders",
    data.frame(item = c("pen", "cap"), person = c(people[[2]], NA))
  )

  # Point the reference at the `name` column, as the Grist interface does.
  name_ref <- grist_columns(doc, "People")$col_ref[[1]]
  grist_columns_modify(
    doc,
    "Orders",
    data.frame(id = "person", visible_col = name_ref)
  )

  out <- grist_records(doc, "Orders") |>
    grist_resolve_refs(doc, "Orders")
  expect_equal(out$person_display, c("Bob", NA))
})
