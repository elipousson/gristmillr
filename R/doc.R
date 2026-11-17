#' @include options.R
NULL

#' Create a handle for a Grist document
#'
#' @description
#' `grist_doc()` creates a lightweight handle that identifies a Grist document
#' and the server it lives on. The handle is passed as the first argument to
#' most gristmillr functions so it works in pipelines:
#'
#' ```r
#' grist_doc("<doc id>") |>
#'   grist_records("People")
#' ```
#'
#' The handle never stores your API key. Requests read it from the
#' `GRIST_API_KEY` environment variable.
#'
#' @param doc A document ID, the URL of a document, or an existing
#'   `grist_doc` object.
#' @param server URL of the Grist server, such as `"https://docs.getgrist.com"`
#'   or `"https://myteam.getgrist.com"`. For a self-hosted server, include the
#'   team path if needed, e.g. `"http://localhost:8484/o/docs"`. Defaults to the
#'   server in `doc` if `doc` is a URL, then the `GRIST_SERVER` environment
#'   variable, then `"https://docs.getgrist.com"`.
#' @param options A [grist_request_options()] object. If `NULL`, the default
#'   from `getOption("gristmillr.request_options")` or
#'   [grist_request_options()] is used.
#' @returns A `grist_doc` object with properties `doc_id`, `server` and
#'   `options`.
#' @family docs
#' @examples
#' grist_doc("am2iHJ9Amvo7Ve3EE5emtu")
#' grist_doc("https://docs.getgrist.com/doc/am2iHJ9Amvo7Ve3EE5emtu")
#' @export
grist_doc <- new_class(
  "grist_doc",
  properties = list(
    doc_id = class_character,
    server = class_character,
    options = grist_request_options
  ),
  constructor = function(doc, server = NULL, options = NULL) {
    if (S7::S7_inherits(doc, grist_doc)) {
      return(doc)
    }
    check_string(doc)
    parsed <- parse_doc(doc)
    server <- server %||% parsed$server %||% default_server()
    new_object(
      S7_object(),
      doc_id = parsed$doc_id,
      server = normalize_server(server),
      options = as_request_options(options)
    )
  },
  validator = function(self) {
    if (!is_string(self@doc_id)) {
      return("@doc_id must be a single non-empty string.")
    }
    if (grepl("[/?#[:space:]]", self@doc_id)) {
      return("@doc_id must not contain slashes, spaces or URL delimiters.")
    }
    if (!grepl("^https?://", self@server)) {
      return("@server must be a URL starting with http:// or https://.")
    }
    NULL
  }
)

method(print, grist_doc) <- function(x, ...) {
  cli::cli_text("{.cls grist_doc} {.val {x@doc_id}}")
  cli::cli_text("Server: {.url {x@server}}")
  invisible(x)
}

default_server <- function() {
  server <- Sys.getenv("GRIST_SERVER", unset = "")
  if (nzchar(server)) server else "https://docs.getgrist.com"
}

# Strip trailing slashes and a trailing `/api` so users can paste either form.
normalize_server <- function(server, call = caller_env()) {
  check_string(server, call = call)
  server <- sub("/+$", "", server)
  sub("/api$", "", server)
}

# Extract the document ID (and server, if present) from a document URL.
# Plain IDs are returned unchanged.
parse_doc <- function(doc, call = caller_env()) {
  if (!grepl("^https?://", doc)) {
    return(list(doc_id = doc, server = NULL))
  }

  m <- regmatches(
    doc,
    regexec(
      "^(https?://[^/]+(?:/o/[^/]+)?)(?:/api/docs|/doc)/([^/?#]+)",
      doc,
      perl = TRUE
    )
  )[[1]]

  if (length(m) == 0) {
    m <- regmatches(
      doc,
      regexec(
        "^(https?://[^/]+(?:/o/[^/]+)?)/([A-Za-z0-9]{22})(?:[/?#]|$)",
        doc,
        perl = TRUE
      )
    )[[1]]
  }

  if (length(m) == 0) {
    cli::cli_abort(
      c(
        "Can't find a document ID in {.arg doc}.",
        i = "Supply a document ID or a URL such as {.url https://docs.getgrist.com/doc/<id>}."
      ),
      call = call
    )
  }

  list(doc_id = m[[3]], server = m[[2]])
}
