test_that("dict_type() maps Grist types to data-dict types", {
  expect_equal(dict_type("Text")$type, "string")
  expect_equal(dict_type("Int")$type, "number")
  expect_equal(dict_type("Numeric")$type, "number")
  expect_equal(dict_type("Bool")$type, "boolean")
  expect_equal(dict_type("Date")$type, "date")
  expect_equal(
    dict_type("DateTime:Europe/Paris"),
    list(type = "datetime", time_zone = "Europe/Paris")
  )
  expect_equal(
    dict_type("Choice", c("a", "b")),
    list(type = "enum", values = c("a", "b"))
  )
  expect_equal(dict_type("Choice")$type, "string")
  expect_equal(dict_type("ChoiceList", "a")$type, "list(enum)")
  expect_equal(
    dict_type("Ref:People"),
    list(type = "number(id)", ref = "People")
  )
  expect_equal(dict_type("RefList:People")$type, "list(number(id))")
  expect_equal(dict_type("Attachments")$type, "list(number(id))")
  expect_null(dict_type("Any")$type)
})

test_that("column_choices() reads widget options", {
  expect_equal(column_choices('{"choices":["a","b"]}'), c("a", "b"))
  expect_equal(column_choices(""), character())
  expect_equal(column_choices(NA_character_), character())
  expect_equal(column_choices("not json"), character())
})

test_that("sample_values() spreads values evenly", {
  expect_equal(sample_values(c(3, 1, 2)), c(1, 2, 3))
  expect_equal(sample_values(1:100), c(1, 26, 50, 75, 100))
  expect_equal(sample_values(c(NA, 2, 2)), 2)
})

test_that("dict_values() describes values by type", {
  num <- list(type = "number")
  expect_equal(dict_values(c(5, 1), num, "sample"), list(examples = list(1, 5)))
  expect_equal(
    dict_values(
      as.Date(c("2020-02-01", "2020-01-01")),
      list(type = "date"),
      "sample"
    ),
    list(range = list("2020-01-01", "2020-02-01"))
  )
  expect_equal(
    dict_values(
      as.POSIXct("2024-01-01 12:00:00", tz = "UTC"),
      list(type = "datetime", time_zone = "America/New_York"),
      "sample"
    )$range[[1]],
    "2024-01-01T07:00:00"
  )
  expect_equal(
    dict_values("a", list(type = "enum", values = c("a", "b")), "sample"),
    list(values = list("a", "b"))
  )
  expect_equal(dict_values(TRUE, list(type = "boolean"), "sample"), list())
  expect_equal(
    dict_values(list(c("a", "b"), "c"), list(type = "list(string)"), "sample"),
    list(examples = list("a", "b", "c"))
  )
})

test_that("dict_values() leaves a todo when there is nothing to sample", {
  expect_equal(
    dict_values(character(), list(type = "string"), "sample"),
    list(
      examples = list(),
      todo = "No values to sample. Add representative values."
    )
  )
  expect_equal(
    dict_values("", list(type = "string"), "sample")$examples,
    list()
  )
  expect_equal(
    dict_values(as.Date(character()), list(type = "date"), "sample")$range,
    list(-Inf, Inf)
  )
  out <- dict_values(1:3, list(type = "number"), "none")
  expect_equal(out$examples, list())
  expect_equal(out$todo, "Add representative values.")
})

test_that("write_data_dict() writes open ranges as .inf", {
  skip_if_not_installed("yaml12")
  path <- withr::local_tempfile(fileext = ".yaml")
  write_data_dict(list(range = list(-Inf, Inf), x = "inf"), path)
  lines <- readLines(path)
  expect_true("  - -.inf" %in% lines)
  expect_true("  - .inf" %in% lines)
  expect_equal(yaml12::read_yaml(path)$range, c(-Inf, Inf))
})

