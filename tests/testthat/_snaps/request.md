# a missing API key is an informative error

    Code
      grist_request(test_doc())
    Condition
      Error in `grist_request()`:
      ! Can't find a Grist API key.
      i Set the `GRIST_API_KEY` environment variable, e.g. in your '.Renviron'.

# HTTP errors include Grist's message and a gristmillr class

    Code
      grist_tables(test_doc())
    Condition
      Error in `grist_tables()`:
      ! Grist request failed with HTTP status 404.
      Caused by error in `httr2::req_perform()`:
      ! HTTP 404 Not Found.
      i Table not found: "Nope"

