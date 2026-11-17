# grist_doc_update() patches name and pinned

    Code
      grist_doc_update(doc)
    Condition
      Error in `grist_doc_update()`:
      ! Must supply at least one of `name` and `pinned`.

# grist_doc_delete() refuses to run unconfirmed in scripts

    Code
      grist_doc_delete(test_doc())
    Condition
      Error in `grist_doc_delete()`:
      ! Must confirm before deleting a document.
      i Use `confirm = TRUE` to delete without a prompt.

# grist_doc_delete() validates confirm

    Code
      grist_doc_delete(test_doc(), confirm = "yes")
    Condition
      Error in `grist_doc_delete()`:
      ! `confirm` must be `TRUE`, `FALSE` or `NULL`, not a string.

