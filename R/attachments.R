#' List, upload and download attachments
#'
#' @description
#' Attachments are files stored inside a Grist document and referenced from
#' cells of `Attachments` columns.
#'
#' * `grist_attachments()` lists the metadata of all attachments in a document.
#' * `grist_attachment_info()` returns the metadata of one attachment.
#' * `grist_attachments_upload()` uploads files and returns their attachment
#'   IDs.
#' * `grist_attachment_download()` saves an attachment to a file.
#'
#' @section Attaching files to records:
#' Uploading a file does not attach it to a record. Write the returned IDs into
#' an `Attachments` column as a list-column:
#'
#' ```r
#' ids <- grist_attachments_upload(doc, c("a.pdf", "b.pdf"))
#'
#' grist_records_update(
#'   doc, "Reports",
#'   data.frame(id = 1L, files = I(list(ids)))
#' )
#' ```
#'
#' With `convert = "auto"`, `Attachments` columns are read back as list-columns
#' of attachment IDs, which you can pass to `grist_attachment_download()`.
#'
#' Attachments that are no longer referenced by any cell may still appear in
#' `grist_attachments()` for a while.
#'
#' @inheritParams grist_records
#' @param id An attachment ID.
#' @param path For `grist_attachments_upload()`, a character vector of files to
#'   upload, each uploaded in its own request. For
#'   `grist_attachment_download()`, the file to write, or an existing directory,
#'   in which case the attachment's original file name (reduced to its base
#'   name) is used.
#' @param overwrite Whether to replace an existing file.
#' @returns `grist_attachments()` returns a data frame with columns `id`,
#'   `file_name`, `file_size` (bytes) and `time_uploaded` (a `POSIXct` in UTC).
#'   `grist_attachment_info()` returns the same columns for one attachment.
#'   `grist_attachments_upload()` returns the new attachment IDs and
#'   `grist_attachment_download()` returns the path written, both invisibly.
#' @family attachments
#' @examplesIf FALSE
#' doc <- grist_doc("am2iHJ9Amvo7Ve3EE5emtu")
#'
#' ids <- grist_attachments_upload(doc, "report.pdf")
#' grist_attachments(doc)
#' grist_attachment_info(doc, ids[[1]])
#' grist_attachment_download(doc, ids[[1]], tempdir())
#' @export
grist_attachments <- function(doc, filter = NULL, sort = NULL, limit = NULL) {
  doc <- grist_doc(doc)
  check_list_query(filter, sort, limit)

  body <- grist_request(doc, "attachments") |>
    req_list_query(filter, sort, limit) |>
    grist_perform()

  attachments_to_df(body$records)
}

#' @rdname grist_attachments
#' @export
grist_attachment_info <- function(doc, id) {
  doc <- grist_doc(doc)
  check_number_whole(id, min = 1)

  body <- grist_request(doc, "attachments", id) |>
    grist_perform()

  attachments_to_df(list(list(id = id, fields = body)))
}

#' @rdname grist_attachments
#' @export
grist_attachments_upload <- function(doc, path) {
  doc <- grist_doc(doc)
  check_character(path)

  missing <- path[!file.exists(path) | dir.exists(path)]
  if (length(missing) > 0) {
    cli::cli_abort(
      c(
        "{.arg path} must be existing files.",
        x = "Not an existing file: {.file {missing}}."
      )
    )
  }

  ids <- integer()
  for (file in path) {
    body <- grist_request(doc, "attachments") |>
      httr2::req_body_multipart(upload = curl::form_file(file)) |>
      grist_perform()
    ids <- c(ids, as.integer(unlist(body)))
  }
  invisible(ids)
}

#' @rdname grist_attachments
#' @export
grist_attachment_download <- function(doc, id, path, overwrite = FALSE) {
  doc <- grist_doc(doc)
  check_number_whole(id, min = 1)
  check_string(path)
  check_bool(overwrite)

  if (dir.exists(path)) {
    name <- basename(grist_attachment_info(doc, id)$file_name)
    if (is.na(name) || !nzchar(name)) {
      name <- paste0("attachment-", id)
    }
    path <- file.path(path, name)
  }

  req <- grist_request(doc, "attachments", id, "download")
  download_file(req, path, overwrite)
}

attachments_to_df <- function(records) {
  new_tbl(
    list(
      id = map_int(records, function(x) as.integer(x$id)),
      file_name = field_vec(records, "fileName", NA_character_),
      file_size = field_vec(records, "fileSize", NA_real_),
      time_uploaded = as.POSIXct(
        field_vec(records, "timeUploaded", NA_character_),
        format = "%Y-%m-%dT%H:%M:%OSZ",
        tz = "UTC"
      )
    ),
    n = length(records)
  )
}
