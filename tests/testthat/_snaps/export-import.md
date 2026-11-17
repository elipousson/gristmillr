# grist_import() validates its arguments

    Code
      grist_import(doc, "x", types = c("a"))
    Condition
      Error in `grist_import()`:
      ! `types` must be a named character vector, like `c("Table.column" = "value")`.

---

    Code
      grist_import(doc, "x", types = c(a = "Int"))
    Condition
      Error in `grist_import()`:
      ! Names in `types` must have the form `Table.column`.
      x Can't use "a".

---

    Code
      grist_import(doc, "x", display = 1)
    Condition
      Error in `grist_import()`:
      ! `display` must be a named character vector, like `c("Table.column" = "value")`.

---

    Code
      grist_import(doc, "x", orphans = "drop")
    Condition
      Error in `grist_import()`:
      ! `orphans` must be one of "error" or "empty", not "drop".

# grist_export() validates its arguments

    Code
      grist_export(doc, to = 1)
    Condition
      Error in `grist_export()`:
      ! `to` must be a single string, not the number 1.

---

    Code
      grist_export(doc, examples = "all")
    Condition
      Error in `grist_export()`:
      ! `examples` must be one of "sample" or "none", not "all".

# grist_import() checks before changing anything

    Code
      grist_import(doc, dir)
    Condition
      Error in `grist_import()`:
      ! Column kids.parent refers to 1 key that is not in "parents".
      x Missing keys: 9.
      i Use `orphans = "empty"` to leave them empty.

---

    Code
      grist_import(doc, dir, orphans = "empty")
    Condition
      Error in `grist_import()`:
      ! 2 tables already exist in the document.
      x Existing: "parents" and "kids".
      i Use `if_exists = "append"` to add rows to existing tables.

---

    Code
      grist_import(doc, dir, types = c(kids.nope = "Int"))
    Condition
      Error in `grist_import()`:
      ! `types` names a column that isn't in the dictionary: "kids.nope".