test_that("parse_join() reads simple joins", {
  expect_equal(
    parse_join("orders.person_id = people.id"),
    list(
      left = list(table = "orders", column = "person_id"),
      right = list(table = "people", column = "id")
    )
  )
  expect_null(parse_join("a.x >= b.y AND a.x <= b.z"))
})

test_that("map_references() maps keys to row IDs", {
  lookup <- c("a" = 10L, "b" = 20L)
  expect_equal(
    map_references(c("b", NA, "a", "zz"), lookup),
    c(20L, 0L, 10L, 0L)
  )
  expect_equal(
    map_references(list(c("a", "b"), character(), c("zz", "a")), lookup),
    list(c(10L, 20L), integer(), 10L)
  )
})

test_that("import_column_type() chooses Grist types", {
  type <- function(col, x = NULL) import_column_type(col, x)$type
  expect_equal(type(list(type = "string")), "Text")
  expect_equal(type(list(type = "number"), 1L), "Int")
  expect_equal(type(list(type = "number"), 1.5), "Numeric")
  expect_equal(type(list(type = "number(id)"), 1L), "Int")
  expect_equal(type(list(type = "boolean")), "Bool")
  expect_equal(type(list(type = "date")), "Date")
  expect_equal(
    type(list(type = "datetime", time_zone = "Europe/Paris")),
    "DateTime:Europe/Paris"
  )
  expect_equal(
    type(list(type = "datetime", time_zone = "naive")),
    "DateTime:UTC"
  )
  expect_equal(type(list(name = "x")), "Any")
  expect_equal(type(list(type = "list(string)")), "ChoiceList")
  expect_equal(type(list(type = "string", grist_type = "Ref:T")), "Ref:T")
  expect_null(import_column_type(list(type = "list(number(id))"), NULL))
  expect_null(import_column_type(list(type = "struct"), NULL))

  enum <- import_column_type(list(type = "enum", values = list("a", "b")), NULL)
  expect_equal(enum$type, "Choice")
  expect_equal(enum$widget_options, '{"choices":["a","b"]}')
  mapped <- import_column_type(
    list(type = "enum", values = list(M = "Male", F = "Female")),
    NULL
  )
  expect_equal(mapped$widget_options, '{"choices":["M","F"]}')
})

test_that("grist_import() validates its arguments", {
  doc <- test_doc()
  expect_snapshot(grist_import(doc, "x", types = c("a")), error = TRUE)
  expect_snapshot(grist_import(doc, "x", types = c(a = "Int")), error = TRUE)
  expect_snapshot(grist_import(doc, "x", display = 1), error = TRUE)
  expect_snapshot(grist_import(doc, "x", orphans = "drop"), error = TRUE)
})

test_that("grist_import() needs a dictionary", {
  skip_if_not_installed("yaml12")
  skip_if_not_installed("nanoparquet")
  local_grist_env()
  dir <- withr::local_tempdir()
  expect_error(grist_import(test_doc(), dir), "Can't find a data dictionary")
  writeLines("name: x", file.path(dir, "data-dict.yaml"))
  expect_error(grist_import(test_doc(), dir), "no .*tables")
})

test_that("grist_export() validates its arguments", {
  skip_if_not_installed("yaml12")
  skip_if_not_installed("nanoparquet")
  doc <- test_doc()
  expect_snapshot(grist_export(doc, to = 1), error = TRUE)
  expect_snapshot(grist_export(doc, examples = "all"), error = TRUE)
})

# Live ----------------------------------------------------------------------

skip_if_no_migration <- function() {
  skip_if_no_grist()
  skip_if_not_installed("yaml12")
  skip_if_not_installed("nanoparquet")
}

