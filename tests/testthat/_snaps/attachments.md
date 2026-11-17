# grist_attachments_upload() checks that files exist

    Code
      grist_attachments_upload(test_doc(), c("missing-1.txt", "missing-2.txt"))
    Condition
      Error in `grist_attachments_upload()`:
      ! `path` must be existing files.
      x Not an existing file: 'missing-1.txt' and 'missing-2.txt'.

---

    Code
      grist_attachments_upload(test_doc(), tempdir())
    Condition
      Error in `grist_attachments_upload()`:
      ! `path` must be existing files.
      x Not an existing file: '<tmp>'.

