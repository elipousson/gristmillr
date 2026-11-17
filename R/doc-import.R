#' Import a file as a new document
#'
#' @description
#' `grist_doc_import()` uploads a file and creates a new document from it in a
#' workspace. It's the quickest way to start from data you already have in a
#' file. To load several related tables with their types and references, see
#' [grist_import()].
#'
#' @section File formats:
#' Grist reads `.grist`, `.csv`, `.xlsx` and `.json` files. A `.grist` file
#' becomes a copy of that document. A CSV or JSON file becomes one table named
#' after the file, and an Excel workbook one table per sheet. Column types are
#' guessed from the values, so whole numbers arrive as `Numeric` and not
#' `Int`, and nothing links the tables. Use [grist_columns_modify()] to change
#' types afterwards. A JSON file must hold an array of objects.
#'
#' @inheritParams grist_doc_create
#' @param path Path to the file to upload.
#' @param name Name for the new document. If `NULL`, Grist names it after the
#'   file.
#' @returns A [grist_doc()] for the new document.
#' @family docs
#' @examplesIf FALSE
#' doc <- grist_doc_import("pets.csv", workspace = 1234, name = "Pets")
#' grist_tables(doc)
#' grist_records(doc, "Pets")
#' @export
grist_doc_import <- function(
  path,
  workspace,
  name = NULL,
  server = NULL,
  options = NULL
) {
  check_string(path)
  check_number_whole(workspace, min = 1)
  check_string(name, allow_null = TRUE)
  server <- normalize_server(server %||% default_server())
  options <- as_request_options(options)

  if (!file.exists(path) || dir.exists(path)) {
    cli::cli_abort(
      c(
        "{.arg path} must be an existing file.",
        x = "Not an existing file: {.file {path}}."
      )
    )
  }

  body <- req_grist(server, c("workspaces", workspace, "import"), options) |>
    httr2::req_body_multipart(
      upload = curl::form_file(path),
      documentName = name
    ) |>
    grist_perform()

  grist_doc(body$id, server = server, options = options)
}
