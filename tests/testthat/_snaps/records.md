# typed cell format requires raw conversion

    Code
      grist_records(test_doc(), "People", options = options)
    Condition
      Error in `grist_records()`:
      ! `cell_format = "typed"` requires `convert = "raw"`.
      i Typed cells are self-describing, so no conversion is applied.

# grist_records() validates its arguments

    Code
      grist_records(doc, "People", filter = c(a = 1))
    Condition
      Error in `grist_records()`:
      ! `filter` must be a named list of vectors.
      i For example: `list(status = c("open", "new"))`.

---

    Code
      grist_records(doc, "People", filter = list(1))
    Condition
      Error in `grist_records()`:
      ! `filter` must be a named list of vectors.
      i For example: `list(status = c("open", "new"))`.

---

    Code
      grist_records(doc, "People", convert = "typed")
    Condition
      Error in `grist_records()`:
      ! `convert` must be one of "auto", "basic", or "raw", not "typed".

---

    Code
      grist_records(doc, "People", limit = -1)
    Condition
      Error in `grist_records()`:
      ! `limit` must be a whole number larger than or equal to 0 or `NULL`, not the number -1.

# grist_records_add() with convert = 'auto' checks column names

    Code
      grist_records_add(data.frame(name = "x", nope = 1), test_doc(), "People")
    Condition
      Error in `grist_records_add()`:
      ! `data` has 1 column not in the Grist table.
      x Unknown column: nope.
      i Use `grist_write_options(unknown_cols = "drop")` to ignore unknown columns.

# grist_records_add() rejects an id column

    Code
      grist_records_add(data.frame(id = 1, x = 1), test_doc(), "People")
    Condition
      Error in `grist_records_add()`:
      ! `data` can't have an id column when adding records.
      i Use `grist_records_update()` to change existing rows.

---

    Code
      grist_records_add(list(x = 1), test_doc(), "People")
    Condition
      Error in `grist_records_add()`:
      ! `data` must be a data frame, not a list.

# grist_records_update() only supports the unmatched value Grist can

    Code
      grist_records_update(data, test_doc(), "People", unmatched = "ignore")
    Condition
      Error in `grist_records_update()`:
      ! Can't use `unmatched = "ignore"` when `by = "id"`.
      i Grist errors when a row ID doesn't exist.
      i Set `by` to a key column to skip rows with no match.

---

    Code
      grist_records_update(data[-1], test_doc(), "People", by = "name")
    Condition
      Error in `grist_records_update()`:
      ! Can't use `unmatched = "error"` when `by` is not "id".
      i Grist skips rows with no match, and doesn't say which.
      i Use `unmatched = "ignore"`.

---

    Code
      grist_records_update(data, test_doc(), "People", by = c("id", "name"))
    Condition
      Error in `grist_records_update()`:
      ! `by` can't combine "id" with other columns.
      i Use `by = "id"` on its own to match row IDs.

# grist_records_update() requires an id column

    Code
      grist_records_update(data.frame(x = 1), test_doc(), "People")
    Condition
      Error in `grist_records_update()`:
      ! `data` must have an id column to update records.

# grist_records_delete() validates ids

    Code
      grist_records_delete("a", test_doc(), "People")
    Condition
      Error in `grist_records_delete()`:
      ! `data` must be whole numbers without missing values.
      i Got a string.

---

    Code
      grist_records_delete(data.frame(x = 1), test_doc(), "People")
    Condition
      Error in `grist_records_delete()`:
      ! `data` must have an id column.

# grist_records_update() validates and converts ids

    Code
      grist_records_update(data.frame(id = c(1, 1.5), age = 3:4), test_doc(),
      "People", convert = "basic")
    Condition
      Error in `grist_records_update()`:
      ! `data$id` must be whole numbers without missing values.
      i Got a double vector.

# grist_records_upsert() validates by and data

    Code
      grist_records_upsert(data, test_doc(), "T")
    Condition
      Error in `grist_records_upsert()`:
      ! `by` is absent but must be supplied.

---

    Code
      grist_records_upsert(data, test_doc(), "T", by = 1)
    Condition
      Error in `grist_records_upsert()`:
      ! `by` must be a character vector of column names, not a number.

---

    Code
      grist_records_upsert(data, test_doc(), "T", by = "x")
    Condition
      Error in `grist_records_upsert()`:
      ! Every column in `by` must be in `data`.
      x Missing from `data`: x.

---

    Code
      grist_records_upsert(data, test_doc(), "T", by = "name")
    Condition
      Error in `grist_records_upsert()`:
      ! `by` columns can't have missing values.
      x Rows with missing keys: 3.

---

    Code
      grist_records_upsert(data[c(1, 2), ], test_doc(), "T", by = "name")
    Condition
      Error in `grist_records_upsert()`:
      ! `by` must identify each row of `data` uniquely.
      x Rows with duplicated keys: 1 and 2.

---

    Code
      grist_records_upsert(data.frame(id = 1L, a = 1), test_doc(), "T", by = "a")
    Condition
      Error in `grist_records_upsert()`:
      ! `data` can't have an id column when matching on `by`.
      i Use `grist_records_update()` with `by = "id"` to change rows by ID.

