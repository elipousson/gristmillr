# columns without a display column warn and are left alone

    Code
      out <- grist_resolve_refs(data, test_doc(), "Orders", columns = "orphan")
    Condition
      Warning:
      Can't resolve 1 reference column: orphan.
      i No display column is set in Grist, so only row IDs are available.

# grist_resolve_refs() validates its input

    Code
      grist_resolve_refs(orders(), test_doc(), "Orders", columns = "item")
    Condition
      Error in `grist_resolve_refs()`:
      ! `columns` must be reference columns of table "Orders".
      x Not reference columns: item.

---

    Code
      grist_resolve_refs(orders()[c("id", "item")], test_doc(), "Orders", columns = "person")
    Condition
      Error in `grist_resolve_refs()`:
      ! `data` has no column person.

---

    Code
      grist_resolve_refs(list(), test_doc(), "Orders")
    Condition
      Error in `grist_resolve_refs()`:
      ! `data` must be a data frame, not an empty list.

