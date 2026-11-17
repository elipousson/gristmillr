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