test_that("export and import round trip through a live server", {
  skip_if_no_migration()
  src <- local_scratch_doc()
  dst <- local_scratch_doc()
  out <- withr::local_tempdir()

  grist_table_create(
    src,
    "People",
    data.frame(
      id = c("name", "age", "joined", "active", "seen", "status", "tags"),
      type = c(
        "Text",
        "Int",
        "Date",
        "Bool",
        "DateTime:America/New_York",
        "Choice",
        "ChoiceList"
      ),
      description = c("Full name", NA, NA, NA, NA, NA, NA),
      widget_options = c(
        NA,
        NA,
        NA,
        NA,
        NA,
        '{"choices":["on","off"]}',
        '{"choices":["a","b"]}'
      )
    )
  )
  grist_table_create(
    src,
    "Orders",
    c(item = "Text", person = "Ref:People", buddies = "RefList:People")
  )
  grist_records_add(
    src,
    "People",
    data.frame(
      name = c("Ann", "Bob"),
      age = c(31L, 45L),
      joined = as.Date(c("2020-01-02", "2021-05-06")),
      active = c(TRUE, FALSE),
      seen = as.POSIXct(
        c("2024-01-01 10:00:00", "2024-02-01 11:30:00"),
        tz = "America/New_York"
      ),
      status = c("on", "off"),
      tags = I(list(c("a", "b"), "a"))
    )
  )
  grist_records_add(
    src,
    "Orders",
    data.frame(
      item = c("pen", "ink"),
      person = c(2L, 1L),
      buddies = I(list(1:2, 2L))
    )
  )

  exported <- grist_export(src, out, tables = c("People", "Orders"))
  expect_equal(exported$table, c("People", "Orders"))
  expect_equal(exported$rows, c(2L, 2L))
  expect_true(all(file.exists(exported$path)))
  expect_error(
    grist_export(src, out, tables = "People"),
    class = "gristmillr_file_exists"
  )

  dict <- yaml12::read_yaml(file.path(out, "data-dict.yaml"))
  expect_equal(dict$tables[[1]]$name, "People")
  expect_equal(dict$relationships[[1]]$join, "Orders.person = People.id")

  imported <- grist_import(
    dst,
    out,
    types = c("Orders.buddies" = "RefList:People"),
    display = c("Orders.person" = "name")
  )
  expect_equal(imported$table, c("People", "Orders"))

  expect_equal(
    as.data.frame(grist_records(dst, "People")),
    as.data.frame(grist_records(src, "People"))
  )
  expect_equal(
    grist_columns(dst, "People")$description[[1]],
    "Full name"
  )
  expect_equal(
    grist_columns(dst, "Orders")$type,
    c("Text", "Ref:People", "RefList:People")
  )
  orders <- grist_records(dst, "Orders")
  expect_equal(orders$person, c(2L, 1L))
  expect_equal(orders$buddies, list(1:2, 2L))
  expect_equal(
    grist_resolve_refs(
      orders,
      dst,
      "Orders",
      columns = "person"
    )$person_display,
    c("Bob", "Ann")
  )
})

