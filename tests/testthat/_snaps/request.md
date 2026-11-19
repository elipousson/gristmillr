# a missing API key is an informative error

    Code
      grist_request(test_doc())
    Condition
      Error in `grist_request()`:
      ! Can't find a Grist API key.
      i Supply `api_key`, or set the `GRIST_API_KEY` environment variable, e.g. in your '.Renviron'.

# HTTP errors include Grist's message and a gristmillr class

    Code
      grist_tables(test_doc())
    Condition
      Error in `grist_tables()`:
      ! Grist request failed with HTTP status 404.
      Caused by error in `httr2::req_perform()`:
      ! HTTP 404 Not Found.
      i Table not found: "Nope"

# string keys are not serialised with the object

    Code
      grist_request(doc)
    Condition
      Error in `grist_request()`:
      ! The API key for this object is not available in this session.
      i API keys are never saved with an object. Supply `api_key` again, or use a function that looks it up.

# api_key is validated

    Code
      grist_doc("abc123", api_key = 1)
    Condition
      Error in `grist_request_options()`:
      ! `api_key` must be a string or a function that returns one, not a number.

---

    Code
      grist_request(doc)
    Condition
      Error in `grist_request()`:
      ! The `api_key` function must return a single string, not a number.

# nested error details are flattened into the error message

    Code
      grist_tables(test_doc())
    Condition
      Error in `grist_tables()`:
      ! Grist request failed with HTTP status 400.
      Caused by error in `httr2::req_perform()`:
      ! HTTP 400 Bad Request.
      Invalid payload
      body.records[0].id is not a number

