json_resp <- function(json = "{}", status = 200L) {
  httr2::response(
    status_code = status,
    headers = list("Content-Type" = "application/json"),
    body = charToRaw(json)
  )
}

# Mock Grist responses. Each response is used in turn (the last repeats).
# Returns an environment that records every request in `$reqs`.
local_grist_mock <- function(..., .env = parent.frame()) {
  responses <- list(...)
  state <- new.env()
  state$reqs <- list()
  httr2::local_mocked_responses(
    function(req) {
      state$reqs <- c(state$reqs, list(req))
      i <- min(length(state$reqs), length(responses))
      r <- responses[[i]]
      if (is.function(r)) r(req) else r
    },
    env = .env
  )
  state
}

req_body <- function(req) {
  jsonlite::toJSON(req$body$data, auto_unbox = TRUE, null = "null")
}

# The JSON body as it is sent, unlike `req_body()`, which re-serializes it.
req_body_sent <- function(req) {
  as.character(rlang::inject(jsonlite::toJSON(
    req$body$data,
    !!!req$body$params
  )))
}

local_grist_env <- function(.env = parent.frame()) {
  withr::local_envvar(
    GRIST_API_KEY = "test-key",
    GRIST_SERVER = NA,
    .local_envir = .env
  )
}

test_doc <- function() {
  grist_doc("abc123", server = "https://example.getgrist.com")
}

columns_json <- paste0(
  '{"columns":[',
  '{"id":"name","fields":{"label":"Name","type":"Text","isFormula":false}},',
  '{"id":"age","fields":{"label":"Age","type":"Int","isFormula":false}},',
  '{"id":"born","fields":{"label":"Born","type":"Date"}},',
  '{"id":"seen","fields":{"label":"Seen","type":"DateTime:America/New_York"}},',
  '{"id":"tags","fields":{"label":"Tags","type":"ChoiceList"}},',
  '{"id":"boss","fields":{"label":"Boss","type":"Ref:People"}}',
  "]}"
)

records_json <- paste0(
  '{"records":[',
  '{"id":1,"fields":{"name":"Ann","age":30,"born":631152000,',
  '"seen":1700000000,"tags":["L","a","b"],"boss":0}},',
  '{"id":2,"fields":{"name":"Bob","age":null,"born":null,',
  '"seen":null,"tags":null,"boss":1}}',
  "]}"
)
