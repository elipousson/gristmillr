#' Create, describe, update, move and delete documents
#'
#' @description
#' * `grist_doc_create()` creates an empty document in a workspace and returns
#'   a [grist_doc()] handle.
#' * `grist_doc_info()` describes a document.
#' * `grist_doc_update()` renames a document or pins and unpins it.
#' * `grist_doc_move()` moves a document to another workspace.
#' * `grist_doc_delete()` moves a document to the trash, or deletes it
#'   permanently.
#' * `grist_doc_restore()` restores a document from the trash.
#'
#' @section Deleting:
#' `grist_doc_delete()` asks for confirmation. In an interactive session it
#' prompts: a yes/no question for `mode = "trash"`, and typing the document
#' name for `mode = "permanent"`. In a script, it refuses to delete unless
#' `confirm = TRUE`.
#'
#' @inheritParams grist_doc
#' @param workspace A workspace ID, as listed by [grist_workspaces()].
#' @param name Document name.
#' @param pinned Whether the document is pinned. For `grist_doc_update()`,
#'   `NULL` leaves the setting unchanged.
#' @param mode `"trash"` moves the document to the trash, where it can be
#'   restored with `grist_doc_restore()`. `"permanent"` deletes it for good.
#' @param confirm `NULL` (the default) prompts in an interactive session and
#'   errors otherwise. `TRUE` skips the prompt. `FALSE` always errors.
#' @returns `grist_doc_create()` returns a [grist_doc()]. `grist_doc_info()`
#'   returns a one-row data frame with `id`, `name`, `access`, `is_pinned`,
#'   `url_id`, `workspace_id`, `workspace_name` and `org_domain`. The others
#'   return a [grist_doc()] invisibly.
#' @family docs
#' @examplesIf FALSE
#' doc <- grist_doc_create(workspace = 1234, name = "Pets")
#' grist_doc_info(doc)
#' doc |> grist_doc_update(name = "Pets 2026", pinned = TRUE)
#' doc |> grist_doc_delete()
#' doc |> grist_doc_restore()
#' @export
grist_doc_create <- function(
  workspace,
  name,
  pinned = FALSE,
  server = NULL,
  options = NULL
) {
  check_number_whole(workspace, min = 1)
  check_string(name)
  check_bool(pinned)
  server <- normalize_server(server %||% default_server())
  options <- as_request_options(options)

  doc_id <- req_grist(server, c("workspaces", workspace, "docs"), options) |>
    req_json_body(list(name = name, isPinned = pinned)) |>
    grist_perform()

  grist_doc(doc_id, server = server, options = options)
}

#' @rdname grist_doc_create
#' @export
grist_doc_info <- function(doc) {
  doc <- grist_doc(doc)
  body <- grist_perform(grist_request(doc))

  new_tbl(
    list(
      id = body$id,
      name = body$name,
      access = body$access %||% NA_character_,
      is_pinned = body$isPinned %||% NA,
      url_id = body$urlId %||% NA_character_,
      workspace_id = as.integer(body$workspace$id %||% NA_integer_),
      workspace_name = body$workspace$name %||% NA_character_,
      org_domain = body$workspace$org$domain %||% NA_character_
    ),
    n = 1L
  )
}

#' @rdname grist_doc_create
#' @export
grist_doc_update <- function(doc, name = NULL, pinned = NULL) {
  doc <- grist_doc(doc)
  check_string(name, allow_null = TRUE)
  check_bool(pinned, allow_null = TRUE)
  if (is.null(name) && is.null(pinned)) {
    cli::cli_abort("Must supply at least one of {.arg name} and {.arg pinned}.")
  }

  grist_request(doc) |>
    httr2::req_method("PATCH") |>
    req_json_body(compact(list(name = name, isPinned = pinned))) |>
    grist_perform()
  invisible(doc)
}

#' @rdname grist_doc_create
#' @export
grist_doc_move <- function(doc, workspace) {
  doc <- grist_doc(doc)
  check_number_whole(workspace, min = 1)

  grist_request(doc, "move") |>
    httr2::req_method("PATCH") |>
    req_json_body(list(workspace = as.integer(workspace))) |>
    grist_perform()
  invisible(doc)
}

#' @rdname grist_doc_create
#' @export
grist_doc_delete <- function(
  doc,
  mode = c("trash", "permanent"),
  confirm = NULL
) {
  doc <- grist_doc(doc)
  mode <- arg_match(mode)
  confirm_delete(
    "document",
    function() grist_doc_info(doc)$name,
    mode,
    confirm
  )

  req <- grist_request(doc, "remove") |>
    httr2::req_method("POST")
  if (mode == "permanent") {
    req <- httr2::req_url_query(req, permanent = "true")
  }
  grist_perform(req)
  invisible(doc)
}

#' @rdname grist_doc_create
#' @export
grist_doc_restore <- function(doc) {
  doc <- grist_doc(doc)
  grist_request(doc, "unremove") |>
    httr2::req_method("POST") |>
    grist_perform()
  invisible(doc)
}