test_that("grist_import() links tables by their own keys", {
  skip_if_no_migration()
  doc <- local_scratch_doc()
  dir <- withr::local_tempdir()

  nanoparquet::write_parquet(
    data.frame(
      emp_id = c("e1", "e2", "e3"),
      name = c("Ann", "Bob", "Cy"),
      manager_id = c(NA, "e1", "e1")
    ),
    file.path(dir, "employees.parquet")
  )
  nanoparquet::write_parquet(
    data.frame(
      task_id = 1:2,
      emp_id = c("e3", "e2"),
      score = c(1.5, 2)
    ),
    file.path(dir, "tasks.parquet")
  )
  # A table with only references has no other columns to load.
  nanoparquet::write_parquet(
    data.frame(emp_id = c("e1", "e2"), task_id = c(2L, 1L)),
    file.path(dir, "links.parquet")
  )
  writeLines(
    c(
      "$version: 0.1.0",
      "tables:",
      "  - name: employees",
      "    source: {parquet: employees.parquet}",
      "    columns:",
      "      - {name: emp_id, type: string, constraints: [primary_key], examples: [e1]}",
      "      - {name: name, type: string, examples: [Ann]}",
      "      - {name: manager_id, type: string, constraints: [foreign_key], examples: [e1]}",
      "  - name: tasks",
      "    source: {parquet: tasks.parquet}",
      "    columns:",
      "      - {name: task_id, type: number(id), constraints: [primary_key], examples: [1]}",
      "      - {name: emp_id, type: string, constraints: [foreign_key], examples: [e1]}",
      "      - {name: score, type: number, examples: [1.5]}",
      "  - name: links",
      "    source: {parquet: links.parquet}",
      "    columns:",
      "      - {name: emp_id, type: string, constraints: [foreign_key], examples: [e1]}",
      "      - {name: task_id, type: number(id), constraints: [foreign_key], examples: [1]}",
      "relationships:",
      "  - {join: employees.manager_id = employees.emp_id, cardinality: many-to-one}",
      "  - {join: tasks.emp_id = employees.emp_id, cardinality: many-to-one}",
      "  - {join: links.emp_id = employees.emp_id, cardinality: many-to-one}",
      "  - {join: links.task_id = tasks.task_id, cardinality: many-to-one}"
    ),
    file.path(dir, "data-dict.yaml")
  )

  grist_import(doc, dir)

  employees <- grist_records(doc, "Employees")
  expect_equal(employees$emp_id, c("e1", "e2", "e3"))
  expect_equal(employees$manager_id, c(NA, 1L, 1L))
  tasks <- grist_records(doc, "Tasks")
  expect_equal(tasks$emp_id, c(3L, 2L))
  expect_equal(tasks$score, c(1.5, 2))
  expect_equal(
    grist_columns(doc, "Tasks")$type,
    c("Int", "Ref:Employees", "Numeric")
  )
  links <- grist_records(doc, "Links")
  expect_equal(links$emp_id, 1:2)
  expect_equal(links$task_id, c(2L, 1L))
})

test_that("grist_import() checks before changing anything", {
  skip_if_no_migration()
  doc <- local_scratch_doc()
  dir <- withr::local_tempdir()
  nanoparquet::write_parquet(
    data.frame(k = 1:2, name = c("a", "b")),
    file.path(dir, "parents.parquet")
  )
  nanoparquet::write_parquet(
    data.frame(parent = c(1L, 9L)),
    file.path(dir, "kids.parquet")
  )
  writeLines(
    c(
      "$version: 0.1.0",
      "tables:",
      "  - name: parents",
      "    source: {parquet: parents.parquet}",
      "    columns:",
      "      - {name: k, type: number(id), constraints: [primary_key], examples: [1]}",
      "      - {name: name, type: string, examples: [a]}",
      "  - name: kids",
      "    source: {parquet: kids.parquet}",
      "    columns:",
      "      - {name: parent, type: number(id), constraints: [foreign_key], examples: [1]}",
      "relationships:",
      "  - {join: kids.parent = parents.k, cardinality: many-to-one}"
    ),
    file.path(dir, "data-dict.yaml")
  )
  tables_before <- grist_tables(doc)$id

  expect_snapshot(grist_import(doc, dir), error = TRUE)
  expect_equal(grist_tables(doc)$id, tables_before)

  grist_import(doc, dir, orphans = "empty")
  expect_equal(grist_records(doc, "Kids")$parent, c(1L, NA))

  expect_snapshot(grist_import(doc, dir, orphans = "empty"), error = TRUE)
  expect_snapshot(
    grist_import(doc, dir, types = c("kids.nope" = "Int")),
    error = TRUE
  )
  grist_import(doc, dir, tables = "parents", if_exists = "append")
  expect_equal(nrow(grist_records(doc, "Parents")), 4)
})

# Text formats --------------------------------------------------------------

