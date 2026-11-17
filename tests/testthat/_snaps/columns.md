# columns_spec() validates input

    Code
      columns_spec(1)
    Condition
      Error:
      ! `columns` must be a character vector or a data frame with an id column.
      i Got a number.

---

    Code
      columns_spec(data.frame(x = 1))
    Condition
      Error:
      ! `columns` must be a character vector or a data frame with an id column.
      i Got a data frame.

---

    Code
      columns_spec(data.frame(id = "a", nope = 1))
    Condition
      Error:
      ! `columns` has unknown column: nope.
      i Allowed columns are id, type, label, formula, is_formula, widget_options, visible_col, untie_col_id_from_label, and col_id.

# grist_columns_modify() patches columns

    Code
      grist_columns_modify(doc, "People", c(a = "Int"))
    Condition
      Error in `grist_columns_modify()`:
      ! `columns` must be a data frame with an id column, not a string.

