# argument combinations are validated

    Code
      grist_doc_download(doc, path, format = "csv")
    Condition
      Error in `grist_doc_download()`:
      ! `table` is required when `format = "csv"`.
      i Use `format = "xlsx"` or `"grist"` to download the whole document.

---

    Code
      grist_doc_download(doc, path, table = "People")
    Condition
      Error in `grist_doc_download()`:
      ! `table` can't be used with `format = "grist"`.
      i The "grist" format always contains the whole document.

---

    Code
      grist_doc_download(doc, path, format = "xlsx", template = TRUE)
    Condition
      Error in `grist_doc_download()`:
      ! `no_history` and `template` can only be used with `format = "grist"`.

---

    Code
      grist_doc_download(doc, path, format = "pdf")
    Condition
      Error in `grist_doc_download()`:
      ! `format` must be one of "grist", "xlsx", "csv", "tsv", or "dsv", not "pdf".

# existing files are only replaced with overwrite = TRUE

    Code
      grist_doc_download(test_doc(), path, format = "xlsx")
    Condition
      Error in `grist_doc_download()`:
      ! '<path>' already exists.
      i Use `overwrite = TRUE` to replace it.

