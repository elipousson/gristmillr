# grist_doc() validates its input

    Code
      grist_doc("https://example.com/nothing")
    Condition
      Error in `grist_doc()`:
      ! Can't find a document ID in `doc`.
      i Supply a document ID or a URL such as <https://docs.getgrist.com/doc/<id>>.

---

    Code
      grist_doc(1)
    Condition
      Error in `grist_doc()`:
      ! `doc` must be a single string, not the number 1.

---

    Code
      grist_doc("a b")
    Condition
      Error in `grist_doc()`:
      ! <gristmillr::grist_doc> object is invalid:
      - @doc_id must not contain slashes, spaces or URL delimiters.

---

    Code
      grist_doc("abc", server = "example.com")
    Condition
      Error in `grist_doc()`:
      ! <gristmillr::grist_doc> object is invalid:
      - @server must be a URL starting with http:// or https://.

# grist_doc() has a print method

    Code
      print(test_doc())
    Message
      <grist_doc> "abc123"
      Server: <https://example.getgrist.com>

