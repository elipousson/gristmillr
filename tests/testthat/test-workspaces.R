workspaces_json <- paste0(
  '[{"id":12,"name":"Home","access":"owners","orgDomain":"docs","docs":[',
  '{"id":"d1","name":"Pets","access":"owners","isPinned":true,"urlId":null},',
  '{"id":"d2","name":"Plants","access":"editors","isPinned":false,"urlId":"plants"}]},',
  '{"id":13,"name":"Empty","access":"owners","orgDomain":"docs","docs":[]}]'
)

server <- "https://x.getgrist.com"

test_that("grist_orgs() lists orgs", {
  local_grist_env()
  mock <- local_grist_mock(json_resp(
    '[{"id":1,"name":"Personal","domain":"docs","access":"owners","createdAt":"2020-01-01T00:00:00.000Z","updatedAt":"2020-01-02T00:00:00.000Z"}]'
  ))

  out <- grist_orgs(server)

  expect_equal(out$id, 1L)
  expect_equal(out$domain, "docs")
  expect_s3_class(out$created_at, "POSIXct")
  expect_equal(format(out$updated_at, "%Y-%m-%d"), "2020-01-02")
  expect_equal(mock$reqs[[1]]$url, "https://x.getgrist.com/api/orgs")
})

test_that("grist_workspaces() lists workspaces with document counts", {
  local_grist_env()
  mock <- local_grist_mock(json_resp(workspaces_json))

  out <- grist_workspaces("docs", server)

  expect_equal(out$id, 12:13)
  expect_equal(out$n_docs, c(2L, 0L))
  expect_equal(out$org_domain, c("docs", "docs"))
  expect_equal(
    mock$reqs[[1]]$url,
    "https://x.getgrist.com/api/orgs/docs/workspaces"
  )
})

test_that("grist_docs() flattens documents across workspaces", {
  local_grist_env()
  local_grist_mock(json_resp(workspaces_json))

  out <- grist_docs(server = server)

  expect_equal(out$id, c("d1", "d2"))
  expect_equal(out$workspace_name, c("Home", "Home"))
  expect_equal(out$is_pinned, c(TRUE, FALSE))
  expect_equal(out$url_id, c(NA, "plants"))
})

test_that("grist_docs() handles no documents", {
  local_grist_env()
  local_grist_mock(json_resp("[]"))
  out <- grist_docs(server = server)
  expect_equal(nrow(out), 0)
  expect_named(
    out,
    c(
      "id",
      "name",
      "access",
      "is_pinned",
      "url_id",
      "workspace_id",
      "workspace_name"
    )
  )
})

test_that("grist_workspace_create() returns the new ID", {
  local_grist_env()
  mock <- local_grist_mock(json_resp("155"))
  expect_equal(grist_workspace_create("Pets", server = server), 155L)
  expect_equal(as.character(req_body(mock$reqs[[1]])), '{"name":"Pets"}')
})

test_that("grist_workspace_delete() follows the same ask rules", {
  local_grist_env()
  mock <- local_grist_mock(json_resp(""))

  grist_workspace_delete(12, ask = FALSE, server = server)
  expect_match(mock$reqs[[1]]$url, "/workspaces/12/remove$")

  grist_workspace_delete(
    12,
    mode = "permanent",
    ask = FALSE,
    server = server
  )
  expect_match(mock$reqs[[2]]$url, "/workspaces/12/remove\\?permanent=true$")

  local_interactive(FALSE)
  expect_error(
    grist_workspace_delete(12, server = server),
    class = "gristmillr_ask_required"
  )
  expect_length(mock$reqs, 2)
})

test_that("grist_workspace_delete() prompts with the workspace name", {
  local_grist_env()
  local_interactive(TRUE)
  prompts <- character()
  local_mocked_bindings(ask_yes_no = function(msg) {
    prompts <<- c(prompts, msg)
    TRUE
  })
  local_grist_mock(
    json_resp('{"id":12,"name":"Home","docs":[]}'),
    json_resp("")
  )

  grist_workspace_delete(12, server = server)
  expect_equal(prompts, 'Move workspace "Home" to the trash?')
})

test_that("grist_workspace_restore() posts to unremove", {
  local_grist_env()
  mock <- local_grist_mock(json_resp(""))
  expect_equal(grist_workspace_restore(12, server = server), 12L)
  expect_match(mock$reqs[[1]]$url, "/workspaces/12/unremove$")
})
