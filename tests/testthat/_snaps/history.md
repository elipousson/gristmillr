# grist_doc_compare() validates its arguments

    Code
      grist_doc_compare(test_doc(), left = 1)
    Condition
      Error in `grist_doc_compare()`:
      ! `left` must be a single string or `NULL`, not the number 1.

---

    Code
      grist_doc_compare(test_doc(), max_rows = -1)
    Condition
      Error in `grist_doc_compare()`:
      ! `max_rows` must be a whole number larger than or equal to 0 or `NULL`, not the number -1.

# history changes refuse to run without ask = FALSE in scripts

    Code
      grist_snapshot_restore(test_doc(), "s1")
    Condition
      Error in `grist_snapshot_restore()`:
      ! Can't ask before replacing a document in a non-interactive session.
      i Use `ask = FALSE` to replace without a prompt.

---

    Code
      grist_snapshots_remove(test_doc(), "s1")
    Condition
      Error in `grist_snapshots_remove()`:
      ! Can't ask before deleting a snapshot in a non-interactive session.
      i Use `ask = FALSE` to delete without a prompt.

---

    Code
      grist_doc_history_truncate(test_doc(), 1)
    Condition
      Error in `grist_doc_history_truncate()`:
      ! Can't ask before truncating a history in a non-interactive session.
      i Use `ask = FALSE` to truncate without a prompt.

# history changes validate their arguments

    Code
      grist_snapshot_restore(test_doc(), 1)
    Condition
      Error in `grist_snapshot_restore()`:
      ! `snapshot_id` must be a single string, not the number 1.

---

    Code
      grist_snapshots_remove(test_doc(), character())
    Condition
      Error in `grist_snapshots_remove()`:
      ! `snapshot_ids` must be a character vector of snapshot IDs.

---

    Code
      grist_doc_history_truncate(test_doc(), -1)
    Condition
      Error in `grist_doc_history_truncate()`:
      ! `keep` must be a whole number larger than or equal to 0, not the number -1.

