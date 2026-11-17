# option enums are validated

    Code
      grist_read_options(col_names = "name")
    Condition
      Error in `grist_read_options()`:
      ! `col_names` must be one of "id" or "label", not "name".

---

    Code
      grist_write_options(unknown_cols = "ignore")
    Condition
      Error in `grist_write_options()`:
      ! `unknown_cols` must be one of "error" or "drop", not "ignore".

# option values are validated

    Code
      grist_request_options(timeout = -1)
    Condition
      Error in `grist_request_options()`:
      ! <gristmillr::grist_request_options> object is invalid:
      - @timeout must be a single positive number.

---

    Code
      grist_write_options(chunk_size = 0)
    Condition
      Error in `grist_write_options()`:
      ! <gristmillr::grist_write_options> object is invalid:
      - @chunk_size must be a single number >= 1.

---

    Code
      grist_read_options(hidden = NA)
    Condition
      Error in `grist_read_options()`:
      ! <gristmillr::grist_read_options> object is invalid:
      - @hidden must be `TRUE` or `FALSE`.

# options of the wrong class are rejected

    Code
      as_read_options(grist_write_options())
    Condition
      Error:
      ! `grist_write_options()` must be a <grist_read_options> object, not a <gristmillr::grist_write_options> object.

