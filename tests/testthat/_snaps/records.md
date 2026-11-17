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
      grist_records_add(test_doc(), "People", data.frame(name = "x", nope = 1))
    Condition
      Error in `grist_records_add()`:
      ! `data` has 1 column not in the Grist table.
      x Unknown column: nope.
      i Use `grist_write_options(unknown_cols = "drop")` to ignore unknown columns.

# grist_records_add() rejects an id column

    Code
      grist_records_add(test_doc(), "People", data.frame(id = 1, x = 1))
    Condition
      Error in `grist_records_add()`:
      ! `data` can't have an id column when adding records.
      i Use `grist_records_update()` to change existing rows.

---

    Code
      grist_records_add(test_doc(), "People", list(x = 1))
    Condition
      Error in `grist_records_add()`:
      ! `data` must be a data frame, not a list.

# grist_records_update() requires an id column

    Code
      grist_records_update(test_doc(), "People", data.frame(x = 1))
    Condition
      Error in `grist_records_update()`:
      ! `data` must have an id column to update records.

# grist_records_delete() validates ids

    Code
      grist_records_delete(test_doc(), "People", "a")
    Condition
      Error in `grist_records_delete()`:
      ! `ids` must be a numeric vector without missing values, not a string.

---

    Code
      grist_records_delete(test_doc(), "People", data.frame(x = 1))
    Condition
      Error in `grist_records_delete()`:
      ! `ids` must have an id column.

