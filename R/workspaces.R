#' List orgs, workspaces and documents; manage workspaces
#'
#' @description
#' Orgs are the team sites (or personal areas) you can access. Each org has
#' workspaces, and each workspace holds documents.
#'
#' * `grist_orgs()` lists the orgs you can access.
#' * `grist_workspaces()` lists the workspaces in an org.
#' * `grist_docs()` lists the documents in an org, with their workspace.
#' * `grist_workspace_create()` creates a workspace.
#' * `grist_workspace_delete()` and `grist_workspace_restore()` move a
#'   workspace to the trash or delete it permanently, and restore it. As with
#'   [grist_doc_delete()], deleting asks for confirmation.
#'
#' @inheritParams grist_doc_create
#' @param org An org ID or domain. `"current"` is the org that matches the
#'   server URL. If the server has no current org (as with Grist Desktop) and
#'   you can access exactly one org, that org is used. Otherwise, set `org` to
#'   a value from `grist_orgs()$id`.
#' @param workspace A workspace ID.
#' @returns A data frame for the listing functions. `grist_workspace_create()`
#'   returns the new workspace ID invisibly. `grist_workspace_delete()` and
#'   `grist_workspace_restore()` return the workspace ID invisibly.
#' @family workspaces
#' @examplesIf FALSE
#' grist_orgs()
#' grist_workspaces()
#' grist_docs()
#' id <- grist_workspace_create(name = "Pets")
#' grist_workspace_delete(id, ask = FALSE)
#' @export
grist_orgs <- function(server = NULL, options = NULL) {
  server <- normalize_server(server %||% default_server())
  options <- as_request_options(options)

  orgs <- req_grist(server, "orgs", options) |>
    grist_perform()

  new_tbl(
    list(
      id = map_int(orgs, function(x) as.integer(x$id)),
      name = field_vec(orgs, "name", NA_character_, top = TRUE),
      domain = field_vec(orgs, "domain", NA_character_, top = TRUE),
      access = field_vec(orgs, "access", NA_character_, top = TRUE),
      created_at = as_grist_time(
        field_vec(orgs, "createdAt", NA_character_, top = TRUE)
      ),
      updated_at = as_grist_time(
        field_vec(orgs, "updatedAt", NA_character_, top = TRUE)
      )
    ),
    n = length(orgs)
  )
}

#' @rdname grist_orgs
#' @export
grist_workspaces <- function(org = "current", server = NULL, options = NULL) {
  workspaces <- list_workspaces(org, server, options)

  new_tbl(
    list(
      id = map_int(workspaces, function(x) as.integer(x$id)),
      name = field_vec(workspaces, "name", NA_character_, top = TRUE),
      access = field_vec(workspaces, "access", NA_character_, top = TRUE),
      org_domain = field_vec(
        workspaces,
        "orgDomain",
        NA_character_,
        top = TRUE
      ),
      n_docs = map_int(workspaces, function(x) length(x$docs))
    ),
    n = length(workspaces)
  )
}

#' @rdname grist_orgs
#' @export
grist_docs <- function(org = "current", server = NULL, options = NULL) {
  workspaces <- list_workspaces(org, server, options)

  docs <- unlist(
    map(workspaces, function(ws) {
      map(ws$docs, function(doc) {
        list(doc = doc, workspace_id = ws$id, workspace_name = ws$name)
      })
    }),
    recursive = FALSE
  )

  new_tbl(
    list(
      id = map_chr(docs, function(x) x$doc$id),
      name = map_chr(docs, function(x) x$doc$name),
      access = map_chr(docs, function(x) x$doc$access %||% NA_character_),
      is_pinned = vapply(
        docs,
        function(x) x$doc$isPinned %||% NA,
        logical(1)
      ),
      url_id = map_chr(docs, function(x) x$doc$urlId %||% NA_character_),
      workspace_id = map_int(docs, function(x) as.integer(x$workspace_id)),
      workspace_name = map_chr(docs, function(x) x$workspace_name)
    ),
    n = length(docs)
  )
}

#' @rdname grist_orgs
#' @export
grist_workspace_create <- function(
  name,
  org = "current",
  server = NULL,
  options = NULL
) {
  check_string(name)
  server <- normalize_server(server %||% default_server())
  options <- as_request_options(options)

  id <- with_org(org, server, options, function(org) {
    req_grist(server, c("orgs", org, "workspaces"), options) |>
      req_json_body(list(name = name)) |>
      grist_perform()
  })
  invisible(as.integer(id))
}

#' @rdname grist_orgs
#' @export
grist_workspace_delete <- function(
  workspace,
  mode = c("trash", "permanent"),
  ask = NULL,
  server = NULL,
  options = NULL
) {
  check_number_whole(workspace, min = 1)
  mode <- arg_match(mode)
  server <- normalize_server(server %||% default_server())
  options <- as_request_options(options)

  check_ask(
    "workspace",
    function() {
      body <- req_grist(server, c("workspaces", workspace), options) |>
        grist_perform()
      body$name
    },
    mode,
    ask
  )

  req <- req_grist(server, c("workspaces", workspace, "remove"), options) |>
    httr2::req_method("POST")
  if (mode == "permanent") {
    req <- httr2::req_url_query(req, permanent = "true")
  }
  grist_perform(req)
  invisible(as.integer(workspace))
}

#' @rdname grist_orgs
#' @export
grist_workspace_restore <- function(workspace, server = NULL, options = NULL) {
  check_number_whole(workspace, min = 1)
  server <- normalize_server(server %||% default_server())
  options <- as_request_options(options)

  req_grist(server, c("workspaces", workspace, "unremove"), options) |>
    httr2::req_method("POST") |>
    grist_perform()
  invisible(as.integer(workspace))
}

list_workspaces <- function(org, server, options, call = caller_env()) {
  server <- normalize_server(server %||% default_server())
  options <- as_request_options(options)
  with_org(org, server, options, call = call, function(org) {
    req_grist(server, c("orgs", org, "workspaces"), options, call = call) |>
      grist_perform(call = call)
  })
}

# Run `fn(org)`. A server with no "current" org (such as Grist Desktop) rejects
# `org = "current"` with HTTP 400. When that happens and the account has exactly
# one org, retry with that org's ID.
with_org <- function(org, server, options, fn, call = caller_env()) {
  if (!identical(org, "current")) {
    return(fn(org))
  }
  try_fetch(
    fn(org),
    gristmillr_http_error = function(cnd) {
      if (!inherits(cnd$parent, "httr2_http_400")) {
        return(zap())
      }
      orgs <- grist_orgs(server, options)
      if (nrow(orgs) != 1) {
        cli::cli_abort(
          c(
            "Can't find the current org.",
            i = "Set {.arg org} to one of {.code grist_orgs()$id}."
          ),
          parent = cnd,
          call = call
        )
      }
      fn(orgs$id[[1]])
    }
  )
}