test_that("coerce_column() applies dictionary types to text", {
  expect_equal(coerce_column(c("1", NA, "3"), "number"), c(1L, NA, 3L))
  expect_equal(coerce_column(c("1.5", "2"), "number"), c(1.5, 2))
  expect_equal(coerce_column(c("1", "3000000000"), "number(id)"), c(1, 3e9))
  expect_equal(
    coerce_column(c("TRUE", "false", NA), "boolean"),
    c(TRUE, FALSE, NA)
  )
  expect_equal(coerce_column(c(TRUE, NA), "boolean"), c(TRUE, NA))
  expect_equal(
    coerce_column(c("2020-01-02", NA), "date"),
    as.Date(c("2020-01-02", NA))
  )
  expect_equal(
    coerce_column("2024-03-10T06:30:00Z", "datetime"),
    as.POSIXct("2024-03-10 06:30:00", tz = "UTC")
  )
  expect_equal(coerce_column(c("a", NA), "string"), c("a", ""))
  expect_equal(coerce_column(c(NA, "on"), "enum"), c("", "on"))
  expect_equal(
    coerce_column(c('["a","b"]', "[]", NA), "list(enum)"),
    list(c("a", "b"), character(), character())
  )
  expect_equal(
    coerce_column(list(c(1, 2), NULL, 3), "list(number(id))"),
    list(1:2, integer(), 3L)
  )
  expect_equal(coerce_column(c("x", "y"), NULL), c("x", "y"))
})

test_that("table files round trip through every format", {
  skip_if_not_installed("nanoparquet")
  data <- data.frame(
    id = 1:3,
    name = c('He said "hi", twice\nnewline é', "", "plain"),
    zip = c("02134", "99", "00000"),
    n = c(1L, NA, 3L),
    x = c(1.25, 2, NA),
    ok = c(TRUE, FALSE, NA),
    d = as.Date(c("2020-01-02", NA, "2021-05-06")),
    seen = as.POSIXct(
      c("2024-03-10 01:30:00", NA, "2024-11-03 01:30:00"),
      tz = "UTC"
    )
  )
  data$tags <- list(c("a", "b"), "a", character())
  columns <- list(
    id = list(type = "number(id)"),
    name = list(type = "string"),
    zip = list(type = "string"),
    n = list(type = "number"),
    x = list(type = "number"),
    ok = list(type = "boolean"),
    d = list(type = "date"),
    seen = list(type = "datetime"),
    tags = list(type = "list(enum)")
  )

  for (format in c("parquet", "csv", "json")) {
    path <- withr::local_tempfile(fileext = paste0(".", format))
    write_table_file(data, path, format)
    out <- read_table_file(path, format, columns)
    expect_equal(out$name, data$name, info = format)
    expect_equal(out$zip, data$zip, info = format)
    expect_equal(out$n, data$n, info = format)
    expect_equal(out$ok, data$ok, info = format)
    expect_equal(out$d, data$d, info = format)
    expect_equal(out$seen, data$seen, info = format)
    expect_equal(out$tags, data$tags, info = format)
  }
})

test_that("an empty JSON file gives an empty table", {
  path <- withr::local_tempfile(fileext = ".json")
  writeLines("[]", path)
  out <- read_table_file(
    path,
    "json",
    list(a = list(type = "number"), b = list(type = "string"))
  )
  expect_equal(nrow(out), 0)
  expect_named(out, c("a", "b"))
})

test_that("find_table_file() uses the source, then file names", {
  dir <- withr::local_tempdir()
  spec <- list(name = "Things", source = "things.parquet")
  expect_null(find_table_file(spec, dir, "auto"))

  file.create(file.path(dir, "Things.json"))
  expect_equal(find_table_file(spec, dir, "auto")$format, "json")
  expect_null(find_table_file(spec, dir, "csv"))

  file.create(file.path(dir, "Things.csv"))
  expect_equal(find_table_file(spec, dir, "auto")$format, "csv")
  expect_equal(find_table_file(spec, dir, "json")$format, "json")

  file.create(file.path(dir, "things.parquet"))
  expect_equal(find_table_file(spec, dir, "auto")$format, "parquet")
  expect_equal(find_table_file(spec, dir, "csv")$format, "csv")
})

