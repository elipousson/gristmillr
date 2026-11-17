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

# history changes refuse to run unconfirmed in scripts

    Code
      grist_snapshot_restore(test_doc(), "s1")
    Condition
      Error in `grist_snapshot_restore()`:
      ! Must confirm before replacing a document.
      i Use `confirm = TRUE` to replace without a prompt.

---

    Code
      grist_snapshots_remove(test_doc(), "s1")
    Condition
      Error in `grist_snapshots_remove()`:
      ! Must confirm before deleting a snapshot.
      i Use `confirm = TRUE` to delete without a prompt.

---

    Code
      grist_doc_history_truncate(test_doc(), 1)
    Condition
      Error in `grist_doc_history_truncate()`:
      ! Must confirm before truncating a history.
      i Use `confirm = TRUE` to truncate without a prompt.

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

