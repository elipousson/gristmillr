#' Build a request for the Grist API
#'
#' @description
#' `grist_request()` returns an [httr2][httr2::httr2-package] request for a
#' document, with authentication, a user agent, a timeout, retries and
#' Grist-aware error messages already set. Use it to call endpoints that
#' gristmillr does not wrap yet:
#'
#' ```r
#' grist_request(doc, "tables") |>
#'   httr2::req_perform() |>
#'   httr2::resp_body_json()
#' ```
#'
#' @inheritParams grist_doc
#' @param ... Path components appended to the document URL, such as
#'   `"tables"` or `c("tables", "People", "records")`.
#' @returns An `httr2_request` object.
#' @family docs
#' @examples
#' doc <- grist_doc("am2iHJ9Amvo7Ve3EE5emtu", server = "https://docs.getgrist.com")
#' withr::with_envvar(
#'   c(GRIST_API_KEY = "example"),
#'   httr2::req_dry_run(grist_request(doc, "tables"))
#' )
#' @export
grist_request <- function(doc, ...) {
  doc <- grist_doc(doc)
  req_grist(doc@server, c("docs", doc@doc_id, ...), doc@options)
}

# Request against the server root rather than a single document.
req_grist <- function(server, path, options, call = caller_env()) {
  httr2::request(paste0(server, "/api")) |>
    httr2::req_url_path_append(paste(path, collapse = "/")) |>
    httr2::req_auth_bearer_token(grist_api_key(options, call)) |>
    httr2::req_user_agent(options@user_agent) |>
    httr2::req_timeout(options@timeout) |>
    httr2::req_retry(max_tries = options@max_tries) |>
    httr2::req_error(body = grist_error_body)
}

# API keys supplied as strings are kept in this session-only registry rather
# than on the options object, so serialising an object (`saveRDS()`, targets)
# never writes the key to disk.
key_registry <- new_environment()

store_api_key <- function(api_key, call = caller_env()) {
  if (is.null(api_key) || is.function(api_key)) {
    return(api_key)
  }
  if (inherits(api_key, "gristmillr_key_ref")) {
    return(api_key)
  }
  if (!is_nonempty_string(api_key)) {
    cli::cli_abort(
      "{.arg api_key} must be a string or a function that returns one, not {.obj_type_friendly {api_key}}.",
      call = call
    )
  }
  id <- basename(tempfile("key"))
  env_poke(key_registry, id, api_key)
  structure(id, class = "gristmillr_key_ref")
}

grist_api_key <- function(options, call = caller_env()) {
  key <- options@api_key

  if (is.function(key)) {
    value <- key()
    if (!is_nonempty_string(value)) {
      cli::cli_abort(
        "The {.arg api_key} function must return a single string, not {.obj_type_friendly {value}}.",
        class = "gristmillr_no_api_key",
        call = call
      )
    }
    return(value)
  }

  if (inherits(key, "gristmillr_key_ref")) {
    value <- env_get(key_registry, unclass(key), default = NULL)
    if (is.null(value)) {
      cli::cli_abort(
        c(
          "The API key for this object is not available in this session.",
          i = "API keys are never saved with an object. Supply {.arg api_key} again, or use a function that looks it up."
        ),
        class = "gristmillr_no_api_key",
        call = call
      )
    }
    return(value)
  }

  value <- Sys.getenv("GRIST_API_KEY", unset = "")
  if (!nzchar(value)) {
    cli::cli_abort(
      c(
        "Can't find a Grist API key.",
        i = "Supply {.arg api_key}, or set the {.envvar GRIST_API_KEY} environment variable, e.g. in your {.file .Renviron}."
      ),
      class = "gristmillr_no_api_key",
      call = call
    )
  }
  value
}

grist_error_body <- function(resp) {
  body <- tryCatch(httr2::resp_body_json(resp), error = function(cnd) NULL)
  if (!is.list(body)) {
    return(NULL)
  }
  # `details` can be a nested object, such as `list(userError = "...")`, but
  # httr2 requires a character vector.
  as.character(unlist(c(body$error, body$details), use.names = FALSE))
}

# Perform a request, turning HTTP errors into gristmillr errors. Returns the
# response.
perform_request <- function(req, path = NULL, call = caller_env()) {
  try_fetch(
    httr2::req_perform(req, path = path),
    httr2_http = function(cnd) {
      status <- httr2::resp_status(cnd$resp)
      cli::cli_abort(
        "Grist request failed with HTTP status {status}.",
        class = "gristmillr_http_error",
        parent = cnd,
        call = call
      )
    }
  )
}

# Perform a request, returning the parsed JSON body (or NULL if empty).
grist_perform <- function(req, call = caller_env()) {
  resp <- perform_request(req, call = call)
  if (!httr2::resp_has_body(resp)) {
    return(invisible(NULL))
  }
  httr2::resp_body_json(resp)
}

# Doc-scoped request helpers ----------------------------------------------

req_json_body <- function(req, data) {
  # jsonlite writes numeric `NA` as the string "NA" unless `na = "null"`.
  httr2::req_body_json(req, data, auto_unbox = TRUE, null = "null", na = "null")
}

# Convert a vector or list into the strict JSON shape Grist expects. Names are
# dropped because a named list would be written as a JSON object.
json_array <- function(x) {
  unname(as.list(x))
}