test_that("grist_export() and grist_import() validate format", {
  doc <- test_doc()
  expect_snapshot(grist_export(doc, format = "xlsx"), error = TRUE)
  expect_snapshot(grist_import(doc, "x", format = "xlsx"), error = TRUE)
})

test_that("export and import round trip in CSV and JSON", {
  skip_if_no_migration()
  src <- local_scratch_doc()
  grist_table_create(
    src,
    "Things",
    data.frame(
      id = c(
        "name",
        "zip",
        "n",
        "x",
        "ok",
        "d",
        "seen",
        "status",
        "tags",
        "buddy"
      ),
      type = c(
        "Text",
        "Text",
        "Int",
        "Numeric",
        "Bool",
        "Date",
        "DateTime:America/New_York",
        "Choice",
        "ChoiceList",
        "Ref:Things"
      ),
      widget_options = c(
        NA,
        NA,
        NA,
        NA,
        NA,
        NA,
        NA,
        '{"choices":["on","off"]}',
        '{"choices":["a","b"]}',
        NA
      )
    )
  )
  grist_records_add(
    src,
    "Things",
    data.frame(
      name = c('He said "hi", twice\nnewline é', "", "plain"),
      zip = c("02134", "99", ""),
      n = c(1L, NA, 3L),
      x = c(1.25, 2, NA),
      ok = c(TRUE, FALSE, TRUE),
      d = as.Date(c("2020-01-02", NA, "2021-05-06")),
      seen = as.POSIXct(
        c("2024-03-10 01:30:00", NA, "2024-11-03 01:30:00"),
        tz = "America/New_York"
      ),
      status = c("on", "", "off"),
      tags = I(list(c("a", "b"), "a", character())),
      buddy = c(2L, 3L, 1L)
    )
  )

  for (format in c("csv", "json")) {
    out <- withr::local_tempdir()
    exported <- grist_export(src, out, tables = "Things", format = format)
    expect_equal(basename(exported$path), paste0("Things.", format))
    dict <- yaml12::read_yaml(file.path(out, "data-dict.yaml"))
    expect_null(dict$tables[[1]]$source)

    dst <- local_scratch_doc()
    grist_import(dst, out)
    expect_equal(
      as.data.frame(grist_records(dst, "Things")),
      as.data.frame(grist_records(src, "Things")),
      info = format
    )
    expect_equal(
      grist_columns(dst, "Things")$type,
      grist_columns(src, "Things")$type,
      info = format
    )
  }
})

test_that("grist_import() reads CSV files for a dictionary without sources", {
  skip_if_no_migration()
  doc <- local_scratch_doc()
  dir <- withr::local_tempdir()
  utils::write.csv(
    data.frame(
      emp_id = c("e1", "e2"),
      name = c("Ann", "Bob"),
      manager = c("", "e1")
    ),
    file.path(dir, "employees.csv"),
    row.names = FALSE,
    na = ""
  )
  writeLines(
    c(
      "$version: 0.1.0",
      "tables:",
      "  - name: employees",
      "    columns:",
      "      - {name: emp_id, type: string, constraints: [primary_key], examples: [e1]}",
      "      - {name: name, type: string, examples: [Ann]}",
      "      - {name: manager, type: string, constraints: [foreign_key], examples: [e1]}",
      "relationships:",
      "  - {join: employees.manager = employees.emp_id, cardinality: many-to-one}"
    ),
    file.path(dir, "data-dict.yaml")
  )

  grist_import(doc, dir)

  out <- grist_records(doc, "Employees")
  expect_equal(out$name, c("Ann", "Bob"))
  expect_equal(out$manager, c(NA, 1L))
})
