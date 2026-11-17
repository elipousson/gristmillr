# Live tests run only when a Grist server and API key are configured, e.g.
# GRIST_API_KEY and GRIST_SERVER=http://localhost:47478/o/docs
skip_if_no_grist <- function() {
  testthat::skip_on_cran()
  testthat::skip_on_ci()
  if (!nzchar(Sys.getenv("GRIST_API_KEY"))) {
    testthat::skip("GRIST_API_KEY is not set.")
  }
  if (!nzchar(Sys.getenv("GRIST_SERVER"))) {
    testthat::skip("GRIST_SERVER is not set.")
  }
}

# Create a scratch document in the first workspace and delete it afterwards.
local_scratch_doc <- function(.env = parent.frame()) {
  workspace <- grist_workspaces()$id[[1]]
  doc <- grist_doc_create(workspace, "gristmillr-test-scratch")
  withr::defer(
    try(
      grist_doc_delete(doc, mode = "permanent", ask = FALSE),
      silent = TRUE
    ),
    envir = .env
  )
  doc
}
